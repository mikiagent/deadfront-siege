shader_type canvas_item;
// WEATHER heat shimmer (WeatherFx, high quality only): the scene below the HUD wobbles in rising waves,
// strongest low on the screen where the ground is, and takes a bleached, warm desert grade.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float heat = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	float w = sin(uv.y * 90.0 - t * 4.0 + sin(uv.x * 30.0 + t * 1.3) * 2.0) + 0.6 * sin(uv.y * 53.0 - t * 2.7 + uv.x * 17.0);
	float band = 0.35 + 0.65 * smoothstep(0.15, 0.95, uv.y);
	vec2 off = vec2(w * 0.0018, w * 0.0009) * heat * band;
	vec3 c = texture(screen_tex, uv + off).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.1 * heat);
	c *= mix(vec3(1.0), vec3(1.05, 1.0, 0.9), heat);
	COLOR = vec4(c, 1.0);
}
