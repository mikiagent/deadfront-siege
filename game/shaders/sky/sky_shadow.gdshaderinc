// Sky shadows (SKYSHADOWS): drifting cloud cover and the soft silhouettes of pteranodons gliding
// overhead, as a darkening factor on the ground. No flyer and no cloud is ever drawn; only what they
// throw on the terrain, grass and cards. scripts/world/sky_shadows.gd writes these globals every frame
// (declared in project.godot [shader_globals]); with every strength 0 (the default, quality off, night)
// sky_shade() returns 1.0 after one texture-free branch.
//
// sky_cloud_tex   seamless cloud noise (R), one tile per SKY_CLOUD_TILE_M of ground
// sky_cloud       xy: wind offset in metres, z: coverage threshold (noise above it is cloud),
//                 w: darkening at full cover (0 = off)
// sky_flyer_0..2  xy: the shadow's centre on the ground (m), z: heading (rad, 0 = +x), w: darkening
// sky_flyer_wing  xyz: wing span scale per flyer (a flap folds the wings in), w: unused
global uniform sampler2D sky_cloud_tex;
global uniform vec4 sky_cloud;
global uniform vec4 sky_flyer_0;
global uniform vec4 sky_flyer_1;
global uniform vec4 sky_flyer_2;
global uniform vec4 sky_flyer_wing;

const float SKY_CLOUD_TILE_M = 240.0;
const float SKY_CLOUD_SOFT = 0.08;
// Penumbra half-width of a flyer's shadow in metres (60 m up, the sun's disc spreads it about 0.5 m).
const float SKY_FLYER_SOFT = 0.3;

// Signed distance (metres, approximate) to a pteranodon seen from below, ~6 m span at s = 1.
// q: x to the right wing, y forward along the heading.
float sky_ptero_d(vec2 q, float s) {
	float half_span = 3.0 * s;
	float ax = abs(q.x);
	float t = clamp(ax / half_span, 0.0, 1.0);
	// Long narrow wings: the leading edge sweeps back toward a pointed tip.
	float lead = 0.45 - 0.9 * t * t;
	float chord = mix(1.6, 0.2, t);
	float wing = max(max(q.y - lead, lead - chord - q.y), ax - half_span);
	float body = (length(q / vec2(0.3, 1.0)) - 1.0) * 0.3;
	// Head and the long beak ahead of the body (the crest lies over the neck: no extra silhouette).
	float beak = length(vec2(q.x, q.y - clamp(q.y, 0.7, 2.0))) - 0.15;
	return min(min(wing, body), beak);
}

float sky_flyer(vec2 p, vec4 f, float span) {
	if (f.w <= 0.0) {
		return 0.0;
	}
	vec2 d = p - f.xy;
	if (dot(d, d) > 16.0) {
		return 0.0;
	}
	float c = cos(f.z);
	float s = sin(f.z);
	// forward = (c, s) on the ground; right = (s, -c).
	vec2 q = vec2(d.x * s - d.y * c, d.x * c + d.y * s);
	return f.w * (1.0 - smoothstep(-SKY_FLYER_SOFT, SKY_FLYER_SOFT, sky_ptero_d(q, span)));
}

// 1.0 in open sun; lower under a cloud or a flyer. p: world xz.
float sky_shade(vec2 p) {
	float k = 0.0;
	if (sky_cloud.w > 0.0) {
		float n = textureLod(sky_cloud_tex, fract((p + sky_cloud.xy) / SKY_CLOUD_TILE_M), 0.0).r;
		k = sky_cloud.w * smoothstep(sky_cloud.z, sky_cloud.z + SKY_CLOUD_SOFT, n);
	}
	k = max(k, sky_flyer(p, sky_flyer_0, sky_flyer_wing.x));
	k = max(k, sky_flyer(p, sky_flyer_1, sky_flyer_wing.y));
	k = max(k, sky_flyer(p, sky_flyer_2, sky_flyer_wing.z));
	return 1.0 - k;
}
