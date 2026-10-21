class_name NetServer
extends Node
## Headless server root (contracts.md §1, §2, §3, §5.3, §5.4). Owns the TCP listener and the
## WebSocket peers, parses and validates envelopes, rate limits, and dispatches to registered
## ops. auth.hello lives here because it binds a socket to an account; presence, chat and the
## character intents (NetCharacters) register like any other op, and the economy plugs in the same way:
##
##   server.register_op("market.buy", handler, true, "write")
##   handler: func(account_id: int, a: Dictionary) -> Dictionary   # NetProtocol.ok(r) / .fail(code, msg)
##        or: func(account_id: int, a: Dictionary, rid: String) -> Dictionary
##
## Handlers run on the main thread one at a time, must validate everything before they change
## anything, and must not await (§5.1). A mutating op's response is stored under its rid in
## rids.jsonl before it is sent, so a retry with that rid replays it, even after a restart. An
## op that journals itself (§5.2) should take the rid, journal it with the op, and on boot call
## remember_rid() for each entry it replays: that covers a crash between its journal flush and
## ours.

signal account_created(account_id: int, name: String)
signal account_online(account_id: int)
signal account_offline(account_id: int)

const RATE_CLASSES := {"read": [20.0, 40.0], "write": [5.0, 10.0], "chat": [1.0, 5.0],
	"presence": [12.0, 50.0]}  # ASSUMPTION: §5.4 has no class for the 10 Hz stream; burst 50 = a 5 s stall
## ASSUMPTION: burst 4 leaves room for a stale-token retry and a name-taken retry.
const PRE_AUTH_RATE := [2.0, 4.0]
## Rejected frames (bad JSON, over the rate) before the socket is closed for flooding.
const FLOOD_RATE := [3.0, 30.0]
## Transport buffers. Frames between 64 KiB and this still arrive and get bad_request; anything
## larger makes the WebSocket layer close the socket (1009).
const PEER_BUFFER := 1 << 17
const PEER_QUEUE := 256
const MAX_CONNECTIONS := 256  # ASSUMPTION: v1 single-process cap
const MAX_PER_IP := 16  # ASSUMPTION
const HANDSHAKE_TIMEOUT := 5.0
const HELLO_TIMEOUT := 20.0
const IDLE_TIMEOUT := 60.0  # NetClient pings every 15 s
const CLOSE_GRACE := 3.0
const FRAMES_PER_TICK := 32  # per socket per frame, so one socket cannot starve the rest
const RID_CACHE := RidStore.PER_ACCOUNT
const SWEEP_INTERVAL := 10.0
## One server per data dir: a second one would overwrite the first's files. The lock is a
## heartbeat, not a pid, because Godot cannot ask whether an unrelated pid is alive.
const LOCK_FILE := "server.lock"
const LOCK_BEAT := 3.0
const LOCK_STALE := 10.0
## Room left for the res envelope around r, so a response that passes never makes a frame over 64 KiB.
const MAX_RESULT := NetProtocol.MAX_FRAME - 256
const ENVELOPE_KEYS: Array[String] = ["t", "id", "rid", "op", "a"]

## server.tscn sets it: the scene is the whole server process, started from Game's flags (§1).
@export var autostart := false
var accounts := AccountStore.new()
var rids := RidStore.new()
var presence: PresenceRooms
var chat: NetChat
var characters: NetCharacters
var port := 0
var new_accounts_per_hour := 10.0  # ASSUMPTION: per IP; tests raise it

var _tcp := TCPServer.new()
var _conns: Dictionary = {}  # conn id -> Conn
var _by_account: Dictionary = {}  # account_id -> Conn
var _ops: Dictionary = {}  # op -> {handler, mutating, rate_class}
var _buckets: Dictionary = {}  # account_id -> {rate_class -> TokenBucket}
var _ip_new: Dictionary = {}  # ip -> TokenBucket for account creation
var _lock_path := ""
var _lock_acc := 0.0
var _next_conn := 1
var _sweep_acc := 0.0
var _op_re := RegEx.create_from_string("^[a-z][a-z0-9_]{0,31}(\\.[a-z][a-z0-9_]{0,31}){0,3}\\z")  # \z, not $ (see NetProtocol)
var _rid_re := RegEx.create_from_string(RidStore.RID_PATTERN)

class Conn:
	var id := 0
	var ws: WebSocketPeer
	var ip := ""
	var opened := 0.0
	var last_rx := 0.0
	var account_id := -1
	var is_open := false
	var closing_until := -1.0
	var pre_auth: TokenBucket
	var flood: TokenBucket

func _init() -> void:
	presence = PresenceRooms.new(self)
	chat = NetChat.new(self, presence)
	register_op("sys.ping", func (_aid: int, _a: Dictionary) -> Dictionary: return NetProtocol.ok({"server_time": wall_time()}), false, "read")
	register_op("presence.join", presence.op_join, false, "write")
	register_op("presence.update", presence.op_update, false, "presence")
	register_op("chat.send", chat.op_send, false, "chat")
	characters = NetCharacters.new(self)

func _ready() -> void:
	if autostart:
		Engine.max_fps = 60  # ASSUMPTION: a headless main loop would otherwise spin a whole core
		if await start_when_free(Game.server_port, Game.server_data_dir) != OK:
			get_tree().quit(1)

## start(), but a lock left by a server that was killed waits out its heartbeat (at most
## LOCK_STALE + LOCK_BEAT) instead of failing. Godot runs no exit code on SIGTERM or Ctrl+C, so
## every non-graceful stop leaves the lock, and a supervisor's restart would otherwise exit 1.
func start_when_free(p_port: int, data_dir: String, bind: String = "*") -> Error:
	var err := start(p_port, data_dir, bind)
	var give_up := mono() + LOCK_STALE + LOCK_BEAT
	while err == ERR_ALREADY_IN_USE and mono() < give_up and is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		err = start(p_port, data_dir, bind)
	return err

## Locks the data dir, opens the stores and starts listening. port 0 picks a free port (see `port`).
func start(p_port: int, data_dir: String, bind: String = "*") -> Error:
	if not DirAccess.dir_exists_absolute(data_dir) and DirAccess.make_dir_recursive_absolute(data_dir) != OK:
		_log("store_error", {"dir": data_dir, "err": "cannot create the data dir"})
		return ERR_CANT_CREATE
	var err := _take_lock(data_dir)
	if err != OK:
		return err
	err = accounts.open(data_dir)
	if err == OK:
		err = rids.open(data_dir)
	var why := characters.open(data_dir) if err == OK else error_string(err)
	if why != "":
		_log("store_error", {"dir": data_dir, "err": why})
		stop()
		return err if err != OK else ERR_FILE_CORRUPT
	err = _tcp.listen(p_port, bind)
	if err != OK:
		_log("listen_error", {"port": p_port, "bind": bind, "err": error_string(err)})
		stop()
		return err
	port = _tcp.get_local_port()
	_log("listen", {"port": port, "bind": bind, "data": data_dir, "accounts": accounts.count()})
	return OK

func stop() -> void:
	for c: Conn in _conns.values():
		_unbind(c)
		c.ws.close(1001, "server shutting down")
	_conns.clear()
	if _tcp.is_listening():
		_tcp.stop()
		_log("stop", {"port": port})
	rids.close()
	characters.close()
	if _lock_path != "":
		DirAccess.remove_absolute(_lock_path)
		_lock_path = ""

func _exit_tree() -> void:
	stop()

func register_op(op_name: String, handler: Callable, mutating: bool, rate_class: String) -> bool:
	if _op_re.search(op_name) == null or op_name == "auth.hello" or _ops.has(op_name) \
			or not RATE_CLASSES.has(rate_class) or not handler.is_valid():
		push_error("[net] register_op refused %s (%s)" % [op_name, rate_class])
		return false
	_ops[op_name] = {"handler": handler, "mutating": mutating, "rate_class": rate_class,
		"takes_rid": handler.get_argument_count() >= 3}
	return true

## Puts a mutating op's response in the account's rid cache (on disk before it returns). The
## server does this itself; an economy replaying its journal at boot calls it for each entry.
func remember_rid(account_id: int, rid: String, op: String, res: Dictionary) -> Error:
	var err := rids.remember(account_id, rid, op, res)
	if err != OK:
		_log("store_error", {"op": op, "account": account_id, "err": "rid not saved: %s" % error_string(err)})
	return err

func send_event(account_id: int, ev: String, d: Dictionary) -> bool:
	var c: Conn = _by_account.get(account_id)
	var buf := _event_buf(ev, d) if c != null else PackedByteArray()
	return not buf.is_empty() and _send(c, buf)

## Serialises once and sends to every listed account that is online.
func broadcast_event(account_ids: Array, ev: String, d: Dictionary) -> void:
	var buf := _event_buf(ev, d)
	if buf.is_empty():
		return
	for aid in account_ids:
		var c: Conn = _by_account.get(aid)
		if c != null:
			_send(c, buf)

func is_online(account_id: int) -> bool:
	return _by_account.has(account_id)

func account_name(account_id: int) -> String:
	return accounts.name_of(account_id)

func connection_count() -> int:
	return _conns.size()

## Monotonic seconds for rate limits and timeouts.
func mono() -> float:
	return Time.get_ticks_usec() / 1000000.0

## Unix seconds for anything a client sees.
func wall_time() -> float:
	return Time.get_unix_time_from_system()

func _process(delta: float) -> void:
	if not _tcp.is_listening():
		return
	var now := mono()
	while _tcp.is_connection_available():
		_accept(_tcp.take_connection(), now)
	for c: Conn in _conns.values():
		_poll(c, now)
	presence.tick(delta)
	_lock_acc += delta
	if _lock_acc >= LOCK_BEAT:
		_lock_acc = 0.0
		_beat_lock()
	_sweep_acc += delta
	if _sweep_acc >= SWEEP_INTERVAL:
		_sweep_acc = 0.0
		_sweep(now)

func _accept(tcp: StreamPeerTCP, now: float) -> void:
	if tcp == null:
		return
	var ip := tcp.get_connected_host()
	var same_ip := 0
	for c: Conn in _conns.values():
		if c.ip == ip:
			same_ip += 1
	if _conns.size() >= MAX_CONNECTIONS or same_ip >= MAX_PER_IP:
		_log("refused", {"ip": ip, "conns": _conns.size(), "same_ip": same_ip})
		tcp.disconnect_from_host()
		return
	var c := Conn.new()
	c.ws = WebSocketPeer.new()
	c.ws.inbound_buffer_size = PEER_BUFFER
	c.ws.outbound_buffer_size = PEER_BUFFER
	c.ws.max_queued_packets = PEER_QUEUE
	var err := c.ws.accept_stream(tcp)
	if err != OK:
		_log("accept_error", {"ip": ip, "err": error_string(err)})
		tcp.disconnect_from_host()
		return
	c.id = _next_conn
	_next_conn += 1
	c.ip = ip
	c.opened = now
	c.last_rx = now
	c.pre_auth = TokenBucket.new(PRE_AUTH_RATE[0], PRE_AUTH_RATE[1], now)
	c.flood = TokenBucket.new(FLOOD_RATE[0], FLOOD_RATE[1], now)
	_conns[c.id] = c
	_log("connect", {"conn": c.id, "ip": ip})

func _poll(c: Conn, now: float) -> void:
	c.ws.poll()
	var st := c.ws.get_ready_state()
	if st == WebSocketPeer.STATE_CLOSED:
		_remove(c, "closed")
		return
	if c.closing_until >= 0.0:
		if now >= c.closing_until:
			c.ws.close(-1)
			_remove(c, "close timeout")
		return
	if st == WebSocketPeer.STATE_CONNECTING:
		if now - c.opened > HANDSHAKE_TIMEOUT:
			c.ws.close(-1)
			_remove(c, "handshake timeout")
		return
	if st != WebSocketPeer.STATE_OPEN:
		return  # the client started closing; wait for CLOSED
	if not c.is_open:
		c.is_open = true
		_log("open", {"conn": c.id, "ip": c.ip})
	var n := 0
	while n < FRAMES_PER_TICK and c.closing_until < 0.0 and c.ws.get_available_packet_count() > 0:
		n += 1
		var pkt := c.ws.get_packet()
		c.last_rx = now
		_on_frame(c, pkt, c.ws.was_string_packet(), now)
	if c.closing_until >= 0.0:
		return
	if c.account_id < 0 and now - c.opened > HELLO_TIMEOUT:
		_drop(c, 4001, "no hello", now)
	elif now - c.last_rx > IDLE_TIMEOUT:
		_drop(c, 4002, "idle", now)

func _on_frame(c: Conn, pkt: PackedByteArray, is_text: bool, now: float) -> void:
	if pkt.size() > NetProtocol.MAX_FRAME:
		_reject(c, 0, "frame larger than 64 KiB", now)
		return
	if not is_text:
		_reject(c, 0, "text frames only", now)
		return
	var json := JSON.new()
	if json.parse(pkt.get_string_from_utf8()) != OK or not json.data is Dictionary:
		_reject(c, 0, "frame is not a JSON object", now)
		return
	var env: Dictionary = json.data
	var id: Variant = NetProtocol.as_int(env.get("id"), 1, NetProtocol.MAX_ID)
	if id == null:
		_reject(c, 0, "id must be an integer from 1 to 2147483647", now)
		return
	var res := _handle(c, id, env, now)
	if c.closing_until < 0.0:
		_send(c, NetProtocol.res_frame(id, res).to_utf8_buffer())  # _handle keeps results under MAX_RESULT

func _handle(c: Conn, id: int, env: Dictionary, now: float) -> Dictionary:
	for k in env.keys():
		if not k in ENVELOPE_KEYS:
			return _strike(c, now, NetProtocol.fail("bad_request", "unknown envelope field %s" % str(k).substr(0, 32)))
	var op: Variant = env.get("op")
	var a: Variant = env.get("a", {})
	var rid: Variant = env.get("rid", "")
	if not env.get("t") is String or env["t"] != "req":
		return _strike(c, now, NetProtocol.fail("bad_request", "t must be \"req\""))
	if not op is String or _op_re.search(op) == null:
		return _strike(c, now, NetProtocol.fail("bad_request", "op missing or malformed"))
	if not a is Dictionary:
		return _strike(c, now, NetProtocol.fail("bad_request", "a must be an object"))
	if not rid is String or (rid != "" and _rid_re.search(rid) == null):
		return _strike(c, now, NetProtocol.fail("bad_request", "rid must be 8-64 of [A-Za-z0-9-]"))
	if c.account_id < 0:
		if not c.pre_auth.take(now):
			return _strike(c, now, NetProtocol.fail("rate_limited", "slow down"))
		if op != "auth.hello":
			return NetProtocol.fail("unauthorized", "send auth.hello first")
		return _hello(c, a, now)
	if op == "auth.hello":
		return NetProtocol.fail("bad_request", "already signed in on this connection")
	var spec: Dictionary = _ops.get(op, {})
	if spec.is_empty():
		return _strike(c, now, NetProtocol.fail("bad_request", "unknown op %s" % op))
	if not _bucket(c.account_id, spec["rate_class"], now).take(now):
		return _strike(c, now, NetProtocol.fail("rate_limited", "slow down"))
	var aid := c.account_id  # a handler may drop this socket, which clears c.account_id
	if spec["mutating"]:
		if rid == "":
			return NetProtocol.fail("bad_request", "%s needs a rid" % op)
		var hit := rids.lookup(aid, rid)
		if not hit.is_empty():
			return hit["res"] if hit["op"] == op else NetProtocol.fail("conflict", "rid already used for another op")
		if not rids.is_open():
			return NetProtocol.fail("server_error", "storage unavailable")  # an applied op must be replayable
	var handler: Callable = spec["handler"]
	var res: Variant = handler.call(aid, a, rid) if spec["takes_rid"] else handler.call(aid, a)
	if not NetProtocol.is_result(res):
		_log("handler_error", {"op": op, "account": aid})
		res = NetProtocol.fail("server_error", "internal error")
	elif JSON.stringify(res).to_utf8_buffer().size() > MAX_RESULT:
		# Sent as is, it would overflow the client's frame cap and our send buffer (dropping the
		# socket, after which the client resends the same request and loops).
		_log("handler_error", {"op": op, "account": aid, "err": "response over 64 KiB"})
		res = NetProtocol.fail("server_error", "response too large")
	if spec["mutating"]:
		remember_rid(aid, rid, op, res)
	return res

## auth.hello {name, token?} → {account_id, name, token, server_time} (contracts §3).
func _hello(c: Conn, a: Dictionary, now: float) -> Dictionary:
	var raw_name: Variant = a.get("name")
	var token: Variant = a.get("token", "")
	if not raw_name is String or not token is String:
		return NetProtocol.fail("bad_request", "name must be a string and token a string")
	var nm := (raw_name as String).strip_edges()
	if not NetProtocol.valid_name(nm):
		return NetProtocol.fail("bad_request", "name must be 3-20 characters: letters, digits, space, _ or -")
	var rec: Dictionary
	var created := false
	if token != "":
		if not NetProtocol.is_token(token):
			return NetProtocol.fail("bad_request", "token must be 64 lowercase hex characters")
		rec = accounts.find_by_token(token)
		if rec.is_empty():
			return NetProtocol.fail("unauthorized", "unknown token")
	else:
		if accounts.name_taken(nm):
			return NetProtocol.fail("conflict", "name taken")
		var bucket: TokenBucket = _ip_new.get(c.ip)
		if bucket == null:
			bucket = TokenBucket.new(new_accounts_per_hour / 3600.0, new_accounts_per_hour, now)
			_ip_new[c.ip] = bucket
		if not bucket.take(now):
			return NetProtocol.fail("rate_limited", "too many new accounts from this address")
		var made := accounts.create(nm, int(wall_time()))
		if made.is_empty():
			_log("store_error", {"op": "create", "conn": c.id})
			return NetProtocol.fail("server_error", "could not save the account")
		rec = made["account"]
		token = made["token"]
		created = true
	var aid: int = rec["id"]
	var old: Conn = _by_account.get(aid)
	if old != null and old != c:
		_send(old, NetProtocol.evt_frame("kicked", {"reason": "signed in elsewhere"}).to_utf8_buffer())
		_drop(old, 4003, "signed in elsewhere", now)
	c.account_id = aid
	_by_account[aid] = c
	_log("hello", {"conn": c.id, "account": aid, "name": rec["name"], "new": created})
	if created:
		account_created.emit(aid, rec["name"])
	account_online.emit(aid)
	return NetProtocol.ok({"account_id": aid, "name": rec["name"], "token": token, "server_time": wall_time()})

func _bucket(aid: int, cls: String, now: float) -> TokenBucket:
	var per: Dictionary = _buckets.get(aid, {})
	if per.is_empty():
		_buckets[aid] = per
	var b: TokenBucket = per.get(cls)
	if b == null:
		b = TokenBucket.new(RATE_CLASSES[cls][0], RATE_CLASSES[cls][1], now)
		per[cls] = b
	return b

## Counts a rejected frame against the flood budget; returns res so callers can chain it.
func _strike(c: Conn, now: float, res: Dictionary) -> Dictionary:
	if not c.flood.take(now):
		_drop(c, 4005, "flood", now)
	return res

func _reject(c: Conn, id: int, msg: String, now: float) -> void:
	var res := _strike(c, now, NetProtocol.fail("bad_request", msg))
	if c.closing_until < 0.0:
		_send(c, NetProtocol.res_frame(id, res).to_utf8_buffer())

func _send(c: Conn, buf: PackedByteArray) -> bool:
	if c.closing_until >= 0.0 or c.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return false
	if c.ws.get_current_outbound_buffered_amount() + buf.size() > PEER_BUFFER - 4096:
		_drop(c, 4004, "too slow", mono())  # a client that stops reading must not grow our memory
		return false
	if c.ws.send(buf, WebSocketPeer.WRITE_MODE_TEXT) != OK:
		_drop(c, 4004, "send failed", mono())
		return false
	return true

## Server-initiated close: the account is released at once, the socket gets CLOSE_GRACE to finish.
func _drop(c: Conn, code: int, reason: String, now: float) -> void:
	if c.closing_until >= 0.0:
		return
	_log("drop", {"conn": c.id, "account": c.account_id, "code": code, "reason": reason})
	_unbind(c)
	c.closing_until = now + CLOSE_GRACE
	c.ws.close(code, reason)

func _remove(c: Conn, why: String) -> void:
	_log("close", {"conn": c.id, "account": c.account_id, "code": c.ws.get_close_code(),
		"reason": c.ws.get_close_reason().substr(0, 64), "why": why, "secs": snappedf(mono() - c.opened, 0.01)})
	_unbind(c)
	_conns.erase(c.id)

func _unbind(c: Conn) -> void:
	var aid := c.account_id
	c.account_id = -1
	if aid < 0 or _by_account.get(aid) != c:
		return
	_by_account.erase(aid)
	account_offline.emit(aid)

## Drops limiter state that nobody can be using any more, so memory follows live load. The rid
## cache is never swept: it is bounded per account and must outlive any retry (§4, §5.3).
func _sweep(now: float) -> void:
	for aid in _buckets.keys():
		if _by_account.has(aid):
			continue
		var full := true
		for b: TokenBucket in _buckets[aid].values():
			full = full and b.is_full(now)
		if full:
			_buckets.erase(aid)
	for ip in _ip_new.keys():
		if (_ip_new[ip] as TokenBucket).is_full(now):
			_ip_new.erase(ip)

## The serialised event, or empty (and logged) when it would break the 64 KiB frame cap.
func _event_buf(ev: String, d: Dictionary) -> PackedByteArray:
	var buf := NetProtocol.evt_frame(ev, d).to_utf8_buffer()
	if buf.size() <= NetProtocol.MAX_FRAME:
		return buf
	_log("event_error", {"ev": ev.substr(0, 32), "bytes": buf.size(), "err": "event over 64 KiB"})
	return PackedByteArray()

func _take_lock(dir: String) -> Error:
	var p := dir.path_join(LOCK_FILE)
	if FileAccess.file_exists(p):
		var json := JSON.new()
		var held: Variant = json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null
		var beat: Variant = held.get("beat") if held is Dictionary else null
		if NetProtocol.is_num(beat) and absf(wall_time() - float(beat)) < LOCK_STALE:
			_log("lock_error", {"dir": dir, "held_by": held.get("pid"), "err": "data dir in use; if that server is gone, wait %d s or delete %s" % [int(LOCK_STALE), LOCK_FILE]})
			return ERR_ALREADY_IN_USE
	_lock_path = p
	return _beat_lock()

func _beat_lock() -> Error:
	if _lock_path == "":
		return OK
	var f := FileAccess.open(_lock_path, FileAccess.WRITE)
	if f == null:
		_log("lock_error", {"path": _lock_path, "err": error_string(FileAccess.get_open_error())})
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"pid": OS.get_process_id(), "beat": wall_time()}))
	f.close()
	return OK

func _log(ev: String, fields: Dictionary) -> void:
	var line := {"ev": ev}
	line.merge(fields)
	print("[net] %s" % JSON.stringify(line))
