shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never, diffuse_lambert, specular_schlick_ggx;

// Sea plane: colour and opacity from the water depth over the terrain heightmap, a rolling
// Gerstner swell (vertex only, never gameplay: the logical sea stays HarbourSite.WATER_Y), ripple
// normals, two breaker foam bands running in to the beach (ShoreWash carries them up the sand),
// whitecaps in rough weather. SeaWaves sets the weather uniforms; hq = false is the web/phone path.
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// 1 on the sea coast, 0 in the river and inland water (SeaWaves.surf_mask): no surf there.
uniform sampler2D surf_tex : filter_linear, repeat_disable, hint_default_white;
uniform float map_size = 240.0;
uniform float height_res = 129.0;
uniform float water_y = -0.05;
uniform vec3 shallow_col : source_color = vec3(0.55, 0.80, 0.82);
uniform vec3 deep_col : source_color = vec3(0.14, 0.32, 0.46);
uniform vec3 foam_col : source_color = vec3(0.93, 0.96, 0.96);
uniform vec3 storm_col : source_color = vec3(0.20, 0.27, 0.31);
// Weather (SeaWaves): swell amplitude m, choppiness 0..1, foam 0..1, wind, roughness 0..1.
uniform float wave_amp = 0.05;
uniform float chop = 0.25;
uniform float foam_amt = 0.55;
uniform vec2 wind_dir = vec2(0.94, 0.34);
uniform float sea_state = 0.0;
// One breaker cycle: the line runs in over the first half, the swash runs up the beach after.
uniform float swash_period = 7.0;
uniform float break_depth = 0.55;
uniform bool hq = true;

varying vec3 world_pos;

float ground_at(vec2 xz) {
	vec2 uv = (xz + vec2(map_size * 0.5)) / map_size;
	if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0) {
		return -8.0;  // open ocean past the heightmap
	}
	vec2 tuv = uv * (height_res - 1.0) / height_res + vec2(0.5 / height_res);
	return textureLod(height_tex, tuv, 0.0).r;
}

// GPU Gems 1 ch. 1 Gerstner wave: adds its offset to p, its slopes to tangent and binormal.
void gerstner(vec2 dir, float wavelength, float amp, float q, vec2 xz, float t,
		inout vec3 p, inout vec3 tg, inout vec3 bn) {
	float k = 6.28318 / wavelength;
	float c = sqrt(9.8 / k) * 0.6;
	float f = k * (dot(dir, xz) - c * t);
	float wa = k * amp;
	float s = sin(f);
	float co = cos(f);
	p += vec3(q * amp * dir.x * co, amp * s, q * amp * dir.y * co);
	tg += vec3(-q * dir.x * dir.x * wa * s, dir.x * wa * co, -q * dir.x * dir.y * wa * s);
	bn += vec3(-q * dir.x * dir.y * wa * s, dir.y * wa * co, -q * dir.y * dir.y * wa * s);
}

vec2 rot(vec2 v, float a) {
	return vec2(v.x * cos(a) - v.y * sin(a), v.x * sin(a) + v.y * cos(a));
}

// The swell: two long waves move the mesh; the short ones (hq: two more) only shade, per pixel,
// so the 8-16 m sea mesh never facets. Returns the offset; tg / bn take the slopes.
vec3 swell(vec2 xz, float amp, bool shading, inout vec3 tg, inout vec3 bn) {
	vec3 p = vec3(0.0);
	float q = mix(0.3, 0.9, chop);
	vec2 wd = normalize(wind_dir);
	gerstner(wd, 30.0, amp, q, xz, TIME, p, tg, bn);
	gerstner(rot(wd, 0.55), 17.0, amp * 0.6, q, xz, TIME, p, tg, bn);
	if (shading) {
		gerstner(rot(wd, -0.6), 9.0, amp * 0.4, q, xz, TIME, p, tg, bn);
		if (hq) {
			gerstner(rot(wd, 0.25), 5.5, amp * 0.25, q, xz, TIME, p, tg, bn);
		}
	}
	return p;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The swell dies out in the shallows so the waterline (and the beach) stay where they are.
	float depth = water_y - ground_at(w.xz);
	float amp = wave_amp * smoothstep(0.15, 2.2, depth);
	vec3 tg = vec3(1.0, 0.0, 0.0);
	vec3 bn = vec3(0.0, 0.0, 1.0);
	vec3 p = swell(w.xz, amp, false, tg, bn);
	// No trough within ~5 m of depth: a sea-mesh triangle spans 6-13 m, and a vertex dipping offshore
	// dragged the drawn waterline down the beach, under the sand. Crests may rise (alpha hides them
	// over dry ground); the drawn shore stays at the logical sea level.
	p.y = mix(max(p.y, 0.0), p.y, smoothstep(3.0, 6.0, depth));
	// The sea plane is only ever translated (IslandTerrain._sea), so world offsets are local ones.
	VERTEX += p;
	world_pos = w + p;
}

void fragment() {
	float ground = ground_at(world_pos.xz);
	float depth = max(0.0, water_y - ground);
	float d = clamp(depth / 1.6, 0.0, 1.0);
	float amp = wave_amp * smoothstep(0.15, 2.2, depth);
	vec3 tg = vec3(1.0, 0.0, 0.0);
	vec3 bn = vec3(0.0, 0.0, 1.0);
	float swell_h = swell(world_pos.xz, amp, true, tg, bn).y / max(wave_amp * 2.25, 0.001);
	vec3 swell_n = normalize(cross(bn, tg));
	vec3 col = mix(shallow_col, deep_col, d);
	// Crests catch the light, troughs fall dark: reads as swell from the high game camera.
	col *= 1.0 + swell_h * mix(0.14, 0.24, chop) * d;
	col = mix(col, storm_col, sea_state * 0.45 * d);
	// Shallow water is still water: the river is only ~0.3 m deep over its bed and used to read as
	// a brown trench of mud. The floor is high enough that a channel reads blue-green at a glance.
	// Soft shallow fade to solid water by 1.6 m. At a 0.95 floor the seabed (and the deep plane under it)
	// showed through open water as hard-edged see-through patches, seen from the beach (owner bug).
	float alpha = mix(0.62, 1.0, smoothstep(0.0, 1.6, depth));

	float t = TIME;
	vec2 wd = normalize(wind_dir);
	vec2 drift = wd * t * (0.035 + 0.04 * chop);
	float f1 = texture(noise_tex, world_pos.xz / 7.0 + drift + vec2(t * 0.012, 0.0)).r;
	float f2 = texture(noise_tex, world_pos.xz / 3.5 - rot(drift, 1.2) * 1.3).r;
	// Static waterline foam, and faint ridges on open water.
	float shore = smoothstep(0.0, 0.03, depth) * (1.0 - smoothstep(0.05, 0.16, depth));
	float ridge = smoothstep(0.62, 0.86, f1 * 0.6 + f2 * 0.6);
	float foam = shore * (0.25 + ridge * 0.6) + ridge * 0.06 * (1.0 - d);
	// Ripple light and shade, so a calm sea still moves at the high game camera.
	col *= 1.0 + (f1 + f2 - 1.0) * mix(0.07, 0.12, chop);

	// Two breaker lines run in from break_depth to the waterline, offset by half a cycle, each one's
	// timing jittered along the coast so the beach never breaks in a single ring.
	float along = texture(noise_tex, world_pos.xz / 45.0).r;
	vec2 suv = (world_pos.xz + vec2(map_size * 0.5)) / map_size;
	float sres = float(textureSize(surf_tex, 0).x);  // its own grid: the height texture may be finer
	float surf = texture(surf_tex, suv * (sres - 1.0) / sres + vec2(0.5 / sres)).r;
	for (int i = 0; i < 2; i++) {
		float p = fract(t / swash_period + float(i) * 0.5 + along * 0.8);
		float a = p * 2.0;
		float line_d = break_depth * (1.0 - a);
		float w = 0.03 + 0.04 * a;
		float x = (depth - line_d) / w;
		// A sharp front and a softer trail of spent foam behind it (seaward).
		float band = exp(-x * x) + 0.35 * exp(-max(x, 0.0) * 0.8) * step(0.0, x) * a;
		band *= step(p, 0.5) * smoothstep(0.0, 0.2, a) * (i == 0 ? 1.0 : 0.7);
		foam += band * smoothstep(0.25, 0.55, f1 * 0.5 + f2 * 0.5 + 0.15) * foam_amt * surf;
	}
	// Whitecaps on the crests once the sea gets up.
	float caps = smoothstep(0.7, 1.0, swell_h) * smoothstep(0.3, 1.0, sea_state) * smoothstep(0.66, 0.82, f2 * 0.6 + f1 * 0.5);
	foam += caps * 0.7 * d;
	foam = clamp(foam, 0.0, 1.0);
	col = mix(col, foam_col, foam);
	alpha = max(alpha, foam * 0.92);
	if (depth <= 0.0) { alpha = 0.0; }

	float rip = 0.10 + 0.22 * chop;
	vec3 nrm = swell_n + vec3((f1 - 0.5) * rip, 0.0, (f2 - 0.5) * rip);
	if (hq) {
		// A fine third layer for the sun's glints.
		float f3 = texture(noise_tex, world_pos.xz / 1.3 + rot(drift, -0.8) * 2.2).r;
		nrm += vec3((f3 - 0.5) * rip * 0.6, 0.0, (f1 - f3) * rip * 0.4);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(nrm), 0.0)).xyz);
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = mix(0.07, 0.16, chop) + foam * 0.6;
	SPECULAR = 0.6;
}
