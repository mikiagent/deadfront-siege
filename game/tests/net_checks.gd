extends RefCounted
## Network core over real localhost sockets: one NetServer plus real NetClients and raw
## WebSocketPeers in this process (contracts.md §2, §3, §5.3, §5.4, §7, v2 §0). net_tests.gd
## loads it once the autoloads exist; every wait is bounded so a regression fails instead of hanging.

const ISLAND := "temperate_25"

var tree: SceneTree
var expect: Callable
var server: NetServer
var url := ""
var dir := ""
var alice: NetClient
var bob: NetClient
var frank_token := ""
var last_fill := 0  # the response n cached under rid-fill-0065
var crashy_n: Array = [0]  # applies of test.crashy on the restarted server
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
		await _test_flood()
		await _test_rid_replay()
		await _test_restart()
		await _test_client_retry()
		await _test_token_kept()
		await _test_rid_write_failure()
		await _test_lock_wait()
		await _test_presence_and_chat()
		await _test_area_caps()
		await _test_per_ip()
		await _test_characters()
		_test_presence_rules()
		_test_chat_clean()
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
	raw.ws.close()
	raw = await _raw()  # a fresh pre-hello bucket (burst 4)
	_check((await _req(raw, "auth.hello", {"name": "Zed", "token": "00"})).get("err") == "bad_request", "a malformed token is rejected")
	_check((await _req(raw, "auth.hello", {"name": "Zed", "token": "ab".repeat(32)})).get("err") == "unauthorized", "an unknown token is unauthorized")
	_check((await _req(raw, "auth.hello", {"name": "Zed", "token": "ab".repeat(32) + "\n"})).get("err") == "bad_request", "a token with a trailing newline is malformed (validators anchor with \\z)")
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
	_check(_err(await _req(r, "sys.ping\n", {})) == "bad_request", "an op name with a trailing newline gets bad_request")
	_check(_err(await _req(r, "sys.ping", {}, "abcdefgh\n")) == "bad_request", "a rid with a trailing newline gets bad_request")
	_check(_err(await _req(r, "presence.update", {"p": [0, 1, 0], "yaw": 0, "anim": "idle\n", "island": ISLAND})) == "bad_request", "a clip name with a trailing newline gets bad_request")
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
	var moves := await _burst(c2, "presence.update", _state(Vector3(2, 1, 2), "idle", "tundra_30"), 30)
	var pings := await _burst(c2, "sys.ping", {}, 40)
	_check(_count(moves, "") == 30 and _count(pings, "") == 40, "presence has its own bucket and leaves the read budget alone (%d/%d)" % [_count(moves, ""), _count(pings, "")])
	c2.ws.close()

## Flood strikes: frames no op bucket throttles (a second hello, bad JSON, unknown ops) close the
## socket with 4005; an op over its own bucket is answered rate_limited and the socket stays.
func _test_flood() -> void:
	var h := await _raw()
	_check(await _hello(h, "Olga"), "Olga signs in")
	var twice := await _req(h, "auth.hello", {"name": "Olga", "token": h.token})
	_check(_err(twice) == "bad_request" and "already signed in" in str(twice.get("msg")), "a second hello on a signed-in socket is bad_request (%s)" % twice)
	for i in 40:
		_frame(h, "auth.hello", {"name": "Olga"})
	_check(await _until(func () -> bool: return _pump(h) == WebSocketPeer.STATE_CLOSED) and h.ws.get_close_code() == 4005, "a burst of hellos after sign-in closes the socket for flooding (code %d)" % h.ws.get_close_code())
	var m := await _raw()
	_check(await _hello(m, "Pia") and (await _req(m, "presence.join", {"island": "tundra_30"})).get("ok") == true, "Pia joins a room")
	var mash := await _burst(m, "chat.send", {"text": "hi"}, 60)
	var sent := _count(mash, "")
	_check(mash.size() == 60 and sent >= 5 and sent <= 6 and _count(mash, "rate_limited") == 60 - sent, "mashing Send 60 times is throttled: %d sent, %d of 60 answered" % [sent, mash.size()])
	_check((await _req(m, "sys.ping", {})).get("ok") == true, "the socket stays open after the mashing")
	for i in 200:
		_frame(m, "chat.send", {"text": "spam"})
	_check(await _until(func () -> bool: return _pump(m) == WebSocketPeer.STATE_CLOSED) and m.ws.get_close_code() == 4005, "a script looping far past its bucket is still cut off (code %d)" % m.ws.get_close_code())

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
	server.register_op("test.rid", func (_aid: int, _a: Dictionary, rid: String) -> Dictionary: return NetProtocol.ok({"rid": rid}), true, "write")
	_check((await _req(r, "test.rid", {}, "rid-echo-0001")).get("r", {}).get("rid") == "rid-echo-0001", "a handler with a third parameter gets the rid (to journal it)")
	server.register_op("test.huge", func (_aid: int, _a: Dictionary) -> Dictionary: return NetProtocol.ok({"blob": "x".repeat(200000)}), false, "read")
	var huge := await _req(r, "test.huge", {})
	_check(_err(huge) == "server_error" and str(huge.get("msg")) == "response too large", "a response over 64 KiB becomes server_error instead of killing the socket")
	_check(not server.send_event(r.account_id, "test", {"blob": "x".repeat(200000)}), "an event over 64 KiB is not sent")
	_check((await _req(r, "sys.ping", {})).get("ok") == true, "the socket survives oversize results and events")
	frank_token = r.token
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
	var held := server.rids.count(r2.account_id)
	_check(held == NetServer.RID_CACHE and not server.rids.lookup(r2.account_id, "rid-fill-0065").is_empty() \
		and server.rids.lookup(r2.account_id, "rid-fill-0000").is_empty(), "the rid cache keeps exactly the last 64 (has %d)" % held)
	var before: int = applied[0]
	last_fill = before
	_check((await _req(r2, "test.bump", {}, "rid-fill-0065")).get("r", {}).get("n") == before and applied[0] == before, "a recent rid still replays")
	r2.ws.close()
	_check(await _until(func () -> bool: return not server.is_online(r2.account_id)), "Frank goes offline")
	server._sweep(server.mono() + 7200.0)  # two hours offline
	var r3 := await _raw()
	_check(await _hello(r3, "Frank", frank_token), "Frank comes back")
	_check((await _req(r3, "test.bump", {}, "rid-fill-0065")).get("r", {}).get("n") == before and applied[0] == before, "the rid cache has no time limit: it still replays after hours offline")
	r3.ws.close()

# ---------------------------------------------------------------- restart and client retries (§5.3)

## The dupe the review found: an op applies, the server dies before answering, a new server
## starts on the same data dir within the client's deadline, and NetClient resends the same rid.
func _test_restart() -> void:
	var applied: Array = [0]
	server.register_op("test.crashy", _crashy(server, applied), true, "write")
	var pending := bob.request("test.crashy", {"crash": true})
	_check(await _until(func () -> bool: return applied[0] == 1), "the op applies on the first server")
	var p := server.port
	server.stop()  # dies without answering
	server = NetServer.new()
	server.new_accounts_per_hour = 1000.0
	_add(server)
	_check(server.start(p, dir, "127.0.0.1") == OK, "a new server starts on the same port and data dir")
	server.register_op("test.crashy", _crashy(server, crashy_n), true, "write")
	var bumps: Array = [0]
	server.register_op("test.bump", func (_aid: int, _a: Dictionary) -> Dictionary:
		bumps[0] += 1
		return NetProtocol.ok({"n": -1}), true, "read")
	if not pending.finished:
		await pending.done
	_check(pending.ok and pending.r.get("n") == 1 and crashy_n[0] == 0, "NetClient's resend after the restart replays the saved response instead of applying twice")
	var r := await _raw()
	_check(await _hello(r, "Frank", frank_token), "accounts survive the restart")
	_check((await _req(r, "test.bump", {}, "rid-fill-0065")).get("r", {}).get("n") == last_fill and bumps[0] == 0, "an older rid replays after the restart too")
	r.ws.close()
	var rival := NetServer.new()
	_check(rival.start(0, dir, "127.0.0.1") == ERR_ALREADY_IN_USE, "a second server on the same data dir is refused")
	rival.free()
	_check(FileAccess.file_exists(dir.path_join(AccountStore.FILE + ".bak")), "the account store keeps the previous file as .bak")
	_check(await _until(func () -> bool: return alice.is_online() and bob.is_online(), 5.0), "clients reconnect to the restarted server")

func _test_client_retry() -> void:
	var before: int = crashy_n[0]
	var q := bob.request("test.crashy", {"crash": true}, 0.3)  # never answered; the reconnect takes >= 0.4 s
	await q.done
	_check(q.err == "timeout" and crashy_n[0] == before + 1, "an applied but unanswered request times out")
	_check(await _until(func () -> bool: return bob.is_online(), 5.0), "Bob reconnects")
	var again := bob.retry(q)
	await again.done
	_check(again.rid == q.rid and again.id != q.id, "retry reuses the rid under a new id")
	_check(again.ok and again.r.get("n") == before + 1 and crashy_n[0] == before + 1, "retry after a timeout replays instead of applying twice")

	var line := bob.request("chat.send", {"text": "only once"})
	var ping := bob.request("sys.ping")
	server._drop(server._by_account[bob.account_id], 4002, "test drop", server.mono())  # before the server reads either
	await line.done
	if not ping.finished:
		await ping.done
	_check(line.err == "offline", "a chat line already sent is not resent after a reconnect (got %s)" % line.err)
	_check(ping.ok, "a read already sent is resent after the reconnect")

	var order: Array = []
	server.register_op("test.order", func (_aid: int, a: Dictionary) -> Dictionary:
		order.append(int(a.get("n", -1)))
		return NetProtocol.ok({}), true, "write")
	server._drop(server._by_account[bob.account_id], 4002, "test drop", server.mono())
	_check(await _until(func () -> bool: return not bob.is_online()), "Bob is offline again")
	var backlog: Array[NetRequest] = []
	for i in 20:
		backlog.append(bob.request("test.order", {"n": i}))
	_check(await _until(func () -> bool: return bob.is_online(), 5.0), "Bob reconnects with a backlog")
	backlog.append(bob.request("test.order", {"n": 20}))  # the backlog is still draining at 4/s
	await _until(func () -> bool: return backlog.all(func (b: NetRequest) -> bool: return b.finished), 9.0)
	var limited := backlog.filter(func (b: NetRequest) -> bool: return b.err == "rate_limited").size()
	_check(backlog.all(func (b: NetRequest) -> bool: return b.ok), "a 20-request backlog plus a new request is paced under the write limit (%d rate limited)" % limited)
	_check(order == range(21), "a request made while the backlog drains lands after it (applied %s)" % str(order))

## The token is the account's only key (§3): a server that rejects it must not cost the player
## the account once the operator restores the data.
func _test_token_kept() -> void:
	var file := dir.path_join("tok_g.json")
	var stale := "cd".repeat(32)
	_write(file, JSON.stringify({url: {"token": stale, "name": "Gina", "account_id": 4242, "saved": 1}}))
	var g := _client("Gina", "tok_g.json")
	var warned: Array = []
	g.event.connect(func (ev: String, _d: Dictionary) -> void:
		if ev == "token_rejected":
			warned.append(ev)
	)
	_check(await _until(func () -> bool: return g.is_online()), "a client whose saved token is rejected still comes online")
	_check(g.account_name == "Gina" and g.account_id != 4242 and not warned.is_empty(), "it falls back to a fresh account and emits token_rejected")
	var e := _token_entry(file)
	_check(e.get("token") != stale and _lost_keys(e).has(stale), "the rejected token is kept on disk after the fallback")
	g.disconnect_from_server()
	# The operator restores a backup: Gina's new key is unknown again, but an archived one (Frank's
	# account stands in for her original) is known. The client must find its way back.
	e["token"] = "ef".repeat(32)
	if not e.get("lost") is Array:
		e["lost"] = []  # only when the check above already failed; keeps the rest running
	e["lost"].append({"token": frank_token, "name": "Frank", "account_id": -1, "lost_at": 1})
	_write(file, JSON.stringify({url: e}))
	g.connect_to(url)
	_check(await _until(func () -> bool: return g.is_online()) and g.account_name == "Frank", "after a restore, an archived key signs back in to the old account")
	e = _token_entry(file)
	_check(e.get("token") == frank_token and _lost_keys(e).has("ef".repeat(32)) and _lost_keys(e).has(stale), "every key the server ever refused is still on disk")
	g.disconnect_from_server()

## A full disk: store_line and flush report success there, so the store checks the file length.
## A read-only handle makes every write fail the same way the checks see it.
func _test_rid_write_failure() -> void:
	var applied: Array = [0]
	server.register_op("test.disk", func (_aid: int, _a: Dictionary) -> Dictionary:
		applied[0] += 1
		return NetProtocol.ok({"n": applied[0]}), true, "write")
	var r := await _raw()
	_check(await _hello(r, "Frank", frank_token), "Frank signs in for the disk test")
	server.rids._file = FileAccess.open(server.rids.path, FileAccess.READ)
	var first := await _req(r, "test.disk", {}, "rid-disk-0001")
	_check(first.get("ok") == true and not server.rids.is_open(), "a failed rid write closes the store (the op had applied, so its answer is still sent)")
	_check(_err(await _req(r, "test.disk", {}, "rid-disk-0002")) == "server_error" and applied[0] == 1, "later mutating ops fail closed instead of applying with no saved rid")
	_check((await _req(r, "test.disk", {}, "rid-disk-0001")).get("r", {}).get("n") == 1 and applied[0] == 1, "the rid whose write failed still replays in this process")
	_check((await _req(r, "sys.ping", {})).get("ok") == true, "reads still work while the store is closed")
	_check(server.rids.open(dir) == OK and (await _req(r, "test.disk", {}, "rid-disk-0003")).get("ok") == true, "a reopened store takes mutating ops again")
	r.ws.close()

## Godot runs no exit code on SIGTERM, so a killed server leaves a fresh lock behind.
func _test_lock_wait() -> void:
	var d := dir.path_join("locked")
	DirAccess.make_dir_recursive_absolute(d)
	_write(d.path_join(NetServer.LOCK_FILE), JSON.stringify({"pid": 1, "beat": Time.get_unix_time_from_system() - NetServer.LOCK_STALE + 2.0}))
	var s := NetServer.new()
	_add(s)
	_check(s.start(0, d, "127.0.0.1") == ERR_ALREADY_IN_USE, "a lock left by a killed server refuses a plain start()")
	var t0 := Time.get_ticks_msec()
	var err: Error = await s.start_when_free(0, d, "127.0.0.1")
	var waited := (Time.get_ticks_msec() - t0) / 1000.0
	_check(err == OK and waited >= 1.0 and waited < NetServer.LOCK_STALE, "start_when_free waits out a dead server's lock instead of failing (%.1f s)" % waited)
	s.stop()
	_check(not FileAccess.file_exists(d.path_join(NetServer.LOCK_FILE)), "a graceful stop removes the lock")

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

	var ch := alice.request("chat.send", {"text": "  hi\u0007 there\u202e  "})
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
	var ghost := alice.request("chat.send", {"text": _invisible()})
	await ghost.done
	_check(ghost.err == "bad_request", "chat that is only odd spaces, fillers and private-use characters is rejected")

	alice.disconnect_from_server()
	_check(await _until(func () -> bool: return puppets.puppet(aid) == null), "leaving removes the avatar")
	_check(heard.any(func (e: Array) -> bool: return e[0] == "presence_leave" and int(e[1].get("id", -1)) == aid), "the room gets evt presence_leave")

	# A private island is everyone's own home: same island id, different rooms.
	alice = _client("Alice", "tok_a.json")
	_check(await _until(func () -> bool: return alice.is_online()), "Alice is back")
	var tp2 := alice.request("presence.update", _state(Vector3(500, 1, 0)))
	await tp2.done
	_check(tp2.err == "bad_request" and tp2.msg.begins_with("moved too fast"), "reconnecting does not reset the teleport check")
	var ha := alice.request("presence.join", {"island": "home_grassland"})
	await ha.done
	var hb := bob.request("presence.join", {"island": "home_grassland"})
	await hb.done
	var mark := Time.get_ticks_msec()
	var hu := alice.request("presence.update", _state(Vector3(3, 1, 3), "idle", "home_grassland"))
	await hu.done
	await tree.create_timer(0.3).timeout
	_check(ha.ok and hb.ok and hu.ok and not heard.any(func (e: Array) -> bool: return e[2] >= mark and e[0] == "presence"), "players on their own home islands never see each other")
	var hop := alice.request("presence.update", _state(Vector3(500, 1, 0)))
	await hop.done
	_check(hop.err == "rate_limited", "hopping straight back to another island to dodge the speed check is refused")

## Area caps (contract §7, owner rule 2026-10-19): an island instance holds max_players_area
## players. A full one refuses a join with the reason and the next instance, rooms (presence and
## chat) are per instance, and the client's PresenceSender takes the instance it is offered.
func _test_area_caps() -> void:
	var pr := server.presence
	var cap := pr.max_players
	_check(cap == int(Data.world_rules.get("max_players_area", -1)) and cap > 0, "the area cap comes from rules.json max_players_area (%d)" % cap)
	pr.max_players = 2
	var area := "desert_35"
	var r1 := await _raw()
	var r2 := await _raw()
	var r3 := await _raw()
	_check(await _hello(r1, "Ivy") and await _hello(r2, "Jon") and await _hello(r3, "Kai"), "three players sign in for the area test")
	var j1 := await _req(r1, "presence.join", {"island": area})
	var j2 := await _req(r2, "presence.join", {"island": area})
	_check(j1.get("r", {}).get("instance") == 1 and j2.get("r", {}).get("instance") == 1 and j2.get("r", {}).get("max_players") == 2, "the first two players share instance 1 (%s)" % j2)
	_check((await _req(r1, "presence.update", _state(Vector3(4, 1, 4), "idle", area))).get("ok") == true, "Ivy stands in instance 1")
	var full := await _req(r3, "presence.join", {"island": area, "instance": 1})
	_check(_err(full) == "limit_reached" and full.get("r", {}).get("next_instance") == 2 and "instance 1 is full (2/2 players)" in str(full.get("msg")), "a full instance refuses a join with the reason and the next instance (%s)" % full)
	_check(_err(await _req(r3, "presence.join", {"island": area, "instance": 1.5})) == "bad_request" \
		and _err(await _req(r3, "presence.join", {"island": area, "instance": PresenceRooms.MAX_INSTANCES + 1})) == "bad_request", "a fractional or out-of-range instance is bad_request")
	var auto := await _req(r3, "presence.join", {"island": area})
	_check(auto.get("r", {}).get("instance") == 2 and auto.get("r", {}).get("players") == 1, "a join without an instance lands in the first one with room")
	_check((await _req(r3, "presence.update", _state(Vector3(6, 1, 6), "idle", area))).get("ok") == true, "Kai moves in instance 2")
	_check((await _req(r3, "chat.send", {"text": "only instance two"})).get("ok") == true, "Kai chats in instance 2")
	await tree.create_timer(0.3).timeout
	_check(not _evts(r1, "presence").any(func (d: Dictionary) -> bool: return d.get("players", []).any(func (p: Dictionary) -> bool: return int(p.get("id", -1)) == r3.account_id)) \
		and _evts(r1, "chat").is_empty(), "instance 1 neither sees nor hears instance 2")
	_check(_evts(r3, "chat").size() == 1, "the speaker's own instance hears the line")
	var hop := await _req(r2, "presence.join", {"island": area, "instance": 2})
	_check(hop.get("r", {}).get("instance") == 2 and _evts(r2, "presence_leave").any(func (d: Dictionary) -> bool: return int(d.get("id", -1)) == r1.account_id), "switching instance tells the player that the old roommates are gone")
	# The client: an instance that filled up while it was away offers the next, and the sender takes it.
	var lia := _client("Lia", "tok_l.json")
	_check(await _until(func () -> bool: return lia.is_online()), "Lia comes online")
	var sender := PresenceSender.new(lia)
	_add(sender)
	sender.instance = 2
	var back := lia.request("presence.join", {"island": area, "instance": 2})
	await back.done
	sender._on_join(back)
	_check(back.err == "limit_reached" and sender.instance == 1, "PresenceSender takes the next instance the server offers (instance %d)" % sender.instance)
	lia.disconnect_from_server()
	for r: Raw in [r1, r2, r3]:
		r.ws.close()
	pr.max_players = cap

## Sockets per IP: the cap holds at least a full area, so players behind one NAT all get on.
func _test_per_ip() -> void:
	_check(server.max_per_ip == int(Data.world_rules.get("max_connections_per_ip", -1)) and server.max_per_ip >= server.presence.max_players, "the per-IP cap comes from rules.json and holds a full area (%d)" % server.max_per_ip)
	var crowd: Array[NetClient] = []
	for i in 24:
		var c := NetClient.new()
		c.token_path = ""
		_add(c)
		c.connect_to(url, "Lan%02d" % i)
		crowd.append(c)
	var online := func () -> int: return crowd.filter(func (c: NetClient) -> bool: return c.is_online()).size()
	_check(await _until(func () -> bool: return online.call() == 24, 10.0), "24 clients from one IP all come online (%d did)" % online.call())
	for c in crowd:
		c.disconnect_from_server()

## Server-owned characters over the socket (contracts v2 §0.1, §0.3, §0.4): the hello makes the
## character, intents run on the server's copy at the position presence accepted, a rid applies
## once, server-only ops are unknown to clients, and the store reopens from disk.
func _test_characters() -> void:
	var r := await _raw()
	_check(await _hello(r, "Hana"), "Hana signs in")
	var me := await _req(r, "char.get", {})
	_check(me.get("ok") == true and me.get("r", {}).get("name") == "Hana" and me.get("r", {}).get("bag") is Array, "the hello made Hana's server-owned character (%s)" % _err(me))
	_check(_err(await _req(r, "char.import", {"save": {}}, "rid-import-01")) == "invalid_asset", "an offline save never imports into an online character")
	_check(_err(await _req(r, "char.wallet", {"wallet": 999999}, "rid-system-01")) == "bad_request" \
		and _err(await _req(r, "char.move", {"p": [20, 1, 0], "reset": true}, "rid-system-02")) == "bad_request", "server-only ops are unknown to clients")
	server.characters.world.add_node("net_rock", Vector3(20, 1, 0), [{"item": "stone", "tool": "none", "min": 2, "max": 2, "left": 10}], 1, "Rock")
	var gather := {"node_id": "net_rock", "option": 0}
	_check(_err(await _req(r, "act.gather", gather, "rid-gather-01")) == "out_of_range", "before presence puts her there, the rock is out of reach")
	_check((await _req(r, "presence.update", _state(Vector3(19, 1, 0), "idle", "tropical_25"))).get("ok") == true, "Hana walks up to the rock")
	var journal := dir.path_join("chars/journal.jsonl")
	var lines := FileAccess.get_file_as_string(journal).count("\n")
	_check(lines > 0 and (await _req(r, "char.get", {})).get("ok") == true and FileAccess.get_file_as_string(journal).count("\n") == lines, "char.get after a move writes no journal line (%d before)" % lines)
	var g := await _req(r, "act.gather", gather, "rid-gather-02")
	_check(g.get("ok") == true and g.get("r", {}).get("item") == "stone" and int(g.get("r", {}).get("gained", 0)) >= 2, "act.gather runs on the server's copy at the position presence accepted (%s)" % g)
	var again := await _req(r, "act.gather", gather, "rid-gather-02")
	var left := int(server.characters.world.nodes["net_rock"]["options"][0]["left"])
	_check(again.get("r") == g.get("r") and left == 9, "a repeated rid returns the first answer and gathers once (%d left)" % left)
	var bag: Array = (await _req(r, "char.get", {})).get("r", {}).get("bag", [])
	var stones := 0
	for row in bag:
		stones += int(row.get("count", 0)) if row is Dictionary and row.get("id") == "stone" else 0
	_check(stones == int(g.get("r", {}).get("gained", -1)), "the stone is in the server's bag (%d)" % stones)
	server.characters.close()
	_check(server.characters.open(dir) == "", "the character store reopens from disk")
	_check((await _req(r, "char.get", {})).get("r", {}).get("bag") == bag, "the bag survives the store restart")
	r.ws.close()

## The speed check itself, called directly with made-up account ids (events to them go nowhere).
func _test_presence_rules() -> void:
	var pr := server.presence
	var up := func (aid: int, p: Vector3) -> Dictionary: return pr.op_update(aid, _state(p, "idle", "tundra_30"))
	var a := 990001
	_check(up.call(a, Vector3(0, -15, 0)).ok, "a first update is accepted")
	_check(_err(up.call(a, Vector3(0, 99000, 0))) == "bad_request", "a vertical teleport far up is rejected")
	_check(_err(up.call(a, Vector3(0, -99000, 0))) == "bad_request", "a vertical teleport far down is rejected")
	_check(up.call(a, Vector3(0, 10, 0)).ok, "a 25 m climb fits the carried allowance")
	var climb: Dictionary = up.call(a, Vector3(0, 20, 0))
	_check(_err(climb) == "bad_request" and str(climb.get("msg")).begins_with("moved too fast"), "climbing counts against the speed check")
	_check(up.call(a, Vector3(0, -10, 0)).ok, "falling 20 m is free")
	# A stalled link hands over 40 updates at once, 0.7 m apart (running at 10 Hz).
	var b := 990002
	up.call(b, Vector3.ZERO)
	var bunched := 0
	for i in range(1, 41):
		bunched += 1 if up.call(b, Vector3(0.7 * i, 0, 0)).ok else 0
	_check(bunched == 40, "40 updates delivered together after a stall all pass (%d did)" % bunched)
	_check(_err(up.call(b, Vector3(35, 0, 0))) == "bad_request", "banked allowance is capped at %d s of running" % int(PresenceRooms.CARRY_S))
	pr._last[b]["spots"]["tundra_30"]["at"] -= 30.0  # 30 s without an update: the client kept running through a disconnect
	_check(up.call(b, Vector3(228, 0, 0)).ok, "running on through a long gap is not frozen out")
	# Island hops: A -> B -> A must not be a free teleport on A.
	var c := 990003
	var on := func (aid: int, p: Vector3, island: String) -> Dictionary: return pr.op_update(aid, _state(p, "idle", island))
	_check(on.call(c, Vector3.ZERO, "tundra_30").ok and on.call(c, Vector3(900, 0, 0), ISLAND).ok, "arriving on another island may start anywhere (travel resets the check)")
	pr._last[c]["hopped_at"] -= 5.0  # past the hop cooldown
	var back: Dictionary = on.call(c, Vector3(900, 0, 0), "tundra_30")
	_check(_err(back) == "bad_request" and str(back.get("msg")).begins_with("moved too fast"), "going back is checked against the spot left there (no A -> B -> A teleport)")
	_check(on.call(c, Vector3(5, 0, 0), "tundra_30").ok, "going back near that spot passes")
	pr.leave(a)
	pr.leave(b)
	pr.leave(c)

func _test_chat_clean() -> void:
	_check(NetChat.clean("ad" + char(0xAD) + "min") == "admin", "chat strips the soft hyphen")
	_check(NetChat.clean("a" + char(0x61C) + "b" + char(0xE0041) + "c" + char(0x2066) + "d") == "abcd", "chat strips every format character (U+061C, tags, isolates)")
	_check(NetChat.clean("a" + char(0x301).repeat(199)).length() == 1 + NetChat.MAX_MARKS, "stacked combining marks are capped")
	var real := "Olá, café, Tiếng Việt, naïve, 日本語 👍"
	_check(NetChat.clean(real) == real, "ordinary accented text, CJK and emoji are untouched")
	_check(NetChat.clean(" " + _invisible() + " ") == "", "odd spaces, Hangul fillers, braille blanks and private-use characters leave nothing")
	_check(NetChat.clean(char(0x301) + char(0x34F) + char(0xFE0F)) == "", "a line of only combining marks leaves nothing")
	_check(NetChat.clean(char(0x3000) + "hi" + char(0xA0) + "there" + char(0x3164)) == "hi there", "odd spaces are trimmed at the edges and read as spaces inside")

# ---------------------------------------------------------------- persistence and cleanup

func _test_store_reload() -> void:
	var store := AccountStore.new()
	_check(store.open(dir) == OK and store.count() == server.accounts.count() and store.name_of(alice.account_id) == "Alice", "accounts reload from disk")
	var bad := dir.path_join("corrupt")
	DirAccess.make_dir_recursive_absolute(bad)
	_write(bad.path_join(AccountStore.FILE), "{oops")
	_check(AccountStore.new().open(bad) == ERR_FILE_CORRUPT, "a corrupt account file refuses to open instead of starting empty")
	var good := JSON.stringify({"acc": 5, "rid": "rid-torn-0001", "op": "test.x", "res": {"ok": true, "r": {}}})
	_write(bad.path_join(RidStore.FILE), good + "\n" + good.substr(0, 20))
	var rs := RidStore.new()
	_check(rs.open(bad) == OK and rs.count(5) == 1, "a torn last rid line is dropped and the rest reload")
	rs.close()
	_write(bad.path_join(RidStore.FILE), "{oops\n" + good + "\n")
	_check(RidStore.new().open(bad) == ERR_FILE_CORRUPT, "a bad rid line mid-file refuses to open")

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

## The d of every evt ev that reached r so far (consumed).
func _evts(r: Raw, ev: String) -> Array:
	_pump(r)
	var out: Array = []
	for m in r.got:
		if m is Dictionary and m.get("t") == "evt" and m.get("ev") == ev:
			out.append(m.get("d", {}))
	r.got = r.got.filter(func (m: Variant) -> bool: return not (m is Dictionary and m.get("t") == "evt" and m.get("ev") == ev))
	return out

static func _err(res: Dictionary) -> String:
	return str(res.get("err", "")) if res.get("ok") == false else ("" if res.get("ok") == true else "no answer")

static func _count(results: Array, err: String) -> int:
	return results.filter(func (m: Dictionary) -> bool: return _err(m) == err).size()

static func _state(p: Vector3, anim: String = "idle", island: String = ISLAND) -> Dictionary:
	return {"p": [p.x, p.y, p.z], "yaw": 0.25, "anim": anim, "island": island}

## Characters that draw nothing: NBSP, ideographic and em space, Hangul fillers, braille blank, private use.
static func _invisible() -> String:
	return char(0xA0) + char(0x3000) + char(0x2003) + char(0x3164) + char(0xFFA0) + char(0x115F) + char(0x1160) + char(0x2800) + char(0xE000)

func _token_entry(file: String) -> Dictionary:
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	return all.get(url, {}) if all is Dictionary and all.get(url) is Dictionary else {}

static func _lost_keys(e: Dictionary) -> Array:
	return (e.get("lost", []) as Array).map(func (row: Variant) -> String: return str(row.get("token", "")) if row is Dictionary else "")

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

## test.crashy: applies, and with {crash: true} drops the caller before the answer is sent.
static func _crashy(srv: NetServer, applied: Array) -> Callable:
	return func (aid: int, a: Dictionary) -> Dictionary:
		applied[0] += 1
		if a.get("crash") == true:
			srv._drop(srv._by_account[aid], 4006, "test crash", srv.mono())
		return NetProtocol.ok({"n": applied[0]})

static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _rm_rf(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for sub in da.get_directories():
		_rm_rf(path.path_join(sub))
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(path)
