extends Node3D
## W2-BUILDSYS acceptance lab. Builds a 2-storey 3x3 house (9 stone foundations, wood walls with a
## doorway, a door and windows, wood ceilings, upper walls, a thatch roof with a ridge, a ramp to the
## door) ONLY through BuildPlacer socket snapping: the placer is aimed near each socket and must
## snap onto it, every piece within 1 cm of the socket worked out here independently.
## Headless it then checks stairs, pillar support and collapse, a raptor bite on a wood wall, repair
## and a wood-to-stone upgrade at material cost, creature vs owner paths through the closed door,
## save/load of every piece (schema 4) and a schema-3 save migrating, and prints [snap] PASS.
## Windowed (--shot=<png>) it builds the house and frames it; --snap-inside puts the survivor
## inside on the ground floor (the roof fades there once W2-OCCLUDE's Occlusion is in the build).
## Fixture, not earned play: Construction is set to 40 and each piece's exact materials are seeded
## into the bag just before it is placed; the raptor's bite runs its own on-hit path, not its brain.

const M := 2.0      # structures.json module_m
const H := 2.5      # structures.json storey_m
const TOL := 0.01

var _player: Player
var _cam: IsoCamera
var _fails: PackedStringArray = []
var _o := Vector2i.ZERO  # module of the house's south-west cell
var _floor0 := 0.0
var _max_err := 0.0
var _built := 0

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_player.skills.trees["construction"]["level"] = 40
	print("[boot] lab=snap_build_lab")
	call_deferred("_run")

func _expect(ok: bool, what: String) -> void:
	print("[snap] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _sg() -> StructureGrid:
	return (World.runtime.get("build_grid") as BuildGrid).structures

func _run() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_o = _find_site()
	_player.global_position = _centre(1, 1, 0) + Vector3(0, 1.0, 0)
	_build_house()
	_expect(_built == 53, "house: 52 pieces and its ramp placed through socket snapping (got %d)" % _built)
	_expect(_max_err <= TOL, "every piece within 1 cm of its socket (worst %.4f m)" % _max_err)
	if DisplayServer.get_name() != "headless":
		_frame_for_shot()
		return
	await get_tree().physics_frame
	_check_stairs_and_collapse()
	_check_raptor_repair_upgrade()
	_check_paths()
	await _check_save_load()
	if _fails.is_empty():
		print("[snap] PASS")
		get_tree().quit(0)
	else:
		print("[snap] FAIL count=%d" % _fails.size())
		get_tree().quit(1)

# ------------------------------------------------------------------ the house

func _build_house() -> void:
	var cells: Array[Vector2i] = []
	for z in 3:
		for x in 3:
			cells.append(Vector2i(x, z))
	_floor0 = _pad(cells, &"stone")
	for level in 2:
		for e in _perimeter(level):
			var kind := &"wall"
			if level == 0 and e == _door_edge():
				kind = &"doorway"
			elif e in [Vector4i(_o.x + 3, _o.y + 1, 0, StructurePiece.EDGE_X), Vector4i(_o.x + 1, _o.y, 1, StructurePiece.EDGE_Z), Vector4i(_o.x + 1, _o.y + 3, 1, StructurePiece.EDGE_Z)]:
				kind = &"window"
			_snap_place(kind, &"wood", _edge_point(e), e)
		if level == 0:
			var d := _door_edge()
			_snap_place(&"door", &"wood", _edge_point(d), Vector4i(d.x, d.y, 0, StructurePiece.DOOR_Z))
			for z in 3:
				for x in 3:
					_snap_place(&"ceiling", &"wood", _centre(x, z, 1), Vector4i(_o.x + x, _o.y + z, 1, StructurePiece.CELL))
	for x in 3:
		_snap_place(&"roof", &"thatch", _centre(x, 0, 2), Vector4i(_o.x + x, _o.y, 2, StructurePiece.CELL), 0)
		_snap_place(&"roof", &"thatch", _centre(x, 2, 2), Vector4i(_o.x + x, _o.y + 2, 2, StructurePiece.CELL), 2)
	for x in 3:
		_snap_place(&"roof_peak", &"thatch", _centre(x, 1, 2), Vector4i(_o.x + x, _o.y + 1, 2, StructurePiece.CELL), 0)
	_snap_place(&"ramp", &"stone", _centre(1, 3, 0), Vector4i(_o.x + 1, _o.y + 3, 0, StructurePiece.CELL))
	_player.placer.cancel()

## The doorway: north wall, middle module (the face the iso camera sees).
func _door_edge() -> Vector4i:
	return Vector4i(_o.x + 1, _o.y + 3, 0, StructurePiece.EDGE_Z)

## Seed the piece's exact cost, aim the placer 0.3-0.4 m off the socket, confirm, and check that it
## snapped onto `want`, at the independently computed point, and took exactly its materials.
func _snap_place(kind: StringName, tier: StringName, socket: Vector3, want: Vector4i, rot: int = -1) -> StructurePiece:
	var cost := StructurePiece.cost(kind, tier)
	for id in cost:
		_player.inventory.consume(id, _player.inventory.count_of(id))
		LabKit.give(_player, id, int(cost[id]))
	var placer := _player.placer
	if placer.placing != kind or placer.piece_tier != tier:
		placer.begin_piece(kind, tier)
	if rot >= 0:
		var presses := posmod(rot - placer.rot_step, 4)
		for i in (presses if presses > 0 else 4):
			placer.rotate_clockwise()  # real rotation presses, which also stop auto-orientation
	var off := Vector3(0.31, 0.12, -0.22).rotated(Vector3.UP, float(_built) * 1.1)
	placer.aim_at(socket + off)
	var ok := placer.confirm(_player)
	var p := _sg().piece_at(want)
	if not ok or p == null or p.kind != kind:
		_expect(false, "%s %s snapped onto %s (placer reason %s)" % [tier, kind, want, placer.reason])
		return null
	var err := p.global_position.distance_to(socket)
	_max_err = maxf(_max_err, err)
	if err > TOL:
		_expect(false, "%s at %s is %.3f m off its socket" % [kind, want, err])
	for id in cost:
		if _player.inventory.count_of(id) != 0:
			_expect(false, "%s %s cost: %d %s left in the bag" % [tier, kind, _player.inventory.count_of(id), id])
	if rot >= 0 and p.rot != rot:
		_expect(false, "%s at %s rot %d (wanted %d)" % [kind, want, p.rot, rot])
	_built += 1
	return p

## Foundations for module cells (relative to the house origin), highest ground first and then
## outward through neighbours, the order that keeps one shared floor (the lattice rule: the first
## foundation sits floor_clear_m above its highest corner, the rest snap to their neighbour).
## Returns that floor height.
func _pad(cells: Array[Vector2i], tier: StringName) -> float:
	var sg := _sg()
	var start := cells[0]
	for c in cells:
		if sg._terrain_span(_o + c).y > sg._terrain_span(_o + start).y:
			start = c
	var f0 := sg._terrain_span(_o + start).y + float(StructurePiece.defs().get("floor_clear_m", 0.12))
	var keep := _floor0
	_floor0 = f0  # _centre() reads it for the expected sockets
	var todo: Array[Vector2i] = [start]
	var done := {}
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if done.has(c):
			continue
		done[c] = true
		_snap_place(&"foundation", tier, _centre(c.x, c.y, 0), Vector4i(_o.x + c.x, _o.y + c.y, 0, StructurePiece.CELL))
		for n in StructureGrid.neighbours(c):
			if n in cells and not done.has(n):
				todo.append(n)
	_floor0 = keep
	return f0

func _perimeter(level: int) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for i in 3:
		out.append(Vector4i(_o.x + i, _o.y, level, StructurePiece.EDGE_Z))
		out.append(Vector4i(_o.x + i, _o.y + 3, level, StructurePiece.EDGE_Z))
		out.append(Vector4i(_o.x, _o.y + i, level, StructurePiece.EDGE_X))
		out.append(Vector4i(_o.x + 3, _o.y + i, level, StructurePiece.EDGE_X))
	return out

## Socket points from the lattice alone (module M, storey H): the cross-check for StructurePiece.pose.
func _centre(x: int, z: int, level: int) -> Vector3:
	return Vector3((float(_o.x + x) + 0.5) * M, _floor0 + float(level) * H, (float(_o.y + z) + 0.5) * M)

func _edge_point(e: Vector4i) -> Vector3:
	var y := _floor0 + float(e.z) * H
	if e.w == StructurePiece.EDGE_X:
		return Vector3(float(e.x) * M, y, (float(e.y) + 0.5) * M)
	return Vector3((float(e.x) + 0.5) * M, y, float(e.y) * M)

## A flat, free spot near the camp: the house, its ramp and the two test pads east of it must all
## take a foundation. The flattest such origin wins.
func _find_site() -> Vector2i:
	var sg := _sg()
	var around := StructureGrid.module_of(Vector3(0, 0, 12))
	# Fixture: the search runs on a temporary claim over the whole area; the chosen site then gets
	# one real, saved 14 x 14 claim (the largest a save keeps), as staking a plot would.
	var search := Rect2i(around * 2 - Vector2i(24, 24), Vector2i(48, 48))
	World.runtime.claims.append(search)
	var best := around
	var best_span := INF
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			var o := around + Vector2i(dx, dz)
			var cells: Array[Vector2i] = [o + Vector2i(1, 3), o + Vector2i(5, 0), o + Vector2i(5, 1), o + Vector2i(5, 3)]
			for z in 3:
				for x in 3:
					cells.append(o + Vector2i(x, z))
			var lo := INF
			var hi := -INF
			var fine := true
			# One module of clear ground around the house: no camp piece, kit or tree against its walls.
			for z in range(-1, 5):
				for x in range(-1, 4):
					var why: String = sg.check(&"foundation", Vector4i(o.x + x, o.y + z, 0, StructurePiece.CELL), 0, &"stone")["reason"]
					fine = fine and not why in ["reserved", "overlap", "resource"]
			for c in cells:
				if not fine:
					break
				if sg.check(&"foundation", Vector4i(c.x, c.y, 0, StructurePiece.CELL), 0, &"stone")["reason"] != "":
					fine = false
					break
				var span := sg._terrain_span(c)
				lo = minf(lo, span.x)
				hi = maxf(hi, span.y)
			if fine and hi - lo < best_span:
				best_span = hi - lo
				best = o
	World.runtime.claims.erase(search)
	var plot := Rect2i(best * 2, Vector2i(14, 14))
	World.runtime.claims.append(plot)
	World.home_claims.append([plot.position.x, plot.position.y, plot.size.x, plot.size.y])
	print("[snap] site module=%s terrain span=%.2f m, claim %s" % [best, best_span, plot])
	return best

func _frame_for_shot() -> void:
	var inside := "--snap-inside" in OS.get_cmdline_user_args()
	_player.global_position = _centre(1, 1, 0) + Vector3(0.3, 1.0, 0.4) if inside else _centre(1, 4, 0) + Vector3(0.8, 1.0, 0.6)
	_player.reset_physics_interpolation()
	_cam._target = _player  # the survivor: the see-through system fades for the camera's target
	_cam.size = 17.0 if inside else 22.0
	_cam._snap()
	print("[snap] framed %s" % ("inside" if inside else "outside"))

# ------------------------------------------------------------------ stairs, pillar, collapse

func _check_stairs_and_collapse() -> void:
	_player.global_position = _centre(5, 1, 0) + Vector3(0, 1.0, 0)
	var house_floor := _floor0
	_floor0 = _pad([Vector2i(5, 0), Vector2i(5, 1)], &"wood")
	var st := _snap_place(&"stairs", &"wood", _centre(5, 0, 0), Vector4i(_o.x + 5, _o.y, 0, StructurePiece.ON_FLOOR), 0)
	_expect(st != null and _sg().piece_at(Vector4i(_o.x + 5, _o.y + 1, 1, StructurePiece.STAIRWELL)) == st, "stairs keep their stairwell clear")
	_player.placer.begin_piece(&"ceiling", &"wood")
	_player.placer.aim_at(_centre(5, 1, 1))
	_expect(not _player.placer.valid, "no ceiling over the stairs (reason %s)" % _player.placer.reason)
	_player.placer.cancel()
	# Lean-to: foundation, north wall, ceiling, upper wall on the ceiling, pillar on the SE corner.
	_player.global_position = _centre(5, 3, 0) + Vector3(0, 1.0, 0)
	_floor0 = _pad([Vector2i(5, 3)], &"thatch")
	var w0 := _snap_place(&"wall", &"thatch", _edge_point(Vector4i(_o.x + 5, _o.y + 4, 0, StructurePiece.EDGE_Z)), Vector4i(_o.x + 5, _o.y + 4, 0, StructurePiece.EDGE_Z))
	var corner := Vector4i(_o.x + 6, _o.y + 3, 0, StructurePiece.CORNER)
	var pil := _snap_place(&"pillar", &"thatch", Vector3(float(corner.x) * M, _floor0, float(corner.y) * M), corner)
	var ceil := _snap_place(&"ceiling", &"thatch", _centre(5, 3, 1), Vector4i(_o.x + 5, _o.y + 3, 1, StructurePiece.CELL))
	var w1 := _snap_place(&"wall", &"thatch", _edge_point(Vector4i(_o.x + 5, _o.y + 3, 1, StructurePiece.EDGE_Z)), Vector4i(_o.x + 5, _o.y + 3, 1, StructurePiece.EDGE_Z))
	_player.placer.cancel()
	_floor0 = house_floor
	if w0 == null or pil == null or ceil == null or w1 == null:
		_expect(false, "lean-to built")
		return
	_expect(_player.placer.demolish(w0, _player), "demolish the supporting wall")
	_expect(is_instance_valid(ceil) and not ceil.is_queued_for_deletion(), "the pillar still holds the ceiling")
	var refund := _player.inventory.count_of(&"branch")
	_expect(refund == 2, "demolish refunds half the wall's branches (got %d)" % refund)
	var fell := pil.destroy("demolished")
	_expect(fell.size() == 2 and ceil in fell and w1 in fell, "removing the last support collapses the ceiling and the wall on it (fell %d)" % fell.size())

# ------------------------------------------------------------------ raptor, repair, upgrade

func _check_raptor_repair_upgrade() -> void:
	var wall := _sg().piece_at(Vector4i(_o.x, _o.y, 0, StructurePiece.EDGE_Z))
	if wall == null or wall.tier != &"wood":
		_expect(false, "south-west wood wall present")
		return
	var sp := Spawner.new()
	sp.species = &"velociraptor"
	sp.count = 1
	sp.radius = 0.1
	sp.position = wall.global_position + Vector3(0, 0, -1.2)
	World.runtime.add_child(sp)
	var raptor: Creature = sp.spawn_now()[0]
	raptor.set_physics_process(false)
	raptor.brain.set_physics_process(false)
	_expect((wall.collision_layer & raptor.collision_mask) != 0, "creatures collide with walls (layer %d, mask %d)" % [wall.collision_layer, raptor.collision_mask])
	_expect(wall in _player.get_collision_exceptions(), "the owner walks through its own wall")
	var before := wall.health.hp
	raptor.apply_species_on_hit(&"attack_primary", wall)
	var dealt := before - wall.health.hp
	var want := raptor.attack_for(false) * raptor.statuses.attack_mult() * float(StructurePiece.tier_def(&"wood").get("creature_mult", 1.0))
	_expect(dealt > 0.0 and absf(dealt - want) < 0.01, "raptor bite on the wood wall through StructureHealth: %.1f (want %.1f)" % [dealt, want])
	raptor.queue_free()
	sp.queue_free()
	var cost := StructurePlacer.repair_cost(wall)
	_expect(not cost.is_empty(), "repair has a material cost %s" % cost)
	for id in cost:
		LabKit.give(_player, id, int(cost[id]))
	_expect(_player.placer.repair(wall, _player), "repair accepted")
	_expect(wall.health.hp == wall.health.max_hp, "repair restores full durability")
	for id in cost:
		_expect(_player.inventory.count_of(id) == 0, "repair took exactly %d %s" % [int(cost[id]), id])
	var id_before := wall.get_instance_id()
	var mesh_before := (wall.get_node("Visual/StandIn") as MeshInstance3D).mesh
	var pos_before := wall.global_transform
	_expect(not _player.placer.upgrade(wall, &"stone", _player), "upgrade refused without stone")
	var up := StructurePiece.cost(&"wall", &"stone")
	for id in up:
		LabKit.give(_player, id, int(up[id]))
	_expect(_player.placer.upgrade(wall, &"stone", _player), "wood-to-stone upgrade accepted")
	var vis := wall.get_node_or_null("Visual/StandIn") as MeshInstance3D
	_expect(is_instance_valid(wall) and wall.get_instance_id() == id_before and wall.tier == &"stone" and _sg().piece_at(wall.slot) == wall, "the upgrade swaps in place (same node, same socket)")
	_expect(wall.global_transform.origin.distance_to(pos_before.origin) < 0.001 and vis != null and vis.mesh != mesh_before, "same pose, stone look")
	_expect(wall.health.max_hp == StructurePiece.max_durability(&"wall", &"stone") and wall.health.hp == wall.health.max_hp, "stone durability %.0f" % wall.health.max_hp)
	for id in up:
		_expect(_player.inventory.count_of(id) == 0, "upgrade took exactly %d %s" % [int(up[id]), id])

# ------------------------------------------------------------------ paths

func _check_paths() -> void:
	var tp := World.runtime.get("pathing") as TilePath
	var outside := _centre(1, 7, 0)
	var inside := _centre(1, 1, 0)
	var door := _sg().piece_at(Vector4i(_door_edge().x, _door_edge().y, 0, StructurePiece.DOOR_Z))
	_expect(door != null and not door.door_open, "door closed")
	tp.path(outside, inside)
	_expect(not tp.last_reachable, "a creature cannot path into the closed house")
	tp.path(outside, inside, TilePath.DEFAULT_MAX_LEN, true)
	_expect(tp.last_reachable, "the owner's path goes through its own door")
	tp.path(outside, inside)
	_expect(not tp.last_reachable, "the owner's query leaves the creature map closed")
	if door:
		door.interact(_player)
		tp.path(outside, inside)
		_expect(door.door_open and tp.last_reachable, "an open door lets a creature path in")
		door.interact(_player)

# ------------------------------------------------------------------ save and load

func _check_save_load() -> void:
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	var dmg := _sg().piece_at(Vector4i(_o.x + 3, _o.y + 2, 0, StructurePiece.EDGE_X))
	dmg.health.take_damage(200.0)
	var want := {}
	for p in _sg().pieces():
		want[p.slot] = [p.kind, p.tier, p.health.hp, p.global_position, p.rot]
	LabKit.give(_player, &"basket_kit", 1)
	_player.placer.begin(&"basket")
	_player.placer.cell = BuildGrid.tile_of(_centre(2, 2, 0))
	_expect(_player.placer.confirm(_player), "a basket kit stands on a foundation inside")
	_expect(SG.save_now(), "save")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	var rows := 0
	for r in (raw as Dictionary).get("home", {}).get("buildings", []):
		rows += 1 if StructurePiece.is_piece_kind(StringName(str(r.get("kind", "")))) else 0
	_expect(int((raw as Dictionary).get("schema", 0)) == 4 and rows == want.size(), "schema 4 save holds %d piece rows (got %d)" % [want.size(), rows])
	SG.load_now(self)
	await get_tree().physics_frame
	var got := 0
	var bad := 0
	for p in _sg().pieces():
		var w: Variant = want.get(p.slot)
		got += 1
		if w == null or w[0] != p.kind or w[1] != p.tier or absf(float(w[2]) - p.health.hp) > 0.01 or (w[3] as Vector3).distance_to(p.global_position) > TOL or int(w[4]) != p.rot:
			bad += 1
	_expect(got == want.size() and bad == 0, "load restores every piece: %d/%d, %d differ" % [got, want.size(), bad])
	var baskets := get_tree().get_nodes_in_group("basket").filter(func (n: Node) -> bool: return not n.is_queued_for_deletion() and n.get("is_cargo") != true)
	_expect(baskets.size() == 1, "the basket on the foundation comes back (got %d)" % baskets.size())
	# An old (schema 3) save: no piece rows existed then. It must load, migrate and keep its kits.
	var old: Dictionary = (raw as Dictionary).duplicate(true)
	old["schema"] = 3
	old["home"]["buildings"] = (old["home"]["buildings"] as Array).filter(func (r: Variant) -> bool: return not StructurePiece.is_piece_kind(StringName(str(r.get("kind", "")))))
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var read := SaveMigrations.read(SG.path)
	_expect(int(read.get("schema", 0)) == 3 and int((read.get("data", {}) as Dictionary).get("schema", 0)) == 4, "a schema-3 save migrates to 4")
	SG.load_now(self)
	await get_tree().physics_frame
	baskets = get_tree().get_nodes_in_group("basket").filter(func (n: Node) -> bool: return not n.is_queued_for_deletion() and n.get("is_cargo") != true)
	_expect(_sg().pieces().is_empty() and baskets.size() == 1, "the schema-3 save loads with its kits and no pieces")
