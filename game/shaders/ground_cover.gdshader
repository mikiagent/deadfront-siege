shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

// GROUND2D: painted ground-cover sprites (SPRITES2D sheet cuts) drawn as camera-facing cards in a
// per-cell MultiMesh, all of them through one atlas material for the whole island.
// It reuses the CARD2D card shader's sway: sideways travel grows with height, none at the ground
// pivot, phase from the card's world position plus a per-instance jitter, so neighbours never move
// in lockstep. Per instance: COLOR = tint (brightness/hue jitter),
// INSTANCE_CUSTOM = (tile offset u, tile offset v, sway phase 0..1, sway scale for this size).
// No normal map and no shadow casting: these are knee-high painted clumps, lit by the sun on their
// albedo. Alpha-scissored so the cards draw in the opaque pass, like CARD2D.
#include "res://shaders/camera/camera.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 tiles = vec2(1.0, 1.0);
uniform float sway_amplitude = 0.08;
uniform float sway_speed = 1.4;
uniform float alpha_scissor = 0.5;

// INSTANCE_CUSTOM is readable in the vertex stage only, so the tile offset travels to the fragment
// in a varying (one vec2, interpolated flat across the quad's two triangles).
varying vec2 v_tile_offset;
#include "res://shaders/sky/sky_shadow.gdshaderinc"
varying float v_sky;

void vertex() {
	v_tile_offset = INSTANCE_CUSTOM.xy;
	v_sky = sky_shade((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 0 at the ground pivot row, 1 at the top of the card.
	// The card's local Y runs from -0.5 (bottom, the ground row) to +0.5 (top), so the sway grows from
	// the ground pivot up: the whole bottom edge, not just the pivot pixel, stays planted.
	float h = clamp(VERTEX.y + 0.5, 0.0, 1.0);
	float phase = world.x * 0.45 + world.z * 0.37 + INSTANCE_CUSTOM.z * 6.2831;
	float wave = sin(TIME * sway_speed + phase);
	float gust = sin(TIME * 0.37 + phase * 0.5) * 0.5;
	// The per-instance sway scale keeps the travel proportional to the clump's own height, so a
	// small tuft shivers a centimetre while a tall reed leans several.
	float amp = sway_amplitude * INSTANCE_CUSTOM.w * (wave + gust);
	VERTEX.x += amp * h * h;
	VERTEX.z += amp * 0.35 * h * h;
	// A touch of settle, so the top of a leaning clump dips instead of stretching.
	VERTEX.y -= abs(amp) * 0.05 * h * h;
}

void fragment() {
	vec2 uv = v_tile_offset + clamp(UV, vec2(0.001), vec2(0.999)) * tiles;
	vec4 tex = texture(atlas, uv);
	ALBEDO = tex.rgb * COLOR.rgb * v_sky;
	ALPHA = tex.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
