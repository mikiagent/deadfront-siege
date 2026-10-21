class_name CardProp
extends Node3D
## CARD2D (spec 25 §1, trial): one resource prop drawn as a baked, swaying card instead of a GLB.
## The quad is anchored at the bottom centre (its ground point) and turned to face the fixed iso
## camera (yaw 45), so a Y-axis billboard is enough. Alpha-scissor keeps it in the opaque pass, the
## normal map lets the moving sun shade it, and the sway lives in the vertex shader.
## Data: game/data/card2d.json. Buildings stay 3D; creatures and characters are untouched.

const DATA_PATH := "res://data/card2d.json"
## IsoCamera's yaw (scripts/camera/iso_camera.gd: rotation_degrees = (-35.264, 45, 0)).
const CAMERA_YAW_DEG := 45.0
const SHADER_PATH := "res://shaders/card_sway.gdshader"

static var _data: Dictionary = {}

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
	var w := size.x * sc
	var h := size.y * sc
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
	# PlaneMesh is centred; move it so the texture's pivot pixel sits on the node origin (ground point).
	mi.position = Vector3((0.5 - pivot.x) * w, (pivot.y - 0.5) * h, 0.0)
	rotation = Vector3(0.0, deg_to_rad(CAMERA_YAW_DEG), 0.0)
	set_meta(&"card_id", card_id)
	return true

## Short shiver after a gather (HarvestNode.mark_gathered calls this).
func rustle(seconds: float = 0.6) -> void:
	var mi := get_node_or_null("Card") as MeshInstance3D
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var mat := mi.material_override as ShaderMaterial
	mat.set_shader_parameter("rustle", 1.0)
	mat.set_shader_parameter("rustle_time", 0.0)
	var tw := create_tween()
	tw.tween_method(func (t: float) -> void:
		mat.set_shader_parameter("rustle", 1.0 - t)
		mat.set_shader_parameter("rustle_time", t * seconds), 0.0, 1.0, seconds)
