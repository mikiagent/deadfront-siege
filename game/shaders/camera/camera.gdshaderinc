// The follow camera, as global shader parameters (declared in project.godot [shader_globals];
// scripts/camera/iso_camera.gd sets them every frame). One contract for every shader that has to
// line up with the camera: tall props here (occluder_standard), CARD2D's flat cards next.
//
// camera_focus       world point the camera looks at (its smoothed follow point, survivor height)
// camera_pitch_deg   the camera's Euler x in degrees; negative looks down (-39 measured from Durango)
// camera_yaw_deg     the camera's Euler y in degrees (45: the build grid's diagonal)
// camera_distance    camera to focus along the view, metres (perspective: from the zoom)
// parallax_strength  extra sideways lean of tall props, on top of the lean the lens gives them:
//                    metres of shift per metre of height per metre the prop stands right or left of
//                    the focus (along the camera's right axis on the ground). 0 = off (ortho camera).
// tall_fade_height   tall props dither out above this height over their base, metres (0 = off). It
//                    drops as the camera zooms in, so crowns that would fill the close view fade.
// Apply both only in the main camera's pass (camera_is_main_pass), never in shadow passes: a real
// lens moves nothing on the ground, so a prop's shadow stays where its 3D shape puts it.
global uniform vec3 camera_focus;
global uniform float camera_pitch_deg;
global uniform float camera_yaw_deg;
global uniform float camera_distance;
global uniform float parallax_strength;
global uniform float tall_fade_height;

// Where the main camera looks (-Z of Basis.from_euler(pitch, yaw, 0)).
vec3 camera_main_forward() {
	float p = radians(camera_pitch_deg);
	float y = radians(camera_yaw_deg);
	return vec3(-cos(p) * sin(y), sin(p), -cos(p) * cos(y));
}

// The main camera's screen-right axis (it never rolls, so it lies on the ground plane).
vec3 camera_main_right() {
	float y = radians(camera_yaw_deg);
	return vec3(cos(y), 0.0, -sin(y));
}

// True in the pass rendered from the main camera (shadow passes look along their light).
bool camera_is_main_pass(mat4 inv_view) {
	return dot(-inv_view[2].xyz, camera_main_forward()) > 0.9995;
}

// World-space shift of a point `h` metres above a prop whose base is `origin`.
vec3 camera_parallax_world(vec3 origin, float h) {
	vec3 r = camera_main_right();
	float side = dot(origin - camera_focus, r);
	return r * (parallax_strength * max(h, 0.0) * side);
}

// Share of pixels to drop (0..1) at `h` metres over the prop's base: a 2 m dither band.
float camera_tall_fade(float h) {
	if (tall_fade_height <= 0.0) {
		return 0.0;
	}
	return smoothstep(tall_fade_height, tall_fade_height + 2.0, h);
}
