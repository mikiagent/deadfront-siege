class_name PinHold
extends RefCounted
## PINFEEL (owner 2026-10-30: "It would be cool if the trex or whatever physically pinned the target with a foot").
## A predator whose rig has pin_foot (CreatureAnim.start_pin) holds its Pinned victim under one foot: the victim
## lies facing the predator (knocked onto its back, head away from it) and is slid each physics frame until its chest
## is under the claws, its legs under the foot and its head and arms out in front of the toes where the camera sees
## them (under the middle of the toes a 12 m T. rex's foot hid the survivor completely). The foot is never moved.
## BIGSTOMP (owner 2026-10-31: "the trexes would pin me and it would teleport me under their feet"): the old exponential
## snap pulled a victim from anywhere the stomp's wide hit reached, metres per frame. Now a pin only starts on a victim
## already within pin_reach_frac x body height of the foot (can_start; the stomp that lands on her, or the jaws/pounce
## that put her there), and she is pressed under the claws at most pin_slide_mps (ai.json big_stomp): no jump.

const TOE_BONE := "Toe.R"
## Along Toe.R from the ball of the foot, in skeleton units: the claws (the T. rex Toe.R is 0.944 long).
const TOE_REACH := 0.85
const CHEST_BONES: Array[String] = ["Spine2", "Chest", "Spine1", "Spine"]

## World point the victim's chest is held under: the claws of the pinning foot (ai.json big_stomp.species.<id>
## pin_bone / pin_reach; the T. rex's Toe.R by default).
static func foot_point(pinner: Creature) -> Vector3:
	var row := BigStomp.species_row(pinner.def.id) if pinner.def else {}
	var sk := _skeleton(pinner)
	var b := sk.find_bone(str(row.get("pin_bone", TOE_BONE))) if sk else -1
	if b < 0:
		return pinner.global_position - pinner.global_basis.z * pinner.body_radius() * 1.4
	var t := sk.get_bone_global_pose(b)
	return sk.global_transform * (t.origin + t.basis.y.normalized() * float(row.get("pin_reach", TOE_REACH)))

## A pin starts only on a victim already close to the pinning foot (no pulling her in from across the stomp's reach).
static func can_start(pinner: Creature, victim: Node3D) -> bool:
	var reach := float(BigStomp.section().get("pin_reach_frac", 0.3)) * pinner.def.height_meters * pinner.size_scale()
	return BigStomp.flat(foot_point(pinner), chest_point(victim)) <= maxf(1.0, reach)

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

## Presses the victim (ground plane only) under the foot, at most pin_slide_mps: it follows the foot as it plants.
static func snap(pinner: Creature, victim: Node3D, delta: float) -> void:
	var d := foot_point(pinner) - chest_point(victim)
	d.y = 0.0
	victim.global_position += d.limit_length(float(BigStomp.section().get("pin_slide_mps", 3.0)) * delta)

static func _skeleton(n: Node3D) -> Skeleton3D:
	if n is Player:
		var rig: RiggedModel = (n as Player).rig
		return rig.skeleton if rig else null
	if n is Creature:
		var v: CreatureView = (n as Creature).view
		return v.rig.skeleton if v and v.rig else null
	return null
