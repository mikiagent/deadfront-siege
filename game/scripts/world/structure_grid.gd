class_name StructureGrid
extends RefCounted
## Modular-piece occupancy for one island, keyed by StructurePiece slots (module cell, level, code):
## placement rules, structural support (collapse) and the socket search the placer snaps to.
## BuildGrid owns one; it asks here which 1 m cells a level-0 wall blocks for creatures and which
## cells carry a foundation floor (kits may stand on those).

var build_grid: BuildGrid
var _slots: Dictionary = {}       # Vector4i -> StructurePiece
var _floor_cells: Dictionary = {} # Vector2i (1 m) -> StructurePiece: level-0 foundations and ramps
var _path_cells: Dictionary = {}  # Vector2i (1 m) -> StructurePiece: blocks creatures
var _piece_cells: Dictionary = {} # piece instance id -> Array of 1 m cells it registered
var _roof_groups: Dictionary = {} # roof/ceiling piece instance id -> its storey's roof group Node3D

func _init(owner_grid: BuildGrid) -> void:
	build_grid = owner_grid

func piece_at(key: Vector4i) -> StructurePiece:
	var p: Variant = _slots.get(key)
	return p as StructurePiece if is_instance_valid(p) else null

func pieces() -> Array[StructurePiece]:
	var out: Array[StructurePiece] = []
	var seen := {}
	for p in _slots.values():
		if is_instance_valid(p) and not seen.has((p as Object).get_instance_id()):
			seen[(p as Object).get_instance_id()] = true
			out.append(p as StructurePiece)
	return out

func floor_piece_at_cell(c: Vector2i) -> StructurePiece:
	var p: Variant = _floor_cells.get(c)
	return p as StructurePiece if is_instance_valid(p) else null

func blocks_cell(c: Vector2i) -> bool:
	return is_instance_valid(_path_cells.get(c))

func path_blocked_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _path_cells:
		out.append(c)
	return out

# ------------------------------------------------------------------ registration

func register(p: StructurePiece) -> void:
	for k in p.keys():
		_slots[k] = p
	var cells: Array[Vector2i] = []
	if p.slot.z == 0 and (p.kind == &"foundation" or p.kind == &"ramp"):
		for c in module_cells(Vector2i(p.slot.x, p.slot.y)):
			_floor_cells[c] = p
			cells.append(c)
	_piece_cells[p.get_instance_id()] = cells
	refresh_piece(p)
	if p.is_roof():
		p.attach_visual(roof_group(p))

## One node per storey of a connected building that its roofs and ceilings hang their looks under,
## made occludable "inside" (W2-OCCLUDE): the survivor under any part of it fades the whole storey's
## roof, which a per-piece fade cannot do (from the iso pitch the roof between the camera and a
## survivor indoors is the piece nearest the camera, not the one overhead). Pieces that bridge two
## groups merge them.
# shortcut: a group is never split when a piece in its middle goes; the two halves keep fading
# together until the island reloads. Upgrade if separate buildings ever share a roof line.
func roof_group(p: StructurePiece) -> Node3D:
	var found: Array[Node3D] = []
	for nb in neighbours(Vector2i(p.slot.x, p.slot.y)):
		var n := piece_at(Vector4i(nb.x, nb.y, p.slot.z, StructurePiece.CELL))
		var g: Variant = _roof_groups.get(n.get_instance_id()) if n else null
		if is_instance_valid(g) and not found.has(g):
			found.append(g as Node3D)
	var group: Node3D = found[0] if not found.is_empty() else null
	if group == null:
		group = Node3D.new()
		group.name = "RoofGroup"
		build_grid.runtime.add_child(group)
		StructurePiece._occlusion(group, &"roof")
	for other in found.slice(1):
		StructurePiece._occlusion(other, &"none")  # its meshes are re-adopted by the group they join
		for id in _roof_groups:
			if _roof_groups[id] == other:
				_roof_groups[id] = group
		for c in other.get_children():
			c.reparent(group)
		other.queue_free()
	_roof_groups[p.get_instance_id()] = group
	return group

func unregister(p: StructurePiece) -> void:
	_roof_groups.erase(p.get_instance_id())
	for k in p.keys():
		if _slots.get(k) == p:
			_slots.erase(k)
	var changed: Array = []
	for c in _piece_cells.get(p.get_instance_id(), []):
		if _floor_cells.get(c) == p:
			_floor_cells.erase(c)
			changed.append(c)
	_piece_cells.erase(p.get_instance_id())
	for c in _path_cells.keys():
		if _path_cells[c] == p:
			_path_cells.erase(c)
			changed.append(c)
	build_grid.cells_changed(changed)

## Re-flag the creature-blocking cells of a piece (placed, removed, door opened or closed).
func refresh_piece(p: StructurePiece) -> void:
	var changed: Array = []
	for c in _path_cells.keys():
		if _path_cells[c] == p:
			_path_cells.erase(c)
			changed.append(c)
	if is_instance_valid(p) and not p.is_queued_for_deletion() and _slots.get(p.slot) == p:
		for c in enemy_cells(p):
			_path_cells[c] = p
			changed.append(c)
	build_grid.cells_changed(changed)

## 1 m cells a level-0 blocker closes to creatures: the row of cells on the module side of its edge.
## A doorway is open unless its door is shut; the owner's own path ignores all of these.
func enemy_cells(p: StructurePiece) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if p.slot.z != 0:
		return out
	var blocks := str(StructurePiece.piece_def(p.kind).get("blocks", "none"))
	if blocks == "none" or blocks == "enemies_unless_open" or (blocks == "enemies_when_closed" and p.door_open):
		return out
	var n := cells_per_module()
	var base := Vector2i(p.slot.x * n, p.slot.y * n)
	if p.slot.w == StructurePiece.EDGE_X or p.slot.w == StructurePiece.DOOR_X:
		for i in n:
			out.append(base + Vector2i(0, i))
	elif p.slot.w == StructurePiece.EDGE_Z or p.slot.w == StructurePiece.DOOR_Z:
		for i in n:
			out.append(base + Vector2i(i, 0))
	return out

static func cells_per_module() -> int:
	return maxi(1, roundi(StructurePiece.module_m() / BuildGrid.CELL_SIZE))

static func module_cells(m: Vector2i) -> Array[Vector2i]:
	var n := cells_per_module()
	var out: Array[Vector2i] = []
	for dz in n:
		for dx in n:
			out.append(Vector2i(m.x * n + dx, m.y * n + dz))
	return out

static func module_of(world: Vector3) -> Vector2i:
	var m := StructurePiece.module_m()
	return Vector2i(floori(world.x / m), floori(world.z / m))

## Saved piece rows back onto the island (save load, coming home). Rows are checked one by one
## (StructurePiece.from_dict); a malformed row, a taken slot or a broken piece is skipped and
## logged; whatever the restored set cannot hold up then collapses. Returns the pieces restored.
func restore(rows: Array, parent: Node) -> int:
	var pieces_in: Array[StructurePiece] = []
	for row in rows:
		var p: StructurePiece = StructurePiece.from_dict(row) if row is Dictionary else null
		if p == null or p.health.hp <= 0.0:
			print("[struct] skipped a saved piece row that is not a valid piece")
			if p:
				p.free()
			continue
		pieces_in.append(p)
	pieces_in.sort_custom(func (a: StructurePiece, b: StructurePiece) -> bool:
		return a.slot.z < b.slot.z or (a.slot.z == b.slot.z and a.slot.w < b.slot.w))
	var n := 0
	for p in pieces_in:
		var taken := false
		for k in p.keys():
			taken = taken or piece_at(k) != null
		if taken:
			print("[struct] skipped saved %s at %s: slot taken" % [p.kind, p.slot])
			p.free()
			continue
		parent.add_child(p)
		register(p)
		n += 1
	var fell := collapse_unsupported()
	print("[struct] restored %d pieces (%d unsupported)" % [n - fell.size(), fell.size()])
	return n - fell.size()

## Rows of every live piece (SaveGame writes them beside the kit rows).
func to_rows() -> Array:
	var out: Array = []
	for p in pieces():
		if not p.is_queued_for_deletion():
			out.append(p.to_dict())
	return out

# ------------------------------------------------------------------ queries used by the rules

## The walkable floor at a module cell and level: a foundation (level 0) or a ceiling (level >= 1).
func floor_at(m: Vector2i, level: int) -> StructurePiece:
	var p := piece_at(Vector4i(m.x, m.y, level, StructurePiece.CELL))
	return p if p and p.is_floor() else null

func wall_at(edge: Vector4i) -> StructurePiece:
	var p := piece_at(edge)
	return p if p and p.is_wall_type() else null

## The two module cells either side of an edge slot.
static func edge_cells(e: Vector4i) -> Array[Vector2i]:
	if e.w == StructurePiece.EDGE_X or e.w == StructurePiece.DOOR_X:
		return [Vector2i(e.x - 1, e.y), Vector2i(e.x, e.y)]
	return [Vector2i(e.x, e.y - 1), Vector2i(e.x, e.y)]

## The four edge slots around a module cell at a level.
static func cell_edges(m: Vector2i, level: int) -> Array[Vector4i]:
	return [Vector4i(m.x, m.y, level, StructurePiece.EDGE_X), Vector4i(m.x + 1, m.y, level, StructurePiece.EDGE_X),
		Vector4i(m.x, m.y, level, StructurePiece.EDGE_Z), Vector4i(m.x, m.y + 1, level, StructurePiece.EDGE_Z)]

static func cell_corners(m: Vector2i, level: int) -> Array[Vector4i]:
	return [Vector4i(m.x, m.y, level, StructurePiece.CORNER), Vector4i(m.x + 1, m.y, level, StructurePiece.CORNER),
		Vector4i(m.x, m.y + 1, level, StructurePiece.CORNER), Vector4i(m.x + 1, m.y + 1, level, StructurePiece.CORNER)]

static func corner_cells(k: Vector4i) -> Array[Vector2i]:
	return [Vector2i(k.x - 1, k.y - 1), Vector2i(k.x, k.y - 1), Vector2i(k.x - 1, k.y), Vector2i(k.x, k.y)]

## The four 1 m cells that meet at a corner slot (a pillar on bare ground stands on these).
static func corner_ground_cells(k: Vector4i) -> Array[Vector2i]:
	var n := cells_per_module()
	var c := Vector2i(k.x * n, k.y * n)
	return [c + Vector2i(-1, -1), c + Vector2i(0, -1), c + Vector2i(-1, 0), c]

static func neighbours(m: Vector2i) -> Array[Vector2i]:
	return [m + Vector2i(1, 0), m + Vector2i(-1, 0), m + Vector2i(0, 1), m + Vector2i(0, -1)]

## Direct support for a slab at a level: a wall-type on one of its edges or a pillar on one of its
## corners, one storey down.
func _slab_direct(m: Vector2i, level: int) -> StructurePiece:
	for e in cell_edges(m, level - 1):
		var w := wall_at(e)
		if w:
			return w
	for k in cell_corners(m, level - 1):
		var p := piece_at(k)
		if p and p.kind == &"pillar":
			return p
	return null

# ------------------------------------------------------------------ placement rules

## Can `kind` go into slot (with rot)? {reason: "" when it can, floor0, variant, span}.
## Reasons: occupied, stairwell, max_level, no_support, unclaimed, water, overlap, reserved,
## resource, slope, no_blueprint.
func check(kind: StringName, s: Vector4i, rot: int, p_tier: StringName = &"thatch") -> Dictionary:
	var out := {"reason": "", "floor0": 0.0, "variant": 0, "span": 0}
	var pd := StructurePiece.piece_def(kind)
	if pd.is_empty() or StructurePiece.blueprint(kind, p_tier).is_empty():
		out["reason"] = "no_blueprint"
		return out
	var lv: Array = pd.get("levels", [0, 0])
	if s.z < int(lv[0]) or s.z > mini(int(lv[1]), int(StructurePiece.defs().get("max_levels", 4))):
		out["reason"] = "max_level"
		return out
	for k in StructurePiece.keys_for(kind, s, rot):
		if piece_at(k) != null:
			out["reason"] = "occupied"
			return out
	var m := Vector2i(s.x, s.y)
	match kind:
		&"foundation":
			return _check_foundation(m, out)
		&"ramp":
			return _check_ramp(m, rot, out)
		&"ceiling", &"roof", &"roof_peak":
			if piece_at(Vector4i(m.x, m.y, s.z, StructurePiece.STAIRWELL)):
				out["reason"] = "stairwell"
				return out
			var direct := _slab_direct(m, s.z)
			if direct:
				out["floor0"] = direct.floor0
				return out
			var best: StructurePiece = null
			for nb in neighbours(m):
				var n := piece_at(Vector4i(nb.x, nb.y, s.z, StructurePiece.CELL))
				if n and n.kind in [&"ceiling", &"roof", &"roof_peak"] and n.span + 1 <= int(StructurePiece.defs().get("max_span", 2)):
					if best == null or n.span < best.span:
						best = n
			if best == null:
				out["reason"] = "no_support"
				return out
			out["floor0"] = best.floor0
			out["span"] = best.span + 1
			return out
		&"stairs":
			var f := StructurePiece.FWD[posmod(rot, 4)]
			var a := floor_at(m, s.z)
			var b := floor_at(m + f, s.z)
			if a == null or b == null:
				out["reason"] = "no_support"
				return out
			for c in [m, m + f]:
				if piece_at(Vector4i(c.x, c.y, s.z + 1, StructurePiece.CELL)):
					out["reason"] = "stairwell"  # a ceiling over the run would hit the climber's head
					return out
			out["floor0"] = a.floor0
			return out
		&"pillar":
			if s.z == 0:
				for c in corner_cells(s):
					var fp := floor_at(c, 0)
					if fp:
						out["floor0"] = fp.floor0
						return out
				var why := _ground_ok(corner_ground_cells(s), false)
				if why != "":
					out["reason"] = why
					return out
				out["floor0"] = _terrain_y(Vector3(float(s.x) * StructurePiece.module_m(), 0.0, float(s.y) * StructurePiece.module_m()))
				return out
			var below := piece_at(Vector4i(s.x, s.y, s.z - 1, StructurePiece.CORNER))
			if below:
				out["floor0"] = below.floor0
				return out
			for c in corner_cells(s):
				var fl := floor_at(c, s.z)
				if fl:
					out["floor0"] = fl.floor0
					return out
			out["reason"] = "no_support"
			return out
		&"door":
			var dw := piece_at(Vector4i(s.x, s.y, s.z, StructurePiece.EDGE_X if s.w == StructurePiece.DOOR_X else StructurePiece.EDGE_Z))
			if dw == null or dw.kind != &"doorway":
				out["reason"] = "no_support"
				return out
			out["floor0"] = dw.floor0
			return out
	if is_furniture(kind):  # chests, boxes, signs: one per floor module, not on a stair run
		var fl := floor_at(m, s.z)
		if fl == null:
			out["reason"] = "no_support"
			return out
		out["floor0"] = fl.floor0
		return out
	# Wall types: on a floor at this level (either side) or on a wall-type one storey down.
	for c in edge_cells(s):
		var fl2 := floor_at(c, s.z)
		if fl2:
			out["floor0"] = fl2.floor0
			return out
	if s.z > 0:
		var under := wall_at(Vector4i(s.x, s.y, s.z - 1, s.w))
		if under:
			out["floor0"] = under.floor0
			return out
	out["reason"] = "no_support"
	return out

func _check_foundation(m: Vector2i, out: Dictionary) -> Dictionary:
	var cells := module_cells(m)
	var why := _ground_ok(cells, true)
	if why != "":
		out["reason"] = why
		return out
	var lo_hi := _terrain_span(m)
	var clear := float(StructurePiece.defs().get("floor_clear_m", 0.12))
	var max_skirt := float(StructurePiece.defs().get("max_skirt_m", 1.2))
	var floor0: float = lo_hi.y + clear
	for nb in neighbours(m):
		var n := floor_at(nb, 0)
		if n:
			floor0 = n.floor0  # snapped foundations share one floor height; the skirt takes up the slope
			break
	if lo_hi.y > floor0 - 0.02 or floor0 - lo_hi.x > max_skirt:
		out["reason"] = "slope"
		return out
	out["floor0"] = floor0
	out["variant"] = ceili((floor0 - lo_hi.x + 0.1) * 10.0)
	return out

func _check_ramp(m: Vector2i, rot: int, out: Dictionary) -> Dictionary:
	var f := StructurePiece.FWD[posmod(rot, 4)]
	var top := floor_at(m + f, 0)
	if top == null or top.kind != &"foundation":
		out["reason"] = "no_support"
		return out
	var why := _ground_ok(module_cells(m), true)
	if why != "":
		out["reason"] = why
		return out
	var lo_hi := _terrain_span(m)
	var drop: float = top.floor0 - lo_hi.x
	if lo_hi.y > top.floor0 or drop > float(StructurePiece.defs().get("max_skirt_m", 1.2)) + 0.4:
		out["reason"] = "slope"
		return out
	out["floor0"] = top.floor0
	out["variant"] = maxi(1, roundi(drop * 10.0))
	return out

## Level-0 ground rules for 1 m cells (kits use BuildGrid.can_place for the same checks).
func _ground_ok(cells: Array[Vector2i], need_free: bool) -> String:
	var rt := build_grid.runtime
	for c in cells:
		if build_grid.is_reserved(c):
			return "reserved"
		if need_free and (build_grid.occupant(c) != null or _floor_cells.has(c)):
			return "overlap"
	if rt and rt.has_method("is_claimed"):
		for c in cells:
			if not rt.is_claimed(c):
				return "unclaimed"
	for c in cells:
		if rt and rt.has_method("spawn_ok") and not rt.spawn_ok(BuildGrid.tile_centre(c, rt), false):
			return "water"
	for c in cells:
		if build_grid.harvest_at(c):
			return "resource"
	return ""

## (lowest, highest) terrain height over a module square's corners and centre.
func _terrain_span(m: Vector2i) -> Vector2:
	var s := StructurePiece.module_m()
	var x0 := float(m.x) * s
	var z0 := float(m.y) * s
	var lo := INF
	var hi := -INF
	for p in [Vector2(x0, z0), Vector2(x0 + s, z0), Vector2(x0, z0 + s), Vector2(x0 + s, z0 + s), Vector2(x0 + s * 0.5, z0 + s * 0.5)]:
		var y := _terrain_y(Vector3(p.x, 0.0, p.y))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi)

func _terrain_y(at: Vector3) -> float:
	var rt := build_grid.runtime
	return float(rt.surface_y(at.x, at.z)) if rt and rt.has_method("surface_y") else 0.0

# ------------------------------------------------------------------ support

## Recompute support level by level from the ground and destroy every piece nothing holds up.
## Floors at level k rest on walls/pillars of level k-1 (or span max_span modules from such a
## slab); walls rest on a floor at their level or on the wall below; doors need their doorway.
func collapse_unsupported() -> Array[StructurePiece]:
	var ok := {}
	var all := pieces()
	var by_level := {}
	var top := 0
	for p in all:
		if p.is_queued_for_deletion():
			continue
		top = maxi(top, p.slot.z)
		(by_level.get_or_add(p.slot.z, []) as Array).append(p)
	var max_span := int(StructurePiece.defs().get("max_span", 2))
	for level in range(0, top + 1):
		var here: Array = by_level.get(level, [])
		var queue: Array[StructurePiece] = []
		for p in here:
			var sp := p as StructurePiece
			if sp.kind == &"foundation":
				ok[sp] = true
			elif level > 0 and sp.slot.w == StructurePiece.CELL and _slab_supported(sp, ok):
				ok[sp] = true
				sp.span = 0
				queue.append(sp)
		while not queue.is_empty():
			var q: StructurePiece = queue.pop_front()
			for nb in neighbours(Vector2i(q.slot.x, q.slot.y)):
				var n := piece_at(Vector4i(nb.x, nb.y, level, StructurePiece.CELL))
				if n and not ok.has(n) and n.kind in [&"ceiling", &"roof", &"roof_peak"] and q.span + 1 <= max_span:
					ok[n] = true
					n.span = q.span + 1
					queue.append(n)
		for pass_kind in [&"ramp", &"pillar", &"stairs", &"wall", &"door", &"furniture"]:
			for p in here:
				var sp2 := p as StructurePiece
				if not ok.has(sp2) and _kind_group(sp2.kind) == pass_kind and _supported(sp2, ok):
					ok[sp2] = true
	var fell: Array[StructurePiece] = []
	for p in all:
		if not ok.has(p) and not p.is_queued_for_deletion():
			fell.append(p)
	for p in fell:
		p.spill_storage()
		unregister(p)
		print("[struct] %s %s collapsed at %s" % [p.tier, p.kind, p.slot])
		p.queue_free()
	return fell

static func _kind_group(k: StringName) -> StringName:
	if is_furniture(k):
		return &"furniture"
	return &"wall" if k in StructurePiece.WALL_KINDS else k

## Pieces that stand on a floor module (structures.json slot "on_floor"): chest, large box, sign.
static func is_furniture(k: StringName) -> bool:
	return str(StructurePiece.piece_def(k).get("slot", "")) == "on_floor"

func _slab_supported(p: StructurePiece, ok: Dictionary) -> bool:
	for e in cell_edges(Vector2i(p.slot.x, p.slot.y), p.slot.z - 1):
		var w := wall_at(e)
		if w and ok.has(w):
			return true
	for k in cell_corners(Vector2i(p.slot.x, p.slot.y), p.slot.z - 1):
		var c := piece_at(k)
		if c and c.kind == &"pillar" and ok.has(c):
			return true
	return false

func _supported(p: StructurePiece, ok: Dictionary) -> bool:
	var m := Vector2i(p.slot.x, p.slot.y)
	match p.kind:
		&"ramp":
			var top := floor_at(m + StructurePiece.FWD[p.rot], 0)
			return top != null and ok.has(top)
		&"pillar":
			if p.slot.z == 0:
				return true
			var below := piece_at(Vector4i(p.slot.x, p.slot.y, p.slot.z - 1, StructurePiece.CORNER))
			if below and ok.has(below):
				return true
			for c in corner_cells(p.slot):
				var fl := floor_at(c, p.slot.z)
				if fl and ok.has(fl):
					return true
			return false
		&"stairs":
			var a := floor_at(m, p.slot.z)
			var b := floor_at(m + StructurePiece.FWD[p.rot], p.slot.z)
			return a != null and b != null and ok.has(a) and ok.has(b)
		&"door":
			var dw := piece_at(Vector4i(p.slot.x, p.slot.y, p.slot.z, StructurePiece.EDGE_X if p.slot.w == StructurePiece.DOOR_X else StructurePiece.EDGE_Z))
			return dw != null and ok.has(dw)
	if is_furniture(p.kind):
		var under := floor_at(m, p.slot.z)
		return under != null and ok.has(under)
	for c in edge_cells(p.slot):
		var fl2 := floor_at(c, p.slot.z)
		if fl2 and ok.has(fl2):
			return true
	if p.slot.z > 0:
		var under := wall_at(Vector4i(p.slot.x, p.slot.y, p.slot.z - 1, p.slot.w))
		return under != null and ok.has(under)
	return false

# ------------------------------------------------------------------ sockets

## Candidate slots for a kind around a world point: module cells, edges or corners within
## `radius` modules, at the kind's levels up to one storey above the highest piece nearby.
func candidates(kind: StringName, around: Vector3, radius: int = 2) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	var pd := StructurePiece.piece_def(kind)
	var lv: Array = pd.get("levels", [0, 0])
	var m0 := module_of(around)
	var top := -1
	for p in pieces():
		if absi(p.slot.x - m0.x) <= radius + 2 and absi(p.slot.y - m0.y) <= radius + 2:
			top = maxi(top, p.slot.z)
	var hi := mini(int(lv[1]), mini(top + 1, int(StructurePiece.defs().get("max_levels", 4))))
	var slot_kind := str(pd.get("slot", "cell"))
	for level in range(int(lv[0]), hi + 1):
		for dz in range(-radius, radius + 2):
			for dx in range(-radius, radius + 2):
				var x := m0.x + dx
				var z := m0.y + dz
				match slot_kind:
					"edge":
						if dz <= radius:
							out.append(Vector4i(x, z, level, StructurePiece.EDGE_X))
						if dx <= radius:
							out.append(Vector4i(x, z, level, StructurePiece.EDGE_Z))
					"door":
						for code in [StructurePiece.EDGE_X, StructurePiece.EDGE_Z]:
							var dw := piece_at(Vector4i(x, z, level, code))
							if dw and dw.kind == &"doorway":
								out.append(Vector4i(x, z, level, StructurePiece.DOOR_X if code == StructurePiece.EDGE_X else StructurePiece.DOOR_Z))
					"corner":
						out.append(Vector4i(x, z, level, StructurePiece.CORNER))
					_:
						if dx <= radius and dz <= radius:
							out.append(Vector4i(x, z, level, StructurePiece.slot_code(kind)))
	return out

## Where a slot reads as "aimed at": the middle of the piece it would hold.
static func anchor(kind: StringName, s: Vector4i, rot: int, floor0: float) -> Vector3:
	var t := StructurePiece.pose(kind, s, rot, floor0)
	match s.w:
		StructurePiece.EDGE_X, StructurePiece.EDGE_Z, StructurePiece.DOOR_X, StructurePiece.DOOR_Z, StructurePiece.CORNER:
			return t.origin + Vector3(0, StructurePiece.storey_m() * 0.5, 0)
	return t.origin

## Auto orientation for oriented pieces when the player has not rotated: a roof's low edge faces
## out over a wall with nothing beyond, a ridge runs between its slopes, a ramp faces its foundation.
func suggested_rot(kind: StringName, s: Vector4i, fallback: int) -> int:
	var m := Vector2i(s.x, s.y)
	match kind:
		&"ramp":
			for r in 4:
				if floor_at(m + StructurePiece.FWD[r], 0):
					return r
		&"roof":
			for r in 4:
				var low := m - StructurePiece.FWD[r]
				var beyond := piece_at(Vector4i(low.x, low.y, s.z, StructurePiece.CELL))
				var e := _edge_between(m, low, s.z - 1)
				if beyond == null and wall_at(e) != null:
					return r
		&"roof_peak":
			for r in [0, 1]:
				var f := StructurePiece.FWD[r]
				var a := piece_at(Vector4i(m.x + f.x, m.y + f.y, s.z, StructurePiece.CELL))
				var b := piece_at(Vector4i(m.x - f.x, m.y - f.y, s.z, StructurePiece.CELL))
				if (a and a.kind == &"roof") or (b and b.kind == &"roof"):
					return r
	return fallback

## The edge slot between two side-by-side module cells at a level.
static func _edge_between(a: Vector2i, b: Vector2i, level: int) -> Vector4i:
	if a.y == b.y:
		return Vector4i(maxi(a.x, b.x), a.y, level, StructurePiece.EDGE_X)
	return Vector4i(a.x, maxi(a.y, b.y), level, StructurePiece.EDGE_Z)
