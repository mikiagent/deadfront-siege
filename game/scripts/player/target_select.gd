class_name TargetSelect
extends RefCounted
## Tap-to-select (spec 23, owner 2026-10-20): a tap on a wild animal only selects it. The fight starts
## from the red swords hex beside it or its key (engage), always through PlayerActions. An animal that
## bites first is still fought at once (Player.receive_creature_hit). The selected animal wears a pale
## ring; HuntHud shows its target plate and TargetSwordsHex floats beside it.

## A selection left past hunt range drops: the swords would start nothing there (review r3).
const KEEP_RANGE := PlayerActions.ATTACK_SEEK_RANGE
const RING_COLOR := Color(1.0, 0.95, 0.8, 0.9)

var p: Player
var target: Creature
var _ring: MeshInstance3D

func _init(player: Player) -> void:
	p = player

## Select a wild animal. Null, a pet or a dead animal clears the selection.
func select(c: Creature) -> void:
	if c != null and (c.is_pet or c.health.dead):
		c = null
	if c == current():
		return
	clear()
	if c == null:
		return
	target = c
	_ring = MeshInstance3D.new()
	_ring.name = "SelectRing"
	var torus := TorusMesh.new()
	var r := maxf(0.8, c.body_radius() * 2.2)
	torus.inner_radius = r - 0.08
	torus.outer_radius = r
	_ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = RING_COLOR
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(_ring)
	_ring.position = Vector3(0, 0.08, 0)
	print("[combat] select %s" % c.def.id)

func clear() -> void:
	if _ring and is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	target = null

## The live selection, or null: it drops once the animal dies, is tamed, is freed or is left behind.
func current() -> Creature:
	if not is_instance_valid(target):
		target = null  # freed together with its ring
		_ring = null
	elif target.health.dead or target.is_pet or p.global_position.distance_to(target.global_position) > KEEP_RANGE:
		clear()
	return target

## The selection while its swords hex is on screen, else null. E, F and SIC act on it only then: a
## selection left off screen kept E from benches, beds and pets and sent the survivor on a long chase.
func shown() -> Creature:
	var hex := p.get_tree().get_first_node_in_group(&"target_swords") as TargetSwordsHex if p.is_inside_tree() else null
	return current() if hex and hex.player == p and hex.is_visible_in_tree() else null

## The swords hex or its key: fight the selection (online this becomes the act.attack intent).
func engage() -> void:
	var c := current()
	if c:
		p.actions.attack(c)
