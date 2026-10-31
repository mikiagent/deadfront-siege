class_name StoneProjectile
extends Node3D
## Visible shot on a gravity arc aimed to land on the aim point. Segment tests prevent tunneling; no homing or area
## damage. PARTCOMBAT: a shot is judged against the animals' hurtbox capsules (Hurtboxes, the same bodies melee hits),
## not their collision capsules, so a T. rex head that sticks out past its collider can be shot; the capsule it meets
## names the body section hit (BodySections), and its flight through a crit spot is a sure crit. Bodies without
## hurtboxes (box stand-ins) keep the collider hit. Terrain and structures still stop it. An arrow draws as a shaft.
var source: Player
var weapon: ItemStack
var velocity := Vector3.FORWARD * SPEED
var damage := 0.0
var skill_level := 0
var range_left := 12.0
## Torpor this shot adds on a hit; < 0 = a plain stone (the blunt dose).
var torpor := -1.0
## The ammo it is (its look and radius); the body section it was aimed at (for the log and tests).
var ammo := &"stone_shot"
var aimed_section: StringName = &""
var radius := 0.08
## Where and what it hit (tests): {victim, section, part, spot, at}; empty while flying or after a miss.
var result: Dictionary = {}
signal landed(result: Dictionary)
const SPEED := 18.0

## Launch velocity at `speed` that drops onto `offset` (lifted by the fall over the flight time).
static func launch_velocity(offset: Vector3, speed: float = SPEED) -> Vector3:
	var flight := offset.length() / speed
	var g := CombatTuning.num("ranged", "gravity", 9.8)
	return offset / maxf(0.001, flight) + Vector3.UP * 0.5 * g * flight

func _ready() -> void:
	var visual := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ammo == &"arrow":
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.012
		shaft.bottom_radius = 0.012
		shaft.height = 0.75
		visual.mesh = shaft
		visual.rotation = Vector3(-PI * 0.5, 0, 0)  # the shaft along -Z, the way it flies (look_at below)
		mat.albedo_color = Color(0.55, 0.42, 0.28)
		var fletch := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.09, 0.002)
		fletch.mesh = box
		fletch.position = Vector3(0, -0.32, 0)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.85, 0.25, 0.2)
		fletch.material_override = fm
		visual.add_child(fletch)
	else:
		var mesh := SphereMesh.new()
		mesh.radius = 0.08
		mesh.height = 0.16
		visual.mesh = mesh
		mat.albedo_color = Color(0.9, 0.85, 0.55)
	visual.material_override = mat
	add_child(visual)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	velocity.y -= CombatTuning.num("ranged", "gravity", 9.8) * delta
	var step := velocity * delta
	var distance := minf(range_left, step.length())
	var from := global_position
	var end := from + step.normalized() * distance
	if step.length_squared() > 1e-8:
		look_at(from + step, Vector3.UP if absf(step.normalized().y) < 0.99 else Vector3.FORWARD)
	# The world first (terrain, walls); animal colliders do not stop it: their hurtboxes judge the hit below.
	var exclude: Array[RID] = [source.get_rid()]
	var wall := {}
	var body_hit := {}
	for _i in 6:
		var query := PhysicsRayQueryParameters3D.create(from, end)
		query.exclude = exclude
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var col := hit.get("collider") as Object
		if col is Creature:
			if Hurtboxes.of(col as Node) == null and body_hit.is_empty():
				body_hit = hit  # a box stand-in: its collider is its body
			exclude.append((col as CollisionObject3D).get_rid())
			continue
		wall = hit
		break
	if not wall.is_empty():
		end = wall["position"]
	var best := _hurtbox_hit(from, end)
	if best.is_empty() and not body_hit.is_empty() and (wall.is_empty() or from.distance_to(body_hit["position"]) < from.distance_to(end)):
		var victim := body_hit["collider"] as Creature
		if victim and not victim.health.dead and not victim.is_pet:
			var through: Vector3 = body_hit["position"] + step.normalized() * victim.body_radius() * 2.0
			best = {"victim": victim, "part": &"", "section": &"", "at": body_hit["position"], "spot": CritSpots.on_path(victim, from, through, radius)}
	if not best.is_empty():
		global_position = best["at"]
		impact(best["victim"], best["spot"], best)
		queue_free()
		return
	if not wall.is_empty():
		queue_free()
		return
	global_position = end
	range_left -= distance
	if range_left <= 0: queue_free()

## The first hurtbox capsule of a living wild animal this flight segment meets: {victim, part, section, at, spot}.
func _hurtbox_hit(from: Vector3, to: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	var seg := AABB(from, Vector3.ZERO).expand(to).grow(radius)
	var dir := (to - from).normalized()
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.health.dead or c.is_pet:
			continue
		var hb := Hurtboxes.of(c)
		if hb == null:
			continue
		hb.sync()
		for cap in hb.caps:
			var r := float(cap["wr"]) + radius
			if not seg.grow(r).intersects(AABB(cap["wa"], Vector3.ZERO).expand(cap["wb"])):
				continue
			var pts := Geometry3D.get_closest_points_between_segments(from, to, cap["wa"], cap["wb"])
			var off := pts[0].distance_to(pts[1])
			if off > r:
				continue
			# Back along the flight to where it first touches the capsule's skin.
			var at: Vector3 = pts[0] - dir * sqrt(maxf(0.0, r * r - off * off))
			var d := from.distance_to(at)
			if d < best_d:
				best_d = d
				var surface := at + dir * radius
				best = {"victim": c, "part": cap["part"], "at": at, "section": BodySections.of_hit(c, cap["part"], surface),
					# A crit spot sits inside the body: the line of flight on through the capsule it struck is what passes it.
					"spot": CritSpots.on_path(c, from, at + dir * (2.0 * float(cap["wr"]) + 0.3), radius)}
	return best

## spot: the crit spot its flight passed through (CritSpots.on_path), or {}. hit: the hurtbox hit (section, part, at).
func impact(victim: Creature, spot: Dictionary = {}, hit: Dictionary = {}) -> void:
	var section: StringName = hit.get("section", &"")
	result = {"victim": victim, "section": section, "part": hit.get("part", &""), "spot": spot, "at": hit.get("at", global_position)}
	landed.emit(result)
	var dodge := victim.dodge_chance() + victim.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	if not CombatTuning.roll(CombatTuning.hit_chance(source.statuses.accuracy_mult(), dodge)):
		CombatAvoid.avoided(victim, source)
		return
	var dtype: StringName = weapon.def().damage_type if weapon and weapon.def() and weapon.def().damage_type != &"" else &"blunt"
	var tune := CombatTuning.section("ranged")
	var raw := maxf(damage * float(tune.get("min_damage_frac", 0.05)), damage - victim.defense_for(true) * victim.statuses.defense_mult() * float(tune.get("defense_factor", 0.5)))
	var dealt := raw * (1.0 + float(tune.get("damage_per_ranged_level", 0.01)) * skill_level) * CombatCounters.multiplier(victim.def.archetype, dtype)
	victim.next_hit_kind = Hunt.effectiveness(victim, dtype)
	# BODY SECTIONS: unbroken armour cuts the shot; a Wound there makes it a sure crit like a spot.
	var armour := BodyWounds.damage_mult(victim, section)
	dealt *= armour
	if armour < 1.0:
		victim.next_hit_kind = &"armoured"
	if spot.is_empty() and section != &"":
		spot = BodyWounds.wound_spot(victim, section, result["at"])
	var spot_mult := 0.0
	if not spot.is_empty() and str(spot.get("name", "")).begins_with("wound_"):
		spot_mult = float(spot["mult"])
		victim.next_hit_kind = &"wound"
	else:
		spot_mult = CritSpots.land(victim, spot, source)  # a sure crit at the spot's multiplier
	if spot_mult > 0.0:
		dealt *= spot_mult
	victim.health.take_damage(dealt, source)
	if dtype == &"blunt" or torpor >= 0.0:
		victim.add_torpor(torpor if torpor >= 0.0 else CombatTuning.num("torpor", "blunt", 6.0), source)
	if source.skills: source.skills.add_xp("ranged", int(tune.get("xp_per_hit", 2)))
	source.hunt.wear_weapon(weapon)
	source.hunt.apply_counter_hit(weapon, victim)
	if dtype == &"blunt" and victim.brain is TyrantBrain: (victim.brain as TyrantBrain).blunt_counter()
	print("[ranged] hit %s %s=%.1f section=%s aimed=%s%s" % [victim.def.id, dtype, dealt, section, aimed_section, " weak spot" if spot_mult > 0.0 else ""])
