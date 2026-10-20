// See-through test shared by every occluder shader (scripts/world/occlusion.gd sets the globals).
// Works in view space, so one formula serves the orthographic iso camera and any perspective one.

// xyz: survivor chest in world space; w: sight-line radius in metres (0 = nothing to keep visible).
global uniform vec4 occl_target;
// xyz: the main camera's forward vector; only passes rendered from that camera fade.
global uniform vec4 occl_view;

// 4x4 ordered dither in [0, 15/16]: a screen-door fade that needs no blending or sorting.
float occl_bayer4(vec2 p) {
	vec2 a = floor(p);
	vec2 b = floor(p * 0.5);
	return fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + fract(a.x * 0.5 + a.y * a.y * 0.75);
}

// 0..1: how much of this fragment to drop because it sits between the camera and the survivor.
float occl_between(vec3 v_view, mat4 view, mat4 inv_view, mat4 proj) {
	// Shadow and probe cameras look another way, so trees keep their whole shadow.
	if (occl_target.w <= 0.0 || dot(-inv_view[2].xyz, occl_view.xyz) < 0.999) {
		return 0.0;
	}
	vec3 s = (view * vec4(occl_target.xyz, 1.0)).xyz;
	vec3 dir = proj[3][3] > 0.5 ? vec3(0.0, 0.0, -1.0) : normalize(s);
	vec3 rel = v_view - s;
	float ahead = -dot(rel, dir);
	float off = length(rel + dir * ahead);
	return smoothstep(occl_target.w, occl_target.w * 0.5, off) * smoothstep(0.3, 1.5, ahead);
}
