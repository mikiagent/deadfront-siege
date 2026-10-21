shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

// CARD2D: a flat card baked from a resource GLB (scripts/dev/card_bake.gd), stood on the ground and
// facing the fixed iso camera. The albedo carries the baked look, the normal map the model's
// view-space normals, so the island's moving sun still shades the card like a 3D object. The quad is
// alpha-scissored, so it draws in the opaque pass and sorts without the transparency headaches.
// Sway: sideways travel grows with height, none at the ground pivot, driven by TIME and a phase from
// the card's world position so neighbours never move in lockstep. The fade body (see-through trees,
// W2-OCCLUDE) comes from the occlusion include: Occlusion drives occl_fade per instance.
#include "res://shaders/occlusion/occlusion.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform float sway_amplitude = 0.1;
uniform float sway_speed = 1.0;
uniform vec2 pivot_uv = vec2(0.5, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float rustle = 0.0;
uniform float rustle_time = 0.0;
uniform float alpha_scissor = 0.5;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 0 at the ground pivot row, 1 at the top of the card.
	float h = clamp((pivot_uv.y - UV.y) / max(0.001, pivot_uv.y), 0.0, 1.0);
	float phase = world.x * 0.45 + world.z * 0.37;
	float wave = sin(TIME * sway_speed + phase);
	float gust = sin(TIME * 0.37 + phase * 0.5) * 0.5;
	float amp = sway_amplitude * (wave + gust);
	// A short shiver right after a gather (HarvestNode.mark_gathered -> CardProp.rustle).
	amp += rustle * 0.09 * sin(rustle_time * 26.0) * h * h;
	VERTEX.x += amp * h * h;
	VERTEX.z += amp * 0.35 * h * h;
	occl_drop = occl_drop_of(MODEL_MATRIX, INV_VIEW_MATRIX);
}

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	ALBEDO = albedo.rgb * tint.rgb;
	ALPHA = albedo.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// Last, so the texture reads above keep their derivatives in every lane.
	if (occl_drop > occl_bayer4(FRAGCOORD.xy)) {
		discard;
	}
}
