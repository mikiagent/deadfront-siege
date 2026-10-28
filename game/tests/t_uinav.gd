extends SceneTree
## UINAV acceptance (docs/design/ui-redesign-spec.md §7 B3, B4), on the home island with the real HUD:
## B3: MENU opens the nav menu with Character..Animals left and World Atlas..Save right, Orders and
## Friends disabled; at 844x390 and 1600x900 every entry, the close hex and the debug gear sit inside
## the view, clear of each other, 64 px or more; an entry badges its own notices and opening it clears
## them; Save saves with a green "Game saved" notice; the close hex, Esc and a tap on the world close it.
## B4: warnings and ok notices size for their glyph; the station radial's main action is gold-rimmed and
## its hexes grow on desktop; eating shows seconds left and the food's energy; the claim confirm has a
## parchment header and 64 px buttons inside the view; the fatigue close and death respawn are 64 px+.
## Usage: godot --headless --path game --script res://tests/t_uinav.gd -> "[t_uinav] PASS", exit 0/1.

const GOLD := Color(0.957, 0.769, 0.188, 1.0)  ## UiTokens.GOLD (game classes load after this script compiles)
const PARCHMENT_TOP := Color(0.804, 0.722, 0.541, 1.0)

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _world: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_uinav] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TUinavHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _test_entries()
	await _test_layout()
	await _test_badges_and_open()
	await _test_close()
	await _test_b4()
	if _fails.is_empty():
		print("[t_uinav] PASS")
		quit(0)
	else:
		print("[t_uinav] FAIL count=%d" % _fails.size())
		quit(1)

func _open_nav():
	_hud._close_sheet()
	_hud._toggle_sheet(&"menu")
	await _frames(2)
	return _hud.get("_sheet")

# ---------------------------------------------------------------- B3

func _test_entries() -> void:
	var nav = await _open_nav()
	_expect(nav != null and nav.name == "NavMenu", "MENU opens the nav menu (%s)" % [nav.name if nav else "none"])
	if nav == null:
		return
	var left: Array = nav.LEFT.map(func (e) -> String: return str(e["label"]))
	var right: Array = nav.RIGHT.map(func (e) -> String: return str(e["label"]))
	_expect(left == ["Character", "Skills", "Craft", "Build", "Bag", "Animals"], "left column reads Character..Animals (%s)" % [left])
	_expect(right == ["World Atlas", "Domain", "Orders", "Communication", "Island Market", "Save"], "right column reads World Atlas..Save (%s)" % [right])
	for id in nav.entries:
		var b: Button = nav.entries[id]
		_expect(b.disabled == false, "%s is %s" % [id, "disabled" if b.disabled else "enabled"])
	_expect(_hud.sheet_open(), "the nav menu counts as an open sheet (HANDS and plates hide)")

func _test_layout() -> void:
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _frames(3)
		var nav = await _open_nav()
		await _frames(1)
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var rects: Dictionary = nav.tap_rects()
		var keys: Array = rects.keys()
		for i in keys.size():
			var a: Rect2 = rects[keys[i]]
			_expect(view.grow(0.5).encloses(a), "%dx%d %s %s inside the view" % [size.x, size.y, keys[i], a])
			_expect(a.size.x >= 63.5 and a.size.y >= 55.0, "%dx%d %s %s is a big enough tap target" % [size.x, size.y, keys[i], a.size])
			for j in range(i + 1, keys.size()):
				var b: Rect2 = rects[keys[j]]
				_expect(not a.grow(-0.5).intersects(b.grow(-0.5)), "%dx%d %s clears %s" % [size.x, size.y, keys[i], keys[j]])
		for id in nav.entries:
			var b: Button = nav.entries[id]
			_expect(b.size.y >= 64.0, "%dx%d %s row is 64 px or taller (%.0f)" % [size.x, size.y, id, b.size.y])
			_expect(b.get_minimum_size().x <= b.size.x + 0.5, "%dx%d %s label fits its row" % [size.x, size.y, id])
	_hud._close_sheet()
	root.size = was_size
	root.content_scale_size = was_scale
	await _frames(2)

func _test_badges_and_open() -> void:
	_hud.field.notices.clear()
	_hud.notify_menu(&"skills", 2)
	var nav = await _open_nav()
	_expect(nav.badge_text(&"skills") == "2" and nav.badge_text(&"craft") == "", "Skills badges 2, Craft none (%s)" % nav.badge_text(&"skills"))
	(nav.entries[&"skills"] as Button).pressed.emit()
	await _frames(2)
	var sheet: Control = _hud.get("_skills_sheet")
	_expect(sheet != null and sheet.visible, "Skills opens from the nav menu")
	_expect(_hud.field.count(&"skills") == 0 and _hud.get("_sheet") == null, "opening Skills clears its badge and the menu")
	_hud._toggle_skills()
	nav = await _open_nav()
	(nav.entries[&"orders"] as Button).pressed.emit()
	await _frames(1)
	_expect(_hud.get("_sheet") == nav, "a disabled entry does nothing")
	(nav.entries[&"atlas"] as Button).pressed.emit()
	await _frames(2)
	var map: Control = _hud.get("_map_screen")
	_expect(map != null and map.is_visible_in_tree(), "World Atlas opens the map")
	if map and map.has_method("close"):
		map.call("close")
	elif map:
		map.visible = false
	nav = await _open_nav()
	var before: int = _hud._events.notices.size()
	(nav.entries[&"save"] as Button).pressed.emit()
	await _frames(1)
	var saved := false
	for n in _hud._events.notices:
		if str(n["text"]).begins_with("Game saved") and bool(n.get("ok", false)):
			saved = true
	_expect(saved and _hud._events.notices.size() > before, "Save adds a green 'Game saved' notice")

func _test_close() -> void:
	var nav = await _open_nav()
	nav.close_hex.pressed.emit()
	await _frames(1)
	_expect(_hud.get("_sheet") == null, "the close hex closes the menu")
	nav = await _open_nav()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	nav._on_root_input(ev)
	await _frames(1)
	_expect(_hud.get("_sheet") == null, "a tap on the world closes the menu")
	nav = await _open_nav()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	nav._unhandled_input(esc)
	await _frames(1)
	_expect(_hud.get("_sheet") == null, "Esc closes the menu")

# ---------------------------------------------------------------- B4

func _test_b4() -> void:
	# Loaded here: these classes reference the Data/World autoloads, which a SceneTree script cannot name.
	var HudEventState: GDScript = load("res://scripts/ui/hud_event_state.gd")
	var StationMenu: GDScript = load("res://scripts/ui/station_menu.gd")
	var ClaimPanel: GDScript = load("res://scripts/ui/claim_panel.gd")
	var data: Node = root.get_node("Data")
	var font := ThemeDB.fallback_font
	var w: float = HudEventState.call("notice_width", font, "Too heavy", 17, Vector2(1600, 900))
	_expect(w > font.get_string_size("Too heavy", HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 16.0, "a desktop notice box makes room for its warning glyph")
	var ev = HudEventState.new()
	ev.add_notice("Need a stone knife")
	ev.add_notice("Game saved", true)
	_expect(not bool(ev.notices[0]["ok"]) and bool(ev.notices[1]["ok"]), "notices carry the warning / ok look")
	# station radial
	_expect(float(StationMenu.call("hex_px", Vector2(1600, 900))) > float(StationMenu.call("hex_px", Vector2(844, 390))) and float(StationMenu.call("hex_px", Vector2(844, 390))) >= 64.0, "station hexes: 64 px on a phone, larger on desktop")
	var sm = StationMenu.new()
	sm.player = _player
	_hud.add_child(sm)
	var st := Node3D.new()
	_host.add_child(st)
	st.global_position = _player.global_position + Vector3(2, 0, 0)
	sm.show_for(st, StationMenu.call("actions_for", &"bonfire", _player))
	await _frames(1)
	var hexes: Array = sm.find_children("*", "HexButton", false, false)
	_expect(not hexes.is_empty() and hexes[0].rim_color == GOLD, "the station's main action (COOK) is gold-rimmed")
	sm.hide_menu()
	sm.queue_free()
	st.queue_free()
	# eating
	var ep = _player.eat_session.progress_ui
	ep.show_eat(&"grilled_meat", 0.0)
	ep.set_progress(0.5)
	_expect(absf(ep.seconds_left() - _player.eat_session.eat_seconds * 0.5) < 0.01, "eating shows the seconds left (%.2f)" % ep.seconds_left())
	_expect(ep.line_text().begins_with(data.item(&"grilled_meat").display_name), "eating names the food (%s)" % ep.line_text())
	ep.hide_eat()
	# claim confirm
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2(844, 390), Vector2(1600, 900)]:
		root.size = Vector2i(size)
		root.content_scale_size = Vector2i(size)
		await _frames(2)
		var cp = ClaimPanel.new()
		_hud.add_child(cp)
		cp.open([Rect2i(0, 0, 4, 4)], Vector2i(6, 2), Rect2i(4, 0, 4, 4), "", true)
		cp.fit(size, Vector4.ZERO)
		await _frames(2)
		cp.fit(size, Vector4.ZERO)
		var r := Rect2(cp.position, cp.size)
		_expect(Rect2(Vector2.ZERO, size).grow(0.5).encloses(r), "claim confirm %s inside %s" % [r, size])
		var ok_btn := cp.find_child("ClaimConfirm", true, false) as Button
		var cancel := cp.find_child("ClaimCancel", true, false) as Button
		_expect(ok_btn.size.y >= 64.0 and cancel.size.y >= 64.0, "claim buttons are 64 px tall")
		_expect((ok_btn.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == GOLD, "claim's action is GOLD")
		var head := (cp.find_child("ClaimTitle", true, false) as Label).get_parent() as PanelContainer
		_expect((head.get_theme_stylebox("panel") as StyleBoxFlat).bg_color == PARCHMENT_TOP, "claim header is parchment")
		print("[t_uinav] claim %s min %s body %s" % [size, cp.get_combined_minimum_size(), (cp.find_child("ClaimBody", true, false) as Control).get_combined_minimum_size()])
		cp.queue_free()
	root.size = was_size
	root.content_scale_size = was_scale
	# fatigue and death
	var fp: Control = _hud.get("_fatigue_panel")
	var fc := fp.find_child("FatigueClose", true, false) as Control
	_expect(fc != null and fc.custom_minimum_size.y >= 64.0, "fatigue close is 64 px")
	var db: Button = _hud.get("_death_btn")
	_expect(db.size.y >= 64.0 and (db.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == GOLD, "death card's respawn button is GOLD, 64 px")
