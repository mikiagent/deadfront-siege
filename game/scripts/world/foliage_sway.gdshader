shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform float sway_amplitude = 0.06;
uniform float sway_speed = 1.6;
uniform float gust_speed = 0.55;
uniform vec3 tint : source_color = vec3(0.40, 0.56, 0.26);
// Biome knobs (BiomeMaterial); defaults reproduce the pre-biome look.
uniform vec3 tip_tint : source_color = vec3(1.0);
uniform float root_dark = 0.75;
uniform float tip_gain = 0.35;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float top = clamp(VERTEX.y, 0.0, 1.0);
	float wave = sin(TIME * sway_speed + world.x * 0.35 + world.z * 0.2);
	float gust = sin(TIME * gust_speed + world.x * 0.08 + world.z * 0.05) * 0.5;
	float offset = (wave + gust) * sway_amplitude * top;
	VERTEX.x += offset;
	VERTEX.z += offset * 0.35;
}

void fragment() {
	// Quaternius grass carries no vertex colour; tint it and darken toward the roots.
	float y = clamp(UV.y, 0.0, 1.0);
	ALBEDO = tint * mix(vec3(1.0), tip_tint, y) * (root_dark + tip_gain * y);
	ROUGHNESS = 1.0;
}
