// See-through fade shared by every occluder shader (scripts/world/occlusion.gd sets the values).
// A prop fades as a whole object: an ordered dither drops the same share of its pixels everywhere
// on its silhouette, so it still reads as a tree or a roof, never as a hole. The CPU decides which
// props are in the way and steps their fades; the shader only looks its own value up.

// xyz: the main camera's forward vector (only passes rendered from that camera fade, so a faded
// prop keeps its whole shadow); w: slots below in use (0 skips the lookup).
global uniform vec4 occl_view;
// Fading MultiMesh instances: xyz the instance's world origin, w the share of its pixels to drop.
// One MultiMesh draws every instance with one material, so each finds itself by origin.
global uniform vec4 occl_slot_0;
global uniform vec4 occl_slot_1;
global uniform vec4 occl_slot_2;
global uniform vec4 occl_slot_3;
global uniform vec4 occl_slot_4;
global uniform vec4 occl_slot_5;
global uniform vec4 occl_slot_6;
global uniform vec4 occl_slot_7;
// Share of this node's pixels to drop, 0..1 (MeshInstance3D props, roofs). Per node, so one shared
// material serves every prop while each fades on its own.
instance uniform float occl_fade = 0.0;

varying float occl_drop;

// 4x4 ordered dither in [0, 15/16]. At the "between" share (9/16) it is a pixel checkerboard plus
// one cell in 16: an even half-tone, not a coarse screen.
float occl_bayer4(vec2 p) {
	vec2 a = floor(p);
	vec2 b = floor(p * 0.5);
	return fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float occl_match(vec4 slot, vec3 o, float f) {
	vec3 d = slot.xyz - o;
	return dot(d, d) < 1e-4 ? max(f, slot.w) : f;
}

// Called in vertex(): the share of pixels this instance drops (0 = solid).
float occl_drop_of(mat4 model, mat4 inv_view) {
	if (dot(-inv_view[2].xyz, occl_view.xyz) < 0.999) {
		return 0.0;
	}
	float f = occl_fade;
	if (occl_view.w > 0.5) {
		vec3 o = model[3].xyz;
		f = occl_match(occl_slot_0, o, f);
		f = occl_match(occl_slot_1, o, f);
		f = occl_match(occl_slot_2, o, f);
		f = occl_match(occl_slot_3, o, f);
		f = occl_match(occl_slot_4, o, f);
		f = occl_match(occl_slot_5, o, f);
		f = occl_match(occl_slot_6, o, f);
		f = occl_match(occl_slot_7, o, f);
	}
	return f;
}
