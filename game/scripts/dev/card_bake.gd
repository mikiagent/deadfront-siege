extends Node3D
## CARD2D bake tool (spec 25 §1). Renders every resource GLB in game/data/card2d.json through an
## orthographic camera at the IsoCamera angle into a transparent SubViewport and saves
##   game/assets/nature/cards/<name>_albedo.png   soft neutral light, alpha = the model's silhouette
##   game/assets/nature/cards/<name>_normal.png   view-space normals (R = x, G = y, B = z), so the
##                                                game's moving sun still shades the card like a 3D object
## trimmed to the content, power-of-two, 512 px for small props and 1024 px for trees, and records the
## ground pivot (normalized UV), the texture's metres per pixel / world size and the content box in
## card2d.json. Re-running is deterministic: fixed camera, fixed light, no randomness.
## Run: Godot --path game -- --lab=card_bake   (prints [cardbake] lines, then PASS)
## --only=<id,id> bakes a subset and leaves card2d.json alone.
## After a bake (new PNGs) run: Godot --headless --path game --import

const DATA_PATH := "res://data/card2d.json"
const OUT_DIR := "res://assets/nature/cards"
## Framing margin around the model's projected bounds, as a share of its larger side.
const MARGIN := 0.03
## Albedo alpha at or above this counts as content (the shader scissor is 0.5).
const ALPHA_CUT := 0.5

const NORMAL_SHADER := "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { ALBEDO = NORMAL * 0.5 + 0.5; }\n"

var _fails: PackedStringArray = []
var _decode := "srgb"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			for id in a.substr(7).split(","):
				only.append(id)
	await _bake_all(only)

func _bake_all(only: Array) -> void:
	var data: Dictionary = CardProp.data()
	var cards: Dictionary = data.get("cards", {})
	if cards.is_empty():
		print("[cardbake] FAIL no cards in %s" % DATA_PATH)
		get_tree().quit(1)
		return
	_decode = await _calibrate()
	print("[cardbake] normal decode=%s" % _decode)
	var done := 0
	var names: Array = cards.keys()
	names.sort()
	for id: String in names:
		if not only.is_empty() and not only.has(id):
			continue
		var row: Dictionary = cards[id]
		var path := str(row.get("model", ""))
		if not ResourceLoader.exists(path):
			_fails.append("%s: missing model %s" % [id, path])
			continue
		var res := int(row.get("resolution", 512))
		var one := await _bake_one(id, path, res)
		if one.is_empty():
			continue
		for k in one.keys():
			row[k] = one[k]
		cards[id] = row
		done += 1
		print("[cardbake] %-22s %dx%d pivot=(%.3f, %.3f) size=(%.2f, %.2f) m" % [
			id, int(row["texture"][0]), int(row["texture"][1]),
			float(row["pivot"][0]), float(row["pivot"][1]),
			float(row["world_size"][0]), float(row["world_size"][1])])
	if only.is_empty():
		_save(data)
	if _fails.is_empty():
		print("[cardbake] PASS cards=%d" % done)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[cardbake] FAIL %s" % f)
		get_tree().quit(1)

## One card: measure, render twice, trim, pad to power-of-two, save. Returns the card2d.json fields.
func _bake_one(id: String, path: String, res: int) -> Dictionary:
	var box := _bounds(path)
	if box.size.length() < 0.001:
		_fails.append("%s: empty model" % id)
		return {}
	# The game camera's own angle (an IsoCamera instance, nothing hard-coded), so a camera change
	# only needs a re-bake.
	var basis := _camera_basis()
	var right := basis.x
	var up := basis.y
	var fwd := -basis.z
	# Projected bounds of the box's eight corners.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var c := box.get_endpoint(i)
		lo = Vector2(minf(lo.x, c.dot(right)), minf(lo.y, c.dot(up)))
		hi = Vector2(maxf(hi.x, c.dot(right)), maxf(hi.y, c.dot(up)))
	var mid := (lo + hi) * 0.5
	var span := maxf(hi.x - lo.x, hi.y - lo.y)
	var cam_size := span * (1.0 + MARGIN * 2.0)
	var mpp := cam_size / float(res)
	var origin_uv := Vector2(Vector3.ZERO.dot(right), Vector3.ZERO.dot(up))
	var origin_px := Vector2((origin_uv.x - mid.x) / mpp + res * 0.5, -(origin_uv.y - mid.y) / mpp + res * 0.5)
	var cam_pos := right * mid.x + up * mid.y - fwd * 40.0
	var albedo := await _render(path, res, cam_pos, basis, cam_size, false)
	var normal := await _render(path, res, cam_pos, basis, cam_size, true)
	if albedo == null or normal == null:
		_fails.append("%s: render failed" % id)
		return {}
	var bbox := _alpha_box(albedo)
	if bbox.size.x < 1 or bbox.size.y < 1:
		_fails.append("%s: the render is empty (nothing visible at the iso angle)" % id)
		return {}
	var pw := _pot(bbox.size.x)
	var ph := _pot(bbox.size.y)
	var canvas := _blank(pw, ph, Color(0, 0, 0, 0))
	canvas.blit_rect(albedo.get_region(bbox), Rect2i(Vector2i.ZERO, bbox.size), Vector2i.ZERO)
	var ncanvas := _blank(pw, ph, Color(0.5, 0.5, 1.0, 1.0))
	ncanvas.blit_rect(normal.get_region(bbox), Rect2i(Vector2i.ZERO, bbox.size), Vector2i.ZERO)
	var ea := canvas.save_png(CardProp.albedo_path(id))
	var en := ncanvas.save_png(CardProp.normal_path(id))
	if ea != OK or en != OK:
		_fails.append("%s: cannot save PNGs (albedo=%d normal=%d)" % [id, ea, en])
		return {}
	var px_pivot := origin_px - Vector2(bbox.position)
	return {
		"pivot": [snappedf(clampf(px_pivot.x / float(pw), 0.0, 1.0), 0.0001), snappedf(clampf(px_pivot.y / float(ph), 0.0, 1.0), 0.0001)],
		"world_size": [snappedf(float(pw) * mpp, 0.001), snappedf(float(ph) * mpp, 0.001)],
		"content": {"x": bbox.position.x, "y": bbox.position.y, "w": bbox.size.x, "h": bbox.size.y, "mpp": snappedf(mpp, 0.00001)},
		"texture": [pw, ph],
		"resolution": res,
	}

## The basis of the game camera: an IsoCamera node is stood up once and read, so the bake follows
## any change to the camera script's angle without duplicating it here.
var _basis_cache: Basis = Basis()
func _camera_basis() -> Basis:
	if _basis_cache == Basis():
		var cam := IsoCamera.new()
		add_child(cam)
		_basis_cache = cam.global_basis.orthonormalized()
		cam.queue_free()
	return _basis_cache

## Renders one pass of one model: albedo (neutral light, transparent sky) or view-space normals.
func _render(path: String, res: int, cam_pos: Vector3, basis: Basis, cam_size: float, normals: bool) -> Image:
	var packed := load(path)
	if not packed is PackedScene:
		return null
	var model: Node3D = (packed as PackedScene).instantiate() as Node3D
	if model == null:
		return null
	model.transform = Transform3D.IDENTITY
	var vp := SubViewport.new()
	vp.size = Vector2i(res, res)
	vp.own_world_3d = true
	vp.transparent_bg = not normals
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0, 0, 0, 0) if not normals else Color(0, 0, 0, 1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.ssao_enabled = false
	e.glow_enabled = false
	e.fog_enabled = false
	e.adjustment_enabled = false
	env.environment = e
	vp.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cam_size
	cam.near = 0.05
	cam.far = 200.0
	cam.transform = Transform3D(basis, cam_pos)
	vp.add_child(cam)
	cam.current = true
	if normals:
		var nm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = NORMAL_SHADER
		nm.shader = sh
		for gi in model.find_children("*", "MeshInstance3D", true, false):
			(gi as MeshInstance3D).material_override = nm
	else:
		# Soft neutral key light from the camera's upper left, so faces read as volume, not flat cutouts.
		var sun := DirectionalLight3D.new()
		var light_basis := Basis.from_euler(Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0))
		sun.transform = Transform3D(light_basis, Vector3(0, 20, 0))
		sun.light_color = Color(1.0, 0.98, 0.95)
		sun.light_energy = 1.15
		sun.shadow_enabled = false
		vp.add_child(sun)
	vp.add_child(model)
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	if normals:
		if _decode == "srgb":
			img.srgb_to_linear()
		_to_card_tangent(img)
	return img

## The normal pass stores the view-space normal (camera basis: x right, y up, z towards the viewer),
## but a material's NORMAL_MAP is tangent space: the card's own quad is the surface, so the map must
## be relative to it. This rewrites each texel as (along tangent, along bitangent, along the card's
## normal), with z made positive so thin foliage is lit two-sided instead of going black on every
## leaf that faces away from the camera. The quad's handedness is read from a real PlaneMesh, not
## assumed.
func _to_card_tangent(img: Image) -> void:
	var sign_b := _bitangent_sign()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var n := Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b * 2.0 - 1.0)
			var ts := Vector3(n.x, n.y * sign_b, absf(n.z))
			img.set_pixel(x, y, Color(ts.x * 0.5 + 0.5, ts.y * 0.5 + 0.5, ts.z * 0.5 + 0.5, 1.0))

## +1/-1: does the quad's bitangent point along the camera's up? PlaneMesh FACE_Z's UVs and
## tangents decide it, so the map matches whatever mesh CardProp draws.
var _sign_b := 0.0
func _bitangent_sign() -> float:
	if _sign_b != 0.0:
		return _sign_b
	var pm := PlaneMesh.new()
	pm.orientation = PlaneMesh.FACE_Z
	var arr := pm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
	var normal := Vector3.BACK
	var tangent := Vector3(tangents[0], tangents[1], tangents[2])
	var w := tangents[3]
	var bitangent := normal.cross(tangent) * w
	# Texture v grows towards the quad's -Y in Godot's UV convention; the map's y follows the
	# bitangent, so compare the two directly.
	_sign_b = -1.0 if bitangent.y < 0.0 else 1.0
	print("[cardbake] quad tangent=%s bitangent=%s sign=%+.0f" % [tangent, bitangent, _sign_b])
	return _sign_b

## Which colour space the normal pass lands in: a plane turned 45° about Y should encode its
## view-space normal (0.707, 0, 0.707) as R = 0.854 linear; an sRGB target stores 0.933.
func _calibrate() -> String:
	var vp := SubViewport.new()
	vp.size = Vector2i(16, 16)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.background_color = Color(0, 0, 0, 1)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.glow_enabled = false
	env.environment = e
	vp.add_child(env)
	var quad := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	pm.orientation = PlaneMesh.FACE_Z
	quad.mesh = pm
	var nm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = NORMAL_SHADER
	nm.shader = sh
	quad.material_override = nm
	quad.rotation = Vector3(0.0, deg_to_rad(45.0), 0.0)
	vp.add_child(quad)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	cam.far = 100.0
	cam.position = Vector3(0, 0, 10)
	vp.add_child(cam)
	cam.current = true
	for i in 2:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null:
		return "srgb"
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_pixel(8, 8)
	print("[cardbake] calibration pixel=(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
	return "linear" if absf(c.r - 0.8536) < 0.05 else "srgb"

## World-space bounds of every mesh in a model scene (the model's root transform included).
func _bounds(path: String) -> AABB:
	var packed := load(path)
	if not packed is PackedScene:
		return AABB()
	var inst: Node = (packed as PackedScene).instantiate()
	add_child(inst)
	var box := AABB()
	var first := true
	for gi in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := gi as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	inst.queue_free()
	return box

func _blank(w: int, h: int, fill: Color) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img

func _alpha_box(img: Image) -> Rect2i:
	var minx := img.get_width()
	var miny := img.get_height()
	var maxx := -1
	var maxy := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= ALPHA_CUT:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	if maxx < minx:
		return Rect2i()
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

## Smallest power of two >= n (at least 1, at most 2048).
func _pot(n: int) -> int:
	var p := 1
	while p < n and p < 2048:
		p *= 2
	return p

## Writes card2d.json back with the baked fields, sorted so a re-run gives the same bytes.
func _save(data: Dictionary) -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if f == null:
		_fails.append("cannot write %s" % DATA_PATH)
		return
	f.store_string(JSON.stringify(data, "  ", true) + "\n")
