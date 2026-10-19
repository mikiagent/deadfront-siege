extends RefCounted
## Network core over real localhost sockets: one NetServer plus real NetClients and raw
## WebSocketPeers in this process (contracts.md §2, §3, §5.3, §5.4, §7). Loaded by run_all.gd
## once autoloads exist; every wait is bounded so a regression fails instead of hanging.

const ISLAND := "temperate_25"

var tree: SceneTree
var expect: Callable
var server: NetServer
var url := ""
var dir := ""
var alice: NetClient
var bob: NetClient
var _nodes: Array[Node] = []

class Raw:
	var ws := WebSocketPeer.new()
	var got: Array = []
	var next_id := 1
	var token := ""
	var account_id := -1

func run(p_tree: SceneTree, p_expect: Callable) -> void:
	tree = p_tree
	expect = p_expect
	dir = OS.get_user_data_dir().path_join("test_net_%d" % Time.get_ticks_usec())
	server = NetServer.new()
	server.new_accounts_per_hour = 1000.0
	_add(server)
	var err := server.start(0, dir, "127.0.0.1")
	_check(err == OK and server.port > 0, "server listens on a free localhost port")
	if err == OK:
		url = "ws://127.0.0.1:%d" % server.port
		await _test_accounts()
		await _test_hostile_frames()
		await _test_rate_limits()
		await _test_rid_replay()
		await _test_presence_and_chat()
		_test_store_reload()
		await _test_cleanup()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_rm_rf(dir)

# ---------------------------------------------------------------- identity (§3)

func _test_accounts() -> void:
	alice = _client("Alice", "tok_a.json")
	bob = _client("Bob", "tok_b.json")
	_check(await _until(func () -> bool: return alice.is_online() and bob.is_online()), "two clients come online")
	_check(alice.account_id >= 1 and bob.account_id >= 1 and alice.account_id != bob.account_id, "hello creates two accounts")
	_check(alice.account_name == "Alice" and bob.account_name == "Bob", "hello keeps the requested names")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tok_a.json")))
	var token := str(saved.get(url, {}).get("token", "")) if saved is Dictionary else ""
	_check(NetProtocol.is_token(token), "the client saves a 64-hex token per server url")
	var store_text := FileAccess.get_file_as_string(dir.path_join("accounts.json"))
	_check(token != "" and not token in store_text and token.sha256_text() in store_text, "the server stores only sha256(token)")

	var raw := await _raw()
	_check((await _req(raw, "auth.hello", {"name": "aLiCe"})).get("err") == "conflict", "a duplicate name is rejected case-insensitively")
	_check((await _req(raw, "auth.hello", {"name": "x!"})).get("err") == "bad_request", "an invalid name is rejected")
	_check((await _req(raw, "auth.hello", {"name": "Settlers"})).get("err") == "conflict", "the NPC account name is reserved")
	_check((await _req(raw, "auth.hello", {"name": "Zed", "token": "00"})).get("err") == "bad_request", "a malformed token is rejected")
	_check((await _req(raw, "auth.hello", {"name": "Zed", "token": "ab".repeat(32)})).get("err") == "unauthorized", "an unknown token is unauthorized")
	raw.ws.close()

	var alice_id := alice.account_id
	alice.disconnect_from_server()
	var again := _client("SomeoneElse", "tok_a.json")
	_check(await _until(func () -> bool: return again.is_online()), "a client with a saved token comes back online")
	_check(again.account_id == alice_id and again.account_name == "Alice", "reconnect with the token restores the same account")
	var kicked: Array = []
	again.event.connect(func (ev: String, _d: Dictionary) -> void:
		if ev == "kicked":
			kicked.append(ev)
	)
	alice = _client("Alice", "tok_a.json")
	_check(await _until(func () -> bool: return alice.is_online() and again.state == NetClient.State.OFFLINE), "a second login for the account wins")
	_check(alice.account_id == alice_id and not kicked.is_empty() and again.last_error == "signed in elsewhere", "the first connection gets evt kicked and stays offline")

	var bob_id := bob.account_id
	server._drop(server._by_account[bob_id], 4002, "test drop", server.mono())
	_check(await _until(func () -> bool: return not bob.is_online()), "a dropped client notices")
	var queued := bob.request("sys.ping")
	_check(await _until(func () -> bool: return bob.is_online(), 5.0), "the client reconnects by itself with backoff")
	_check(bob.account_id == bob_id, "auto-reconnect keeps the account")
	if not queued.finished:
		await queued.done
	_check(queued.ok and queued.r.has("server_time"), "a request made while reconnecting is sent once back online")

# ---------------------------------------------------------------- envelope and validation (§2)

func _test_hostile_frames() -> void:
	var r := await _raw()
	_check((await _req(r, "sys.ping", {})).get("err") == "unauthorized", "ops before hello are unauthorized")
	_check(await _hello(r, "Carol"), "a raw socket can say hello")
	_check(_err(await _ask(r, "{not json", 0)) == "bad_request", "bad JSON gets bad_request")
	_check(_err(await _ask(r, "[1,2,3]", 0)) == "bad_request", "a non-object frame gets bad_request")
	_check(_err(await _ask(r, "[".repeat(20000), 0)) == "bad_request", "absurdly nested JSON gets bad_request")
	_check(_err(await _ask(r, '{"t":"req","op":"sys.ping"}', 0)) == "bad_request", "a missing id gets bad_request")
	_check(_err(await _ask(r, '{"t":"req","id":1.5,"op":"sys.ping"}', 0)) == "bad_request", "a fractional id gets bad_request")
	_check(_err(await _ask(r, '{"t":"req","id":77}', 77)) == "bad_request", "a missing op gets bad_request with its id")
	_check(_err(await _ask(r, '{"t":"evt","id":78,"op":"sys.ping"}', 78)) == "bad_request", "a wrong t gets bad_request")
	_check(_err(await _ask(r, '{"t":"req","id":79,"op":"sys.ping","x":1}', 79)) == "bad_request", "an unknown envelope field gets bad_request")
	_check(_err(await _ask(r, '{"t":"req","id":80,"op":"sys.ping","a":[1]}', 80)) == "bad_request", "non-object args get bad_request")
	_check(_err(await _req(r, "nope.nothing", {})) == "bad_request", "an unknown op gets bad_request")
	_check(_err(await _req(r, "presence.update", {"island": ISLAND})) == "bad_request", "missing presence fields get bad_request")
	_check(_err(await _ask(r, '{"t":"req","id":81,"op":"presence.update","a":{"p":[1e999,0,0],"yaw":0,"anim":"idle","island":"%s"}}' % ISLAND, 81)) == "bad_request", "an infinite coordinate gets bad_request")
	_check(_err(await _req(r, "presence.update", {"p": ["a", 0, 0], "yaw": 0, "anim": "idle", "island": ISLAND})) == "bad_request", "a string coordinate gets bad_request")
	_check(_err(await _req(r, "presence.join", {"island": "../../etc"})) == "bad_request", "an unknown island gets bad_request")
	_check(_err(await _req(r, "chat.send", {"text": "hi"})) == "bad_request", "chat outside a room gets bad_request")
	r.ws.send(PackedByteArray([1, 2, 3]), WebSocketPeer.WRITE_MODE_BINARY)
	_check(_err(await _ask(r, "", 0)) == "bad_request", "a binary frame gets bad_request")
	var big := '{"t":"req","id":82,"op":"chat.send","a":{"text":"%s"}}' % "x".repeat(70000)
	_check(_err(await _ask(r, big, 0)) == "bad_request", "a frame over 64 KiB gets bad_request")
	_check((await _req(r, "sys.ping", {})).get("ok") == true, "the socket still works after hostile frames")
	r.ws.close()
	var huge := await _raw()
	huge.ws.send_text("x".repeat(300000))
	_check(await _until(func () -> bool: return _pump(huge) == WebSocketPeer.STATE_CLOSED), "a frame over the transport buffer closes only that socket")
	var after := await _raw()
	_check(await _hello(after, "Dave"), "the server keeps accepting after a hostile socket")
	after.ws.close()

# ---------------------------------------------------------------- rate limits (§5.4)

func _test_rate_limits() -> void:
	var r := await _raw()
	var pre := await _burst(r, "sys.ping", {}, 8)
	_check(_count(pre, "rate_limited") >= 3 and _count(pre, "unauthorized") <= 5, "requests before hello are rate limited per connection")
	r.ws.close()
	var c := await _raw()
	_check(await _hello(c, "Erin"), "Erin says hello")
	_check((await _req(c, "presence.join", {"island": "tundra_30"})).get("ok") == true, "Erin joins a room")
	var chats := await _burst(c, "chat.send", {"text": "spam"}, 8)
	var oks := _count(chats, "")
	_check(oks >= 5 and oks <= 6 and _count(chats, "rate_limited") >= 2, "chat is limited to burst 5 (got %d ok)" % oks)
	c.ws.close()
	# Per account, not per socket: a fresh connection does not refill the bucket.
	var c2 := await _raw()
	_check(await _hello(c2, "Erin", c.token), "Erin reconnects with her token")
	_check((await _req(c2, "presence.join", {"island": "tundra_30"})).get("ok") == true, "Erin rejoins")
	var more := await _burst(c2, "chat.send", {"text": "spam"}, 3)
	_check(_count(more, "rate_limited") >= 2, "the chat bucket belongs to the account, not the socket")
	c2.ws.close()

# ---------------------------------------------------------------- idempotency (§5.3)

func _test_rid_replay() -> void:
	var applied: Array = [0]
	var bump := func (_aid: int, _a: Dictionary) -> Dictionary:
		applied[0] += 1
		return NetProtocol.ok({"n": applied[0]})
	_check(server.register_op("test.bump", bump, true, "read"), "a mutating op registers")
	_check(server.register_op("test.other", func (_aid: int, _a: Dictionary) -> Dictionary: return NetProtocol.ok({}), true, "write"), "a second op registers")
	_check(server.register_op("test.broken", func (_aid: int, _a: Dictionary) -> Dictionary: return {"nope": 1}, false, "read"), "a broken op registers")
	_check(not server.register_op("test.bump", bump, true, "write"), "a duplicate op name is refused")
	_check(not server.register_op("auth.hello", bump, false, "read"), "auth.hello cannot be replaced")
	_check(not server.register_op("Bad Op", bump, false, "read") and not server.register_op("test.x", bump, false, "gold"), "malformed op names and rate classes are refused")
	var r := await _raw()
	_check(await _hello(r, "Frank"), "Frank says hello")
	var first := await _req(r, "test.bump", {}, "rid-first-01")
	var replay := await _req(r, "test.bump", {}, "rid-first-01")
	_check(first.get("r", {}).get("n") == 1 and replay.get("r", {}).get("n") == 1 and applied[0] == 1, "a replayed rid returns the cached response and changes nothing")
	_check((await _req(r, "test.bump", {}, "rid-second-02")).get("r", {}).get("n") == 2, "a new rid applies again")
	_check(_err(await _req(r, "test.other", {}, "rid-first-01")) == "conflict", "a rid reused for another op is a conflict")
	_check(_err(await _req(r, "test.bump", {})) == "bad_request" and applied[0] == 2, "a mutating op without rid is refused before it runs")
	_check(_err(await _req(r, "test.broken", {})) == "server_error", "a handler returning garbage gives server_error")
	r.ws.close()
	var r2 := await _raw()
	_check(await _hello(r2, "Frank", r.token), "Frank reconnects")
	_check((await _req(r2, "test.bump", {}, "rid-second-02")).get("r", {}).get("n") == 2 and applied[0] == 2, "the rid cache survives a dropped socket")
	# Bounded: only the last 64 rids are kept, oldest evicted first.
	for i in 30:
		_frame(r2, "test.bump", {}, "rid-fill-%04d" % i)
	var batch1 := await _collect(r2, 30)
	await tree.create_timer(1.8).timeout  # the read bucket (20/s, burst 40) refills
	for i in range(30, 66):
		_frame(r2, "test.bump", {}, "rid-fill-%04d" % i)
	var batch2 := await _collect(r2, 36)
	_check(_count(batch1, "") == 30 and _count(batch2, "") == 36, "66 paced mutating requests all apply")
	var cache: Dictionary = server.rid_caches.get(r2.account_id, {})
	_check(cache.size() == NetServer.RID_CACHE and cache.has("rid-fill-0065") and not cache.has("rid-fill-0000"), "the rid cache keeps exactly the last 64 (has %d)" % cache.size())
	var before: int = applied[0]
	_check((await _req(r2, "test.bump", {}, "rid-fill-0065")).get("r", {}).get("n") == before and applied[0] == before, "a recent rid still replays")
	r2.ws.close()

# ---------------------------------------------------------------- presence and chat (§7)

func _test_presence_and_chat() -> void:
	var puppets := RemotePlayers.new(bob)
	_add(puppets)
	var heard: Array = []  # [ev, d, msec] seen by Bob
	bob.event.connect(func (ev: String, d: Dictionary) -> void: heard.append([ev, d, Time.get_ticks_msec()]))
	var aid := alice.account_id
	var ja := alice.request("presence.join", {"island": ISLAND})
	await ja.done
	var jb := bob.request("presence.join", {"island": ISLAND})
	await jb.done
	_check(ja.ok and jb.ok, "both join the same island room")
	var u := alice.request("presence.update", _state(Vector3(0, 1, 0)))
	await u.done
	_check(u.ok, "the first presence update is accepted")
	_check(await _until(func () -> bool: return puppets.puppet(aid) != null, 3.0), "Bob spawns a puppet survivor for Alice")
	var pup := puppets.puppet(aid)
	_check(pup != null and pup.rig != null and pup.rig.has_clip(&"walk"), "the puppet reuses the survivor rig and clips")

	await tree.create_timer(0.15).timeout
	var sent := Time.get_ticks_msec()
	alice.request("presence.update", _state(Vector3(1, 1, 0), "walk"))
	var moved := await _until(func () -> bool: return _saw(heard, aid, 1.0) >= 0, 1.0)
	var latency := _saw(heard, aid, 1.0) - sent
	print("[nettests] presence latency %d ms" % latency)
	_check(moved and latency <= 300, "Bob receives Alice's move within 300 ms (got %d ms)" % latency)
	_check(await _until(func () -> bool: return pup.position.distance_to(Vector3(1, 1, 0)) < 0.01, 1.0) and pup.anim == "walk", "the puppet interpolates to the new position and plays the relayed clip")

	var tp := alice.request("presence.update", _state(Vector3(500, 1, 0)))
	await tp.done
	_check(not tp.ok and tp.err == "bad_request" and tp.msg.begins_with("moved too fast"), "a teleport is rejected")
	await tree.create_timer(0.3).timeout
	_check(_saw(heard, aid, 500.0) < 0, "a rejected teleport is never relayed")

	var ch := alice.request("chat.send", {"text": "  hi\u0007 there‮  "})
	await ch.done
	_check(ch.ok, "chat is accepted")
	_check(await _until(func () -> bool: return _chat(heard) != ""), "Bob receives the chat")
	_check(_chat(heard) == "hi there", "chat arrives trimmed and stripped (got \"%s\")" % _chat(heard))
	_check(pup.bubble.visible and pup.bubble.text == "hi there", "the puppet shows a chat bubble")
	var long := alice.request("chat.send", {"text": "x".repeat(NetChat.MAX_LEN + 1)})
	await long.done
	_check(long.err == "bad_request", "chat over 200 characters is rejected")
	var blank := alice.request("chat.send", {"text": " \u0001\n "})
	await blank.done
	_check(blank.err == "bad_request", "chat that is only control characters is rejected")

	alice.disconnect_from_server()
	_check(await _until(func () -> bool: return puppets.puppet(aid) == null), "leaving removes the avatar")
	_check(heard.any(func (e: Array) -> bool: return e[0] == "presence_leave" and int(e[1].get("id", -1)) == aid), "the room gets evt presence_leave")

	# A private island is everyone's own home: same island id, different rooms.
	alice = _client("Alice", "tok_a.json")
	_check(await _until(func () -> bool: return alice.is_online()), "Alice is back")
	var ha := alice.request("presence.join", {"island": "home_grassland"})
	await ha.done
	var hb := bob.request("presence.join", {"island": "home_grassland"})
	await hb.done
	var mark := Time.get_ticks_msec()
	var hu := alice.request("presence.update", _state(Vector3(3, 1, 3), "idle", "home_grassland"))
	await hu.done
	await tree.create_timer(0.3).timeout
	_check(ha.ok and hb.ok and hu.ok and not heard.any(func (e: Array) -> bool: return e[2] >= mark and e[0] == "presence"), "players on their own home islands never see each other")

# ---------------------------------------------------------------- persistence and cleanup

func _test_store_reload() -> void:
	var store := AccountStore.new()
	_check(store.open(dir) == OK and store.count() == server.accounts.count() and store.name_of(alice.account_id) == "Alice", "accounts reload from disk")
	var bad := dir.path_join("corrupt")
	DirAccess.make_dir_recursive_absolute(bad)
	var f := FileAccess.open(bad.path_join(AccountStore.FILE), FileAccess.WRITE)
	f.store_string("{oops")
	f.close()
	_check(AccountStore.new().open(bad) == ERR_FILE_CORRUPT, "a corrupt account file refuses to open instead of starting empty")

func _test_cleanup() -> void:
	alice.disconnect_from_server()
	bob.disconnect_from_server()
	_check(await _until(func () -> bool: return server.connection_count() == 0, 5.0), "the server releases every closed connection (left %d)" % server.connection_count())
	server.stop()

# ---------------------------------------------------------------- helpers

func _check(ok: bool, msg: String) -> void:
	expect.call(ok, "net: %s" % msg)

func _add(n: Node) -> void:
	tree.root.add_child(n)
	_nodes.append(n)

func _client(nm: String, token_file: String) -> NetClient:
	var c := NetClient.new()
	c.token_path = dir.path_join(token_file)
	_add(c)
	c.connect_to(url, nm)
	return c

func _until(cond: Callable, timeout: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await tree.process_frame
	return true

func _raw() -> Raw:
	var r := Raw.new()
	r.ws.outbound_buffer_size = 1 << 19  # room for the oversize frames sent on purpose
	r.ws.connect_to_url(url)
	await _until(func () -> bool: return _pump(r) == WebSocketPeer.STATE_OPEN)
	return r

func _pump(r: Raw) -> int:
	r.ws.poll()
	while r.ws.get_available_packet_count() > 0:
		r.got.append(JSON.parse_string(r.ws.get_packet().get_string_from_utf8()))
	return r.ws.get_ready_state()

## Sends frame (if any) and waits for the response with that id; id 0 = frame-level errors.
func _ask(r: Raw, frame: String, id: int) -> Dictionary:
	if frame != "":
		r.ws.send_text(frame)
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		_pump(r)
		for i in r.got.size():
			var m: Variant = r.got[i]
			if m is Dictionary and m.get("t") == "res" and int(m.get("id", -1)) == id:
				r.got.remove_at(i)
				return m
		await tree.process_frame
	return {}

func _frame(r: Raw, op: String, a: Dictionary, rid: String = "") -> int:
	var id := r.next_id
	r.next_id += 1
	var env := {"t": "req", "id": id, "op": op, "a": a}
	if rid != "":
		env["rid"] = rid
	r.ws.send_text(JSON.stringify(env))
	return id

func _req(r: Raw, op: String, a: Dictionary, rid: String = "") -> Dictionary:
	var id := _frame(r, op, a, rid)
	return await _ask(r, "", id)

## Sends n identical requests at once and returns their n responses.
func _burst(r: Raw, op: String, a: Dictionary, n: int) -> Array:
	for i in n:
		_frame(r, op, a)
	return await _collect(r, n)

func _collect(r: Raw, n: int) -> Array:
	await _until(func () -> bool:
		_pump(r)
		return r.got.filter(func (m: Variant) -> bool: return m is Dictionary and m.get("t") == "res").size() >= n
	)
	var out := r.got.filter(func (m: Variant) -> bool: return m is Dictionary and m.get("t") == "res")
	r.got = r.got.filter(func (m: Variant) -> bool: return not (m is Dictionary and m.get("t") == "res"))
	return out

func _hello(r: Raw, nm: String, token: String = "") -> bool:
	var a := {"name": nm}
	if token != "":
		a["token"] = token
	var res := await _req(r, "auth.hello", a)
	if res.get("ok") != true:
		return false
	r.token = str(res["r"]["token"])
	r.account_id = int(res["r"]["account_id"])
	return true

static func _err(res: Dictionary) -> String:
	return str(res.get("err", "")) if res.get("ok") == false else ("" if res.get("ok") == true else "no answer")

static func _count(results: Array, err: String) -> int:
	return results.filter(func (m: Dictionary) -> bool: return _err(m) == err).size()

static func _state(p: Vector3, anim: String = "idle", island: String = ISLAND) -> Dictionary:
	return {"p": [p.x, p.y, p.z], "yaw": 0.25, "anim": anim, "island": island}

## Msec when an evt presence for id at x arrived, or -1.
static func _saw(heard: Array, id: int, x: float) -> int:
	for e in heard:
		if e[0] != "presence":
			continue
		for row in e[1].get("players", []):
			if int(row.get("id", -1)) == id and absf(float(row["p"][0]) - x) < 0.01:
				return e[2]
	return -1

static func _chat(heard: Array) -> String:
	for e in heard:
		if e[0] == "chat":
			return str(e[1].get("text", ""))
	return ""

func _rm_rf(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for sub in da.get_directories():
		_rm_rf(path.path_join(sub))
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(path)
