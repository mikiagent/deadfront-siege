class_name StructureHealth
extends Node
## Durability of one structure: every modular piece, and every kit-placed kind (workbench, fence,
## catapult, ...), which gets one lazily on its first hit. Creature damage reaches it only through
## CreatureAttack, scaled by the tier's creature_mult; at 0 the structure is destroyed (pieces
## collapse whatever they held up). Saved as max/current_durability (spec 10 section 11).
##
## API for brains (W2-ECO) and UI (W2-HUD):
##   StructureHealth.of(node)                    -> StructureHealth or null (null = not a structure)
##   StructureHealth.of(node, true)              -> creates one on a placed kind that has none yet
##   StructureHealth.is_structure(node)          -> true for pieces and placed kinds
##   StructureHealth.blocker_between(a, b_pos)   -> the structure body on the knee-height line from
##                                                  node a to a world point, or null (attack it when
##                                                  TilePath.path(..., false) says the goal is unreachable)
##   health.take_damage(amount, source)          -> damage dealt after the tier multiplier
##   health.hp / health.max_hp / health.fraction()
##   signals damaged(amount, source), destroyed(source)
## A destroyed structure is queue_free()d, so a brain's is_instance_valid(attack_target) check ends the attack.

signal damaged(amount: float, source: Node)
signal destroyed(source: Node)

const NODE_NAME := "StructureHealth"

var max_hp: float = 100.0
var hp: float = 100.0
var damage_mult: float = 1.0  # the tier's creature_mult (pieces) or 1.0 (kits)
var dead: bool = false

static func of(node: Node, create: bool = false) -> StructureHealth:
	if node == null or not is_instance_valid(node):
		return null
	var h := node.get_node_or_null(NODE_NAME) as StructureHealth
	if h != null or not create or not is_structure(node):
		return h
	h = StructureHealth.new()
	h.name = NODE_NAME
	var row := StructurePiece.placed_kind(BuildPlacer.kind_of_building(node))
	h.max_hp = maxf(1.0, float(node.get("max_hp")) if node.get("max_hp") != null else float(row.get("max_durability", 300.0)))
	h.hp = clampf(float(node.get("hp")), 0.0, h.max_hp) if node.get("hp") != null else h.max_hp
	node.add_child(h)
	return h

## Camp pieces (rebuilt from the camp layout every load) and cargo are not structures: they would
## come back whole, so nothing may wear them down.
static func is_structure(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is StructurePiece:
		return true
	if not (node.is_in_group("placed_building") or node.is_in_group("craft_station")):
		return false
	return node.get("persist_building") != false and node.get("is_cargo") != true

## The structure between a creature (or any body) and a world point at knee height, or null.
static func blocker_between(a: Node3D, to: Vector3) -> Node3D:
	if a == null or not a.is_inside_tree():
		return null
	var from := a.global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(to.x, from.y, to.z))
	q.collision_mask = StructurePiece.LAYER_WALK | StructurePiece.LAYER_STRUCTURE
	if a is CollisionObject3D:
		q.exclude = [(a as CollisionObject3D).get_rid()]
	var hit := a.get_world_3d().direct_space_state.intersect_ray(q)
	var col: Variant = hit.get("collider")
	return col as Node3D if col is Node3D and is_structure(col as Node) else null

func setup(p_max: float, p_hp: float = -1.0, p_mult: float = 1.0) -> void:
	max_hp = maxf(1.0, p_max)
	hp = max_hp if p_hp < 0.0 else clampf(p_hp, 0.0, max_hp)
	damage_mult = p_mult

func fraction() -> float:
	return hp / max_hp

func missing() -> float:
	return max_hp - hp

## Returns the damage dealt. Kits mirror hp onto their own `hp` field (the catapult label reads it).
func take_damage(amount: float, source: Node = null) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var host0 := get_parent()
	if host0 and not host0 is StructurePiece and host0.get("hp") != null:
		hp = clampf(float(host0.get("hp")), 0.0, max_hp)  # the kit may have changed its own hp
	var dealt := minf(hp, amount * damage_mult * float(StructurePiece.defs().get("creature_damage_mult", 1.0)))
	hp -= dealt
	_mirror()
	damaged.emit(dealt, source)
	var host := get_parent()
	print("[struct] %s hit dmg=%.1f hp=%.0f/%.0f" % [BuildPlacer.kind_of_building(host) if not host is StructurePiece else (host as StructurePiece).kind, dealt, hp, max_hp])
	if hp <= 0.0:
		dead = true
		destroyed.emit(source)
		if host is StructurePiece:
			(host as StructurePiece).destroy("destroyed")
		elif host and not host.is_queued_for_deletion():
			print("[struct] %s destroyed" % BuildPlacer.kind_of_building(host))
			host.queue_free()
	return dealt

func heal_full() -> void:
	hp = max_hp
	dead = false
	_mirror()

func _mirror() -> void:
	var host := get_parent()
	if host and not host is StructurePiece and host.get("hp") != null:
		host.set("hp", hp)
