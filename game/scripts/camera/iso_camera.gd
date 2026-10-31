class_name IsoCamera
extends Camera3D
## The follow camera, matched to Durango: Wild Lands from the owner's screenshots (method and
## numbers: docs/orchestration/reports/claude-mmo-camera.md). Durango draws with a long-lens
## PERSPECTIVE camera: pitch 38.7 deg down, a vertical field of view of about 4.3 deg, yawed 45 deg
## to the build grid. At that lens the ground recedes gently (the top of a 16:9 screen ~9 % smaller
## than the bottom), tall things fan out a few degrees towards the screen edges, and a crown slides
## against the ground as the camera moves past it (the parallax the owner pointed at).
## `size` stays the zoom in both projections: metres of view height at the focus. In perspective the
## camera stands distance_for(size) back, so labs, the wheel and pinch zoom keep setting size.
## ISOCAM: below ISO_MIN_SIZE the zoom keeps going, and the camera tilts down to CLOSE_PITCH_DEG with a
## CLOSE_FOV_DEG lens: behind and a little above the survivor (yaw stays fixed). See close_t().
## Each frame it publishes the camera as global shader parameters (shaders/camera/camera.gdshaderinc)
## for tall props and CARD2D cards, and keeps a tight near/far around the focus (WorldLighting fits
## the shadow splits to it).
## --cam-ortho (dev, for comparison): the old orthographic iso camera, pitch -35.264, 40 m back,
## zoom 10-28 m, no parallax. --cam-size=<m> starts at that zoom.

## Measured from the references (a pinhole fit to the straight ground lines of three screenshots: the
## placing grid, two domain borders): pitch 38.55-38.85 deg; 38 deg from a fire pit's ellipse. Euler x,
## so negative looks down.
const PITCH_DEG := -38.7
## World axes: north = -Z, south = +Z, east = +X, west = -X. ISOCAM (owner 2026-10-30, overriding
## NORTHUP's yaw 0: "i like the isometric look better ... north changes and the perspective is back to
## durango isometric"): the camera looks north-west along the grid diagonal, so the grid-aligned town
## reads as diamonds, screen up = north-west, screen right = north-east, and a building's south-east
## corner is the one nearest the camera. --cam-yaw=0 brings north-up back for an A/B.
const YAW_DEG := 45.0
## Vertical field of view (keep_aspect KEEP_HEIGHT): 3.7-4.6 deg from how the parallel ground lines
## converge (an orthographic camera fits those lines 10-25x worse).
const FOV_DEG := 4.3
const PROJECTION: Camera3D.ProjectionType = Camera3D.PROJECTION_PERSPECTIVE
## The old camera, behind --cam-ortho.
const ORTHO_PITCH_DEG := -35.264
const ORTHO_DISTANCE := 40.0
const ORTHO_MIN_SIZE := 10.0
const ORTHO_MAX_SIZE := 28.0
const ORTHO_DEFAULT_SIZE := 15.0
## Zoom, metres of view height at the focus. Durango's survivor stands 10-15 % of the screen height in its
## usual views (median 13 %) and 23-26 % zoomed right in; ours (~1.8 m on the image plane at this pitch)
## is 13 % at 14 m, 26 % at 7 m and 10 % at 18 m. The old camera's game view was 17 m at 35.3 deg (11 %).
## ISOCAM: MIN_SIZE is now the close end; the iso range is ISO_MIN_SIZE..MAX_SIZE, unchanged.
const ISO_MIN_SIZE := 7.0
const MIN_SIZE := 3.5
const DEFAULT_SIZE := 14.0
const MAX_SIZE := 18.0
## Labs zoom out to ~30 m for overview shots; cull ranges cover that (cull_range).
const LAB_MAX_SIZE := 30.0
## Extra sideways lean of tall props as a multiple of the lean the lens gives them (published as
## parallax_strength). Durango's jungle trees stand 15-20 m and ours 7-11 m, so the lens alone slides our
## crowns half as far: doubling it gives a 10 m crown the slide of a 20 m one.
# ASSUMPTION: gain 1.0 (Durango's own trees show no exaggeration; 0.0 is the lens alone).
const PARALLAX_GAIN := 1.0
## Tall props dither out above this many metres per metre of zoom (published as tall_fade_height).
## Owner (spec 25): "the tall trees fade out of zoom". At the default zoom (14 m) nothing of ours fades
## (the fade starts at 16.8 m); zoomed in to 7 m, crowns above 8.4 m fade.
# ASSUMPTION: 1.2 m per metre of zoom, the reading of the owner's words above.
const TALL_FADE_PER_SIZE := 1.2
## ASSUMPTION: selection owns 35 % of the frame, capped at 6 m so the survivor stays readable.
const SELECTION_BIAS := 0.35
const SELECTION_MAX_SHIFT_M := 6.0
## ISOCAM, the close end of the zoom (owner: "go more horizontal so the camera looks like it's behind the
## player and slightly up, we can zoom out and get isometric"). Between ISO_MIN_SIZE and MIN_SIZE the
## pitch, the lens and a lift of the focus to the survivor's chest blend by close_t() (a smoothstep of
## the zoom), so six wheel notches go from the iso view to an over-the-shoulder one. The top edge of the
## close view sits CLOSE_PITCH + CLOSE_FOV/2 = 2 deg under the horizon: no sky band. Past that pitch,
## ground up to CLOSE_FAR_M stays in view and the scaled fog (WorldLighting, 40 m / distance) hides the end.
# ASSUMPTION: pitch -22, FOV 40, lift 1.0 m, far 260 m, smoothstep over 7 -> 3.5 m (open question in
# docs/vision/WildLandsMMO_Open_Questions.md, ISOCAM).
const CLOSE_PITCH_DEG := -22.0
const CLOSE_FOV_DEG := 40.0
const CLOSE_LIFT_M := 1.0
const CLOSE_FAR_M := 260.0
## Shadows and the near band stop this far past the focus (ground_half_depth): a low camera sees the
## ground to the horizon, and one shadow map stretched over all of it would blur the survivor's own.
const SHADOW_DEPTH_MAX := 40.0

## The dev flag, read once: every IsoCamera and every static helper agree on the projection.
static var ortho: bool = "--cam-ortho" in OS.get_cmdline_user_args()
## What the current camera last published (Occlusion bends its sight test by the same lean).
static var focus := Vector3.ZERO
static var parallax := 0.0
static var right := Vector3.RIGHT

@export var target_path: NodePath
## Camera to focus along the view, metres. Perspective: distance_for(size), every frame. Ortho: a lab may set it.
@export var distance: float = ORTHO_DISTANCE
@export var follow_lerp: float = 8.0
@export var min_size: float = MIN_SIZE
@export var max_size: float = MAX_SIZE
@export var default_size: float = DEFAULT_SIZE

var _target: Node3D
## The zoom _apply_zoom last posed the camera for (pitch and lens follow the zoom: close_t).
var _posed_size := -1.0
var _lift := Vector3.ZERO
## 0..1 impact shake; decays linearly, offset grows with trauma^2 so small knocks stay subtle.
var trauma: float = 0.0
var _shake_t: float = 0.0
## WEATHER's camera offset this frame (thunder, heat sway, shivers), metres; WeatherFx writes it.
var weather_offset := Vector2.ZERO
## Upper bound on the weather offset, metres (rules.json weather.shake_m.max is the tuned value under it).
const WEATHER_OFFSET_MAX := 0.2
## Accessibility: no camera shake at all, combat or weather (--reduce-shake).
static var reduce_shake: bool = "--reduce-shake" in OS.get_cmdline_user_args()
## 3D A/B (dev): --cam-fov=<deg> and --cam-pitch=<deg> try a wider lens or another tilt in place of
## FOV_DEG and PITCH_DEG; the camera still stands distance_for(size) back, so zoom keeps meaning metres.
static var fov_deg: float = _arg_float("--cam-fov=", FOV_DEG)
static var pitch_override: float = _arg_float("--cam-pitch=", PITCH_DEG)
## ISOCAM A/B (dev): --cam-yaw=0 is NORTHUP's north-up camera; --cam-notilt keeps the zoom inside the
## iso range (no close, tilted end).
static var yaw_deg: float = _arg_float("--cam-yaw=", YAW_DEG)
static var no_tilt: bool = "--cam-notilt" in OS.get_cmdline_user_args()

static func _arg_float(prefix: String, fallback: float) -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return float(a.substr(prefix.length()))
	return fallback

## The view angle of the camera this run uses at the iso zoom, in degrees (Euler x; negative looks down).
static func pitch_deg() -> float:
	return ORTHO_PITCH_DEG if ortho else pitch_override

## 0 across the iso range, 1 at the closest zoom: how far the camera has tilted toward the survivor.
static func close_t(view_height: float) -> float:
	if ortho:
		return 0.0
	return smoothstep(0.0, 1.0, clampf((ISO_MIN_SIZE - view_height) / (ISO_MIN_SIZE - MIN_SIZE), 0.0, 1.0))

static func pitch_for(view_height: float) -> float:
	return lerpf(pitch_deg(), CLOSE_PITCH_DEG, close_t(view_height))

static func fov_for(view_height: float) -> float:
	return lerpf(fov_deg, CLOSE_FOV_DEG, close_t(view_height))

## The camera's rotation at the iso zoom: x = screen right, y = screen up, z = towards the viewer. From the
## constants (not a live node), so offline tools (CARD2D's card bake) and the running game cannot drift apart.
static func view_basis(view_height: float = DEFAULT_SIZE) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_for(view_height)), deg_to_rad(yaw_deg), 0.0))

## The projection this run uses (PROJECTION, or orthographic under --cam-ortho).
static func projection_mode() -> Camera3D.ProjectionType:
	return Camera3D.PROJECTION_ORTHOGONAL if ortho else PROJECTION

## How far back the camera stands to show `view_height` metres at its focus.
static func distance_for(view_height: float) -> float:
	if ortho:
		return ORTHO_DISTANCE
	return view_height / (2.0 * tan(deg_to_rad(fov_for(view_height)) * 0.5))

## A visibility_range_end that keeps everything within `radius_m` of the focus drawn at every zoom
## up to LAB_MAX_SIZE (the old 40 m camera's ranges were 40 + radius).
static func cull_range(radius_m: float) -> float:
	return distance_for(LAB_MAX_SIZE) + radius_m

## Shake the camera that follows `subject` (no-op on a headless server or for other bodies).
static func shake(subject: Node, amount: float) -> void:
	if subject == null or not subject.is_inside_tree():
		return
	var cam := subject.get_viewport().get_camera_3d() as IsoCamera
	if cam and cam._target == subject:
		cam.add_trauma(amount)

func add_trauma(amount: float) -> void:
	if reduce_shake:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _ready() -> void:
	projection = projection_mode()
	if ortho:
		min_size = ORTHO_MIN_SIZE
		max_size = ORTHO_MAX_SIZE
		default_size = ORTHO_DEFAULT_SIZE
	else:
		fov = fov_deg
		if no_tilt:
			min_size = ISO_MIN_SIZE
	keep_aspect = Camera3D.KEEP_HEIGHT
	# Moved every frame after the target's interpolated transform, so it is not interpolated itself:
	# interpolated, unproject_position() in _process read last frame's camera and screen UI trailed the world.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if size <= 1.0:
		size = default_size  # Camera3D.size defaults to 1 m, which is a face-full of capsule
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam-size="):  # screenshot runs: start at this zoom
			size = clampf(float(a.substr(11)), min_size, max_size)
	basis = view_basis(size)
	_apply_zoom()
	_target = get_node_or_null(target_path) as Node3D
	if _target:
		_snap()
	_publish()

func _process(delta: float) -> void:
	_update_shake(delta)
	# The follow eases the focus, and the camera stands `distance` back from it: with a fixed distance this
	# is the old position lerp, and a zoom (a new distance) takes effect at once instead of gliding in
	# behind the fingers.
	var focus := focus_point() - _lift
	_apply_zoom()
	_lift = lift()
	if _target:
		# Interpolated origin: the survivor moves on physics ticks, the camera every frame. Without
		# this the survivor stepped 60 Hz under a 120 Hz camera and read as a doubled, smeared image.
		focus = focus.lerp(_desired_focus(true), clampf(follow_lerp * delta, 0.0, 1.0))
	global_position = focus + _lift + global_basis.z * distance
	_publish()

## Close up the camera looks at her chest, not her feet. Added on top of the follow (not eased with
## it), so a zoom moves the view at once like the distance does.
func lift() -> Vector3:
	return Vector3.UP * (CLOSE_LIFT_M * close_t(size))

## Perspective: the distance follows the zoom, and near/far hug the focus. A tight depth range keeps
## depth precise at 90-430 m out, and WorldLighting's shadow splits are fractions of near..far.
func _apply_zoom() -> void:
	if projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	if size != _posed_size:  # only on a zoom change, so a lab that turns the camera itself keeps its angle
		_posed_size = size
		basis = view_basis(size)
		fov = fov_for(size)
	distance = distance_for(size)
	near = maxf(0.3, distance - near_margin())
	far = distance + far_margin()

## Metres in front of the focus that stay inside the view: the ground to the screen's bottom edge
## plus the crown of a 20 m tree standing just below it.
func near_margin() -> float:
	return ground_half_depth() + 35.0

## Metres behind the focus: the ground to the screen's top edge plus terrain relief.
func far_margin() -> float:
	return view_depth() + 30.0 + 150.0 * close_t(size)  # close up: hills past the ground line stay in

## Depth from the focus to the ground at the screen's top (or bottom) edge, capped at SHADOW_DEPTH_MAX
## (WorldLighting ends the shadow map just past it).
func ground_half_depth() -> float:
	return minf(view_depth(), SHADOW_DEPTH_MAX)

## Depth (along the view) from the focus to the ground under the screen's top edge; CLOSE_FAR_M when
## that edge looks at or above the horizon. The iso lens gives ~0.5 * size / tan(pitch).
func view_depth() -> float:
	var pitch := absf(rotation_degrees.x)
	var half := fov * 0.5 if projection == Camera3D.PROJECTION_PERSPECTIVE else 0.0
	var below := pitch - half
	if below < 1.0:
		return CLOSE_FAR_M
	var h := distance * sin(deg_to_rad(pitch)) + CLOSE_LIFT_M * close_t(size)  # the camera over the ground
	var along := h / sin(deg_to_rad(below)) * cos(deg_to_rad(half))
	if projection != Camera3D.PROJECTION_PERSPECTIVE:
		return 0.5 * size / tan(deg_to_rad(maxf(pitch, 5.0)))
	return clampf(along - distance, 0.5 * size / tan(deg_to_rad(maxf(pitch, 5.0))), CLOSE_FAR_M)

## Where the camera looks: its smoothed follow point.
func focus_point() -> Vector3:
	return global_position - global_basis.z * distance

func _desired_focus(interpolated: bool = false) -> Vector3:
	if _target == null:
		return focus_point()
	var base := _target.get_global_transform_interpolated().origin if interpolated else _target.global_position
	if not _target.has_method("camera_interest"):
		return base
	var interest: Variant = _target.call("camera_interest")
	if not interest is Node3D or not is_instance_valid(interest):
		return base
	var shift: Vector3 = (interest as Node3D).global_position - base
	shift.y = 0.0
	shift = (shift * SELECTION_BIAS).limit_length(SELECTION_MAX_SHIFT_M)
	return base + shift

## The camera for every shader that has to line up with it (shaders/camera/camera.gdshaderinc).
func _publish() -> void:
	if not current or not is_inside_tree():
		return
	var persp := projection == Camera3D.PROJECTION_PERSPECTIVE
	focus = focus_point()
	right = Vector3(global_basis.x.x, 0.0, global_basis.x.z).normalized()
	# The lens leans a prop h m tall standing s m right of the focus by h * s * sin(pitch) / distance.
	# Close up the wide lens already leans everything, so the extra lean fades out with close_t.
	parallax = PARALLAX_GAIN * (1.0 - close_t(size)) * sin(deg_to_rad(absf(rotation_degrees.x))) / distance if persp and distance > 1.0 else 0.0
	RenderingServer.global_shader_parameter_set(&"camera_focus", focus)
	RenderingServer.global_shader_parameter_set(&"camera_pitch_deg", rotation_degrees.x)
	RenderingServer.global_shader_parameter_set(&"camera_yaw_deg", rotation_degrees.y)
	RenderingServer.global_shader_parameter_set(&"camera_distance", distance)
	RenderingServer.global_shader_parameter_set(&"parallax_strength", parallax)
	# Close up crowns stand beside and ahead of her, not over her: the fade lifts out of reach (Occlusion
	# still thins whatever stands on the sight line).
	RenderingServer.global_shader_parameter_set(&"tall_fade_height", lerpf(TALL_FADE_PER_SIZE * size, 60.0, close_t(size)) if persp else 0.0)

## Screen-space offsets, so the shake never fights the follow lerp.
func _update_shake(delta: float) -> void:
	var w := Vector2.ZERO if reduce_shake else weather_offset.limit_length(WEATHER_OFFSET_MAX)
	if trauma <= 0.0 or reduce_shake:
		trauma = 0.0
		h_offset = w.x
		v_offset = w.y
		return
	trauma = maxf(0.0, trauma - CombatTuning.num("camera", "trauma_decay_per_s", 1.4) * delta)
	_shake_t += delta
	var amp := trauma * trauma * CombatTuning.num("camera", "max_offset_m", 0.45)
	h_offset = amp * sin(_shake_t * 57.0) + w.x
	v_offset = amp * sin(_shake_t * 43.0 + 1.3) + w.y

func _snap() -> void:
	_apply_zoom()
	_lift = lift()
	global_position = _desired_focus() + _lift + global_basis.z * distance
	_publish()

## Wheel zoom: 12 % a notch, inside min_size..max_size.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = clampf(size / 1.12, min_size, max_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = clampf(size * 1.12, min_size, max_size)
