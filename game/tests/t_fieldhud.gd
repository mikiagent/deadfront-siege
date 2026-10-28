extends SceneTree
## FIELDHUD acceptance (owner layout 2026-10-28, docs/design/ui-redesign-spec.md §11), on the home island:
## INTERACT shows and runs what is near (gather the nearest resource, open a station, drink at fresh
## water, dismount; disabled with nothing near); ATTACK NEAREST engages the selection, else the nearest
## wild animal; SPRINT latches; the rail reads MENU, BUILD, BAG; Skills and Animals open from the MENU
## sheet; the MENU badge counts notices (gold, red when urgent) and clears when its sheet opens; and at
## 844x390 and 1600x900 no HUD rect overlaps another, every rect stays on screen, and every tap target is
## 64 px or more on the phone canvas.
## Usage: godot --headless --path game --script res://tests/t_fieldhud.gd -> "[t_fieldhud] PASS", exit 0/1.

const WATER_Y := -0.05  ## HarbourSite.WATER_Y
const TILE_MUD := 6  ## IslandTerrain.TileType.MUD: the river channel and its banks
const GOLD := Color(0.957, 0.769, 0.188, 1.0)  ## UiTokens.GOLD (game classes load after this script compiles)
const LIFE := Color(0.847, 0.314, 0.227, 1.0)  ## UiTokens.LIFE

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _rt: Node
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
	print("[t_fieldhud] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TFieldHudHost"
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
	_rt = _world.runtime
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # held where the test puts her
	_player.vitals.fatigue = 0.0  # no bed wins INTERACT
	await _test_rail_and_menu()
	await _test_badge()
	await _test_interact()
	await _test_attack_and_sprint()
	await _test_layout()
	if _fails.is_empty():
		print("[t_fieldhud] PASS")
		quit(0)
	else:
		print("[t_fieldhud] FAIL count=%d" % _fails.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _put(at: Vector3) -> void:
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 1.0, at.z)

func _choice() -> Dictionary:
	return _player.controls.interact_choice()

# ---------------------------------------------------------------- rail, MENU sheet

func _test_rail_and_menu() -> void:
	var rail: Array = [_hud.get_node_or_null("MenuHex"), _hud.get_node_or_null("BuildHex"), _hud.get_node_or_null("BagHex")]
	_expect(not rail.has(null), "the rail has MENU, BUILD and BAG hexes")
	if rail.has(null):
		return
	var caps: Array = rail.map(func (h) -> String: return str(h.caption))
	_expect(caps == ["MENU", "BUILD", "BAG"], "the rail reads MENU, BUILD, BAG (%s)" % [caps])
	_expect((rail[0] as Control).position.x < (rail[1] as Control).position.x and (rail[1] as Control).position.x < (rail[2] as Control).position.x
		and (rail[0] as Control).position.y == (rail[2] as Control).position.y, "MENU, BUILD, BAG run left to right on one line")
	for n in _hud.get_children():
		var h = n
		if h.is_in_group(&"hex_button") and h.is_visible_in_tree():
			_expect(h.caption != "ANIMALS" and h.caption != "SKILLS" and h.caption != "COMBAT", "%s is not an ANIMALS / SKILLS / COMBAT hex" % h.caption)
	# Skills and Animals from the MENU sheet.
	_hud._toggle_sheet(&"menu")
	await _frames(2)
	var skills := _sheet_button("Skills")
	var animals := _sheet_button("Animals")
	_expect(skills != null and animals != null, "the MENU sheet lists Skills and Animals")
	if skills:
		skills.pressed.emit()
		await _frames(2)
		var sheet: Control = _hud.get("_skills_sheet")
		_expect(sheet != null and sheet.visible, "Skills opens from the MENU sheet")
		_hud._toggle_skills()  # close it again
		await _frames(1)
	_hud._toggle_sheet(&"menu")
	await _frames(2)
	animals = _sheet_button("Animals")
	if animals:
		animals.pressed.emit()
		await _frames(2)
		var screen: Control = _hud.get("_animal_screen")
		_expect(screen != null and screen.visible, "Animals opens from the MENU sheet")
		if screen:
			screen.call("close_screen")
	_hud._close_sheet()
	await _frames(1)

func _sheet_button(prefix: String) -> Button:
	var sheet: Control = _hud.get("_sheet")
	if sheet == null:
		return null
	for b in sheet.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			return b
	return null

# ---------------------------------------------------------------- MENU badge

func _test_badge() -> void:
	var menu = _hud.get("_menu_hex")
	_hud.field.notices.clear()
	_hud.field.apply_badge()
	_expect(menu.badge == "", "no notices: no badge")
	_hud.notify_menu(&"skills")
	_player.skills.skill_leveled.emit(&"gathering", 2)  # a real skill level-up counts too
	_expect(menu.badge == "2" and menu.badge_color == GOLD, "two skill notices: a gold 2 at MENU's corner (%s)" % menu.badge)
	_hud.notify_menu(&"market", 1, true)
	_expect(menu.badge == "3" and menu.badge_color == LIFE, "an urgent market notice: 3, red (%s)" % menu.badge)
	_hud._toggle_sheet(&"menu")
	await _frames(2)
	var skills := _sheet_button("Skills")
	_expect(skills != null and skills.text == "Skills (2)", "the MENU sheet names the skill count (%s)" % (skills.text if skills else "none"))
	if skills:
		skills.pressed.emit()
		await _frames(2)
	_expect(menu.badge == "1" and menu.badge_color == LIFE, "opening Skills clears its notices, the urgent one stays (%s)" % menu.badge)
	_hud._toggle_skills()
	_hud.field.clear(&"market")
	_expect(menu.badge == "", "all read: the badge is gone")
	var corner: Vector2 = menu.position + Vector2(menu.size.x * 0.5, 0.0)
	_expect(corner.x > menu.position.x, "the badge sits in MENU's top-right quarter (HexButton badge at +0.55r, -0.55r)")
	await _frames(1)

# ---------------------------------------------------------------- INTERACT

func _test_interact() -> void:
	var hex = _hud.field.interact_hex
	# Gather: a land spot with no station, bed, pen, fire, corpse, water or pet close, a resource within 12 m.
	var gather_at := _scan(func (c: Dictionary) -> bool: return str(c.get("id", "")) == "gather", false)
	_expect(gather_at != Vector3.INF, "a spot where INTERACT gathers (found %s)" % gather_at)
	if gather_at != Vector3.INF:
		_put(gather_at)
		_hud.field.refresh()
		_expect(hex.caption == "GATHER" and not hex.disabled and hex.icon != null, "INTERACT reads GATHER with the resource's icon")
		var expect = _player.controls._nearest_harvest_node(float(_player.controls.QUICK_GATHER_RADIUS))
		hex.pressed.emit()
		await _frames(1)
		var radial_on = _player._gather_radial.focus_node() if _player._gather_radial else null
		_expect(_player.gather_target == expect or radial_on == expect, "INTERACT gathers the nearest resource (target %s, radial %s, nearest %s)" % [_player.gather_target, radial_on, expect])
		_player.actions.cancel_work()
		if _player._gather_radial and _player._gather_radial.has_method("close"):
			_player._gather_radial.close()
	# Open: beside a camp station.
	var st: Node3D = _player._nearest_group("craft_station")
	_expect(st != null, "the island has a craft station")
	if st:
		_put(st.global_position + Vector3(1.4, 0, 0))
		var c := _choice()
		_expect(str(c.get("id", "")) in ["open", "sleep", "pen"] and (c["run"] as Callable).get_method() in ["open_station_craft", "start_sleep", "pen_interact"],
			"beside a station INTERACT opens it (%s via %s)" % [c.get("id"), (c["run"] as Callable).get_method() if c.has("run") else "-"])
		_hud.field.refresh()
		_expect(hex.caption == str(c.get("label", "")).to_upper(), "the hex caption follows the pick (%s)" % hex.caption)
	# Drink: fresh water underfoot, nothing closer.
	var water_at := _scan(func (c: Dictionary) -> bool: return str(c.get("id", "")) == "drink", true)
	_expect(water_at != Vector3.INF, "a river spot where INTERACT drinks (found %s)" % water_at)
	if water_at != Vector3.INF:
		_put(water_at)
		_hud.field.refresh()
		_expect(hex.caption == "DRINK", "INTERACT reads DRINK at the river (%s)" % hex.caption)
		_player.statuses.clear_id(&"quenched")
		hex.pressed.emit()
		_expect(_player.statuses.has(&"quenched"), "INTERACT drinks: Quenched")
		_hud._ctx_ids = []
		_hud._ctx_timer = 0.0
		_hud._refresh_context(0.0)
		var dup := false
		for h in _hud.get("_ctx_hexes"):
			dup = dup or str(h.caption) == "DRINK"
		_expect(not dup, "the context row does not repeat INTERACT's Drink")
	# Dismount while riding.
	var mount = _creature(&"compsognathus", _player.global_position + Vector3(3, 0, 0))
	_player.mounted_on = mount
	var md := _choice()
	_expect(str(md.get("id", "")) == "dismount" and (md["run"] as Callable).get_method() == "dismount", "riding, INTERACT dismounts")
	_player.mounted_on = null
	mount.queue_free()
	# Nothing near: with the island's resources out of the harvest group, a dry spot away from camp and water.
	var nodes := root.get_tree().get_nodes_in_group("harvest")
	for n in nodes:
		(n as Node).remove_from_group("harvest")
	var far := _scan(func (c: Dictionary) -> bool: return c.is_empty(), false)
	_expect(far != Vector3.INF, "a spot with nothing to interact with")
	if far != Vector3.INF:
		_put(far)
		_hud.field.refresh()
		_expect(hex.disabled and hex.caption == "INTERACT", "nothing in reach: INTERACT is disabled (%s)" % hex.caption)
	for n in nodes:
		(n as Node).add_to_group("harvest")
	await _frames(1)

## The first spot on a coarse island grid (water tiles when `wet`) whose INTERACT pick passes `ok`.
func _scan(ok: Callable, wet: bool) -> Vector3:
	var half: float = float(_rt.get("_size")) * 0.5 - 4.0
	var step := 3.0 if not wet else 0.5
	var x := -half
	while x < half:
		var z := -half
		while z < half:
			var h: float = _rt.surface_y(x, z)
			var water: bool = h < WATER_Y
			var river: bool = int(load("res://scripts/world/island_terrain.gd").tile_type_at_world(_rt, x, z)) == TILE_MUD
			if (wet and water and river and h > -0.38) or (not wet and not water):
				_put(Vector3(x, 0, z))
				if ok.call(_choice()):
					return Vector3(x, 0, z)
			z += step
		x += step * (1.0 if not wet else 4.0)
	return Vector3.INF

func _creature(id: StringName, at: Vector3) -> Node3D:
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	_host.add_child(c)
	c.global_position = at
	c.spawn(root.get_node("Data").creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

# ---------------------------------------------------------------- ATTACK NEAREST, SPRINT

func _test_attack_and_sprint() -> void:
	var spot := _scan(func (c: Dictionary) -> bool: return true, false)
	_put(spot)
	for n in root.get_tree().get_nodes_in_group("creatures"):
		(n as Node).remove_from_group("creatures")  # only the test's animals count
	var atk = _hud.field.attack_hex
	_hud.field.refresh()
	_expect(atk.disabled, "no animal in range: ATTACK NEAREST is disabled")
	var near = _creature(&"compsognathus", _player.global_position + Vector3(4, 0, 0))
	var far = _creature(&"compsognathus", _player.global_position + Vector3(0, 0, 9))
	_hud.field.refresh()
	_expect(not atk.disabled, "an animal in range enables ATTACK NEAREST")
	atk.pressed.emit()
	_expect(_player.hunt.target == near, "ATTACK NEAREST engages the nearest wild animal")
	# [owner 2026-10-28] in combat: a tap on another enemy retargets at once, no swords; ATTACK NEAREST
	# retargets to the nearest valid enemy.
	var swords = _hud.get("_swords_hex")
	_player.controls.interact_tap_target(far)
	_expect(_player.hunt.target == far, "in combat a tap on another enemy switches the target to it")
	_expect(swords._shown_for() == null, "in combat the swords hex is not shown on enemies")
	atk.pressed.emit()
	_expect(_player.hunt.target == near, "in combat ATTACK NEAREST retargets to the nearest enemy")
	_player.hunt.stop()
	# Out of combat: a tap only selects (TARGETUI); the swords hex or ATTACK NEAREST start the fight.
	_player.controls.interact_tap_target(far)
	_expect(_player.hunt.target == null, "out of combat a tap selects and starts no fight")
	_expect(swords._shown_for() == far, "out of combat the selection gets the swords hex")
	atk.pressed.emit()
	_expect(_player.hunt.target == far, "with a selection, ATTACK NEAREST engages the selected animal")
	_player.hunt.stop()
	_player.controls.selection.clear()
	near.queue_free()
	far.queue_free()
	var sprint = _hud.field.sprint_hex
	_player.sprint_toggled = false
	sprint.pressed.emit()
	_expect(_player.sprint_toggled and sprint.selected, "SPRINT taps on")
	sprint.pressed.emit()
	_expect(not _player.sprint_toggled and not sprint.selected, "SPRINT taps off")
	await _frames(2)

# ---------------------------------------------------------------- layout

func _test_layout() -> void:
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	# An unclaimed riverside spot so the context row (Wash / Fill) and CLAIM show.
	var spot := _scan(func (c: Dictionary) -> bool: return str(c.get("id", "")) == "drink", true)
	if spot != Vector3.INF:
		_put(spot)
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _frames(3)
		_hud.field.refresh()  # INTERACT's pick first: the context row leaves it out
		_hud._ctx_ids = []
		_hud._ctx_timer = 0.0
		_hud._refresh_context(0.0)
		_hud.queue_redraw()
		await _frames(2)
		var phone: bool = size.x < 1000
		for state in ["idle", "combat"]:
			_check_rects(Vector2(size), state, phone)
	root.size = was_size
	root.content_scale_size = was_scale
	await _frames(2)

## Every control the HUD shows in `state` (whistles counted as if a pet were out), each as its hex and
## caption rects, plus the drawn vitals, map text and quest blocks: pairwise clear, all inside the view,
## and every tap target 64 px or more on the phone canvas.
func _check_rects(view: Vector2, state: String, phone: bool) -> void:
	var tag := "%dx%d %s" % [view.x, view.y, state]
	var items: Array = []  # [name, Control]
	for n in ["MenuHex", "BuildHex", "BagHex", "InteractHex", "AttackNearest", "SprintToggle"]:
		items.append([n, _hud.get_node(n)])
	for h in _hud.get("_food_hexes"):
		items.append(["food", h])
	for h in _hud.get("_whistle_hexes"):
		items.append(["whistle " + str(h.caption), h])
	if state == "idle":
		for h in _hud.get("_ctx_hexes"):
			items.append(["ctx " + str(h.caption), h])
	else:
		items.append(["chase", _hud.get("_chase_hex")])
		for h in _hud.get("_skill_hexes"):
			items.append(["skill " + str(h.caption), h])
		items.append(["auto", _hud.get("_auto_hex")])
		items.append(["feed", _hud.get("_feed_hex")])
		items.append(["end", _hud.get("_end_btn")])
		items.append(["stance", _hud.get("_stance_label")])
	var held: Control = _player.station_craft.held_slot if _player.station_craft else null
	var rects: Array = []  # [name, Rect2]
	for it in items:
		var c: Control = it[1]
		if c.is_in_group(&"hex_button"):
			rects.append([it[0], c.hex_rect()])
			if str(c.caption) != "":
				rects.append([str(it[0]) + " caption", c.caption_rect()])
			if phone:
				_expect(c.size.x >= 64.0 and c.size.y >= 64.0, "%s: %s is a 64 px tap target (%s)" % [tag, it[0], c.size])
		else:
			rects.append([it[0], c.get_global_rect()])
			if phone and c is Button:
				_expect(c.size.y >= 64.0, "%s: %s is 64 px tall (%s)" % [tag, it[0], c.size])
	if held:
		var hp: Vector2 = _hud.hands_spot()
		rects.append(["HANDS", Rect2(hp, Vector2(held.size.x, held.size.y + 18.0))])
		if phone:
			_expect(held.size.x >= 64.0, "%s: HANDS is a 64 px tap target" % tag)
	rects.append(["minimap", (_hud.get("_minimap") as Control).get_global_rect()])
	rects.append(["dial", (_hud.get("_daynight") as Control).get_global_rect()])
	for k in ["vitals", "map_text", "map_title"]:
		if _hud.drawn_blocks.has(k):
			rects.append([k, _hud.drawn_blocks[k]])
	if state == "idle" and _hud.drawn_blocks.has("quest"):
		rects.append(["quest", _hud.drawn_blocks["quest"]])
	rects.append(["xp line", Rect2(view.x * 0.5 - 90.0, view.y - 26.0, 180.0, 26.0)])  # UiTokens.xp_line_zone
	var screen := Rect2(Vector2.ZERO, view)
	var overlaps := 0
	for i in rects.size():
		var a: Rect2 = rects[i][1]
		if not a.has_area():
			continue
		_expect(screen.encloses(a.grow(-0.5)), "%s: %s %s stays on screen" % [tag, rects[i][0], a])
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j][1]
			if b.has_area() and a.grow(-1.0).intersects(b.grow(-1.0)):
				overlaps += 1
				_expect(false, "%s: %s %s overlaps %s %s" % [tag, rects[i][0], a, rects[j][0], b])
	print("[t_fieldhud] %s: %d rects, %d overlaps" % [tag, rects.size(), overlaps])
	for r in rects:
		print("[t_fieldhud]   %s %s" % [r[0], r[1]])
