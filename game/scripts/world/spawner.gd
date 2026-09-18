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
		var at := _member_pos(ang, radius * (0.2 if count == 1 else 1.0))
		c.position = at
		get_parent().add_child(c)
		c.global_position = at
		c.spawn(def, variant, pack_id if as_pack else _next_pack)
		if not as_pack:
			_next_pack += 1
		out.append(c)
	return out

## Pack members sit on the terrain, never below it or in the sea. On an island the
## offset shrinks toward the pack centre until the ground there is dry land.
func _member_pos(ang: float, dist: float) -> Vector3:
	var centre := global_position
	var rt := World.runtime if World else null
	if rt == null or not rt.has_method("surface_y") or not rt.has_method("spawn_ok"):
		return centre + Vector3(cos(ang), 0, sin(ang)) * dist
	var d := dist
	for _k in 4:
		var p := centre + Vector3(cos(ang), 0, sin(ang)) * d
		p.y = rt.surface_y(p.x, p.z) + 0.3
		if rt.spawn_ok(p, false):
			return p
		d *= 0.5
	return Vector3(centre.x, rt.surface_y(centre.x, centre.z) + 0.3, centre.z)
