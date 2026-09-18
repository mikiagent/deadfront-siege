shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_never, diffuse_lambert, specular_schlick_ggx;

// Sea plane: colour and opacity from the water depth over the terrain heightmap,
// foam where the water is shallow plus scrolling streaks, gentle ripples.
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float map_size = 240.0;
uniform float height_res = 129.0;
uniform float water_y = -0.05;
uniform vec3 shallow_col : source_color = vec3(0.55, 0.80, 0.82);
uniform vec3 deep_col : source_color = vec3(0.14, 0.32, 0.46);
uniform vec3 foam_col : source_color = vec3(0.93, 0.96, 0.96);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz + vec2(map_size * 0.5)) / map_size;
	float ground = -3.0;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		vec2 tuv = uv * (height_res - 1.0) / height_res + vec2(0.5 / height_res);
		ground = texture(height_tex, tuv).r;
	}
	float depth = max(0.0, water_y - ground);
	float d = clamp(depth / 1.6, 0.0, 1.0);
	vec3 col = mix(shallow_col, deep_col, d);
	float alpha = mix(0.22, 0.90, smoothstep(0.0, 1.3, depth));

	float t = TIME;
	float f1 = texture(noise_tex, world_pos.xz / 7.0 + vec2(t * 0.05, t * 0.03)).r;
	float f2 = texture(noise_tex, world_pos.xz / 3.5 - vec2(t * 0.04, -t * 0.06)).r;
	// Foam lives in a band just past the waterline, in streaks; open water only gets faint ridges.
	float shore = smoothstep(0.0, 0.10, depth) * (1.0 - smoothstep(0.22, 0.75, depth));
	float ridge = smoothstep(0.60, 0.84, f1 * 0.6 + f2 * 0.6);
	float foam = clamp(shore * (0.10 + ridge * 0.75) + ridge * 0.10 * (1.0 - d), 0.0, 1.0);
	col = mix(col, foam_col, foam);
	alpha = max(alpha, foam * 0.92);
	if (depth <= 0.0) { alpha = 0.0; }

	vec3 nrm = normalize(vec3((f1 - 0.5) * 0.18, 1.0, (f2 - 0.5) * 0.18));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ALBEDO = col;
	ALPHA = alpha;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
}
