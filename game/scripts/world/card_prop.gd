class_name CardProp
extends Node3D
## CARD2D (spec 25 §1, owner 2026-10-21: "keep buildings 3D and make resources 2D"): one resource
## prop drawn as a flat, swaying card instead of a GLB. Two art sources:
##   PAINTED  the owner's cut 2D sprites (assets/nature/sprites2d, data/world/sprites2d.json): the
##            texture is the PNG, the world size follows height_m and the PNG's aspect, and the
##            manifest's pivot pixel is the ground point.
##   BAKED    the CARD2D bake of a 3D model (data/card2d.json): albedo + normal, used for a family
##            that has no painted art yet.
## The quad is anchored at its ground point and kept PARALLEL to the camera's view plane every frame
## (owner: "make the flat assets align with the camera angle at all times"), so it is a full
## camera-facing card, not a Y-axis billboard: the card's basis becomes the active camera's basis.
## The camera's angle, focus and parallax reach the shader as the global shader parameters IsoCamera
## publishes ([shader_globals]); nothing here hard-codes a pitch, yaw or projection.
## Alpha-scissor keeps it in the opaque pass, the sway is in the vertex shader. Buildings stay 3D;
## creatures and characters are untouched.

const DATA_PATH := "res://data/card2d.json"
const SPRITES_PATH := "res://data/world/sprites2d.json"
const SPRITES_MAP_PATH := "res://data/world/sprites2d_map.json"
const SHADER_PATH := "res://shaders/card_sway.gdshader"

## Shading for painted art (see card_sway.gdshader). 1 = lit through a flat camera-facing normal:
## one shade over the whole sprite from the sun's own colour and energy, so it darkens at night and
## under shade but the paint never gets a second, invented 3D shading. 2 = unlit (emission only),
## the comparison the brief asks for.
const SHADE_PAINTED := 1
const SHADE_PAINTED_UNLIT := 2

static var _data: Dictionary = {}
static var _sprite_rows: Array = []
static var _sprite_index: Dictionary = {}  # kind (nature family id) -> Array[Dictionary]
static var _sprite_loaded := false
static var _map: Dictionary = {}
static var _map_loaded := false

## The shader without the fade body: the same card_sway.gdshader minus the CARD_FADE_* lines and the
## occlusion include. No instance uniform, so GLES3's per-instance budget (a few thousand) is spent
## only on the tall cards that can fade, not on every grass tuft on the island.
static var _plain_shader: Shader = null

var _quad: MeshInstance3D
var _quad_size := Vector2.ONE
var _pivot := Vector2(0.5, 1.0)
var _basis_used: Basis = Basis()

## The active camera's basis, resolved once per frame for every card on the island instead of once per
## card: 270-odd cards each doing a viewport camera lookup and an orthonormalize every frame is pure
## script cost for a value they all share. `_cam_frame` marks which physics/process frame the cached
## basis belongs to (Engine.get_process_frames), and a missing camera leaves it stale (`_cam_valid`).
static var _cam_basis: Basis = Basis()
static var _cam_frame: int = -1
static var _cam_valid: bool = false

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

## The angle a card is built at before a camera exists: the camera package's declared globals
## ([shader_globals], the values IsoCamera publishes). Never a constant of this script; a live card
## takes the active camera's own basis every frame.
static func default_basis() -> Basis:
	var pitch := global_float(&"camera_pitch_deg")
	var yaw := global_float(&"camera_yaw_deg")
	return Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))

## A camera global's declared value: project.godot [shader_globals], the same parameter IsoCamera
## publishes to the shaders every frame. Used only for a card built before a camera has published
## anything (a headless test, the first frames of a lab); the live camera's basis, not this, is what
## keeps a real card facing the view (_process reads the active Camera3D). RenderingServer's getter is
## editor-only (it errors outside the editor), so the declared value is the honest fallback here.
static func global_float(name: StringName) -> float:
	var declared: Variant = ProjectSettings.get_setting("shader_globals/%s" % name, null)
	if declared is Dictionary:
		var d: Variant = (declared as Dictionary).get("value", 0.0)
		if d is float or d is int:
			return float(d)
	return 0.0

## card_sway.gdshader with the CARD_FADE_INCLUDE line and every CARD_FADE_BEGIN..END block removed.
static func fade_free_shader() -> Shader:
	if _plain_shader != null:
		return _plain_shader
	var src := FileAccess.get_file_as_string(SHADER_PATH)
	var out := PackedStringArray()
	var skipping := false
	for line in src.split("\n"):
		if line.contains("CARD_FADE_BEGIN"):
			skipping = true
			continue
		if line.contains("CARD_FADE_END"):
			skipping = false
			continue
		if skipping or line.contains("CARD_FADE_INCLUDE"):
			continue
		out.append(line)
	var sh := Shader.new()
	sh.code = "\n".join(out)
	_plain_shader = sh
	return sh

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

# ---------------------------------------------------------------- painted sprites

## The family's row in data/nature_manifest.json (role, height, models). Read through the Data
## autoload node so this script also parses outside a full project boot (--check-only).
static func family_row(family: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var d: Node = tree.root.get_node_or_null("Data") if tree and tree.root else null
	var fams: Variant = d.get("nature_families") if d else null
	if fams is Dictionary:
		var row: Variant = (fams as Dictionary).get(family, {})
		if row is Dictionary:
			return row
	return {}

static func family_role(family: String) -> String:
	return str(family_row(family).get("role", ""))

## Every row of data/world/sprites2d.json (the manifest arrives in parts; read it, never hard-code).
static func sprites() -> Array:
	if not _sprite_loaded:
		_sprite_loaded = true
		var f := FileAccess.open(SPRITES_PATH, FileAccess.READ)
		if f == null:
			push_error("[switch2d] cannot read %s" % SPRITES_PATH)
			return _sprite_rows
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			var rows: Variant = (parsed as Dictionary).get("sprites", [])
			if rows is Array:
				for r in rows:
					if not (r is Dictionary):
						continue
					var row := r as Dictionary
					var file := str(row.get("file", ""))
					if file == "" or not file.begins_with("res://"):
						continue
					_sprite_rows.append(row)
					var kind := str(row.get("kind", ""))
					var list: Array = _sprite_index.get(kind, [])
					list.append(row)
					_sprite_index[kind] = list
	return _sprite_rows

## Painted sprites whose manifest kind is this nature family id (may be empty).
static func sprites_for_family(family: String) -> Array:
	sprites()
	var list: Variant = _sprite_index.get(family, [])
	if list is Array and not (list as Array).is_empty():
		return list
	# A family whose art is aliased in sprites2d_map.json ("families": {family: {sprite: <id>}}): the
	# rows' own kind names the art ("prop:vine_hanging"), not the family, so index alone cannot see it.
	var fam: Variant = (sprite_map().get("families", {}) as Dictionary).get(family, null)
	if fam is Dictionary:
		var row := sprite(str((fam as Dictionary).get("sprite", "")))
		if not row.is_empty():
			return [row]
	return [] if not list is Array else list

## True when the family has painted art to draw (the PNGs imported).
static func has_painted(family: String) -> bool:
	for row in sprites_for_family(family):
		if ResourceLoader.exists(str(row.get("file", ""))):
			return true
	return false

## One painted sprite for this family, chosen deterministically from the node's ground point (a
## stable hash), so neighbours mix variants while a node always draws the same one.
static func pick_painted(family: String, pos: Vector3) -> Dictionary:
	var rows := sprites_for_family(family)
	if rows.is_empty():
		return {}
	var pick := int(abs(hash(Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0))))) % rows.size()
	return rows[pick] as Dictionary

## A painted sprite row by manifest id ({} when the manifest has no such id).
static func sprite(id: String) -> Dictionary:
	var rows := sprites()
	for r in rows:
		if str((r as Dictionary).get("id", "")) == id:
			return r as Dictionary
	return {}

## data/world/sprites2d_map.json: family -> sprite/card overrides plus the per-role fallbacks, for
## families whose art has not been cut yet. Empty is fine; the defaults below then apply.
static func sprite_map() -> Dictionary:
	if not _map_loaded:
		_map_loaded = true
		if ResourceLoader.exists(SPRITES_MAP_PATH):
			var f := FileAccess.open(SPRITES_MAP_PATH, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_map = parsed
	return _map

## ASSUMPTION: no resource draws as a 3D model under resource_render "card", so a family whose own
## painted art has not been cut yet borrows the closest look of the same role (a card where one is
## baked, else a painted sprite). Overridable per family in data/world/sprites2d_map.json.
const ROLE_FALLBACK := {
	"tree": ["card", "tree-common-a"],
	"tree_dead": ["card", "tree-common-dead"],
	"bush": ["card", "bush-berries-b-empty"],
	"rock": ["card", "rock-moss-a"],
	"plant": ["card", "plant-a"],
	"ground": ["card", "grass-a"],
	"crop": ["card", "plant-a"],
	"water": ["sprite", "jungle-plants_24_white_lily_plant"],
	"prop": ["card", "plant-a"],
	"node": ["card", "rock-moss-a"],
}

## What a node of `family` standing at `pos` should draw under resource_render "card":
##   {"kind": "painted", "row": <manifest row>}   the owner's painted sprite (deterministic variant)
##   {"kind": "card", "card": <card2d.json id>}   a BAKED card (family has no painted art)
##   {"kind": ""}                                   nothing (no art at all)
## Never a 3D model: buildings do not come through here, so they stay 3D.
static func visual_for(family: String, pos: Vector3) -> Dictionary:
	var map := sprite_map()
	var by_family: Variant = map.get("families", {})
	var override: Dictionary = {}
	if by_family is Dictionary and (by_family as Dictionary).get(family) is Dictionary:
		override = (by_family as Dictionary)[family] as Dictionary
	var role := family_role(family)
	# 1. An explicit sprite override, 2. the family's own painted art.
	var sprite_id := str(override.get("sprite", ""))
	if sprite_id != "":
		var row := sprite(sprite_id)
		if not row.is_empty():
			return {"kind": "painted", "row": row}
	if not sprites_for_family(family).is_empty():
		var picked: Dictionary = pick_painted(family, pos)
		if not picked.is_empty():
			return {"kind": "painted", "row": picked}
	# 3. An explicit baked-card override, 4. the family's own baked card.
	var card_id := str(override.get("card", ""))
	if card_id != "" and baked(card_id):
		return {"kind": "card", "card": card_id}
	var own := card_for_family(family)
	# A family whose only card is its depleted look (Bush -> bush-berries-b-empty) keeps it.
	if own != "" and baked(own):
		return {"kind": "card", "card": own}
	# 5. The role's fallback (map overrides first).
	var roles: Variant = map.get("role_fallback", {})
	var fb: Variant = (roles as Dictionary).get(role, null) if roles is Dictionary else null
	if fb is Array and (fb as Array).size() >= 2:
		var kind := str((fb as Array)[0])
		var id := str((fb as Array)[1])
		if kind == "sprite":
			var frow := sprite(id)
			if not frow.is_empty():
				return {"kind": "painted", "row": frow}
		elif baked(id):
			return {"kind": "card", "card": id}
	var def: Variant = ROLE_FALLBACK.get(role, null)
	if def is Array and (def as Array).size() >= 2:
		var dkind := str((def as Array)[0])
		var did := str((def as Array)[1])
		if dkind == "sprite":
			var drow := sprite(did)
			if not drow.is_empty():
				return {"kind": "painted", "row": drow}
		elif baked(did):
			return {"kind": "card", "card": did}
	return {"kind": ""}

## The manifest pivot pixel as normalized UV (u from the left, v from the top).
static func sprite_pivot_uv(row: Dictionary) -> Vector2:
	var px: Variant = row.get("px", [])
	var pivot: Variant = row.get("pivot", [])
	if px is Array and pivot is Array and (px as Array).size() >= 2 and (pivot as Array).size() >= 2:
		var w := maxf(1.0, float(px[0]))
		var h := maxf(1.0, float(px[1]))
		return Vector2(clampf(float(pivot[0]) / w, 0.0, 1.0), clampf(float(pivot[1]) / h, 0.0, 1.0))
	return Vector2(0.5, 1.0)

## The sprite's whole rectangle in metres for `height_m` of visible content (height_m is the sprite's
## own manifest height_m, i.e. the art's full pixel height): width follows the PNG's aspect.
static func sprite_world_size(row: Dictionary, height_m: float) -> Vector2:
	var px: Variant = row.get("px", [])
	var w := 1.0
	var h := 1.0
	if px is Array and (px as Array).size() >= 2:
		w = maxf(1.0, float(px[0]))
		h = maxf(1.0, float(px[1]))
	return Vector2(maxf(0.05, height_m) * w / h, maxf(0.05, height_m))

## The sway kind for a nature family, from its role in the manifest (trees slow and wide, grass fast,
## rocks still) - the same kinds card2d.json carries.
static func sway_kind(family: String) -> String:
	var role := family_role(family)
	if role.begins_with("tree"):
		return "tree"
	if role == "bush":
		return "bush"
	if role == "rock":
		return "rock"
	if role == "ground":
		return "grass"
	return "plant"

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
	var w := size.x * sc
	var h := size.y * sc
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", load(albedo_path(card_id)) as Texture2D)
	mat.set_shader_parameter("normal_tex", load(normal_path(card_id)) as Texture2D)
	mat.set_shader_parameter("shading_mode", 0)
	_apply_sway(mat, params, sc, height_m if height_m > 0.0 else h)
	set_meta(&"card_id", card_id)
	return _place(mat, pivot, Vector2(w, h), bool(params.get("cast_shadow", kind == "tree")))

## Builds the card for one painted sprite row (data/world/sprites2d.json), `height_m` metres of the
## sprite's visible art. The texture is the PNG itself, the size follows the PNG's aspect and the
## manifest pivot pixel sits on the node's origin. False when the PNG is missing.
func setup_painted(row: Dictionary, height_m: float, shade_mode: int = SHADE_PAINTED) -> bool:
	var file := str(row.get("file", ""))
	if file == "" or not ResourceLoader.exists(file):
		return false
	Occlusion._ensure_driver()
	var tex := load(file) as Texture2D
	if tex == null:
		return false
	var family := str(row.get("kind", ""))
	var params := kind_params(sway_kind(family))
	var size := sprite_world_size(row, height_m)
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.set_shader_parameter("albedo_tex", tex)
	# Painted art has no baked normal: the flat, camera-facing normal is the shading (see the shader).
	mat.set_shader_parameter("shading_mode", shade_mode)
	_apply_sway(mat, params, 1.0, size.y)
	set_meta(&"card_id", str(row.get("id", "")))
	set_meta(&"sprite", str(row.get("id", "")))
	return _place(mat, sprite_pivot_uv(row), size, bool(params.get("cast_shadow", false)))

## Sway is in metres of the quad: the amplitude grows with the card's scale (a 10 m palm sways farther
## than a 1 m fern of the same kind). card_height is the visible art height the parallax measures in.
func _apply_sway(mat: ShaderMaterial, params: Dictionary, sc: float, card_height: float) -> void:
	mat.set_shader_parameter("sway_amplitude", float(params.get("amplitude", 0.0)) * sc)
	mat.set_shader_parameter("sway_speed", float(params.get("speed", 1.0)))
	mat.set_shader_parameter("card_height", card_height)

## The quad, its material and the ground pivot; shared by both art sources.
func _place(mat: ShaderMaterial, pivot: Vector2, size: Vector2, cast_shadow: bool) -> bool:
	# Only a card tall enough to hide the survivor gets the fade body (and its instance uniform).
	if size.y < Occlusion.TALL_M:
		mat.shader = fade_free_shader()
	mat.set_shader_parameter("pivot_uv", pivot)
	_pivot = pivot
	var mi := get_node_or_null("Card") as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Card"
		add_child(mi)
	var quad := PlaneMesh.new()
	quad.orientation = PlaneMesh.FACE_Z
	quad.size = size
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Every card is its own mesh (no MultiMesh batching like VegBatch's cells), so far ones must cull:
	# the same distance rule as the tree discs, never nearer than half a screen of ground.
	mi.visibility_range_end = IsoCamera.cull_range(maxf(40.0, size.y * 2.0))
	# PlaneMesh is centred; its offset from the ground point follows the camera's screen axes (see
	# _face_camera), which runs now and every frame after.
	_quad = mi
	_quad_size = size
	_face_camera(default_basis())
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
	if not is_inside_tree():
		return
	var f := Engine.get_process_frames()
	if f != _cam_frame:
		_cam_frame = f
		var cam := get_viewport().get_camera_3d()
		_cam_valid = cam != null
		if _cam_valid:
			_cam_basis = cam.global_basis.orthonormalized()
	if not _cam_valid:
		return
	if not _basis_used.is_equal_approx(_cam_basis):
		_face_camera(_cam_basis)

## Short shiver after a gather (HarvestNode.mark_gathered calls this).
func rustle(seconds: float = 0.6) -> void:
	var mi := get_node_or_null("Card") as MeshInstance3D
	if mi == null or not (mi.material_override is ShaderMaterial):
		return
	var mat := mi.material_override as ShaderMaterial
	# Rocks do not sway: the sway kind gives them amplitude 0, and they do not shiver either.
	if float(mat.get_shader_parameter("sway_amplitude")) <= 0.0:
		return
	mat.set_shader_parameter("rustle", 1.0)
	mat.set_shader_parameter("rustle_time", 0.0)
	var tw := create_tween()
	tw.tween_method(func (t: float) -> void:
		mat.set_shader_parameter("rustle", 1.0 - t)
		mat.set_shader_parameter("rustle_time", t * seconds), 0.0, 1.0, seconds)
