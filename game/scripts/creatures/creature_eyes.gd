class_name CreatureEyes
extends Node3D
## Eyeshine: two small emissive dots on the head bone, faint by day and bright at night.
## Data: the creature JSON "eyes" block {bone, points [[x,y,z],[x,y,z]], radius, color}, points in the
## head bone's local space in model units (the BoneAttachment3D under the Skeleton3D inherits the
## model scale, so the dots scale with the animal). Spec: docs/design/durango-prompts/
## 27_2d_asset_sheets_glowing_eyes.md, "Glowing eyes".

## HDR intensity at full night. Compatibility ignores StandardMaterial emission in unshaded mode,
## so paint() drives both albedo and emission. Small anatomical dots need this stronger value to
## remain legible at the gameplay camera without returning to oversized eye geometry.
const NIGHT_ENERGY := 20.0
## Glow over the day, from data/world/eye_glow.json (owner, round 4: "make the eyes glow a little bit in
## the daytime too but no trail"): glow_at(night) = day + (1 - day) * night^ramp_pow. day_fraction is the
## noon level (eyeglow_lab --day= overrides it); the trail's night-only range is in the same file.
const GLOW_PATH := "res://data/world/eye_glow.json"
static var _glow_cfg: Dictionary = _load_glow()
static var day_fraction := clampf(float(_glow_cfg.get("day", 0.16)), 0.0, 1.0)
static var day_halo := clampf(float(_glow_cfg.get("day_halo", 0.3)), 0.0, 1.0)
static var ramp_pow := clampf(float(_glow_cfg.get("ramp_pow", 1.5)), 0.2, 6.0)
static var trail_from := clampf(float(_glow_cfg.get("trail_from", 0.2)), 0.0, 0.99)
static var trail_to := maxf(clampf(float(_glow_cfg.get("trail_to", 0.5)), 0.0, 1.0), trail_from + 0.01)
## Threat scaling (eye_glow.json "_threat"): small harassers get a faint glow and a stub of a trail.
static var threat_tier_low := float(_glow_cfg.get("threat_tier_low", 10.0))
static var threat_tier_high := maxf(float(_glow_cfg.get("threat_tier_high", 60.0)), threat_tier_low + 1.0)
static var weak_length := clampf(float(_glow_cfg.get("weak_length", 0.05)), 0.0, 1.0)
static var weak_energy := clampf(float(_glow_cfg.get("weak_energy", 0.25)), 0.0, 1.0)
static var weak_size := clampf(float(_glow_cfg.get("weak_size", 0.6)), 0.0, 1.0)
static var weak_glow := clampf(float(_glow_cfg.get("weak_glow", 0.45)), 0.0, 1.0)
## Pushed this far (metres, in world space after the model scale) out of the painted eye so the dot
## never z-fights or sinks into the skull; the billboard quad is flat against the camera, so a dot
## left on the surface comes out a crescent.
const SURFACE_PUSH_M := 0.005
## ASSUMPTION: glow geometry is a highlight over the authored eye, not a replacement eyeball.
## Cap its world radius by animal height and an absolute 2.5 cm ceiling across every species.
const EYE_RADIUS_PER_HEIGHT := 0.006
const MIN_WORLD_RADIUS_M := 0.006
const MAX_WORLD_RADIUS_M := 0.025

## ASSUMPTION (owner: "a subtle rim light on the skull around the eye so the face reads"): one small
## omni light per eye, just outside the socket, in the eye colour, only at night. Range is this many
## eye separations; no shadows, so it costs a light per eye and no shadow pass.
const RIM_RANGE_PER_SEPARATION := 0.8
const RIM_PUSH_PER_SEPARATION := 0.35
## Godot's omni falls off with the inverse square of the distance, so a light a few cm from the skull
## burns the face white; its energy is this level times the push distance squared (metres), which
## lights every head about as brightly whatever its size.
const RIM_LEVEL := 1.2
## Below this night factor the rim lights are off (a faint day glint lights nothing).
const RIM_MIN_NIGHT := 0.05

static var _materials: Dictionary = {} ## colour html -> shared StandardMaterial3D
static var _applied_night := -1.0

var attachment: BoneAttachment3D
var dots: Array[MeshInstance3D] = []
var rims: Array[OmniLight3D] = []
var _rim_energy := 0.0
## Motion ribbon behind the two dots (EyeTrail); null until setup() has built the dots.
var trail: EyeTrail
var eye_color := Color.WHITE
var bone_index: int = -1
var eye_material: StandardMaterial3D
var radius_model: float = 0.02
## 0 (a harmless pest) .. 1 (an apex predator); see threat_of.
var threat: float = 1.0
## The dot and rim glow the threat allows (alpha glow multiplies on top).
var threat_glow: float = 1.0

## ASSUMPTION (owner: a compsognathus "looks very intimidating with the eye trails but it's not that
## powerful"): threat follows the species tier (its level), or the eyes block "threat" override.
static func threat_of(def: CreatureDef, eyes: Dictionary = {}) -> float:
	if eyes.has("threat"):
		return clampf(float(eyes["threat"]), 0.0, 1.0)
	var tier := float(def.tier) if def else threat_tier_high
	return clampf((tier - threat_tier_low) / (threat_tier_high - threat_tier_low), 0.0, 1.0)

## Builds the BoneAttachment3D on the head bone and the two dots. Returns false when the rig has no
## such bone or the data has no usable points (the caller then drops this node).
func setup(view: CreatureView, eyes: Dictionary) -> bool:
	if view == null or view.rig == null or view.rig.skeleton == null:
		return false
	var sk := view.rig.skeleton
	var bone := str(eyes.get("bone", "Head"))
	bone_index = sk.find_bone(bone)
	if bone_index < 0:
		return false
	var pts: Array = eyes.get("points", [])
	if pts.size() < 2:
		return false
	var requested_radius := float(eyes.get("radius", 0.02))
	_requested_radius = requested_radius
	var col := Color.WHITE
	var raw: Variant = eyes.get("color", [1.0, 1.0, 1.0])
	if raw is Array and (raw as Array).size() >= 3:
		col = Color(float(raw[0]), float(raw[1]), float(raw[2]))
	threat = threat_of(view.def, eyes)
	threat_glow = lerpf(weak_glow, 1.0, threat)
	eye_material = material_for(col, threat_glow)
	var scale := maxf(view.rig.mesh_root.scale.x, 0.0001) if view.rig.mesh_root else 1.0
	var height_m := view.def.height_meters if view.def else 1.0
	var max_world_radius := clampf(height_m * EYE_RADIUS_PER_HEIGHT, MIN_WORLD_RADIUS_M, MAX_WORLD_RADIUS_M)
	radius_model = minf(requested_radius, max_world_radius / scale)
	attachment = BoneAttachment3D.new()
	attachment.name = "EyeSocket"
	sk.add_child(attachment)
	attachment.bone_name = bone
	# Out from the midpoint between the two authored eyes. Several transplanted head bones are rotated,
	# so model X is not their lateral axis; pushing both along +X buried the far-side small species.
	var eye_mid := (_vec(pts[0]) + _vec(pts[1])) * 0.5
	for p in pts:
		var v: Vector3 = _vec(p)
		var out := (v - eye_mid).normalized()
		if out.length_squared() < 0.0001:
			out = Vector3.RIGHT
		var at := v + out * (SURFACE_PUSH_M / scale)
		var mi := MeshInstance3D.new()
		mi.set_meta(&"creature_eyeshine", true)
		# A sphere, not a camera-facing quad: a quad half buried in the skull came out as a crescent
		# from the side, and a ball reads as a dot from every angle.
		var ball := SphereMesh.new()
		ball.radius = radius_model
		ball.height = radius_model * 2.0
		ball.radial_segments = 12
		ball.rings = 6
		mi.mesh = ball
		mi.material_override = eye_material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		attachment.add_child(mi)
		mi.position = at
		dots.append(mi)
	if dots.size() != 2:
		return false
	_add_rims(col, scale)
	# The ribbon lives in world space (top_level), so it hangs off this node, not the bone: a
	# BoneAttachment3D child would carry every vertex along with the head and never trail.
	eye_color = col
	trail = EyeTrail.new()
	trail.name = "EyeTrail"
	add_child(trail)
	trail.setup(self, dots, radius_model * scale, col, eyes)
	return true

## One rim light per eye, a little outside the dot, so the skull around the socket catches the glow.
## Children of the dots (they ride the head bone); the range is in world metres.
func _add_rims(col: Color, scale: float) -> void:
	var sep := dots[0].position.distance_to(dots[1].position)
	var push_m := sep * scale * RIM_PUSH_PER_SEPARATION
	_rim_energy = RIM_LEVEL * push_m * push_m * threat_glow
	for dot in dots:
		var out := (dot.position - (dots[0].position + dots[1].position) * 0.5).normalized()
		var l := OmniLight3D.new()
		l.name = "EyeRim"
		l.light_color = col
		l.light_energy = 0.0
		l.light_specular = 0.2
		l.shadow_enabled = false
		l.omni_range = sep * scale * RIM_RANGE_PER_SEPARATION
		l.omni_attenuation = 2.4
		l.visible = false
		dot.add_child(l)
		l.position = out * (sep * RIM_PUSH_PER_SEPARATION)
		rims.append(l)

## ALPHAS: a stronger glow. The dots take a brighter shared material (one per colour and level) and
## the rim lights scale by the same factor; 1.0 is the normal eyeshine.
var glow: float = 1.0
var _requested_radius := 0.02

## GENETICS: the view now carries the body size. The dots ride it (so the eye points follow the head),
## but their world radius keeps the species' anatomical cap, never a bigger ball on a bigger animal.
func fit_size(size: float) -> void:
	var view := get_parent() as CreatureView
	if view == null or view.rig == null or dots.is_empty():
		return
	var scale := maxf(view.rig.mesh_root.scale.x, 0.0001) * maxf(size, 0.0001)
	var max_world_radius := clampf((view.def.height_meters if view.def else 1.0) * EYE_RADIUS_PER_HEIGHT, MIN_WORLD_RADIUS_M, MAX_WORLD_RADIUS_M)
	radius_model = minf(_requested_radius, max_world_radius / scale)
	for d in dots:
		var ball := d.mesh as SphereMesh
		if ball != null:
			ball.radius = radius_model
			ball.height = radius_model * 2.0

func set_glow(mult: float) -> void:
	if is_equal_approx(mult, glow) or dots.is_empty():
		return
	_rim_energy *= mult / glow
	if trail != null:
		trail.boost(mult / glow)
	glow = mult
	eye_material = material_for(eye_color, glow * threat_glow)
	for d in dots:
		d.material_override = eye_material

static func _vec(p: Variant) -> Vector3:
	if p is Array and (p as Array).size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	if p is Vector3:
		return p
	return Vector3.ZERO

## One material per colour, shared by every creature that uses it: the brightness is a world-wide
## night factor, so there is nothing per-instance to animate but visibility.
static func material_for(col: Color, glow_mult: float = 1.0) -> StandardMaterial3D:
	var key := col.to_html(false) + ("" if is_equal_approx(glow_mult, 1.0) else "x%.2f" % glow_mult)
	var have: StandardMaterial3D = _materials.get(key)
	if have != null:
		return have
	var m := StandardMaterial3D.new()
	# Unshaded HDR albedo keeps a tiny dot legible in the Compatibility renderer, where emission-only
	# StandardMaterials rendered black. `paint` drives both albedo and emission from the night factor.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.BLACK
	m.metallic = 0.0
	m.roughness = 1.0
	m.emission_enabled = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Depth-tested, so the head hides the far eye; no depth write, so the two dots never sort
	# against each other at grazing angles.
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.set_meta(&"eye_col", col)
	m.set_meta(&"eye_glow", glow_mult)
	_materials[key] = m
	# A material created mid-night must already be at the current level, not jump on the next frame.
	paint(m, col, WorldLighting.night)
	return m

static func _load_glow() -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(GLOW_PATH)) if FileAccess.file_exists(GLOW_PATH) else null
	return raw if raw is Dictionary else {}

## Core glow (0..1 of the night glow) at night factor n: faint at noon, rising through dawn and dusk.
static func glow_at(n: float) -> float:
	return lerpf(day_fraction, 1.0, pow(clampf(n, 0.0, 1.0), ramp_pow))

## The core and bloom over the dot (EyeTrail's halo): the same ramp from a higher noon level.
static func halo_at(n: float) -> float:
	return lerpf(day_halo, 1.0, pow(clampf(n, 0.0, 1.0), ramp_pow))

## How much flame trail the night allows (0 by day, 1 at night).
static func trail_at(n: float) -> float:
	return smoothstep(trail_from, trail_to, clampf(n, 0.0, 1.0))

## Writes one species' colour at night factor n into its shared material.
static func paint(m: StandardMaterial3D, col: Color, n: float) -> void:
	var energy := NIGHT_ENERGY * glow_at(n) * float(m.get_meta(&"eye_glow", 1.0))
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, 1.0)
	m.emission = col
	m.emission_energy_multiplier = energy

## Writes the current night factor into every shared eye material (once per change).
static func apply_night() -> void:
	var n := clampf(WorldLighting.night, 0.0, 1.0)
	_applied_night = n
	for key in _materials:
		var m := _materials[key] as StandardMaterial3D
		paint(m, m.get_meta(&"eye_col", Color.html(str(key).left(6))), n)

func _process(delta: float) -> void:
	if WorldLighting.night != _applied_night:
		apply_night()
	# Dead or asleep creatures show no eyeshine (ASSUMPTION: the glow is an alert, waking trait).
	if attachment:
		attachment.visible = is_awake()
	var n := clampf(WorldLighting.night, 0.0, 1.0)
	for l in rims:
		l.visible = n > RIM_MIN_NIGHT
		l.light_energy = _rim_energy * n
	if trail:
		trail.tick(delta)

func is_awake() -> bool:
	var c := get_parent().get_parent() as Creature if get_parent() else null
	if c == null:
		return true
	if c.health and c.health.dead:
		return false
	if c.brain and c.brain.state == &"sleep":
		return false
	return true
