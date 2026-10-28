shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never, diffuse_lambert, specular_schlick_ggx;

// Swash on the beach: a thin skin over the sand just above the waterline (SeaWaves builds it from
// the terrain's own triangles). Each of water.gdshader's two breaker lines, once it reaches the
// waterline, runs up the sand as a foam lip over a sheet of water, then drains back and leaves a
// wet darkening line at that cycle's high mark that fades until the next one. Height above the
// logical sea (world y - lift - water_y) is the shore distance: the beach slope turns it into metres.
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float water_y = -0.05;
uniform float lift = 0.04;
uniform float swash_period = 7.0;
// Highest run-up of a cycle, in metres of height above the sea (SeaWaves, by weather).
uniform float run_up = 0.07;
uniform float foam_amt = 0.55;
uniform vec3 wet_col : source_color = vec3(0.30, 0.25, 0.18);
uniform vec3 sheet_col : source_color = vec3(0.72, 0.86, 0.86);
uniform vec3 foam_col : source_color = vec3(0.95, 0.97, 0.97);

varying vec3 world_pos;
varying float surf;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	surf = COLOR.r;  // SeaWaves.surf_mask: 0 at the river mouth fades the swash out
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float h = world_pos.y - lift - water_y;
	// Same along-coast jitter as water.gdshader, so a breaker line arrives where its swash starts.
	float along = texture(noise_tex, world_pos.xz / 45.0).r;
	float grain = texture(noise_tex, world_pos.xz / 2.2 + vec2(TIME * 0.05, 0.0)).r;
	// A ragged front: the reach varies along the beach by up to half the run-up.
	float reach = (texture(noise_tex, world_pos.xz / 6.0 + vec2(0.0, TIME * 0.01)).r - 0.5) * run_up * 0.6;
	float wet = 0.0;
	float sheet = 0.0;
	float lip = 0.0;
	for (int i = 0; i < 2; i++) {
		float ti = TIME / swash_period + float(i) * 0.5 + along * 0.8;
		float p = fract(ti);
		float big = i == 0 ? 1.0 : 0.65;
		// Run-up over the second half: up fast (to 0.65), back slowly.
		float s = clamp((p - 0.5) * 2.0, 0.0, 1.0);
		float r_now = run_up * big * mix(0.6, 1.0, hash(floor(ti) + float(i) * 7.3));
		float r = r_now * (s < 0.3 ? smoothstep(0.0, 0.3, s) : 1.0 - smoothstep(0.3, 1.0, s)) * step(0.5, p);
		r += reach * step(0.5, p) * (1.0 - s) + (grain - 0.5) * 0.008;
		sheet = max(sheet, (1.0 - smoothstep(r - 0.008, r + 0.002, h)) * step(0.5, p) * (1.0 - s * 0.6));
		float x = (h - r) / 0.014;
		lip = max(lip, exp(-x * x) * step(0.5, p) * (1.0 - s * 0.7) * big);
		// The wet line sits at the latest cycle's high mark and fades until the next one peaks.
		float tp = ti - 0.65;
		float r_peak = run_up * big * mix(0.6, 1.0, hash(floor(tp) + float(i) * 7.3)) + reach * 0.7;
		wet = max(wet, (1.0 - smoothstep(r_peak - 0.02, r_peak + 0.004, h)) * (0.95 - 0.7 * fract(tp)));
	}
	lip *= smoothstep(0.25, 0.55, grain + 0.15) * foam_amt;
	// Bubbles left in the draining sheet.
	float fizz = sheet * smoothstep(0.58, 0.78, grain) * 0.6;
	vec3 col = wet_col;
	float a = wet * 0.45;
	col = mix(col, sheet_col, sheet);
	a = max(a, sheet * 0.3);
	float fw = clamp(lip + fizz, 0.0, 1.0);
	col = mix(col, foam_col, fw);
	a = max(a, fw * 0.95);
	// Below the waterline the sea plane draws; this skin only covers the sand.
	a *= smoothstep(-0.01, 0.005, h) * surf;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
	ROUGHNESS = mix(0.85, 0.12, max(wet * 0.6, sheet));
	SPECULAR = 0.5;
}
