class_name OcclusionMaterial
extends RefCounted
## Turns a prop's StandardMaterial3D into a ShaderMaterial that looks the same but can fade
## (scripts/world/occlu_occluder_standard.gdshaderinc). Godot does not expose the shader it generates
## for a BaseMaterial3D, so the props' feature subset is rebuilt here; anything else is reported.

const BODY := "res://scripts/world/occlu_occluder_standard.gdshaderinc"
const FILTERS := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap",
	"filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
const DIFFUSE := ["diffuse_burley", "diffuse_lambert", "diffuse_lambert_wrap", "diffuse_toon"]
const SPECULAR := ["specular_schlick_ggx", "specular_toon", "specular_disabled"]
const CULL := ["cull_back", "cull_front", "cull_disabled"]
const DEPTH := ["depth_draw_opaque", "depth_draw_always", "depth_draw_never"]
const CHANNEL := [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1),
	Vector4(0.333333, 0.333333, 0.333333, 0)]

## Feature key -> Shader. A handful of combinations exist, so these stay for the session.
static var _shaders: Dictionary = {}
static var _warned: Dictionary = {}

## A new ShaderMaterial equivalent to `src` that can fade (both modes: the share to drop comes per
## node or per instance), or null when `src` is not a BaseMaterial3D (left solid; the caller logs it).
static func derive(src: Material) -> ShaderMaterial:
	var b := src as BaseMaterial3D
	if b == null:
		return null
	var defines: PackedStringArray = []
	var modes: PackedStringArray = ["blend_mix", DEPTH[b.depth_draw_mode], CULL[b.cull_mode],
		DIFFUSE[b.diffuse_mode], SPECULAR[b.specular_mode]]
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		modes.append("unshaded")
	elif b.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX:
		modes.append("vertex_lighting")
	if b.no_depth_test:
		modes.append("depth_test_disabled")
	if b.disable_receive_shadows:
		modes.append("shadows_disabled")
	if b.disable_ambient_light:
		modes.append("ambient_light_disabled")
	if b.disable_fog:
		modes.append("fog_disabled")
	match b.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			defines.append("OCCL_SCISSOR")
		BaseMaterial3D.TRANSPARENCY_ALPHA:
			defines.append("OCCL_ALPHA")
		BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			defines.append("OCCL_ALPHA")
			modes.append("depth_prepass_alpha")
	if b.normal_enabled:
		defines.append("OCCL_NORMAL")
	if b.vertex_color_use_as_albedo:
		defines.append("OCCL_VCOLOR")
	if b.vertex_color_is_srgb:
		defines.append("OCCL_VCOLOR_SRGB")
	var multiply_emission := b.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY
	var emission := b.emission_enabled and not (multiply_emission and b.emission_texture == null)
	if emission:
		defines.append("OCCL_EMISSION")
	_warn_unsupported(b)
	var filter: String = FILTERS[b.texture_filter] + (", repeat_enable" if b.texture_repeat else ", repeat_disable")
	var key := "%s|%s|%s" % [",".join(modes), ",".join(defines), filter]
	var shader := _shaders.get(key) as Shader
	if shader == null:
		shader = Shader.new()
		var code := "shader_type spatial;\nrender_mode %s;\n#define OCCL_FILTER %s\n" % [", ".join(modes), filter]
		for d in defines:
			code += "#define %s\n" % d
		shader.code = code + "#include \"%s\"\n" % BODY
		_shaders[key] = shader
	var m := ShaderMaterial.new()
	m.shader = shader
	# The trunk line stays 0 (the whole model fades) until Occlusion sets it from the mesh it came from.
	m.set_shader_parameter("occl_trunk", 0.0)
	m.render_priority = b.render_priority
	m.next_pass = b.next_pass
	m.set_shader_parameter("albedo", b.albedo_color)
	m.set_shader_parameter("texture_albedo", b.albedo_texture)
	m.set_shader_parameter("roughness", b.roughness)
	m.set_shader_parameter("texture_roughness", b.roughness_texture)
	m.set_shader_parameter("roughness_texture_channel", CHANNEL[b.roughness_texture_channel])
	m.set_shader_parameter("metallic", b.metallic)
	m.set_shader_parameter("texture_metallic", b.metallic_texture)
	m.set_shader_parameter("metallic_texture_channel", CHANNEL[b.metallic_texture_channel])
	m.set_shader_parameter("specular", b.metallic_specular)
	m.set_shader_parameter("uv1_scale", b.uv1_scale)
	m.set_shader_parameter("uv1_offset", b.uv1_offset)
	if b.normal_enabled:
		m.set_shader_parameter("texture_normal", b.normal_texture)
		m.set_shader_parameter("normal_scale", b.normal_scale)
	if b.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
		m.set_shader_parameter("alpha_scissor_threshold", b.alpha_scissor_threshold if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.5)
	if emission:
		m.set_shader_parameter("emission", b.emission)
		m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
	return m

## Features the replica does not draw: say so once per feature instead of failing quietly.
static func _warn_unsupported(b: BaseMaterial3D) -> void:
	var missing: PackedStringArray = []
	for f in ["ao_enabled", "rim_enabled", "clearcoat_enabled", "anisotropy_enabled", "heightmap_enabled",
			"subsurf_scatter_enabled", "backlight_enabled", "refraction_enabled", "detail_enabled", "grow",
			"uv1_triplanar", "proximity_fade_enabled"]:
		if b.get(f):
			missing.append(f)
	if b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		missing.append("billboard_mode")
	if b.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		missing.append("distance_fade_mode")
	if b.emission_enabled and b.emission_texture != null:
		missing.append("emission_texture")
	for f in missing:
		if not _warned.has(f):
			_warned[f] = true
			print("[occlusion] %s is not replicated; %s draws without it while occludable" % [f, b.resource_name if b.resource_name != "" else b.resource_path])
