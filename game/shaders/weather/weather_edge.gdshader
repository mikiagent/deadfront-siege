shader_type canvas_item;
// WEATHER screen layer (WeatherFx), no screen read so it stays cheap on gl_compatibility and phones:
// the rain's grey wash, heat's warm wash and orange edge, cold's blue-white edge, frost creeping in from
// the borders, and the lightning flash. The edge ramp is the combat red edge's (StatusFx.draw_vignette):
// linear, 14% of the short side deep.
uniform vec2 px = vec2(1600.0, 900.0);
uniform float heat = 0.0;
uniform float cold = 0.0;
uniform float frost = 0.0;
uniform float rain = 0.0;
uniform float flash = 0.0;
uniform float edge_scale = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

vec4 over(vec4 dst, vec3 c, float a) {
	a = clamp(a, 0.0, 1.0);
	float oa = a + dst.a * (1.0 - a);
	if (oa <= 0.0001) {
		return vec4(0.0);
	}
	return vec4((c * a + dst.rgb * dst.a * (1.0 - a)) / oa, oa);
}

void fragment() {
	vec2 p = UV * px;
	float s = min(px.x, px.y);
	float dx = min(p.x, px.x - p.x);
	float dy = min(p.y, px.y - p.y);
	float d = min(dx, dy);
	float ramp = 1.0 - clamp(d / (s * 0.14), 0.0, 1.0);
	vec4 o = vec4(0.0);
	o = over(o, vec3(0.18, 0.22, 0.3), rain * rain * 0.26);
	o = over(o, vec3(0.08, 0.1, 0.16), rain * rain * 0.3 * ramp);
	o = over(o, vec3(1.0, 0.6, 0.25), heat * 0.04);
	o = over(o, vec3(0.74, 0.86, 1.0), cold * 0.05);
	float throb = 0.8 + 0.2 * sin(TIME * 2.4);
	o = over(o, vec3(1.0, 0.36, 0.04), heat * 0.6 * throb * ramp * ramp * edge_scale);
	o = over(o, vec3(0.62, 0.84, 1.0), cold * 0.5 * ramp * ramp * edge_scale);
	if (frost > 0.002) {
		vec2 q = p / s;
		// Corners frost first: the distance shrinks where both edges are near.
		float de = d * (0.55 + 0.45 * smoothstep(0.0, s * 0.5, max(dx, dy)));
		float reach = frost * 0.15 * s;
		float n = fbm(q * 7.0);
		float m = 1.0 - smoothstep(reach * 0.35, reach, de + (n - 0.5) * reach * 0.9);
		if (m > 0.0) {
			// Rime: fine frosted-glass grain, a brighter crust where it stops, a few glints.
			float grain = fbm(q * 64.0);
			float crust = m * (1.0 - m) * 4.0;
			float cell = hash(floor(q * 330.0));
			float sp = step(0.996, cell) * (0.5 + 0.5 * sin(TIME * 3.0 + cell * 40.0));
			vec3 fc = mix(vec3(0.82, 0.91, 1.0), vec3(1.0), clamp(grain * 0.6 + crust * 0.5 + sp, 0.0, 1.0));
			o = over(o, fc, (m * (0.3 + 0.45 * grain) + crust * 0.18 + sp * m) * min(1.0, edge_scale + 0.3));
		}
	}
	o = over(o, vec3(0.86, 0.91, 1.0), flash * (0.12 + 0.14 * (1.0 - UV.y)));
	COLOR = o;
}
