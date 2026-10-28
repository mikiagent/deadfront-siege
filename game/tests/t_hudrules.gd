extends SceneTree
## HUDRULES acceptance (owner 2026-10-28): afflictions only beside the survivor, buffs / boons / debuffs only
## in the chip row under the vitals with hover / click / tap tooltips, a stomach ring right of the health
## bar, the orders card hidden in combat unless the fight serves it, DoT numbers in their status colour and
## no green negative status. Runs on the home island at 844x390 and 1600x900.
## Usage: godot --headless --path game --script res://tests/t_hudrules.gd -> "[t_hudrules] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _world: Node
var _data: Node
var BS: GDScript
var DIG: GDScript
var OBJ: GDScript
var ROW: GDScript
var TOK: GDScript
var IS: GDScript

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
	print("[t_hudrules] %s %s" % ["ok" if ok else "FAIL", what])

func _secs(t: float) -> void:
	await create_timer(t).timeout
	await process_frame

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_world = root.get_node("World")
	_data = root.get_node("Data")
	BS = load("res://scripts/items/buff_slots.gd")
	DIG = load("res://scripts/items/digestion.gd")
	OBJ = load("res://scripts/core/objectives.gd")
	ROW = load("res://scripts/ui/hud_buff_row.gd")
	TOK = load("res://scripts/ui/ui_tokens.gd")
	IS = load("res://scripts/items/item_stack.gd")
	_host = Node3D.new()
	_host.name = "THudRulesHost"
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
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # statuses and digestion move only when the test says so
	_test_data()
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _test_split(Vector2(size))
		await _test_tooltip(Vector2(size))
		await _test_stomach(Vector2(size))
		await _test_orders(Vector2(size))
	await _test_tick_colours()
	root.size = was_size
	root.content_scale_size = was_scale
	if _fails.is_empty():
		print("[t_hudrules] PASS")
		quit(0)
	else:
		print("[t_hudrules] FAIL count=%d" % _fails.size())
		quit(1)

## Every status names its kind and has a desc; no negative one is green (green = healing only).
func _test_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json"))
	for s in (parsed as Dictionary).get("statuses", []):
		var def = _data.status(StringName(str(s["id"])))
		_expect(def != null and def.kind in [&"effect", &"buff", &"boon", &"debuff"] and def.desc.length() > 8, "%s has a kind (%s) and a desc" % [s["id"], def.kind if def else "?"])
		if def and def.kind in [&"effect", &"debuff"]:
			var c: Color = def.fx_color
			var green: bool = c.s > 0.25 and c.h > 0.2 and c.h < 0.47
			_expect(not green, "%s (%s) is not green (hue %.2f)" % [s["id"], def.kind, c.h])
	for id in [&"venom", &"poisoned", &"poisoned_target", &"infected_wound", &"stomachache"]:
		_expect(_data.status(id).fx_color.is_equal_approx(TOK.POISON), "%s takes the POISON purple" % id)
	_expect(TOK.HEAL.h > 0.25 and TOK.HEAL.h < 0.45 and TOK.POISON.h > 0.7 and TOK.POISON.h < 0.85, "HEAL is green, POISON purple")

func _reset() -> void:
	_player.statuses.from_array([])
	var slots = BS.of(_player)
	for row in slots.rows().duplicate():
		slots.rows().erase(row)
	DIG.of(_player).rows().clear()
	_hud._buff_row.pinned = ""
	_hud._buff_row.hovered = ""
	_player.vitals.health = _player.vitals.effective_max_health()

func _test_split(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	var sx = _hud.get("_status_fx")
	var row = _hud._buff_row
	_reset()
	_player.statuses.apply(&"bleed")
	await _frames(4)
	_expect(sx.boxes.has(&"bleed"), "%s bleed makes a world box" % tag)
	_expect(not row.chips.has("bleed") and row.chips.is_empty(), "%s bleed makes no chip under the vitals (%s)" % [tag, row.chips.keys()])
	_player.statuses.clear_id(&"bleed")
	_player.statuses.apply(&"well_rested")
	await _frames(4)
	_expect(row.chips.has("well_rested"), "%s Well Rested makes a chip under the vitals" % tag)
	_expect(not sx.boxes.has(&"well_rested") and sx.boxes.is_empty(), "%s Well Rested makes no world box" % tag)
	var vit: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	var chip: Rect2 = row.chips.get("well_rested", Rect2())
	_expect(chip.position.y >= vit.end.y and chip.position.y < vit.end.y + 20.0, "%s the chip sits right under the vitals (%s under %s)" % [tag, chip, vit])
	BS.of(_player).apply(_player, [{"id": "t_stew", "group": "enhanced_ability", "group_name": "Enhanced Ability",
		"display_name": "Camp Stew: Perception +20.9", "duration": 1200.0, "stats": {"perception": {"add": 20.9}}}])
	await _frames(3)
	_expect(row.chips.has("food:t_stew"), "%s a food buff makes a chip too" % tag)
	_expect(not row.chips.has("bleed"), "%s still no bleed chip" % tag)

func _motion(pos: Vector2, device: int = 0) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.device = device
	_hud._input(m)

func _click(pos: Vector2, device: int = 0) -> void:
	var b := InputEventMouseButton.new()
	b.position = pos
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = true
	b.device = device
	_hud._input(b)

func _tap(pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.position = pos
	t.pressed = true
	_hud._input(t)
	_click(pos, InputEvent.DEVICE_ID_EMULATION)  # the mouse event a touch screen also sends

func _test_tooltip(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	var row = _hud._buff_row
	await _frames(2)
	var chip: Rect2 = row.chips.get("well_rested", Rect2())
	var at := chip.get_center()
	_expect(chip.has_area(), "%s the Well Rested chip is drawn" % tag)
	if TOK.is_compact(view):
		for k in row.chips:
			var tr: Rect2 = row.touch_rect(k)
			_expect(tr.size.x >= 64.0 and tr.size.y >= 64.0, "%s %s touch area is 64 px or more (%s)" % [tag, k, tr.size])
	# Desktop hover shows it; moving off hides it.
	_motion(at)
	await _frames(2)
	_expect(row.shown() == "well_rested" and row.tooltip_rect.has_area(), "%s hover shows the tooltip (shown %s)" % [tag, row.shown()])
	if not row.tooltip_rect.has_area():
		print("[t_hudrules] debug chip %s taken %s" % [chip, _hud.taken_rects()])
	_check_tip(view, tag + " hover")
	_motion(Vector2(view.x * 0.5, view.y * 0.6))
	await _frames(2)
	_expect(row.shown() == "" and not row.tooltip_rect.has_area(), "%s moving off hides it" % tag)
	# Click pins it (it stays with the pointer away), a second click unpins it.
	_click(at)
	_motion(Vector2(view.x * 0.5, view.y * 0.6))
	await _frames(2)
	_expect(row.pinned == "well_rested" and row.tooltip_rect.has_area(), "%s a click pins the tooltip" % tag)
	_check_tip(view, tag + " pinned")
	_motion(at)
	_click(at)
	await _frames(2)
	_expect(row.pinned == "" and not row.tooltip_rect.has_area(), "%s a second click closes it (pointer still on the chip)" % tag)
	# Touch: one tap opens (the emulated mouse press does not toggle it back), a second closes.
	_tap(at)
	await _frames(2)
	_expect(row.pinned == "well_rested" and row.tooltip_rect.has_area(), "%s a tap opens the tooltip" % tag)
	_tap(at)
	await _frames(2)
	_expect(row.pinned == "" and not row.tooltip_rect.has_area(), "%s a second tap closes it" % tag)
	# The food buff's tooltip names its stat.
	var food: Rect2 = row.chips.get("food:t_stew", Rect2())
	_tap(food.get_center())
	await _frames(2)
	_expect(row.pinned == "food:t_stew" and row.tooltip_rect.has_area(), "%s the food buff's tooltip opens" % tag)
	var e: Array = ROW.entries(_player).filter(func (x: Dictionary) -> bool: return x["key"] == "food:t_stew")
	_expect(not e.is_empty() and str(e[0]["effect"]).contains("Perception +20.9"), "%s it reads the buff's stat (%s)" % [tag, e[0]["effect"] if not e.is_empty() else ""])
	_tap(food.get_center())
	await _frames(1)

## The tooltip inside the screen and off every HUD rect but its own.
func _check_tip(view: Vector2, tag: String) -> void:
	var tip: Rect2 = _hud._buff_row.tooltip_rect
	_expect(Rect2(Vector2.ZERO, view).encloses(tip), "%s tooltip on screen (%s)" % [tag, tip])
	var hit := Rect2()
	for t: Rect2 in _hud.taken_rects(PackedStringArray(["buff_tip"])):
		if t.intersects(tip):
			hit = t
	_expect(not hit.has_area(), "%s tooltip off the HUD (hits %s)" % [tag, hit])

func _test_stomach(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	var dig = DIG.of(_player)
	dig.rows().clear()
	await _frames(2)
	_expect(is_equal_approx(_hud.stomach_fill, 0.0), "%s empty stomach reads 0 (%.2f)" % [tag, _hud.stomach_fill])
	dig.schedule(&"t_meal", 80.0, 300.0)
	await _frames(2)
	_expect(is_equal_approx(_hud.stomach_fill, 1.0), "%s right after a meal the ring is full (%.2f)" % [tag, _hud.stomach_fill])
	for left in [60.0, 20.0, 0.0]:
		dig.rows()[0]["remaining"] = left
		await _frames(2)
		_expect(absf(_hud.stomach_fill - left / 80.0) < 0.001, "%s %.0f of 80 left reads %.2f" % [tag, left, _hud.stomach_fill])
	var ring: Rect2 = _hud.stomach_rect
	var vit: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	_expect(ring.has_area() and vit.encloses(ring), "%s the ring sits inside the vitals panel (%s in %s)" % [tag, ring, vit])
	_expect(ring.position.x > vit.position.x + vit.size.x * 0.5 and ring.position.y < vit.position.y + 30.0, "%s the ring is at the right, level with the health bar (%s)" % [tag, ring])
	_expect(ring.size.x >= 28.0, "%s the ring is %.0f px across" % [tag, ring.size.x])
	dig.rows().clear()

func _creature(species: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	_host.add_child(c)
	c.global_position = at
	c.spawn(_data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _order_index(id: String) -> int:
	var steps: Array = OBJ._steps()
	for i in steps.size():
		if str(steps[i].get("id", "")) == id:
			return i
	return -1

func _quest() -> bool:
	return _hud.drawn_blocks.has("quest")

func _badge() -> bool:
	return _hud.orders_badge_rect.has_area()

## Calm, collapsed, no auto timer: the start of every orders case.
func _orders_calm() -> void:
	_player.hunt.stop()
	OrdersSheet_set(false)
	_hud.orders_auto_t = 0.0
	await _frames(3)

func OrdersSheet_set(v: bool) -> void:
	load("res://scripts/ui/orders_sheet.gd").hud_expanded = v

func _test_orders(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	_reset()
	var was_obj: int = _world.objective
	var tame := _order_index("tame")
	var meat := _order_index("meat")
	var branches := _order_index("branches")
	_expect(tame >= 0 and meat >= 0 and branches >= 0, "%s the tame, meat and branches orders exist" % tag)
	# Collapsed by default: a badge on the minimap with the order's number.
	_world.objective = tame
	_world.objective_best = 0
	await _orders_calm()
	_expect(_badge() and not _quest(), "%s collapsed by default: the minimap badge, no card" % tag)
	var mm: Control = _hud.get("_minimap")
	_expect(mm.get_global_rect().encloses(_hud.orders_badge_rect), "%s the badge sits on the minimap (%s)" % [tag, _hud.orders_badge_rect])
	var steps: Array = OBJ._steps()
	_expect(_hud.orders_badge_text == "%d/%d" % [tame + 1, steps.size()], "%s the badge reads the order's number (%s)" % [tag, _hud.orders_badge_text])
	if TOK.is_compact(view):
		var tr: Rect2 = load("res://scripts/ui/hud_orders_badge.gd").touch_rect(_hud.orders_badge_rect, true)
		_expect(tr.size.x >= 64.0 and tr.size.y >= 64.0, "%s the badge's touch area is 64 px or more" % tag)
	# Tap toggles: badge -> card -> badge.
	_tap(_hud.orders_badge_rect.get_center())
	await _frames(2)
	_expect(_quest() and not _badge(), "%s a tap on the badge expands the card" % tag)
	_tap((_hud.drawn_blocks["quest"] as Rect2).get_center() if _quest() else Vector2.ZERO)
	await _frames(2)
	_expect(_badge() and not _quest(), "%s a tap on the card collapses it" % tag)
	_click(_hud.orders_badge_rect.get_center())
	await _frames(2)
	_expect(_quest(), "%s a click expands it too" % tag)
	# Combat: a fight that does not serve the order hides card and badge, expanded or not.
	var dei = _creature(&"deinonychus", _player.global_position + Vector3(3.0, 0.0, 1.0))
	_player.hunt.start(dei)
	await _frames(3)
	_expect(not _quest() and not _badge(), "%s fighting a deinonychus hides \"Tame a Zebraceratops\"" % tag)
	_player.hunt.stop()
	OrdersSheet_set(false)
	var zeb = _creature(&"zebraceratops", _player.global_position + Vector3(-3.0, 0.0, 1.0))
	_player.hunt.start(zeb)
	await _secs(0.4)
	_expect(_quest(), "%s fighting a zebraceratops auto-expands \"Tame a Zebraceratops\"" % tag)
	_player.hunt.stop()
	_world.objective = meat
	_hud.orders_auto_t = 0.0
	_player.hunt.start(dei)
	await _secs(0.4)
	_expect(_quest(), "%s fighting a deinonychus keeps \"Hunt something for meat\" up (fight *)" % tag)
	_player.hunt.stop()
	dei.queue_free()  # a phone keeps the last target's plate in the band while it lives nearby
	zeb.queue_free()
	await _frames(3)
	_expect(_quest(), "%s right after the fight it is still up (auto, %.1f s left)" % [tag, _hud.orders_auto_t])
	_hud.orders_auto_t = 0.05
	await _secs(0.4)
	_expect(_badge() and not _quest(), "%s once progress stops it collapses back to the badge" % tag)
	# Auto-expand on progress: gathering the ordered branches.
	_world.objective = branches
	_world.objective_best = 0
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	await _orders_calm()
	await _secs(0.4)
	_expect(_badge() and not _quest(), "%s no progress, no card" % tag)
	_player.inventory.add(IS.make(&"branch", 1))
	await _secs(0.4)
	_expect(_quest(), "%s a gathered branch auto-expands the card" % tag)
	# Collapsed by hand while auto-expanded: it stays down while she keeps gathering.
	_tap((_hud.drawn_blocks["quest"] as Rect2).get_center() if _quest() else Vector2.ZERO)
	await _frames(2)
	_expect(_badge() and not _quest(), "%s a tap collapses the auto-expanded card" % tag)
	_player.inventory.add(IS.make(&"branch", 1))
	await _secs(0.4)
	_expect(_badge() and not _quest(), "%s it stays collapsed for the rest of the activity" % tag)
	_hud.orders_auto_t = 0.05
	await _secs(0.4)
	_player.inventory.add(IS.make(&"branch", 1))
	await _secs(0.4)
	_expect(_quest() or _world.objective != branches, "%s a new activity auto-expands it again" % tag)
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	_world.objective = was_obj
	_world.objective_best = 0
	await _orders_calm()

## Each DoT's tick number takes its status's fx colour.
func _test_tick_colours() -> void:
	for id in [&"bleed", &"venom", &"poisoned", &"stomachache"]:
		_reset()
		_player.statuses.apply(id)
		await _frames(2)
		var floats: Array = _hud.get("_events").player_floats
		var before := floats.size()
		_player.statuses._dot(_player.statuses.get_instance(id))
		floats = _hud.get("_events").player_floats
		_expect(floats.size() == before + 1, "%s tick adds one number" % id)
		if floats.size() == before + 1:
			var col: Color = floats[floats.size() - 1]["col"]
			_expect(col.is_equal_approx(_data.status(id).fx_color), "%s tick number is its fx colour (%s vs %s)" % [id, col, _data.status(id).fx_color])
	_reset()
