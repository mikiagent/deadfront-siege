class_name BodySections
extends RefCounted
## BODY SECTIONS (owner: "I want to be able to click the intended body section"). Each body's hurtbox capsules
## (Hurtboxes) are grouped into named sections: head, neck, torso, belly, foreleg/hindleg _L/_R, tail, plus frill,
## plates or hump where a species has one. All from data (hitboxes.json "sections"): bone-name patterns pick a capsule's
## section, and splits carve a second section out of one capsule by where the hit lands on it (the belly is the
## underside of the torso, the frill the back of a ceratopsian's skull, the plates the top of a stegosaurus).
## Flags: armoured (data; unbroken armour takes armour_mult of a hit until an Armor break, BodyWounds) and crit (a
## section holding a crit spot, CritSpots). Ranged aim and the melee focus both name a section from here.

static func cfg() -> Dictionary:
	return Hitbox.data().get("sections", {})

static func _species(c: Node) -> Dictionary:
	if not c is Creature or (c as Creature).def == null:
		return {}
	return (cfg().get("species", {}) as Dictionary).get(str((c as Creature).def.id), {})

## The section a capsule's bone belongs to, before any split.
static func base_of(c: Node, bone: String) -> StringName:
	var low := bone.to_lower()
	var stem := low.trim_suffix(".l").trim_suffix(".r").trim_suffix("_l").trim_suffix("_r")
	var exact: Dictionary = cfg().get("exact", {}).duplicate()
	exact.merge(_species(c).get("exact", {}), true)
	var sec := str(cfg().get("default", "torso"))
	if exact.has(stem):
		sec = str(exact[stem])
	else:
		for row in cfg().get("bones", []) as Array:
			if stem.contains(str(row[0])):
				sec = str(row[1])
				break
	if sec in (cfg().get("sided", []) as Array):
		var left := low.ends_with(".l") or low.ends_with("_l") or low.contains("left")
		var right := low.ends_with(".r") or low.ends_with("_r") or low.contains("right")
		if left or right:
			sec += "_L" if left else "_R"
	return StringName(sec)

static func splits_of(c: Node) -> Array:
	return (cfg().get("splits", []) as Array) + (_species(c).get("splits", []) as Array)

## Every section of this body, in a stable order (base sections in capsule order, then the splits that apply).
static func names(c: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	var hb := Hurtboxes.of(c)
	if hb == null:
		return out
	for cap in hb.caps:
		var s := cap_section(c, cap)
		if s not in out:
			out.append(s)
	for sp in splits_of(c):
		var to := StringName(str(sp["to"]))
		if StringName(str(sp["from"])) in out and to not in out:
			out.append(to)
	return out

static func cap_section(c: Node, cap: Dictionary) -> StringName:
	if not cap.has("section"):
		cap["section"] = base_of(c, str(cap["part"]))
	return cap["section"]

static func is_split(c: Node, section: StringName) -> bool:
	return splits_of(c).any(func(sp: Dictionary) -> bool: return StringName(str(sp["to"])) == section)

static func is_armoured(c: Node, section: StringName) -> bool:
	return str(section) in (_species(c).get("armoured", []) as Array)

static func label(section: StringName) -> String:
	return str((cfg().get("labels", {}) as Dictionary).get(str(section), str(section).capitalize()))

## The section a hit on hurtbox `part` at world point `at` lands in (splits applied).
static func of_hit(c: Node, part: StringName, at: Vector3) -> StringName:
	var hb := Hurtboxes.of(c)
	if hb == null:
		return &""
	for cap in hb.caps:
		if cap["part"] == part:
			return _split(c, cap, at)
	return section_at(c, at)

## The section of the capsule surface nearest a world point (crit spots, taps, ranged).
static func section_at(c: Node, at: Vector3) -> StringName:
	var cap := cap_at(c, at)
	return _split(c, cap, at) if not cap.is_empty() else &""

## The hurtbox capsule a world point belongs to: the one it is deepest inside (as a share of the radius), else the
## nearest surface.
static func cap_at(c: Node, at: Vector3) -> Dictionary:
	var hb := Hurtboxes.of(c)
	if hb == null:
		return {}
	hb.sync()
	var best: Dictionary = {}
	var best_d := INF
	for cap in hb.caps:
		# Depth as a share of the radius: a point inside two capsules goes to the one it is most inside (a leg's
		# axis inside a fat torso is the leg), a point outside every capsule to the nearest surface.
		var d := Geometry3D.get_closest_point_to_segment(at, cap["wa"], cap["wb"]).distance_to(at) - float(cap["wr"])
		d = d / float(cap["wr"]) if d < 0.0 else d
		if d < best_d:
			best_d = d
			best = cap
	return best

static func _split(c: Node, cap: Dictionary, at: Vector3) -> StringName:
	var sec := cap_section(c, cap)
	var a: Vector3 = cap["wa"]
	var b: Vector3 = cap["wb"]
	var r := float(cap["wr"])
	var on := Geometry3D.get_closest_point_to_segment(at, a, b)
	var up := (c as Node3D).global_basis.y.normalized()
	for sp in splits_of(c):
		if StringName(str(sp["from"])) != sec:
			continue
		var h := (at - on).dot(up)
		if sp.has("below") and h < -float(sp["below"]) * r:
			return StringName(str(sp["to"]))
		if sp.has("above") and h > float(sp["above"]) * r:
			return StringName(str(sp["to"]))
		if sp.has("base_frac"):
			var share := on.distance_to(_base_end(c, cap)) / maxf(0.001, a.distance_to(b))
			if share < float(sp["base_frac"]) and h > -0.2 * r:  # the back of the skull, not its underside
				return StringName(str(sp["to"]))
	return sec

## The section a ray (a tap through the camera) meets first on this body, or "".
static func on_ray(c: Node, from: Vector3, to: Vector3) -> StringName:
	var hb := Hurtboxes.of(c)
	if hb == null:
		return &""
	hb.sync(true)
	var best := INF
	var at := Vector3.INF
	for cap in hb.caps:
		var pts := Geometry3D.get_closest_points_between_segments(from, to, cap["wa"], cap["wb"])
		if pts[0].distance_to(pts[1]) <= float(cap["wr"]):
			var d := from.distance_to(pts[0])
			if d < best:
				best = d
				# Back up along the ray to the capsule's surface: the point the finger is on.
				var r := float(cap["wr"])
				var off := pts[0].distance_to(pts[1])
				at = pts[0] - (to - from).normalized() * sqrt(maxf(0.0, r * r - off * off))
	return section_at(c, at) if at != Vector3.INF else &""

## The capsule end nearest the bone's own joint.
static func _base_end(c: Node, cap: Dictionary) -> Vector3:
	var hb := Hurtboxes.of(c)
	var joint := (hb.skeleton.global_transform * hb.skeleton.get_bone_global_pose(int(cap["bone"]))).origin
	return cap["wa"] if (cap["wa"] as Vector3).distance_to(joint) < (cap["wb"] as Vector3).distance_to(joint) else cap["wb"]

## The live capsules a section is drawn on / aimed at: [{a, b, r, cap}] (a split rides its parent's capsules).
static func caps_of(c: Node, section: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var hb := Hurtboxes.of(c)
	if hb == null:
		return out
	hb.sync()
	var from := section
	for sp in splits_of(c):
		if StringName(str(sp["to"])) == section:
			from = StringName(str(sp["from"]))
	for cap in hb.caps:
		if cap_section(c, cap) == from:
			out.append(cap)
	return out

## Where a shot or a swing aims for this section: a point on it, live. A section holding a crit spot aims at the spot
## itself (the shooter goes for the weak spot); else the first point of its biggest capsule (centre, above, below, its
## base end) that lands back in the section, so a split aims at its own side of the parent capsule.
static func aim_point(c: Node, section: StringName, at_spot: bool = true) -> Vector3:
	if at_spot:
		for s in CritSpots.world(c as Creature):
			if section_at(c, s["centre"]) == section:
				return s["centre"]
	var caps := caps_of(c, section)
	if caps.is_empty():
		return (c as Node3D).global_position
	var up := (c as Node3D).global_basis.y.normalized()
	caps.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return (x["wa"] as Vector3).distance_to(x["wb"]) + float(x["wr"]) > (y["wa"] as Vector3).distance_to(y["wb"]) + float(y["wr"]))
	for cap in caps:
		var mid: Vector3 = ((cap["wa"] as Vector3) + (cap["wb"] as Vector3)) * 0.5
		var r := float(cap["wr"])
		var base := _base_end(c, cap)
		for p in [mid, mid + up * r * 0.6, mid - up * r * 0.75, base + (mid - base) * 0.3 + up * r * 0.5, base + (mid - base) * 0.3]:
			if section_at(c, p) == section:
				return p
		for k in [0.25, 0.75, 0.0, 1.0]:
			for h in [0.0, 0.6, -0.75, -0.9]:
				var q: Vector3 = (cap["wa"] as Vector3).lerp(cap["wb"], k) + up * r * h
				if section_at(c, q) == section:
					return q
	return ((caps[0]["wa"] as Vector3) + (caps[0]["wb"] as Vector3)) * 0.5

## The sections holding a crit spot.
static func crit_sections(c: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	for s in CritSpots.world(c as Creature):
		var sec := section_at(c, s["centre"])
		if sec != &"" and sec not in out:
			out.append(sec)
	return out
