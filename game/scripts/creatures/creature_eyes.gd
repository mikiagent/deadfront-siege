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
## ASSUMPTION: a faint glint by day (the owner asked for "especially in the dark"): the dot is
## still there, and dark enough that the painted head reads through it. AgX compresses the low end.
static var day_fraction := 0.01
## Pushed this far (metres, in world space after the model scale) out of the painted eye so the dot
## never z-fights or sinks into the skull; the billboard quad is flat against the camera, so a dot
## left on the surface comes out a crescent.
const SURFACE_PUSH_M := 0.005
## ASSUMPTION: glow geometry is a highlight over the authored eye, not a replacement eyeball.
## Cap its world radius by animal height and an absolute 2.5 cm ceiling across every species.
const EYE_RADIUS_PER_HEIGHT := 0.006
const MIN_WORLD_RADIUS_M := 0.006
const MAX_WORLD_RADIUS_M := 0.025

static var _materials: Dictionary = {} ## colour html -> shared StandardMaterial3D
static var _applied_night := -1.0

var attachment: BoneAttachment3D
var dots: Array[MeshInstance3D] = []
var bone_index: int = -1
var eye_material: StandardMaterial3D
var radius_model: float = 0.02

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
	var col := Color.WHITE
	var raw: Variant = eyes.get("color", [1.0, 1.0, 1.0])
	if raw is Array and (raw as Array).size() >= 3:
		col = Color(float(raw[0]), float(raw[1]), float(raw[2]))
	eye_material = material_for(col)
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
	return dots.size() == 2

static func _vec(p: Variant) -> Vector3:
	if p is Array and (p as Array).size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	if p is Vector3:
		return p
	return Vector3.ZERO

## One material per colour, shared by every creature that uses it: the brightness is a world-wide
## night factor, so there is nothing per-instance to animate but visibility.
static func material_for(col: Color) -> StandardMaterial3D:
	var key := col.to_html(false)
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
	_materials[key] = m
	# A material created mid-night must already be at the current level, not jump on the next frame.
	paint(m, col, WorldLighting.night)
	return m

## Writes one species' colour at night factor n into its shared material.
static func paint(m: StandardMaterial3D, col: Color, n: float) -> void:
	var energy := NIGHT_ENERGY * lerpf(day_fraction, 1.0, clampf(n, 0.0, 1.0))
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, 1.0)
	m.emission = col
	m.emission_energy_multiplier = energy

## Writes the current night factor into every shared eye material (once per change).
static func apply_night() -> void:
	var n := clampf(WorldLighting.night, 0.0, 1.0)
	_applied_night = n
	for key in _materials:
		paint(_materials[key] as StandardMaterial3D, Color.html(key), n)

func _process(_delta: float) -> void:
	if WorldLighting.night != _applied_night:
		apply_night()
	# Dead or asleep creatures show no eyeshine (ASSUMPTION: the glow is an alert, waking trait).
	if attachment:
		attachment.visible = is_awake()

func is_awake() -> bool:
	var c := get_parent().get_parent() as Creature if get_parent() else null
	if c == null:
		return true
	if c.health and c.health.dead:
		return false
	if c.brain and c.brain.state == &"sleep":
		return false
	return true
