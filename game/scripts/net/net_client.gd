class_name NetClient
extends Node
## Client end of the online protocol (contracts.md §1-§3): one WebSocket, auth.hello with the
## saved token, requests with timeouts, server events, keepalive pings, and reconnect with
## exponential backoff. Lives at Game.net; it does nothing until connect_to() is called.
##
##   var req := Game.net.request("chat.send", {"text": "hi"})
##   await req.done
##   if req.ok: ... req.r ...  else: ... req.err, req.msg ...
##
## Every request carries a fresh rid; the server uses it to deduplicate mutating ops. Requests
## still waiting when the socket drops are resent with the same rid after reconnect, paced so a
## backlog never trips the rate limit; requests made while it drains queue behind it, so ops land
## in the order they were made. A request that ends in "timeout" or "offline" may still have
## applied: retry(req) resends it under the same rid, never request() again.
##
## The saved token is the account's only key (§3), so it is never deleted: a key that is replaced
## moves to "lost" in the token file. When the server rejects the key, the archived ones are tried
## (a restored backup knows them) before a fresh account is made, and event("token_rejected")
## tells the UI.

signal state_changed(state: int)
signal event(ev: String, d: Dictionary)

enum State { OFFLINE, CONNECTING, AUTHENTICATING, ONLINE, WAITING }

const TOKEN_PATH := "user://online_token.json"
const MAX_SAVED_SERVERS := 16
const REQUEST_TIMEOUT := 10.0
const CONNECT_TIMEOUT := 10.0
const PING_INTERVAL := 15.0
const SILENCE_TIMEOUT := 45.0
const BACKOFF_MIN := 0.5
const BACKOFF_MAX := 30.0
const MAX_PENDING := 256
const MAX_NAME_RETRIES := 3
const PEER_BUFFER := 1 << 17
const NO_RETRY_CODES: Array[int] = [4003]  # signed in elsewhere: reconnecting would kick the other device back
## Not resent once written: the server has no rid cache for them, so a chat line would show
## twice, and a position from before the drop is stale anyway. They end with err "offline".
const NO_RESEND_OPS: Array[String] = ["chat.send", "presence.update"]
## Under the write class (§5.4, 5/s burst 10) so arrival jitter cannot push a backlog over it:
## rate_limited answers count toward the server's flood cut-off.
const RESEND_RATE := 4.0
const RESEND_BURST := 8.0
## Written at once even while a backlog drains: only the newest position matters, and at 10 Hz it
## would outrun the 4/s drain so the backlog never finished.
const STREAM_OPS: Array[String] = ["presence.update"]
## Rejected keys kept per server. shortcut: the oldest goes after this many rejections; a hostile
## server could otherwise grow the file one key per reconnect.
const MAX_LOST_TOKENS := 32

var state: State = State.OFFLINE
var url := ""
## Where the per-server token is kept; "" = throwaway identity (probes, tests).
var token_path := TOKEN_PATH
var account_id := -1
var account_name := ""
var last_error := ""
## Server unix time minus local unix time, from the last hello.
var server_time_offset := 0.0

var _ws: WebSocketPeer
var _want := false
var _token := ""
var _name := ""
var _name_tries := 0
var _attempt := 0
var _retry_at := 0.0
var _opened_at := 0.0
var _last_rx := 0.0
var _last_ping := 0.0
var _next_id := 1
var _pending: Dictionary = {}  # id -> NetRequest, sent or waiting for ONLINE
var _resend: Array[NetRequest] = []  # pending requests to write after a hello, oldest first
var _resend_bucket: TokenBucket
var _hello: NetRequest
var _rejected: Dictionary = {}  # tokens this server refused since the last good hello
var _crypto := Crypto.new()

## Starts connecting (and keeps reconnecting) to a ws:// or wss:// server.
func connect_to(p_url: String, wanted_name: String = "") -> Error:
	if not (p_url.begins_with("ws://") or p_url.begins_with("wss://")) or p_url.length() > 512:
		last_error = "online URL must start with ws:// or wss://"
		return ERR_INVALID_PARAMETER
	if _want and p_url == url:
		return OK
	_close_socket()
	url = p_url
	var saved := _saved_entry()
	_token = str(saved.get("token", ""))
	_name = NetProtocol.sanitize_name(str(saved.get("name", wanted_name)))
	_name_tries = 0
	_rejected.clear()
	_attempt = 0
	_want = true
	last_error = ""
	_open()
	return OK

func disconnect_from_server() -> void:
	_want = false
	_close_socket()
	_set_state(State.OFFLINE)
	_fail_all("offline", "disconnected")

func is_online() -> bool:
	return state == State.ONLINE

func request(op: String, a: Dictionary = {}, timeout: float = REQUEST_TIMEOUT) -> NetRequest:
	return _submit(_make(op, a, timeout))

## Sends req's op and args again under its rid, as a new request: the safe answer to a "timeout"
## or "offline" on a mutating op, because the server replays its cached response.
func retry(req: NetRequest, timeout: float = REQUEST_TIMEOUT) -> NetRequest:
	return _submit(_make(req.op, req.a, timeout, req.rid))

func _submit(req: NetRequest) -> NetRequest:
	if not _want:
		_finish_later(req, "offline", "not connected")
	elif req.frame.to_utf8_buffer().size() > NetProtocol.MAX_FRAME:
		_finish_later(req, "bad_request", "request larger than 64 KiB")
	elif _pending.size() >= MAX_PENDING:
		_finish_later(req, "rate_limited", "too many requests in flight")
	else:
		_pending[req.id] = req
		if state == State.ONLINE:
			if _resend.is_empty() or req.op in STREAM_OPS:
				_write(req)
			else:
				_resend.append(req)  # behind the backlog, paced by the same bucket
	return req

func _write(req: NetRequest) -> void:
	_ws.send_text(req.frame)
	req.sent = true

func _process(_delta: float) -> void:
	var now := _now()
	if _ws != null:
		_ws.poll()
		# Drain before looking at the state: a server that pushes evt kicked and closes in the
		# same tick leaves the event readable on a socket that already reports CLOSED.
		var n := 0
		while _ws != null and n < 64 and _ws.get_available_packet_count() > 0:
			n += 1
			var pkt := _ws.get_packet()
			_last_rx = now
			_on_frame(pkt)
	if _ws != null:
		match _ws.get_ready_state():
			WebSocketPeer.STATE_CONNECTING:
				if now - _opened_at > CONNECT_TIMEOUT:
					_lost("connect timeout")
			WebSocketPeer.STATE_OPEN:
				if state == State.CONNECTING:
					_last_rx = now
					_send_hello()
				elif state == State.ONLINE:
					if now - _last_rx > SILENCE_TIMEOUT:
						_lost("server silent for %d s" % int(SILENCE_TIMEOUT))
					elif now - _last_ping > PING_INTERVAL:
						_last_ping = now
						request("sys.ping")
					while not _resend.is_empty() and _resend_bucket.take(now):
						var req: NetRequest = _resend.pop_front()
						if not req.finished:
							_write(req)
			WebSocketPeer.STATE_CLOSED:
				var code := _ws.get_close_code()
				var reason := _ws.get_close_reason().substr(0, 120)
				# WebSocketPeer drops unread frames once CLOSED, so evt kicked can be lost with the
				# close; the 4003 close code carries the same news.
				var kicked := code in NO_RETRY_CODES and _want
				if kicked:
					_want = false
					last_error = "signed in elsewhere"
				_lost("closed (%d %s)" % [code, reason])
				if kicked:
					event.emit("kicked", {"reason": reason})
	elif state == State.WAITING and now >= _retry_at:
		_open()
	for id in _pending.keys():
		var req: NetRequest = _pending[id]
		if now > req.deadline:
			_pending.erase(id)
			req.finish({"ok": false, "err": "timeout", "msg": "no answer from the server in time"})

func _exit_tree() -> void:
	_close_socket()

func _open() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = PEER_BUFFER
	_ws.outbound_buffer_size = PEER_BUFFER
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		_lost("could not open %s (%s)" % [url, error_string(err)])
		return
	_opened_at = _now()
	_set_state(State.CONNECTING)

func _send_hello() -> void:
	_set_state(State.AUTHENTICATING)
	var a := {"name": _name}
	if _token != "":
		a["token"] = _token
	_hello = _make("auth.hello", a, REQUEST_TIMEOUT)
	_hello.done.connect(_on_hello)
	_pending[_hello.id] = _hello
	_ws.send_text(_hello.frame)

func _on_hello(req: NetRequest) -> void:
	if req != _hello:
		return
	_hello = null
	if req.ok:
		account_id = int(req.r.get("account_id", -1))
		account_name = str(req.r.get("name", _name))
		var tok := str(req.r.get("token", _token))
		_token = tok if NetProtocol.is_token(tok) else _token
		var st: Variant = req.r.get("server_time")
		server_time_offset = float(st) - Time.get_unix_time_from_system() if NetProtocol.is_num(st) else 0.0
		_rejected.clear()
		_save_entry()
		_attempt = 0
		_last_ping = _now()
		last_error = ""
		print("[net] online as %s (#%d) at %s" % [account_name, account_id, url])
		_set_state(State.ONLINE)
		_resend.clear()
		_resend_bucket = TokenBucket.new(RESEND_RATE, RESEND_BURST, _now())
		for id in _pending.keys():
			var pend: NetRequest = _pending[id]
			if pend.sent and pend.op in NO_RESEND_OPS:
				_pending.erase(id)
				_finish_later(pend, "offline", "the connection dropped before the answer; it may have been delivered")
			else:
				_resend.append(pend)
		return
	if req.err == "unauthorized" and _token != "":
		# Data reset or rolled back, a wrong --data dir, or another server on this address. The
		# key may work again once the operator fixes that, so keep it (see the header).
		_rejected[_token] = true
		_token = _next_archived()
		last_error = "the server did not recognise the saved account; its key stays in %s" % token_path
		print("[net] WARNING: %s rejected the saved token for %s (kept on disk); trying %s" % [url, _name,
			"an older key" if _token != "" else "a new account"])
		event.emit("token_rejected", {"name": _name})
		_send_hello()
		return
	if req.err == "conflict" and _token == "" and _name_tries < MAX_NAME_RETRIES:
		_name_tries += 1
		_name = NetProtocol.suffix_name(_name)
		_send_hello()
		return
	last_error = "%s: %s" % [req.err, req.msg]
	if req.err in ["bad_request", "conflict"]:
		_want = false  # the same hello can never succeed
	_lost(last_error)

func _on_frame(pkt: PackedByteArray) -> void:
	var json := JSON.new()
	if json.parse(pkt.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return  # never trust the server either: ignore what does not parse
	var m: Dictionary = json.data
	var t: Variant = m.get("t")
	if t is String and t == "res":
		var id: Variant = NetProtocol.as_int(m.get("id"), 0, NetProtocol.MAX_ID)
		if id == null:
			return
		if id == 0:
			print("[net] server rejected a frame: %s" % str(m.get("msg", "")).substr(0, 120))
			return
		var req: NetRequest = _pending.get(id)
		if req != null:
			_pending.erase(id)
			req.finish(m)
	elif t is String and t == "evt":
		var ev: Variant = m.get("ev")
		var d: Variant = m.get("d", {})
		if not ev is String or not d is Dictionary:
			return
		if ev == "kicked":
			_want = false
			last_error = "signed in elsewhere"
		event.emit(ev, d)

func _lost(why: String) -> void:
	if _hello != null:
		_pending.erase(_hello.id)  # a new socket says hello again
		_hello = null
	_resend.clear()  # the next hello queues every pending request again
	_close_socket()
	if state == State.ONLINE or state == State.AUTHENTICATING:
		print("[net] connection lost: %s" % why)
	if last_error == "":
		last_error = why
	if not _want:
		_set_state(State.OFFLINE)
		_fail_all("offline", last_error)
		return
	var delay := minf(BACKOFF_MAX, BACKOFF_MIN * pow(2.0, _attempt)) * randf_range(0.8, 1.2)
	_attempt = mini(_attempt + 1, 16)
	_retry_at = _now() + delay
	_set_state(State.WAITING)

func _close_socket() -> void:
	if _ws != null:
		_ws.close()
		_ws = null

func _set_state(s: State) -> void:
	if s != state:
		state = s
		state_changed.emit(s)

func _make(op: String, a: Dictionary, timeout: float, rid: String = "") -> NetRequest:
	var req := NetRequest.new()
	req.id = _next_id
	_next_id = 1 if _next_id >= NetProtocol.MAX_ID else _next_id + 1
	req.op = op
	req.a = a
	req.rid = rid if rid != "" else NetProtocol.uuid4(_crypto)
	req.deadline = _now() + timeout
	req.frame = JSON.stringify({"t": "req", "id": req.id, "rid": req.rid, "op": op, "a": a})
	return req

func _finish_later(req: NetRequest, code: String, msg: String) -> void:
	_finish_deferred.call_deferred(req, {"ok": false, "err": code, "msg": msg})

func _finish_deferred(req: NetRequest, res: Dictionary) -> void:
	req.finish(res)

func _fail_all(code: String, msg: String) -> void:
	var reqs := _pending.values()
	_pending.clear()
	_resend.clear()
	for req: NetRequest in reqs:
		_finish_later(req, code, msg)

func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0

# ---------------------------------------------------------------- token file
# {"<server url>": {"token", "name", "account_id", "saved", "lost": [{token, name, account_id,
# lost_at}]}}. Keyed by URL so one server's tokens are never sent to another.

func _read_tokens() -> Dictionary:
	if token_path == "" or not FileAccess.file_exists(token_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(token_path)) != OK or not json.data is Dictionary:
		return {}
	return json.data

func _saved_entry() -> Dictionary:
	var e: Variant = _read_tokens().get(url)
	if not e is Dictionary or not e.get("token") is String or not NetProtocol.is_token(e["token"]):
		return {}
	return e

func _save_entry() -> void:
	if token_path == "":
		return
	var all := _read_tokens()
	var e: Dictionary = all[url] if all.get(url) is Dictionary else {}
	var prev: Variant = e.get("token")
	if prev is String and NetProtocol.is_token(prev) and prev != _token:
		_add_lost(e, prev)  # never overwrite a key without archiving it
	var entry := {"token": _token, "name": account_name, "account_id": account_id, "saved": int(Time.get_unix_time_from_system())}
	if e.has("lost"):
		entry["lost"] = _lost_rows(e)
	all[url] = entry
	while all.size() > MAX_SAVED_SERVERS:
		var oldest: Variant = null
		for k in all.keys():
			if oldest == null or _saved_at(all[k]) < _saved_at(all[oldest]):
				oldest = k
		all.erase(oldest)
	_write_tokens(all)

static func _saved_at(e: Variant) -> float:
	return float(e.get("saved", 0)) if e is Dictionary and NetProtocol.is_num(e.get("saved")) else 0.0

## Adds e's current key to e["lost"] once, with e's name and account id, keeping the newest few.
static func _add_lost(e: Dictionary, tok: String) -> void:
	var lost := _lost_rows(e)
	if not lost.any(func (row: Dictionary) -> bool: return row["token"] == tok):
		lost.append({"token": tok, "name": e.get("name", ""), "account_id": e.get("account_id", -1),
			"lost_at": int(Time.get_unix_time_from_system())})
	e["lost"] = lost.slice(maxi(0, lost.size() - MAX_LOST_TOKENS))

## The newest archived key for this server not yet refused since the last good hello, or "".
func _next_archived() -> String:
	var lost := _lost_rows(_read_tokens().get(url))
	for i in range(lost.size() - 1, -1, -1):
		var t: String = lost[i]["token"]
		if NetProtocol.is_token(t) and not _rejected.has(t):
			return t
	return ""

static func _lost_rows(e: Variant) -> Array:
	var lost: Variant = e.get("lost") if e is Dictionary else null
	if not lost is Array:
		return []
	return (lost as Array).filter(func (row: Variant) -> bool: return row is Dictionary and row.get("token") is String)

func _write_tokens(all: Dictionary) -> void:
	var tmp := token_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		print("[net] could not save the online token (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(all, "\t"))
	var wrote := NetProtocol.flushed(f)  # a full disk must not truncate the file holding the keys
	f.close()
	if not wrote:
		DirAccess.remove_absolute(tmp)
		print("[net] could not save the online token (disk full?)")
		return
	if DirAccess.rename_absolute(tmp, token_path) != OK:
		print("[net] could not save the online token (rename failed)")
