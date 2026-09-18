shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_lambert, specular_disabled;

// Rough circular dirt patch under structures and trees (Durango reference): the edge is
// eroded by noise so it never reads as a perfect circle or a tile.
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.62, 0.48, 0.34);
uniform vec4 modulate : source_color = vec4(1.0);
uniform float radius = 2.0;
uniform float edge = 0.5;

varying vec3 world_pos;
varying vec2 local_xz;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_xz = VERTEX.xz;
}

void fragment() {
	float r = length(local_xz) / radius;
	float n = texture(noise_tex, world_pos.xz / 2.5).r;
	float a = 1.0 - smoothstep(1.0 - edge, 1.0, r + (n - 0.5) * 0.5);
	vec3 col = texture(dirt_tex, world_pos.xz / 3.0).rgb * tint * (0.85 + n * 0.3);
	ALBEDO = col * modulate.rgb;
	ALPHA = a * modulate.a;
	ROUGHNESS = 1.0;
}
