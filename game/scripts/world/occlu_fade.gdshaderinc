// See-through fade shared by every occluder shader (scripts/world/occlusion.gd sets the values).
// A prop fades as a whole object: an ordered dither drops the same share of its pixels everywhere on
// its silhouette, so it still reads as a tree or a roof, never as a hole. The CPU decides which props
// are in the way and steps their fades; the shader only looks its own value up.
//
// The dither is screen-space (an ordered 4x4 pattern in FRAGCOORD), which is what makes a stack safe:
// two props at the same share discard the SAME pixels, so the survivor behind them shows through that
// share once, not at 1-(1-share)^2. And over the survivor's own silhouette every prop, trunks and
// roofs included, discards at least OCCL_COVER_DROP, so they always show through what covers them.
//
// Kept under scripts/world/ because that is this job's scope; occlu_occluder_standard.gdshaderinc is
// the material body every derived prop shader includes, and it includes this file.

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
// The survivor's silhouette on screen: xy the body's centre in pixels (origin top left), zw its half
// width and half height there. w = 0 when there is no survivor, which turns the rule off.
global uniform vec4 occl_body;
// Share of its pixels every prop drops over the survivor's body: 11 of the 16 dither cells, so 11/16
// (69 %) of the survivor shows through whatever covers them (the owner's gate is 0.6). Occlusion's
// BODY_DROP must match this number; t_occlude2 checks the two agree.
const float OCCL_COVER_DROP = 0.6875;
// Share of this node's pixels to drop, 0..1 (MeshInstance3D props, roofs). Per node, so one shared
// material serves every prop while each fades on its own.
instance uniform float occl_fade = 0.0;
// Model height (the mesh's own units) below which a prop never fades: a tree's trunk stays solid while
// its crown dithers, so the tree still reads whole (spec 21). 0 fades the whole model (bushes, sheds,
// roofs). Per node: a shared material serves every prop, and the trunk is a property of one model.
instance uniform float occl_trunk = 0.0;

// Varyings may only be assigned in the shader's own vertex(), so the including shader sets these:
//   occl_on = occl_camera_on(INV_VIEW_MATRIX);
//   occl_drop = occl_drop_of(MODEL_MATRIX, INV_VIEW_MATRIX); occl_y = the vertex's model height;
// occl_drop: the share of this vertex's pixels to drop. occl_y: its height in the model's own units.
// occl_on: 1 only in the main camera's pass, so the shadow and depth passes keep the prop whole.
varying float occl_drop;
varying float occl_y;
varying float occl_on;

// 4x4 ordered dither in [0, 15/16]. At the "between" share (9/16) it is a pixel checkerboard plus one
// cell in 16: an even half-tone, not a coarse screen.
float occl_bayer4(vec2 p) {
	vec2 a = floor(p);
	vec2 b = floor(p * 0.5);
	return fract(b.x * 0.5 + b.y * b.y * 0.75) * 0.25 + fract(a.x * 0.5 + a.y * a.y * 0.75);
}

float occl_match(vec4 slot, vec3 o, float f) {
	vec3 d = slot.xyz - o;
	return dot(d, d) < 1e-4 ? max(f, slot.w) : f;
}

// 1 when this pass is the main camera's: the shadow and depth passes see the prop from another
// direction, and a dither pattern on the ground under a faded tree is not wanted.
float occl_camera_on(mat4 inv_view) {
	return dot(-inv_view[2].xyz, occl_view.xyz) < 0.999 ? 0.0 : 1.0;
}

// Called in vertex(): the share of pixels this instance drops (0 = solid).
float occl_drop_of(mat4 model, mat4 inv_view) {
	if (occl_camera_on(inv_view) < 0.5) {
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

// Called last in fragment(), so every texture read before it keeps its derivatives: drop this pixel.
// Nothing below the trunk line is dropped, so a tree's trunk stays solid through any fade, and the
// survivor's own silhouette always drops at least the cover share, so they show through what covers
// them however many props stand on the line (all of them discard the same pixels there).
void occl_cut(vec2 px) {
	if (occl_on < 0.5) {
		return;
	}
	// A prop that is not fading draws SOLID, over the survivor's silhouette included: the CPU fades
	// only props between the camera and the survivor, so a tree BEHIND her keeps occl_drop 0 and must
	// not open up just because her crown-sized silhouette is under it on screen (owner bug 2026-10-28).
	// Every prop that does fade (occl_drop > 0) covers her, so the cover rule below still applies.
	if (occl_drop <= 0.0) {
		return;
	}
	bool trunk = occl_y < occl_trunk;
	vec2 q = (px - occl_body.xy) / max(occl_body.zw, vec2(0.001));
	if (occl_body.w > 0.0 && dot(q, q) < 1.0) {
		if (max(trunk ? 0.0 : occl_drop, OCCL_COVER_DROP) > occl_bayer4(px)) {
			discard;
		}
		return;
	}
	if (trunk) {
		return;
	}
	if (occl_drop > occl_bayer4(px)) {
		discard;
	}
}
