extends SceneTree
## BUILDQUALITY acceptance (owner's spec 10 §§2-3, 6): a finished building's level comes from the
## exact material instances that went into it, the primary material's traits pass and only do what
## the blueprint supports, a construction site finished with mixed materials lands on the spec's
## level, save/load keeps level and traits, an old save without the fields loads sane, and a
## station's rare traits shorten its jobs / add a job slot.
## Run: Godot --headless --path game --script res://tests/t_buildquality.gd -> "[t_buildquality] PASS"
## Scripts are load()ed on the first frame: --script compiles this before the autoloads exist.

const TEST := "t_buildquality"

var _fails: PackedStringArray = []
var _started := false
var _BQ: GDScript
var _SP: GDScript
var _INV: GDScript
var _IS: GDScript
var _BLUEPRINTS: GDScript
var _BF: GDScript
var _SITE: GDScript
var _CS: GDScript
var _PS: GDScript
var _SPL: GDScript
var _SHEET: GDScript
var _player: Node3D
var _host: Node3D
var _rt: Node3D
var _bg: Node
var _sg: Variant   # StructureGrid (a RefCounted, not a Node)
var _site := Vector2i.ZERO
var _floor0 := 0.0

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[%s] FAIL %s" % [TEST, what])
	else:
		print("[%s] ok %s" % [TEST, what])

func _run() -> void:
	_BQ = load("res://scripts/world/building_quality.gd")
	_SP = load("res://scripts/world/structure_piece.gd")
	_SPL = load("res://scripts/world/structure_placer.gd")
	_SHEET = load("res://scripts/world/structure_sheet.gd")
	_INV = load("res://scripts/items/inventory.gd")
	_IS = load("res://scripts/items/item_stack.gd")
	_BLUEPRINTS = load("res://scripts/items/blueprints.gd")
	_BF = load("res://scripts/items/build_flow.gd")
	_SITE = load("res://scripts/world/construction_site.gd")
	_CS = load("res://scripts/world/craft_station.gd")
	_PS = load("res://scripts/world/process_station.gd")
	# A hung test must never hold the gate's slot.
	get_root().get_tree().create_timer(60.0).timeout.connect(func () -> void:
		print("[%s] FAIL watchdog" % TEST)
		quit(1))
	_host = Node3D.new()
	_host.name = "TBuildQualityHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	_player = kit["player"]
	var world: Node = root.get_node("World")
	world.set("home_terrain", &"meadow")
	world.call("load_island", _host, &"home_grassland", Vector3(0, 1, 12), false)
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await process_frame
	await physics_frame
	_player.skills.trees["construction"]["level"] = 40
	_rt = world.get("runtime")
	_bg = _rt.get("build_grid")
	_sg = _bg.get("structures")
	_bg.set("ignore_distance", true)
	var around: Vector2i = _sg.call("module_of", Vector3(0, 0, 12))
	_rt.claims.append(Rect2i(around * 2 - Vector2i(60, 60), Vector2i(120, 120)))
	_site = _find_site(around)
	_test_engine()
	_test_pieces()
	_test_traits_and_effects()
	_test_storage_capacity()
	_test_inspect_text()
	_test_save_load()
	_test_old_save()
	await _test_site_mixed_materials()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[%s] PASS" % TEST)
		quit(0)
	else:
		print("[%s] FAIL count=%d" % [TEST, _fails.size()])
		quit(1)

# ------------------------------------------------------------------ fixtures

func _find_site(around: Vector2i) -> Vector2i:
	var best := around
	var best_span := INF
	for dz in range(-9, 10):
		for dx in range(-9, 10):
			var o: Vector2i = around + Vector2i(dx, dz)
			var ok := true
			var lo := INF
			var hi := -INF
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c: Vector2i = o + d
				var span: Vector2 = _sg.call("_terrain_span", c)
				ok = ok and str(_sg.check(&"foundation", Vector4i(c.x, c.y, 0, _SP.CELL), 0, &"thatch")["reason"]) == ""
				lo = minf(lo, span.x)
				hi = maxf(hi, span.y)
			if ok and hi - lo < best_span:
				best_span = hi - lo
				best = o
	return best

func _give(id: StringName, n: int, level: int, attrs: Dictionary = {}) -> void:
	for _i in n:
		_player.inventory.add(_IS.make(id, 1, attrs, level))

## A piece placed through StructurePlacer's real path (pay + quality) at the site's module.
func _place(kind: StringName, tier: StringName, slot: Vector4i, rot: int = 0) -> Variant:
	var res: Dictionary = _sg.check(kind, slot, rot, tier)
	if str(res["reason"]) != "":
		_expect(false, "setup: %s %s refused (%s)" % [tier, kind, res["reason"]])
		return null
	var at := {"slot": slot, "rot": rot, "floor0": float(res["floor0"]), "variant": int(res["variant"]),
		"span": int(res.get("span", 0)), "reason": ""}
	var out: Dictionary = _SPL.place(_sg, _rt, kind, tier, at, _player)
	if str(out.get("reason", "")) != "":
		_expect(false, "setup: %s %s place refused (%s)" % [tier, kind, out["reason"]])
		return null
	return out["piece"]

## Foundation the pad (the 2x2 the site finder validated) so pieces have floors to stand on.
func _pad_foundation(tier: StringName) -> Variant:
	var first: Variant = null
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var cost: Dictionary = _SP.cost(&"foundation", tier)
		for id in cost:
			_player.inventory.consume(id, _player.inventory.count_of(id))
			_give(id, int(cost[id]), 1)
		var f: Variant = _place(&"foundation", tier, Vector4i(_site.x + d.x, _site.y + d.y, 0, _SP.CELL))
		if first == null:
			first = f
		if f != null:
			_floor0 = f.floor0
	return first

# ------------------------------------------------------------------ 1. the engine itself

func _test_engine() -> void:
	# Spec 10 §2: floor(mean), clamped by the blueprint and capped by Construction.
	_expect(_BQ.level([10, 10, 10, 10], 1, 60, 40) == 10, "four lv-10 units give level 10 (%d)" % _BQ.level([10, 10, 10, 10], 1, 60, 40))
	_expect(_BQ.level([9, 10], 1, 60, 40) == 9, "a mixed 9/10 averages down to 9 (%d)" % _BQ.level([9, 10], 1, 60, 40))
	_expect(_BQ.level([60, 60, 60, 60], 1, 60, 20) == 20, "a lv-20 Construction caps lv-60 materials to 20 (%d)" % _BQ.level([60, 60, 60, 60], 1, 60, 20))
	_expect(_BQ.level([60, 60, 60, 60], 1, 30, 60) == 30, "the blueprint max clamps to 30 (%d)" % _BQ.level([60, 60, 60, 60], 1, 30, 60))
	_expect(_BQ.level([], 1, 60, 40) == 1, "no level-contributing units lands on level 1")
	# Only the slot rows that declare it count for the level; traits come from the primary row alone.
	var slots := [
		{"role": "primary", "counts_for_level": true, "counts_for_attributes": true},
		{"role": "binding", "counts_for_level": true, "counts_for_attributes": false},
	]
	var taken := [[_IS.make(&"plank", 2, {}, 10)], [_IS.make(&"twine", 2, {}, 60)]]
	_expect(_BQ.contributing_levels(slots, taken) == [10, 10, 60, 60], "contributing units carry their own levels (%s)" % [_BQ.contributing_levels(slots, taken)])
	taken[0][0].attributes["high_density"] = 3
	taken[1][0].attributes["lightweight"] = 4
	var tr: Array = _BQ.primary_traits(slots, taken)
	_expect(tr.size() == 1 and str(tr[0]["id"]) == "high_density" and int(tr[0]["level"]) == 3,
		"only the primary material's trait passes, never the binding's (%s)" % [tr])
	taken[0][0].attributes.clear()
	_expect(_BQ.primary_traits(slots, taken).is_empty(), "a primary with no traits passes none")

# ------------------------------------------------------------------ 2. pieces

func _test_pieces() -> void:
	var f: Variant = _pad_foundation(&"wood")
	if f == null:
		return
	# A wood wall from lv-10 planks and twine versus one from lv-1: the first is the higher level.
	_player.inventory.consume(&"plank", _player.inventory.count_of(&"plank"))
	_player.inventory.consume(&"twine", _player.inventory.count_of(&"twine"))
	_give(&"plank", 8, 10)
	_give(&"twine", 4, 10)
	var hi: Variant = _place(&"wall", &"wood", Vector4i(_site.x, _site.y, 0, _SP.EDGE_Z))
	_player.inventory.consume(&"plank", _player.inventory.count_of(&"plank"))
	_player.inventory.consume(&"twine", _player.inventory.count_of(&"twine"))
	_give(&"plank", 4, 1)
	_give(&"twine", 2, 1)
	var lo: Variant = _place(&"wall", &"wood", Vector4i(_site.x, _site.y, 0, _SP.EDGE_X))
	if hi == null or lo == null:
		return
	_expect(hi.build_level == 10, "a wall from lv-10 materials is level 10 (%d)" % hi.build_level)
	_expect(lo.build_level == 1, "a wall from lv-1 materials is level 1 (%d)" % lo.build_level)
	_expect(hi.build_level > lo.build_level, "higher-level materials give a higher-level building (%d > %d)" % [hi.build_level, lo.build_level])

# ------------------------------------------------------------------ 3. traits and their effects

func _test_traits_and_effects() -> void:
	_player.inventory.consume(&"plank", _player.inventory.count_of(&"plank"))
	_player.inventory.consume(&"twine", _player.inventory.count_of(&"twine"))
	_give(&"plank", 4, 10, {"high_density": 3})
	# The binding carries a trait too: it must stay behind (spec 10 §3, primary material only).
	_give(&"twine", 2, 10, {"lightweight": 5})
	var wall: Variant = _place(&"wall", &"wood", Vector4i(_site.x + 1, _site.y, 0, _SP.EDGE_Z))
	if wall == null:
		return
	var ids: Array = wall.inherited_attributes.map(func (r: Dictionary) -> String: return str(r["id"]))
	_expect(ids == ["high_density"], "the wall carries only the primary's trait (%s)" % [ids])
	_expect(wall.quality_durability == 6, "High Density Lv 3 adds +2 durability per level on a wall (%d)" % wall.quality_durability)
	var base: float = _SP.max_durability(&"wall", &"wood")
	_expect(absf(float(wall.health.max_hp) - (base + 6.0)) < 0.01, "the wall's max durability includes the trait (%0.f, want %.0f)" % [wall.health.max_hp, base + 6.0])
	_expect(float(wall.health.hp) == float(wall.health.max_hp), "a fresh wall is at full durability (%.0f/%.0f)" % [wall.health.hp, wall.health.max_hp])
	# An effect the blueprint does not support is carried, shown, and never applied: a wall gains no
	# storage from Lightweight, and a piece without storage has none at all.
	var wall_light: Dictionary = _BQ.effects(["durability"], [{"id": "lightweight", "level": 4}], false)
	_expect(int(wall_light["storage_space"]) == 0 and int(wall_light["durability"]) == 0,
		"Lightweight does nothing on a wall that does not support storage (%s)" % [wall_light])
	var lines: PackedStringArray = _BQ.effect_lines([{"id": "lightweight", "level": 4}], wall_light)
	_expect(lines.size() == 1 and "(no effect here)" in lines[0], "the card says the trait has no effect here (%s)" % [lines])

# ------------------------------------------------------------------ 4. storage capacity

func _test_storage_capacity() -> void:
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	_player.inventory.consume(&"fibre_stalk", _player.inventory.count_of(&"fibre_stalk"))
	_give(&"branch", 6, 10, {"lightweight": 2})
	_give(&"fibre_stalk", 4, 10)
	var chest: Variant = _place(&"chest", &"thatch", Vector4i(_site.x + 1, _site.y + 1, 0, _SP.ON_FLOOR), 0)
	if chest == null:
		return
	var base := int(_SP.piece_def(&"chest").get("storage_slots", 0))
	_expect(chest.quality_storage == 6, "Lightweight Lv 2 adds +3 spaces per level to a chest (%d)" % chest.quality_storage)
	_expect(chest.storage != null and chest.storage.slot_count == base + 6, "the chest's container grew to %d slots (%s)" % [base + 6, chest.storage.slot_count if chest.storage else "null"])
	# A Heavy primary shrinks it again, but only while the slots it drops are empty.
	_player.inventory.consume(&"branch", _player.inventory.count_of(&"branch"))
	_player.inventory.consume(&"fibre_stalk", _player.inventory.count_of(&"fibre_stalk"))
	_give(&"branch", 6, 10, {"heavy": 2})
	_give(&"fibre_stalk", 4, 10)
	var box: Variant = _place(&"large_box", &"thatch", Vector4i(_site.x, _site.y + 1, 0, _SP.ON_FLOOR), 0)
	if box != null:
		var bbase := int(_SP.piece_def(&"large_box").get("storage_slots", 0))
		_expect(box.quality_storage == -6 and box.storage.slot_count == bbase - 6, "Heavy Lv 2 takes 6 spaces off a large box (%d of %d)" % [box.storage.slot_count, bbase])

# ------------------------------------------------------------------ 4b. inspect text

func _test_inspect_text() -> void:
	# The piece card's lines: level + traits on top, one line per trait, the durability it added, and
	# a storage piece's capacity. The same function fills the sheet, so this is the real text.
	var wall: Variant = null
	for p in _sg.pieces():
		if p.kind == &"wall" and not p.inherited_attributes.is_empty():
			wall = p
			break
	if wall == null:
		_expect(false, "setup: a trait-carrying wall exists for the inspect text")
		return
	var lines: PackedStringArray = _SHEET.card_lines(wall)
	_expect(lines.size() >= 3 and lines[0].begins_with("Lv ") and lines[0].contains("High Density"),
		"the wall's card names its level and trait (%s)" % [lines])
	_expect(lines[1].contains("durability"), "the card says what the trait did (%s)" % [lines[1]])
	_expect(lines[lines.size() - 1].contains("Durability"), "the card shows the trait's durability bonus (%s)" % [lines[lines.size() - 1]])
	var chest: Variant = null
	for p in _sg.pieces():
		if p.kind == &"chest":
			chest = p
			break
	if chest != null:
		var clines: PackedStringArray = _SHEET.card_lines(chest)
		_expect(clines[clines.size() - 1].contains("slots") and clines[clines.size() - 1].contains(str(chest.storage.slot_count)),
			"the chest's card shows its real capacity (%s)" % [clines[clines.size() - 1]])
	# A plain piece (no traits) still shows its level, and no invented bonus lines.
	var plain: Variant = null
	for p in _sg.pieces():
		if p.inherited_attributes.is_empty():
			plain = p
			break
	if plain != null:
		var plines: PackedStringArray = _SHEET.card_lines(plain)
		_expect(plines.size() >= 1 and plines[0] == "Lv %d" % plain.build_level, "a plain piece's card is just its level (%s)" % [plines])

# ------------------------------------------------------------------ 5. save / load

func _test_save_load() -> void:
	var pieces: Array = _sg.pieces()
	if pieces.is_empty():
		_expect(false, "setup: no pieces to save")
		return
	var want := {}
	for p in pieces:
		want[str(p.uid)] = [p.build_level, p.inherited_attributes.duplicate(true), p.quality_durability, p.quality_storage]
	var bad := 0
	for p in pieces:
		var back: Variant = _SP.from_dict(p.to_dict())
		var w: Array = want[str(p.uid)]
		if back == null or back.build_level != int(w[0]) or str(back.inherited_attributes) != str(w[1]) or back.quality_durability != int(w[2]) or back.quality_storage != int(w[3]):
			bad += 1
			print("[%s] round trip differs: %s vs %s" % [TEST, str(w), str([back.build_level, back.inherited_attributes, back.quality_durability, back.quality_storage]) if back else "null"])
	_expect(bad == 0, "every piece keeps its level, traits and quality on a save round trip (%d differ)" % bad)
	# A level-10 wall with High Density in a save keeps both, and its durability bonus.
	var wall: Variant = null
	for p in pieces:
		if p.kind == &"wall" and p.build_level == 10 and not p.inherited_attributes.is_empty():
			wall = p
			break
	if wall != null:
		var row: Dictionary = wall.to_dict()
		var back2: Variant = _SP.from_dict(row)
		_expect(back2.build_level == 10 and back2.inherited_attributes.size() == 1 and back2.inherited_attributes[0]["id"] == "high_density",
			"the saved lv-10 High Density wall comes back with both (%d, %s)" % [back2.build_level, back2.inherited_attributes])
		_expect(back2.health.max_hp == wall.health.max_hp, "its trait durability comes back (%.0f = %.0f)" % [back2.health.max_hp, wall.health.max_hp])

# ------------------------------------------------------------------ 6. an old save

func _test_old_save() -> void:
	var row := {"kind": "wall", "tier": "wood", "position": [_site.x, _site.y, 0, _SP.EDGE_Z], "rotation": 0,
		"floor_y": 0.0, "variant": 0, "current_durability": 300.0}
	var p: Variant = _SP.from_dict(row)
	_expect(p != null and p.build_level == 1 and p.inherited_attributes.is_empty() and p.quality_durability == 0,
		"a save row without the quality fields loads as a sane level-1, trait-less piece (%s/%s)" % [p.build_level if p else "null", p.inherited_attributes if p else "null"])
	# Garbage in the trait list is dropped rather than trusted.
	var junk := row.duplicate(true)
	junk["inherited_attributes"] = [{"id": "high_density", "level": 900}, {"id": "", "level": 3}, "oops", {"id": "firm", "level": "x"}]
	var q: Variant = _SP.from_dict(junk)
	_expect(q != null and q.inherited_attributes.size() == 1 and int(q.inherited_attributes[0]["level"]) == 60,
		"a malformed trait row is clamped and the junk dropped (%s)" % [q.inherited_attributes if q else "null"])
	# A station row from before the fields keeps its level and gains no traits.
	var srow := {"kind": "workbench", "station_level": 7, "station_tags": ["workbench"], "cell": [0, 0], "rot": 0}
	var st: Variant = _CS.from_dict(srow)
	_expect(st != null and st.station_level == 7 and st.inherited_attributes.is_empty() and is_equal_approx(st.quality_duration_mult, 1.0),
		"an old station row keeps its level and has no traits (%s)" % [st.station_level if st else "null"])

# ------------------------------------------------------------------ 7. a site, mixed materials, a station

func _learn_workbench() -> void:
	var sk: Node = _player.skills
	sk.trees["construction"]["level"] = 40
	sk._learn_autos("construction")
	sk.sp_extra = 400
	sk._recount_sp()
	if not sk.is_unlocked("construction", "bonfire"):
		sk.unlock("construction", "bonfire")
	if not sk.is_unlocked("construction", "workbench"):
		sk.unlock("construction", "workbench")

func _free_cell() -> Vector2i:
	var first: Variant = _rt.claims[0]
	for z in range(first.position.y, first.end.y):
		for x in range(first.position.x, first.end.x):
			var c := Vector2i(x, z)
			if _bg.can_place(&"workbench", c, 0) == "":
				return c
	return Vector2i.ZERO

func _test_site_mixed_materials() -> void:
	_learn_workbench()
	var cell := _free_cell()
	var site: Variant = _BF.place_site(_player, &"basic_workbench", cell, 0)
	if site == null:
		_expect(false, "setup: the workbench site is placed")
		return
	await process_frame
	# Mixed materials: two lv-20 plank shapes and two lv-4 pillars average to 12 (the spec's formula).
	_player.inventory.consume(&"plank_shape", _player.inventory.count_of(&"plank_shape"))
	_player.inventory.consume(&"pillar_shape", _player.inventory.count_of(&"pillar_shape"))
	_player.inventory.consume(&"strap", _player.inventory.count_of(&"strap"))
	_give(&"plank_shape", 2, 20, {"split_easily": 2})
	_give(&"pillar_shape", 2, 12)
	_give(&"strap", 6, 1)
	for slot in site.slot_count():
		while site.deposited(slot) < site.needed(slot):
			if not site.deposit(slot, site.first_fitting(_player.inventory, slot)):
				break
	_expect(site.materials_ready(), "the site has every slot filled")
	var lvls: Array = site.contributing_levels()
	_expect(lvls.size() == 4, "four level-contributing instances are counted (%s)" % [lvls])
	var want_level: int = _BLUEPRINTS.result_level(site.bp(), lvls, 40)
	_expect(want_level == 16, "the mixed site averages to the spec's level 16 ((20+20+12+12)/4) (%d from %s)" % [want_level, lvls])
	_expect(site.preview_level(40) == 16, "the site's preview shows the same level (%d)" % site.preview_level(40))
	var traits: Array = site.contributing_traits()
	_expect(traits.size() == 1 and str(traits[0]["id"]) == "split_easily", "the site previews the primary material's trait (%s)" % [traits])
	var prev: Dictionary = site.preview_effects()
	_expect(is_equal_approx(float(prev.get("duration_mult", 1.0)), 0.9), "Split Easily Lv 2 shortens jobs by 10%% on a station (%s)" % [prev.get("duration_mult", 1.0)])
	site.work(999.0)
	_expect(site.ready_to_finish(), "the site is finished")
	var station: Variant = _BF.complete(_player, site)
	_expect(station != null, "completion makes one station")
	if station == null:
		return
	_expect(station.station_level == 16, "the finished station is level 16 (%d)" % station.station_level)
	_expect(station.inherited_attributes.size() == 1 and str(station.inherited_attributes[0]["id"]) == "split_easily",
		"the finished station carries the primary's trait (%s)" % [station.inherited_attributes])
	_expect(is_equal_approx(station.quality_duration_mult, 0.9), "the station's jobs run 10%% shorter (%.2f)" % station.quality_duration_mult)
	var ps: Variant = _PS.of(station)
	var base_secs: float = _PS.job_seconds(&"workbench", &"trimmed_plank")
	_expect(ps != null and absf(ps.effective_seconds(&"trimmed_plank") - base_secs * 0.9) < 0.01,
		"its process station runs trimmed_plank 10%% shorter (%.1fs of %.0fs)" % [ps.effective_seconds(&"trimmed_plank") if ps else -1.0, base_secs])
	_expect(ps != null and ps.quality_duration_mult == station.quality_duration_mult, "the ProcessStation took the station's duration effect")
	# The station keeps its quality across a save round trip.
	var back: Variant = _CS.from_dict(station.to_dict())
	_expect(back.station_level == 16 and back.inherited_attributes.size() == 1 and is_equal_approx(back.quality_duration_mult, 0.9),
		"the station keeps level and traits across a save (%d, %s)" % [back.station_level, back.inherited_attributes])
	# A rare trait that grants a job slot (More Space).
	var slot_eff: Dictionary = _BQ.effects([], [{"id": "vivid_inspiration", "level": 1}], true)
	_expect(int(slot_eff.get("slots", 0)) == 1, "Vivid Inspiration Lv 1 adds a station job slot (%s)" % [slot_eff.get("slots", 0)])
	if ps != null:
		var before: int = ps.capacity()
		ps.quality_slots = int(slot_eff.get("slots", 0))
		_expect(ps.capacity() == before + 1, "the added slot raises the station's job capacity (%d -> %d)" % [before, ps.capacity()])
	# A second site whose primary material is High Density: the station's durability carries it, and
	# its preview level equals the finished one (spec 10 §10 "previews use the same calculation").
	await _test_station_durability()

## A station built from High Density planks gets the durability effect through BuildFlow.complete.
func _test_station_durability() -> void:
	var cell := _free_cell()
	var site: Variant = _BF.place_site(_player, &"basic_workbench", cell, 0)
	if site == null:
		_expect(false, "setup: the second workbench site is placed")
		return
	await process_frame
	_player.inventory.consume(&"plank_shape", _player.inventory.count_of(&"plank_shape"))
	_player.inventory.consume(&"pillar_shape", _player.inventory.count_of(&"pillar_shape"))
	_player.inventory.consume(&"strap", _player.inventory.count_of(&"strap"))
	_give(&"plank_shape", 2, 30, {"high_density": 4})
	_give(&"pillar_shape", 2, 30)
	_give(&"strap", 6, 1)
	for slot in site.slot_count():
		while site.deposited(slot) < site.needed(slot):
			if not site.deposit(slot, site.first_fitting(_player.inventory, slot)):
				break
	if not site.materials_ready():
		_expect(false, "setup: the second site has its materials")
		return
	site.work(999.0)
	var preview: int = site.preview_level(40)
	var station: Variant = _BF.complete(_player, site)
	if station == null:
		_expect(false, "the High Density site completes")
		return
	_expect(station.station_level == preview, "a station finishes at exactly the level its site previewed (%d = %d)" % [station.station_level, preview])
	_expect(station.quality_durability == 8, "High Density Lv 4 adds +2 durability per level to the station (%d)" % station.quality_durability)
	var h: Variant = station.get_node_or_null("StructureHealth")
	var base: float = float(_SP.placed_kind(&"workbench").get("max_durability", 0.0))
	_expect(h != null and absf(float(h.max_hp) - (base + 8.0)) < 0.01, "the station's max durability includes the trait (%.0f, want %.0f)" % [float(h.max_hp) if h else -1.0, base + 8.0])
	_expect(station.get("quality_chip_text") == null or str(station.call("quality_chip_text")).contains("High Density"),
		"the station's inspect text names the inherited trait (%s)" % [str(station.call("quality_chip_text"))])
