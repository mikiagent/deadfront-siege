extends SceneTree
## CRAFTRADIAL acceptance (docs/design/ui-redesign-spec.md §7 D4 / D5) at 1600x900 and 844x390, home island:
##   radial   - a station tap opens the ring: main wedge on top (CRAFT at the workbench, COOK at the stone
##              grill "oven", OPEN at a basket, PEN for the pen), then PACKAGE and REMOVE; the output row
##              lists the station's recipe outputs and a slot opens that recipe in the craft panel;
##   package  - PACKAGE puts the kit in the bag and takes the station away;
##   remove   - REMOVE asks first (CONFIRM), the second tap demolishes;
##   panel    - the right pop-out: category tabs and search narrow the list;
##   tags     - a large leg bone (thick_pillar) crafts a Plank and lists Plank in its craft-into list;
##              a silver chunk makes 2 metal sticks that inherit Firm and fill a handle slot;
##   site     - the Construction panel: tag + level gate, Fill Automatically, progress %, and the build
##              timer starting once every material is placed.
## Usage: godot --headless --path game --script res://tests/t_craftradial.gd -> "[t_craftradial] PASS".

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _world: Node
var _size := Vector2i.ZERO
var IS: GDScript
var CR: GDScript
var SM: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(170.0).timeout.connect(func () -> void:
		print("[t_craftradial] FAIL watchdog: the run did not finish in 170 s")
		quit(1))
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_craftradial] %s %dx%d %s" % ["ok" if ok else "FAIL", _size.x, _size.y, what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	CR = load("res://scripts/items/crafting.gd")
	SM = load("res://scripts/ui/station_menu.gd")
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "TCraftRadialHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_world.home_claims = []
	_world.unstable_claims = []
	_world.free_claim_used = false
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_test_tags()
	for s in [Vector2i(1600, 900), Vector2i(844, 390)]:
		_size = s
		root.size = s
		root.content_scale_size = s
		await _frames(3)
		await _test_radial()
		await _test_panel()
	await _test_site()
	await _test_plot()
	if _fails.is_empty():
		print("[t_craftradial] PASS")
		quit(0)
	else:
		print("[t_craftradial] FAIL count=%d" % _fails.size())
		quit(1)

func _bag(items: Array) -> void:
	var inv = _player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null
	for row in items:
		inv.add(IS.make(StringName(row[0]), int(row[1]), row[3] if row.size() > 3 else {}, int(row[2]) if row.size() > 2 else -1))
	inv.changed.emit()

func _station(kind: StringName) -> Node3D:
	var st: Node3D
	if kind == &"basket":
		st = load("res://scripts/world/placed_building.gd").make(&"basket")
	else:
		st = load("res://scripts/world/craft_station.gd").make(kind)
	_host.add_child(st)
	st.global_position = _player.global_position + Vector3(1.5, 0, 0)
	return st

func _wedges(menu) -> Array:
	return menu._buttons.map(func (b) -> String: return str(b.name))

# ---------------------------------------------------------------- radial

func _test_radial() -> void:
	var sc = _player.station_craft
	var menu = sc.menu
	var cases := {&"workbench": "CRAFT", &"stone_grill": "COOK", &"basket": "OPEN"}
	for kind in cases:
		var st := _station(kind)
		await _frames(1)
		sc.open_station_menu(st)
		await _frames(2)
		menu.snap_open()
		var w: Array = _wedges(menu)
		var main_label: String = str(menu._buttons[0].bottom_text) if not menu._buttons.is_empty() else ""
		_expect(menu.visible and main_label == cases[kind] and w.has("Wedge_package") and w.back() == "Wedge_remove",
			"%s: the radial leads with %s, then PACKAGE and REMOVE (%s, %s)" % [kind, cases[kind], main_label, w])
		var top_ok := true
		for b in menu._buttons:
			top_ok = top_ok and menu._buttons[0].position.y <= b.position.y + 0.5
		_expect(top_ok, "%s: the main wedge sits on top of the ring" % kind)
		var pk: Control = menu.find_child("Wedge_package", false, false)
		var rmv: Control = menu.find_child("Wedge_remove", false, false)
		var c: Vector2 = menu._ring_center
		var hh := Vector2(pk.size.x, pk.size.y) * 0.5 if pk else Vector2.ZERO
		_expect(pk != null and rmv != null and pk.position.x + hh.x < c.x and pk.position.y + hh.y > c.y and rmv.position.x + hh.x > c.x and rmv.position.y + hh.y > c.y,
			"%s: PACKAGE sits bottom-left and REMOVE bottom-right, every time" % kind)
		var small: Array = menu._buttons.filter(func (b) -> bool: return b.size.x < 63.5 or b.size.y < 63.5)
		_expect(small.is_empty(), "%s: every wedge is >= 64 px" % kind)
		var card: Control = menu.info_card
		_expect(card != null and card.get_global_rect().position.x < float(_size.x) * 0.5 and card.get_global_rect().position.y < float(_size.y) * 0.5,
			"%s: the info card sits top left" % kind)
		var outs: Array = SM.outputs_for(kind)
		if outs.is_empty():
			_expect(menu.output_row == null, "%s: no recipes, no output row" % kind)
		else:
			var slots: Array = menu.output_row.get_child(0).get_children()
			_expect(slots.size() == outs.size() and slots.all(func (c) -> bool: return c.custom_minimum_size.y >= 64.0),
				"%s: the output row lists the station's %d outputs at >= 64 px (%d)" % [kind, outs.size(), slots.size()])
			_expect(Rect2(Vector2.ZERO, Vector2(_size)).encloses(menu.output_row.get_global_rect()), "%s: the output row is on screen" % kind)
		menu.hide_menu()
		st.queue_free()
		await _frames(1)
	_expect((SM.actions_for(&"makeshift_taming_pen", _player)[0] as Dictionary).get("id") == &"pen", "the taming pen's top wedge is PEN")
	await _test_fixed_slots()
	# Output slot -> craft panel on that recipe.
	var wb := _station(&"workbench")
	await _frames(1)
	sc.open_station_menu(wb)
	await _frames(2)
	var first: Node = menu.output_row.get_child(0).get_child(0)
	var rid: StringName = first.recipe
	first.pressed.emit()
	await _frames(2)
	var craft = _player.craft_ui
	_expect(craft.visible and craft._phone_detail and craft._selected_id == str(rid) and craft._station == "workbench",
		"an output slot opens recipe %s in the craft panel (selected %s)" % [rid, craft._selected_id])
	craft.hide_ui()
	await _frames(1)
	# Remove asks first.
	sc.open_station_menu(wb)
	await _frames(2)
	menu._on_pressed(&"remove")
	await _frames(1)
	_expect(is_instance_valid(wb) and not wb.is_queued_for_deletion() and menu.remove_armed and menu.visible,
		"REMOVE asks for confirmation before demolishing")
	var rm: Variant = menu.find_child("Wedge_remove", false, false)
	_expect(rm != null and rm.bottom_text == "CONFIRM", "the REMOVE wedge turns into CONFIRM")
	menu._on_pressed(&"remove")
	await _frames(1)
	_expect(not is_instance_valid(wb) or wb.is_queued_for_deletion(), "the second tap demolishes the workbench")
	await _frames(1)
	# Package returns the kit.
	var wb2 := _station(&"workbench")
	_bag([])
	await _frames(1)
	sc.open_station_menu(wb2)
	await _frames(2)
	menu._on_pressed(&"package")
	await _frames(1)
	_expect(_player.inventory.count_of(&"workbench_kit") == 1 and (not is_instance_valid(wb2) or wb2.is_queued_for_deletion()),
		"PACKAGE puts the workbench kit in the bag and takes the station away")

## Kingdom Rush slots: the same offsets from the station on every open and at another camera angle,
## and no drift while the camera holds still.
func _test_fixed_slots() -> void:
	var sc = _player.station_craft
	var menu = sc.menu
	var st := _station(&"workbench")
	await _frames(1)
	var runs: Array = []
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	for k in 3:
		if k == 2 and cam:
			cam.rotate_y(0.35)  # another angle (the iso camera may pull it back; offsets must not care)
		sc.open_station_menu(st)
		await _frames(2)
		menu.snap_open()
		var rel: Array = []
		for b in menu._buttons:
			rel.append(b.position - menu._ring_center)
		runs.append(rel)
		if k == 0:  # still camera: nothing moves over a dozen frames
			var before: Array = menu._buttons.map(func (b) -> Vector2: return b.position)
			await _frames(12)
			var drift := 0.0
			for i in before.size():
				drift = maxf(drift, (before[i] as Vector2).distance_to(menu._buttons[i].position))
			_expect(drift <= 1.0, "a still camera: the wedges hold within 1 px (%.2f)" % drift)
		menu.hide_menu()
		await _frames(1)
	if cam:
		cam.rotate_y(-0.35)
	var same := true
	for k in [1, 2]:
		for i in (runs[0] as Array).size():
			same = same and ((runs[0] as Array)[i] as Vector2).distance_to((runs[k] as Array)[i]) < 0.5
	_expect(same and (runs[0] as Array).size() == 3, "each action keeps its slot across opens and camera angles (%s)" % [runs])
	st.queue_free()
	await _frames(1)

# ---------------------------------------------------------------- panel

func _test_panel() -> void:
	var craft = _player.craft_ui
	craft.toggle()
	await _frames(2)
	var sheet: Control = craft.find_child("CraftSheet", true, false)
	var r: Rect2 = sheet.get_global_rect()
	_expect(craft.visible and absf(r.end.x - float(_size.x)) < 1.0 and r.position.x > float(_size.x) * 0.2, "the craft panel pops out on the right (%s)" % r)
	_expect(craft.find_child("Cat_weapon", true, false) != null and craft.find_child("Cat_tool", true, false) != null and craft.find_child("Cat_construction", true, false) != null,
		"category tabs include Tool, Weapon and Building Components")
	var small: Array = []
	for c in craft.find_children("*", "Control", true, false):
		if (c is BaseButton or c is LineEdit) and c.is_visible_in_tree() and (c.size.x < 63.5 or c.size.y < 63.5):
			small.append(c.name)
	_expect(small.is_empty(), "every tap target in the panel is >= 64 px (%s)" % [small])
	(craft.find_child("Cat_weapon", true, false) as Button).pressed.emit()
	await _frames(1)
	var shown: Array = craft._shown_recipes()
	_expect(not shown.is_empty() and shown.all(func (rec) -> bool: return craft.in_category(rec, "weapon")), "the Weapon tab narrows the list (%d)" % shown.size())
	(craft.find_child("Cat_all", true, false) as Button).pressed.emit()
	craft._search.text = "plank"
	craft._search.text_changed.emit("plank")
	await _frames(1)
	shown = craft._shown_recipes()
	_expect(not shown.is_empty() and shown.all(func (rec) -> bool: return craft._output_name(rec).to_lower().contains("plank")), "search narrows to planks (%d)" % shown.size())
	craft._search.text = ""
	craft._search.text_changed.emit("")
	craft.hide_ui()
	await _frames(1)

# ---------------------------------------------------------------- tags

func _test_tags() -> void:
	var into: Array = CR.recipes_accepting(&"large_leg_bone").map(func (r) -> String: return str(r.get("id", "")))
	_expect(into.has("plank"), "a large leg bone's craft-into list has Plank (%s)" % [into])
	_bag([["large_leg_bone", 2, 10]])
	var rec: Dictionary = CR.recipe(&"plank")
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	_expect(CR.picks_valid(_player.inventory, rec, picks), "two leg bones fill the plank's Thick Pillar slot")
	var made: Variant = _craft(rec, picks)
	_expect(made != null and _player.inventory.count_of(&"plank") == 1 and _player.inventory.count_of(&"large_leg_bone") == 0, "the bones became a plank")
	var silver_into: Array = CR.recipes_accepting(&"silver_chunk").map(func (r) -> String: return str(r.get("id", "")))
	_expect(silver_into.has("metal_stick") and silver_into.has("metal_nails_from_chunk"), "silver's craft-into list has Metal Stick and Metal Nail (%s)" % [silver_into])
	_bag([["silver_chunk", 1, 50, {"firm": 4}]])
	rec = CR.recipe(&"metal_stick")
	picks = CR.default_picks(_player.inventory, rec)
	_craft(rec, picks)
	var sticks: Array = []
	for s in _player.inventory.slots:
		if s and s.def_id == &"metal_stick":
			for _n in s.count:
				sticks.append(s)
	_expect(sticks.size() == 2, "a silver chunk makes 2 metal sticks (%d)" % sticks.size())
	_expect(sticks.all(func (s) -> bool: return int(s.attributes.get("firm", 0)) == 4), "each stick inherits Firm 4")
	_expect(CR.recipes_accepting(&"metal_stick").any(func (r) -> bool: return str(r.get("id", "")) == "club"), "a metal stick fills a handle (stick) slot: the club takes it")
	_bag([])

## The craft itself, past the skill-node and station-range gates (other tests own those): Crafting's
## own plan and run, so the tag chain and the output are what crafting really makes.
func _craft(rec: Dictionary, picks: Array[int]) -> Variant:
	var inv = _player.inventory
	var plan: Dictionary = CR.plan_craft(rec, inv, picks, 100.0, CR.crafted_level_for(rec, CR.consumed_levels(inv, rec, picks), _player), 0)
	if plan.is_empty():
		return null
	plan["outcome"] = {"success": true, "flawless": false, "rare": &""}
	return CR.run_plan(rec, inv, plan).get("item", null)

# ---------------------------------------------------------------- Construction

func _test_site() -> void:
	_size = Vector2i(844, 390)
	var site = load("res://scripts/world/construction_site.gd").new()
	site.setup(&"basic_workbench", "Tester")
	_host.add_child(site)
	site.global_position = _player.global_position + Vector3(3, 0, 0)
	# planks need plank_shape Lv 10+: one too low, three good; pillars two; straps six.
	_bag([["plank_shape", 1, 5], ["plank_shape", 1, 12], ["plank_shape", 1, 30], ["plank_shape", 1, 20],
		["pillar_shape", 1, 15], ["pillar_shape", 1, 15], ["strap", 6, 3], ["stone", 3, 5]])
	var craft = _player.craft_ui
	craft.open_site(site)
	await _frames(2)
	var place = craft._place
	_expect(craft.visible and place.visible and place.site == site and craft._title.text == "Construction", "a site opens the Construction panel")
	var inv = _player.inventory
	var cands: Array = place.candidates(0)
	var lv_ok := cands.size() == 3 and cands.all(func (i) -> bool: return inv.slots[i].def_id == &"plank_shape" and inv.slots[i].level >= 10)
	_expect(lv_ok, "the plank slot takes plank shapes Lv 10+ only, not the Lv 5 one or stone (%s)" % [cands])
	place.toggle_pick(cands[0])
	await _frames(1)
	_expect(place.find_child("Cand_%d" % cands[0], true, false).order == 1 and place._cta.text == "Place Material", "a picked item gets badge 1 and the action reads Place Material")
	place.toggle_pick(cands[0])
	await _frames(1)
	_expect(place._cta.text == "Fill Automatically", "with nothing picked the action is Fill Automatically")
	place._on_cta()  # fill
	await _frames(1)
	var best: Array = place.picked[0]
	_expect(best.size() == 2 and inv.slots[best[0]].level == 30 and inv.slots[best[1]].level == 20, "Fill Automatically picks the best two plank shapes (%s)" % [best])
	_expect(place.picked[2].size() == 6, "and all six straps")
	place._on_cta()  # place
	await _frames(1)
	_expect(is_equal_approx(site.materials_ratio(), 1.0) and place._complete.text == "100%", "every material placed: 100%% (%s)" % place._complete.text)
	_expect(site.building, "placing the last material starts the build timer")
	var w0: float = site.work_progress
	await _frames(20)
	_expect(site.work_progress > w0, "the timer runs by itself (%.2f -> %.2f)" % [w0, site.work_progress])
	var timer: Label = place.find_child("SiteTimer", true, false)
	_expect(timer != null and timer.text.count(":") == 2, "the panel shows the build timer (%s)" % (timer.text if timer else "none"))
	craft.hide_ui()
	site.queue_free()

## Build page -> plot: the old placer's ghost (grid snap, rotate, confirm) places a construction plot
## with an empty bag; it finishes only once every slot group is filled and the timer ran.
func _test_plot() -> void:
	_bag([])
	_player.skills.trees["construction"] = {"level": 20, "xp": 0.0, "unlocked": ["workbench"]}
	var placer = _player.placer
	var before: Array = root.get_tree().get_nodes_in_group("construction_site")
	var placed := false
	for off in [Vector3(4, 0, 0), Vector3(-4, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, -4), Vector3(5, 0, 5)]:
		placer.begin_blueprint(&"basic_workbench")
		placer.aim_at(_player.global_position + off)
		await _frames(2)
		if placer.valid and placer.confirm(_player):
			placed = true
			break
		placer.cancel()
	await _frames(2)
	var sites: Array = root.get_tree().get_nodes_in_group("construction_site").filter(func (n) -> bool: return not before.has(n))
	_expect(placed and sites.size() == 1, "an empty bag still places a Basic Workbench plot (%s, reason %s)" % [placed, placer.reason])
	if not placed:
		return
	var site = sites[0]
	var BF: GDScript = load("res://scripts/items/build_flow.gd")
	_expect(site != null and BF.complete(_player, site) == null and is_instance_valid(site), "the empty plot does not complete")
	_expect(_player.craft_ui.visible and _player.craft_ui._place.site == site, "confirming the plot opens its Construction panel")
	_bag([["plank_shape", 1, 20], ["plank_shape", 1, 20], ["pillar_shape", 1, 20], ["pillar_shape", 1, 20], ["strap", 6, 5]])
	var place = _player.craft_ui._place
	place.auto_fill()
	place.place_picks()
	site.work(999.0)
	var done = BF.complete(_player, site)
	_expect(done != null, "every slot group filled and worked: the plot completes into a workbench")
	_player.craft_ui.hide_ui()
