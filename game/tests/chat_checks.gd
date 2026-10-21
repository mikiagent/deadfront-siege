extends RefCounted
## Region chat (spec 20) over real localhost sockets: one NetServer and two real NetClients in this
## process exchange region lines; each has its own ChatLog, and Bob's ChatScreen is laid out on the
## 844x390 phone canvas and the 1600x900 desktop. t_chat.gd loads this once the autoloads exist.
## Every wait is bounded, so a regression fails instead of hanging.

const ISLAND := "temperate_25"
const HOSTILE := "[b]bold[/b] [url=https://evil.example]tap[/url] [img]res://icon.svg[/img] %s {0} [color=red]x"

var tree: SceneTree
var expect: Callable
var server: NetServer
var url := ""
var dir := ""
var alice: NetClient
var bob: NetClient
var alice_log: ChatLog
var bob_log: ChatLog
var _nodes: Array[Node] = []

func run(p_tree: SceneTree, p_expect: Callable) -> void:
	tree = p_tree
	expect = p_expect
	_test_format()
	await _test_offline()
	dir = OS.get_user_data_dir().path_join("test_chat_%d" % Time.get_ticks_usec())
	server = NetServer.new()
	server.new_accounts_per_hour = 1000.0
	_add(server)
	var err := server.start(0, dir, "127.0.0.1")
	_check(err == OK and server.port > 0, "server listens on a free localhost port")
	if err == OK:
		url = "ws://127.0.0.1:%d" % server.port
		await _test_two_clients()
		await _test_layout()
		await _test_wide_line()
		await _test_overlay_and_hud()
		await _test_many_lines()
		await _test_held_enter()
		await _test_disconnect()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	await tree.process_frame
	_rm_rf(dir)

# ---------------------------------------------------------------- pure

func _test_format() -> void:
	_check(ChatLog.ago(1000.0 - 5280.0, 1000.0) == "1h 28m ago", "5280 s reads \"1h 28m ago\" (got \"%s\")" % ChatLog.ago(-4280.0, 1000.0))
	_check(ChatLog.ago(970.0, 1000.0) == "just now", "30 s reads \"just now\"")
	_check(ChatLog.ago(700.0, 1000.0) == "5m ago", "300 s reads \"5m ago\"")
	_check(ChatLog.ago(1000.0 - 2.0 * 86400.0 - 60.0, 1000.0) == "2d ago", "two days read \"2d ago\"")
	_check(ChatLog.ago(1060.0, 1000.0) == "just now", "a line from a clock ahead never reads negative")
	var a := {"from": "Ann", "id": 1, "text": "a", "ts": 0.0}
	var b := {"from": "Ben", "id": 2, "text": "b", "ts": 0.0}
	var s := {"from": "", "id": -1, "text": "s", "ts": 0.0}
	_check(ChatLog.stacks(a, a) and not ChatLog.stacks(a, b) and not ChatLog.stacks(b, a),
		"consecutive lines from one sender stack under one name, another sender starts a new block")
	_check(not ChatLog.stacks(s, s), "System lines never stack")

# ---------------------------------------------------------------- offline (no server)

func _test_offline() -> void:
	var net := NetClient.new()
	net.token_path = ""
	_add(net)
	var feed := ChatLog.new(net)
	var screen := _screen(feed, Vector2(844, 390))
	await _frames(2)
	_check(not feed.online() and _banner(screen).begins_with("Offline. Region chat needs the island server"), "Region says it is offline without a server (\"%s\")" % _banner(screen))
	var field := screen.find_child("Field", true, false) as LineEdit
	var send := screen.find_child("Send", true, false) as Button
	_check(not field.editable and send.disabled and (screen.find_child("Plus", true, false) as Button).disabled, "offline: the field, + and Send are disabled")
	feed.system("Bag is full.")
	feed.system("Bag is full.")  # a repeat refreshes the line instead of stacking a copy
	screen.select(ChatLog.SYSTEM)
	await _frames(2)
	var texts := _texts(screen)
	_check(feed.lines[ChatLog.SYSTEM].size() == 1 and texts.size() == 1 and texts[0].begins_with("Bag is full.") and texts[0].ends_with("just now"),
		"System works offline: the notice shows with its time, once (%s)" % [texts])
	_check(_banner(screen) == "" and not field.editable, "System shows no offline banner and is read-only")
	var ch := screen.find_child("Channel_system", true, false) as Button
	_check(ch.get_theme_color("font_color") == ChatScreen.GOLD and (screen.find_child("Channel_region", true, false) as Button).get_theme_color("font_color") == ChatScreen.TEXT, "the selected channel is gold, the other white")
	(screen.get_parent() as Node).queue_free()

# ---------------------------------------------------------------- two clients

func _test_two_clients() -> void:
	alice = _client("Alice", "tok_a.json")
	bob = _client("Bob", "tok_b.json")
	alice_log = ChatLog.new(alice)
	bob_log = ChatLog.new(bob)
	_check(await _until(func () -> bool: return alice.is_online() and bob.is_online()), "two clients come online")
	var screen := _screen(bob_log, Vector2(844, 390))
	screen.name = "BobScreen"
	var early := alice_log.send("anyone?")
	await early.done
	_check(not early.ok and early.msg.contains("join an island"), "a line before joining an island is refused with the reason (%s)" % early.msg)
	await _frames(1)
	var ja := alice.request("presence.join", {"island": ISLAND})
	var jb := bob.request("presence.join", {"island": ISLAND})
	await ja.done
	await jb.done
	_check(ja.ok and jb.ok, "both join the same island room")
	var hi := alice_log.send("hi bob")
	await hi.done
	_check(hi.ok, "Alice's line is accepted")
	_check(await _until(func () -> bool: return _last(bob_log)["text"] == "hi bob"), "Bob's log gets Alice's line")
	_check(_last(bob_log)["from"] == "Alice" and _last(bob_log)["id"] == alice.account_id, "the line names Alice and her account")
	_check(await _until(func () -> bool: return _last(alice_log)["text"] == "hi bob"), "Alice sees her own line (the server's echo)")
	var sk := bob_log.send(":skull:")
	await sk.done
	_check(await _until(func () -> bool: return _last(alice_log)["text"] == ":skull:"), "Alice gets Bob's sticker")
	for t in ["two in a row", HOSTILE]:
		var r := alice_log.send(t)
		await r.done
		_check(r.ok, "Alice's line \"%s\" is accepted" % t.left(12))
	_check(await _until(func () -> bool: return bob_log.lines[ChatLog.REGION].size() == 4), "Bob has four region lines")
	screen.open(ChatLog.REGION)
	await _frames(3)
	var rows := screen.find_child("Lines", true, false).get_child(0).get_children()
	_check(rows.size() == 3, "three blocks: Alice, Bob, Alice x2 (got %d)" % rows.size())
	if rows.size() == 3:
		var names := _names(rows[2])
		_check(names == ["Alice"] and _texts(rows[2]).size() == 2 and rows[2].find_child("Sticker", true, false) == null, "Alice's two lines in a row stack under one name")
		_check(rows[1].find_child("Sticker", true, false) is ChatEmotes.Sticker and _names(rows[1]) == ["Bob"], "Bob's :skull: shows as a sticker under his name")
		var n := rows[0].find_child("Name", true, false) as RichTextLabel
		_check(n != null and n.get_theme_color("default_color") == ChatScreen.GOLD, "sender names are gold")
		var t := rows[0].find_child("Text", true, false) as Control
		_check(n != null and t != null and is_equal_approx(n.get_global_rect().position.y, t.get_global_rect().position.y) and is_equal_approx(n.size.y, t.size.y),
			"a name and its first line share one baseline (name %s, text %s)" % [n.get_global_rect() if n else Rect2(), t.get_global_rect() if t else Rect2()])
		var tint0 := ((rows[0] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).bg_color
		var tint1 := ((rows[1] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).bg_color
		_check(tint0 != tint1, "rows alternate tints")
	# Hostile text: the line arrives as typed and draws as plain text, never markup.
	var shown := _texts(screen)
	var hostile := shown.filter(func (t: String) -> bool: return t.begins_with(HOSTILE))
	_check(hostile.size() == 1 and hostile[0] == HOSTILE + "   just now", "hostile markup renders literally (%s)" % [hostile])
	var rtls := _all(screen, "RichTextLabel")
	_check(not rtls.is_empty() and rtls.all(func (r: RichTextLabel) -> bool: return not r.bbcode_enabled), "lines are RichTextLabels with BBCode off")
	# A hostile or broken server: fields are checked and cleaned again on the client.
	var before: int = bob_log.lines[ChatLog.REGION].size()
	for bad: Dictionary in [{"id": "7", "text": "x"}, {"id": 7, "text": 5}, {"id": 1.5, "text": "x"}, {"id": -3, "text": "x"},
			{"id": 7, "text": "x".repeat(NetChat.MAX_RAW + 1)}, {"id": 7, "text": "\u200b\u0007 "}]:
		bob.event.emit("chat", bad)
	_check(bob_log.lines[ChatLog.REGION].size() == before, "malformed or blank evt chat is dropped")
	bob.event.emit("chat", {"id": 77, "from": "[b]Mal[/b]\u202e", "text": "[url=x]click[/url]\u200b\u0007", "ts": bob_log.now() - 5280.0})
	await _frames(2)
	var m: Dictionary = _last(bob_log)
	_check(m["from"] == "[b]Mal[/b]" and m["text"] == "[url=x]click[/url]", "a server's control and bidi characters are stripped (%s)" % [m])
	var last_row: Node = screen.find_child("Lines", true, false).get_child(0).get_children()[-1]
	_check(_names(last_row) == ["[b]Mal[/b]"] and _texts(last_row) == ["[url=x]click[/url]   1h 28m ago"], "the old line shows its relative time and literal name (%s %s)" % [_names(last_row), _texts(last_row)])
	bob.event.emit("chat", {"id": 77, "from": "Mallory", "text": "from the future", "ts": bob_log.now() + 9999.0})
	_check(float(_last(bob_log)["ts"]) <= bob_log.now(), "a line stamped in the future is clamped to now")

# ---------------------------------------------------------------- layout

func _test_layout() -> void:
	var screen := tree.root.find_child("BobScreen", true, false) as ChatScreen
	if screen == null:
		_check(false, "Bob's screen exists")
		return
	(screen.find_child("Plus", true, false) as Button).pressed.emit()
	await _frames(2)
	_check((screen.find_child("Stickers", true, false) as Control).visible, "+ opens the sticker picker")
	for view in [Vector2(844, 390), Vector2(1600, 900)]:
		(screen.get_parent() as Control).size = view
		await _frames(3)
		var small := []
		for c in _all(screen, "BaseButton") + _all(screen, "LineEdit"):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and (ctl.size.y < 44.0 or ctl.size.x < 44.0):
				small.append("%s %s" % [ctl.name, ctl.size])
		_check(small.is_empty(), "every target is 44 px or more at %s (%s)" % [view, small])
		var box := Rect2(Vector2.ZERO, view)
		var out := []
		var lines := screen.find_child("Lines", true, false)
		for c in _all(screen, "Control"):
			var ctl := c as Control
			if lines.is_ancestor_of(ctl):
				continue  # rows scroll inside the clipped list
			var r := Rect2(ctl.get_global_rect().position - screen.global_position, ctl.size)
			if ctl.is_visible_in_tree() and r.has_area() and not box.grow(0.5).encloses(r):
				out.append("%s %s" % [ctl.name, r])
		_check(out.is_empty(), "everything stays inside %s (%s)" % [view, out.slice(0, 4)])
	# A tap on a sticker sends it and closes the picker.
	(screen.find_child("Sticker_heart", true, false) as Button).pressed.emit()
	_check(await _until(func () -> bool: return _last(alice_log)["text"] == ":heart:"), "a picked sticker reaches Alice")
	_check(not (screen.find_child("Stickers", true, false) as Control).visible, "the picker closes after a pick")
	# The on-screen keyboard: the input bar rides above it.
	(screen.get_parent() as Control).size = Vector2(844, 390)
	screen.keyboard_override = 200.0
	await _frames(3)
	var bar := (screen.find_child("InputBar", true, false) as Control).get_global_rect()
	_check(bar.end.y - screen.global_position.y <= 390.0 - 200.0 + 0.5, "the input bar sits above a 200 px keyboard (bottom %.0f)" % (bar.end.y - screen.global_position.y))
	screen.keyboard_override = 0.0
	await _frames(2)
	bar = (screen.find_child("InputBar", true, false) as Control).get_global_rect()
	_check(bar.end.y - screen.global_position.y > 370.0, "and drops back when the keyboard goes")

# ---------------------------------------------------------------- HUD

func _test_overlay_and_hud() -> void:
	var box := _box(Vector2(844, 390))
	var hud := HuntHud.new()
	box.add_child(hud)
	await _frames(1)
	var hooked: Variant = hud.get("chat")
	var menu := hud.get("_menu_hex") as HexButton
	if hooked == null:
		print("[t_chat] note: hunt_hud.gd has no chat hook (claude-mmo-chat-hooks.patch not applied); HUD feed checks skipped")
	else:
		_check(hooked is ChatHud, "HuntHud.chat is the ChatHud")
		var hh := hooked as ChatHud
		var skills := hud.get("_skills_hex") as HexButton
		_check(hh.hex.caption == "CHAT" and is_equal_approx(hh.hex.position.y, menu.position.y) and hh.hex.position.x > skills.position.x,
			"the CHAT hex sits in the menu row after SKILLS (%s)" % hh.hex.position)
		hud.notice("Storage is full.")
		_check(_last(hh.feed, ChatLog.SYSTEM).get("text") == "Storage is full.", "a HUD notice becomes a System line")
		hud.call("_on_level_up", 4)
		_check(str(_last(hh.feed, ChatLog.SYSTEM).get("text")).begins_with("Level up: Lv. 5"), "a level-up becomes a System line (%s)" % _last(hh.feed, ChatLog.SYSTEM).get("text"))
		hh.hex.pressed.emit()
		await _frames(2)
		_check(hh.screen != null and hh.screen.visible, "the CHAT hex opens the chat screen")
		hh.screen.close()
		hh.hex.visible = false  # the overlay below is the test's own ChatHud, on Bob's connection
	var chat := ChatHud.attach(hud, bob)
	chat.hex.position = menu.position + Vector2(4.0 * (HuntHud.HEX + 10.0), 0.0)  # where the hook's _layout puts it
	World.island_changed.emit(&"temperate_25")
	_check(str(_last(chat.feed, ChatLog.SYSTEM).get("text")).begins_with("Arrived at "), "an island arrival becomes a System line")
	var r := alice_log.send("overlay line")
	await r.done
	_check(await _until(func () -> bool: return chat.visible), "a fresh region line shows the overlay")
	var fresh := chat.fresh()
	_check(fresh.size() <= ChatHud.LINES and fresh[-1]["text"] == "overlay line", "the overlay holds the newest %d region lines, newest last" % ChatHud.LINES)
	_check(chat.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the overlay never takes a tap")
	var view := Rect2(Vector2.ZERO, chat.get_viewport_rect().size)
	_check(view.encloses(Rect2(chat.position, chat.size)) and chat.position.y + chat.size.y <= chat.hex.position.y, "the overlay stands inside the view, over the hex row (%s)" % Rect2(chat.position, chat.size))
	chat.open()
	await _frames(1)
	_check(not chat.visible, "the overlay hides while the chat screen is open")
	(chat.screen.find_child("Eye", true, false) as Button).pressed.emit()
	chat.screen.close()
	await _frames(1)
	_check(not chat.overlay_on and not chat.visible, "the eye turns the overlay off")
	chat.open()
	(chat.screen.find_child("Eye", true, false) as Button).pressed.emit()
	(chat.screen.find_child("Close", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(chat.overlay_on and chat.visible and not chat.screen.visible, "the eye turns it back on; the X closes the screen")
	chat.feed.lines[ChatLog.REGION].clear()
	await _frames(1)
	_check(not chat.visible, "no fresh lines, no overlay")
	box.queue_free()

## U+FDFD is one of the widest glyphs there is: 200 of them stood one row 1419 px tall at 844x390.
func _test_wide_line() -> void:
	var screen := tree.root.find_child("BobScreen", true, false) as ChatScreen
	var latin := "Meet at the north harbour at dusk, bring rope, two spears and the big raft. ".repeat(3).left(NetChat.MAX_LEN).strip_edges()
	bob.event.emit("chat", {"id": 81, "from": "Wren", "text": latin, "ts": bob_log.now()})
	bob.event.emit("chat", {"id": 82, "from": "Vex", "text": "\uFDFD".repeat(NetChat.MAX_LEN), "ts": bob_log.now()})
	await _frames(3)
	var rows := screen.find_child("Lines", true, false).get_child(0).get_children()
	var wide := rows[-1] as Control
	print("[t_chat] info: widest-glyph row %.0f px tall, %.0f wide" % [wide.size.y, wide.size.x])
	_check(wide.size.y <= 300.0, "a line of 200 of the widest glyphs stays a few rows tall at 844x390 (%.0f px)" % wide.size.y)
	_check(_texts(wide)[0].ends_with("…   just now") and _texts(rows[-2])[0] == latin + "   just now", "it ends in an ellipsis; 200 ordinary characters show in full")

## A new line makes one row (or joins the last) and leaves every other row alone; a closed screen
## does nothing until it opens. Before, each line made all 100 rows again (24-34 ms a line).
func _test_many_lines() -> void:
	var screen := tree.root.find_child("BobScreen", true, false) as ChatScreen
	screen.open(ChatLog.REGION)
	await _frames(2)
	var list := screen.find_child("Lines", true, false).get_child(0)
	var added := [0]
	var count := func (_n: Node) -> void: added[0] += 1
	tree.node_added.connect(count)
	var t0 := Time.get_ticks_usec()
	var emit_us := 0
	for i in 300:
		var e0 := Time.get_ticks_usec()
		bob.event.emit("chat", {"id": 900 + i % 2, "from": "Ann" if i % 2 == 0 else "Ben", "text": "line %d" % i, "ts": bob_log.now()})
		emit_us += Time.get_ticks_usec() - e0
		await tree.process_frame
	var open_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	await _frames(300)
	var idle_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var per_line := float(added[0]) / 300.0
	_check(per_line <= 12.0, "a new line adds one row's nodes, not every row's (%.1f nodes a line)" % per_line)
	_check(list.get_child_count() == ChatLog.MAX_LINES and _texts(list.get_child(list.get_child_count() - 1))[0].begins_with("line 299"),
		"the list keeps the newest %d lines, newest at the bottom (%d rows)" % [ChatLog.MAX_LINES, list.get_child_count()])
	var ids := list.get_children().map(func (c: Node) -> int: return c.get_instance_id())
	added[0] = 0
	bob.event.emit("chat", {"id": 901, "from": "Ben", "text": "one more", "ts": bob_log.now()})
	await tree.process_frame
	var kept := list.get_children().map(func (c: Node) -> int: return c.get_instance_id())
	_check(added[0] <= 3 and kept == ids.slice(1), "a line from the last sender joins his row; the other rows are the same nodes (%d nodes added)" % added[0])
	screen.close()
	added[0] = 0
	t0 = Time.get_ticks_usec()
	for i in 100:
		bob.event.emit("chat", {"id": 902, "from": "Cy", "text": "closed %d" % i, "ts": bob_log.now()})
	var closed_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(added[0] == 0 and list.get_children().map(func (c: Node) -> int: return c.get_instance_id()) == kept, "a closed screen does no work for new lines (%d nodes added)" % added[0])
	tree.node_added.disconnect(count)
	screen.open()
	await _frames(2)
	var last := list.get_child(list.get_child_count() - 1)
	_check(_names(last) == ["Cy"] and _texts(last).size() == ChatLog.MAX_LINES and _texts(last)[-1].begins_with("closed 99"), "opening it catches the rows up once")
	print("[t_chat] info: 300 lines while open: %.1f nodes and %.3f ms a line handling them, %.2f ms a frame with a line vs %.2f without; 100 while closed %.2f ms" % [per_line, emit_us / 300000.0, open_ms / 300.0, idle_ms / 300.0, closed_ms])

## Holding Enter after "slow down": every refusal from the server counts toward its flood cut-off,
## which dropped the connection twice in 6 s. The client keeps under the server's chat rate.
func _test_held_enter() -> void:
	var screen := tree.root.find_child("BobScreen", true, false) as ChatScreen
	screen.open(ChatLog.REGION)
	var field := screen.find_child("Field", true, false) as LineEdit
	var states: Array = []
	var rec := func (st: int) -> void: states.append(st)
	bob.state_changed.connect(rec)
	var spam := func () -> int: return (alice_log.lines[ChatLog.REGION] as Array).filter(func (l: Dictionary) -> bool: return l["text"] == "spam").size()
	var before: int = spam.call()
	var presses := 0
	var told := false
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		field.text = "spam"
		field.text_submitted.emit(field.text)
		presses += 1
		await tree.process_frame
		told = told or _banner(screen) == "Not sent: slow down"
	field.clear()
	await _until(func () -> bool: return false, 0.5)  # answers still on the way
	bob.state_changed.disconnect(rec)
	var got: int = spam.call() - before
	_check(states.is_empty() and bob.is_online(), "holding Enter for 3 s (%d presses) never drops the connection (states %s)" % [presses, states])
	var burst: float = NetServer.RATE_CLASSES["chat"][1]
	_check(got >= 1 and got <= int(burst) + 4, "the lines that go out keep to the server's chat rate (%d sent)" % got)
	_check(told, "the screen says \"Not sent: slow down\"")

func _test_disconnect() -> void:
	var screen := tree.root.find_child("BobScreen", true, false) as ChatScreen
	bob.disconnect_from_server()
	await _frames(2)
	_check(_banner(screen).begins_with("Offline.") and not bob_log.lines[ChatLog.REGION].is_empty(), "after a disconnect Region keeps its lines and says it is offline")

# ---------------------------------------------------------------- helpers

func _check(ok: bool, msg: String) -> void:
	expect.call(ok, "chat: %s" % msg)

func _add(n: Node) -> void:
	tree.root.add_child(n)
	_nodes.append(n)

func _box(view: Vector2) -> Control:
	var box := Control.new()
	box.size = view
	_add(box)
	return box

func _screen(feed: ChatLog, view: Vector2) -> ChatScreen:
	var s := ChatScreen.new(feed)
	_box(view).add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return s

func _client(nm: String, token_file: String) -> NetClient:
	var c := NetClient.new()
	c.token_path = dir.path_join(token_file)
	_add(c)
	c.connect_to(url, nm)
	return c

func _last(feed: ChatLog, ch: StringName = ChatLog.REGION) -> Dictionary:
	var rows: Array = feed.lines[ch]
	return rows[-1] if not rows.is_empty() else {"text": null, "from": null, "id": null}

func _banner(n: Node) -> String:
	var b := n.find_child("Banner", true, false) as RichTextLabel
	return b.get_parsed_text() if b else ""

func _texts(n: Node) -> Array:
	return _all(n, "RichTextLabel").filter(func (r: RichTextLabel) -> bool: return r.name != "Name" and r.name != "Banner").map(func (r: RichTextLabel) -> String: return r.get_parsed_text())

func _names(n: Node) -> Array:
	return _all(n, "RichTextLabel").filter(func (l: RichTextLabel) -> bool: return l.name == "Name").map(func (l: RichTextLabel) -> String: return l.get_parsed_text())

func _all(n: Node, cls: String) -> Array:
	var out: Array = []
	for c in n.find_children("*", cls, true, false):
		out.append(c)
	return out

func _frames(k: int) -> void:
	for i in k:
		await tree.process_frame

func _until(cond: Callable, timeout: float = 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await tree.process_frame
	return true

func _rm_rf(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for sub in da.get_directories():
		_rm_rf(path.path_join(sub))
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(path)
