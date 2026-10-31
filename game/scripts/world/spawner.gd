class_name Spawner
extends Node3D
## Drops a pack of one species in a radius.

@export var species: StringName = &"velociraptor"
@export var count: int = 3
@export var radius: float = 4.0
@export var as_pack: bool = true
@export var variant: StringName = &""
## Labs: every member's nature ("" = rolled), and make member 0 an alpha regardless of the roll.
@export var nature: StringName = &""
@export var force_alpha: bool = false

var pack_id: int = 0
static var _next_pack: int = 1

func spawn_now() -> Array[Creature]:
	var def := Data.creature(species)
	if def == null:
		push_error("[creature] spawner missing species %s" % species)
		return []
	if CreatureDef.eligible(species) != species:
		print("[creature] spawner: %s has no model; not spawned (NOBOXES)" % species)
		return []
	# A lone animal is not a pack: pack 0 keeps it from flanking from the far side as an "alpha".
	pack_id = 0
	if as_pack and count > 1:
		pack_id = _next_pack
		_next_pack += 1
	var rt: Node = get_parent() if get_parent() and get_parent().has_method("ring_name") else null
	var tier_offset := _row_tier_offset(rt)
	var out: Array[Creature] = []
	# ALPHAS: one roll per spawn group (ai.json alpha.chance_per_group); the winner is member 0.
	var alpha_idx := 0 if force_alpha else CreatureGenetics.alpha_pick(count, null)
	if not force_alpha and World and bool(World.island_def.get("no_alphas", false)):
		alpha_idx = -1  # ASSUMPTION: an island def can forbid rolled alphas (the tutorial island does)
	for i in count:
		var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
		var ang := TAU * float(i) / float(maxi(1, count))
		var at := _member_pos(ang, radius * (0.2 if count == 1 else 1.0), rt)
		c.position = at
		get_parent().add_child(c)
		c.global_position = at
		c.alpha_spawn = i == alpha_idx
		c.spawn(def, variant, pack_id, rt, tier_offset, nature)
		out.append(c)
	return out

## The row's tier_offset: the "tier_offset" meta when the runtime set it from the row (integrator
## hook), else the row found by ring + species. shortcut: the fallback misreads a row whose ring
## band IslandRuntime clamped into another ring; goes away once the meta hook lands.
func _row_tier_offset(rt: Node) -> int:
	if has_meta(&"tier_offset"):
		return int(get_meta(&"tier_offset"))
	if rt == null or World == null:
		return 0
	var spawns: Variant = World.island_def.get("spawns", {})
	if not spawns is Dictionary:
		return 0
	var rows: Variant = (spawns as Dictionary).get(str(rt.ring_name(global_position)), [])
	if rows is Array:
		for row in rows:
			if row is Dictionary and StringName(str(row.get("species", ""))) == species:
				return int(row.get("tier_offset", 0))
	return 0

## Pack members sit on the terrain, never below it or in the sea. On an island the
## offset shrinks toward the pack centre until the ground there is dry land. During an island
## build World.runtime is still null, so the parent runtime is passed in.
func _member_pos(ang: float, dist: float, rt: Node) -> Vector3:
	var centre := global_position
	if rt == null:
		rt = World.runtime if World else null
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
