extends SceneTree
## W2-BUILDSYS acceptance: the modular building system on the real island. Checks structures.json data
## (a blueprint per piece and tier, tier ranks, rising durability, real items, kit durability rows),
## material costs (table + the placer spending exactly them), every placement refusal reason, socket
## snapping and rotation, support and collapse, tier damage multipliers and real creature bites, kit
## durability, camp/cargo immunity, catapult hits, repair and in-place upgrade costs and gates, owner
## vs creature paths through walls and closed doors, save-row round trips with clamping, malformed
## rows, and save schema migration to 4.
## Run: Godot --headless --path game --script res://tests/t_buildsys.gd
## Game classes are load()ed on the first frame (`--script` compiles this file before autoloads exist).

var _fails: PackedStringArray = []
var _case_fails := 0
var _started := false
var _SP: GDScript  # structure_piece.gd
var _BG: GDScript  # build_grid.gd
var _SH: GDScript  # structure_health.gd (test 7)
var _player: Variant
var _sg: Variant   # StructureGrid
var _bg: Variant   # BuildGrid
var _rt: Node     # IslandRuntime
var _host: Node3D
var _site := Vector2i.ZERO
var _claims_base: Array = []

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true ; _run()
	return false

# ------------------------------------------------------------------ harness

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what) ; print("[t_buildsys] FAIL %s" % what)

func _begin_case() -> void:
	_case_fails = _fails.size()

func _done(name: String, extra: String = "") -> void:
	if _fails.size() == _case_fails:
		print("[t_buildsys] ok %s%s" % [name, extra])

func _run() -> void:
	_SP = load("res://scripts/world/structure_piece.gd") ; _BG = load("res://scripts/world/build_grid.gd")
	_host = Node3D.new() ; _host.name = "TBuildsysHost"
	root.add_child(_host) ; var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	_player = kit["player"] ; var world: Node = root.get_node("World")
	world.set("home_terrain", &"meadow") ; world.call("load_island", _host, &"home_grassland", Vector3(0, 1, 12), false)
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	await process_frame ; await physics_frame
	_player.skills.trees["construction"]["level"] = 40 ; _rt = world.get("runtime")
	_bg = _rt.get("build_grid") ; _sg = _bg.get("structures")
	_bg.set("ignore_distance", true)
	# Fixture: one long-lived claim over the test area (a staked plot is only 14x14 tiles).
	var around: Vector2i = _sg.call("module_of", Vector3(0, 0, 12))
	_rt.claims.append(Rect2i(around * 2 - Vector2i(50, 50), Vector2i(100, 100))) ; _claims_base = _rt.claims.duplicate()
	_site = _find_site(around) ; _stand_at(_site)
	for case in ["data_rows", "costs", "reasons", "snap", "collapse", "damage_tiers", "kits_and_camp", "repair_upgrade", "paths", "rows_round_trip", "bad_rows", "migrations"]:
		call("_test_" + case)
	if _fails.is_empty():
		print("[t_buildsys] PASS") ; quit(0)
	else:
		print("[t_buildsys] FAIL count=%d" % _fails.size()) ; quit(1)

## The flattest 2x2-module pad near the camp where every foundation fits.
func _find_site(around: Vector2i) -> Vector2i:
	var best := around
	var best_span := INF
	for dz in range(-9, 10):
		for dx in range(-9, 10):
			var o: Vector2i = around + Vector2i(dx, dz)
			var ok := true
			var lo := INF
			var hi := -INF
			for d in _square():
				var c: Vector2i = o + d
				var span: Vector2 = _sg.call("_terrain_span", c)
				ok = ok and _why(&"foundation", _slot(c, 0, 0)) == "" ; lo = minf(lo, span.x)
				hi = maxf(hi, span.y)
			if ok and hi - lo < best_span:
				best_span = hi - lo ; best = o
	_expect(best_span <= 0.6, "a flat 2x2-module pad exists near the camp (spread %.2f m)" % best_span)
	return best

func _square() -> Array:
	return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]

func _slot(m: Vector2i, level: int, code: int) -> Vector4i:
	return Vector4i(m.x, m.y, level, code)

func _why(kind: StringName, slot: Vector4i, rot: int = 0, tier: StringName = &"thatch") -> String:
	return str(_sg.check(kind, slot, rot, tier)["reason"])

## True when a module's four 1 m cells are dry land (so `water` cannot mask another reason).
func _dry(m: Vector2i) -> bool:
	for d in _square():
		if not bool(_rt.spawn_ok(_BG.tile_centre(m * 2 + d, _rt), false)):
			return false
	return true

func _floor0_at(m: Vector2i) -> float:
	var res: Dictionary = _sg.check(&"foundation", _slot(m, 0, 0), 0, &"thatch")
	return float(res["floor0"]) if str(res["reason"]) == "" else float(_rt.surface_y(float(m.x) * 2.0, float(m.y) * 2.0))

func _stand_at(m: Vector2i) -> void:
	_player.global_position = Vector3(float(m.x) * 2.0 + 1.0, _floor0_at(m) + 1.0, float(m.y) * 2.0 + 1.0)

## Drop every piece and case-local claim/reservation so cases never see each other's structures.
func _reset_case() -> void:
	if _player.placer.placing != &"":
		_player.placer.cancel()
	for p in _sg.pieces():
		_sg.unregister(p)
	for n in get_nodes_in_group("structure_piece"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			n.free()
	_rt.claims = _claims_base.duplicate() ; _bg.get("_reserved").clear()
	_stand_at(_site)

## Put exactly `cost` of each item in the bag, nothing else of those items.
func _give_exact(cost: Dictionary) -> void:
	for id in cost:
		_player.inventory.consume(id, _player.inventory.count_of(id)) ; load("res://scripts/dev/lab_kit.gd").give(_player, id, int(cost[id]))

## A piece placed straight into the grid (no placer) at the floor/variant/span the rules picked.
func _place_direct(kind: StringName, tier: StringName, slot: Vector4i, rot: int = 0) -> Node:
	var w := _why(kind, slot, rot, tier)
	if w != "":
		_expect(false, "setup: %s %s at %s refused (%s)" % [tier, kind, slot, w])
		return null
	var res: Dictionary = _sg.check(kind, slot, rot, tier)
	var p: Node = _SP.make(kind, tier, slot, rot, float(res["floor0"]), int(res["variant"]))
	p.set("span", int(res["span"])) ; _rt.add_child(p)
	_sg.register(p)
	return p

func _pad(cells: Array, tier: StringName = &"thatch") -> void:
	for c in cells:
		_place_direct(&"foundation", tier, _slot(c, 0, _SP.CELL))

# ------------------------------------------------------------------ 1. data rows

func _test_data_rows() -> void:
	_begin_case() ; var items: Node = root.get_node("Data")
	var tiers: Array = [&"thatch", &"wood", &"stone", &"metal"]
	var pieces: Dictionary = _SP.defs().get("pieces", {})
	for i in tiers.size():
		_expect(_SP.tier_rank(tiers[i]) == i, "tier %s ranks %d (got %d)" % [tiers[i], i, _SP.tier_rank(tiers[i])])
	_expect(pieces.size() >= 11, "structures.json lists every piece kind (%d)" % pieces.size())
	for kind in pieces:
		var k := StringName(kind)
		var last := -1.0
		for t in tiers:
			var bp: Dictionary = _SP.blueprint(k, t)
			_expect(not bp.is_empty(), "%s has a %s blueprint" % [k, t]) ; var good := true
			for sl in bp.get("material_slots", []):
				var it := StringName(str((sl as Dictionary).get("item", "")))
				good = good and items.get("items").has(it) and int((sl as Dictionary).get("quantity", 0)) > 0
			_expect(good, "%s %s blueprint costs real items with quantities > 0 (%s)" % [k, t, bp.get("material_slots", [])])
			var dur: float = _SP.max_durability(k, t)
			_expect(dur > last, "%s durability rises with tier (%s %.0f after %.0f)" % [k, t, dur, last]) ; last = dur
	var kits := 0
	for id in items.get("items"):
		var def: Variant = items.get("items")[id]
		if def == null or str(def.get("place_as")) == "":
			continue
		kits += 1 ; var row: Dictionary = _SP.placed_kind(StringName(str(def.get("place_as"))))
		_expect(float(row.get("max_durability", 0)) > 0.0, "kit kind %s has a placed_kinds durability row" % def.get("place_as"))
	_expect(kits >= 20, "every kit kind was checked (%d)" % kits) ; _done("data_rows")

# ------------------------------------------------------------------ 2. costs

func _test_costs() -> void:
	_begin_case() ; _reset_case()
	# Hand-read from structures.json's piece_tiers.
	var rows := [
		[&"wall", &"wood", {&"plank": 4, &"twine": 2}], [&"foundation", &"stone", {&"stone": 12, &"plank": 3}],
		[&"door", &"metal", {&"iron_ingot": 2, &"stone": 2}], [&"roof", &"thatch", {&"branch": 4, &"fibre_stalk": 4}],
		[&"ramp", &"wood", {&"plank": 3, &"twine": 2}], [&"foundation", &"thatch", {&"branch": 6, &"fibre_stalk": 6}],
		[&"doorway", &"metal", {&"iron_ingot": 3, &"stone": 3}], [&"pillar", &"stone", {&"stone": 4, &"plank": 1}],
		[&"stairs", &"metal", {&"iron_ingot": 6, &"stone": 6}], [&"window", &"thatch", {&"branch": 3, &"fibre_stalk": 3}],
		[&"ceiling", &"wood", {&"plank": 4, &"twine": 2}], [&"wall", &"metal", {&"iron_ingot": 4, &"stone": 4}],
	]
	_expect(rows.size() >= 8, "the cost table has at least 8 rows")
	for row in rows:
		var got: Dictionary = _SP.cost(row[0], row[1])
		var want: Dictionary = row[2]
		var same := got.size() == want.size()
		for id in want:
			same = same and int(got.get(id, -1)) == int(want[id])
		_expect(same, "%s %s costs %s (got %s)" % [row[1], row[0], want, got])
	# The placer takes exactly the blueprint: a wood wall on a wood foundation.
	var f := _place_direct(&"foundation", &"wood", _slot(_site, 0, _SP.CELL))
	if f == null: return
	var floor0: float = f.get("floor0")
	var edge := Vector4i(_site.x, _site.y, 0, _SP.EDGE_Z)
	_give_exact(_SP.cost(&"wall", &"wood")) ; _player.placer.begin_piece(&"wall", &"wood")
	_player.placer.aim_at(_SP.pose(&"wall", edge, 0, floor0).origin + Vector3(0.3, 0.2, 0.0)) ; var ok: bool = _player.placer.confirm(_player)
	var wall: Variant = _sg.piece_at(edge)
	_expect(ok and wall != null and wall.kind == &"wall", "wood wall placed on the wood foundation (%s)" % _player.placer.reason)
	for id in _SP.cost(&"wall", &"wood"):
		_expect(_player.inventory.count_of(id) == 0, "the wall took all its %s (%d left)" % [id, _player.inventory.count_of(id)])
	# One plank short: refused, nothing placed, nothing spent.
	var edge2 := Vector4i(_site.x, _site.y, 0, _SP.EDGE_X)
	_give_exact({&"plank": 3, &"twine": 2}) ; _player.placer.begin_piece(&"wall", &"wood")
	_player.placer.aim_at(_SP.pose(&"wall", edge2, 0, floor0).origin + Vector3(0.3, 0.2, 0.3))
	_expect(not bool(_player.placer.confirm(_player)), "one plank short: the wall is not placed")
	_expect(_sg.piece_at(edge2) == null, "one plank short: no piece at the socket")
	_expect(_player.inventory.count_of(&"plank") == 3, "a refused placement takes no materials") ; _player.placer.cancel()
	_done("costs")

# ------------------------------------------------------------------ 3. placement reasons

## First module east of the site matching `want` (and dry unless `want` is water).
func _scan(want: StringName) -> Vector2i:
	var land := int(_rt.land_radius())
	for dx in range(4, land):
		for dz in [0, 1, -1, 2, -2]:
			var m: Vector2i = _site + Vector2i(dx, dz)
			var wet := not _dry(m)
			if (want == &"water") != wet:
				continue
			if want == &"unclaimed":
				var hit := false
				for d in _square():
					if bool(_rt.is_claimed(m * 2 + d)):
						hit = true
				if not hit:
					return m
			elif _why(&"foundation", _slot(m, 0, _SP.CELL)) == want:
				return m
	_expect(false, "found a module for the '%s' reason" % want)
	return _site + Vector2i(400, 0)

## A module whose whole 2x2 is land with a harvest node on it, so `resource` (not water) fires.
func _harvest_module() -> Vector2i:
	for n in get_nodes_in_group("harvest"):
		if is_instance_valid(n) and n.is_visible_in_tree():
			var m: Vector2i = _sg.call("module_of", (n as Node3D).global_position)
			if _dry(m):
				return m
	_expect(false, "found a harvest node to build on")
	return _site + Vector2i(400, 0)

func _test_reasons() -> void:
	_begin_case() ; _reset_case()
	var ma := _site
	var mb := _site + Vector2i(2, 0)
	var ms := _site + Vector2i(0, 2)
	var mr := _site + Vector2i(-2, 0)
	# Prep: stairs on a two-cell pad, so the ceiling-over-stairs row sees a real stairwell.
	_pad([ms, ms + Vector2i(0, 1)])
	if _place_direct(&"stairs", &"wood", _slot(ms, 0, _SP.ON_FLOOR)) == null: return
	var water_m := _scan(&"water")
	var tree_m := _harvest_module()
	var free_m := _scan(&"unclaimed")
	_rt.claims.append(Rect2i(water_m * 2 - Vector2i(1, 1), Vector2i(6, 6))) ; _rt.claims.append(Rect2i(tree_m * 2 - Vector2i(1, 1), Vector2i(6, 6)))
	_bg.call("reserve_cells", _sg.call("module_cells", mr))
	var table: Array = [
		["valid", &"foundation", _slot(ma, 0, _SP.CELL), ""],
		["occupied", &"foundation", _slot(ma, 0, _SP.CELL), "occupied"],
		["wall_on_bare_ground", &"wall", Vector4i(mb.x, mb.y, 0, _SP.EDGE_Z), "no_support"],
		["ceiling_without_wall", &"ceiling", _slot(mb, 1, _SP.CELL), "no_support"],
		["door_without_doorway", &"door", Vector4i(mb.x, mb.y, 0, _SP.DOOR_Z), "no_support"],
		["floating_roof", &"roof", _slot(mb, 1, _SP.CELL), "no_support"],
		["wall_at_max_level", &"wall", Vector4i(mb.x, mb.y, 4, _SP.EDGE_Z), "max_level"],
		["ceiling_over_stairs", &"ceiling", _slot(ms, 1, _SP.CELL), "stairwell"],
		["outside_the_claim", &"foundation", _slot(free_m, 0, _SP.CELL), "unclaimed"],
		["in_water", &"foundation", _slot(water_m, 0, _SP.CELL), "water"],
		["on_a_tree", &"foundation", _slot(tree_m, 0, _SP.CELL), "resource"],
		["reserved_cell", &"foundation", _slot(mr, 0, _SP.CELL), "reserved"],
		["unknown_kind", &"banana", _slot(_site + Vector2i(4, 0), 0, _SP.CELL), "no_blueprint"],
		["ramp_without_floor", &"ramp", _slot(_site + Vector2i(4, 2), 0, _SP.CELL), "no_support"],
	]
	_expect(table.size() >= 12, "the reasons table has at least 12 rows")
	for row in table:
		var why := _why(row[1], row[2])
		_expect(why == row[3], "reason for %s is '%s' (got '%s')" % [row[0], row[3], why])
		if row[0] == "valid" and why == "":
			_place_direct(&"foundation", &"thatch", row[2])  # the occupied row needs it there
	_bg.get("_reserved").clear() ; _done("reasons", " cases=%d" % table.size())

# ------------------------------------------------------------------ 4. socket snapping

func _test_snap() -> void:
	_begin_case() ; _reset_case()
	var f := _place_direct(&"foundation", &"wood", _slot(_site, 0, _SP.CELL))
	if f == null: return
	var floor0: float = f.get("floor0")
	var costs: Dictionary = _SP.cost(&"wall", &"wood")
	var zx: int = _SP.EDGE_Z ; var xx: int = _SP.EDGE_X
	var s := _site
	for e in [Vector4i(s.x, s.y, 0, zx), Vector4i(s.x + 1, s.y, 0, xx), Vector4i(s.x, s.y + 1, 0, zx), Vector4i(s.x, s.y, 0, xx)]:
		_give_exact(costs) ; _player.placer.begin_piece(&"wall", &"wood")
		_player.placer.aim_at(_SP.pose(&"wall", e, 0, floor0).origin + Vector3(0.18, 0.18, 0.18)) ; var snapped: Dictionary = _player.placer.piece_at
		_expect(snapped.get("slot", Vector4i.ZERO) == e, "aim 0.3 m off edge %s snaps onto it (got %s)" % [e, snapped.get("slot")])
		_expect(bool(_player.placer.valid), "a wall on its edge is valid (%s)" % _player.placer.reason) ; _player.placer.cancel()
	# Aim 10 m from the only piece: nothing valid out there, and nothing is placed.
	_give_exact(costs) ; _player.placer.begin_piece(&"wall", &"wood")
	_player.placer.aim_at(Vector3(float(_site.x) * 2.0 + 11.0, floor0, float(_site.y) * 2.0 + 1.0))
	_expect(not bool(_player.placer.valid), "aiming 10 m from any piece is not valid")
	# 4 m out is past snap_radius_m (3 m) but still inside the socket search: no valid snap there.
	_player.placer.aim_at(Vector3(float(_site.x) * 2.0 + 1.0, floor0, float(_site.y) * 2.0 + 6.0))
	_expect(not bool(_player.placer.valid), "aiming 4 m past the nearest socket is not valid (%s)" % _player.placer.reason)
	_expect(not bool(_player.placer.confirm(_player)), "confirming past snap_radius_m places nothing")
	_expect(_sg.pieces().size() == 1, "only the foundation is in the grid (%d pieces)" % _sg.pieces().size()) ; _player.placer.cancel()
	# Rotation: rotate_clockwise moves the step, and oriented pieces keep it after confirm.
	_player.placer.begin_piece(&"ramp", &"wood") ; var before: int = _player.placer.rot_step
	_player.placer.rotate_clockwise()
	_expect(_player.placer.rot_step != before, "rotate_clockwise() changes rot_step (%d -> %d)" % [before, _player.placer.rot_step])
	_player.placer.cancel()
	# Ramp rot 1 rises toward +X onto the foundation; its own module is the free one beside it.
	var ramp_m := _site + Vector2i(-1, 0)
	_give_exact(_SP.cost(&"ramp", &"wood")) ; _player.placer.begin_piece(&"ramp", &"wood")
	while int(_player.placer.rot_step) != 1:
		_player.placer.rotate_clockwise()
	_player.placer.aim_at(Vector3((float(ramp_m.x) + 0.5) * 2.0, floor0, (float(ramp_m.y) + 0.5) * 2.0))
	var ramp: Variant = _sg.piece_at(_slot(ramp_m, 0, _SP.CELL)) if bool(_player.placer.confirm(_player)) else null
	_expect(ramp != null and ramp.kind == &"ramp" and int(ramp.rot) == 1, "the ramp keeps rot 1 after confirm (%s)" % str(ramp.rot if ramp else "none"))
	# A roof above a wall, turned twice: rot 2 survives the confirm.
	var me := _site + Vector2i(0, 1)
	var w := _place_direct(&"wall", &"wood", Vector4i(me.x, me.y, 0, _SP.EDGE_Z))
	if w == null: return
	_give_exact(_SP.cost(&"roof", &"wood")) ; _player.placer.begin_piece(&"roof", &"wood")
	var turns := 0
	while int(_player.placer.rot_step) != 2 and turns < 6:
		_player.placer.rotate_clockwise() ; turns += 1
	_player.placer.aim_at(Vector3((float(me.x) + 0.5) * 2.0, float(w.get("floor0")) + 2.5, (float(me.y) + 0.5) * 2.0))
	var roof: Variant = _sg.piece_at(_slot(me, 1, _SP.CELL)) if bool(_player.placer.confirm(_player)) else null
	_expect(roof != null and roof.kind == &"roof" and int(roof.rot) == 2, "the roof keeps rot 2 after confirm (%s)" % str(roof.rot if roof else "none"))
	_done("snap")

# ------------------------------------------------------------------ 5. collapse

## One lean-to on module `m`: its foundation, the wall on its north edge, the ceiling that wall holds
## and a wall standing on the ceiling (+ optionally a pillar on the far corner).
func _lean_to(m: Vector2i, tier: StringName = &"thatch", with_pillar: bool = false) -> Dictionary:
	_pad([m], tier)
	var out := {"wall": _place_direct(&"wall", tier, Vector4i(m.x, m.y + 1, 0, _SP.EDGE_Z)),
		"ceiling": _place_direct(&"ceiling", tier, _slot(m, 1, _SP.CELL)), "upper": null, "pillar": null}
	out["upper"] = _place_direct(&"wall", tier, Vector4i(m.x, m.y, 1, _SP.EDGE_Z))
	if with_pillar:
		out["pillar"] = _place_direct(&"pillar", tier, Vector4i(m.x + 1, m.y + 1, 0, _SP.CORNER))
	return out

## A module with a free three-module row east/west of it (for the span test).
func _free_row3() -> Vector2i:
	for dz in range(0, 12):
		for sx in [1, -1]:
			for dx in range(2, 18):
				var m: Vector2i = _site + Vector2i(dx * sx, dz)
				var ok := true
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0)]:
					ok = ok and _why(&"foundation", _slot(m + d, 0, _SP.CELL)) == ""
				if ok:
					return m
	_expect(false, "found a free three-module row for the span test")
	return _site

func _test_collapse() -> void:
	_begin_case()
	# a) Destroy the only wall that holds the ceiling: the ceiling and the wall on it fall.
	_reset_case() ; var a := _lean_to(_site)
	if a["wall"] == null: return
	var fell: Array = a["wall"].destroy("test")
	_expect(fell.size() == 2 and a["ceiling"] in fell and a["upper"] in fell, "destroying the wall drops the ceiling and the wall on it (fell %d)" % fell.size())
	# b) A pillar on the far corner holds the ceiling: 0 fall, then the pillar takes it all.
	_reset_case() ; var b := _lean_to(_site + Vector2i(4, 0), &"thatch", true)
	if b["pillar"] == null: return
	fell = b["wall"].destroy("test")
	_expect(fell.size() == 0 and not b["ceiling"].is_queued_for_deletion(), "the pillar still holds the ceiling: nothing falls (fell %d)" % fell.size())
	fell = b["pillar"].destroy("test")
	_expect(fell.size() == 2 and b["ceiling"] in fell and b["upper"] in fell, "removing the pillar drops the ceiling and the wall on it (fell %d)" % fell.size())
	# c) Ceilings one and two modules out from a supported one stay, then fall with it.
	_reset_case() ; var span_m := _free_row3()
	var base := _lean_to(span_m)
	if base["ceiling"] == null: return
	var spans: Array = []
	for d in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var sp := _slot(span_m + d, 1, _SP.CELL)
		var c: Node = _place_direct(&"ceiling", &"thatch", sp)
		_expect(c != null and not c.is_queued_for_deletion(), "a ceiling spans from a supported one (%s, %s)" % [sp, _why(&"ceiling", sp)])
		if c:
			spans.append(c)
	fell = base["ceiling"].destroy("test")
	_expect(fell.size() == 3 and spans.all(func (n: Node) -> bool: return n in fell), "spanned ceilings fall with the one that held them (fell %d)" % fell.size())
	# d) A doorway holds its door: destroying the doorway drops the door.
	_reset_case() ; var dm := _free_row3() + Vector2i(0, 4)
	_pad([dm, dm + Vector2i(0, 1)]) ; var dw := _place_direct(&"doorway", &"wood", Vector4i(dm.x, dm.y, 0, _SP.EDGE_Z))
	var door: Node = _place_direct(&"door", &"wood", Vector4i(dm.x, dm.y, 0, _SP.DOOR_Z))
	if dw == null or door == null: return
	fell = dw.destroy("test") ; _expect(fell.size() == 1 and door in fell, "destroying a doorway drops its door (fell %d)" % fell.size())
	_done("collapse")

# ------------------------------------------------------------------ 6. tiers and creature damage

## A lone raptor with its brain and physics off, so a bite is one deliberate on-hit call.
func _spawn_raptor(at: Vector3) -> Variant:
	var sp: Node3D = load("res://scripts/world/spawner.gd").new()
	sp.position = at ; sp.set("count", 1)
	sp.set("radius", 0.1) ; _rt.add_child(sp)
	var pack: Array = sp.call("spawn_now")
	sp.queue_free()
	if pack.is_empty():
		_expect(false, "a raptor spawned for the bite")
		return null
	var c: Variant = pack[0]
	c.set_physics_process(false)
	if c.get("brain") != null:
		c.get("brain").set_physics_process(false)
	return c

func _test_damage_tiers() -> void:
	_begin_case() ; _reset_case()
	var mults := {&"thatch": 1.0, &"wood": 0.8, &"stone": 0.35, &"metal": 0.15}
	var i := 0
	for tier in mults:
		var m := _site + Vector2i(i * 3, 0)
		i += 1 ; _pad([m], tier)
		var w := _place_direct(&"wall", tier, Vector4i(m.x, m.y, 0, _SP.EDGE_Z))
		if w == null: return
		var hp: float = w.health.hp
		var dealt: float = w.health.take_damage(100.0)
		var want: float = 100.0 * float(mults[tier])
		_expect(absf(dealt - want) < 0.01 and absf((hp - float(w.health.hp)) - want) < 0.01, "%s wall takes %.1f from 100 (got %.2f)" % [tier, want, dealt])
	# A raptor bite on a wood wall goes through the creature's own on-hit path.
	_reset_case() ; _pad([_site], &"wood")
	var wall := _place_direct(&"wall", &"wood", Vector4i(_site.x, _site.y, 0, _SP.EDGE_Z))
	if wall == null: return
	var raptor: Variant = _spawn_raptor(wall.global_position + Vector3(0, 0, -1.4))
	if raptor == null: return
	var hp0: float = wall.health.hp
	raptor.call("apply_species_on_hit", &"attack_primary", wall)
	_expect(float(wall.health.hp) < hp0, "a raptor bite lowers the wood wall (%.0f -> %.0f)" % [hp0, float(wall.health.hp)])
	if is_instance_valid(raptor):
		raptor.free()
	# Enough damage destroys the wall and the ceiling it alone held.
	_reset_case() ; var lean := _lean_to(_site, &"wood")
	if lean["wall"] == null: return
	lean["wall"].health.take_damage(100000.0) ; _expect(lean["wall"].is_queued_for_deletion(), "enough damage destroys the wall")
	_expect(lean["ceiling"].is_queued_for_deletion(), "the ceiling the wall held collapses with it") ; _done("damage_tiers")

# ------------------------------------------------------------------ 7. kits, camp, cargo, catapult

func _kit_cell(kind: StringName) -> Vector2i:
	for dz in range(-10, 11):
		for dx in range(-10, 11):
			var c: Vector2i = _site * 2 + Vector2i(dx, dz)
			if str(_bg.can_place(kind, c, 0)) == "":
				return c
	_expect(false, "found a free cell for a %s" % kind)
	return Vector2i(-9999, -9999)

func _test_kits_and_camp() -> void:
	_begin_case() ; _reset_case()
	_SH = load("res://scripts/world/structure_health.gd") ; var cell := _kit_cell(&"fence")
	if cell.x == -9999: return
	load("res://scripts/dev/lab_kit.gd").give(_player, &"fence_kit", 1) ; _player.placer.begin(&"fence")
	_player.placer.set("cell", cell) ; var ok: bool = _player.placer.confirm(_player)
	_player.placer.cancel() ; var fence: Node = null
	for n in get_nodes_in_group("fence"):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			fence = n
	_expect(ok and fence != null, "a fence kit stands on the claim (%s)" % _player.placer.reason)
	if fence == null: return
	var h: Variant = _SH.of(fence, true)
	var want_hp: float = _SP.placed_kind(&"fence").get("max_durability", 0.0)
	_expect(h != null and absf(float(h.max_hp) - want_hp) < 0.01, "the fence gets a StructureHealth with durability %.0f (got %s)" % [want_hp, str(h.max_hp if h else "null")])
	if h != null:
		var raptor: Variant = _spawn_raptor(fence.global_position + Vector3(0, 0, -1.4))
		if raptor != null:
			var before: float = h.hp
			raptor.call("apply_species_on_hit", &"attack_primary", fence)
			_expect(float(h.hp) < before, "a raptor bite lowers the fence (%.0f -> %.0f)" % [before, float(h.hp)])
			_expect(h.hp == fence.get("hp") if fence.get("hp") != null else true, "the fence mirrors hp onto its own field")
			if is_instance_valid(raptor):
				raptor.free()
	# Camp pieces (rebuilt from the layout each load) and cargo come back whole: not structures.
	var PB: GDScript = load("res://scripts/world/placed_building.gd")
	var camp: Node = PB.call("make", &"tent")
	camp.set("persist_building", false) ; var cargo: Node = PB.call("make", &"basket")
	cargo.set("is_cargo", true) ; var loose: Node = PB.call("make", &"basket")
	for n in [camp, cargo, loose]:
		_rt.add_child(n)
	_expect(_SH.of(camp, true) == null and not _SH.is_structure(camp), "a camp piece (persist_building false) is not a structure")
	_expect(_SH.of(cargo, true) == null and not _SH.is_structure(cargo), "cargo is not a structure")
	_expect(_SH.of(loose, true) != null, "a placed building that persists is a structure")
	for n in [camp, cargo, loose]:
		n.free()
	# Catapult: a siege hit wears its own hp down and destroys it at 0.
	var cat: Node3D = load("res://scripts/world/field_catapult.gd").new()
	cat.position = Vector3(float(_site.x) * 2.0 - 8.0, _floor0_at(_site), float(_site.y) * 2.0) ; _rt.add_child(cat)
	cat.call("receive_siege_hit", 50.0)
	_expect(absf(float(cat.get("hp")) - (float(cat.get("max_hp")) - 50.0)) < 0.01, "a catapult hit takes 50 hp (%s)" % str(cat.get("hp")))
	cat.call("receive_siege_hit", 100000.0) ; _expect(cat.is_queued_for_deletion() or not is_instance_valid(cat), "a catapult at 0 hp is destroyed")
	_done("kits_and_camp")

# ------------------------------------------------------------------ 8. repair and upgrade

func _test_repair_upgrade() -> void:
	_begin_case() ; _reset_case()
	_pad([_site], &"wood") ; var wall := _place_direct(&"wall", &"wood", Vector4i(_site.x, _site.y, 0, _SP.EDGE_Z))
	if wall == null: return
	var max_hp: float = wall.health.max_hp
	wall.health.take_damage(750.0)  # wood takes 0.8 of it: 600 of 1200 gone
	var h: Variant = wall.health
	_expect(absf(float(h.missing()) - 600.0) < 1.0, "the wood wall is 600 hp down (missing %.0f)" % float(h.missing()))
	var cost: Dictionary = load("res://scripts/world/structure_placer.gd").call("repair_cost", wall)
	var want_cost := {}
	for id in _SP.cost(&"wall", &"wood"):
		var n := ceili(float(_SP.cost(&"wall", &"wood")[id]) * (float(h.missing()) / max_hp) * 0.5 - 0.0001)
		if n > 0:
			want_cost[id] = n
	_expect(cost.size() == want_cost.size(), "repair cost lists %s (got %s)" % [want_cost, cost])
	for id in want_cost:
		_expect(int(cost.get(id, -1)) == int(want_cost[id]), "repair needs %d %s (got %s)" % [int(want_cost[id]), id, str(cost.get(id))])
	# One item short: refused, nothing changes, nothing spent.
	_give_exact(want_cost) ; var short_id: StringName = cost.keys()[0]
	_player.inventory.consume(short_id, 1) ; var hp_before: float = h.hp
	_expect(not _player.placer.repair(wall, _player), "repair with one item short is refused")
	_expect(absf(float(h.hp) - hp_before) < 0.01, "a refused repair changes nothing")
	# With the exact cost it restores full durability and empties the bag of it.
	load("res://scripts/dev/lab_kit.gd").give(_player, short_id, 1)
	_expect(_player.placer.repair(wall, _player), "repair with the exact cost is accepted (%s)" % _player.placer.reason)
	_expect(absf(float(h.hp) - max_hp) < 0.01, "repair restores full durability")
	for id in cost:
		_expect(_player.inventory.count_of(id) == 0, "repair took exactly its cost of %s" % id)
	# Upgrade wood -> stone in place: same node, slot and pose; stone durability.
	var id_before: int = wall.get_instance_id()
	var slot_before: Vector4i = wall.get("slot")
	var pos_before: Vector3 = wall.global_position
	_give_exact(_SP.cost(&"wall", &"stone"))
	_expect(_player.placer.upgrade(wall, &"stone", _player), "wood -> stone upgrade accepted (%s)" % _player.placer.reason)
	_expect(is_instance_valid(wall) and wall.get_instance_id() == id_before and wall.get("tier") == &"stone", "the upgrade swaps the tier in place (same node)")
	_expect(wall.get("slot") == slot_before and wall.global_position.distance_to(pos_before) < 0.001, "the upgraded piece keeps its slot and position")
	_expect(absf(float(wall.health.max_hp) - _SP.max_durability(&"wall", &"stone")) < 0.01, "the stone wall has stone durability (%.0f)" % float(wall.health.max_hp))
	# The bag holds the cost each time, so only the rank rule can refuse these.
	_give_exact(_SP.cost(&"wall", &"wood"))
	_expect(not _player.placer.upgrade(wall, &"wood", _player), "stone -> wood is refused")
	_expect(wall.get("tier") == &"stone" and _player.inventory.count_of(&"plank") == 4, "a refused downgrade changes nothing and takes nothing")
	_give_exact(_SP.cost(&"wall", &"stone"))
	_expect(not _player.placer.upgrade(wall, &"stone", _player), "stone -> stone is refused")
	# Gates: stone needs Construction 20, thatch needs nothing.
	_reset_case() ; var m2 := _site + Vector2i(3, 0)
	_pad([m2]) ; var tw := _place_direct(&"wall", &"thatch", Vector4i(m2.x, m2.y, 0, _SP.EDGE_Z))
	if tw == null: return
	_player.skills.trees["construction"]["level"] = 0 ; _give_exact(_SP.cost(&"wall", &"stone"))
	_expect(not _player.placer.upgrade(tw, &"stone", _player), "a stone upgrade is locked at Construction 0")
	_expect(tw.get("tier") == &"thatch", "a refused upgrade leaves the tier alone") ; _give_exact(_SP.cost(&"wall", &"wood"))
	_expect(not _player.placer.upgrade(tw, &"wood", _player), "a wood upgrade is locked at Construction 0 too")
	_expect(load("res://scripts/world/structure_placer.gd").call("tier_gate", _player, &"thatch") == "", "thatch needs no Construction level")
	_expect(load("res://scripts/world/structure_placer.gd").call("tier_gate", _player, &"stone") == "locked", "stone is locked at Construction 0")
	_player.skills.trees["construction"].set("level", 40) ; _done("repair_upgrade")

# ------------------------------------------------------------------ 9. paths through walls

func _test_paths() -> void:
	_begin_case() ; _reset_case()
	var m := _site
	_pad([m]) ; var tp: Variant = _rt.get("pathing")
	# Three walls and a doorway with a closed door seal one foundation into a room.
	for e in [[m.x, m.y, _SP.EDGE_X], [m.x + 1, m.y, _SP.EDGE_X], [m.x, m.y, _SP.EDGE_Z]]:
		_place_direct(&"wall", &"wood", Vector4i(e[0], e[1], 0, e[2]))
	var dw := _place_direct(&"doorway", &"wood", Vector4i(m.x, m.y + 1, 0, _SP.EDGE_Z))
	var door: Node = _place_direct(&"door", &"wood", Vector4i(m.x, m.y + 1, 0, _SP.DOOR_Z))
	if _sg.path_blocked_cells().size() < 6 or dw == null or door == null:
		_expect(false, "the closed room blocks its cells (%d)" % _sg.path_blocked_cells().size())
		return
	var outside: Vector3 = _BG.tile_centre(Vector2i(m.x * 2 + 2, m.y * 2 + 7), _rt)
	var inside: Vector3 = _BG.tile_centre(Vector2i(m.x * 2 + 1, m.y * 2 + 1), _rt)
	var reach := func (owner: bool) -> bool: tp.path(outside, inside, 96, owner); return bool(tp.last_reachable)
	_expect(not reach.call(false), "a creature cannot path into the closed room")
	_expect(reach.call(true), "the owner's path goes through its own closed door")
	_expect(not reach.call(false), "right after the owner query the creature path is closed again") ; door.interact(_player)
	_expect(bool(door.get("door_open")), "interacting with the door opens it") ; _expect(reach.call(false), "an open door lets a creature path in")
	door.interact(_player) ; _expect(not reach.call(false), "the door closes again for creatures")
	# Only level-0 blockers close 1 m cells: a wall one storey up never does.
	var up_m := _site + Vector2i(0, 3)
	_pad([up_m]) ; var base := _place_direct(&"wall", &"wood", Vector4i(up_m.x, up_m.y, 0, _SP.EDGE_Z))
	_place_direct(&"ceiling", &"wood", _slot(up_m, 1, _SP.CELL)) ; var up := _place_direct(&"wall", &"wood", Vector4i(up_m.x, up_m.y + 1, 1, _SP.EDGE_Z))
	_expect(base != null and up != null, "a wall stands one storey up")
	if base == null or up == null: return
	var n: int = _sg.call("cells_per_module")
	var base_cell := Vector2i(base.slot.x * n, base.slot.y * n)
	var up_cell := Vector2i(up.slot.x * n, up.slot.y * n)
	_expect(bool(_sg.blocks_cell(base_cell)), "a level-0 wall blocks its cells (%s)" % base_cell)
	_expect(not bool(_sg.blocks_cell(up_cell)), "a level-1 wall blocks nothing (%s)" % up_cell) ; _done("paths")

# ------------------------------------------------------------------ 10. save rows round trip

func _test_rows_round_trip() -> void:
	_begin_case()
	# One row per kind (tiers cycling, rotations 0-3), plus a damaged wall and an open door.
	var rows: Array = []
	var kinds: Array = _SP.defs().get("pieces", {}).keys()
	var tiers: Array = [&"thatch", &"wood", &"stone", &"metal"]
	for i in kinds.size():
		var k := StringName(kinds[i])
		var level := 1 if k in [&"wall", &"doorway", &"door", &"window", &"ceiling", &"pillar"] else 0
		rows.append([k, tiers[i % 4], Vector4i(100 + i, 200 + i, level, _SP.slot_code(k, _SP.EDGE_Z if i % 2 == 0 else _SP.EDGE_X)), i % 4])
	rows.append([&"wall", &"stone", Vector4i(140, 240, 0, _SP.EDGE_Z), 1]) ; rows.append([&"door", &"wood", Vector4i(141, 241, 0, _SP.DOOR_X), 2])
	for r in rows:
		var made: Node = _SP.make(r[0], r[1], r[2], r[3], 12.5, 3)
		var damaged: bool = r[0] == &"wall" and r[1] == &"stone"
		var open: bool = r[0] == &"door"
		if damaged:
			made.health.hp = float(made.health.max_hp) * 0.5
		if open:
			made.set("door_open", true)
		var back: Node = _SP.from_dict(made.call("to_dict"))
		var want := [r[0], r[1], r[2], int(r[3]), 12.5, 3, float(made.health.hp), open]
		var got: Array = [] if back == null else [back.get("kind"), back.get("tier"), back.get("slot"), int(back.get("rot")),
			float(back.get("floor0")), int(back.get("variant")), float(back.health.hp), bool(back.get("door_open"))]
		# Same kind, tier, slot, rot, floor_y, variant, durability and door state.
		_expect(got.size() == 8 and str(got) == str(want), "%s %s at %s rot %d round trips to_dict/from_dict (got %s)" % [r[0], r[1], r[2], r[3], str(got)])
		made.free()
		if back != null:
			back.free()
	_expect(rows.size() >= 11, "every piece kind round trips (%d rows)" % rows.size())
	# restore(): a supported set comes back; a piece whose support row is missing is dropped.
	_reset_case() ; var m := _site
	var live: Array = []
	var orphan: Array = []
	for spec in [[&"foundation", _slot(m, 0, _SP.CELL)], [&"wall", Vector4i(m.x, m.y + 1, 0, _SP.EDGE_Z)], [&"ceiling", _slot(m, 1, _SP.CELL)], [&"wall", Vector4i(m.x, m.y, 1, _SP.EDGE_Z)]]:
		live.append(_SP.make(spec[0], &"wood", spec[1], 0, 0.0).call("to_dict"))
	orphan.append(_SP.make(&"foundation", &"wood", _slot(m + Vector2i(4, 0), 0, _SP.CELL), 0, 0.0).call("to_dict"))
	orphan.append(_SP.make(&"ceiling", &"wood", _slot(m + Vector2i(4, 0), 1, _SP.CELL), 0, 0.0).call("to_dict"))
	_expect(_sg.restore(live, _rt) == 4, "restore rebuilds a supported set of 4")
	_expect(_sg.piece_at(_slot(m, 0, _SP.CELL)) != null and _sg.piece_at(Vector4i(m.x, m.y, 1, _SP.EDGE_Z)) != null, "the restored pieces are in the grid")
	_expect(_sg.to_rows().size() == 4, "to_rows lists every restored piece (%d)" % _sg.to_rows().size()) ; _reset_case()
	var n: int = _sg.restore(orphan, _rt)
	_expect(n == 1 and _sg.pieces().size() == 1, "a piece whose support row is missing is dropped (restored %d, %d left)" % [n, _sg.pieces().size()])
	_done("rows_round_trip")

# ------------------------------------------------------------------ 11. malformed rows

func _test_bad_rows() -> void:
	_begin_case() ; var base: Dictionary = _SP.make(&"wall", &"wood", Vector4i(3, 4, 0, _SP.EDGE_Z), 0, 0.0).call("to_dict")
	var bad: Array = [
		{"kind": &"banana", "position": [3, 4, 0, 1], "tier": "wood"},
		{"kind": "wall", "tier": "wood"},
		{"kind": "wall", "position": [3, 4, 0], "tier": "wood"},
		{"kind": "wall", "position": [3, "four", 0, 1], "tier": "wood"},
		{"kind": "wall", "position": [3, 4, 0, 7], "tier": "wood"},
		{"kind": "wall", "position": [3, 4, 0, 9], "tier": "wood"},
		{"kind": "wall", "position": [1000000000, 4, 0, 1], "tier": "wood"},
		{"kind": ["wall"], "position": [3, 4, 0, 1], "tier": "wood"},
		{"kind": "wall", "position": "3,4,0,1", "tier": "wood"},
	]
	for i in bad.size():
		var got: Variant = _SP.from_dict(bad[i])
		_expect(got == null, "malformed row %d is rejected (row %s)" % [i, str(bad[i])])
		if got != null and is_instance_valid(got):
			got.free()
	# Rows that must load, clamped into range: unknown tier -> thatch, 1e9 durability -> max, level -> 60.
	var max_hp: float = _SP.max_durability(&"wall", &"wood")
	for row in [[{"tier": "gold"}, "tier", &"thatch"], [{"current_durability": 1e9}, "hp", max_hp], [{"level": 999}, "build_level", 60]]:
		var r: Dictionary = base.duplicate(true)
		r.merge(row[0], true) ; var p: Variant = _SP.from_dict(r)
		var got: Variant = null if p == null else (p.health.hp if row[1] == "hp" else p.get(row[1]))
		var same: bool = p != null and (got == row[2] if row[1] == "tier" else is_equal_approx(float(got), float(row[2])))
		_expect(same, "a row with %s loads clamped to %s (got %s)" % [str(row[0]), str(row[2]), str(got)])
		if p != null:
			p.free()
	_done("bad_rows", " cases=%d" % bad.size())

# ------------------------------------------------------------------ 12. save schema

func _test_migrations() -> void:
	_begin_case() ; var SM: GDScript = load("res://scripts/core/save_migrations.gd")
	_expect(int(SM.CURRENT_SCHEMA) == 4, "CURRENT_SCHEMA is 4 (got %d)" % int(SM.CURRENT_SCHEMA))
	var row: Dictionary = _SP.make(&"wall", &"wood", Vector4i(3, 4, 0, _SP.EDGE_Z), 0, 0.0).call("to_dict")
	for sv in [0, 1, 2, 3]:
		var out: Dictionary = SM.migrate({"schema": sv, "player": {"name": "dsc"}, "home": {"buildings": [row.duplicate(true)]}, "unstable": {}})
		_expect(int(out.get("schema", -1)) == 4, "a schema %d save migrates to 4 (got %s)" % [sv, str(out.get("schema"))])
		var buildings: Array = (out.get("home", {}) as Dictionary).get("buildings", [])
		var kept: bool = buildings.size() == 1 and str((buildings[0] as Dictionary).get("kind", "")) == "wall"
		_expect(kept, "a schema %d save keeps its building rows (%s)" % [sv, str(buildings)])
		var back: Variant = _SP.from_dict(buildings[0]) if kept else null
		_expect(back != null, "the migrated schema %d piece row still loads" % sv)
		if back != null:
			back.free()
	var newer: Dictionary = SM.migrate({"schema": 5, "home": {}})
	_expect(newer.is_empty(), "a schema 5 save is rejected (got %s)" % str(newer)) ; _done("migrations")
