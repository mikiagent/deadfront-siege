class_name RagdollRig
extends RefCounted
## Builds the physical skeleton of one creature from a ragdoll.json species profile: a
## PhysicalBoneSimulator3D with one capsule PhysicalBone3D per listed bone (unlisted bones follow
## their parent), and reads the simulated pose back for the freeze.
##
## Two engine details shape this file:
## - Joints are created while the skeleton sits in its REST pose, so every limit in the profile is
##   measured from rest (degrees), never from whatever frame the death clip was on.
## - PhysicalBone3D strips scale from its body but writes bone poses back through the scaled
##   skeleton (creatures are scaled to height_meters), which shrank every bone by 1/scale. Giving
##   body_offset a 1/scale basis makes the write-back exact (see _body_offset).

## "cone" is built as a 6DOF joint: GodotPhysics' cone-twist joint blew up on landing (bodies at
## hundreds of m/s) where pin, hinge and 6DOF stayed calm, and 6DOF also allows an asymmetric bend.
const JOINT_TYPES := {
	"cone": PhysicalBone3D.JOINT_TYPE_6DOF,
	"hinge": PhysicalBone3D.JOINT_TYPE_HINGE,
	"pin": PhysicalBone3D.JOINT_TYPE_PIN,
}

var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
## Per body, same order as `bodies`: bone, parent_body (index into bodies or -1), length_m,
## joint ("cone"/"hinge"/"pin"/""), axis (skeleton rest space), min/max (hinge, degrees),
## swing/twist (cone, degrees), offset_inv (body -> bone transform).
var info: Array[Dictionary] = []
var scale: float = 1.0
## Local pose of every bone when the simulation started; lengths are restored from it on freeze.
var start_local: Array[Transform3D] = []
var _body_of_bone: Dictionary = {}  ## bone index -> body index
var _moved: Array = []  ## [bone, old parent, old rest] per reparented bone

## Returns null (and leaves the skeleton untouched) when the profile names a bone this rig lacks.
static func build(sk: Skeleton3D, prof: Dictionary, defaults: Dictionary) -> RagdollRig:
	if sk == null or prof.is_empty():
		return null
	var defs: Array = prof.get("bodies", [])
	if defs.is_empty():
		return null
	for d in defs:
		if not (d is Dictionary) or sk.find_bone(str(d.get("bone", ""))) < 0:
			return null
		for key in ["from", "to"]:
			if d.has(key) and sk.find_bone(str(d[key])) < 0:
				return null
	var s3 := sk.global_transform.basis.get_scale()
	if absf(s3.x - s3.y) > 0.01 * s3.x or absf(s3.x - s3.z) > 0.01 * s3.x or s3.x <= 0.0:
		return null  # non-uniform scale: the 1/scale body offset trick only holds for uniform scale
	var r := RagdollRig.new()
	r.skeleton = sk
	r.scale = s3.x
	r._reparent(prof.get("reparent", {}))
	# Bones keep their rest offsets from their parent (an IK foot the clip planted elsewhere snaps to
	# its ankle), so every joint starts closed and the frozen pose keeps every bone's rest length.
	for i in sk.get_bone_count():
		if sk.get_bone_parent(i) >= 0:
			sk.set_bone_pose_position(i, sk.get_bone_rest(i).origin)
		r.start_local.append(sk.get_bone_pose(i))
	# Joints are made against the rest pose (limits are rest-relative), then the death pose returns.
	sk.reset_bone_poses()
	r.simulator = PhysicalBoneSimulator3D.new()
	r.simulator.name = "RagdollSimulator"
	sk.add_child(r.simulator)
	var order := defs.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return r._depth(sk.find_bone(str(a["bone"]))) < r._depth(sk.find_bone(str(b["bone"]))))
	var total_mass := float(prof.get("mass_kg", defaults.get("mass_kg", 100.0)))
	var vols: Array[float] = []
	var explicit := 0.0
	for d in order:
		var g := r._geometry(d)
		vols.append(PI * g["r"] * g["r"] * (g["len"] + 4.0 / 3.0 * g["r"]))
		explicit += float(d.get("mass_frac", 0.0))
	var vol_sum := 0.0
	for v in vols:
		vol_sum += v
	var masses: Array[float] = []
	for k in order.size():
		var frac := float((order[k] as Dictionary).get("mass_frac", 0.0))
		if frac <= 0.0:
			frac = (1.0 - minf(explicit, 0.95)) * vols[k] / maxf(vol_sum, 1e-9)
		masses.append(maxf(0.05, frac * total_mass))
	# Joint chains go unstable past a few-to-one mass ratio (a 60:1 torso-to-foot ratio exploded on
	# landing), so light bodies are raised to heaviest / max_mass_ratio.
	var floor_mass := float(masses.max()) / maxf(1.0, float(defaults.get("max_mass_ratio", 6.0)))
	for k in order.size():
		r._add_body(order[k], maxf(masses[k], floor_mass), defaults)
	for i in sk.get_bone_count():
		sk.set_bone_pose_position(i, r.start_local[i].origin)
		sk.set_bone_pose_rotation(i, r.start_local[i].basis.get_rotation_quaternion())
		sk.set_bone_pose_scale(i, r.start_local[i].basis.get_scale())
	return r

## Bones whose rig parent is not their anatomical parent (the donor rigs hang IK feet off `root`)
## move under the named bone, keeping their current global pose and rest.
func _reparent(map: Dictionary) -> void:
	for child_name in map:
		var c := skeleton.find_bone(str(child_name))
		var p := skeleton.find_bone(str(map[child_name]))
		if c < 0 or p < 0 or c == p or skeleton.get_bone_parent(c) == p:
			continue
		var gc := skeleton.get_bone_global_pose(c)
		var gp := skeleton.get_bone_global_pose(p)
		var gc_rest := skeleton.get_bone_global_rest(c)
		var gp_rest := skeleton.get_bone_global_rest(p)
		_moved.append([c, skeleton.get_bone_parent(c), skeleton.get_bone_rest(c)])
		skeleton.set_bone_parent(c, p)
		skeleton.set_bone_rest(c, gp_rest.affine_inverse() * gc_rest)
		var local := gp.affine_inverse() * gc
		skeleton.set_bone_pose_position(c, local.origin)
		skeleton.set_bone_pose_rotation(c, local.basis.get_rotation_quaternion())

## Puts reparented bones back (an aborted simulation hands the pose back to the death clip).
func undo_reparent() -> void:
	for m in _moved:
		skeleton.set_bone_parent(int(m[0]), int(m[1]))
		skeleton.set_bone_rest(int(m[0]), m[2])
	_moved.clear()

func _depth(bone: int) -> int:
	var n := 0
	var p := skeleton.get_bone_parent(bone)
	while p >= 0:
		n += 1
		p = skeleton.get_bone_parent(p)
	return n

## Capsule geometry in skeleton rest space: head/tip points (skeleton units), radius and length in
## metres. `from`/`to` name bones whose heads bound the capsule; `length` (m) is used for end bones.
func _geometry(d: Dictionary) -> Dictionary:
	var b := skeleton.find_bone(str(d["bone"]))
	var g := skeleton.get_bone_global_rest(b)
	var head: Vector3 = g.origin
	if d.has("from"):
		head = skeleton.get_bone_global_rest(skeleton.find_bone(str(d["from"]))).origin
	var tip: Vector3
	if d.has("dir"):
		var dv: Array = d["dir"]
		tip = head + Vector3(float(dv[0]), float(dv[1]), float(dv[2])).normalized() * float(d.get("length", 0.1)) / scale
	elif d.has("to"):
		tip = skeleton.get_bone_global_rest(skeleton.find_bone(str(d["to"]))).origin
	else:
		var kids := skeleton.get_bone_children(b)
		if kids.size() == 1 and not d.has("length"):
			tip = skeleton.get_bone_global_rest(kids[0]).origin
		else:
			tip = head + g.basis.y.normalized() * float(d.get("length", 0.1)) / scale
	var ls := float(d.get("length_scale", 1.0))
	tip = head + (tip - head) * ls
	var off: Array = d.get("offset", [0.0, 0.0, 0.0])
	var shift := Vector3(float(off[0]), float(off[1]), float(off[2])) / scale
	head += shift
	tip += shift
	var len_m := maxf(0.001, (tip - head).length() * scale)
	var rad := float(d["radius"]) if d.has("radius") else float(d.get("radius_frac", 0.25)) * len_m
	return {"head": head, "tip": tip, "len": len_m, "r": maxf(0.005, rad)}

func _add_body(d: Dictionary, mass: float, defaults: Dictionary) -> void:
	var b := skeleton.find_bone(str(d["bone"]))
	var g := _geometry(d)
	var rest := skeleton.get_bone_global_rest(b)
	var inv := rest.affine_inverse()
	var head_l: Vector3 = inv * (g["head"] as Vector3)
	var tip_l: Vector3 = inv * (g["tip"] as Vector3)
	var dir := (tip_l - head_l).normalized()
	if dir.length_squared() < 0.5:
		dir = Vector3.UP
	var ref := Vector3.RIGHT if absf(dir.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := (ref - dir * ref.dot(dir)).normalized()
	var basis := Basis(x, dir, x.cross(dir))  # body Y runs along the bone, like CapsuleShape3D
	var centre := (head_l + tip_l) * 0.5
	var pb := PhysicalBone3D.new()
	pb.name = "RB_%s" % str(d["bone"]).validate_node_name()
	pb.bone_name = str(d["bone"])
	pb.body_offset = _body_offset(basis, centre)
	var cap := CapsuleShape3D.new()
	cap.radius = g["r"]
	cap.height = maxf(float(g["len"]) + float(d.get("extend", 0.0)), cap.radius * 2.0 + 0.001)
	var cs := CollisionShape3D.new()
	cs.shape = cap
	pb.add_child(cs)
	pb.mass = mass
	pb.friction = float(d.get("friction", defaults.get("friction", 0.9)))
	pb.bounce = float(d.get("bounce", defaults.get("bounce", 0.0)))
	pb.linear_damp = float(d.get("linear_damp", defaults.get("linear_damp", 0.4)))
	pb.angular_damp = float(d.get("angular_damp", defaults.get("angular_damp", 2.0)))
	pb.gravity_scale = float(defaults.get("gravity_scale", 1.0))
	pb.can_sleep = true
	# Layer 0: nothing collides with a ragdoll (no self-collision, survivors walk through); mask 1:
	# it lands on terrain, rocks, trees and buildings. Live characters are added as exceptions.
	pb.collision_layer = 0
	pb.collision_mask = int(defaults.get("collision_mask", 1))
	var j: Dictionary = d.get("joint", {})
	var jtype := str(j.get("type", "cone"))
	var parent_body := _parent_body(b)
	var ax: Array = j.get("axis", [1.0, 0.0, 0.0])
	var axis_skel := Vector3(float(ax[0]), float(ax[1]), float(ax[2])).normalized()
	if parent_body >= 0 and JOINT_TYPES.has(jtype):
		pb.joint_type = JOINT_TYPES[jtype]
		# Joint frame in body space, at the bone head (= body_offset inverse origin, as the engine
		# itself would fix it). Hinge: Z is the hinge axis. Cone: X (twist) runs along the bone.
		var head_body := -(basis.transposed() * centre) * scale
		var a_body := (basis.transposed() * (rest.basis.orthonormalized().transposed() * axis_skel)).normalized()
		var jb := Basis.IDENTITY
		if jtype == "hinge":
			var xb := (Vector3.UP - a_body * Vector3.UP.dot(a_body))
			xb = xb.normalized() if xb.length_squared() > 1e-6 else Vector3.RIGHT
			jb = Basis(xb, a_body.cross(xb), a_body)
		else:
			# 6DOF frame: X = the bone line (twist), Z = the bend axis (`axis` made square to it), Y = side.
			var zb := (a_body - Vector3.UP * a_body.dot(Vector3.UP))
			zb = zb.normalized() if zb.length_squared() > 1e-6 else Vector3.RIGHT
			jb = Basis(Vector3.UP, zb.cross(Vector3.UP), zb)
		pb.joint_offset = Transform3D(jb, head_body)
		_set_limits(pb, jtype, j, defaults)
	var idx := bodies.size()
	bodies.append(pb)
	_body_of_bone[b] = idx
	info.append({
		"bone": b, "parent_body": parent_body, "length_m": g["len"], "radius_m": g["r"],
		"joint": jtype if parent_body >= 0 else "", "axis": axis_skel if parent_body >= 0 else Vector3.ZERO,
		"min": float(j.get("min", -float(j.get("swing", 45.0)))), "max": float(j.get("max", float(j.get("swing", 45.0)))),
		"swing": float(j.get("swing", 30.0)), "twist": float(j.get("twist", 15.0)),
		"side": float(j.get("side", float(j.get("swing", 30.0)))),
		"offset_inv": pb.body_offset.affine_inverse(),
		"parent_bone": int(info[parent_body]["bone"]) if parent_body >= 0 else -1,
		"dir_skel": ((g["tip"] as Vector3) - (g["head"] as Vector3)).normalized(),
		"head_skel": g["head"], "tip_skel": g["tip"],
	})
	simulator.add_child(pb)

## Godot's hinge and 6DOF angles both run opposite to a right-hand rotation of the child about the
## joint axis (calibrated: limits [-60, -10] let a rod swing to +10 right-hand), so a profile range
## [min, max] (right-hand, from rest) maps to [lower, upper] = [-max, -min].
func _set_limits(pb: PhysicalBone3D, jtype: String, j: Dictionary, defaults: Dictionary) -> void:
	var jd: Dictionary = defaults.get("joint", {})
	match jtype:
		"cone":
			var swing := float(j.get("swing", 30.0))
			var twist := float(j.get("twist", 15.0))
			var side := float(j.get("side", swing))
			var limits := {"x": [-twist, twist], "y": [-side, side], "z": [-float(j.get("max", swing)), -float(j.get("min", -swing))]}
			for ax in limits:
				pb.set("joint_constraints/%s/angular_limit_enabled" % ax, true)
				pb.set("joint_constraints/%s/angular_limit_lower" % ax, float(limits[ax][0]))
				pb.set("joint_constraints/%s/angular_limit_upper" % ax, float(limits[ax][1]))
				pb.set("joint_constraints/%s/angular_limit_softness" % ax, float(j.get("softness", jd.get("softness", 0.5))))
				pb.set("joint_constraints/%s/erp" % ax, float(j.get("erp", jd.get("erp", 0.5))))
				pb.set("joint_constraints/%s/angular_damping" % ax, float(j.get("damping", jd.get("damping", 1.0))))
		"hinge":
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_lower", -float(j.get("max", 45.0)))
			pb.set("joint_constraints/angular_limit_upper", -float(j.get("min", -45.0)))
			pb.set("joint_constraints/angular_limit_bias", float(j.get("bias", jd.get("bias", 0.3))))
			pb.set("joint_constraints/angular_limit_softness", float(j.get("softness", jd.get("hinge_softness", 0.9))))
			pb.set("joint_constraints/angular_limit_relaxation", float(j.get("relaxation", jd.get("relaxation", 1.0))))
		"pin":
			pb.set("joint_constraints/bias", float(j.get("bias", jd.get("bias", 0.3))))

## body = orthonormalized(skeleton * bone * offset) and bone = skeleton^-1 * body * offset^-1.
## With skeleton scale s, a 1/s basis here cancels both the stripped and the re-applied scale.
func _body_offset(basis: Basis, centre: Vector3) -> Transform3D:
	return Transform3D(Basis(basis.x / scale, basis.y / scale, basis.z / scale), centre)

func _parent_body(bone: int) -> int:
	var p := skeleton.get_bone_parent(bone)
	while p >= 0:
		if _body_of_bone.has(p):
			return int(_body_of_bone[p])
		p = skeleton.get_bone_parent(p)
	return -1

func start(exceptions: Array[RID]) -> void:
	for rid in exceptions:
		simulator.physical_bones_add_collision_exception(rid)
	simulator.physical_bones_start_simulation()

## Skeleton-space global pose of bone `b` as its body holds it now (bodies only).
func body_bone_pose(k: int) -> Transform3D:
	var t := skeleton.global_transform.affine_inverse() * bodies[k].global_transform * (info[k]["offset_inv"] as Transform3D)
	return Transform3D(t.basis.orthonormalized(), t.origin)

## The pose to freeze: every bone's skeleton-space global, rotations from the bodies, local
## positions from the start pose so no bone stretches (the root body alone keeps its position).
func settled_globals() -> Array[Transform3D]:
	var n := skeleton.get_bone_count()
	var out: Array[Transform3D] = []
	out.resize(n)
	var done: Array[bool] = []
	done.resize(n)
	for i in n:
		_settle_bone(i, out, done)
	return out

func _settle_bone(i: int, out: Array[Transform3D], done: Array[bool]) -> void:
	if done[i]:
		return
	var p := skeleton.get_bone_parent(i)
	var parent_g := Transform3D.IDENTITY
	if p >= 0:
		_settle_bone(p, out, done)
		parent_g = out[p]
	var local := start_local[i]
	if _body_of_bone.has(i):
		var k := int(_body_of_bone[i])
		var from_body := body_bone_pose(k)
		if int(info[k]["parent_body"]) < 0:
			out[i] = from_body
		else:
			out[i] = Transform3D(from_body.basis, parent_g * local.origin)
	else:
		out[i] = parent_g * local
	done[i] = true

## Writes globals as local poses (no modifiers left, so they persist and cost nothing per frame).
func apply_globals(globals: Array[Transform3D]) -> void:
	for i in skeleton.get_bone_count():
		var p := skeleton.get_bone_parent(i)
		var local := globals[i] if p < 0 else globals[p].affine_inverse() * globals[i]
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())

## Stops the simulation and frees every physical bone now (not at the end of the frame).
func release() -> void:
	if simulator and is_instance_valid(simulator):
		simulator.physical_bones_stop_simulation()
		if simulator.get_parent():
			simulator.get_parent().remove_child(simulator)
		simulator.queue_free()
	simulator = null
	bodies.clear()
