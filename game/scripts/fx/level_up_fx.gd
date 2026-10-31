class_name LevelUpFx
extends Node3D
## The level-up light at the survivor's feet (owner 2026-10-21: "Level ups should have light effect
## animations"). A character level-up: a warm gold pillar rising from the ground, two ground rings
## spreading out, a slow ray burst behind her, rising sparkles, a short flash on her and a
## short-lived OmniLight. A skill level-up: one ring, fewer sparkles, a smaller light. Additive
## unshaded meshes and a real light, not only post glow: gl_compatibility (the web build) glows far
## less than Forward+. One-shot: it frees itself after `life`. A child of the survivor, at her feet;
## while she rides, a child of her mount at the saddle (where she sits), its rings left on the ground
## under the mount and spread wider the higher she sits. It follows the interpolated transform and
## moves with her when she mounts or dismounts mid-way. Nothing here touches the camera.
## Parts, colours and timings come from data/level_fx.json (a part missing from a kind's section is
## not built).
# ASSUMPTION: the look (gold pillar, rings, rays, sparkles, a flash) is ours; the owner asked for
# "light effect animations" and the Durango references show only the HUD side.

const PATH := "res://data/level_fx.json"
const SHADER := preload("res://scripts/fx/level_up_fx.gdshader")
const GROUP := &"level_up_fx"
## Shader shapes (level_up_fx.gdshader).
const PILLAR := 0
const RING := 1
const RAYS := 2
const GLOW := 3

var kind: StringName = &"character"
var life: float = 2.0
var _t: float = 0.0
var _cfg: Dictionary = {}
var _parts: Array = []  # [MeshInstance3D, ShaderMaterial, part name, shape]
var _light: OmniLight3D
var _warm := false
var _who: Node3D  ## the survivor it plays for
var _ground := 0.0  ## how far above the ground it stands (her seat on a mount), where the rings stay

static var _data: Dictionary = {}
static var _dot: GradientTexture2D
static var _sparks: Dictionary = {}  # "size/energy" -> QuadMesh

## Section `name` of level_fx.json ("character", "skill", "hud"); {} when it is missing.
static func section(name: String) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = parsed if parsed is Dictionary else {"_load_failed": true}
		if not parsed is Dictionary:
			push_warning("[levelfx] %s missing or invalid: no level-up light" % PATH)
	var v: Variant = _data.get(name, {})
	return v if v is Dictionary else {}

static func color_of(row: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = row.get(key, null)
	return Color(float(v[0]), float(v[1]), float(v[2])) if v is Array and (v as Array).size() >= 3 else fallback

## 0..1: fades in over `in` from `at`, holds, fades out over `out`.
static func envelope(row: Dictionary, t: float) -> float:
	var u := t - float(row.get("at", 0.0))
	var fade_in := maxf(0.001, float(row.get("in", 0.1)))
	if u <= 0.0:
		return 0.0
	if u < fade_in:
		return 1.0 - pow(1.0 - u / fade_in, 2.0)
	u -= fade_in + float(row.get("hold", 0.0))
	return 1.0 if u <= 0.0 else 1.0 - smoothstep(0.0, maxf(0.001, float(row.get("out", 0.3))), u)

## 0..1 eased out over the part's whole run (`in` + `hold` + `out`): how far a ring has spread.
static func spread(row: Dictionary, t: float) -> float:
	var span := float(row.get("in", 0.1)) + float(row.get("hold", 0.0)) + float(row.get("out", 0.3))
	var p := clampf((t - float(row.get("at", 0.0))) / maxf(0.001, span), 0.0, 1.0)
	return 1.0 - pow(1.0 - p, 3.0)

## Plays a `fx_kind` level-up light on `who` (the survivor) at her feet.
static func spawn(who: Node3D, fx_kind: StringName) -> LevelUpFx:
	var fx := LevelUpFx.new()
	fx.kind = fx_kind
	fx._who = who
	fx._stand()
	return fx

## Stands on anchor(_who): at her feet; riding, at her model root on the saddle (6.9 m up a T. rex),
## held there in the mount's frame (the saddle bone bobs).
func _stand() -> void:
	var at := anchor(_who)
	var rig: Variant = _who.get("rig")
	var pos := Vector3.ZERO
	if at != _who:
		pos = at.to_local((rig as Node3D).global_position) if rig is Node3D else Vector3.ZERO
	elif _who.has_method("half_height"):
		pos = Vector3(0.0, -float(_who.call("half_height")), 0.0)
	_ground = maxf(0.0, pos.y) if at != _who else 0.0
	if get_parent():
		get_parent().remove_child(self)
	at.add_child(self)
	position = pos
	reset_physics_interpolation()

## What the light is a child of: her; riding, the mount's root, not the saddle or bone socket
## Player.mount hangs her from, which turns and bobs with the mount's animation.
static func anchor(who: Node3D) -> Node3D:
	var mount: Variant = who.get("mounted_on")
	return mount if mount is Node3D and is_instance_valid(mount) else who

## An invisible two-frame copy of the character light: the web renderer compiles its shaders on
## first draw, and that stall would land on the first real level-up.
static func warm_up(who: Node3D) -> void:
	var fx := LevelUpFx.new()
	fx._warm = true
	who.add_child(fx)

func _ready() -> void:
	name = "LevelUpFx"
	process_mode = Node.PROCESS_MODE_ALWAYS  # a paused or disabled survivor must not keep it alive
	_cfg = section(str(kind))
	life = float(_cfg.get("life", 2.0))
	if _warm:
		life = 0.05
	else:
		add_to_group(GROUP)
	if _cfg.has("pillar"):
		var p: Dictionary = _cfg["pillar"]
		var cyl := CylinderMesh.new()
		cyl.height = float(p.get("height", 4.6))
		cyl.bottom_radius = float(p.get("radius", 0.6))
		cyl.top_radius = cyl.bottom_radius * 1.2
		cyl.radial_segments = 24
		cyl.rings = 1
		cyl.cap_top = false
		cyl.cap_bottom = false
		_part("pillar", cyl, PILLAR, Vector3(0.0, cyl.height * 0.5, 0.0))
	for ring in ["ring", "ring2"]:
		if _cfg.has(ring):
			var plane := PlaneMesh.new()
			plane.size = Vector2(2.0, 2.0)
			# Lifted off the ground: on a bumpy island the terrain cut notches out of a ring laid at 6 cm.
			_part(ring, plane, RING, Vector3(0.0, float((_cfg[ring] as Dictionary).get("lift", 0.2)), 0.0))
	for glow in [["rays", RAYS], ["flash", GLOW]]:
		if _cfg.has(glow[0]):
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE
			_part(glow[0], quad, glow[1], Vector3(0.0, float((_cfg[glow[0]] as Dictionary).get("lift", 1.0)), 0.0))
	if _cfg.has("sparkles"):
		_sparkles(_cfg["sparkles"])
	if _cfg.has("light"):
		var l: Dictionary = _cfg["light"]
		_light = OmniLight3D.new()
		_light.light_color = color_of(l, "color", Color(1.0, 0.8, 0.45))
		_light.omni_range = float(l.get("range", 7.0))
		_light.omni_attenuation = 1.2
		_light.shadow_enabled = false
		_light.light_energy = 0.0
		_light.position = Vector3(0.0, float(l.get("lift", 1.2)), 0.0)
		add_child(_light)
	_animate()

func _part(part: String, mesh: Mesh, shape: int, at: Vector3) -> void:
	var row: Dictionary = _cfg[part]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("tint", color_of(row, "color", Color(1.0, 0.8, 0.35)))
	mat.set_shader_parameter("energy", float(row.get("energy", 2.0)))
	mat.set_shader_parameter("height", float(row.get("height", 4.0)))
	mat.set_shader_parameter("rays", float(row.get("count", 14)))
	mat.set_shader_parameter("push", 1.4 if shape == RAYS else (-1.6 if shape == GLOW else 0.0))
	var mi := MeshInstance3D.new()
	mi.name = part.capitalize().replace(" ", "")
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	if shape >= RAYS:
		mi.scale = Vector3.ONE * float(row.get("size", 3.0))
		mi.extra_cull_margin = float(row.get("size", 3.0))  # it faces the camera, not its mesh AABB
	add_child(mi)
	_parts.append([mi, mat, part, shape])

## Rising gold sparks: CPU particles (the same on both renderers and on a phone), left in the world
## as she walks on, gone with the effect.
func _sparkles(row: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.name = "Sparkles"
	p.amount = int(row.get("amount", 40))
	p.lifetime = float(row.get("life", 1.3))
	p.one_shot = true
	p.explosiveness = float(row.get("spread", 0.6))
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = float(row.get("radius", 0.8))
	p.emission_ring_inner_radius = float(row.get("radius", 0.8)) * 0.25
	p.emission_ring_height = 0.3
	p.direction = Vector3.UP
	p.spread = 14.0
	var speed: Array = row.get("speed", [1.2, 3.2])
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	p.gravity = Vector3(0.0, -0.4, 0.0)
	p.damping_min = 0.6
	p.damping_max = 1.4
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var col := color_of(row, "color", Color(1.0, 0.86, 0.45))
	var ramp := Gradient.new()
	ramp.set_color(0, col.lerp(Color.WHITE, 0.6))
	ramp.set_color(1, Color(col, 0.0))
	ramp.add_point(0.35, Color(col, 1.0))
	p.color_ramp = ramp
	p.mesh = _spark_mesh(float(row.get("size", 0.16)), float(row.get("energy", 2.0)))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 0.15, 0.0)
	if _warm:
		p.amount = 1
		p.scale_amount_min = 0.01
		p.scale_amount_max = 0.01
	add_child(p)
	p.emitting = true

## The sparkle quad, kept for the session: BaseMaterial3D frees its generated shader with the last
## material using it, so a fresh material per level-up recompiled it every time (a 120 ms frame on
## gl_compatibility in levelfx_lab --cost-only).
static func _spark_mesh(size: float, energy: float) -> QuadMesh:
	var key := "%.3f/%.3f" % [size, energy]
	if not _sparks.has(key):
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * size
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.disable_fog = true
		mat.disable_receive_shadows = true
		mat.albedo_color = Color(energy, energy, energy, 1.0)
		mat.albedo_texture = _dot_texture()
		quad.material = mat
		_sparks[key] = quad
	return _sparks[key]

static func _dot_texture() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.85))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(0.5, 0.0)
		_dot.width = 32
		_dot.height = 32
	return _dot

func _process(delta: float) -> void:
	_t += minf(delta, 0.1)  # as LevelUpCelebration.tick: a stalled frame does not skip the light
	if _t >= life:
		queue_free()
		return
	if _who and is_instance_valid(_who) and anchor(_who) != get_parent():
		_stand()  # she mounted or dismounted mid-way
	_animate()

func _animate() -> void:
	for entry in _parts:
		var mi: MeshInstance3D = entry[0]
		var mat: ShaderMaterial = entry[1]
		var row: Dictionary = _cfg[entry[2]]
		var e := 0.0 if _warm else envelope(row, _t)
		mat.set_shader_parameter("fade", e)
		match int(entry[3]):
			PILLAR:
				var rise_s := maxf(0.001, float(row.get("in", 0.4)))
				var u := clampf((_t - float(row.get("at", 0.0))) / rise_s, 0.0, 1.0)
				mat.set_shader_parameter("rise", 1.0 - pow(1.0 - u, 2.0))
			RING:
				var wide := 1.0 + _ground * float(section("mount").get("ring_per_m", 0.1))
				var radius := lerpf(float(row.get("from", 0.4)), float(row.get("to", 3.0)), spread(row, _t)) * wide
				mi.scale = Vector3(radius, 1.0, radius)
				mi.position.y = float(row.get("lift", 0.2)) - _ground  # on the ground, under her mount too
			RAYS:
				mat.set_shader_parameter("spin", _t * float(row.get("spin", 0.5)))
		mi.visible = _warm or e > 0.0
	if _light:
		var l: Dictionary = _cfg["light"]
		_light.light_energy = 0.0 if _warm else float(l.get("energy", 6.0)) * envelope(l, _t)
