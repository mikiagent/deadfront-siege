class_name BrainFactory
extends RefCounted
## Which brain a creature gets, by AI archetype (ai.json species row first, then the species
## file's archetype). Tyrants (T. rex, Tarbosaurus) get the timed-attack brain, raptor packs the
## pack brain; everything else, Allosaurus included, the archetype-driven base brain.

static func create(c: Creature) -> CreatureBrain:
	if c.is_pet:
		return PetBrain.new()
	if c.def == null:
		return CreatureBrain.new()
	match c.def.mapped_archetype():
		&"tyrant":
			return TyrantBrain.new()
		&"raptor_pack":
			return RaptorPackBrain.new()
	return CreatureBrain.new()
