class_name Spawner
extends Node3D
## Drops a pack of one species in a radius.

@export var species: StringName = &"velociraptor"
@export var count: int = 3
@export var radius: float = 4.0
@export var as_pack: bool = true
@export var variant: StringName = &""

var pack_id: int = 0
static var _next_pack: int = 1

func spawn_now() -> Array[Creature]:
	var def := Data.creature(species)
	if def == null:
		push_error("[creature] spawner missing species %s" % species)
		return []
	if as_pack:
		pack_id = _next_pack
		_next_pack += 1
	var out: Array[Creature] = []
	for i in count:
		var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
		var ang := TAU * float(i) / float(maxi(1, count))
		c.position = global_position + Vector3(cos(ang), 0, sin(ang)) * radius * (0.2 if count == 1 else 1.0)
		get_parent().add_child(c)
		c.global_position = global_position + Vector3(cos(ang), 0, sin(ang)) * radius * (0.2 if count == 1 else 1.0)
		c.spawn(def, variant, pack_id if as_pack else _next_pack)
		if not as_pack:
			_next_pack += 1
		out.append(c)
	return out
