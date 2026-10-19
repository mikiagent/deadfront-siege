class_name ServerRng
extends RefCounted
## The server's only source of chance. Each op gets a generator seeded from the store's world
## seed and the seq the op will be journaled under, so replaying a journal draws the same numbers.

static func seed_for(world_seed: int, seq: int, salt: String = "") -> int:
	return hash([world_seed, seq, salt])

static func for_op(world_seed: int, seq: int, salt: String = "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(world_seed, seq, salt)
	return rng

## Domain code that still calls the global randf() (Crafting.build_output's burn roll) runs
## after this, so it is deterministic too. Safe because the server applies one op at a time.
# shortcut: reseeds the process-wide RNG; drop it once W1-ITEMS lands the injectable burn RNG.
static func seed_global(world_seed: int, seq: int) -> void:
	seed(seed_for(world_seed, seq, "global"))
