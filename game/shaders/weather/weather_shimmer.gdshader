shader_type canvas_item;
// WEATHER heat shimmer (WeatherFx, high quality only): a vignette of rising heat waves. The scene wobbles
// hard near the screen's border and hardly at all in the middle, and only the border takes the bleached,
// warm grade. The mask is a rounded rect measured in pixels against the short side, so the band is the
// same share of the screen at 1600x900 and at a phone's 844x390.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float heat = 0.0;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * res;
	float s = min(res.x, res.y);
	// Rounded-rect distance in from the border (px), so the corners bend round instead of meeting square.
	float r = s * 0.35;
	vec2 q = abs(p - res * 0.5) - (res * 0.5 - r);
	float inside = r - length(max(q, 0.0)) - min(max(q.x, q.y), 0.0);
	float m = 1.0 - smoothstep(0.0, s * 0.3, inside);
	m *= m;
	// Waves in short-side units, so they keep their size on every aspect.
	vec2 u = p / s;
	float t = TIME;
	float w = sin(u.y * 70.0 - t * 4.0 + sin(u.x * 24.0 + t * 1.3) * 2.0) + 0.6 * sin(u.y * 41.0 - t * 2.7 + u.x * 13.0);
	vec2 off = vec2(w, w * 0.5) * s * 0.006 * heat * m * SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV + off).rgb;
	float g = heat * m;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), 0.12 * g);
	c *= mix(vec3(1.0), vec3(1.06, 1.0, 0.88), g);
	COLOR = vec4(c, 1.0);
}
