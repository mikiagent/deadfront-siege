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
	await _test_fullness_fatigue()
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
	var ST: GDScript = load("res://scripts/ui/hud_stomach.gd")
	var dig = DIG.of(_player)
	dig.rows().clear()
	await _frames(2)
	_expect(is_equal_approx(_hud.stomach_fill, 0.0) and _hud.stomach_state == &"empty" and is_equal_approx(_hud.stomach_saturation, 0.0), "%s nothing digesting: empty, no saturation (%.2f, %s, %.2f)" % [tag, _hud.stomach_fill, _hud.stomach_state, _hud.stomach_saturation])
	# A roast (foods.json fullness 50 of a 100 cap), 60 Energy digesting over 300 s.
	var row: Dictionary = dig.schedule(&"roast", 60.0, 300.0)
	await _frames(2)
	_expect(absf(_hud.stomach_fill - 0.5) < 0.001 and _hud.stomach_state == &"normal", "%s one fresh roast reads half full, normal (%.2f %s)" % [tag, _hud.stomach_fill, _hud.stomach_state])
	_expect(absf(_hud.stomach_saturation - 1.0) < 0.001, "%s fresh meal: the saturation ring is full (%.2f)" % [tag, _hud.stomach_saturation])
	for left in [45.0, 30.0, 6.0]:
		row["remaining"] = left
		await _frames(2)
		var want_sat: float = left / (60.0 / 300.0) / 300.0
		_expect(absf(_hud.stomach_fill - 0.5 * left / 60.0) < 0.001, "%s %.0f of 60 left reads %.2f full" % [tag, left, _hud.stomach_fill])
		_expect(absf(_hud.stomach_saturation - want_sat) < 0.001, "%s saturation follows the digestion time left (%.2f, want %.2f)" % [tag, _hud.stomach_saturation, want_sat])
	_expect(_hud.stomach_state == &"empty", "%s 6 of 60 left (0.05) is empty" % tag)
	row["remaining"] = 30.0
	await _frames(2)
	_expect(_hud.stomach_state == &"hungry", "%s 0.25 is hungry (%s)" % [tag, _hud.stomach_state])
	dig.schedule(&"roast", 60.0, 300.0)
	row["remaining"] = 60.0
	await _frames(2)
	_expect(absf(_hud.stomach_fill - 1.0) < 0.001 and _hud.stomach_state == &"full", "%s two roasts: full (%.2f %s)" % [tag, _hud.stomach_fill, _hud.stomach_state])
	dig.schedule(&"roast", 60.0, 300.0)
	await _frames(2)
	_expect(_hud.stomach_fill > 1.4 and _hud.stomach_state == &"overfull", "%s three roasts: overfull (%.2f %s)" % [tag, _hud.stomach_fill, _hud.stomach_state])
	var ring: Rect2 = _hud.stomach_rect
	var vit: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	_expect(ring.has_area(), "%s the ring draws (%s)" % [tag, ring])
	# Owner 2026-10-28 (HUDTWEAK): the ring sits under the level badge, below the vitals' bars.
	_expect(ring.position.y >= vit.end.y and ring.position.x <= vit.position.x + 16.0, "%s the ring sits under the badge, below the vitals (%s)" % [tag, ring])
	var hit := Rect2()
	for t: Rect2 in _hud.taken_rects(PackedStringArray(["vitals", "stomach"])):
		if t.intersects(ring):
			hit = t
	_expect(not hit.has_area(), "%s the ring is off every other HUD rect (hits %s)" % [tag, hit])
	dig.rows().clear()
	await _frames(1)
	if tag != "844x390":
		return
	# Band colours (once): red empty, yellow hungry, green full, red overfull, blended between.
	_expect(ST.color_for(0.0).is_equal_approx(TOK.STOMACH_EMPTY) and ST.color_for(0.05).is_equal_approx(TOK.STOMACH_EMPTY), "empty is red")
	_expect(ST.color_for(0.4).is_equal_approx(TOK.STOMACH_HUNGRY), "hungry is yellow")
	_expect(ST.color_for(0.9).is_equal_approx(TOK.STOMACH_FULL) and TOK.STOMACH_FULL.h > 0.25 and TOK.STOMACH_FULL.h < 0.45, "full is green")
	_expect(ST.color_for(1.3).is_equal_approx(TOK.STOMACH_OVERFULL) and TOK.STOMACH_OVERFULL.h < 0.06, "overfull is red")
	var mid: Color = ST.color_for(0.65)
	_expect(not mid.is_equal_approx(TOK.STOMACH_HUNGRY) and not mid.is_equal_approx(TOK.STOMACH_FULL) and mid.g >= TOK.STOMACH_HUNGRY.g - 0.01, "0.65 blends yellow into green (%s)" % mid)
	var icons: GDScript = load("res://scripts/ui/ui_icons.gd")
	var seen := {}
	for st in [&"empty", &"hungry", &"full", &"overfull"]:
		var gid: StringName = ST.GLYPH[st]
		_expect(icons.path_for(gid) != "" and icons.icon(gid) != null and not seen.has(gid), "%s has its own glyph %s" % [st, gid])
		seen[gid] = true
	_expect(ST.GLYPH[&"normal"] == ST.GLYPH[&"full"] and ST.GLYPH_SCALE[&"normal"] < ST.GLYPH_SCALE[&"full"], "normal draws the full stomach, smaller")
	for pair in [[0.0, &"empty"], [0.2, &"hungry"], [0.55, &"normal"], [0.85, &"full"], [1.1, &"overfull"]]:
		_expect(ST.state_of(pair[0]) == pair[1], "%.2f is %s (%s)" % [pair[0], pair[1], ST.state_of(pair[0])])
	# Degrades clockwise: the lit arc always ends at 12 o'clock and starts later (clockwise) as it empties.
	var top := -PI * 0.5 + TAU
	var last := -INF
	for f in [1.0, 0.75, 0.5, 0.25, 0.0]:
		var arc: Vector2 = ST.arc_for(f)
		_expect(is_equal_approx(arc.y, top) and absf(arc.y - arc.x - TAU * f) < 0.0001 and arc.x > last, "%.2f full lights %.2f of the ring, ending at 12 o'clock (%s)" % [f, f, arc])
		last = arc.x
	_expect(is_equal_approx(ST.arc_for(0.75).x, 0.0), "at 75 %% the gap runs clockwise from 12 to 3 o'clock")
	# The glyph's drawn scale follows the state: shrunk empty, big full, bigger overfull.
	var sc: Dictionary = ST.GLYPH_SCALE
	_expect(sc[&"empty"] < sc[&"hungry"] and sc[&"hungry"] < sc[&"normal"] and sc[&"normal"] < sc[&"full"] and sc[&"full"] < sc[&"overfull"], "glyph scale grows from empty to overfull (%s)" % sc)
	var dig2 = DIG.of(_player)
	for st in [[[], &"empty"], [[1.0, 1.0], &"full"], [[1.0, 1.0, 1.0], &"overfull"], [[0.5], &"hungry"]]:
		dig2.rows().clear()
		for share in st[0]:
			var r2: Dictionary = dig2.schedule(&"roast", 60.0, 300.0)
			r2["remaining"] = 60.0 * float(share)
		await _secs(0.6)
		_expect(_hud.stomach_state == st[1] and absf(_hud.stomach_glyph_scale - float(sc[st[1]])) < 0.001, "%s: glyph %s at scale %.2f (want %.2f)" % [st[1], ST.GLYPH[_hud.stomach_state], _hud.stomach_glyph_scale, sc[st[1]]])
	dig2.rows().clear()
	await _frames(1)

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

## FULLFATIGUE: the stomach state scales fatigue gain (empty > hungry > normal > full), the breakdown panel
## names it, and the HUD ring shows the model's own value and state.
func _test_fullness_fatigue() -> void:
	_reset()
	var dig = DIG.of(_player)
	var v = _player.vitals
	var FP: GDScript = load("res://scripts/ui/fatigue_panel.gd")
	var gains := {}
	for st in [[[], &"empty"], [[0.5], &"hungry"], [[1.0], &"normal"], [[1.0, 1.0], &"full"], [[1.0, 1.0, 1.0], &"overfull"]]:
		dig.rows().clear()
		for share in st[0]:
			var r: Dictionary = dig.schedule(&"roast", 60.0, 300.0)
			r["remaining"] = 60.0 * float(share)
		_player.sim.tick(0.0)  # PlayerSim sets the stomach state and folds its factor into fatigue_gain_mult
		_expect(v.fullness_state == st[1], "%s: the model's state (%s)" % [st[1], v.fullness_state])
		v.fatigue = 0.0
		v.blocks_fatigue_gain = false
		v.add_fatigue(1.0, &"walk")
		gains[st[1]] = v.fatigue
		var line: String = FP.context_text(v, _player)
		var want: String = {&"empty": "Empty stomach: +100% exhaustion.", &"hungry": "Hungry: +50% exhaustion.", &"normal": "", &"full": "Full: -15% exhaustion.", &"overfull": "Overfull, sluggish: +10% exhaustion."}[st[1]]
		_expect((want == "" and not line.contains("exhaustion.")) or line.contains(want), "%s: the breakdown panel reads \"%s\" (%s)" % [st[1], want, line])
		await _frames(2)
		_expect(absf(_hud.stomach_fill - dig.fullness()) < 0.0001 and _hud.stomach_state == v.fullness_state, "%s: the ring shows the model (%.2f %s)" % [st[1], _hud.stomach_fill, _hud.stomach_state])
	print("[t_hudrules] fatigue per 1.0 walk gain by stomach: %s" % gains)
	_expect(gains[&"empty"] > gains[&"hungry"] and gains[&"hungry"] > gains[&"normal"] and gains[&"normal"] > gains[&"full"], "fatigue gain is ordered empty > hungry > normal > full (%s)" % gains)
	_expect(absf(gains[&"empty"] / gains[&"normal"] - 2.0) < 0.001 and absf(gains[&"overfull"] / gains[&"normal"] - 1.1) < 0.001, "empty doubles it, overfull adds 10 %%")
	# A new survivor and an old save with nothing digesting start "normal" (a starter meal), once.
	var fresh = DIG.new()
	_expect(fresh.seed_starter() and DIG.state_for(fresh.fullness()) == &"normal", "a new survivor starts normal (%.2f)" % fresh.fullness())
	_expect(not fresh.seed_starter() and fresh.rows().size() == 1, "the starter meal is given once")
	var old = DIG.new()
	old.from_dict({"rows": [], "next_id": 4})  # a save from before the flag, nothing digesting
	_expect(old.seed_starter() and DIG.state_for(old.fullness()) == &"normal", "an old save with nothing digesting loads normal")
	var again = DIG.new()
	again.from_dict({"rows": [], "next_id": 9, "starter_given": true})
	_expect(not again.seed_starter() and again.rows().is_empty() and DIG.state_for(again.fullness()) == &"empty", "a later save with nothing digesting stays empty (no free meal per load)")
	var rt = DIG.new()
	rt.from_dict(fresh.to_dict())
	_expect(rt.starter_given and rt.rows().size() == 1, "the flag and the starter row survive a save")
	dig.rows().clear()
	v.fatigue = 0.0
	_player.sim.tick(0.0)

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
