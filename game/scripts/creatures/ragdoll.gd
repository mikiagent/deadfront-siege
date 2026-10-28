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
## ASSUMPTION: a carcass lies with its hips at most this share of the standing hips height; a body
## rounder than its legs are long (zebraceratops) rests higher, on its barrel, so the limit is the
## larger of that and LIE_WIDTH_K x the trunk's half-width across the hips.
const LIE_FRAC := 0.5
const LIE_WIDTH_K := 1.15

static var _data: Dictionary = {}
static var _simulating: Array[Ragdoll] = []
## Tests and the lab force the next starts into a fault: &"nan" poisons one body reading, &"abort"
## aborts on the first simulated frame (like a stretch guard tripping at hand-off).
static var inject_fault: StringName = &""
## Tests and the lab: abort the next simulation once it has run this long (seconds), like a joint
## tearing halfway through the fall. <= 0 disables it.
static var inject_abort_at_s: float = -1.0

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
## Tilt (radians) the ground conform gave the posed body to rest its skin on its supports.
var conform_tilt: float = 0.0
## Limbs turned back out of the ground at the freeze (RagdollSkin.lift_limbs).
var limb_turns: int = 0
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
var _w0: float = 3.0  ## sqrt(g / hips height): how fast this creature topples (rad/s)
## Where the carcass should end: lying on _side, its up axis in the ground plane. On a steep slope
## (_align) also with its length along the fall line, the only way a body on its flank stays put
## there (across the slope it rolls onto its back or props itself up on its legs).
var _target: Basis = Basis.IDENTITY
var _align := false
var _resting := false  ## reached its target: every body got the rest damping
var _ground_n: Vector3 = Vector3.UP  ## terrain normal where it died: "on a flank" is judged against it
var _stretch_bone: String = ""
## Worst joint stretch seen during the whole simulation, as a fraction of the joint's rest length
## The lab and t_ragdoll gate it.
var peak_stretch: float = 0.0
## Fallback: the view moves from _fall_from to _fall_to (creature space) while the clip plays.
var _fall_from: Transform3D
var _fall_to: Transform3D
var _fallback_total: float = 0.0
var _guard_cache: Dictionary = {}
var _lift: float = 0.0  ## how far _depenetrate raised the view (an aborted ragdoll's clip lies from where it stood)

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
	# Freed mid-simulation (the scene went away): never leave the skeleton in the ragdoll's pose
	# with its AnimationTree switched off.
	if rig:
		rig.release()
		rig.undo_reparent()
		rig = null
		if is_instance_valid(creature) and creature.anim and creature.anim.tree:
			creature.anim.tree.active = true

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
			creature.view.transform = _fall_from.interpolate_with(_fall_to, f)
			if _fallback_left <= 0.0:
				_finish()

func _process(_delta: float) -> void:
	# A dead pet lies until its respawn is ready, then the body goes (the new one is summoned).
	if phase == &"frozen" and creature and creature.is_pet and creature.pet_record and not creature.pet_record.respawning():
		creature.visible = false
		set_process(false)

func _timing() -> Dictionary:
	return data().get("timing", {})

## ragdoll.json guards with the species profile's own "guards" over them.
func _guards() -> Dictionary:
	if _guard_cache.is_empty():
		_guard_cache = (data().get("guards", {}) as Dictionary).duplicate()
		_guard_cache.merge(profile(creature.def.id if creature.def else &"").get("guards", {}), true)
	return _guard_cache

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
	rig = RagdollRig.build(sk, prof, data().get("physics", {}), creature.size_scale())
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
			# A sphere of radius r clears a plane with normal n only r / n.y above it, not r: on a
			# 30 degree slope r alone left feet 15 % of their radius inside the hill (coelophysis'
			# BackFoot torn out at 0.03 s).
			var n := RagdollSkin.ground_normal(space, w + above, _exclude)
			lift = maxf(lift, RagdollSkin.ground_y(space, w + above, _exclude, -INF) + float(row["radius_m"]) / maxf(n.y, 0.5) - w.y)
	if lift > 0.0:
		_lift = lift + float(_guards().get("lift_margin_m", 0.01))
		creature.view.global_position.y += _lift

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
	# Onto the flank away from the blow; a blow from ahead or behind picks no flank, so the downhill
	# one (rolled onto its uphill flank a carcass ends propped up on the slope).
	var downhill := right.dot(_ground_n)
	_side = right * (signf(along) if absf(along) > 0.2 else (signf(downhill) if absf(downhill) > 0.02 else 1.0))
	var pivot := creature.global_position
	var hips_h := 1.0
	if _root_body >= 0:
		hips_h = maxf(0.2, rig.bodies[_root_body].global_position.y - pivot.y)
	_w0 = minf(sqrt(9.8 / hips_h), float(_guards().get("pose_w0_max", 3.0)))  # small ones turn no faster than a raptor
	# The whole body tips over its feet the way the blow pushes it: toward _dir, which for a flank
	# blow is a roll onto the far flank and for a blow from ahead or behind is a pitch backward or
	# forward (rolling about the long axis there threw the tail out sideways).
	# The body rolls onto the flank away from the blow. A blow from ahead or behind picks no flank
	# (it has to fall onto one anyway), so it gets a stronger straight shove instead: the carcass
	# ends clearly behind/along the blow, not under the attacker.
	var omega := Vector3.UP.cross(_side).normalized() * float(imp.get("topple_k", 0.6)) * _w0
	# ASSUMPTION: a head-on or rear blow shoves the whole body this many times harder than a flank
	# blow (the blow reaches through the trunk, not around it).
	var head_on := absf(along) <= 0.2
	var shove := _dir * dv * (float(imp.get("end_on_shove_k", 2.0)) if head_on else 1.0) + Vector3.UP * dv * float(imp.get("up_frac", 0.1))
	for pb in rig.bodies:
		pb.linear_velocity = omega.cross(pb.global_position - pivot) + shove
		pb.angular_velocity = omega

func _step(delta: float) -> void:
	sim_time += delta
	if _fault == &"abort":
		_abort("injected abort at %.2f s" % sim_time)
		return
	if inject_abort_at_s > 0.0 and sim_time >= inject_abort_at_s:
		_abort("injected abort at %.2f s" % sim_time)
		return
	var guard: Dictionary = _guards()
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
	peak_stretch = maxf(peak_stretch, stretch)
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
	var g: Dictionary = _guards()
	var n := _ground_n
	var fwd := -creature.global_basis.z.normalized()
	var up := (_side - n * _side.dot(n)).normalized()
	_align = n.angle_to(Vector3.UP) > deg_to_rad(float(g.get("align_slope_deg", 15.0)))
	if _align:
		var down := (Vector3.DOWN - n * Vector3.DOWN.dot(n)).normalized()
		var contour := down.cross(n).normalized()
		fwd = down * signf(fwd.dot(down) if absf(fwd.dot(down)) > 1e-3 else 1.0)
		# The flank it topples onto stays down: rolled onto its right (_side = its right) its right
		# axis (up x back) ends along -n. (Picking up by _side alone was a coin toss for a body that
		# topples along the fall line, and the spring then rolled it over its back to the other flank.)
		var flank := signf(_side.dot(creature.global_basis.x))
		up = contour * signf(contour.cross(-fwd).dot(-n * flank))
	# A little toward the belly: the legs' dead weight then holds it on the flank instead of rolling
	# it onto its back, and the upper legs lean toward the ground.
	var belly := deg_to_rad(float(g.get("belly_tilt_deg", 0.0)))
	up = (up * cos(belly) + n * sin(belly)).normalized()
	if not _align:
		fwd = (fwd - up * fwd.dot(up)).normalized()
	_target = Basis(up.cross(-fwd), up, -fwd)

## Steers the carcass to _target with a damped spring on the root body (pose_k * w0^2 on the angle,
## pose_c * w0 on the spin, scaled by the carcass' inertia about the turn axis), so it never ends
## sitting on folded legs or rolled onto its back, while the limbs and tail flop freely. w0 is how
## fast the creature topples, so a T. rex turns as slowly as it falls and its tail tip stays under
## the speed guard. On flat ground only the up axis is steered. Once there, every body gets heavy
## damping: dead weight stops rolling.
func _pose_guard(delta: float) -> void:
	if _root_body < 0:
		return
	var g: Dictionary = _guards()
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
	var accel := float(g.get("pose_k", 4.4)) * _w0 * _w0 * angle - float(g.get("pose_c", 4.2)) * _w0 * rb.angular_velocity.dot(axis)
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

## Abandons the presentation mid-simulation (the caller no longer wants a ragdoll): the bodies go,
## the death clip's pose comes back and the body is laid out at once instead of standing.
func cancel() -> void:
	if phase == &"frozen":
		return
	if rig:
		rig.release()
		rig.undo_reparent()
		rig = null
	_simulating.erase(self)
	_resume_clip()
	_fall_back("cancelled", true)
	set_physics_process(false)

## Switching the tree back on restarts its state machine (it sat on Start and the body stayed in the
## ragdoll's standing pose), so put it back on the death clip where it would be by now.
func _resume_clip() -> void:
	var anim := creature.anim
	if anim == null or anim.tree == null:
		return
	anim.tree.active = true
	_seek_death(since_death)

## Puts the death clip at `t` seconds of tree time. The first advance after start() only enters the
## state (its play position stays 0), so the clip is entered with a zero step, then advanced.
func _seek_death(t: float) -> bool:
	var anim := creature.anim
	var pb := anim.tree.get("parameters/playback") as AnimationNodeStateMachinePlayback if anim and anim.tree and anim.tree.active else null
	if pb == null or not anim.has_state(&"death"):
		return false
	pb.start(&"death")
	anim.tree.advance(0.0)
	anim.tree.advance(t)
	return true

func _fall_back(why: String, now: bool = false) -> void:
	reason = why
	mode = &"fallback"
	phase = &"fallback"
	var clip_s := 2.0
	var ap := creature.anim.player if creature.anim else null
	if ap and ap.has_animation(&"death"):
		clip_s = ap.get_animation(&"death").length / maxf(0.05, CreatureClips.clip_speed(&"death", creature.def))
	_fallback_left = maxf(0.0, clip_s - since_death) + 0.05
	_fallback_total = _fallback_left
	_fall_from = creature.view.transform
	_fall_to = _plan_fallback(clip_s)
	print("[ragdoll] %s fallback: %s" % [creature.def.id if creature.def else &"?", why])
	if now:
		# A cancelled ragdoll may not wait for the clip to play out: put the clip on its last frame
		# (the pose _plan_fallback read) and land the body there straight away.
		_seek_death(clip_s)
		_fallback_left = 0.0
		_fallback_total = 0.0
		creature.view.transform = _fall_to
		_finish()

## Where a fallback's body ends, so the view can move there while the clip plays. The death clip is
## read ahead to its last frame (the tree runs to its end and back to now) and leaned onto the
## terrain (the clips lie down on flat ground). A clip that ends upright, crouched or propped up on
## a leg is laid down: the least roll about the trunk's line (0, 45, then 90 degrees, the side away
## from the blow first), lowered until the trunk's (or the hips') skin rests on the ground, that brings the hips
## under conform.lie_frac and every foot under conform.foot_frac of the standing hips height without
## turning the hips' up axis past conform.legs_up_dot (onto its back). _finish
## then turns limbs out of the ground and rests the skin on it.
func _plan_fallback(clip_s: float) -> Transform3D:
	var view := creature.view
	var space := creature.get_world_3d().direct_space_state
	var root := creature.global_position
	var n := RagdollSkin.ground_normal(space, root, _exclude)
	var lean := Basis(Quaternion(Vector3.UP, n)) if n.dot(Vector3.UP) < 0.9999 else Basis.IDENTITY
	var now := view.global_transform
	var base := now.translated(Vector3.DOWN * _lift)  # the clip's own placement, not the ragdoll's lift
	var best := Transform3D(lean, root - lean * root) * base
	var sk := _skeleton()
	var prof := profile(creature.def.id if creature.def else &"")
	var spine := _spine(sk, prof) if sk else {}
	var hb := sk.find_bone(str(prof.get("hips", "Hips"))) if sk else -1
	var mi := mesh_instance()
	if sk == null or spine.size() < 2 or hb < 0 or mi == null or mi.skin == null:
		return creature.global_transform.affine_inverse() * best
	var stand := (sk.global_transform * sk.get_bone_global_rest(hb).origin - now.origin).y
	if stand <= 0.0 or not _seek_death(clip_s + 0.5):
		return creature.global_transform.affine_inverse() * best
	var conform: Dictionary = data().get("conform", {})
	var stride := int(conform.get("stride", 61))
	var length := creature.def.real_length_m if creature.def else 2.0
	var ground := RagdollSkin.Ground.new(space, _exclude, length * float(conform.get("cell_frac", 0.025)), maxf(2.0, stand * 2.0))
	var lie_m := stand * float(conform.get("lie_frac", 0.5))
	var foot_m := stand * float(conform.get("foot_frac", 0.75))
	var feet: Array[int] = []
	for fb in prof.get("feet", []):
		if sk.find_bone(str(fb)) >= 0:
			feet.append(sk.find_bone(str(fb)))
	var ends := _spine_ends(sk, prof)
	var leaned := best
	var to_leaned := leaned * now.affine_inverse()
	var a: Vector3 = to_leaned * (sk.global_transform * sk.get_bone_global_pose(ends[0]).origin)
	var b: Vector3 = to_leaned * (sk.global_transform * sk.get_bone_global_pose(ends[1]).origin)
	var axis := (b - a).normalized()
	var mid := (a + b) * 0.5
	var away := 1.0 if axis.cross(Vector3.UP).dot(_dir) >= 0.0 else -1.0  # + roll tips the back toward the blow's push
	var best_score := INF
	for deg: float in [0.0, 45.0 * away, -45.0 * away, 90.0 * away, -90.0 * away]:
		var r := Basis(axis, deg_to_rad(deg)) if axis.length_squared() > 0.5 else Basis.IDENTITY
		var turned := Transform3D(r, mid - r * mid) * leaned
		# Lowered by nothing, until the trunk's skin touches, or until the hips' own skin does (a body
		# propped up on its legs at one end); limbs that go under are turned out at the freeze.
		for drop: Dictionary in ([{}, spine, {hb: true}] if deg == 0.0 else [spine, {hb: true}]):
			var c := turned
			if not drop.is_empty():
				view.global_transform = c
				var gap := RagdollSkin.trunk_gap(ground, mi, sk, drop, stride)
				if not is_finite(gap):
					continue
				c.origin.y -= gap
			view.global_transform = c
			var score := _height(space, sk, hb) / lie_m
			for fb in feet:
				score = maxf(score, _height(space, sk, fb) / foot_m)
			var rot := sk.get_bone_global_pose(hb).basis.orthonormalized() * sk.get_bone_global_rest(hb).basis.orthonormalized().inverse()
			if (sk.global_basis.orthonormalized() * rot * Vector3.UP).normalized().dot(n) < float(conform.get("legs_up_dot", -0.35)):
				score += 10.0  # on its back, legs up
			if score < best_score - 0.01:
				best_score = score
				best = c
			if best_score <= 1.0:
				break
		if best_score <= 1.0:
			break
	view.global_transform = now
	_seek_death(since_death)
	return creature.global_transform.affine_inverse() * best

## Height of a bone above the ground under it, along the ground's normal (as the lab gates it).
func _height(space: PhysicsDirectSpaceState3D, sk: Skeleton3D, bone: int) -> float:
	var p := sk.global_transform * sk.get_bone_global_pose(bone).origin
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 2.0, 0.0), p - Vector3(0.0, 8.0, 0.0), 1, _exclude))
	return (p - (hit["position"] as Vector3)).dot(hit["normal"] as Vector3) if not hit.is_empty() else 0.0

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
	var prof := profile(creature.def.id if creature.def else &"")
	var server := corpse != null and is_instance_valid(corpse) and corpse.server_placed
	if server:
		var g0 := _hips_world(sk, prof)
		g0.y = RagdollSkin.ground_y(space, g0, _exclude, creature.global_position.y)
		creature.view.global_position += corpse.global_position - g0  # the server's resting place wins; the pose moves there
	var conform: Dictionary = data().get("conform", {})
	var t0 := Time.get_ticks_usec()
	var mi := mesh_instance()
	var height := creature.def.height_meters if creature.def else 2.0
	if sk and mi and mi.skin:
		var stride := int(conform.get("stride", 61))
		var length := creature.def.real_length_m if creature.def else 2.0
		var ground := RagdollSkin.Ground.new(space, _exclude, length * float(conform.get("cell_frac", 0.025)), maxf(2.0, height))
		# A ragdoll's simulated bones keep their joint limits; a death clip's limbs (a leg or tail it
		# leaves propping the carcass up) may all turn out of the ground, so only its trunk counts.
		var keep := _body_bones(sk, prof)
		if mode == &"fallback":
			keep = _trunk_bone(sk, prof)
			RagdollRig.reparent_bones(sk, prof.get("reparent", {}))  # IK feet turn with their legs
		limb_turns = RagdollSkin.lift_limbs(ground, mi, sk, keep, stride, float(conform.get("limb_max_deg", 50.0)))
		var res := RagdollSkin.rest(ground, mi, sk, creature.view, stride, deg_to_rad(float(conform.get("max_tilt_deg", 12.0))), int(conform.get("tilt_rounds", 2)), sk.find_bone(str(prof.get("hips", "Hips"))))
		conform_m = float(res["shift"])
		conform_tilt = float(res["tilt"])
	else:
		conform_m = -_box_gap(space)
		creature.view.global_position.y += conform_m
	conform_us = Time.get_ticks_usec() - t0
	# The creature root (and the corpse) go on the ground under the hips; the posed body stays put.
	var hips_w := _hips_world(sk, prof)
	var ground := Vector3(hips_w.x, RagdollSkin.ground_y(space, hips_w, _exclude, creature.global_position.y), hips_w.z)
	if server:
		ground = corpse.global_position
	var view_xf := creature.view.global_transform
	creature.global_position = ground
	creature.view.global_transform = view_xf
	creature.reset_physics_interpolation()
	if corpse and is_instance_valid(corpse):
		corpse.place_settled(ground)
	print("[ragdoll] %s %s settled in %.2f s%s (peak %.1f m/s, %d limbs lifted, conform %+.3f m tilt %.1f deg in %.1f ms)" % [
		creature.def.id if creature.def else &"?", mode, settle_time, " capped" if capped else "", peak_speed, limb_turns, conform_m, rad_to_deg(conform_tilt), conform_us / 1000.0])
	settled.emit(mode)

## Half the trunk's width across the hips in the pose the body is in now (0 without a skeleton).
func trunk_half_width() -> float:
	var sk := _skeleton()
	var mi := mesh_instance()
	if sk == null or mi == null or creature == null or creature.def == null:
		return 0.0
	var prof := profile(creature.def.id)
	return RagdollSkin.trunk_half_width(mi, sk, _body_bones(sk, prof), _hips_world(sk, prof), creature.def.real_length_m)

## The hips height a lying carcass of this species may keep: LIE_FRAC of its standing hips height, or
## LIE_WIDTH_K x its trunk's half-width when the body is rounder than its legs are long (a
## zebraceratops on its side rests on its barrel: 0.3 m of a 0.6 m hip height). The lab's lying gate
## and t_ragdoll both read this, so a species' profile is scored the same way in both.
func lie_limit(stand_hips: float) -> float:
	return maxf(stand_hips * LIE_FRAC, trunk_half_width() * LIE_WIDTH_K)

func _hips_world(sk: Skeleton3D, prof: Dictionary) -> Vector3:
	var hb := sk.find_bone(str(prof.get("hips", "Hips"))) if sk else -1
	return sk.global_transform * sk.get_bone_global_pose(hb).origin if hb >= 0 else creature.global_position

## Placeholder meshes (no skin): gap from the lowest mesh AABB corner to the ground under the root.
func _box_gap(space: PhysicsDirectSpaceState3D) -> float:
	var bottom := INF
	for n in creature.view.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.visible and m.mesh:
			var box := m.global_transform * m.get_aabb()
			bottom = minf(bottom, box.position.y)
	if bottom == INF:
		return 0.0
	return bottom - RagdollSkin.ground_y(space, creature.global_position, _exclude, creature.global_position.y)

## The profile's simulated bones (bone index -> true): limbs below them are what lift_limbs turns.
func _body_bones(sk: Skeleton3D, prof: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for d in prof.get("bodies", []):
		var b := sk.find_bone(str((d as Dictionary).get("bone", "")))
		if b >= 0:
			out[b] = true
	return out

## The profile's root body bone (no body above it) as a bone set: the trunk a death clip's limbs hang off.
func _trunk_bone(sk: Skeleton3D, prof: Dictionary) -> Dictionary:
	var all := _body_bones(sk, prof)
	for b: int in all:
		var p := sk.get_bone_parent(b)
		while p >= 0 and not all.has(p):
			p = sk.get_bone_parent(p)
		if p < 0:
			return {b: true}
	return all

## The root body's capsule ends: its `from` and `to` bones (default: its own bone).
func _spine_ends(sk: Skeleton3D, prof: Dictionary) -> Array[int]:
	var trunk := _trunk_bone(sk, prof)
	for d in prof.get("bodies", []):
		if trunk.has(sk.find_bone(str((d as Dictionary).get("bone", "")))):
			return [sk.find_bone(str(d.get("from", d["bone"]))), sk.find_bone(str(d.get("to", d["bone"])))]
	return [-1, -1]

## The bones from the root body's `from` bone to its `to` bone through their common ancestor: the
## trunk's skin (the donor rigs' Body bone itself carries none).
func _spine(sk: Skeleton3D, prof: Dictionary) -> Dictionary:
	var ends := _spine_ends(sk, prof)
	var out: Dictionary = {}
	if ends[0] < 0 or ends[1] < 0:
		return out
	var above_a: Dictionary = {}
	var x := ends[0]
	while x >= 0:
		above_a[x] = true
		x = sk.get_bone_parent(x)
	x = ends[1]
	while x >= 0 and not above_a.has(x):
		out[x] = true
		x = sk.get_bone_parent(x)
	var y := ends[0]
	while y >= 0 and y != x:
		out[y] = true
		y = sk.get_bone_parent(y)
	if x >= 0:
		out[x] = true
	return out

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
