shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tile_map_tex : filter_nearest, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : source_color, filter_linear_mipmap, repeat_enable;

uniform vec3 tint_grass = vec3(0.42, 0.62, 0.32);
uniform vec3 tint_dry = vec3(0.56, 0.54, 0.35);
uniform vec3 tint_dirt = vec3(0.44, 0.34, 0.24);
uniform vec3 tint_sand = vec3(0.79, 0.72, 0.54);
uniform vec3 tint_shallow = vec3(0.58, 0.77, 0.83);
uniform vec3 tint_rock = vec3(0.47, 0.46, 0.44);
uniform vec3 tint_mud = vec3(0.35, 0.27, 0.20);
uniform vec3 tint_bare = vec3(0.44, 0.33, 0.23);
uniform vec3 tint_deep = vec3(0.22, 0.39, 0.56);
uniform vec3 tint_ash = vec3(0.34, 0.33, 0.33);

uniform float map_size = 240.0;
uniform float grid_enabled = 1.0;
uniform float grid_width = 0.03;
uniform float grid_fade = 25.0;
uniform vec3 focus_pos = vec3(0.0);

varying vec3 world_pos;
varying vec4 v_color;

vec3 sample_tile_texture(float id, vec2 uv) {
	if (id < 0.5) {
		return texture(grass_tex, uv).rgb * tint_grass;
	}
	if (id < 1.5) {
		return texture(grass_tex, uv).rgb * tint_dry;
	}
	if (id < 2.5) {
		return texture(dirt_tex, uv).rgb * tint_dirt;
	}
	if (id < 3.5) {
		return texture(sand_tex, uv).rgb * tint_sand;
	}
	if (id < 4.5) {
		return texture(sand_tex, uv).rgb * tint_shallow;
	}
	if (id < 5.5) {
		return texture(rock_tex, uv).rgb * tint_rock;
	}
	if (id < 6.5) {
		return texture(dirt_tex, uv).rgb * tint_mud;
	}
	if (id < 7.5) {
		return texture(dirt_tex, uv).rgb * tint_bare;
	}
	if (id < 8.5) {
		return texture(sand_tex, uv).rgb * tint_deep;
	}
	return texture(rock_tex, uv).rgb * tint_ash;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR;
}

void fragment() {
	vec2 map_uv = vec2((world_pos.x + map_size * 0.5) / map_size, (world_pos.z + map_size * 0.5) / map_size);
	map_uv = clamp(map_uv, vec2(0.0), vec2(0.9999));
	float tile_raw = texture(tile_map_tex, map_uv).r * 255.0;
	float tile_id = floor(tile_raw + 0.5);

	vec2 tile_uv = fract(world_pos.xz);
	vec3 albedo = sample_tile_texture(tile_id, tile_uv);
	float noise_mul = 0.90 + texture(noise_tex, world_pos.xz / 6.0).r * 0.20;
	albedo *= v_color.rgb * noise_mul;

	float gx = min(fract(world_pos.x), 1.0 - fract(world_pos.x));
	float gz = min(fract(world_pos.z), 1.0 - fract(world_pos.z));
	float line = 1.0 - smoothstep(0.0, grid_width, min(gx, gz));
	float focus_dist = distance(world_pos.xz, focus_pos.xz);
	float fade = 1.0 - smoothstep(grid_fade * 0.7, grid_fade, focus_dist);
	albedo *= (1.0 - 0.08 * grid_enabled * line * fade);

	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.02;
}
