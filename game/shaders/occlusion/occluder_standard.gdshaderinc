// The subset of StandardMaterial3D that props use (OcclusionMaterial copies the values), written the
// way Godot generates it so a converted prop renders the same until something has to fade.
// The including shader sets render_mode, OCCL_FILTER and the OCCL_* feature defines first.
#include "res://shaders/occlusion/occlusion.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, OCCL_FILTER;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_roughness : hint_default_white, OCCL_FILTER;
uniform vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_metallic : hint_default_white, OCCL_FILTER;
uniform vec4 metallic_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
#ifdef OCCL_NORMAL
uniform sampler2D texture_normal : hint_roughness_normal, OCCL_FILTER;
uniform float normal_scale = 1.0;
#endif
#ifdef OCCL_SCISSOR
uniform float alpha_scissor_threshold = 0.5;
#endif
#ifdef OCCL_EMISSION
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 1.0;
#endif
#ifdef OCCL_INSIDE
// Per node, so one shared material serves every roof while each fades on its own.
instance uniform float occl_fade = 0.0;
#endif

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
#ifdef OCCL_VCOLOR_SRGB
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
#endif
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
#ifdef OCCL_VCOLOR
	albedo_tex *= COLOR;
#endif
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = dot(texture(texture_metallic, UV), metallic_texture_channel) * metallic;
	SPECULAR = specular;
	ROUGHNESS = dot(texture(texture_roughness, UV), roughness_texture_channel) * roughness;
#ifdef OCCL_NORMAL
	NORMAL_MAP = texture(texture_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
#endif
#ifdef OCCL_ALPHA
	ALPHA = albedo.a * albedo_tex.a;
#endif
#ifdef OCCL_SCISSOR
	ALPHA = albedo.a * albedo_tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
#endif
#ifdef OCCL_EMISSION
	EMISSION = emission.rgb * emission_energy;
#endif
#ifdef OCCL_INSIDE
	// A faded roof still shades the floor under it.
	float occl = occl_main_view(INV_VIEW_MATRIX) ? occl_fade : 0.0;
#else
	// 0.8: a faint screen-door ghost of the crown stays, so the tree reads as see-through, not cut.
	float occl = occl_between(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX) * 0.8;
#endif
	// Last, so the texture reads above keep their derivatives in every lane.
	if (occl > occl_bayer4(FRAGCOORD.xy)) {
		discard;
	}
}
