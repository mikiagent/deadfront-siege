class_name RagdollSkin
extends RefCounted
## CPU skinning of a creature mesh's vertices, so ground contact is judged on the POSED skin (a
## claw or belly), not on bone heads. The ragdoll's final conform uses a small stride sample; the
## lab's gates use a dense one. Samples are cached per mesh resource and stride.

static var _cache: Dictionary = {}

## Vertex positions in skin space with their bind indices and weights, every `stride`-th vertex.
static func sample(mi: MeshInstance3D, stride: int) -> Dictionary:
	if mi == null or mi.mesh == null or mi.skin == null:
		return {}
	var key := "%d:%d" % [mi.mesh.get_rid().get_id(), stride]
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
		var i := 0
		while i < v.size():
			pos.append(v[i])
			for k in 4:
				bones.append(b[i * per + k] if k < per else 0)
				weights.append(w[i * per + k] if k < per else 0.0)
			i += maxi(1, stride)
	var out := {"pos": pos, "bones": bones, "weights": weights}
	_cache[key] = out
	return out

## World positions of the sampled vertices in the skeleton's current pose.
static func posed_points(mi: MeshInstance3D, sk: Skeleton3D, stride: int) -> PackedVector3Array:
	var s := sample(mi, stride)
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
static func lift_limbs(space: PhysicsDirectSpaceState3D, mi: MeshInstance3D, sk: Skeleton3D, body_bones: Dictionary, exclude: Array[RID], stride: int, max_deg: float, rounds: int = 3, tol: float = 0.02) -> int:
	var s := sample(mi, stride)
	if s.is_empty() or sk == null:
		return 0
	var binds: Array[int] = []
	for k in mi.skin.get_bind_count():
		var b := mi.skin.get_bind_bone(k)
		binds.append(b if b >= 0 else sk.find_bone(mi.skin.get_bind_name(k)))
	var bones: PackedInt32Array = s["bones"]
	var weights: PackedFloat32Array = s["weights"]
	var q := PhysicsRayQueryParameters3D.new()
	q.exclude = exclude
	var turns := 0
	for r in rounds:
		var pts := posed_points(mi, sk, stride)
		var deepest: Dictionary = {}  # chain -> [depth, point, normal]
		for i in pts.size():
			q.from = pts[i] + Vector3(0.0, 2.0, 0.0)
			q.to = pts[i] - Vector3(0.0, 4.0, 0.0)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var n: Vector3 = hit["normal"]
			var depth := (pts[i] - (hit["position"] as Vector3)).dot(n)
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
