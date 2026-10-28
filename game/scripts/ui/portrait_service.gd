class_name PortraitService
extends RefCounted
## The player's profile picture, one source for every screen that shows it (character creation,
## the Character screen, and the HUD, domain banner and map once they show one): a headshot
## rendered from the survivor model wearing the player's look, over the look's portrait pattern
## and background colour. There is no painted portrait art; this is the render.
## One shared instance: request(look) renders when the look changed (else the cached picture
## stands), texture() is the latest picture, `changed` fires with each new one.

signal changed(texture: Texture2D)

const SIZE := 256
## Head framing: the model faces -Z; the camera sits in front of the Head bone (the skull base) and aims
## above it, so the whole head with a little neck fills the picture (0.78 m cut the hair off).
const CAMERA_BACK := 0.9
const AIM_ABOVE_HEAD_BONE := 0.07
const CAMERA_FOV := 26.0

static var _shared: PortraitService

## Renders taken (a request for the cached look does not count).
var renders: int = 0
## The last render captured 3D pixels (false headless, where only the backdrop is drawn).
var captured: bool = false
## The latest picture's pixels (the texture's own copy is not readable on every renderer).
var image: Image
var _key: String = ""
var _tex: ImageTexture
var _pending: Dictionary = {}
var _busy := false
var _studio: SubViewport
var _rig: RiggedModel
var _camera: Camera3D

static func shared() -> PortraitService:
	if _shared == null:
		_shared = PortraitService.new()
		# Let go of the texture and studio with the tree: a static resource freed after the renderer
		# shut down aborted Godot at quit (a crash report on the owner's Mac).
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.tree_exiting.connect(func () -> void:
				CharacterLook.release(_shared._rig)
				_shared = null)
	return _shared

func texture() -> Texture2D:
	return _tex

## The player's own picture: the HUD, Character screen, domain banner and map call this (and listen to
## `changed`). It renders on first use and again only when World's look changes.
static func of_player() -> Texture2D:
	var look: Variant = World.get("look")
	shared().request(CharacterLook.clean(look))
	return shared().texture()

## Height is left out: the head is framed the same at any height, so a slider drag renders nothing.
func key_of(look: Dictionary) -> String:
	var head := look.duplicate(true)
	head.erase("height")
	return JSON.stringify(head, "", true)

func is_current(look: Dictionary) -> bool:
	return _tex != null and key_of(look) == _key

## Re-render for `look` unless the cached picture is already of it. Coalesces bursts (a slider drag)
## into one render of the newest look.
func request(look: Dictionary) -> void:
	if is_current(look) and not _busy:
		return
	_pending = look.duplicate(true)
	if not _busy:
		_drain()

func _drain() -> void:
	_busy = true
	while not _pending.is_empty():
		var look := _pending
		_pending = {}
		await _render(look)
	_busy = false

func _render(look: Dictionary) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var portrait := backdrop(str(look.get("portrait", {}).get("pattern", "plain")), Color.html(str(look.get("portrait", {}).get("bg", "#5d6a8a"))), SIZE)
	captured = false
	if tree and DisplayServer.get_name() != "headless":
		_ensure_studio(tree)
		var head_look := look.duplicate(true)
		head_look["height"] = 1.0  # same framing at any height
		CharacterLook.apply(_rig, head_look)
		_frame_head()
		_studio.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := _studio.get_texture().get_image()
		if shot and not shot.is_empty():
			shot.convert(Image.FORMAT_RGBA8)
			portrait.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
			captured = true
	image = portrait
	if _tex == null:
		_tex = ImageTexture.create_from_image(portrait)
	else:
		_tex.set_image(portrait)
	_key = key_of(look)
	renders += 1
	changed.emit(_tex)

func _ensure_studio(tree: SceneTree) -> void:
	if _studio and is_instance_valid(_studio):
		return
	_studio = SubViewport.new()
	_studio.name = "PortraitStudio"
	_studio.size = Vector2i(SIZE, SIZE)
	_studio.own_world_3d = true
	_studio.transparent_bg = true
	_studio.msaa_3d = Viewport.MSAA_4X
	_studio.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tree.root.add_child(_studio)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.6, 0.6)
	env.environment.ambient_light_energy = 0.7
	_studio.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-25.0, 155.0, 0.0)  # from the front-left, slightly above
	key.light_energy = 1.1
	_studio.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0.6, 2.0, 0.8)
	rim.omni_range = 3.0
	rim.light_energy = 0.8
	rim.light_color = Color(1.0, 0.86, 0.7)
	_studio.add_child(rim)
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_camera.current = true
	_studio.add_child(_camera)
	_rig = CharacterLook.build_rig(_studio, "portrait")
	if _rig.anim_player and _rig.anim_player.has_animation(&"idle"):
		_rig.anim_player.seek(0.5, true)  # a settled idle pose, held
		_rig.anim_player.pause()

func _frame_head() -> void:
	var head := Vector3(0.0, 1.62, 0.0)
	var bone := _rig.skeleton.find_bone("Head") if _rig.skeleton else -1
	if bone >= 0:
		head = _rig.skeleton.global_transform * _rig.skeleton.get_bone_global_pose(bone).origin
	_camera.look_at_from_position(head + Vector3(0.0, AIM_ABOVE_HEAD_BONE + 0.02, -CAMERA_BACK), head + Vector3(0.0, AIM_ABOVE_HEAD_BONE, 0.0))

## The portrait's backdrop: the background colour with the pattern drawn a shade darker. Also the
## pattern swatches in character creation.
static func backdrop(pattern: String, bg: Color, side: int) -> Image:
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var ink := bg.darkened(0.22)
	var cell := maxi(4, side >> 3)
	var n := ceili(float(side) / cell)
	match pattern:
		"checker":
			for j in n:
				for i in n:
					if (i + j) % 2 == 0:
						img.fill_rect(Rect2i(i * cell, j * cell, cell, cell), ink)
		"stripes":
			for j in n:
				img.fill_rect(Rect2i(0, j * cell, side, cell >> 1), ink)
		"dots":
			var r := cell >> 2
			for cy in range(cell >> 1, side, cell):
				for cx in range(cell >> 1, side, cell):
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if dx * dx + dy * dy <= r * r and cx + dx < side and cy + dy < side:
								img.set_pixel(cx + dx, cy + dy, ink)
	return img
