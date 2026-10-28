class_name IslandSpawns
extends RefCounted
## Island creature spawners: fixed rows from the island def plus ring-band spawns from rules.json.

static func spawn_all(rt: IslandRuntime, def: Dictionary) -> void:
	var cap := Game.max_creatures_per_island
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for row in def.get("creatures", []):
		if not row is Dictionary:
			continue
		if rt.creature_count >= cap:
			break
		var placed := Spawner.new()
		placed.species = StringName(str(row.get("species", "velociraptor")))
		placed.count = mini(int(row.get("count", 1)), cap - rt.creature_count)
		placed.as_pack = bool(row.get("pack", true))
		var at: Array = row.get("at", [10, 0, 0])
		var fp := rt.fixed_spawn_at(Vector3(float(at[0]), 0.0, float(at[2])))
		var want := rt._at(fp.x, fp.z)
		var fixed := _nearest_valid(rt, want)
		if fixed.is_empty():
			rt.spawn_rejected += 1
			print("[world] no dry land for %s at %s; skipped" % [placed.species, want])
			placed.queue_free()
			continue
		placed.position = fixed["pos"]
		rt.add_child(placed)
		var made0 := placed.spawn_now()
		_apply_creature_level_override(rt, made0)
		rt.creature_count += made0.size()
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var spawns: Variant = def.get("spawns", {})
	if spawns is Dictionary:
		for ring_id in spawns:
			var rows: Variant = spawns[ring_id]
			if not rows is Array:
				continue
			var span: Array = rings.get(str(ring_id), {}).get("radius_m", [40, 80])
			for row in rows:
				if not row is Dictionary:
					continue
				var groups := int(row.get("groups", 1))
				var chance := float(row.get("chance", 1.0))
				for _g in groups:
					if rt.creature_count >= cap:
						return
					if chance < 1.0 and rng.randf() > chance:
						continue
					var r0 := float(span[0]) if span.size() > 0 else 40.0
					var r1 := float(span[1]) if span.size() > 1 else r0 + 20.0
					# Rings are measured from the landing point (IslandRuntime.ring_centre), and the
					# band is clamped to the FARTHEST DRY TILE from that point, so the outer ring
					# reaches the island's far shore (a land_radius circle left the far half of every
					# shaped island without spawns and pushed crater/far_shore rows 138-146 m out).
					var land: float = rt.farthest_dry_radius()
					r1 = minf(r1, land)
					r0 = minf(r0, r1 - 8.0)
					if r1 <= r0 + 4.0:
						r1 = r0 + 8.0
					var pos := _ring_point(rt, rng, r0, r1)
					if pos.is_empty():
						rt.spawn_rejected += 1
						print("[world] no valid spawn for %s in ring %s (r %.0f-%.0f); skipped" % [
							row.get("species", "?"), ring_id, r0, r1])
						continue
					var sp := Spawner.new()
					sp.species = StringName(str(row.get("species", "velociraptor")))
					sp.count = mini(int(row.get("count", 1)), cap - rt.creature_count)
					sp.as_pack = sp.count > 1
					sp.position = pos["pos"]
					rt.add_child(sp)
					var made := sp.spawn_now()
					_apply_creature_level_override(rt, made)
					rt.creature_count += made.size()

static func _apply_creature_level_override(rt: IslandRuntime, creatures: Array[Creature]) -> void:
	if rt._level_override <= 0:
		return
	for creature in creatures:
		creature.level = rt._level_override

## Up to 40 draws in the band [r0, r1]; returns {"pos": Vector3} or {} when the band has no dry land.
static func _ring_point(rt: IslandRuntime, rng: RandomNumberGenerator, r0: float, r1: float) -> Dictionary:
	var c := rt.ring_centre()
	for _try in 40:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(r0 + 2.0, maxf(r0 + 2.0, r1 - 2.0))
		var pos := Vector3(c.x + cos(ang) * rad, 0.0, c.y + sin(ang) * rad)
		pos.y = rt.surface_y(pos.x, pos.z) + 0.3
		if rt.spawn_ok(pos):
			return {"pos": pos}
	return {}

## Walk a fixed spawn point toward the island centre until it sits on dry land.
static func _nearest_valid(rt: IslandRuntime, want: Vector3) -> Dictionary:
	var p := want
	for _step in 12:
		p.y = rt.surface_y(p.x, p.z) + 0.3
		if rt.spawn_ok(p, false):
			return {"pos": p}
		p.x *= 0.9
		p.z *= 0.9
	return {}
