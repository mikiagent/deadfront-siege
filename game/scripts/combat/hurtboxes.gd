class_name Hurtboxes
extends Area3D
## HITBOXES: the places a body can be hit. A few capsules ride the skeleton's bones (head, neck,
## torso, hips, tail segments, legs), fitted once per model from the skinned mesh: every sampled
## vertex goes to its strongest bone, bones with too few vertices hand theirs to the parent, and each
## remaining bone gets the capsule around its vertices (principal axis, trimmed ends, a high-percentile
## radius). data/creatures/hitboxes.json "hurtbox" tunes the fit and can scale a species or one bone.
## The capsules sit on their own physics layer (LAYER) on this Area3D: they never block movement,
## and other systems can query that layer. Hitbox judges hits on the same capsules analytically (world_capsules
## after a sync), because the physics broadphase moves a shape only on the next step. Built on first use (a
## hit or the debug draw), synced from the live pose right before a check, so idle animals cost nothing.

const LAYER := 1 << 19  ## physics layer 20: hurtboxes only
const NAME := &"Hurtboxes"
const REGIONS := [["jaw", &"head"], ["head", &"head"], ["skull", &"head"], ["neck", &"neck"], ["tail", &"tail"],
	["hips", &"hips"], ["pelvis", &"hips"], ["spine", &"torso"], ["chest", &"torso"], ["torso", &"torso"],
	["shoulder", &"torso"], ["back", &"torso"], ["body", &"torso"], ["arm", &"arm"], ["hand", &"arm"],
	["wing", &"arm"], ["leg", &"leg"], ["thigh", &"leg"], ["shin", &"leg"], ["foot", &"leg"], ["toe", &"leg"],
	["metatarsal", &"leg"], ["finger", &"arm"]]

var skeleton: Skeleton3D
var body: Node3D
## One row per capsule: bone (int), part (bone name), region, a / b (segment ends in the bone's rest
## frame, skeleton units), r (skeleton units), shape (CollisionShape3D).
var caps: Array[Dictionary] = []
var _synced := -1

static var _fit_cache: Dictionary = {}  ## model key -> fitted rows (shared by every animal of a model)

## The body's hurtboxes, built on first use. Null when it has no skeleton (box stand-ins, structures):
## callers keep the old reach rule for those.
static func of(n: Node) -> Hurtboxes:
	if n == null or not is_instance_valid(n) or not (n is Node3D) or not n.is_inside_tree():
		return null
	var hb := n.get_node_or_null(NodePath(NAME)) as Hurtboxes
	if hb != null:
		return hb
	var sk := skeleton_of(n)
	if sk == null:
		return null
	hb = Hurtboxes.new()
	hb.name = NAME
	hb.body = n as Node3D
	hb.skeleton = sk
	n.add_child(hb)
	hb._build(_model_key(n, sk))
	return hb

static func skeleton_of(n: Node) -> Skeleton3D:
	if n is Creature:
		var v := (n as Creature).view
		return v.rig.skeleton if v and v.using_glb and v.rig else null
	var rig: Variant = n.get(&"rig")
	return (rig as RiggedModel).skeleton if rig is RiggedModel and (rig as RiggedModel).using_glb else null

static func _model_key(n: Node, sk: Skeleton3D) -> String:
	var tag := str((n as Creature).def.id) if n is Creature and (n as Creature).def else "survivor"
	var verts := 0
	for mi in _skinned(sk):
		verts += int((mi.mesh.get_aabb().size * 100.0).length())
	return "%s|%d|%d" % [tag, sk.get_bone_count(), verts]

func _ready() -> void:
	top_level = true  # capsules are placed in world space; the body's scale and turns never touch them
	# A disabled body (a paused brain, a frozen test rig) still has a body to hit: a disabled
	# CollisionObject3D would leave the physics space.
	process_mode = Node.PROCESS_MODE_ALWAYS
	global_transform = Transform3D.IDENTITY
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group(&"hurtboxes")

func _build(key: String) -> void:
	if not _fit_cache.has(key):
		_fit_cache[key] = _fit(skeleton, _tuning(body))
	for row in _fit_cache[key] as Array:
		var r: Dictionary = (row as Dictionary).duplicate()
		var cs := CollisionShape3D.new()
		cs.shape = CapsuleShape3D.new()
		cs.set_meta(&"part", r["part"])
		add_child(cs)
		r["shape"] = cs
		caps.append(r)
	sync(true)

## Move every capsule onto the live pose (once per physics frame unless forced).
func sync(force: bool = false) -> void:
	var f := Engine.get_physics_frames()
	if (f == _synced and not force) or skeleton == null or not is_instance_valid(skeleton):
		return
	_synced = f
	var sk_xf := skeleton.global_transform
	var s := sk_xf.basis.get_scale().x
	for c in caps:
		var t := sk_xf * skeleton.get_bone_global_pose(int(c["bone"]))
		var a: Vector3 = t * (c["a"] as Vector3)
		var b: Vector3 = t * (c["b"] as Vector3)
		var r := float(c["r"]) * s
		var cs := c["shape"] as CollisionShape3D
		var cap := cs.shape as CapsuleShape3D
		var h := a.distance_to(b) + 2.0 * r
		if absf(cap.radius - r) > 0.001 or absf(cap.height - h) > 0.001:
			cap.radius = r
			cap.height = h
		cs.transform = Transform3D(_basis_along(b - a), (a + b) * 0.5)
		c["wa"] = a
		c["wb"] = b
		c["wr"] = r

## World capsules of the live pose: [a, b, r, part] per hurtbox (debug draw, tests).
func world_capsules() -> Array:
	sync()
	var out := []
	for c in caps:
		out.append([c["wa"], c["wb"], c["wr"], c["part"]])
	return out

## The point on its hurtbox surfaces nearest `at`, among capsules reaching into the height band [y_lo, y_hi]
## (world), or `at` itself when none does (the survivor's approach: the leg she can hit, not the belly overhead).
func nearest_point(at: Vector3, y_lo: float, y_hi: float) -> Vector3:
	var best := at
	var best_d := INF
	for c in world_capsules():
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var r := float(c[2])
		if minf(a.y, b.y) - r > y_hi or maxf(a.y, b.y) + r < y_lo:
			continue
		var q := Geometry3D.get_closest_point_to_segment(at, a, b)
		var d := q.distance_to(at) - r
		if d < best_d:
			best_d = d
			best = q + (at - q).normalized() * r if q.distance_to(at) > 0.0001 else q
	return best

static func region_of(bone_name: String) -> StringName:
	var low := bone_name.to_lower()
	for pair in REGIONS:
		if low.contains(str(pair[0])):
			return pair[1]
	return &"body"

static func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized() if dir.length_squared() > 1e-8 else Vector3.UP
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

static func _tuning(n: Node) -> Dictionary:
	var hb: Dictionary = Hitbox.data().get("hurtbox", {})
	var row: Dictionary = {}
	if n is Creature and (n as Creature).def:
		row = ((Hitbox.data().get("species", {}) as Dictionary).get(str((n as Creature).def.id), {}) as Dictionary).get("hurtbox", {})
	elif not n is Creature:
		row = (Hitbox.data().get("survivor", {}) as Dictionary).get("hurtbox", {})
	var out := hb.duplicate()
	out.merge(row, true)
	return out

static func _skinned(sk: Skeleton3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in sk.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh and mi.skin and not mi.has_meta(&"creature_eyeshine"):
			out.append(mi)
	return out

## Rest-pose skinned vertices in skeleton space, each with its strongest bone (stride-sampled).
static func rest_samples(sk: Skeleton3D, max_samples: int = 6000) -> Array:
	var pts := PackedVector3Array()
	var bones := PackedInt32Array()
	var total := 0
	for mi in _skinned(sk):
		for s in mi.mesh.get_surface_count():
			total += mi.mesh.surface_get_array_len(s)
	var stride := maxi(1, total / max_samples)
	for mi in _skinned(sk):
		var skin := mi.skin
		var bind_bone := PackedInt32Array()
		for bi in skin.get_bind_count():
			var bb := skin.get_bind_bone(bi)
			bind_bone.append(bb if bb >= 0 else sk.find_bone(skin.get_bind_name(bi)))
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bi_arr: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var w_arr: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			if v.is_empty() or bi_arr.is_empty():
				continue
			var per := bi_arr.size() / v.size()
			var i := 0
			while i < v.size():
				var best := 0
				for k in range(1, per):
					if w_arr[i * per + k] > w_arr[i * per + best]:
						best = k
				var bind := bi_arr[i * per + best]
				var bone := bind_bone[bind] if bind < bind_bone.size() else -1
				if bone >= 0:
					pts.append(sk.get_bone_global_rest(bone) * (skin.get_bind_pose(bind) * v[i]))
					bones.append(bone)
				i += stride
	return [pts, bones]

## Fit the capsules for one model (see the class note). Rows hold rest-frame segments.
static func _fit(sk: Skeleton3D, tune: Dictionary) -> Array:
	var sample: Array = rest_samples(sk)
	var pts: PackedVector3Array = sample[0]
	var owner: PackedInt32Array = sample[1]
	var n := sk.get_bone_count()
	var count := PackedInt32Array()
	count.resize(n)
	for b in owner:
		count[b] += 1
	var min_n := maxi(8, int(float(pts.size()) * float(tune.get("min_share", 0.015))))
	# Children first (glTF bones follow their parents), so a thin chain rolls up into its first big bone.
	var keep_of := PackedInt32Array()
	keep_of.resize(n)
	for b in n:
		keep_of[b] = b
	for b in range(n - 1, -1, -1):
		var p := sk.get_bone_parent(b)
		if count[b] < min_n and p >= 0:
			count[p] += count[b]
			count[b] = 0
			keep_of[b] = p
	var groups: Dictionary = {}
	for i in pts.size():
		var b := owner[i]
		while keep_of[b] != b:
			b = keep_of[b]
		if not groups.has(b):
			groups[b] = []  # an Array, not a Packed one: packed arrays copy on read, so an append would be lost
		(groups[b] as Array).append(pts[i])
	var rows := []
	var lo_hi: Array = tune.get("end_pct", [0.02, 0.98])
	var pct := float(tune.get("radius_pct", 0.9))
	var bone_rows: Dictionary = tune.get("bones", {})
	for b in groups:
		var g := PackedVector3Array(groups[b] as Array)
		if g.size() < 4:
			continue
		var name := sk.get_bone_name(b)
		var mean := Vector3.ZERO
		for p in g:
			mean += p
		mean /= float(g.size())
		var axis := _principal_axis(g, mean)
		var ts := PackedFloat32Array()
		for p in g:
			ts.append((p - mean).dot(axis))
		ts.sort()
		var t0 := ts[int(float(ts.size() - 1) * float(lo_hi[0]))]
		var t1 := ts[int(float(ts.size() - 1) * float(lo_hi[1]))]
		var ds := PackedFloat32Array()
		for p in g:
			var t := clampf((p - mean).dot(axis), t0, t1)
			ds.append(p.distance_to(mean + axis * t))
		ds.sort()
		var r := ds[int(float(ds.size() - 1) * pct)]
		r *= float(tune.get("radius_scale", 1.0)) * float((bone_rows.get(name, {}) as Dictionary).get("radius_scale", 1.0))
		# The rounded caps already cover r past each end: pull the segment in so the ends do not overshoot.
		var half := maxf(0.0, (t1 - t0) * 0.5 - r)
		var mid := mean + axis * ((t0 + t1) * 0.5)
		var inv := sk.get_bone_global_rest(b).affine_inverse()
		rows.append({"bone": b, "part": StringName(name), "region": region_of(name),
			"a": inv * (mid - axis * half), "b": inv * (mid + axis * half), "r": r})
	return rows

## Dominant direction of a point cloud (power iteration on its covariance).
static func _principal_axis(g: PackedVector3Array, mean: Vector3) -> Vector3:
	var c := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # xx xy xz yy yz zz
	for p in g:
		var d := p - mean
		c[0] += d.x * d.x; c[1] += d.x * d.y; c[2] += d.x * d.z
		c[3] += d.y * d.y; c[4] += d.y * d.z; c[5] += d.z * d.z
	var v := Vector3(1.0, 0.7, 0.4).normalized()
	for _i in 16:
		var nv := Vector3(c[0] * v.x + c[1] * v.y + c[2] * v.z, c[1] * v.x + c[3] * v.y + c[4] * v.z, c[2] * v.x + c[4] * v.y + c[5] * v.z)
		if nv.length_squared() < 1e-12:
			return Vector3.UP
		v = nv.normalized()
	return v
