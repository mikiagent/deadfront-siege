class_name NetServer
extends Node
## Headless server root (contracts.md §1, §2, §3, §5.3, §5.4). Owns the TCP listener and the
## WebSocket peers, parses and validates envelopes, rate limits, and dispatches to registered
## ops. auth.hello lives here because it binds a socket to an account; presence and chat
## register like any other op, and the economy plugs in the same way:
##
##   server.register_op("market.buy", handler, true, "write")
##   handler: func(account_id: int, a: Dictionary) -> Dictionary   # NetProtocol.ok(r) / .fail(code, msg)
##
## Handlers run on the main thread one at a time, must validate everything before they change
## anything, and must not await (§5.1).

signal account_created(account_id: int, name: String)
signal account_online(account_id: int)
signal account_offline(account_id: int)

const RATE_CLASSES := {"read": [20.0, 40.0], "write": [5.0, 10.0], "chat": [1.0, 5.0]}
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
const RID_CACHE := 64
const RID_TTL := 3600.0  # ASSUMPTION: an account offline this long loses its in-memory rid cache
const SWEEP_INTERVAL := 10.0
const ENVELOPE_KEYS: Array[String] = ["t", "id", "rid", "op", "a"]

var accounts := AccountStore.new()
var presence: PresenceRooms
var chat: NetChat
var port := 0
var new_accounts_per_hour := 10.0  # ASSUMPTION: per IP; tests raise it
## account_id -> {rid -> {op, res}} in insertion order (oldest first). In memory only; the
## economy snapshot may persist it (contracts §4 lists rid_cache on the Account).
var rid_caches: Dictionary = {}

var _tcp := TCPServer.new()
var _conns: Dictionary = {}  # conn id -> Conn
var _by_account: Dictionary = {}  # account_id -> Conn
var _ops: Dictionary = {}  # op -> {handler, mutating, rate_class}
var _buckets: Dictionary = {}  # account_id -> {rate_class -> TokenBucket}
var _ip_new: Dictionary = {}  # ip -> TokenBucket for account creation
var _offline_since: Dictionary = {}  # account_id -> mono()
var _next_conn := 1
var _sweep_acc := 0.0
var _op_re := RegEx.create_from_string("^[a-z][a-z0-9_]{0,31}(\\.[a-z][a-z0-9_]{0,31}){0,3}$")
var _rid_re := RegEx.create_from_string("^[A-Za-z0-9-]{8,64}$")

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
	register_op("presence.update", presence.op_update, false, "read")
	register_op("chat.send", chat.op_send, false, "chat")

## Opens the account store and starts listening. port 0 picks a free port (see `port`).
func start(p_port: int, data_dir: String, bind: String = "*") -> Error:
	var err := accounts.open(data_dir)
	if err != OK:
		_log("store_error", {"dir": data_dir, "err": error_string(err)})
		return err
	err = _tcp.listen(p_port, bind)
	if err != OK:
		_log("listen_error", {"port": p_port, "bind": bind, "err": error_string(err)})
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

func _exit_tree() -> void:
	stop()

func register_op(op_name: String, handler: Callable, mutating: bool, rate_class: String) -> bool:
	if _op_re.search(op_name) == null or op_name == "auth.hello" or _ops.has(op_name) \
			or not RATE_CLASSES.has(rate_class) or not handler.is_valid():
		push_error("[net] register_op refused %s (%s)" % [op_name, rate_class])
		return false
	_ops[op_name] = {"handler": handler, "mutating": mutating, "rate_class": rate_class}
	return true

func send_event(account_id: int, ev: String, d: Dictionary) -> bool:
	var c: Conn = _by_account.get(account_id)
	return c != null and _send(c, NetProtocol.evt_frame(ev, d).to_utf8_buffer())

## Serialises once and sends to every listed account that is online.
func broadcast_event(account_ids: Array, ev: String, d: Dictionary) -> void:
	var buf := NetProtocol.evt_frame(ev, d).to_utf8_buffer()
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
		_send(c, NetProtocol.res_frame(id, res).to_utf8_buffer())

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
	var cache: Dictionary = {}
	if spec["mutating"]:
		if rid == "":
			return NetProtocol.fail("bad_request", "%s needs a rid" % op)
		cache = rid_caches.get(c.account_id, {})
		var hit: Dictionary = cache.get(rid, {})
		if not hit.is_empty():
			return hit["res"] if hit["op"] == op else NetProtocol.fail("conflict", "rid already used for another op")
	var res: Variant = (spec["handler"] as Callable).call(c.account_id, a)
	if not NetProtocol.is_result(res):
		_log("handler_error", {"op": op, "account": c.account_id})
		res = NetProtocol.fail("server_error", "internal error")
	if spec["mutating"]:
		if cache.is_empty():
			rid_caches[c.account_id] = cache
		cache[rid] = {"op": op, "res": (res as Dictionary).duplicate(true)}
		while cache.size() > RID_CACHE:
			cache.erase(cache.keys()[0])  # dictionaries keep insertion order: oldest first
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
	_offline_since.erase(aid)
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
	_offline_since[aid] = mono()
	account_offline.emit(aid)

## Drops limiter and rid state that nobody can be using any more, so memory follows live load.
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
	for aid in _offline_since.keys():
		if now - float(_offline_since[aid]) > RID_TTL:
			rid_caches.erase(aid)
			_offline_since.erase(aid)

func _log(ev: String, fields: Dictionary) -> void:
	var line := {"ev": ev}
	line.merge(fields)
	print("[net] %s" % JSON.stringify(line))
