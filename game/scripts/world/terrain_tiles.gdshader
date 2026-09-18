shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Durango-style ground: one continuous surface. Bands come from height (grass -> sand ->
// wet sand -> shallow bottom -> deep) with noise-perturbed edges; the tile map only
// carries overrides (bare/harvested, mud, dirt, rock, ash). No visible tiles unless the
// grid is switched on (build mode).
uniform sampler2D tile_map_tex : filter_nearest, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

uniform vec3 tint_grass = vec3(0.42, 0.62, 0.32);
uniform vec3 tint_dry = vec3(0.56, 0.54, 0.35);
uniform vec3 tint_dirt = vec3(0.44, 0.34, 0.24);
uniform vec3 tint_sand = vec3(0.79, 0.72, 0.54);
uniform vec3 tint_wet = vec3(0.55, 0.49, 0.38);
uniform vec3 tint_shallow = vec3(0.58, 0.77, 0.83);
uniform vec3 tint_rock = vec3(0.47, 0.46, 0.44);
uniform vec3 tint_mud = vec3(0.35, 0.27, 0.20);
uniform vec3 tint_bare = vec3(0.44, 0.33, 0.23);
uniform vec3 tint_deep = vec3(0.16, 0.24, 0.30);
uniform vec3 tint_ash = vec3(0.34, 0.33, 0.33);

uniform float map_size = 240.0;
uniform float tex_scale = 4.0;
uniform float h_grass = 0.55;
uniform float h_sand = 0.25;
uniform float h_wet = 0.15;
uniform float h_shallow = -0.05;
uniform float h_deep = -0.6;
uniform float grid_enabled = 0.0;
uniform float grid_width = 0.03;
uniform float grid_fade = 25.0;
uniform vec3 focus_pos = vec3(0.0);

varying vec3 world_pos;
varying vec4 v_color;
varying float v_slope;

// Two samples at different scales and a rotation, blended by low-frequency noise:
// kills the visible repeat of a single tiling texture.
vec3 tex2(sampler2D t, vec2 p) {
	vec2 uv1 = p / tex_scale;
	vec2 uv2 = (mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p) / (tex_scale * 1.83);
	float k = texture(noise_tex, p / 23.0).r;
	return mix(texture(t, uv1).rgb, texture(t, uv2).rgb, clamp(k * 1.4 - 0.2, 0.0, 1.0));
}

float tile_id_at(vec2 p) {
	vec2 map_uv = (p + vec2(map_size * 0.5)) / map_size;
	map_uv = clamp(map_uv, vec2(0.0), vec2(0.9999));
	return floor(texture(tile_map_tex, map_uv).r * 255.0 + 0.5);
}

// Override colour for a tile id, weight 1 when the id is an override type.
vec4 override_for(float id, vec3 dirt, vec3 rock) {
	if (id > 1.5 && id < 2.5) { return vec4(dirt * tint_dirt / tint_dirt, 1.0); }
	if (id > 5.5 && id < 6.5) { return vec4(dirt * (tint_mud / tint_dirt), 1.0); }
	if (id > 6.5 && id < 7.5) { return vec4(dirt * (tint_bare / tint_dirt), 1.0); }
	if (id > 4.5 && id < 5.5) { return vec4(rock, 1.0); }
	if (id > 8.5 && id < 9.5) { return vec4(rock * (tint_ash / tint_rock), 1.0); }
	return vec4(0.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR;
	vec3 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	v_slope = 1.0 - clamp(wn.y, 0.0, 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = texture(noise_tex, p / 9.0).r - 0.5;
	float h = world_pos.y + n * 0.35;

	vec3 grass = tex2(grass_tex, p) * tint_grass;
	vec3 dry = tex2(grass_tex, p) * tint_dry;
	vec3 sand = tex2(sand_tex, p) * tint_sand;
	vec3 wet = tex2(sand_tex, p) * tint_wet;
	vec3 dirt = tex2(dirt_tex, p) * tint_dirt;
	vec3 rock = tex2(rock_tex, p) * tint_rock;

	vec3 base = mix(wet, sand, smoothstep(h_wet - 0.08, h_wet + 0.08, h));
	base = mix(base, grass, smoothstep(h_sand, h_grass, h));
	base = mix(wet * 0.85, base, smoothstep(h_shallow - 0.10, h_shallow + 0.05, h));
	base = mix(tint_deep, base, smoothstep(h_deep - 0.3, h_deep + 0.2, h));
	float above_sand = smoothstep(h_sand, h_sand + 0.2, h);
	base = mix(base, dry, smoothstep(0.12, 0.30, v_slope) * above_sand);
	base = mix(base, rock, smoothstep(0.32, 0.50, v_slope));

	// Tile overrides (harvested bare tiles, mud, dirt, rock, ash) with a soft edge:
	// two lookups, the second displaced by noise, averaged.
	vec2 off = vec2(texture(noise_tex, p / 5.0).r - 0.5, texture(noise_tex, p / 5.0 + vec2(0.37)).r - 0.5) * 1.6;
	vec4 o0 = override_for(tile_id_at(p), dirt, rock);
	vec4 o1 = override_for(tile_id_at(p + off), dirt, rock);
	float ow = (o0.a + o1.a) * 0.5;
	vec3 ocol = (o0.rgb * o0.a + o1.rgb * o1.a) / max(o0.a + o1.a, 0.001);
	vec3 albedo = mix(base, ocol, ow);

	albedo *= 0.90 + texture(noise_tex, p / 12.0).r * 0.20;
	albedo *= v_color.rgb;

	float gx = min(fract(p.x), 1.0 - fract(p.x));
	float gz = min(fract(p.y), 1.0 - fract(p.y));
	float line = 1.0 - smoothstep(0.0, grid_width, min(gx, gz));
	float fade = 1.0 - smoothstep(grid_fade * 0.7, grid_fade, distance(p, focus_pos.xz));
	albedo *= (1.0 - 0.10 * grid_enabled * line * fade);

	ALBEDO = albedo;
	ROUGHNESS = mix(0.55, 1.0, smoothstep(h_wet - 0.05, h_wet + 0.12, h));
	SPECULAR = 0.05;
}
