shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

// CARD2D: a flat card, stood on the ground and kept facing the camera, drawing a resource where a
// 3D prop would be. Two sources of art, chosen by `shading_mode`:
//   0  BAKED (scripts/dev/card_bake.gd): albedo plus the model's view-space normal map, so the
//      moving sun shades it like the 3D object it replaces.
//   1  PAINTED (the owner's cut sprites, data/world/sprites2d.json): the art carries its own
//      shading, so it is lit through a FLAT camera-facing normal - one shade over the whole card,
//      no invented sculpting - and still takes the sun's colour and energy (night, cloud, shade).
//   2  PAINTED, unlit: emission only, for the before/after shot that shows why 1 is the default.
// The quad is alpha-scissored, so it draws in the opaque pass and sorts without the transparency
// headaches. Sway: sideways travel grows with height, none at the ground pivot, driven by TIME and a
// phase from the card's world position so neighbours never move in lockstep. Parallax and the fade
// body come from the camera and occlusion includes (global uniforms, published by IsoCamera and
// Occlusion); nothing here knows the camera's angle.
#include "res://shaders/camera/camera.gdshaderinc"
// CARD_FADE_INCLUDE: the see-through fade body. It declares an instance uniform, and GLES3 (the web
// and phone renderer) caps the instances that may use one, so a card that can never hide the
// survivor is built from this file WITHOUT these marked lines (CardProp.fade_free_shader(), the same
// file minus the markers); only a card tall enough to fade carries them (Occlusion.TALL_M).
#include "res://shaders/occlusion/occlusion.gdshaderinc" // CARD_FADE_INCLUDE
#include "res://shaders/sky/sky_shadow.gdshaderinc"
// One sky-shadow value per card, at its ground point (a cloud darkens the whole card at once).
varying float v_sky;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_disable;
uniform int shading_mode = 0;
uniform float sway_amplitude = 0.1;
uniform float sway_speed = 1.0;
uniform vec2 pivot_uv = vec2(0.5, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float rustle = 0.0;
uniform float rustle_time = 0.0;
uniform float alpha_scissor = 0.5;
// Visible height of the card in metres: the slide is measured per metre of card, so a knee-high
// plant barely moves while a tree's crown drifts, and it never exceeds PARALLAX_MAX_SHARE of the card.
uniform float card_height = 1.0;
const float PARALLAX_MAX_SHARE = 0.15;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 0 at the ground pivot row, 1 at the top of the card.
	float h = clamp((pivot_uv.y - UV.y) / max(0.001, pivot_uv.y), 0.0, 1.0);
	float phase = world.x * 0.45 + world.z * 0.37;
	float wave = sin(TIME * sway_speed + phase);
	float gust = sin(TIME * 0.37 + phase * 0.5) * 0.5;
	float amp = sway_amplitude * (wave + gust);
	// A short shiver right after a gather (HarvestNode.mark_gathered -> CardProp.rustle); rocks send 0.
	amp += rustle * 0.09 * sin(rustle_time * 26.0) * h * h;
	VERTEX.x += amp * h * h;
	VERTEX.z += amp * 0.35 * h * h;
	// Parallax: the card stays planted at its ground point, and its upper part slides across the
	// screen against the camera focus in proportion to its height, like a 3D crown would. The quad
	// is camera-facing, so its local X/Y are the screen's right/up and MODEL_MATRIX's rows are
	// those axes in world space.
	vec3 ground = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_sky = sky_shade(ground.xz);
	vec2 d = ground.xz - camera_focus.xz;
	float sr = dot(vec3(d.x, 0.0, d.y), normalize(MODEL_MATRIX[0].xyz));
	float su = dot(vec3(d.x, 0.0, d.y), normalize(MODEL_MATRIX[1].xyz));
	float t = h * h;
	// In metres of card, not metres of ground: a 0.5 m plant 15 m from the focus slides < 0.08 m,
	// and even a tall tree moves at most 15 % of its own height (else small cards sheared into slivers).
	vec2 dir = vec2(sr, su);
	float metres = length(dir) * parallax_strength * t * card_height;
	float shift = min(metres, PARALLAX_MAX_SHARE * card_height) * t;
	vec2 unit = metres > 1e-5 ? dir / length(dir) : vec2(0.0);
	VERTEX.x += unit.x * shift;
	VERTEX.y += unit.y * shift;
	// CARD_FADE_BEGIN
	occl_drop = occl_drop_of(MODEL_MATRIX, INV_VIEW_MATRIX);
	// CARD_FADE_END
}

void fragment() {
	vec4 albedo = texture(albedo_tex, UV);
	ALBEDO = albedo.rgb * tint.rgb * v_sky;
	ALPHA = albedo.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	if (shading_mode == 0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 1.0;
	} else {
		// Painted art: flat, camera-facing normal in view space. The whole card takes one sun/no-sun
		// value and the light's colour, so it darkens at night and in shadow without a second, fake
		// 3D shading modelled on top of the paint.
		NORMAL = vec3(0.0, 0.0, 1.0);
		if (shading_mode == 2) {
			EMISSION = ALBEDO;
			ALBEDO = vec3(0.0);
		}
	}
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// CARD_FADE_BEGIN
	// See-through: the fade body's dither, strongest in the canopy, so a card hiding the survivor
	// opens up top-down and its trunk stays readable (Durango's fading canopies).
	float canopy = mix(0.65, 1.4, clamp(UV.y < pivot_uv.y ? (pivot_uv.y - UV.y) / max(0.001, pivot_uv.y) : 0.0, 0.0, 1.0));
	float drop = clamp(occl_drop * canopy, 0.0, 1.0);
	// Last, so the texture reads above keep their derivatives in every lane.
	if (drop > occl_bayer4(FRAGCOORD.xy)) {
		discard;
	}
	// CARD_FADE_END
}
