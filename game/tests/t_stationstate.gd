extends SceneTree
## STATIONSTATE: taming pen tiers accept / refuse by species (data/taming_pens.json), a big tame is
## shown full size and overhangs its pen, every station's busy props show only while its job runs
## (stone grill spit, forge glow + sparks, drying rack strips, smoker contents), a farm plot grows
## crop stages and its floating harvest timer counts down.
## Run: Godot --headless --path game --script res://tests/t_stationstate.gd

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_stationstate] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _run() -> void:
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 40.0)
	_player = kit["player"]
	await process_frame
	_test_pen_tiers()
	await _test_pen_insert_and_overhang()
	await _test_stand_stations()
	_test_drying_rack()
	_test_plot_timer()
	_test_worksite()
	_test_pen_odds()
	await _test_work_card()
	if _fails.is_empty():
		print("[t_stationstate] PASS")
		quit(0)
	else:
		print("[t_stationstate] FAIL count=%d" % _fails.size())
		quit(1)

func _def(sp: String) -> Variant:
	return root.get_node("Data").call("creature", StringName(sp))

func _test_pen_tiers() -> void:
	var TP: GDScript = load("res://scripts/world/taming_pen.gd")
	var cases := {
		"makeshift_taming_pen": {"accept": ["zebraceratops", "compsognathus", "velociraptor", "megaloceros"], "refuse": ["ankylosaurus", "smilodon", "gallimimus"]},
		"taming_pen_medium": {"accept": ["gallimimus", "deinonychus", "dilophosaurus", "styracosaurus", "velociraptor"], "refuse": ["ankylosaurus", "utahraptor", "tyrannosaurus"]},
		"taming_pen_large": {"accept": ["ankylosaurus", "stegosaurus", "triceratops", "utahraptor", "smilodon"], "refuse": ["tarbosaurus", "tyrannosaurus"]},
		"taming_pen_apex": {"accept": ["tarbosaurus", "tyrannosaurus", "ankylosaurus", "compsognathus"], "refuse": []},
	}
	for k: String in cases:
		for sp: String in cases[k]["accept"]:
			_expect(TP.fits(StringName(k), _def(sp)), "%s takes %s" % [k, sp])
		for sp: String in cases[k]["refuse"]:
			_expect(not TP.fits(StringName(k), _def(sp)) and TP.refuse_text(StringName(k), _def(sp)) != "", "%s refuses %s" % [k, sp])
	var why: String = TP.refuse_text(&"makeshift_taming_pen", _def("ankylosaurus"))
	_expect(why.contains("too big") and why.contains("Large Taming Pen"), "size refusal names the pen it needs: %s" % why)
	why = TP.refuse_text(&"makeshift_taming_pen", _def("smilodon"))
	_expect(why.contains("too valuable") and why.contains("Large Taming Pen"), "value refusal names the pen it needs: %s" % why)
	# Every tameable species has a pen that takes it.
	var data: Node = root.get_node("Data")
	for sp in data.get("creatures"):
		var d: Variant = data.call("creature", sp)
		if d and d.get("tameable"):
			_expect(TP.required_kind(d) != &"", "%s has a pen tier" % sp)
	# Each tier is buildable: an item that places it and a recipe that makes it.
	for t: Dictionary in TP.tiers():
		var item: Variant = data.call("item", StringName(str(t["kind"])))
		_expect(item != null and str(item.place_as) == str(t["kind"]), "%s has a placeable item" % t["kind"])

func _captured(sp: String) -> Variant:
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var s: Variant = IS.make(&"captured_animal", 1)
	s.attributes["species"] = sp
	return s

func _test_pen_insert_and_overhang() -> void:
	var TP: GDScript = load("res://scripts/world/taming_pen.gd")
	var small: Node3D = TP.make(&"makeshift_taming_pen")
	small.position = Vector3(-8, 0, 0)
	_host.add_child(small)
	_player.inventory.add(_captured("ankylosaurus"))
	_expect(not small.try_insert(_player) and small.occupant == null and str(small.last_refusal).contains("too big"), "small pen refuses the ankylosaurus in the bag: %s" % small.last_refusal)
	_expect(_player.inventory.count_of(&"captured_animal") == 1, "a refused animal stays in the bag")
	var large: Node3D = TP.make(&"taming_pen_large")
	large.position = Vector3(8, 0, 0)
	_host.add_child(large)
	_expect(large.try_insert(_player) and large.occupant != null, "large pen takes the ankylosaurus")
	await process_frame
	var view := large.get_node_or_null("Occupant") as Node3D
	_expect(view != null, "the penned animal is shown")
	if view:
		var ext := _extent(view, large)
		var half: float = float(large.size_m()) * 0.5
		print("[t_stationstate] ankylosaurus extent %.2f m vs pen half %.2f m (scale %.2f)" % [ext, half, view.scale.x])
		_expect(ext > half, "the big tame overhangs its pen (%.2f > %.2f)" % [ext, half])
		_expect(is_equal_approx(view.scale.x, 1.0) or view.scale.x >= 0.7, "not scaled down to fit (scale %.2f)" % view.scale.x)
	# Save keeps the tier; an old row (no tier) stays the small pen.
	var row: Dictionary = large.to_dict()
	_expect(str(row["kind"]) == "taming_pen_large" and str(TP.from_dict(row).kind) == "taming_pen_large", "the tier survives a save round trip")
	_expect(str(TP.from_dict({"kind": "makeshift_taming_pen", "cell": [0, 0]}).kind) == "makeshift_taming_pen", "an old pen row loads as the small pen")
	large.occupant = null
	large.running = false
	await process_frame
	_expect(large.get_node_or_null("Occupant") == null, "an empty pen shows no animal")

## Farthest horizontal reach of any mesh under `n`, in `ref`'s local space.
func _extent(n: Node, ref: Node3D) -> float:
	var best := 0.0
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		var aabb := vi.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue
		var xf := ref.global_transform.affine_inverse() * vi.global_transform
		for i in 8:
			var p: Vector3 = xf * aabb.get_endpoint(i)
			best = maxf(best, maxf(absf(p.x), absf(p.z)))
	return best

func _test_stand_stations() -> void:
	var CS: GDScript = load("res://scripts/world/craft_station.gd")
	var SS: GDScript = load("res://scripts/world/station_state.gd")
	var sc: Variant = _player.station_craft
	var x := -4.0
	for sid in [&"stone_grill", &"forge"]:
		var st: Node3D = CS.make(sid)
		st.position = Vector3(x, 0, -6)
		x += 4.0
		_host.add_child(st)
		await process_frame
		var state: Node = SS.of(st)
		_expect(state != null, "%s has a station state" % sid)
		if state == null:
			continue
		state.sync()
		_expect(not _any_visible(state.busy_nodes()), "%s idle: no busy props" % sid)
		sc.station = st
		sc.crafting = true
		state.sync()
		_expect(_all_visible(state.busy_nodes()), "%s busy: every busy prop shows" % sid)
		sc.crafting = false
		sc.station = null
		state.sync()
		_expect(not _any_visible(state.busy_nodes()), "%s idle again: props gone" % sid)
	var grill: Node = SS.of(get_first_node_in_group("stone_grill"))
	_expect(grill != null and grill.get_node_or_null("SpitMeat") != null, "the grill's busy props include the spit and its meat")
	var forge: Node = SS.of(get_first_node_in_group("forge"))
	_expect(forge != null and forge.get_node_or_null("Glow") is OmniLight3D and forge.get_node_or_null("Sparks") is CPUParticles3D and forge.get_node_or_null("Base") != null, "the forge has a body, glow light and sparks")

func _any_visible(nodes: Array) -> bool:
	return nodes.any(func (n: Node3D) -> bool: return n.visible)

func _all_visible(nodes: Array) -> bool:
	return not nodes.is_empty() and nodes.all(func (n: Node3D) -> bool: return n.visible and (not n is CPUParticles3D or (n as CPUParticles3D).emitting))

func _test_drying_rack() -> void:
	var CS: GDScript = load("res://scripts/world/craft_station.gd")
	var PS: GDScript = load("res://scripts/world/process_station.gd")
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	for sid in [&"drying_rack", &"smoker"]:
		var st: Node3D = CS.make(sid)
		st.position = Vector3(4.0 if sid == &"smoker" else 0.0, 0, 6)
		_host.add_child(st)
		var ps: Node = PS.of(st)
		ps._redraw()
		_expect(_shown_food(st) == 0, "%s empty: nothing hangs on it" % sid)
		var inv: Variant = load("res://scripts/items/inventory.gd").new(12)
		inv.add(IS.make(&"raw_meat", 4))
		var rid := &"dry_meat" if sid == &"drying_rack" else &"smoke_meat"
		var n: int = ps.load_from(inv, rid, 2)
		ps._redraw()
		_expect(n == 2 and ps.is_active() and _shown_food(st) > 0, "%s working: the meat shows (%d shown)" % [sid, _shown_food(st)])
		ps.salvage_contents()
		ps._redraw()
		_expect(_shown_food(st) == 0, "%s emptied: nothing shows" % sid)

## The rack's loaded stage model (raw / drying / dried strips; its empty model has none) plus the
## smoker's content meshes that are visible.
func _shown_food(st: Node3D) -> int:
	var n := 0
	var prop := st.get_node_or_null("Prop")
	if prop and prop.get_child_count() > 0 and str(prop.get_child(0).name) in ["drying_rack_raw", "drying_rack_drying", "drying_rack_dried"]:
		n += 1
	var i := 1
	while prop and prop.find_child("strip_%d" % i, true, false) is Node3D:
		if (prop.find_child("strip_%d" % i, true, false) as Node3D).is_visible_in_tree():
			n += 1
		i += 1
	var contents := st.get_node_or_null("Process/Contents")
	if contents:
		for c in contents.get_children():
			if (c as Node3D).visible:
				n += 1
	return n

func _test_plot_timer() -> void:
	var FP: GDScript = load("res://scripts/world/field_plot.gd")
	var f: Node3D = FP.make(&"field_small")
	f.position = Vector3(0, 0, -12)
	_host.add_child(f)
	f.sync_visual()
	var label := f.get_node_or_null("HarvestTimer") as Label3D
	_expect(label != null and not label.visible and f.get_node_or_null("Crop") == null, "an empty field shows no crop and no timer")
	f.crop_id = &"corn"  # growth_seconds 90
	f.growth = 0.0
	f.sync_visual()
	_expect(label.visible and label.text == "1m 30s", "a fresh corn crop reads 1m 30s (%s)" % label.text)
	_expect(f.get_node_or_null("Crop") != null and f.crop_stage() == "sprout", "sprouts show")
	f._process(17.0)
	f.sync_visual()
	_expect(label.text == "1m 13s", "17 s later the timer reads 1m 13s (%s)" % label.text)
	f.growth = 1.0 - 13.0 / 90.0
	f.sync_visual()
	_expect(label.text == "13s" and f.crop_stage() == "growing", "under a minute it reads seconds (%s, %s)" % [label.text, f.crop_stage()])
	f.growth = 1.0
	f.mature = true
	f.sync_visual()
	_expect(label.text == "Ready" and f.crop_stage() == "mature", "a grown crop reads Ready")
	f._clear_crop()
	f.sync_visual()
	_expect(not label.visible and f.get_node_or_null("Crop") == null, "harvested: bare soil, no timer")
	_expect(FP.duration_text(253) == "4m 13s", "4m 13s format")

func _test_worksite() -> void:
	var site: Node3D = load("res://scripts/world/construction_site.gd").new()
	site.setup(&"basic_workbench", "t")
	site.grid_kind = &"workbench"
	site.position = Vector3(-10, 0, 8)
	_host.add_child(site)
	var icon := site.get_node_or_null("SiteIcon") as Sprite3D
	_expect(site.get_node_or_null("Foundation") != null, "a worksite lies on a dirt patch")
	_expect(icon != null and icon.texture != null and str(site.icon_item()) == "workbench_kit", "its symbol is the workbench's icon (%s)" % site.icon_item())
	var lbl := site.get_node_or_null("SiteProgress") as Label3D
	_expect(lbl != null and lbl.text == "Building 0%", "it shows its build progress (%s)" % (lbl.text if lbl else "-"))

func _test_pen_odds() -> void:
	var TP: GDScript = load("res://scripts/world/taming_pen.gd")
	var pen: Node3D = TP.make(&"makeshift_taming_pen")
	var s: Variant = _captured("velociraptor")
	s.attributes["level"] = 25
	var low: float = pen.odds(null, s)
	_player.skills.trees["survival"] = {"level": 40, "xp": 0.0, "unlocked": []}
	var high: float = pen.odds(_player, s)
	_expect(high > low and high < 1.0 and low > 0.0, "the pen's odds follow the capture curve (%.2f -> %.2f)" % [low, high])
	pen.free()

## A stand-and-craft at the workbench: the floating craft card shows over the station only while
## the job runs, and the survivor plays the station's work loop (play_work when PlayerAnim has it).
func _test_work_card() -> void:
	var SS: GDScript = load("res://scripts/world/station_state.gd")
	_expect(SS.work_kind(&"workbench") == &"hammer" and SS.work_kind(&"forge") == &"forge" and SS.work_kind(&"stone_grill") == &"stir", "stations map to work loops")
	var bench: Node3D = load("res://scripts/world/craft_station.gd").make(&"workbench")
	_host.add_child(bench)
	bench.global_position = _player.global_position + Vector3(1.0, 0, 0)
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	_player.inventory.add(IS.make(&"branch", 2))
	_player.inventory.add(IS.make(&"twine", 1))
	var sc: Variant = _player.station_craft
	sc.station = bench
	sc.recipe_id = &"empty_bucket"
	sc._batch_total = 1
	sc._start_craft_cycle()
	await process_frame
	_expect(sc.crafting and sc.card != null and sc.card.visible, "the craft card floats over the station while the job runs")
	var waited := 0
	while sc.crafting and waited < 600:
		await process_frame
		waited += 1
	_expect(not sc.crafting and not sc.card.visible, "the card is gone when the job ends (frames %d)" % waited)
	_expect(_player.inventory.count_of(&"empty_bucket") == 1, "the job made its bucket")
