class_name MeleeQuery
extends RefCounted
## One reach rule for every melee contact (player swing, tackle, kick, creature bite, tyrant
## impact): a knee-height sphere swept between the two bodies. Structures and terrain block it;
## creatures, players, corpses and resource nodes do not. Also checks that the two bodies
## overlap in height, so a cliff top cannot be bitten from below.

const KNEE_M := 0.5        # fences are 1.2 m, gates 1.6 m: a knee ray always meets them
const MAX_PASSES := 6      # bodies standing in the line are skipped, one recast each
const REACH_UP_M := 0.6    # an attacker reaches this far above its own head
const CAST_RADIUS_M := 0.22  # swept sphere: wider than any slot a body could bite through
const GROUND_CLEAR_M := 0.12  # sphere bottom stays this far above the lower body's feet

## True when nothing solid stands between a and b and their heights overlap.
static func clear(a: Node3D, b: Node3D) -> bool:
	if a == null or b == null or not a.is_inside_tree() or not b.is_inside_tree():
		return false
	var a_feet := feet_y(a)
	var b_feet := feet_y(b)
	if b_feet > a_feet + body_height(a) + REACH_UP_M or a_feet > b_feet + body_height(b) + REACH_UP_M:
		return false
	return blocker(a, b) == null

## The structure or terrain body between a and b, or null when the line is clear.
## A knee-height sphere is swept from body to body: a zero-width ray slipped diagonally through
## the 0.4 m slot where a fence row and column meet; a 0.44 m sphere cannot.
static func blocker(a: Node3D, b: Node3D) -> Node:
	var space := a.get_world_3d().direct_space_state
	var knee_a := minf(KNEE_M, body_height(a) * 0.5)
	var knee_b := minf(KNEE_M, body_height(b) * 0.5)
	var from := Vector3(a.global_position.x, feet_y(a) + knee_a, a.global_position.z)
	var to := Vector3(b.global_position.x, feet_y(b) + knee_b, b.global_position.z)
	var sphere := SphereShape3D.new()
	# Stay clear of the ground each body stands on, or flat floor would count as a wall.
	sphere.radius = clampf(minf(knee_a, knee_b) - GROUND_CLEAR_M, 0.02, CAST_RADIUS_M)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	var exclude: Array[RID] = []
	for n in [a, b]:
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	for i in MAX_PASSES:
		q.exclude = exclude
		q.transform = Transform3D(Basis.IDENTITY, from)
		q.motion = to - from
		var frac := space.cast_motion(q)
		if frac.is_empty() or frac[1] >= 1.0:
			return null
		# Read what the sphere touches at first contact (a start inside a fence counts too).
		q.transform = Transform3D(Basis.IDENTITY, from + (to - from) * frac[1])
		q.motion = Vector3.ZERO
		var info := space.get_rest_info(q)
		if info.is_empty():
			return null
		var col := instance_from_id(int(info.get("collider_id", 0))) as Node
		if _is_blocker(col):
			return col
		exclude.append(info.get("rid") as RID)
	return null

static func _is_blocker(n: Node) -> bool:
	if n == null or n is CharacterBody3D or n is Corpse or n is HarvestNode:
		return false
	return n is StaticBody3D or n is CSGShape3D or n is GridMap

## Horizontal gap between the two bodies' collision surfaces (0 when touching or overlapping).
static func surface_gap(a: Node3D, b: Node3D) -> float:
	var d := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
	return maxf(0.0, d - body_radius(a) - body_radius(b))

## Distance from a world point to the body (its capsule as an upright cylinder), 0 inside.
## AoE and traps use this instead of the feet origin, so big bodies are hit at their edge.
static func point_gap(n: Node3D, at: Vector3) -> float:
	var flat := maxf(0.0, Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length() - body_radius(n))
	var feet := feet_y(n)
	var dy := at.y - clampf(at.y, feet, feet + body_height(n))
	return Vector2(flat, dy).length()

static func body_radius(n: Node3D) -> float:
	var cap := _capsule(n)
	return cap.radius if cap else 0.0

static func body_height(n: Node3D) -> float:
	var cap := _capsule(n)
	return cap.height if cap else 1.0

## World y of the body's lowest point: creatures sit on their origin, the survivor's origin is
## its capsule centre.
static func feet_y(n: Node3D) -> float:
	var cap := _capsule(n)
	if cap == null:
		return n.global_position.y
	return (n.get_node("Shape") as Node3D).global_position.y - cap.height * 0.5

static func _capsule(n: Node3D) -> CapsuleShape3D:
	var shape := n.get_node_or_null("Shape") as CollisionShape3D
	return shape.shape as CapsuleShape3D if shape else null
