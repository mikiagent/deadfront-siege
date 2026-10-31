class_name PinHold
extends RefCounted
## PINFEEL (owner 2026-10-30: "It would be cool if the trex or whatever physically pinned the target with a foot").
## A predator whose rig has pin_foot (CreatureAnim.start_pin) holds its Pinned victim under one foot: the victim
## lies facing the predator (knocked onto its back, head away from it) and is slid each physics frame until its chest
## is under the claws, its legs under the foot and its head and arms out in front of the toes where the camera sees
## them (under the middle of the toes a 12 m T. rex's foot hid the survivor completely). The foot is never moved;
## the victim is "snapped under the foot".

const TOE_BONE := "Toe.R"
## Along Toe.R from the ball of the foot, in skeleton units: the claws (the T. rex Toe.R is 0.944 long).
const TOE_REACH := 0.85
const CHEST_BONES: Array[String] = ["Spine2", "Chest", "Spine1", "Spine"]
const SNAP_TAU := 0.08  # s: the victim follows the foot down during the plant, then sits still under it

## World point the victim's chest is held under: the claws of the pinning foot.
static func foot_point(pinner: Creature) -> Vector3:
	var sk := _skeleton(pinner)
	var b := sk.find_bone(TOE_BONE) if sk else -1
	if b < 0:
		return pinner.global_position - pinner.global_basis.z * pinner.body_radius() * 1.4
	var t := sk.get_bone_global_pose(b)
	return sk.global_transform * (t.origin + t.basis.y.normalized() * TOE_REACH)

## World chest point of a survivor or creature (its first chest/spine bone), else its origin.
static func chest_point(victim: Node3D) -> Vector3:
	var sk := _skeleton(victim)
	if sk:
		for n in CHEST_BONES:
			var b := sk.find_bone(n)
			if b >= 0:
				return sk.global_transform * sk.get_bone_global_pose(b).origin
	return victim.global_position

## The pin holds while both live and the victim still has Pinned.
static func holds(pinner: Creature, victim: Node3D) -> bool:
	if pinner == null or pinner.health.dead or not is_instance_valid(victim) or victim.is_queued_for_deletion():
		return false
	if victim is Player:
		return not (victim as Player).dead and (victim as Player).statuses.has(&"pinned")
	if victim is Creature:
		return not (victim as Creature).health.dead and (victim as Creature).statuses.has(&"pinned")
	return false

## Turns the victim to face the predator: knocked onto its back, a survivor's head points opposite her facing,
## so it ends up out in front of the claws, away from the predator.
static func lay_down(pinner: Creature, victim: Node3D) -> void:
	var f := pinner.global_basis.z  # the predator faces -Z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return
	if victim is Player:
		(victim as Player).face_world(victim.global_position + f)
	elif victim is Creature:
		victim.rotation.y = atan2(-f.x, -f.z)

## Slides the victim (ground plane only) toward the foot; exponential, so it lands under the claws within ~0.3 s.
static func snap(pinner: Creature, victim: Node3D, delta: float) -> void:
	var d := foot_point(pinner) - chest_point(victim)
	d.y = 0.0
	victim.global_position += d * (1.0 - exp(-delta / SNAP_TAU))

static func _skeleton(n: Node3D) -> Skeleton3D:
	if n is Player:
		var rig: RiggedModel = (n as Player).rig
		return rig.skeleton if rig else null
	if n is Creature:
		var v: CreatureView = (n as Creature).view
		return v.rig.skeleton if v and v.rig else null
	return null
