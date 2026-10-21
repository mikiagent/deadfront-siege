shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Per-individual natural coloration for creature skins: samples the original albedo (as imports from
// the GLB's StandardMaterial3D) and shifts it in HSV, keeping normal, roughness and metallic. Status
// FX (tint / darken / damage flash) are applied afterwards, on top of the shifted colour.

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_albedo = false;
uniform bool use_albedo_alpha = false;
uniform bool use_vertex_color = false;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

// Colour profile: hue in turns (0..1), saturation and value scales around 1.0.
uniform float hue_shift = 0.0;
uniform float sat_scale = 1.0;
uniform float val_scale = 1.0;

uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float normal_strength = 1.0;
uniform sampler2D roughness_tex : hint_roughness_gray, filter_linear_mipmap, repeat_enable;
uniform bool use_roughness_tex = false;
uniform int roughness_channel = 0;
uniform sampler2D metallic_tex : filter_linear_mipmap, repeat_enable;
uniform bool use_metallic_tex = false;
uniform int metallic_channel = 0;
// No emission: assigning EMISSION (even 0) on the gl_compatibility renderer added a white
// emissive term to every creature skin, which is what turned the raptors near-white.

// Pattern layer. Drawn from the REST-POSE vertex positions (CUSTOM0, filled once per mesh by
// CreatureView): skinning moves VERTEX, and Tripo UVs are arbitrary, so neither could hold a pattern
// still while the animal animates.
uniform int pattern_kind = 0; // 0 plain, 1 stripes, 2 spots, 3 saddle, 4 countershade
uniform float pattern_scale = 1.0;
uniform float pattern_strength = 0.0;
uniform float pattern_tone = 1.0; // +1 darker, -1 lighter
uniform float pattern_seed = 0.0;
uniform vec3 pattern_min = vec3(0.0);
uniform vec3 pattern_size = vec3(1.0);
uniform int pattern_axis = 2; // 0 x, 1 y, 2 z: the body's long axis

// Status FX (CreatureView.set_status_fx / flash_damage).
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount = 0.0;
uniform float darken = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float flash_amount = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

varying vec3 rest_pos;

void vertex() {
	// CUSTOM0 is the authored rest-pose position of this vertex (set once per mesh, never skinned).
	rest_pos = CUSTOM0.xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// 0..1 mask of the pattern on this fragment; 0 leaves the body colour alone.
float pattern_mask(vec3 n) {
	if (pattern_kind == 1) {
		float along = (pattern_axis == 0) ? n.x : ((pattern_axis == 1) ? n.y : n.z);
		float bands = along * 9.0 * pattern_scale + pattern_seed;
		float d = abs(fract(bands) - 0.5) * 2.0; // 0 at a band centre
		return smoothstep(0.35, 0.85, d);
	}
	if (pattern_kind == 2) {
		float s = 3.5 * pattern_scale;
		float a = vnoise(n * s + vec3(pattern_seed));
		float b = vnoise(n * s * 2.1 + vec3(pattern_seed + 17.0));
		return smoothstep(0.42, 0.62, a * 0.7 + b * 0.3);
	}
	if (pattern_kind == 3) {
		// Dorsal saddle: the back only, fading out down the flanks (n.y is up in mesh bounds).
		return smoothstep(0.50, 0.78, n.y);
	}
	if (pattern_kind == 4) {
		// Countershading: the belly, plus a thin jaw/throat band under the head.
		return smoothstep(0.45, 0.12, n.y);
	}
	return 0.0;
}

float channel_value(vec4 c, int ch) {
	return ch == 1 ? c.g : (ch == 2 ? c.b : (ch == 3 ? c.a : c.r));
}

void fragment() {
	vec2 uv = UV * uv_scale + uv_offset;
	vec4 col = albedo_color;
	if (use_albedo) {
		col *= texture(albedo_tex, uv);
	}
	if (use_vertex_color) {
		col *= COLOR;
	}
	vec3 hsv = rgb_to_hsv(col.rgb);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * sat_scale, 0.0, 1.0);
	hsv.z = clamp(hsv.z * val_scale, 0.0, 1.0);
	vec3 rgb = hsv_to_rgb(hsv);
	// Pattern: tone comes from the body colour itself (value up or down), never a foreign hue.
	if (pattern_kind != 0 && pattern_strength > 0.0) {
		vec3 n = clamp((rest_pos - pattern_min) / max(pattern_size, vec3(0.0001)), 0.0, 1.0);
		float m = pattern_mask(n) * pattern_strength;
		vec3 phsv = rgb_to_hsv(rgb);
		if (pattern_tone > 0.0) {
			phsv.z *= 1.0 - 0.55 * m;
			phsv.y = clamp(phsv.y * (1.0 + 0.15 * m), 0.0, 1.0);
		} else {
			phsv.z = clamp(phsv.z + (1.0 - phsv.z) * 0.65 * m, 0.0, 1.0);
			phsv.y = clamp(phsv.y * (1.0 - 0.30 * m), 0.0, 1.0);
		}
		rgb = hsv_to_rgb(phsv);
	}
	rgb *= (1.0 - darken);
	rgb = mix(rgb, tint_color.rgb, tint_amount);
	rgb = mix(rgb, flash_color.rgb, flash_amount);
	ALBEDO = rgb;
	ALPHA = col.a;
	// glTF materials often share one ORM texture: the channels are kept as the importer set them
	// (Godot's StandardMaterial3D texture channels), never guessed from red.
	ROUGHNESS = use_roughness_tex ? channel_value(texture(roughness_tex, uv), roughness_channel) * roughness : roughness;
	METALLIC = use_metallic_tex ? channel_value(texture(metallic_tex, uv), metallic_channel) * metallic : metallic;
	SPECULAR = specular;
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
