class_name LightningBolt
extends Node3D
## One lightning strike's look (WEATHER, owner 2026-10-28: "spawn actual lightning strike"): a jagged
## emissive ribbon from HEIGHT metres down to the ground with two branches, a ground flash, and a scorch
## mark that lingers. Cheap and gl_compatibility-safe: unshaded additive quads facing the fixed iso camera,
## no decals, no lights of its own (WorldWeather's lightning light lights the scene from its direction).
## WorldWeather ages it from its tick and frees it after LIFE. ASSUMPTION: strikes damage nothing.

const HEIGHT := 70.0
const LIFE := 6.0     ## the scorch fades out over the last 2 s, then the node goes
const BOLT_S := 0.6   ## the ribbon is gone after this
const JAG := 2.4      ## sideways wander of a joint, metres (14 m of view is 900 px: 1 m is ~64 px)

var age := 0.0
var _bolt: MeshInstance3D
var _glow: MeshInstance3D
var _scorch: MeshInstance3D
var _bolt_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _scorch_mat: StandardMaterial3D
var _halo_mat: StandardMaterial3D

static func make(at: Vector3, seed_v: int) -> LightningBolt:
	var b := LightningBolt.new()
	b.name = "LightningStrike"
	b.position = at
	b.set_process(false)
	b._build(seed_v)
	return b

func _build(seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var side := IsoCamera.view_basis().x  # ribbons face the iso camera, whose yaw never changes
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var halo := SurfaceTool.new()
	halo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(rng.randf_range(-8.0, 8.0), HEIGHT, rng.randf_range(-8.0, 8.0))
	var main := _path(rng, top, Vector3.ZERO, 30)
	_ribbon(core, main, side, 0.075)
	_ribbon(halo, main, side, 0.28)
	for i in 2:
		var from: Vector3 = main[rng.randi_range(6, 20)]
		var to := from + Vector3(rng.randf_range(-12.0, 12.0), -rng.randf_range(10.0, 22.0), rng.randf_range(-12.0, 12.0))
		var br := _path(rng, from, to, 10)
		_ribbon(core, br, side, 0.03)
		_ribbon(halo, br, side, 0.16)
	var mesh := ArrayMesh.new()
	core.commit(mesh)
	halo.commit(mesh)
	_bolt_mat = _additive(Color(1.0, 1.0, 1.0))
	_halo_mat = _additive(Color(0.45, 0.6, 1.0))
	_bolt = MeshInstance3D.new()
	_bolt.name = "Bolt"
	_bolt.mesh = mesh
	_bolt.set_surface_override_material(0, _bolt_mat)
	_bolt.set_surface_override_material(1, _halo_mat)
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.extra_cull_margin = 80.0
	add_child(_bolt)
	_glow_mat = _additive(Color(0.7, 0.8, 1.0))
	_glow_mat.albedo_texture = _radial(Color.WHITE)
	_glow = _flat("GroundFlash", 5.0, _glow_mat)
	_scorch_mat = StandardMaterial3D.new()
	_scorch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch_mat.albedo_texture = _radial(Color(0.05, 0.04, 0.03))
	_scorch = _flat("Scorch", 2.6, _scorch_mat)
	update()

func _path(rng: RandomNumberGenerator, a: Vector3, b: Vector3, n: int) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := clampf((float(i) + rng.randf_range(-0.35, 0.35) * float(i > 0 and i < n)) / float(n), 0.0, 1.0)
		var j := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * JAG * (0.0 if i == 0 or i == n else 1.0)
		pts.append(a.lerp(b, t) + j)
	return pts

func _ribbon(st: SurfaceTool, pts: Array[Vector3], side: Vector3, w: float) -> void:
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var quad := [p0 - side * w, p0 + side * w, p1 + side * w, p1 - side * w]
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(quad[k])

static func _additive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true  # a bolt reads through canopies, as a flash does
	m.albedo_color = c
	return m

static func _radial(c: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(c, 1.0))
	g.set_color(1, Color(c, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _flat(n: String, size: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = mat
	mi.position.y = 0.06
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

## Ribbon and ground flash follow the flash's double flicker; the scorch fades in, holds, fades out.
func update() -> void:
	var f := WorldWeather.flash_curve(age)
	_bolt.visible = age < BOLT_S
	_bolt_mat.albedo_color.a = f
	_halo_mat.albedo_color.a = f * 0.35
	_glow_mat.albedo_color.a = f * 0.9
	_scorch_mat.albedo_color.a = 0.7 * clampf(age / 0.15, 0.0, 1.0) * (1.0 - smoothstep(LIFE - 2.0, LIFE, age))

func done() -> bool:
	return age >= LIFE
