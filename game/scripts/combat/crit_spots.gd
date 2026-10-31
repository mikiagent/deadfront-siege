class_name CritSpots
extends RefCounted
## WEAK SPOTS (owner: "since we have hitboxes now, I want you to add crit spots to every animal"). Each species
## has 1-3 spheres riding its bones (data/creatures/hitboxes.json crit_spots: a head for the theropods, the belly and
## throat under the ankylosaurus and stegosaurus armour, behind the frill on the ceratopsians, the neck or hump on
## the big mammals). A player hit whose hitbox passes through one where it first touches the body (Hitbox._sweep
## puts it on the hit as "spot"), or a stone whose flight passes through one, is a sure crit at that spot's
## multiplier: the chance crit (crit_base, crit_behind) still rolls on every other hit. The player learns the spots
## from a gold burst on the spot itself, a "WEAK SPOT" float, a short hit-stop and shake, and afterwards a faint
## glow on that animal's spots (CritSpotMarks). The fight lab's H view draws them magenta (HitboxDebug).

const KIND := &"weakspot"  ## Creature.next_hit_kind and the damage float for a weak-spot crit
const FOUND_META := &"crit_spots_found"
const BURST := Color(1.0, 0.82, 0.2)
## ASSUMPTION (CS4): the target's animation freezes this long on a weak-spot hit; the world keeps running.
const HIT_STOP_S := 0.08

static func cfg() -> Dictionary:
	return Hitbox.data().get("crit_spots", {})

## The species' spot rows: its data row, else (a new species) a head spot on its first "Head" bone, else
## (a stand-in with no rig) the fallback spots placed on its body's size.
static func rows(c: Creature) -> Array:
	var sp: Variant = (cfg().get("species", {}) as Dictionary).get(str(c.def.id))
	if sp is Array and not (sp as Array).is_empty():
		return sp
	var sk := Hurtboxes.skeleton_of(c)
	if sk:
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).to_lower().begins_with("head"):
				return [{"name": "head", "bone": sk.get_bone_name(b)}]
	return cfg().get("fallback", [])

## The live spots in world space: [{name, bone, centre, radius, mult}]. A row whose bone this model lacks is skipped.
static func world(c: Creature) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if c == null or c.def == null or not c.is_inside_tree():
		return out
	var d: Dictionary = cfg().get("default", {})
	var size := c.size_scale()
	var sk := Hurtboxes.skeleton_of(c)
	for row in rows(c):
		var r := row as Dictionary
		var spot := {"name": StringName(str(r.get("name", "spot"))), "bone": StringName(str(r.get("bone", ""))),
			"radius": float(r.get("radius", d.get("radius", 0.3))) * size, "mult": float(r.get("mult", d.get("mult", 2.0)))}
		if r.has("bone"):
			if sk == null:
				continue
			var b := sk.find_bone(str(r["bone"]))
			if b < 0:
				continue
			var off: Array = r.get("offset", [0, 0, 0])
			# The offset is measured in the body's frame at rest (z forward = the body's -Z): carry it into the
			# bone's rest frame, so the spot turns with the bone.
			var body_v := Vector3(float(off[0]), float(off[1]), -float(off[2])) * size
			var sk_in_body := c.global_transform.affine_inverse() * sk.global_transform
			var local := sk.get_bone_global_rest(b).basis.inverse() * (sk_in_body.basis.inverse() * body_v)
			spot["centre"] = sk.global_transform * (sk.get_bone_global_pose(b) * local)
		else:
			var at: Array = r.get("at", [0.0, 0.85, 0.45])
			var length := c.def.real_length_m * size
			spot["centre"] = c.global_transform * Vector3(float(at[0]) * length * 0.3, float(at[1]) * c.def.height_meters * size, -float(at[2]) * length)
		out.append(spot)
	return out

## The spot a path (a -> b, swept radius r) passes through, deepest first, or {}.
static func on_path(target: Node, a: Vector3, b: Vector3, r: float) -> Dictionary:
	if not target is Creature:
		return {}
	var best := {}
	var best_d := INF
	for s in world(target as Creature):
		var centre: Vector3 = s["centre"]
		var d := Geometry3D.get_closest_point_to_segment(centre, a, b).distance_to(centre) - r - float(s["radius"])
		if d <= 0.0 and d < best_d:
			best_d = d
			best = s
	return best

## A landed player hit (melee or ranged) in a spot: the feedback, and the damage multiplier (0 = no spot).
static func land(t: Creature, spot: Dictionary, source: Node) -> float:
	if spot.is_empty() or t == null or t.health.dead:
		return 0.0
	t.next_hit_kind = KIND
	t.hit_burst(BURST, 0.22, 28, 0.5, spot["centre"])
	IsoCamera.shake(source, CombatTuning.num("camera", "weak_spot", 0.45))
	if t.anim:
		t.anim.set_time_scale(0.0, &"hit_stop")
		var ref: WeakRef = weakref(t)  # a lambda capturing a freed animal errors
		t.get_tree().create_timer(HIT_STOP_S, true, false, true).timeout.connect(func() -> void:
			var c: Creature = ref.get_ref() as Creature
			if c and c.anim:
				c.anim.set_time_scale(1.0, &"hit_stop"))
	# ASSUMPTION (CS5): after the first weak-spot hit, that animal's spots glow faintly for the rest of its life.
	if not t.has_meta(FOUND_META):
		t.set_meta(FOUND_META, true)
		CritSpotMarks.attach(t)
	print("[combat] weak spot %s %s x%.2f" % [t.def.id, spot["name"], float(spot["mult"])])
	return float(spot["mult"])
