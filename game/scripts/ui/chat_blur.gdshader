shader_type canvas_item;
// The chat screen's backdrop (spec 20 reference): the world shows through, soft and a little dim.
// shortcut: 25 taps of the screen texture every frame; a one-off snapshot would cost less on a phone
// if this ever shows up in a frame budget.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float spread_px = 5.0;
uniform vec4 dim : source_color = vec4(0.05, 0.07, 0.07, 0.22);

void fragment() {
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 o = vec2(float(x), float(y));
			float w = exp(-dot(o, o) / 4.5);
			acc += textureLod(screen, SCREEN_UV + o * SCREEN_PIXEL_SIZE * spread_px, 2.5).rgb * w;
			wsum += w;
		}
	}
	COLOR = vec4(mix(acc / wsum, dim.rgb, dim.a), 1.0);
}
