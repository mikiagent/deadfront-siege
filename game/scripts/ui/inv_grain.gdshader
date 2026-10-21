// Weathered canvas / wood surface for the Durango bag family (spec 13 s2): broad mottling that
// drifts between olive and a dusty brown (the references' blurred, weathered panels), faint
// horizontal wear streaks, fine grain, sparse scratches and a soft vignette over a flat tint.
// Pixel-space noise from FRAGCOORD so every panel size reads the same; hash noise only, safe on
// gl_compatibility (no NoiseTexture2D: it loads asynchronously on the web).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.224, 0.224, 0.184, 1.0);
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float scale = 1.0;
// How far the broad blotches pull the tint toward olive and toward brown; 0 = one flat hue.
uniform float hue = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 px = FRAGCOORD.xy / max(scale, 0.01);
	float blotch = vnoise(px / 230.0) * 0.55 + vnoise(px / 95.0) * 0.30 + vnoise(px / 38.0) * 0.15;
	float fine = vnoise(px / 2.5) * 0.5 + vnoise(px / 9.0) * 0.5;
	float streak = vnoise(px * vec2(0.011, 0.31)) - 0.5;
	// Sparse scratches: thin bright streaks along a hashed angle per 90 px cell.
	vec2 cell = floor(px / 90.0);
	float ang = hash(cell) * 6.2831;
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 local = px - (cell + 0.5) * 90.0;
	float along = dot(local, dir);
	float across = abs(dot(local, vec2(-dir.y, dir.x)));
	float scratch = step(0.86, hash(cell + 7.0)) * (1.0 - smoothstep(0.0, 0.9, across)) * (1.0 - smoothstep(18.0, 34.0, abs(along)));
	vec3 olive = tint.rgb * vec3(1.04, 1.12, 0.78);
	vec3 brown = tint.rgb * vec3(1.10, 0.94, 0.88);
	vec3 base = mix(tint.rgb, olive, smoothstep(0.30, 0.85, vnoise(px / 310.0 + 17.0)) * 0.85 * hue);
	base = mix(base, brown, smoothstep(0.40, 0.90, vnoise(px / 190.0 + 41.0)) * 0.75 * hue);
	float luma = 1.0 + ((blotch - 0.5) * 0.44 + (fine - 0.5) * 0.10 + streak * 0.06 + scratch * 0.10) * strength;
	vec2 c = UV - 0.5;
	float vig = 1.0 - smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.2))) * 0.28 * strength;
	COLOR = vec4(base * luma * vig, tint.a * COLOR.a);
}
