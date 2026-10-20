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
