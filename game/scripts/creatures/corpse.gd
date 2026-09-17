class_name Corpse
extends Node3D
## Placeholder for M4 butchery. Spawned when a creature dies.

var species: StringName = &""
var source_pack: int = 0

func setup(c: Creature) -> void:
	species = c.def.id
	source_pack = c.pack_id
	name = "Corpse_%s" % species
