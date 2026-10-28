class_name FireWeather
extends RefCounted
## WEATHER x FIREPITS (owner 2026-10-28: "have rain affect fire somehow"; "fires under a roof will build up
## smoke though"; "the smoke should make you take damage"). Bonfire.tick asks this for:
##   - how much faster fuel burns and wood wears in the rain's mode (drizzle < rain < pour);
##   - a soak meter that puts a temporary fire out in pouring rain or a storm (the stone firepit soaks at a
##     fraction, so only a long pour puts it out); drizzle and rain never put a fire out;
##   - shelter: a roof (or ceiling) over the fire's module keeps all of that off;
##   - smoke under that roof, pooling toward the enclosure (walls on the module's four edges), slowly while
##     it burns and fast out once the fire is out or the space is open; a survivor under the roof near the
##     fire in thick smoke gets Smoke Inhalation, its stacks (damage per tick) rising with the density;
##   - whether a fire can be lit here now (not in pouring rain, unsheltered).
## Numbers: data/world/rules.json "fire_weather" (ASSUMPTION throughout; the docs give no fire-weather rules).

## 0 dry, 1 drizzle, 2 rain, 3 pour (storms pour).
static func rain_level() -> int:
	var w := weather()
	return w.rain_level() if w else 0

static func weather() -> WorldWeather:
	var rt: Node = World.runtime if is_instance_valid(World.runtime) else null
	return rt.get("weather") as WorldWeather if rt else null

static func cfg() -> Dictionary:
	return Data.world_rules.get("fire_weather", {}) as Dictionary

static func _mode_val(table: String, level: int) -> float:
	if level <= 0:
		return 1.0
	var t: Dictionary = cfg().get(table, {}) as Dictionary
	return float(t.get(str(WorldWeather.RAIN_MODES[level - 1]), 1.0))

## The roof (roof, roof peak or ceiling) over `at`'s module, or null. A piece counts when it stands
## over the module square holding `at` and above it.
static func roof_over(tree: SceneTree, at: Vector3) -> Node3D:
	if tree == null:
		return null
	var half := StructurePiece.module_m() * 0.5
	for n in tree.get_nodes_in_group("structure_piece"):
		var sp := n as StructurePiece
		if sp == null or not sp.is_roof() or sp.is_queued_for_deletion():
			continue
		var p := sp.global_position
		if absf(p.x - at.x) <= half and absf(p.z - at.z) <= half and p.y > at.y + 0.5:
			return sp
	return null

## 0..1: how closed in `at`'s module is (walls 1, windows 0.8, doorways 0.5 on its four edges, at its
## storey). shortcut: one module only; a fire in a multi-module hall reads that module's own edges.
static func enclosure(tree: SceneTree, at: Vector3) -> float:
	var m := StructurePiece.module_m()
	var c := Vector2((floorf(at.x / m) + 0.5) * m, (floorf(at.z / m) + 0.5) * m)
	var edges := [c + Vector2(m * 0.5, 0), c - Vector2(m * 0.5, 0), c + Vector2(0, m * 0.5), c - Vector2(0, m * 0.5)]
	var score := 0.0
	for e in edges:
		var best := 0.0
		for n in tree.get_nodes_in_group("structure_piece"):
			var sp := n as StructurePiece
			if sp == null or not sp.is_wall_type():
				continue
			var p := sp.global_position
			if Vector2(p.x, p.z).distance_to(e) < 0.35 and p.y > at.y - 1.5 and p.y < at.y + 1.0:
				best = maxf(best, {&"wall": 1.0, &"window": 0.8, &"doorway": 0.5}.get(sp.kind, 0.5))
		score += best
	return score / 4.0

## Fuel burns this many times faster (1 when sheltered or dry). The firepit feels permanent_share of it.
static func fuel_mult(fire: Bonfire) -> float:
	return _share(fire, _mode_val("fuel_mult", rain_level()))

## Wood wears this many times faster.
static func wear_mult(fire: Bonfire) -> float:
	return _share(fire, _mode_val("wear_mult", rain_level()))

static func _share(fire: Bonfire, m: float) -> float:
	if fire.sheltered:
		return 1.0
	return 1.0 + (m - 1.0) * (float(cfg().get("permanent_share", 0.5)) if fire.is_permanent() else 1.0)

## Soak gained per second now: only pouring rain and storms soak a fire.
static func soak_rate(fire: Bonfire) -> float:
	var w := weather()
	if fire.sheltered or w == null or rain_level() < 3:
		return 0.0
	var t: Dictionary = cfg().get("soak_per_s", {}) as Dictionary
	var r := float(t.get("storm" if w.storm else "pour", 0.011))
	return r * (float(cfg().get("permanent_soak_share", 0.3)) if fire.is_permanent() else 1.0)

## One step for `fire`: shelter (re-checked every second), soak, smoke and the survivor's lungs.
## Returns true when the rain has put the fire out this step.
static func step(fire: Bonfire, delta: float) -> bool:
	fire.shelter_check -= delta
	if fire.shelter_check <= 0.0 and fire.is_inside_tree():
		fire.shelter_check = 1.0
		var roof := roof_over(fire.get_tree(), fire.global_position)
		fire.sheltered = roof != null
		fire.roof_y = roof.global_position.y if roof else 0.0
		fire.enclosed = enclosure(fire.get_tree(), fire.global_position) if roof else 0.0
	var rate := soak_rate(fire)
	var out := false
	if rate > 0.0 and fire.burning():
		fire.rain_soak = minf(1.0, fire.rain_soak + rate * delta)
		out = fire.rain_soak >= 1.0
	else:
		fire.rain_soak = maxf(0.0, fire.rain_soak - float(cfg().get("dry_per_s", 0.02)) * delta)
	_smoke(fire, delta)
	return out

## Smoke pools toward 0.15 + 0.85 x enclosure while a sheltered fire burns (rise_s to get there), and
## clears in vent_s once it is out or the roof is gone. An open-sided shelter stays under the hurt line.
static func _smoke(fire: Bonfire, delta: float) -> void:
	var s: Dictionary = cfg().get("smoke", {}) as Dictionary
	var want := 0.0
	if fire.burning() and fire.sheltered:
		want = float(s.get("open_floor", 0.15)) + (1.0 - float(s.get("open_floor", 0.15))) * fire.enclosed
	var secs := float(s.get("rise_s", 90.0)) if want > fire.smoke else float(s.get("vent_s", 12.0))
	fire.smoke = move_toward(fire.smoke, want, delta / maxf(0.1, secs))
	var p := PlayerRegistry.local()
	if p == null or p.statuses == null or fire.smoke < float(s.get("hurt_from", 0.3)) or not fire.is_inside_tree():
		return
	if p.global_position.distance_to(fire.global_position) > float(s.get("radius_m", 3.0)):
		return
	if roof_over(fire.get_tree(), p.global_position + Vector3(0, 0.1, 0)) == null:
		return
	smoke_survivor(p, fire.smoke)

## Smoke Inhalation at `density`: stacks 1-3 by smoke.stack_at, refreshed (it lasts a few seconds,
## so it stops soon after she leaves or the space vents).
static func smoke_survivor(p: Player, density: float) -> void:
	var at: Array = (cfg().get("smoke", {}) as Dictionary).get("stack_at", [0.3, 0.6, 0.85]) as Array
	var n := 0
	for v in at:
		n += 1 if density >= float(v) else 0
	if n == 0:
		return
	var inst := p.statuses.get_instance(&"smoke_inhalation")
	if inst == null:
		p.statuses.apply(&"smoke_inhalation", null, n)
		return
	inst.stacks = n
	inst.time_left = Data.status(&"smoke_inhalation").duration

## True when a fire cannot be lit at `at` now: pouring rain (or a storm) with no roof over it.
static func light_blocked(tree: SceneTree, at: Vector3) -> bool:
	var lvl := rain_level()
	return lvl > 0 and str(WorldWeather.RAIN_MODES[lvl - 1]) in (cfg().get("light_block", ["pour"]) as Array) and roof_over(tree, at) == null

const TOO_WET := "Too wet to light a fire: find shelter or wait for the rain to ease"
