shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// The level-up light (LevelUpFx): one additive shader for its four shapes, so it reads in
// gl_compatibility, where post glow is weak. 0 pillar: an open cylinder, a tube of light bright at
// the ground, rising to `rise`. 1 ring: a flat ring on the ground with a faint fill.
// 2 rays: a camera-facing burst of `rays` rays and a halo, turned by `spin`. 3 glow: a soft
// camera-facing disc. `push` moves a camera-facing quad along the view axis: + behind the
// survivor (her body hides its core), - in front of her (the flash).
uniform int shape = 0;
uniform vec3 tint : source_color = vec3(1.0, 0.78, 0.3);
uniform float energy = 2.0;
uniform float fade = 1.0;
uniform float rise = 1.0;
uniform float height = 4.0;
uniform float spin = 0.0;
uniform float rays = 14.0;
uniform float push = 0.0;

varying float h01;

void vertex() {
	h01 = VERTEX.y / max(height, 0.001) + 0.5;
	if (shape >= 2) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX[3].z -= push;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float a = 0.0;
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	if (shape == 0) {
		float h = clamp(h01, 0.0, 1.0);
		// A tube of light: soft at the silhouette, brightest just inside it, dimmer across the middle
		// so the survivor stays readable inside it.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		float soft = smoothstep(0.0, 0.3, facing) * mix(1.0, 0.4, facing);
		float up = pow(1.0 - h, 1.1);
		float front = 1.0 - smoothstep(rise - 0.16, rise, h);
		float edge = smoothstep(0.14, 0.0, abs(h - (rise - 0.05))) * step(rise, 0.995);
		float streak = 0.72 + 0.28 * sin(UV.x * 50.2655 + h * 6.0) * sin(h * 15.0 - TIME * 7.0);
		a = soft * (up * streak + edge * 0.7) * front;
	} else if (shape == 1) {
		float ring = smoothstep(0.78, 0.94, r) * (1.0 - smoothstep(0.94, 1.0, r));
		a = ring + 0.07 * (1.0 - smoothstep(0.2, 0.95, r));
	} else if (shape == 2) {
		float ang = atan(c.y, c.x) + spin;
		float m = rays * 0.5;
		float beams = pow(abs(cos(ang * m)), 28.0) + 0.45 * pow(abs(cos(ang * m + 0.9)), 70.0);
		float halo = pow(max(0.0, 1.0 - r), 3.0);
		a = beams * (1.0 - smoothstep(0.15, 1.0, r)) * smoothstep(0.04, 0.2, r) + halo * 0.85;
	} else {
		a = pow(max(0.0, 1.0 - r), 2.2);
	}
	ALBEDO = tint * energy;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
