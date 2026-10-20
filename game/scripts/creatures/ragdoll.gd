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
## Tests and the lab force the next starts into a fault: &"nan" poisons one body reading.
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
var _dir: Vector3 = Vector3.ZERO
var _damage: float = -1.0
var _quiet: float = 0.0
var _fallback_left: float = 0.0
var _fault: StringName = &""
var _exclude: Array[RID] = []
var _root_body: int = -1
var _up_in_root: Vector3 = Vector3.UP  ## the creature's up axis in the root body's frame at hand-off
var _side: Vector3 = Vector3.RIGHT  ## the flank it is rolled onto
var _stretch_bone: String = ""

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
	rig.start(_exclude)
	for k in rig.info.size():
		if int(rig.info[k]["parent_body"]) < 0:
			_root_body = k
	if _root_body >= 0:
		_up_in_root = rig.bodies[_root_body].global_basis.inverse() * creature.global_basis.y.normalized()
	_push()
	phase = &"simulate"
	mode = &"ragdoll"
	_simulating.append(self)

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
	var stretch := _worst_stretch()
	if stretch > float(guard.get("max_stretch_frac", 0.35)):
		_abort("joint %s stretched %.0f %% at %.2f s" % [_stretch_bone, stretch * 100.0, sim_time])
		return
	_roll_guards()
	_quiet = _quiet + delta if all_quiet else 0.0
	if all_asleep or _quiet >= float(t.get("quiet_s", 0.35)):
		_freeze()
	elif sim_time >= float(t.get("settle_cap_s", 3.0)):
		capped = true
		_freeze()

## Keeps the carcass on a flank. Early on (roll_s) a body still sitting upright on folded legs
## (up axis y above flank_up_y) is rolled toward the side the blow chose, like the collapse a death
## clip would play; at any time a body rolling past its flank onto its back (y below belly_up_y)
## is turned back, so it never ends legs-up.
func _roll_guards() -> void:
	if _root_body < 0:
		return
	var g: Dictionary = data().get("guards", {})
	var rb := rig.bodies[_root_body]
	var up := rb.global_basis * _up_in_root
	var lever := rb.mass * maxf(0.5, float(rig.info[_root_body]["length_m"]))
	var flank := float(g.get("flank_up_y", 0.3))
	var belly := float(g.get("belly_up_y", -0.2))
	var axis := Vector3.ZERO
	var amount := 0.0
	if sim_time < float(g.get("roll_s", 1.5)) and up.y > flank:
		axis = up.cross(_side)
		amount = float(g.get("roll_rate", 8.0)) * (up.y - flank)
	elif up.y < belly:
		axis = up.cross(Vector3.UP)
		amount = float(g.get("belly_up_rate", 6.0)) * (belly - up.y)
	if amount > 0.0 and axis.length_squared() > 1e-6:
		PhysicsServer3D.body_apply_torque_impulse(rb.get_rid(), axis.normalized() * amount * lever * get_physics_process_delta_time() * 60.0)

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

func _resume_clip() -> void:
	if creature.anim and creature.anim.tree:
		creature.anim.tree.active = true

func _fall_back(why: String) -> void:
	reason = why
	mode = &"fallback"
	phase = &"fallback"
	var clip_s := 2.0
	var ap := creature.anim.player if creature.anim else null
	if ap and ap.has_animation(&"death"):
		clip_s = ap.get_animation(&"death").length / maxf(0.05, CreatureClips.clip_speed(&"death", creature.def))
	_fallback_left = maxf(0.0, clip_s - since_death) + 0.05
	print("[ragdoll] %s fallback: %s" % [creature.def.id if creature.def else &"?", why])

func _freeze() -> void:
	joints = rig.info.duplicate()
	var globals := rig.settled_globals()
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
	var space := creature.get_world_3d().direct_space_state
	var hips_w := creature.global_position
	var prof := profile(creature.def.id if creature.def else &"")
	if sk:
		var hb := sk.find_bone(str(prof.get("hips", "Hips")))
		if hb >= 0:
			hips_w = sk.global_transform * sk.get_bone_global_pose(hb).origin
	var ground := Vector3(hips_w.x, RagdollSkin.ground_y(space, hips_w, _exclude, creature.global_position.y), hips_w.z)
	var view_xf := creature.view.global_transform
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
