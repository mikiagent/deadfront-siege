class_name PropCards
extends Node3D
## PROPS2D (specs 27/28, owner 2026-10-21: "resources 2D but realistic and kind of look 3D", "the
## resources have the UI that is clickable and the props do not"): the scenery layer's painted cards.
##
## A non-resource prop draws as one camera-facing card of its own painted sprite (data/world/
## sprites2d.json, kind "prop:*"): the pivot pixel is the ground point, the art's own height_m is the
## world height and the sway kind comes from the prop kind (`sway` in data/world/props.json), so a
## rock formation stands still while reeds move. The card is parallel to the camera's view plane and
## re-aligned whenever the live camera's basis changes, exactly like CardProp's resource cards.
##
## Cost: one atlas for the whole island (every sprite at once) and one MultiMesh per 64 m cell, so a
## dense island costs a few dozen draw calls, not one node per prop. The shader (built here, from the
## same camera and occlusion includes CardProp uses) places each quad from its own per-instance data:
##   INSTANCE_CUSTOM.xy  the sprite's rect offset in the atlas (UV)
##   INSTANCE_CUSTOM.zw  the sprite's rect size in the atlas (UV)
##   COLOR.rg            the sprite's pivot in sprite UV
##   COLOR.b             sway amplitude in metres;  COLOR.a  card height in metres
##
## Scenery never looks like a resource: every card is multiplied by SCENERY_TINT (a little darker and
## flatter than the same art on a HarvestNode), and a prop is never in the "harvest" group, has no
## TapZone and no label (IslandProps owns those rules). Nothing here decides what a prop is: blocks
## and destroyable come from the prop layer's data and its rows (see island_props.gd).

const CELL_M := 64.0
## Atlas tile edge in px: every sprite is scaled to fit one square cell, bottom-aligned, with a
## transparent gutter so mipmaps never bleed between neighbours.
const TILE_PX := 384
const GUTTER_PX := 8
## ASSUMPTION: a scenery card is a touch darker and cooler than the same art on a resource, so the
## silhouette reads as "not clickable" even where the art is shared (shells, boulders).
const SCENERY_TINT := Color(0.82, 0.83, 0.78, 1.0)
## A cell's draw range, the same rule VegBatch and GroundCover use (IsoCamera adds its own distance).
const CELL_RANGE_M := 80.0
## Sway speed, seconds-scale of the shader's wave (card2d.json's plant/bush/tree kinds sit 0.55-1.7).
const SWAY_SPEED := 1.2

## The card shader: card_sway's painted mode, atlas-based and driven per instance. CARD_FADE_BEGIN/
## END mark the see-through body, so a short card is built without it (no instance uniform spent).
const SHADER_SRC := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;
#include "res://shaders/camera/camera.gdshaderinc"
#include "res://shaders/occlusion/occlusion.gdshaderinc" // CARD_FADE_INCLUDE
#include "res://shaders/sky/sky_shadow.gdshaderinc"
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway_speed = 1.2;
uniform float alpha_scissor = 0.5;
varying vec2 v_uv;
varying vec2 v_pivot;
varying float v_sky;

void vertex() {
	vec2 pivot = COLOR.rg;
	vec2 rect = INSTANCE_CUSTOM.zw;
	float h = COLOR.a;
	float w = h * (rect.x * float(textureSize(atlas, 0).x)) / max(0.001, rect.y * float(textureSize(atlas, 0).y));
	// The quad is unit-sized around the node origin; the pivot pixel is moved onto that origin, so the
	// card stands on its ground point whatever the art's margins are (CardProp's rule).
	VERTEX.x = (0.5 - pivot.x) * w + VERTEX.x * w;
	VERTEX.y = (pivot.y - 0.5) * h + VERTEX.y * h;
	v_uv = INSTANCE_CUSTOM.xy + UV * rect;
	v_pivot = pivot;
	// Sway: sideways travel grows with height, none at the ground pivot, phase from the world point.
	float k = clamp((pivot.y - UV.y) / max(0.001, pivot.y), 0.0, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.45 + world.z * 0.37;
	float wave = sin(TIME * sway_speed + phase);
	float gust = sin(TIME * 0.37 + phase * 0.5) * 0.5;
	float amp = COLOR.b * (wave + gust);
	VERTEX.x += amp * k * k;
	VERTEX.z += amp * 0.35 * k * k;
	// Parallax, from the ground point (MODEL_MATRIX's origin) so neighbours never shear together.
	vec3 ground = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	v_sky = sky_shade(ground.xz);
	vec2 d = ground.xz - camera_focus.xz;
	float sr = dot(vec3(d.x, 0.0, d.y), normalize(MODEL_MATRIX[0].xyz));
	float su = dot(vec3(d.x, 0.0, d.y), normalize(MODEL_MATRIX[1].xyz));
	float t = k * k;
	vec2 dir = vec2(sr, su);
	float metres = length(dir) * parallax_strength * t * h;
	float shift = min(metres, 0.15 * h) * t;
	vec2 unit = metres > 1e-5 ? dir / length(dir) : vec2(0.0);
	VERTEX.x += unit.x * shift;
	VERTEX.y += unit.y * shift;
	// CARD_FADE_BEGIN
	occl_drop = occl_drop_of(MODEL_MATRIX, INV_VIEW_MATRIX);
	// CARD_FADE_END
}

void fragment() {
	vec4 albedo = texture(atlas, v_uv);
	ALBEDO = albedo.rgb * tint.rgb * v_sky;
	ALPHA = albedo.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	// Painted art: one flat, camera-facing normal, so the sun lights the whole card and the paint
	// never gets a second, invented 3D shading.
	NORMAL = vec3(0.0, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	// CARD_FADE_BEGIN
	float canopy = mix(0.65, 1.4, clamp(v_uv.y < v_pivot.y ? 1.0 : 0.0, 0.0, 1.0));
	float drop = clamp(occl_drop * canopy, 0.0, 1.0);
	if (drop > occl_bayer4(FRAGCOORD.xy)) {
		discard;
	}
	// CARD_FADE_END
}
"""

## One instance: the sprite row, its ground point, height and sway amplitude.
var _items: Array[Dictionary] = []      # {row, pos, height, sway, live}
var _slot_of: Dictionary = {}           # instance index -> {"mmi", "slot"}
var _cells: Dictionary = {}             # Vector2i -> MultiMeshInstance3D
var _cell_items: Dictionary = {}        # Vector2i -> Array[int]
var _mats: Dictionary = {}              # "tall"/"short" -> ShaderMaterial
var _atlas: ImageTexture
var _rects: Dictionary = {}             # sprite id -> {offset: Vector2, size: Vector2}
var _basis: Basis = Basis()
var _basis_valid := false
var _committed := false
var _shown := 0

# ---------------------------------------------------------------- build

## Adds one prop card. `row` is a sprites2d.json row whose file exists (the caller resolves it, with a
## variant chosen per position); `height` is the art's visible height in metres; `sway` is the card
## sway kind (tree/bush/plant/grass/rock, the sway amplitudes of data/card2d.json).
func add(row: Dictionary, pos: Vector3, height: float, sway: String) -> int:
	var params: Dictionary = CardProp.kind_params(sway)
	var i := _items.size()
	_items.append({
		"row": row,
		"pos": pos,
		"height": maxf(0.05, height),
		"amp": float(params.get("amplitude", 0.0)) * maxf(0.05, height) * 0.6,
		"live": true,
	})
	return i

## Builds the atlas and the MultiMeshes. Safe to call again after add() (a prop placed by hand).
func commit() -> void:
	var fresh := _items.size() != _shown
	if not _committed:
		_committed = true
		fresh = true
		_basis = _camera_basis()
		_basis_valid = _basis != Basis()
		_atlas = _build_atlas()
	for i in _items.size():
		var it := _items[i]
		if bool(it.get("live", true)) and _slot_of.has(i):
			continue
		var cell := _cell_key(it["pos"] as Vector3)
		var list: Array = _cell_items.get(cell, [])
		if not list.has(i):
			list.append(i)
			_cell_items[cell] = list
		if not _cells.has(cell):
			_cells[cell] = _make_cell(cell)
		_slot_of[i] = {"mmi": _cells[cell], "slot": -1}
	for key: Vector2i in _cells.keys():
		_build_cell(key)
	if fresh:
		_shown = 0
		for i in _items.size():
			if bool((_items[i] as Dictionary)["live"]):
				_shown += 1

func _make_cell(key: Vector2i) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "pc_%d_%d" % [key.x, key.y]
	mmi.multimesh = mm
	mmi.material_override = _material(false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = IsoCamera.cull_range(CELL_RANGE_M)
	mmi.position = Vector3((float(key.x) + 0.5) * CELL_M, 0.0, (float(key.y) + 0.5) * CELL_M)
	add_child(mmi)
	return mmi

func _build_cell(key: Vector2i) -> void:
	var mmi := _cells.get(key, null) as MultiMeshInstance3D
	if mmi == null:
		return
	var list: Array = _cell_items.get(key, [])
	var centre := mmi.position
	var tallest := 0.0
	var tall := false
	mmi.multimesh.instance_count = 0
	mmi.multimesh.instance_count = list.size()
	for s in list.size():
		var i := int(list[s])
		var it: Dictionary = _items[i]
		var row: Dictionary = it["row"]
		var id := str(row.get("id", ""))
		var rect: Dictionary = _rects.get(id, {})
		var halt := float(it["height"])
		tallest = maxf(tallest, halt)
		mmi.multimesh.set_instance_transform(s, Transform3D(_basis, (it["pos"] as Vector3) - centre))
		mmi.multimesh.set_instance_color(s, Color(
			CardProp.sprite_pivot_uv(row).x, CardProp.sprite_pivot_uv(row).y,
			float(it["amp"]), halt))
		mmi.multimesh.set_instance_custom_data(s, Color(
			float((rect.get("offset", Vector2.ZERO) as Vector2).x),
			float((rect.get("offset", Vector2.ZERO) as Vector2).y),
			float((rect.get("size", Vector2.ZERO) as Vector2).x),
			float((rect.get("size", Vector2.ZERO) as Vector2).y)))
		_slot_of[i] = {"mmi": mmi, "slot": s}
		if bool(it.get("live", true)) == false:
			mmi.multimesh.set_instance_transform(s, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
	if tallest >= Occlusion.TALL_M and not tall:
		tall = true
		mmi.material_override = _material(true)
		if Occlusion.enabled:
			Occlusion.auto_fade(mmi, tallest)

static var _quad_mesh: PlaneMesh
static func _quad() -> PlaneMesh:
	if _quad_mesh == null:
		_quad_mesh = PlaneMesh.new()
		_quad_mesh.orientation = PlaneMesh.FACE_Z
		_quad_mesh.size = Vector2.ONE
	return _quad_mesh

## The card material: one for short cards (no fade body, no instance uniform) and one for tall ones
## (the fade body, its per-instance shares coming from Occlusion's slots). `tall` is refused when
## Occlusion is off (web/Compatibility, or --no-occlusion): Compatibility's shader-variable buffer
## holds 1,024 items and reserves 16 per geometry instance with an instance uniform, so even a tall
## card must then compile with zero instance uniforms (CardProp._place uses the same rule).
func _material(tall: bool) -> ShaderMaterial:
	var fade := tall and Occlusion.enabled
	var key := "tall" if fade else "short"
	var cached := _mats.get(key, null) as ShaderMaterial
	if cached != null:
		return cached
	var lines := PackedStringArray()
	var skipping := false
	for line in SHADER_SRC.split("\n"):
		if line.contains("CARD_FADE_INCLUDE"):
			if not fade:
				continue
		elif line.contains("CARD_FADE_BEGIN"):
			skipping = true
			continue
		elif line.contains("CARD_FADE_END"):
			skipping = false
			continue
		elif skipping:
			continue
		lines.append(line)
	var sh := Shader.new()
	sh.code = "\n".join(lines)
	var m := ShaderMaterial.new()
	m.shader = sh
	if fade:
		Occlusion._ensure_driver()
	m.set_shader_parameter("atlas", _atlas)
	m.set_shader_parameter("tint", SCENERY_TINT)
	m.set_shader_parameter("sway_speed", SWAY_SPEED)
	_mats[key] = m
	return m

## Every distinct sprite the island uses, packed into one atlas: a grid of square tiles, each sprite
## scaled to fit its tile with a transparent gutter, bottom-aligned. `rects` gives the sprite's own
## UV rect inside the atlas.
func _build_atlas() -> ImageTexture:
	var ids: Array[String] = []
	for it in _items:
		var id := str((it["row"] as Dictionary).get("id", ""))
		if id != "" and not ids.has(id):
			ids.append(id)
	if ids.is_empty():
		return null
	var cols := int(ceil(sqrt(float(ids.size()))))
	var rows := int(ceil(float(ids.size()) / float(cols)))
	var img := Image.create(TILE_PX * cols, TILE_PX * rows, false, Image.FORMAT_RGBA8)
	var inner := TILE_PX - 2 * GUTTER_PX
	for i in ids.size():
		var row := CardProp.sprite(ids[i])
		var file := str(row.get("file", ""))
		if file == "" or not ResourceLoader.exists(file):
			continue
		var tex := load(file) as Texture2D
		if tex == null:
			continue
		var src := tex.get_image()
		if src == null or src.is_empty():
			continue
		if src.is_compressed():
			src.decompress()
		var pw := maxf(1.0, float(src.get_width()))
		var ph := maxf(1.0, float(src.get_height()))
		var scale := inner / maxf(pw, ph)
		var dw := maxi(1, int(round(pw * scale)))
		var dh := maxi(1, int(round(ph * scale)))
		var small := src.duplicate() as Image
		small.resize(dw, dh, Image.INTERPOLATE_LANCZOS)
		small.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(i % cols, i / cols)
		var ox := cell.x * TILE_PX + (TILE_PX - dw) / 2
		var oy := cell.y * TILE_PX + TILE_PX - GUTTER_PX - dh
		img.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(ox, oy))
		_rects[ids[i]] = {
			"offset": Vector2(float(ox) / float(img.get_width()), float(oy) / float(img.get_height())),
			"size": Vector2(float(dw) / float(img.get_width()), float(dh) / float(img.get_height())),
		}
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	return t

# ---------------------------------------------------------------- placement

func _cell_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_M), floori(pos.z / CELL_M))

func _camera_basis() -> Basis:
	if is_inside_tree():
		var tree := get_tree()
		var cam := tree.root.get_viewport().get_camera_3d() if tree != null and tree.root != null else null
		if cam != null:
			return cam.global_basis.orthonormalized()
	return IsoCamera.view_basis().orthonormalized()

func _process(_delta: float) -> void:
	if not _committed or not is_inside_tree():
		return
	var b := _camera_basis()
	if _basis_valid and b.is_equal_approx(_basis):
		return
	_basis = b
	_basis_valid = true
	for key: Vector2i in _cells.keys():
		_build_cell(key)

## Hides one card (a prop cleared by an attack or a building): the instance is scaled below a pixel,
## so no MultiMesh is rebuilt on a clear.
func set_shown(i: int, shown: bool) -> void:
	if i < 0 or i >= _items.size():
		return
	var it := _items[i]
	if bool(it["live"]) == shown:
		return
	it["live"] = shown
	_shown += 1 if shown else -1
	if not _committed:
		return
	var s: Dictionary = _slot_of.get(i, {})
	var mmi := s.get("mmi", null) as MultiMeshInstance3D
	var slot := int(s.get("slot", -1))
	if mmi == null or slot < 0:
		return
	if shown:
		mmi.multimesh.set_instance_transform(slot, Transform3D(_basis, (it["pos"] as Vector3) - mmi.position))
	else:
		mmi.multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))

## Whether card i is drawn (true until it is cleared).
func is_shown(i: int) -> bool:
	if i < 0 or i >= _items.size():
		return false
	return bool((_items[i] as Dictionary)["live"])

# ---------------------------------------------------------------- queries

func instance_count() -> int:
	return _items.size()

func shown_count() -> int:
	return _shown

## Cards whose texture did not load (the lab's grey_cards; 0 means every prop card has its art).
func grey_cards() -> int:
	var n := 0
	for it in _items:
		var file := str((it["row"] as Dictionary).get("file", ""))
		if file == "" or not ResourceLoader.exists(file) or not _rects.has(str((it["row"] as Dictionary).get("id", ""))):
			n += 1
	return n

## 3D meshes drawn as a prop visual (the PROPS2D rule: none; the only meshes here are card quads).
func model_meshes() -> int:
	var n := 0
	for c in get_children():
		if c is MeshInstance3D:
			n += 1
	return n

func tint() -> Color:
	return SCENERY_TINT

## Every MultiMeshInstance3D (one per 64 m cell), for the lab's draw-call read.
func cell_count() -> int:
	return _cells.size()
