class_name CardProp
extends Node3D
## CARD2D (spec 25 §1, trial): one resource prop drawn as a baked, swaying card instead of a GLB.
## The quad is anchored at its ground point and kept PARALLEL to the camera's view plane every frame
## (owner 2026-10-21: "make the flat assets align with the camera angle at all times"), so it is a
## full camera-facing card, not a Y-axis billboard: the card's basis becomes the active camera's
## basis, which also holds if the camera moves to Durango's lower angle. Alpha-scissor keeps it in
## the opaque pass, the baked normal map lets the moving sun shade it, the sway is in the vertex
## shader. The bake reads the angle from IsoCamera, so a camera change only needs a re-bake.
## Data: game/data/card2d.json. Buildings stay 3D; creatures and characters are untouched.

const DATA_PATH := "res://data/card2d.json"
const SHADER_PATH := "res://shaders/card_sway.gdshader"

static var _data: Dictionary = {}
## The game camera's basis, read from an IsoCamera instance once and kept (the card is baked from
## the same angle, so a camera change only needs a re-bake; nothing here hard-codes it).
static var _default_basis: Basis = Basis()
static var _default_read := false

var _quad: MeshInstance3D
var _quad_size := Vector2.ONE
var _pivot := Vector2(0.5, 1.0)
var _basis_used: Basis = Basis()

## Parsed card2d.json, cached for the run (static data).
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			push_error("[card2d] cannot read %s" % DATA_PATH)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	return _data

static func cards() -> Dictionary:
	var d: Variant = data().get("cards", {})
	return d if d is Dictionary else {}

static func card(name: String) -> Dictionary:
	var row: Variant = cards().get(name, {})
	return row if row is Dictionary else {}

## The card entry for a nature family ("" when the family has no card).
static func card_for_family(family: String) -> String:
	for id in cards().keys():
		var fams: Variant = (cards()[id] as Dictionary).get("families", [])
		if fams is Array and (fams as Array).has(family):
			return str(id)
	return ""

## The card entry for a model path ("" when that model has no card).
static func card_for_model(path: String) -> String:
	for id in cards().keys():
		if str((cards()[id] as Dictionary).get("model", "")) == path:
			return str(id)
	return ""

## The angle the cards are baked from and drawn to when no camera is in the tree yet: IsoCamera's.
static func default_basis() -> Basis:
	if not _default_read:
		_default_read = true
		var cam := IsoCamera.new()
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root:
			tree.root.add_child(cam)
			_default_basis = cam.global_basis.orthonormalized()
			cam.queue_free()
	return _default_basis

static func kind_params(kind: String) -> Dictionary:
	var kinds: Variant = data().get("kinds", {})
	if kinds is Dictionary:
		var row: Variant = (kinds as Dictionary).get(kind, {})
		if row is Dictionary:
			return row
	return {}

static func albedo_path(name: String) -> String:
	return "res://assets/nature/cards/%s_albedo.png" % name

static func normal_path(name: String) -> String:
	return "res://assets/nature/cards/%s_normal.png" % name

## True when both textures exist and the bake recorded the pivot and world size.
static func baked(name: String) -> bool:
	var row := card(name)
	return ResourceLoader.exists(albedo_path(name)) and ResourceLoader.exists(normal_path(name)) \
		and row.has("pivot") and row.has("world_size")

## Ground point of the card in normalized texture UV (u from the left, v from the top).
static func pivot_uv(name: String) -> Vector2:
	var p: Variant = card(name).get("pivot", [0.5, 1.0])
	if p is Array and (p as Array).size() >= 2:
		return Vector2(float(p[0]), float(p[1]))
	return Vector2(0.5, 1.0)

## The whole texture rectangle in metres at scale 1 (visible content plus its margins).
static func world_size(name: String) -> Vector2:
	var s: Variant = card(name).get("world_size", [1.0, 1.0])
	if s is Array and (s as Array).size() >= 2:
		return Vector2(maxf(0.01, float(s[0])), maxf(0.01, float(s[1])))
	return Vector2(1.0, 1.0)

## Visible content height in metres at scale 1 (island_scatter scales against the family's height).
static func content_height(name: String) -> float:
	var row := card(name)
	var c: Variant = row.get("content", {})
	if c is Dictionary:
		var px := float((c as Dictionary).get("h", 0.0))
		var tex: float = maxf(1.0, float(row.get("resolution", 512)))
		if px > 0.0:
			return world_size(name).y * px / tex
	return world_size(name).y * maxf(0.05, pivot_uv(name).y)

## Builds the card for `card_id`, `height_m` metres of visible content. False when it is not baked.
func setup(card_id: String, height_m: float = 0.0) -> bool:
	if not baked(card_id):
		return false
	# The card shader includes the occlusion fade body, whose global uniforms only exist once the
	# Occlusion driver is up. Register them here so a card renders on its own (a bare lab, a beach).
	Occlusion._ensure_driver()
	var row := card(card_id)
	var kind := str(row.get("kind", "plant"))
	var params := kind_params(kind)
	var size := world_size(card_id)
	var sc := 1.0
	if height_m > 0.0:
		var ch := content_height(card_id)
		if ch > 0.001:
			sc = height_m / ch
	var pivot := pivot_uv(card_id)
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", load(albedo_path(card_id)) as Texture2D)
	mat.set_shader_parameter("normal_tex", load(normal_path(card_id)) as Texture2D)
	mat.set_shader_parameter("sway_amplitude", float(params.get("amplitude", 0.0)) * sc)
	mat.set_shader_parameter("sway_speed", float(params.get("speed", 1.0)))
	mat.set_shader_parameter("pivot_uv", pivot)
	mat.set_shader_parameter("card_height", height_m if height_m > 0.0 else world_size(card_id).y)
	var w := size.x * sc
	var h := size.y * sc
	_pivot = pivot
	var mi := get_node_or_null("Card") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Card"
		add_child(mi)
	var quad := PlaneMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = Vector2(w, h)
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(params.get("cast_shadow", kind == "tree")) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# PlaneMesh is centred; its offset from the ground point follows the camera's screen axes (see
	# _face_camera), which runs now and every frame after.
	_quad = mi
	_quad_size = Vector2(w, h)
	_face_camera(default_basis())
	_feed_camera()
	set_meta(&"card_id", card_id)
	return true

## The card's basis and offset for camera basis `b` (x = screen right, y = screen up, z = towards
## the viewer). The pivot pixel lands on the node's origin, so the base stays planted whatever the
## camera angle is; the plane itself is parallel to the view plane.
func _face_camera(b: Basis) -> void:
	if _quad == null or not is_instance_valid(_quad):
		return
	var pivot := _pivot
	var right := b.x.normalized()
	var up := b.y.normalized()
	var fwd := b.z.normalized()
	_quad.basis = Basis(right, up, fwd)
	_quad.position = right * ((0.5 - pivot.x) * _quad_size.x) + up * ((pivot.y - 0.5) * _quad_size.y)
	_basis_used = b

## Re-align while the active camera's basis differs from the one last applied (also covers a camera
## that switches from orthographic iso to a perspective Durango view: the card follows its angle).
func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var b := cam.global_basis.orthonormalized()
	if _basis_used == null or not _basis_used.is_equal_approx(b):
		_face_camera(b)
	# Parallax follows the camera's ground focus as it scrolls.
	_feed_camera()

## Camera state shared by every card: computed once per frame (the first card that asks), not 150
## times. The focus is the active camera's own ground point, so the projection and pitch are never
## assumed here; only the strength is a setting (project.godot [card2d] parallax_strength) until the
## camera package publishes it as a global shader parameter.
static var _frame_seen: int = -1
static var _focus := Vector3.ZERO
static var _strength := 0.055

## The camera's ground focus: project the view ray forward from the camera until it meets y = 0.
static func camera_state(cam: Camera3D) -> void:
	if _frame_seen == Engine.get_process_frames():
		return
	_frame_seen = Engine.get_process_frames()
	_strength = float(ProjectSettings.get_setting("card2d/parallax_strength", 0.006))
	_focus = Vector3.ZERO
	if cam == null:
		return
	var f := -cam.global_basis.z
	if absf(f.y) > 0.001:
		_focus = cam.global_position + f * maxf(0.0, -cam.global_position.y / f.y)

func _feed_camera() -> void:
	var mi := _quad
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	camera_state(cam)
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("camera_focus", _focus)
	mat.set_shader_parameter("parallax_strength", _strength)

## Short shiver after a gather (HarvestNode.mark_gathered calls this).
func rustle(seconds: float = 0.6) -> void:
	var mi := get_node_or_null("Card") as MeshInstance3D
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var mat := mi.material_override as ShaderMaterial
	# Rocks do not sway: card2d.json gives them amplitude 0, and they do not shiver either.
	if float(mat.get_shader_parameter("sway_amplitude")) <= 0.0:
		return
	mat.set_shader_parameter("rustle", 1.0)
	mat.set_shader_parameter("rustle_time", 0.0)
	var tw := create_tween()
	tw.tween_method(func (t: float) -> void:
		mat.set_shader_parameter("rustle", 1.0 - t)
		mat.set_shader_parameter("rustle_time", t * seconds), 0.0, 1.0, seconds)
