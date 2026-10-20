class_name Ragdoll
extends Node
## Death presentation for one creature. Client-side only: the corpse's authoritative state is its
## position and loot (Corpse.place_settled is the one seam that sets it). Plays the first
## hit_react_s of the "death" clip, then simulates a ragdoll built from ragdoll.json on the real
## terrain and props, pushed from the killing blow; when it is quiet (or at the cap) the pose is
## copied onto the skeleton, every physical bone is freed and the body is conformed to the ground.
## Over the budget, without a profile, or when the simulation goes unstable (NaN, a body over the
## speed guard, a stretched joint) it falls back to the death clip plus a terrain-conformed pose.

signal settled(mode: StringName)

const PROFILE_PATH := "res://data/creatures/ragdoll.json"

static var _data: Dictionary = {}
static var _simulating: Array[Ragdoll] = []
## Tests and the lab force the next starts into a fault: &"nan" poisons one body reading, &"abort"
## aborts on the first simulated frame (like a stretch guard tripping at hand-off).
static var inject_fault: StringName = &""

var creature: Creature
var corpse: Corpse
## &"hit_react" -> &"simulate" -> &"frozen", or &"fallback" -> &"frozen".
var phase: StringName = &"hit_react"
## How the body came to rest: &"ragdoll" or &"fallback".
var mode: StringName = &""
var reason: String = ""
var rig: RagdollRig
var peak_speed: float = 0.0
var since_death: float = 0.0
var sim_time: float = 0.0
var settle_time: float = -1.0
var capped: bool = false
var conform_us: int = 0
## Vertical shift the ground conform applied to the posed body (+ = lifted out of the ground).
var conform_m: float = 0.0
## The first body still moving on the last simulated frame (why a capped settle was capped).
var restless: String = ""
## The joints the ragdoll simulated (RagdollRig.info rows), kept after the freeze for the lab gates.
var joints: Array[Dictionary] = []
## Largest gap at the freeze between a body and the bone the frozen pose puts there (metres): the
## frozen pose keeps rest lengths, so a sagging joint chain moves the skin away from its bodies.
var drift_m: float = 0.0
var _dir: Vector3 = Vector3.ZERO
var _damage: float = -1.0
var _quiet: float = 0.0
var _fallback_left: float = 0.0
var _fault: StringName = &""
var _exclude: Array[RID] = []
var _root_body: int = -1
var _creature_in_root: Basis = Basis.IDENTITY  ## the creature's axes in the root body's frame at hand-off
var _side: Vector3 = Vector3.RIGHT  ## the flank it is rolled onto
## Where the carcass should end: lying on _side, its up axis in the ground plane. On a steep slope
## (_align) also with its length along the fall line, the only way a body on its flank stays put
## there (across the slope it rolls onto its back or props itself up on its legs).
var _target: Basis = Basis.IDENTITY
var _align := false
var _resting := false  ## reached its target: every body got the rest damping
var _ground_n: Vector3 = Vector3.UP  ## terrain normal where it died: "on a flank" is judged against it
var _stretch_bone: String = ""
## Fallback on a slope: the view leans from _tilt_from to the terrain normal while the clip plays.
var _tilt_from: Transform3D
var _tilt: Quaternion = Quaternion.IDENTITY
var _fallback_total: float = 0.0

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH)) if FileAccess.file_exists(PROFILE_PATH) else null
		_data = parsed if parsed is Dictionary else {"species": {}}
	return _data

static func profile(species: StringName) -> Dictionary:
	var all: Dictionary = data().get("species", {})
	var p: Variant = all.get(str(species), {})
	return p if p is Dictionary else {}

static func active_count() -> int:
	_simulating = _simulating.filter(func(r: Ragdoll) -> bool: return is_instance_valid(r) and r.phase == &"simulate")
	return _simulating.size()

## Entry point from Creature._on_died. `damage` is the killing blow when the caller knows it.
static func on_death(c: Creature, source: Node, p_corpse: Corpse = null, damage: float = -1.0) -> Ragdoll:
	if c == null or not c.is_inside_tree():
		return null
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r.creature = c
	r.corpse = p_corpse
	r._damage = damage
	r._fault = inject_fault
	r._dir = _blow_dir(c, source)
	if r._damage < 0.0:
		r._damage = _estimate_damage(c, source)
	c.add_child(r)
	return r

static func _blow_dir(c: Creature, source: Node) -> Vector3:
	var d := Vector3.ZERO
	if source is Node3D and is_instance_valid(source):
		d = c.global_position - (source as Node3D).global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = c.global_transform.basis.z  # nothing to push from: topple backwards
		d.y = 0.0
	return d.normalized()

## ASSUMPTION: Health does not record the killing blow, so the push scales with the attacker's
## own attack stat when it has one, else the data default (integrator hook: pass the real damage).
static func _estimate_damage(_c: Creature, source: Node) -> float:
	var imp: Dictionary = data().get("impulse", {})
	if source is Creature and is_instance_valid(source):
		return (source as Creature).attack_for()
	return float(imp.get("default_damage", 25.0))

func _ready() -> void:
	process_physics_priority = 10  # after the creature's own physics tick
	_exclude = _nearby_bodies()

func _exit_tree() -> void:
	_simulating.erase(self)

func _physics_process(delta: float) -> void:
	since_death += delta
	match phase:
		&"hit_react":
			var prof := profile(creature.def.id if creature.def else &"")
			if since_death >= float(prof.get("hit_react_s", _timing().get("hit_react_s", 0.3))):
				_hand_off()
		&"simulate":
			_step(delta)
		&"fallback":
			_fallback_left -= delta
			var f := clampf(1.0 - _fallback_left / maxf(0.01, _fallback_total), 0.0, 1.0)
			creature.view.transform = Transform3D(Basis(Quaternion.IDENTITY.slerp(_tilt, f)), Vector3.ZERO) * _tilt_from
			if _fallback_left <= 0.0:
				_finish()

func _process(_delta: float) -> void:
	# A dead pet lies until its respawn is ready, then the body goes (the new one is summoned).
	if phase == &"frozen" and creature and creature.is_pet and creature.pet_record and not creature.pet_record.respawning():
		creature.visible = false
		set_process(false)

func _timing() -> Dictionary:
	return data().get("timing", {})

func _skeleton() -> Skeleton3D:
	if creature == null or creature.view == null or not creature.view.using_glb or creature.view.rig == null:
		return null
	return creature.view.rig.skeleton

func _hand_off() -> void:
	var sk := _skeleton()
	var prof := profile(creature.def.id if creature.def else &"")
	var max_active := int(data().get("budget", {}).get("max_active", 4))
	var why := ""
	if sk == null:
		why = "no skeleton"
	elif prof.is_empty():
		why = "no profile"
	elif active_count() >= max_active:
		why = "budget %d" % max_active
	if why != "":
		_fall_back(why)
		return
	if creature.anim and creature.anim.tree:
		creature.anim.tree.active = false  # the ragdoll owns the pose from the hit-react frame on
	rig = RagdollRig.build(sk, prof, data().get("physics", {}))
	if rig == null:
		_resume_clip()
		_fall_back("profile does not fit the rig")
		return
	_depenetrate()
	_ground_n = RagdollSkin.ground_normal(creature.get_world_3d().direct_space_state, creature.global_position, _exclude)
	rig.start(_exclude)
	for k in rig.info.size():
		if int(rig.info[k]["parent_body"]) < 0:
			_root_body = k
	if _root_body >= 0:
		_creature_in_root = rig.bodies[_root_body].global_basis.orthonormalized().inverse() * creature.global_basis.orthonormalized()
	_push()
	_plan_pose()
	phase = &"simulate"
	mode = &"ragdoll"
	_simulating.append(self)

## Lifts the posed body until no capsule starts inside the ground. On a slope the clip's flat-ground
## feet sit in the uphill terrain (and wide foot capsules dip into flat ground); the solver tearing
## them out in the first frames tripped the stretch guard.
func _depenetrate() -> void:
	var space := creature.get_world_3d().direct_space_state
	var sk := rig.skeleton
	var xf := sk.global_transform
	var above := Vector3(0.0, creature.def.height_meters if creature.def else 2.0, 0.0)  # rays start above deep points
	var lift := 0.0
	for row in rig.info:
		var b := int(row["bone"])
		var to_world := xf * sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()
		for pt: Vector3 in [row["head_skel"], row["tip_skel"]]:
			var w := to_world * pt
			lift = maxf(lift, RagdollSkin.ground_y(space, w + above, _exclude, -INF) + float(row["radius_m"]) - w.y)
	if lift > 0.0:
		creature.view.global_position.y += lift + float(data().get("guards", {}).get("lift_margin_m", 0.01))

## Starts the fall: every body gets the velocity of the whole creature tipping over its feet onto
## the flank away from the blow (rigid rotation at topple_k * sqrt(g / hips height), so tall and
## short creatures fall alike), plus the blow's own shove (scaled by damage, capped).
func _push() -> void:
	var imp: Dictionary = data().get("impulse", {})
	var dv := clampf(_damage * float(imp.get("mps_per_damage", 0.05)), float(imp.get("min_mps", 0.5)), float(imp.get("max_mps", 3.0)))
	var right := creature.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var along := _dir.dot(right)
	_side = right * (signf(along) if absf(along) > 0.2 else 1.0)  # onto the flank away from the blow
	var pivot := creature.global_position
	var hips_h := 1.0
	if _root_body >= 0:
		hips_h = maxf(0.2, rig.bodies[_root_body].global_position.y - pivot.y)
	var omega := Vector3.UP.cross(_side).normalized() * float(imp.get("topple_k", 0.6)) * sqrt(9.8 / hips_h)
	var shove := _dir * dv + Vector3.UP * dv * float(imp.get("up_frac", 0.1))
	for pb in rig.bodies:
		pb.linear_velocity = omega.cross(pb.global_position - pivot) + shove
		pb.angular_velocity = omega

func _step(delta: float) -> void:
	sim_time += delta
	if _fault == &"abort":
		_abort("injected abort at %.2f s" % sim_time)
		return
	var guard: Dictionary = data().get("guards", {})
	var max_v := float(guard.get("max_body_mps", 30.0))
	var t := _timing()
	var quiet_v := float(t.get("quiet_mps", 0.12))
	var quiet_w := float(t.get("quiet_rps", 0.6))
	var all_quiet := true
	var all_asleep := true
	for k in rig.bodies.size():
		var pb := rig.bodies[k]
		var p := pb.global_position
		var v := pb.linear_velocity.length()
		if _fault == &"nan" and k == rig.bodies.size() - 1 and sim_time > 0.1:
			p = Vector3(NAN, NAN, NAN)
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z) and is_finite(v)):
			_abort("NaN in %s" % pb.bone_name)
			return
		peak_speed = maxf(peak_speed, v)
		if v > max_v:
			_abort("body %s at %.1f m/s" % [pb.bone_name, v])
			return
		if v > quiet_v or pb.angular_velocity.length() > quiet_w:
			if all_quiet:
				restless = "%s %.2f m/s %.2f rad/s" % [pb.bone_name, v, pb.angular_velocity.length()]
			all_quiet = false
		if not PhysicsServer3D.body_get_state(pb.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING):
			all_asleep = false
	if Engine.get_physics_frames() % 15 == 0:
		_refresh_exclude()  # a creature, player or corpse that arrived since the death
	var stretch := _worst_stretch()
	if stretch > float(guard.get("max_stretch_frac", 0.35)):
		_abort("joint %s stretched %.0f %% at %.2f s" % [_stretch_bone, stretch * 100.0, sim_time])
		return
	_pose_guard(delta)
	_quiet = _quiet + delta if all_quiet else 0.0
	if all_asleep or _quiet >= float(t.get("quiet_s", 0.35)):
		_freeze()
	elif sim_time >= float(t.get("settle_cap_s", 3.0)):
		capped = true
		_freeze()

## The resting orientation (see _target). Flat or gentle ground: up axis toward _side, heading kept.
## Steeper than align_slope_deg: also turned to the nearer end of the fall line.
func _plan_pose() -> void:
	var g: Dictionary = data().get("guards", {})
	var n := _ground_n
	var fwd := -creature.global_basis.z.normalized()
	var up := (_side - n * _side.dot(n)).normalized()
	_align = n.angle_to(Vector3.UP) > deg_to_rad(float(g.get("align_slope_deg", 15.0)))
	if _align:
		var down := (Vector3.DOWN - n * Vector3.DOWN.dot(n)).normalized()
		var contour := down.cross(n).normalized()
		up = contour * signf(contour.dot(_side) if absf(contour.dot(_side)) > 1e-3 else 1.0)
		fwd = down * signf(fwd.dot(down) if absf(fwd.dot(down)) > 1e-3 else 1.0)
	else:
		fwd = (fwd - up * fwd.dot(up)).normalized()
	_target = Basis(up.cross(-fwd), up, -fwd)

## Steers the carcass to _target with a damped spring on the root body (pose_k on the angle,
## pose_c on the spin, scaled by the carcass' inertia about the turn axis), so it never ends sitting
## on folded legs or rolled onto its back, while the limbs and tail flop freely. On flat ground only
## the up axis is steered. Once there, every body gets heavy damping: dead weight stops rolling.
func _pose_guard(delta: float) -> void:
	if _root_body < 0:
		return
	var g: Dictionary = data().get("guards", {})
	var rb := rig.bodies[_root_body]
	var now := rb.global_basis.orthonormalized() * _creature_in_root
	var axis: Vector3
	var angle: float
	if _align:
		var q := (_target * now.inverse()).get_rotation_quaternion()
		axis = q.get_axis()
		angle = q.get_angle()
		if angle > PI:
			angle = TAU - angle
			axis = -axis
	else:
		axis = now.y.cross(_target.y)
		angle = now.y.angle_to(_target.y)
	if axis.length_squared() < 1e-8:
		return
	axis = axis.normalized()
	var accel := float(g.get("pose_k", 16.0)) * angle - float(g.get("pose_c", 8.0)) * rb.angular_velocity.dot(axis)
	PhysicsServer3D.body_apply_torque_impulse(rb.get_rid(), axis * accel * _inertia_about(axis, rb.global_position) * delta)
	if not _resting and sim_time > float(g.get("rest_after_s", 0.3)) and angle < float(g.get("rest_angle", 0.45)):
		_resting = true
		for pb in rig.bodies:
			pb.angular_damp = maxf(pb.angular_damp, float(g.get("rest_angular_damp", 20.0)))
			pb.linear_damp = maxf(pb.linear_damp, float(g.get("rest_linear_damp", 3.0)))

## Sum of m (r^2 / 2 + d^2) over the bodies, d = a body's distance from the axis through `at`.
func _inertia_about(axis: Vector3, at: Vector3) -> float:
	var sum := 0.0
	for k in rig.bodies.size():
		var off := rig.bodies[k].global_position - at
		var d := (off - axis * off.dot(axis)).length()
		var r := float(rig.info[k]["radius_m"])
		sum += rig.bodies[k].mass * (r * r * 0.5 + d * d)
	return maxf(sum, 0.01)

## Largest gap between a body's bone head and where its parent body says that head should be,
## as a fraction of the child's length.
func _worst_stretch() -> float:
	var worst := 0.0
	var xf := rig.skeleton.global_transform
	for k in rig.bodies.size():
		var pk := int(rig.info[k]["parent_body"])
		if pk < 0:
			continue
		var bone := int(rig.info[k]["bone"])
		var child_head := xf * rig.body_bone_pose(k).origin
		var parent_bone := int(rig.info[pk]["bone"])
		var rel := rig.skeleton.get_bone_global_rest(parent_bone).affine_inverse() * rig.skeleton.get_bone_global_rest(bone)
		var want := xf * (rig.body_bone_pose(pk) * rel.origin)
		var frac := child_head.distance_to(want) / maxf(0.02, float(rig.info[k]["length_m"]))
		if frac > worst:
			worst = frac
			_stretch_bone = rig.bodies[k].bone_name
	return worst

func _abort(why: String) -> void:
	rig.release()
	rig.undo_reparent()  # the death clip animates the IK feet relative to their original parent
	rig = null
	_simulating.erase(self)
	_resume_clip()
	_fall_back(why)

## Switching the tree back on restarts its state machine (it sat on Start and the body stayed in the
## ragdoll's standing pose), so put it back on the death clip where it would be by now.
func _resume_clip() -> void:
	var anim := creature.anim
	if anim == null or anim.tree == null:
		return
	anim.tree.active = true
	var pb := anim.tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if pb and anim.has_state(&"death"):
		pb.start(&"death")
		anim.tree.advance(since_death)

func _fall_back(why: String) -> void:
	reason = why
	mode = &"fallback"
	phase = &"fallback"
	var clip_s := 2.0
	var ap := creature.anim.player if creature.anim else null
	if ap and ap.has_animation(&"death"):
		clip_s = ap.get_animation(&"death").length / maxf(0.05, CreatureClips.clip_speed(&"death", creature.def))
	_fallback_left = maxf(0.0, clip_s - since_death) + 0.05
	_fallback_total = _fallback_left
	# The clip lies down on flat ground: on a slope lean the body onto the terrain while it falls.
	_tilt_from = creature.view.transform
	var n := RagdollSkin.ground_normal(creature.get_world_3d().direct_space_state, creature.global_position, _exclude)
	var up := creature.global_basis.y.normalized()
	_tilt = (creature.global_basis.inverse() * Basis(Quaternion(up, n)) * creature.global_basis).get_rotation_quaternion() if up.dot(n) < 0.9999 else Quaternion.IDENTITY
	print("[ragdoll] %s fallback: %s" % [creature.def.id if creature.def else &"?", why])

func _freeze() -> void:
	joints = rig.info.duplicate()
	var globals := rig.settled_globals()
	for k in rig.bodies.size():
		var d := (globals[int(rig.info[k]["bone"])].origin - rig.body_bone_pose(k).origin).length() * rig.scale
		drift_m = maxf(drift_m, d)
	rig.release()
	_simulating.erase(self)
	rig.apply_globals(globals)
	rig = null
	_finish()

## Shared end of both paths: stop animation and the dead body's physics, put the creature root on
## the ground under the hips (the body stays where it lies), sink or lift the posed skin so its
## lowest vertex touches the ground, and hand the resting place to the corpse.
func _finish() -> void:
	settle_time = since_death
	phase = &"frozen"
	if creature.anim and creature.anim.tree:
		creature.anim.tree.active = false
	creature.velocity = Vector3.ZERO
	creature.set_physics_process(false)
	var sk := _skeleton()
	if sk:
		# Every Skeleton3D carries an internal compat PhysicalBoneSimulator3D that keeps the skeleton
		# updating each frame; a frozen corpse needs no modifier at all.
		for m in sk.find_children("*", "SkeletonModifier3D", false, false):
			(m as SkeletonModifier3D).active = false
	_refresh_exclude()  # the ground rays must not measure off a corpse or creature that came later
	var space := creature.get_world_3d().direct_space_state
	var hips_w := creature.global_position
	var prof := profile(creature.def.id if creature.def else &"")
	if sk:
		var hb := sk.find_bone(str(prof.get("hips", "Hips")))
		if hb >= 0:
			hips_w = sk.global_transform * sk.get_bone_global_pose(hb).origin
	var ground := Vector3(hips_w.x, RagdollSkin.ground_y(space, hips_w, _exclude, creature.global_position.y), hips_w.z)
	var view_xf := creature.view.global_transform
	if corpse and is_instance_valid(corpse) and corpse.server_placed:
		view_xf.origin += corpse.global_position - ground  # the server's resting place wins; the pose moves there
		ground = corpse.global_position
	creature.global_position = ground
	creature.view.global_transform = view_xf
	var conform: Dictionary = data().get("conform", {})
	var t0 := Time.get_ticks_usec()
	var gap := _visual_gap(space, sk, int(conform.get("stride", 97)))
	conform_us = Time.get_ticks_usec() - t0
	var limit := maxf(float(conform.get("max_shift_m", 0.3)), float(conform.get("max_shift_frac", 0.1)) * (creature.def.height_meters if creature.def else 1.0))
	conform_m = -clampf(gap, -limit, limit)
	creature.view.global_position.y += conform_m
	creature.reset_physics_interpolation()
	if corpse and is_instance_valid(corpse):
		corpse.place_settled(ground)
	print("[ragdoll] %s %s settled in %.2f s%s (peak %.1f m/s, conform %+.3f m in %.1f ms)" % [
		creature.def.id if creature.def else &"?", mode, settle_time, " capped" if capped else "", peak_speed, -gap, conform_us / 1000.0])
	settled.emit(mode)

## Gap from the lowest posed skin vertex to the ground under it (placeholder meshes: AABB bottom).
func _visual_gap(space: PhysicsDirectSpaceState3D, sk: Skeleton3D, stride: int) -> float:
	var mi := mesh_instance()
	if sk and mi and mi.skin:
		var c := RagdollSkin.clearance(space, RagdollSkin.posed_points(mi, sk, stride), _exclude)
		return float(c["min"]) if int(c["hits"]) > 0 else 0.0
	var bottom := INF
	for n in creature.view.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.visible and m.mesh:
			var box := m.global_transform * m.get_aabb()
			bottom = minf(bottom, box.position.y)
	if bottom == INF:
		return 0.0
	return bottom - RagdollSkin.ground_y(space, creature.global_position, _exclude, creature.global_position.y)

func mesh_instance() -> MeshInstance3D:
	if creature == null or creature.view.rig == null or creature.view.rig.mesh_root == null:
		return null
	return _first_skinned(creature.view.rig.mesh_root)

static func _first_skinned(root: Node) -> MeshInstance3D:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).skin:
			return n
	return null

## Adds bodies that arrived since the death to the ground-ray excludes and, while simulating, to
## the ragdoll's collision exceptions.
func _refresh_exclude() -> void:
	for rid in _nearby_bodies():
		if rid in _exclude:
			continue
		_exclude.append(rid)
		if rig and rig.simulator:
			rig.simulator.physical_bones_add_collision_exception(rid)

## Live characters and corpses near the body: the ragdoll passes through them and the ground rays
## ignore them (they are on layer 1 with the terrain).
func _nearby_bodies() -> Array[RID]:
	var out: Array[RID] = []
	var reach := 6.0 + (creature.def.real_length_m if creature.def else 4.0)
	for g in ["creatures", "player", "corpse"]:
		for n in creature.get_tree().get_nodes_in_group(g):
			if n is CollisionObject3D and n != creature and (n as Node3D).global_position.distance_to(creature.global_position) <= reach:
				out.append((n as CollisionObject3D).get_rid())
	if corpse and is_instance_valid(corpse):
		out.append(corpse.get_rid())
	return out
