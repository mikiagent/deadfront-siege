// Weathered canvas / wood surface for the Durango bag family (spec 13 s2): broad mottling,
// fine grain, sparse scratches and a soft vignette over a flat tint. Pixel-space noise from
// FRAGCOORD so every panel size reads the same; hash noise only, safe on gl_compatibility.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.224, 0.224, 0.184, 1.0);
uniform float strength = 1.0;
uniform float seed = 0.0;
uniform float scale = 1.0;

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
	float blotch = vnoise(px / 160.0) * 0.6 + vnoise(px / 70.0) * 0.4;
	float fine = vnoise(px / 2.5) * 0.5 + vnoise(px / 9.0) * 0.5;
	// Sparse scratches: thin bright streaks along a hashed angle per 90 px cell.
	vec2 cell = floor(px / 90.0);
	float ang = hash(cell) * 6.2831;
	vec2 dir = vec2(cos(ang), sin(ang));
	vec2 local = px - (cell + 0.5) * 90.0;
	float along = dot(local, dir);
	float across = abs(dot(local, vec2(-dir.y, dir.x)));
	float scratch = step(0.86, hash(cell + 7.0)) * (1.0 - smoothstep(0.0, 0.9, across)) * (1.0 - smoothstep(18.0, 34.0, abs(along)));
	float luma = 1.0 + ((blotch - 0.5) * 0.30 + (fine - 0.5) * 0.10 + scratch * 0.10) * strength;
	vec2 c = UV - 0.5;
	float vig = 1.0 - smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.2))) * 0.28 * strength;
	COLOR = vec4(tint.rgb * luma * vig, tint.a * COLOR.a);
}
