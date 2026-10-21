class_name RagdollSkin
extends RefCounted
## CPU skinning of a creature mesh's vertices, so ground contact is judged on the POSED skin (a
## claw or belly), not on bone heads. The ragdoll's final conform uses a small stride sample; the
## lab's gates use a dense one. Samples are cached per mesh resource and stride.

static var _cache: Dictionary = {}

## The ground under skin points for one freeze: one ray per cell of the given size, cached, and the
## hit's plane through the cell (exact on terrain patches and box tops; a rock edge inside a cell is
## off by the cell's slope). A lying carcass' skin covers a few hundred cells at most.
class Ground:
	var space: PhysicsDirectSpaceState3D
	var q := PhysicsRayQueryParameters3D.new()
	var cell: float
	var lift: float
	var cells: Dictionary = {}  # Vector2i -> [hit position, normal] or [] (nothing under it)

	func _init(p_space: PhysicsDirectSpaceState3D, exclude: Array[RID], p_cell: float, p_lift: float) -> void:
		space = p_space
		q.exclude = exclude
		cell = maxf(0.01, p_cell)
		lift = p_lift

	## [ground height under p, ground normal] or [] when nothing is under it.
	func at(p: Vector3) -> Array:
		var key := Vector2i(floori(p.x / cell), floori(p.z / cell))
		var row: Variant = cells.get(key)
		if row == null:
			q.from = Vector3((key.x + 0.5) * cell, p.y + lift, (key.y + 0.5) * cell)
			q.to = q.from - Vector3(0.0, lift * 2.0 + 4.0, 0.0)
			var hit := space.intersect_ray(q)
			row = [hit["position"], hit["normal"]] if not hit.is_empty() else []
			cells[key] = row
		if (row as Array).is_empty():
			return []
		var hp: Vector3 = row[0]
		var n: Vector3 = row[1]
		var y := hp.y - (n.x * (p.x - hp.x) + n.z * (p.z - hp.z)) / maxf(n.y, 0.05)
		return [y, n]

## Metres of lift one radian of conform tilt is worth (rest): a tilt only wins where it saves lift.
const TILT_COST := 0.02

## Vertex positions in skin space with their bind indices and weights, every `stride`-th vertex.
## hull = true adds, per bone (dominant weight), the vertices on the convex hull of its vertex group:
## a body rests on its skin's outer hull and each group moves nearly rigidly, so the parts a stride
## misses (a claw, a jaw, the curve of a thigh) are still in the sample.
static func sample(mi: MeshInstance3D, stride: int, hull: bool = false) -> Dictionary:
	if mi == null or mi.mesh == null or mi.skin == null:
		return {}
	var key := "%d:%d:%s" % [mi.mesh.get_rid().get_id(), stride, hull]
	if _cache.has(key):
		return _cache[key]
	var pos := PackedVector3Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for si in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var b: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		if v.is_empty() or b.size() < v.size() or w.size() != b.size():
			continue
		var per := b.size() / v.size()
		var picked: Dictionary = {}  # vertex index -> true
		var i := 0
		while i < v.size():
			picked[i] = true
			i += maxi(1, stride)
		if hull:
			var groups: Dictionary = {}  # bind -> vertex indices
			for vi in v.size():
				var top := 0
				for k in per:
					if w[vi * per + k] > w[vi * per + top]:
						top = k
				var bind := b[vi * per + top]
				if not groups.has(bind):
					groups[bind] = []
				(groups[bind] as Array).append(vi)
			for bind: int in groups:
				for vi: int in _hull_of(v, groups[bind]):
					picked[vi] = true
		for vi: int in picked:
			pos.append(v[vi])
			for k in 4:
				bones.append(b[vi * per + k] if k < per else 0)
				weights.append(w[vi * per + k] if k < per else 0.0)
	var out := {"pos": pos, "bones": bones, "weights": weights}
	_cache[key] = out
	return out

## The vertices (indices into v) on the convex hull of the listed ones (the engine's QuickHull,
## whose cleaned points sit within ~1e-4 of the vertices they came from).
static func _hull_of(v: PackedVector3Array, idx: Array) -> Array:
	if idx.size() <= 12:
		return idx
	const CELL := 0.002
	var pts := PackedVector3Array()
	var grid: Dictionary = {}  # Vector3i cell -> vertex indices
	for vi: int in idx:
		pts.append(v[vi])
		var key := Vector3i((v[vi] / CELL).floor())
		if not grid.has(key):
			grid[key] = []
		(grid[key] as Array).append(vi)
	while pts.size() % 3 != 0:
		pts.append(pts[pts.size() - 1])  # a triangle soup: only the points matter
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := m.create_convex_shape(true, false)
	if shape == null or shape.points.is_empty():
		return idx
	var out := []
	for p in shape.points:
		var c := Vector3i((p / CELL).floor())
		var best := -1
		var best_d := INF
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for vi: int in grid.get(c + Vector3i(dx, dy, dz), []):
						var d := v[vi].distance_squared_to(p)
						if d < best_d:
							best_d = d
							best = vi
		if best >= 0:
			out.append(best)
	return out if not out.is_empty() else idx

## World positions of the sampled vertices in the skeleton's current pose.
static func posed_points(mi: MeshInstance3D, sk: Skeleton3D, stride: int, hull: bool = false) -> PackedVector3Array:
	var s := sample(mi, stride, hull)
	var out := PackedVector3Array()
	if s.is_empty() or sk == null:
		return out
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for k in skin.get_bind_count():
		var bone := skin.get_bind_bone(k)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(k))
		mats.append(sk.get_bone_global_pose(maxi(bone, 0)) * skin.get_bind_pose(k))
	var xf := sk.global_transform
	var pos: PackedVector3Array = s["pos"]
	var bones: PackedInt32Array = s["bones"]
	var weights: PackedFloat32Array = s["weights"]
	out.resize(pos.size())
	for i in pos.size():
		var acc := Vector3.ZERO
		var wsum := 0.0
		for k in 4:
			var w := weights[i * 4 + k]
			if w <= 0.0:
				continue
			acc += (mats[bones[i * 4 + k]] * pos[i]) * w
			wsum += w
		out[i] = xf * (acc / wsum if wsum > 0.0 else pos[i])
	return out

## Lowest gap between the given points and the ground under each (negative = sunk), the ground
## found by a downward ray on `mask` from `lift` m above the point. Returns {min, hits, below}.
static func clearance(space: PhysicsDirectSpaceState3D, points: PackedVector3Array, exclude: Array[RID], mask: int = 1, lift: float = 2.0, below_m: float = 0.06) -> Dictionary:
	var lowest := INF
	var hits := 0
	var below := 0
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = mask
	q.exclude = exclude
	for p in points:
		q.from = p + Vector3(0.0, lift, 0.0)
		q.to = p - Vector3(0.0, 4.0, 0.0)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		hits += 1
		var gap := p.y - (hit["position"] as Vector3).y
		lowest = minf(lowest, gap)
		if gap < -below_m:
			below += 1
	return {"min": lowest if hits > 0 else 0.0, "hits": hits, "below": below}

## Ground height under a point (same ray rule), or `fallback` when nothing is there.
static func ground_y(space: PhysicsDirectSpaceState3D, p: Vector3, exclude: Array[RID], fallback: float, mask: int = 1) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p - Vector3(0.0, 8.0, 0.0), mask, exclude)
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else fallback

## Ground normal under a point (same ray rule), or UP when nothing is there.
static func ground_normal(space: PhysicsDirectSpaceState3D, p: Vector3, exclude: Array[RID], mask: int = 1) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p - Vector3(0.0, 8.0, 0.0), mask, exclude)
	var hit := space.intersect_ray(q)
	return (hit["normal"] as Vector3).normalized() if not hit.is_empty() else Vector3.UP

## Turns limbs whose posed skin went into the ground back onto it. Per round, for every chain with
## sunk vertices (more than `tol` m under), the chain turns about its joint until its deepest vertex
## is on the ground (at most max_deg). A chain is the first bone below the nearest simulated body
## (`body_bones`, bone index -> true) on the way to the vertex's dominant bone: a limb end the
## ragdoll did not simulate, so it followed its body through the ground. Simulated bones keep their
## joint limits; their skin and the trunk are left to the vertical conform. Returns the turns made.
static func lift_limbs(ground: Ground, mi: MeshInstance3D, sk: Skeleton3D, body_bones: Dictionary, stride: int, max_deg: float, rounds: int = 3, tol: float = 0.02) -> int:
	var s := sample(mi, stride, true)
	if s.is_empty() or sk == null:
		return 0
	var binds: Array[int] = []
	for k in mi.skin.get_bind_count():
		var b := mi.skin.get_bind_bone(k)
		binds.append(b if b >= 0 else sk.find_bone(mi.skin.get_bind_name(k)))
	var bones: PackedInt32Array = s["bones"]
	var weights: PackedFloat32Array = s["weights"]
	var turns := 0
	for r in rounds:
		var pts := posed_points(mi, sk, stride, true)
		var deepest: Dictionary = {}  # chain -> [depth, point, normal]
		for i in pts.size():
			var g0 := ground.at(pts[i])
			if g0.is_empty():
				continue
			var n: Vector3 = g0[1]
			var depth := (pts[i].y - float(g0[0])) * n.y  # along the ground normal
			if depth > -tol:
				continue
			var top := 0
			for k in 4:
				if weights[i * 4 + k] > weights[i * 4 + top]:
					top = k
			var chain := _limb_chain(sk, binds[bones[i * 4 + top]], body_bones)
			if chain >= 0 and (not deepest.has(chain) or depth < float(deepest[chain][0])):
				deepest[chain] = [depth, pts[i], n]
		if deepest.is_empty():
			break
		var g := sk.global_transform
		for chain: int in deepest:
			var row: Array = deepest[chain]
			var joint := g * sk.get_bone_global_pose(chain).origin
			var arm := (row[1] as Vector3) - joint
			var axis := arm.cross(row[2] as Vector3)
			if axis.length_squared() < 1e-8:
				continue
			var ang := minf(asin(clampf(-float(row[0]) / maxf(arm.length(), 0.01), 0.0, 1.0)) + 0.02, deg_to_rad(max_deg))
			var rs := g.basis.orthonormalized().inverse() * Basis(axis.normalized(), ang) * g.basis.orthonormalized()
			var p := sk.get_bone_parent(chain)
			var pg := sk.get_bone_global_pose(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
			var now := sk.get_bone_global_pose(chain).basis.orthonormalized()
			sk.set_bone_pose_rotation(chain, (pg.inverse() * rs * now).get_rotation_quaternion())
			turns += 1
	return turns

## The bone a sunk vertex's limb turns about (see lift_limbs), or -1 when it is the trunk.
static func _limb_chain(sk: Skeleton3D, bone: int, body_bones: Dictionary) -> int:
	var chain := bone
	if chain < 0 or body_bones.has(chain):
		return -1
	while true:
		var p := sk.get_bone_parent(chain)
		if p < 0 or body_bones.has(p):
			break
		chain = p
	if sk.get_bone_parent(chain) < 0:
		return -1
	# The root body (no body above it) is the trunk.
	var a := sk.get_bone_parent(chain)
	var has_body_above := false
	while a >= 0:
		if body_bones.has(a):
			has_body_above = true
			break
		a = sk.get_bone_parent(a)
	if not has_body_above:
		return -1
	# A bone carrying another body is structure, not a limb end.
	var stack: Array[int] = [chain]
	while not stack.is_empty():
		var b: int = stack.pop_back()
		for c in sk.get_bone_children(b):
			if body_bones.has(c):
				return -1
			stack.append(c)
	return chain

## Rests the posed skin on the ground with the least change to the pose the simulation found: per
## round, the smallest tilt about the sample's centroid (at most max_tilt rad) that takes the parts
## the capsules let sink out of the ground without lifting the carcass (or, when no tilt can, the
## one that needs the least lift), then the vertical shift that puts the lowest point on the ground;
## the last round only shifts. Moves `view` (the creature's posed model).
## Returns {shift: m (+ = lifted), tilt: rad}.
static func rest(ground: Ground, mi: MeshInstance3D, sk: Skeleton3D, view: Node3D, stride: int, max_tilt: float, rounds: int) -> Dictionary:
	var shift := 0.0
	var tilt := 0.0
	for r in rounds + 1:
		var pts := posed_points(mi, sk, stride, true)
		var gaps := PackedFloat32Array()
		var rel := PackedVector2Array()  # (x, z) from the centroid
		var c := Vector3.ZERO
		var hits := PackedVector3Array()
		for p in pts:
			var g0 := ground.at(p)
			if g0.is_empty():
				continue
			hits.append(p)
			gaps.append(p.y - float(g0[0]))
			c += p
		if hits.is_empty():
			break
		c /= float(hits.size())
		for p in hits:
			rel.append(Vector2(p.x - c.x, p.z - c.z))
		var w := Vector2.ZERO  # rotation vector (x, z) components
		if r < rounds and max_tilt > 0.0:
			w = _least_tilt(gaps, rel, max_tilt)
		var dz := _shift_for(gaps, rel, w)
		var xf := view.global_transform
		if w.length_squared() > 1e-10:
			var rot := Basis(Vector3(w.x, 0.0, w.y).normalized(), w.length())
			xf = Transform3D(rot, c - rot * c) * xf
			tilt += w.length()
		xf.origin.y += dz
		view.global_transform = xf
		shift += dz
	return {"shift": shift, "tilt": tilt}

## Shift that puts the lowest point on the ground after the small tilt w (first order: a point at
## (x, z) from the centroid rises by w.y * x - w.x * z).
static func _shift_for(gaps: PackedFloat32Array, rel: PackedVector2Array, w: Vector2) -> float:
	var need := -INF
	for i in gaps.size():
		need = maxf(need, -gaps[i] - (w.y * rel[i].x - w.x * rel[i].y))
	return need

## The tilt (|w| <= max_tilt) minimising max(lift, 0) + TILT_COST * |w|: no lift with the least
## tilt, else the least lift. Convex, so a 5x5 grid refined four times finds it; a tilt must win by
## a millimetre, so a body already resting on its supports keeps its pose.
static func _least_tilt(gaps: PackedFloat32Array, rel: PackedVector2Array, max_tilt: float) -> Vector2:
	# Only points that some allowed tilt can bring to the lowest contact matter.
	var reach := 0.0
	var lowest := INF
	for i in gaps.size():
		reach = maxf(reach, rel[i].length())
		lowest = minf(lowest, gaps[i])
	var g := PackedFloat32Array()
	var rr := PackedVector2Array()
	for i in gaps.size():
		if gaps[i] - max_tilt * rel[i].length() <= lowest + max_tilt * reach:
			g.append(gaps[i])
			rr.append(rel[i])
	var best := Vector2.ZERO
	var best_f := maxf(_shift_for(g, rr, best), 0.0)
	var step := max_tilt * 0.5
	for level in 4:
		var centre := best
		for a in range(-2, 3):
			for b in range(-2, 3):
				var w := centre + Vector2(a, b) * step
				if w.length() > max_tilt or (a == 0 and b == 0):
					continue
				var f := maxf(_shift_for(g, rr, w), 0.0) + TILT_COST * w.length()
				if f < best_f - 0.001:
					best_f = f
					best = w
		step *= 0.4
	return best
