class_name BodyWounds
extends Node
## WOUNDS AND ARMOR BREAKS (owner: "Melee weapons should make their own crits by attacking and focusing the same body
## part, it should form a crack in armor (Armor break) or a gash in the skin (Wound) and targeting the armor break
## allows you to damage and targeting the wound allows you to crit"). One per animal, made on its first player melee
## hit. Each landed melee hit adds build-up to the section it connected with (BodySections), per the weapon's
## channels (hitboxes.json sections.wounds.channels): slash builds a Wound on skin, impact an Armor break on armoured
## sections, pierce builds both at pierce_rate (ASSUMPTION PC4: Combat_Math has Pierce favoured against Light and Medium
## armour). Hitting another section keeps only switch_keep of every other section's build, and a section left alone
## past idle_s loses decay_per_s. At the threshold it forms, shows a decal on the body (a red gash, a glowing crack)
## and a floating label once. An Armor break lifts the armour's damage cut on that section; a Wound makes every hit
## there a sure crit at wound_mult (like a crit spot) and starts the bleed status. Both last the fight: they clear
## when the animal goes fight_s without a player hit.

const NAME := &"BodyWounds"
const WOUND := &"wound"
const BREAK := &"break"
const GASH := Color(0.75, 0.02, 0.02)
const CRACK := Color(1.0, 0.55, 0.1)

## section -> {wound: float, break: float} build-up as of last_hit[section]
var build: Dictionary = {}
var last_hit: Dictionary = {}
## section -> {wound: true, break: true} once formed
var formed: Dictionary = {}
var last_section: StringName = &""
var _last_any := 0.0
var _active := false
var _decals: Array[Node3D] = []

static func cfg() -> Dictionary:
	return BodySections.cfg().get("wounds", {})

static func of(c: Node, make: bool = true) -> BodyWounds:
	if c == null or not is_instance_valid(c):
		return null
	var w := c.get_node_or_null(NodePath(NAME)) as BodyWounds
	if w == null and make:
		w = BodyWounds.new()
		w.name = NAME
		c.add_child(w)
	return w

static func now() -> float:
	return Time.get_ticks_msec() * 0.001

## The build-up channels a weapon lands with: its tool_class row, else its damage_type row; bare hands punch (impact).
static func channels(def: ItemDef) -> Array:
	var rows: Dictionary = cfg().get("channels", {})
	if def == null:
		return rows.get("blunt", ["impact"])
	return rows.get(str(def.tool_class), rows.get(str(def.damage_type), []))

## Damage multiplier of a hit on this section: unbroken armour cuts it (ASSUMPTION PC2).
static func damage_mult(c: Node, section: StringName) -> float:
	if section == &"" or not BodySections.is_armoured(c, section) or has(c, section, BREAK):
		return 1.0
	return float(BodySections.cfg().get("armour_mult", 0.25))

static func has(c: Node, section: StringName, kind: StringName) -> bool:
	var w := of(c, false)
	if w and w._over():
		w.clear()
	return w != null and (w.formed.get(section, {}) as Dictionary).has(kind)

## A Wound on this section as a crit spot (CritSpots.land feedback, wound_mult), or {}.
static func wound_spot(c: Node, section: StringName, at: Vector3) -> Dictionary:
	if not has(c, section, WOUND):
		return {}
	return {"name": StringName("wound_%s" % section), "bone": &"", "centre": at, "radius": 0.0, "mult": float(cfg().get("wound_mult", 2.0))}

## One landed player melee hit on a section: adds its build-up; returns the kind formed by this hit (&"" none).
static func register(c: Creature, section: StringName, chans: Array, at: Vector3, part: StringName = &"", source: Node = null) -> StringName:
	if c == null or section == &"" or c.health.dead:
		return &""
	return of(c)._hit(c, section, chans, at, part, source)

## The build of one kind on a section now, after idle decay.
func level(section: StringName, kind: StringName) -> float:
	var b := float((build.get(section, {}) as Dictionary).get(kind, 0.0))
	var idle := now() - float(last_hit.get(section, now())) - float(cfg().get("idle_s", 3.0))
	return maxf(0.0, b - maxf(0.0, idle) * float(cfg().get("decay_per_s", 0.5)))

func _hit(c: Creature, section: StringName, chans: Array, at: Vector3, part: StringName, source: Node) -> StringName:
	var t := now()
	_last_any = t
	_active = true
	var armoured := BodySections.is_armoured(c, section)
	var keep := float(cfg().get("switch_keep", 0.5))
	for s in build.keys():
		var row := {WOUND: level(s, WOUND), BREAK: level(s, BREAK)}
		if s != section and section != last_section:
			row[WOUND] *= keep
			row[BREAK] *= keep
		build[s] = row
		last_hit[s] = t if s == section else float(last_hit.get(s, t))
	var row: Dictionary = build.get(section, {WOUND: 0.0, BREAK: 0.0})
	last_section = section
	last_hit[section] = t
	var broken := has(c, section, BREAK)
	for ch in chans:
		var w := 1.0 if ch != "pierce" else float(cfg().get("pierce_rate", 0.5))
		# Unbroken armour only cracks; skin (or armour already cracked open) is cut.
		if (ch == "impact" or ch == "pierce") and armoured and not broken:
			row[BREAK] = float(row[BREAK]) + w
		elif (ch == "slash" or ch == "pierce") and (not armoured or broken):
			row[WOUND] = float(row[WOUND]) + w
	build[section] = row
	var got := &""
	if armoured and not broken and float(row[BREAK]) >= float(cfg().get("break_at", 3.0)):
		got = BREAK
	elif not has(c, section, WOUND) and float(row[WOUND]) >= float(cfg().get("wound_at", 3.0)):
		got = WOUND
	if got != &"":
		_form(c, section, got, at, part, source)
	return got

func _form(c: Creature, section: StringName, kind: StringName, at: Vector3, part: StringName, source: Node) -> void:
	var f: Dictionary = formed.get(section, {})
	f[kind] = true
	formed[section] = f
	(build[section] as Dictionary)[kind] = 0.0
	c.combat_float.emit(0.0, &"wound_formed" if kind == WOUND else &"armor_break")
	if kind == WOUND and str(cfg().get("bleed", "")) != "" and Data.status(StringName(str(cfg()["bleed"]))):
		c.statuses.apply(StringName(str(cfg()["bleed"])), source)
	c.hit_burst(GASH if kind == WOUND else CRACK, 0.18, 22, 0.5, at)
	_decal(c, kind, at, part)
	print("[combat] %s formed on %s %s" % [kind, c.def.id, section])

## A gash (dark red slashes) or a crack (glowing orange fracture lines) riding the bone of the capsule that was hit.
func _decal(c: Creature, kind: StringName, at: Vector3, part: StringName) -> void:
	var hb := Hurtboxes.of(c)
	if hb == null:
		return
	var cap: Dictionary = {}
	for k in hb.caps:
		if k["part"] == part:
			cap = k
	if cap.is_empty():
		var best := INF
		for k in hb.caps:
			var d := Geometry3D.get_closest_point_to_segment(at, k["wa"], k["wb"]).distance_to(at) - float(k["wr"])
			if d < best:
				best = d
				cap = k
	var att := BoneAttachment3D.new()
	att.bone_idx = int(cap["bone"])
	hb.skeleton.add_child(att)
	att.global_transform = hb.skeleton.global_transform * hb.skeleton.get_bone_global_pose(att.bone_idx)  # before its first pose update
	var root := Node3D.new()
	root.name = "WoundDecal" if kind == WOUND else "ArmorBreakDecal"
	att.add_child(root)
	# Out of the capsule's axis to its surface at the hit, facing outwards.
	var axis_pt := Geometry3D.get_closest_point_to_segment(at, cap["wa"], cap["wb"])
	var out := at - axis_pt
	out = out.normalized() if out.length() > 0.001 else (c.global_basis.y)
	var surface := axis_pt + out * float(cap["wr"]) * 1.12  # just proud of the skin (the capsule hugs 90 % of it)
	var along := ((cap["wb"] as Vector3) - (cap["wa"] as Vector3)).normalized()
	if absf(along.dot(out)) > 0.95:
		along = out.cross(Vector3.UP).normalized()
	var side := out.cross(along).normalized()
	var r := float(cap["wr"])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = GASH if kind == WOUND else CRACK
	m.emission_enabled = true
	m.emission = m.albedo_color
	m.emission_energy_multiplier = 0.6 if kind == WOUND else 4.0
	m.no_depth_test = kind == BREAK  # the fracture glows through spikes and plates over it; the gash sits in the skin
	var lines: Array = [[0.0, 0.0, 0.9], [0.12, 0.1, 0.65], [-0.14, -0.08, 0.55]] if kind == WOUND \
		else [[0.0, 0.0, 0.8], [1.0, 0.0, 0.6], [2.1, 0.0, 0.7], [3.3, 0.0, 0.5], [4.4, 0.0, 0.6]]
	for i in lines.size():
		var row: Array = lines[i]
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		var len := maxf(0.3, r * 1.3) * float(row[2])
		box.size = Vector3(len, maxf(0.04, r * 0.12), maxf(0.03, r * 0.08))
		mi.mesh = box
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := along
		var pos := surface + side * float(row[1]) * r
		if kind == BREAK:
			dir = along.rotated(out, float(row[0]) * 1.1)  # a star of fractures
			pos = surface + dir * len * 0.45
		else:
			pos += along * float(row[0]) * r
		var b := Basis(dir, out.cross(dir).normalized(), out).orthonormalized()
		root.add_child(mi)
		mi.global_transform = Transform3D(b, pos)  # placed in the world now; from here on it rides the bone
	_decals.append(att)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _over() -> bool:
	return _active and now() - _last_any > float(cfg().get("fight_s", 30.0))

func _process(_d: float) -> void:
	if _over():
		clear()

## The fight is over: build-up, Wounds, Armor breaks and their decals go.
func clear() -> void:
	build.clear()
	last_hit.clear()
	formed.clear()
	last_section = &""
	_active = false
	for d in _decals:
		if is_instance_valid(d):
			d.queue_free()
	_decals.clear()
