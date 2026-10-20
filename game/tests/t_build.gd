extends SceneTree
## W1-BUILD acceptance: every kit routes, a failed spawn keeps the kit, pack_up conserves units,
## manual fence rotation sticks, gates save their state and open a path, TilePath updates fast
## and reports unreachable goals. Run: Godot --headless --path game --script res://tests/t_build.gd
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _BP: GDScript
var _PB: GDScript
var _IS: GDScript
var _BG: GDScript
var _player: Node3D
var _grid: Node
var _host: Node3D

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_build] FAIL %s" % what)

func _run() -> void:
	_BP = load("res://scripts/world/build_placer.gd")
	_PB = load("res://scripts/world/placed_building.gd")
	_IS = load("res://scripts/items/item_stack.gd")
	_BG = load("res://scripts/world/build_grid.gd")
	_host = Node3D.new()
	_host.name = "TBuildHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	_player = kit["player"]
	var world: Node = root.get_node("World")
	world.load_island(_host, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := _host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	await process_frame
	await physics_frame
	_grid = world.runtime.get("build_grid")
	_grid.ignore_distance = true  # the survivor stands still; claims, water and overlap still apply
	_test_kit_routes()
	_test_spawn_failure_keeps_kit()
	_test_manual_fence_rotation()
	_test_pack_up_every_kind()
	_test_pack_up_refusals()
	_test_field_full_bag()
	_test_pack_up_replacement_xp()
	_test_pen_legacy_and_occupant()
	_test_gate_state_and_path()
	_test_tilepath_incremental()
	_test_gather_refusal_notice()
	if _fails.is_empty():
		print("[t_build] PASS")
		quit(0)
	else:
		print("[t_build] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- kits

func _placeable_items() -> Array:
	var out: Array = []
	var data: Node = root.get_node("Data")
	for id in data.items:
		var def = data.items[id]
		if def and str(def.place_as) != "":
			out.append(def)
	return out

func _test_kit_routes() -> void:
	var placer: Node = _BP.new()
	var holder := Node3D.new()
	_host.add_child(holder)
	var SG: GDScript = load("res://scripts/core/save_game.gd")
	var n_ok := 0
	var defs := _placeable_items()
	for def in defs:
		var kind := StringName(str(def.place_as))
		var kit: StringName = _BP.kit_for(kind)
		var node: Node3D = placer.call("_spawn", kind)
		var spawned := node != null
		var restored_kind := ""
		if spawned:
			holder.add_child(node)  # in the tree so to_dict can read its transform
			var back: Node = SG._spawn_building(node.to_dict())
			if back:
				restored_kind = str(_BP.kind_of_building(back))
				back.free()
			node.free()
		var ok: bool = kit == StringName(str(def.id)) and spawned and restored_kind == str(kind)
		if ok:
			n_ok += 1
			print("[build] route %s ok" % def.id)
		else:
			print("[build] route %s FAIL kit=%s spawn=%s restore=%s" % [def.id, kit, spawned, restored_kind])
		_expect(ok, "route %s" % def.id)
	_expect(n_ok == 24 and defs.size() == 24, "24 kits route (ok=%d of %d)" % [n_ok, defs.size()])
	holder.free()
	placer.free()

func _test_spawn_failure_keeps_kit() -> void:
	var src := GDScript.new()
	src.source_code = "extends BuildPlacer\nfunc _spawn(_kind: StringName) -> Node3D:\n\treturn null\n"
	src.reload()
	var failing: Node = src.new()
	_player.add_child(failing)
	_give(&"basket_kit", 1)
	var before: int = _player.inventory.count_of(&"basket_kit")
	var cell := _free_cell(&"basket")
	failing.begin(&"basket")
	failing.cell = cell
	var placed: bool = failing.confirm(_player)
	failing.cancel()
	var after: int = _player.inventory.count_of(&"basket_kit")
	print("[build] spawn-fail placed=%s kit %d->%d" % [placed, before, after])
	_expect(not placed and after == before, "forced _spawn failure leaves the kit in the bag")
	_player.inventory.consume(&"basket_kit", after)
	failing.free()

func _test_manual_fence_rotation() -> void:
	var placer: Node = _player.placer
	var c0 := Vector2i(-9999, -9999)
	for r in root.get_node("World").runtime.claims:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				if c0.x == -9999 and _grid.can_place(&"fence", c, 0) == "" and _grid.can_place(&"fence", c + Vector2i(2, 0), 1) == "":
					c0 = c
	var first := _place(&"fence", c0, 0)
	_expect(first != null, "first fence placed")
	# A horizontal neighbour makes auto-alignment suggest rot 0; the player turned it to 1.
	_give(&"fence_kit", 1)
	placer.begin(&"fence")
	placer.cell = c0 + Vector2i(2, 0)
	placer.rotate_clockwise()
	var ok: bool = placer.confirm(_player)
	var second := _newest(&"fence")
	var got: int = int(second.get("build_rot")) if ok and second else -1
	print("[build] fence manual rot requested=1 placed=%d" % got)
	_expect(ok and got == 1, "manual fence rotation kept (requested 1, placed %d)" % got)
	for n in [first, second]:
		if n and is_instance_valid(n):
			_grid.release(n)
			n.free()

# ---------------------------------------------------------------- pack up

func _test_pack_up_every_kind() -> void:
	var filler := _filler_id()
	for def in _placeable_items():
		var kind := StringName(str(def.place_as))
		var kit := StringName(str(def.id))
		var node := _place(kind, _free_cell(kind), 0)
		if node == null:
			_expect(false, "pack_up %s: could not place" % kind)
			continue
		var storage: Variant = node.get("storage")
		if _is_inv(storage):
			storage.add(_IS.make(&"stone", 7))
		# Full bag: refuse, structure stays, no unit created or destroyed.
		var empties: Array[int] = []
		for i in _player.inventory.slot_count:
			if _player.inventory.slots[i] == null:
				empties.append(i)
				_player.inventory.slots[i] = _IS.make(filler, 1)
		var units_before := _units(_player.inventory) + _units(storage)
		var refused: bool = not _pack(node)
		var units_after := _units(_player.inventory) + _units(storage)
		var stays := is_instance_valid(node) and not node.is_queued_for_deletion()
		for i in empties:
			_player.inventory.slots[i] = null
		_expect(refused and stays and units_before == units_after, "pack_up %s full bag: refused=%s stays=%s units %d->%d" % [kind, refused, stays, units_before, units_after])
		# Room in the bag: kit (and contents) come back, the structure goes.
		var kit_before: int = _player.inventory.count_of(kit)
		var stone_before: int = _player.inventory.count_of(&"stone")
		var packed := _pack(node)
		var kit_back: bool = _player.inventory.count_of(kit) == kit_before + 1
		var contents_back: bool = not _is_inv(storage) or _player.inventory.count_of(&"stone") == stone_before + 7
		var gone := not is_instance_valid(node) or node.is_queued_for_deletion()
		var ok: bool = packed and kit_back and contents_back and gone
		print("[build] pack_up %s %s full_bag_refused=%s units_conserved=%s kit_back=%s contents_back=%s" % [kind, "ok" if ok else "FAIL", refused and stays, units_before == units_after, kit_back, contents_back])
		_expect(ok, "pack_up %s returns kit/contents" % kind)
		_player.inventory.consume(kit, _player.inventory.count_of(kit))
		_player.inventory.consume(&"stone", _player.inventory.count_of(&"stone"))

func _test_pack_up_refusals() -> void:
	var cases := [
		[&"tent", "sleeps_left", 5],
		[&"campfire", "seconds_left", 60.0],
		[&"catapult", "hp", 150.0],
		[&"field_small", "crop_id", &"wheat"],
	]
	for row in cases:
		var node := _place(row[0], _free_cell(row[0]), 0)
		if node == null:
			_expect(false, "refusal %s: could not place" % row[0])
			continue
		node.set(row[1], row[2])
		var refused := not _pack(node)
		var why: String = _BP.pack_up_blocker(node)
		print("[build] pack_up %s with %s=%s refused=%s reason=\"%s\"" % [row[0], row[1], row[2], refused, why])
		_expect(refused and why != "" and is_instance_valid(node), "%s with %s=%s refuses" % row)
		_grid.release(node)
		node.free()

## Harvest and water on a full bag used to drop the crop / the empty bucket.
func _test_field_full_bag() -> void:
	var field := _place(&"field_small", _free_cell(&"field_small"), 0)
	if field == null:
		_expect(false, "field full-bag: could not place")
		return
	field.crop_id = &"wheat"
	field.mature = true
	_give(&"water_bucket", 2)  # a stack of 2: pouring one frees no slot
	var filler := _filler_id()
	var empties: Array[int] = []
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] == null:
			empties.append(i)
			_player.inventory.slots[i] = _IS.make(filler, 1)
	var units_before := _units(_player.inventory)
	field.apply_action(_player, {"action": "harvest"})
	field.apply_action(_player, {"action": "water"})
	var units_after := _units(_player.inventory)
	var kept: bool = field.mature and field.crop_id == &"wheat" and field.watered == 0.0
	for i in empties:
		_player.inventory.slots[i] = null
	field.apply_action(_player, {"action": "harvest"})
	var got: int = _player.inventory.count_of(&"wheat")
	print("[build] field full bag: units %d->%d crop_kept=%s buckets=%d | with room: wheat=%d" % [units_before, units_after, kept, _player.inventory.count_of(&"water_bucket"), got])
	_expect(units_before == units_after and kept and _player.inventory.count_of(&"water_bucket") == 2, "full bag: harvest and water refuse without losing units")
	_expect(got > 0 and field.crop_id == &"", "harvest lands once the bag has room")
	_player.inventory.consume(&"wheat", got)
	_player.inventory.consume(&"water_bucket", 2)
	_grid.release(field)
	field.free()
	_test_field_overflow_pack_up()

## A harvested field can hold bonus fertiliser past the yield; packing it up used to drop it.
func _test_field_overflow_pack_up() -> void:
	var field := _place(&"field_small", _free_cell(&"field_small"), 0)
	if field == null:
		_expect(false, "field overflow: could not place")
		return
	field.fertilizer_overflow = 2.0
	var before: int = _player.inventory.count_of(&"fruit_fertilizer")
	var packed := _pack(field)
	var back: int = _player.inventory.count_of(&"fruit_fertilizer") - before
	print("[build] field overflow pack-up: packed=%s fertiliser_back=%d (want 2)" % [packed, back])
	_expect(packed and back == 2, "packing up a field with 2 overflow fertiliser returns 2 units (got %d)" % back)
	_player.inventory.consume(&"fruit_fertilizer", back)
	# fertilizer_overflow is a save field that becomes items on pack-up: a forged value is clamped.
	var FP: GDScript = load("res://scripts/world/field_plot.gd")
	var got: Array = []
	for v in [INF, -INF, NAN, 1e9, -3.0, 2.5]:
		var f = FP.from_dict({"kind": "field_small", "fertilizer_overflow": v})
		got.append(f.fertilizer_overflow)
		f.free()
	print("[build] field overflow on load: INF/-INF/NAN/1e9/-3/2.5 -> %s" % [got])
	_expect(got == [0.0, 0.0, 0.0, FP.OVERFLOW_MAX, 0.0, 2.5], "a forged fertilizer_overflow loads finite and clamped to 0..%.0f (got %s)" % [FP.OVERFLOW_MAX, got])

# ---------------------------------------------------------------- gate + pathing

## Place -> pack -> place is a move, not a new build: no +8 construction / +30 pioneer XP per cycle.
func _test_pack_up_replacement_xp() -> void:
	var bag: Variant = _player.inventory
	var world: Node = root.get_node("World")
	var xp0: float = _player.skills.xp_of("construction")
	var pioneer0: int = int(world.pioneer_xp)
	var first := _place(&"sign", _free_cell(&"sign"), 0)
	if first == null:
		_expect(false, "replacement XP: could not place")
		return
	var xp_built: float = _player.skills.xp_of("construction")
	var pioneer_built: int = int(world.pioneer_xp)
	var packed := _pack(first)
	var kit_idx: int = bag.find_first(&"sign_kit")
	var flags: Array = bag.slots[kit_idx].flags.duplicate() if kit_idx >= 0 else []
	var second := _place(&"sign", _free_cell(&"sign"), 0)
	var xp_reset: float = _player.skills.xp_of("construction")
	var pioneer_reset: int = int(world.pioneer_xp)
	print("[build] place/pack/place xp: build +%.0f (pioneer +%d), repack +%.0f (pioneer +%d), kit flags=%s" % [
		xp_built - xp0, pioneer_built - pioneer0, xp_reset - xp_built, pioneer_reset - pioneer_built, flags])
	_expect(xp_built > xp0 and pioneer_built > pioneer0, "a fresh build still pays construction and pioneer XP")
	_expect(packed and second != null and is_equal_approx(xp_reset, xp_built) and pioneer_reset == pioneer_built,
		"re-placing a repacked kit pays no XP (construction +%.0f, pioneer +%d)" % [xp_reset - xp_built, pioneer_reset - pioneer_built])
	_expect(&"repacked" in flags, "a packed kit is marked repacked")
	if second and is_instance_valid(second):
		_grid.release(second)
		second.free()
	_player.inventory.consume(&"sign_kit", _player.inventory.count_of(&"sign_kit"))

## Legacy tamed_animal + captured_animal in one bag: one tap bonds the legacy item AND starts the pen.
## A running pen whose species left data keeps its occupant instead of aborting _process.
func _test_pen_legacy_and_occupant() -> void:
	var pen := _place(&"makeshift_taming_pen", _free_cell(&"makeshift_taming_pen"), 0)
	if pen == null:
		_expect(false, "pen: could not place")
		return
	var bonded0: int = _player.bonded.size()
	_give(&"tamed_animal", 1)
	_give(&"captured_animal", 1)
	var started: bool = pen.try_insert(_player)
	var bonded1: int = _player.bonded.size()
	var legacy_left: int = _player.inventory.count_of(&"tamed_animal")
	var got_occupant: bool = pen.occupant != null and str(pen.occupant.def_id) == "captured_animal"
	print("[build] pen one tap: started=%s bonded %d->%d legacy_left=%d occupant=%s" % [started, bonded0, bonded1, legacy_left, got_occupant])
	_expect(started and bonded1 == bonded0 + 1 and legacy_left == 0 and got_occupant, "one tap bonds the legacy animal and also takes the captured_animal")
	# The species is no longer in data: the pen keeps the animal and does not raise.
	pen.occupant.attributes["species"] = "dodo_gone"
	pen.running = true
	pen.remaining = 0.0
	pen.force_result = 1
	var kept: bool = pen.occupant != null
	pen._process(1.0)
	print("[build] pen unknown species: kept=%s occupant=%s" % [kept, pen.occupant != null])
	_expect(kept and pen.occupant != null, "a pen whose species left data keeps its occupant instead of crashing")
	# The next tap with a second captured animal must not overwrite the one still inside.
	_give(&"captured_animal", 1)
	var reinserted: bool = pen.try_insert(_player)
	var still: String = str(pen.occupant.attributes.get("species", "")) if pen.occupant else "<none>"
	print("[build] pen retry insert=%s occupant=%s running=%s bag_captured=%d" % [reinserted, still, pen.running, _player.inventory.count_of(&"captured_animal")])
	_expect(not reinserted and still == "dodo_gone" and _player.inventory.count_of(&"captured_animal") == 1,
		"a pen holding an unfinished animal refuses a second insert (insert=%s occupant=%s)" % [reinserted, still])
	_player.inventory.consume(&"captured_animal", 1)
	# Packing up an occupied pen hands the captured animal back (taming progress is not kept).
	pen.occupant.attributes["species"] = "velociraptor"
	var caps: int = _player.inventory.count_of(&"captured_animal")
	var kit: StringName = _BP.kit_for(&"makeshift_taming_pen")
	var kits: int = _player.inventory.count_of(kit)
	var packed := _pack(pen)
	var caps_back: int = _player.inventory.count_of(&"captured_animal") - caps
	print("[build] pen occupied pack-up: packed=%s captured_back=%d kit_back=%d" % [packed, caps_back, _player.inventory.count_of(kit) - kits])
	_expect(packed and caps_back == 1 and _player.inventory.count_of(kit) == kits + 1, "packing up an occupied pen returns the kit and the captured animal")
	if not packed:
		pen.occupant = null
		_grid.release(pen)
		pen.free()
	_player.inventory.consume(kit, _player.inventory.count_of(kit))
	_player.inventory.consume(&"captured_animal", _player.inventory.count_of(&"captured_animal"))

func _test_gate_state_and_path() -> void:
	var path: Node = root.get_node("World").runtime.get("pathing")
	# A 9x7 walled ring with the gate (2x1) in the south wall; the goal sits inside.
	var origin := _walkable_block(Vector2i(9, 9), path)
	_expect(origin != Vector2i(-9999, -9999), "found an open 9x9 block for the gate ring")
	if origin == Vector2i(-9999, -9999):
		return
	var gate_cell := origin + Vector2i(3, 6)
	var walls: Array[Node] = []
	for x in range(0, 9):
		for z in range(0, 7):
			var edge := x == 0 or x == 8 or z == 0 or z == 6
			var c := origin + Vector2i(x, z)
			if not edge or c == gate_cell or c == gate_cell + Vector2i(1, 0):
				continue
			var wall := Node.new()
			walls.append(wall)
			var one: Array[Vector2i] = [c]
			_grid.occupy(wall, one)
	var gate: Node3D = _PB.make(&"gate")
	root.get_node("World").runtime.add_child(gate)
	gate.global_transform = _grid.placement_transform(&"gate", gate_cell, 0)
	gate.set_grid_pose(gate_cell, 0)
	_grid.occupy(gate, _grid.cells_for(&"gate", gate_cell, 0))
	var inside: Vector3 = _BG.tile_centre(origin + Vector2i(4, 3), root.get_node("World").runtime)
	var outside: Vector3 = _BG.tile_centre(origin + Vector2i(4, 9), root.get_node("World").runtime)
	path.path(outside, inside)
	var closed_reach: bool = path.last_reachable
	var closed_layer: int = gate.collision_layer
	gate.interact(_player)
	var pts: PackedVector3Array = path.path(outside, inside)
	var open_reach: bool = path.last_reachable
	var open_layer: int = gate.collision_layer
	var row: Dictionary = gate.to_dict()
	var back: Node = _PB.from_dict(row)
	var round_trip: bool = row.get("open", false) == true and back.gate_open == true
	back.free()
	gate.interact(_player)
	path.path(outside, inside)
	var reclosed_reach: bool = path.last_reachable
	print("[build] gate closed reachable=%s layer=%d | open reachable=%s layer=%d points=%d | reclosed reachable=%s | to_dict open=%s round_trip=%s" % [closed_reach, closed_layer, open_reach, open_layer, pts.size(), reclosed_reach, row.get("open"), round_trip])
	_expect(not closed_reach, "closed gate: enclosed target reports reachable=false")
	_expect(open_reach and pts.size() > 0, "open gate: a route through it exists")
	_expect(not reclosed_reach, "re-closed gate blocks again")
	_expect(closed_layer == 1 and open_layer == 2, "gate collision moves off the movement layer when open")
	_expect(round_trip, "gate open state round-trips to_dict/from_dict")
	_grid.release(gate)
	gate.free()
	for w in walls:
		_grid.release(w)
		w.free()

func _test_tilepath_incremental() -> void:
	var path: Node = root.get_node("World").runtime.get("pathing")
	var t0 := Time.get_ticks_usec()
	path._rebuild()
	var full_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var cell := _free_cell(&"tent")
	var pre: bool = path.is_walkable(cell + Vector2i(1, 1))
	var probe := Node.new()
	var cells: Array[Vector2i] = _grid.cells_for(&"tent", cell, 0)
	var a: Vector3 = _BG.tile_centre(cell + Vector2i(-3, 1), root.get_node("World").runtime)
	var b: Vector3 = _BG.tile_centre(cell + Vector2i(6, 1), root.get_node("World").runtime)
	t0 = Time.get_ticks_usec()
	_grid.occupy(probe, cells)
	var occupy_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var blocked: bool = not path.is_walkable(cell + Vector2i(1, 1))
	t0 = Time.get_ticks_usec()
	path.path(a, b)
	var query_ms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	_grid.release(probe)
	var release_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var freed: bool = path.is_walkable(cell + Vector2i(1, 1))
	t0 = Time.get_ticks_usec()
	path.mark_dirty()
	path.path(a, b)
	var refresh_ms := (Time.get_ticks_usec() - t0) / 1000.0
	probe.free()
	print("[build] tilepath full_rebuild=%.1f ms occupy=%.3f ms release=%.3f ms path_query=%.2f ms dirty_refresh+query=%.2f ms cell_blocked=%s cell_freed=%s (walkable before=%s)" % [full_ms, occupy_ms, release_ms, query_ms, refresh_ms, blocked, freed, pre])
	_expect(occupy_ms <= 5.0 and release_ms <= 5.0, "occupy/release <= 5 ms (occupy %.3f, release %.3f)" % [occupy_ms, release_ms])
	_expect(blocked and freed == pre, "occupy blocks and release restores the cell for pathing")
	# path_result() hands back the points and the reachable flag together (the shared last_reachable
	# member is only valid until the next call).
	var block := _walkable_block(Vector2i(3, 3), path)
	var rt: Node = root.get_node("World").runtime
	var res: Dictionary = path.path_result(_BG.tile_centre(block, rt), _BG.tile_centre(block + Vector2i(2, 0), rt)) if block.x != -9999 \
		else path.path_result(a, b)
	_expect(res.has("points") and res.has("reachable") and res["points"] is PackedVector3Array,
		"path_result() returns points and a reachable flag (got %s)" % [res.keys()])

## _begin_gather asks the node before auto-equip, so bare hands at copper read "Needs obsidian
## pick" on the HUD (not "need tool pick"), and other refusals keep their case past the first letter.
func _test_gather_refusal_notice() -> void:
	var hud_src := GDScript.new()
	hud_src.source_code = "extends Node\nvar last := \"\"\nfunc notice(t: String) -> void:\n\tlast = t\n"
	hud_src.reload()
	var hud: Node = hud_src.new()
	var real: Array = root.get_tree().get_nodes_in_group("hud")
	for h in real:
		h.remove_from_group("hud")  # LabKit's HuntHud would take the notice first
	root.add_child(hud)
	hud.add_to_group("hud")
	var scene: PackedScene = load("res://scenes/world/harvest_node.tscn")
	var got: Array[String] = []
	for row in [["CopperOreNode", &"copper_ore", &"pick"], ["Tree", &"branch", &"axe"]]:
		var n = scene.instantiate()
		n.setup(StringName("t_" + row[0]), row[1], 1, 1, {"level": 1, "climate": "temperate"}, row[2], Color.GRAY, 1.2, 8.0, row[0])
		for i in n.options().size():
			if str(n.options()[i]["item"]) == str(row[1]):
				n.select_option(i)
		hud.last = ""
		_player._begin_gather(n)
		got.append(hud.last)
		_expect(_player.gather_target != n, "a refused gather does not start (%s)" % row[0])
		n.free()
	print("[build] bare-hand gather notices: %s" % [got])
	_expect(got == ["Needs obsidian pick", "Need tool axe"], "bare-hand gather refusals reach the HUD as 'Needs obsidian pick' / 'Need tool axe' (got %s)" % [got])
	hud.free()
	for h in real:
		h.add_to_group("hud")

# ---------------------------------------------------------------- helpers

func _give(id: StringName, n: int) -> void:
	_player.inventory.add(_IS.make(id, n))

func _place(kind: StringName, cell: Vector2i, rot: int) -> Node3D:
	var kit: StringName = _BP.kit_for(kind)
	_give(kit, 1)
	var placer: Node = _player.placer
	placer.begin(kind)
	placer.cell = cell
	for i in rot:
		placer.rotate_clockwise()
	var ok: bool = placer.confirm(_player)
	if not ok:
		print("[t_build] place %s at %s refused: %s" % [kind, cell, placer.reason])
		placer.cancel()
		_player.inventory.consume(kit, 1)
		return null
	return _newest_of_kind(kind)

func _newest(group: StringName) -> Node3D:
	var best: Node3D = null
	for n in root.get_tree().get_nodes_in_group(str(group)):
		if not n.is_queued_for_deletion():
			best = n
	return best

func _newest_of_kind(kind: StringName) -> Node3D:
	var best: Node3D = null
	for n in root.get_tree().get_nodes_in_group("placed_building"):
		if not n.is_queued_for_deletion() and _BP.kind_of_building(n) == kind:
			best = n
	return best

func _pack(node: Node) -> bool:
	if node.has_method("pack_up"):
		return bool(node.pack_up(_player))
	return _BP.pack_up_node(node, _player)

## First claimed cell where this kind can be placed.
func _free_cell(kind: StringName) -> Vector2i:
	var rt: Node = root.get_node("World").runtime
	for r in rt.claims:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				if _grid.can_place(kind, c, 0) != "":
					continue
				return c
	return Vector2i(-9999, -9999)

## Top-left of a size block whose every cell is walkable for TilePath.
func _walkable_block(size: Vector2i, path: Node) -> Vector2i:
	for z in range(-40, 40, 3):
		for x in range(-40, 40, 3):
			var ok := true
			for dz in size.y + 3:
				for dx in size.x:
					if not path.is_walkable(Vector2i(x + dx, z + dz)):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, z)
	return Vector2i(-9999, -9999)

func _is_inv(v: Variant) -> bool:
	return v is Object and is_instance_valid(v) and (v as Object).has_method("count_of")

func _units(inv: Variant) -> int:
	if not _is_inv(inv):
		return 0
	var n := 0
	for s in inv.slots:
		if s != null and str(s.def_id) != "_slot_lock":
			n += s.count
	return n

func _filler_id() -> StringName:
	var data: Node = root.get_node("Data")
	for id in data.items:
		var def = data.items[id]
		if def and int(def.stack_max) == 1 and str(def.place_as) == "" and int(def.slot_span) <= 1:
			return StringName(id)
	return &"stone"
