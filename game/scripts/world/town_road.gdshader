shader_type spatial;
// TOWNPOLISH2: the tutorial town's streets (TownDress._roads). A decal-like layer on the ground:
// pulled DEPTH_BIAS metres toward the camera so the terrain never cuts through it, and frayed at its
// outer edge (vertex alpha = the share of road tiles round each corner: 1 inside, 0.5 on an edge) by noise through alpha scissor, so it stays in the opaque pass.
render_mode cull_back;

uniform vec3 tint : source_color = vec3(0.47, 0.38, 0.27);
uniform float cobble = 0.0;  // 1 = paved: a stone-sett pattern on top of the noise
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D fray_tex : repeat_enable, filter_linear_mipmap;
uniform float depth_bias = 0.12;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += depth_bias;  // view space looks down -Z: +Z is toward the camera
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.11).r;
	vec3 col = tint * mix(0.82, 1.06, n);
	if (cobble > 0.5) {
		vec2 g = wpos.xz * vec2(2.2, 2.8);
		g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;
		vec2 f = abs(fract(g) - 0.5);
		float joint = smoothstep(0.40, 0.48, max(f.x, f.y));
		col *= mix(1.0, 0.72, joint);
	}
	ALBEDO = col;
	ROUGHNESS = 0.93;
	float fray = texture(fray_tex, wpos.xz * 0.35).r;
	ALPHA = COLOR.a * 1.25 + (fray - 0.5) * 0.9;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
