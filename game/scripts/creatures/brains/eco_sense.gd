class_name EcoSense
extends RefCounted
## What one wild animal can sense (brain.sense): one cached sight ray per target plus a hearing
## radius, and the searches its needs use (prey, corpses, water). Structures and terrain block
## sight; bodies, corpses, trees and resource nodes do not (the MeleeQuery rule).

const SIGHT_CACHE_S := 0.5
const RAY_PASSES := 4
## Water search step: the river is 10 m wide, so a 2 m ring step cannot jump it.
const WATER_STEP_M := 2.0

var _b: CreatureBrain
var _sight: Dictionary = {} ## target instance id -> Vector2(checked_at_s, 1 seen / 0 hidden)

func _init(brain: CreatureBrain) -> void:
	_b = brain

## Heard (inside hearing_m of the body) or seen (one clear ray). The caller checks range.
func detects(who: Node3D, dist: float) -> bool:
	if dist <= float(_b.profile.get("hearing_m", 4.0)) + _b.creature.body_radius():
		return true
	return sees(who)

func sees(who: Node3D) -> bool:
	var key := who.get_instance_id()
	var now := _b._now_s()
	var row: Variant = _sight.get(key)
	if row is Vector2 and now - (row as Vector2).x < SIGHT_CACHE_S:
		return (row as Vector2).y > 0.5
	if _sight.size() > 16:
		_sight.clear()  # targets come and go; never let the cache grow with them
	var seen := clear_ray(_b.creature, who)
	_sight[key] = Vector2(now, 1.0 if seen else 0.0)
	return seen

## Eyes to chest: true when no structure or terrain body is in the way.
static func clear_ray(from: Creature, who: Node3D) -> bool:
	if not from.is_inside_tree() or not who.is_inside_tree():
		return false
	var eye := from.global_position + Vector3.UP * maxf(0.4, from.def.height_meters * 0.8)
	var aim := who.global_position
	aim.y = MeleeQuery.feet_y(who) + MeleeQuery.body_height(who) * 0.6
	return first_blocker(from, eye, aim, [from, who]) == null

## The structure or terrain body on the segment, skipping bodies that never block.
static func first_blocker(ctx: Node3D, a: Vector3, b: Vector3, skip: Array) -> Node:
	var space := ctx.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var exclude: Array[RID] = []
	for n in skip:
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
	for i in RAY_PASSES:
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return null
		var col := hit.get("collider") as Node
		if col == null or col is CharacterBody3D or col is Corpse or col is HarvestNode:
			exclude.append(hit.get("rid") as RID)
			continue
		if col is StaticBody3D or col is CSGShape3D or col is GridMap:
			return col
		exclude.append(hit.get("rid") as RID)
	return null

## Nearest wild grazer this predator would eat: not its own species or pack, no longer than
## prey_size_ratio x its own length, and sensed.
func find_prey() -> Creature:
	var c := _b.creature
	var max_len := c.def.real_length_m * float(_b.profile.get("prey_size_ratio", 1.0))
	var best: Creature = null
	var best_d := _b._effective_perception()
	for n in c.get_tree().get_nodes_in_group("creatures"):
		var o := n as Creature
		if o == null or o == c or o.is_pet or o.def == null or o.health == null or o.health.dead:
			continue
		if o.def.id == c.def.id or (c.pack_id > 0 and o.pack_id == c.pack_id):
			continue
		if not is_prey_for(c.def, o.def, max_len):
			continue
		var d := c.global_position.distance_to(o.global_position)
		if d < best_d and detects(o, d):
			best = o
			best_d = d
	return best

## ASSUMPTION: predators hunt grazers only (no carnivore eats another carnivore).
static func is_prey_for(hunter: CreatureDef, prey: CreatureDef, max_len: float) -> bool:
	return prey.id != hunter.id and prey.is_herbivore_diet() and prey.real_length_m <= max_len

## Nearest corpse with meat left, by smell (no sight needed).
func find_corpse(radius: float) -> Node3D:
	var c := _b.creature
	var best: Node3D = null
	var best_d := radius
	for n in c.get_tree().get_nodes_in_group("corpse"):
		var corpse := n as Corpse
		if corpse == null or not has_meat(corpse):
			continue
		var d := c.global_position.distance_to(corpse.global_position)
		if d < best_d:
			best = corpse
			best_d = d
	return best

static func has_meat(corpse: Corpse) -> bool:
	return is_instance_valid(corpse) and not corpse.loot.find_by_category(&"meat").is_empty()

## A dry, walkable spot at the water's edge within radius, or Vector3.INF. Lab water sources (group
## "water_source", meta "radius") come first; on an island the runtime's water tiles (not is_dry).
func find_water(radius: float) -> Vector3:
	var c := _b.creature
	var here := c.global_position
	var best := Vector3.INF
	var best_d := radius
	for n in c.get_tree().get_nodes_in_group("water_source"):
		var w := n as Node3D
		var r := float(w.get_meta("radius", 1.0))
		var d := maxf(0.0, _flat(here, w.global_position) - r)
		if d < best_d:
			var away := here - w.global_position
			away.y = 0.0
			best = w.global_position + (away.normalized() if away.length_squared() > 0.01 else Vector3.BACK) * (r + c.body_radius() + 0.3)
			best_d = d
	if best != Vector3.INF:
		return best
	var rt := World.runtime if World else null
	if rt == null or not rt.has_method("is_dry"):
		return Vector3.INF
	# Rings outward: the first ring that touches water wins, then walk back to dry walkable land.
	var ring := WATER_STEP_M
	while ring <= radius:
		var steps := maxi(8, int(TAU * ring / WATER_STEP_M))
		var found := Vector3.INF
		var found_d := INF
		for i in steps:
			var a := TAU * float(i) / float(steps)
			var p := here + Vector3(cos(a), 0.0, sin(a)) * ring
			if not rt.is_dry(p) and Vector2(p.x, p.z).length() < rt.land_radius() + 4.0:
				var d := _flat(here, p)
				if d < found_d:
					found = p
					found_d = d
		if found != Vector3.INF:
			return _shore(rt, here, found)
		ring += WATER_STEP_M
	return Vector3.INF

## Step from the wet point back toward the animal until a tile it can stand on.
static func _shore(rt: Node, here: Vector3, wet: Vector3) -> Vector3:
	var back := here - wet
	back.y = 0.0
	var dist := back.length()
	if dist < 0.01:
		return Vector3.INF
	back /= dist
	var t := 0.5
	while t <= dist:
		var p := wet + back * t
		if rt.spawn_ok(p, false):
			var tile := BuildGrid.tile_centre(BuildGrid.tile_of(p), rt)
			return tile if rt.spawn_ok(tile, false) else Vector3(p.x, rt.surface_y(p.x, p.z), p.z)
		t += 0.5
	return Vector3.INF

## Flat distance from p to the nearest water (runtime water tiles or lab sources), searched out to
## max_m; INF when none. Labs use it to prove an animal drinks at the water's edge.
static func water_gap(ctx: Node3D, p: Vector3, max_m: float = 6.0) -> float:
	var best := INF
	for n in ctx.get_tree().get_nodes_in_group("water_source"):
		var w := n as Node3D
		best = minf(best, maxf(0.0, _flat(p, w.global_position) - float(w.get_meta("radius", 1.0))))
	var rt := World.runtime if World else null
	if rt == null or not rt.has_method("is_dry"):
		return best
	var r := 0.5
	while r <= max_m and r < best:
		for i in 16:
			var a := TAU * float(i) / 16.0
			if not rt.is_dry(p + Vector3(cos(a), 0.0, sin(a)) * r):
				return minf(best, r)
		r += 0.5
	return best

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
