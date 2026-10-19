class_name BiomeLab
extends Node3D
## One 40x40 m ground patch per climate under the main scene's shared sun and environment.
## Windowed: writes <out>/biome_<climate>.png, prints each patch's mean ground RGB and the
## pairwise distances, then PASS/FAIL. Headless renders nothing, so it only builds the materials.
##   --lab=biome_lab -- --biome-out=<dir>   (default user://runs/biome_lab)

const PATCH := 40.0
const GRID := 80
const MIN_DIST := 0.08
## Pairs the spec allows to look alike.
const ALIKE := [["tropical", "blue_tropical"], ["tundra", "snowfield"]]

var _mesh: MeshInstance3D
var _cam: Camera3D

func _ready() -> void:
	_hide_overlays()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _patch_mesh()
	add_child(_mesh)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 20.0  # 35.5 x 20 m view at 16:9: only ground in frame
	_cam.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	_cam.position = Vector3(0.0, 1.0, 0.0) + _cam.basis.z * 40.0
	_cam.far = 200.0
	add_child(_cam)
	_cam.current = true
	_run.call_deferred()

func _hide_overlays() -> void:
	var host := get_parent()
	if host and host.get_node_or_null("UI") is CanvasLayer:
		(host.get_node("UI") as CanvasLayer).visible = false
	var perf := Game.get_node_or_null("PerfHud") as CanvasLayer
	if perf:
		perf.visible = false

func _run() -> void:
	var out := "user://runs/biome_lab"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome-out="):
			out = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out)
	var tile_map := _tile_map()
	var means := {}
	var headless := DisplayServer.get_name() == "headless"
	for climate in BiomeMaterial.climates():
		_mesh.material_override = BiomeMaterial.terrain(climate, PATCH, tile_map)
		if headless:
			continue
		for i in 4:  # let textures stream and the shadow map settle
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/biome_%s.png" % [out, climate])
		means[climate] = _mean(img)
		var m: Color = means[climate]
		print("[biome_lab] %s mean=(%.3f, %.3f, %.3f)" % [climate, m.r, m.g, m.b])
	if headless:
		print("[biome_lab] headless: built %d materials, no pixels" % BiomeMaterial.climates().size())
		get_tree().quit(0)
		return
	var fails := 0
	var keys: Array = means.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Color = means[keys[i]]
			var b: Color = means[keys[j]]
			var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			var exempt := _alike(keys[i], keys[j])
			if d < MIN_DIST and not exempt:
				fails += 1
				print("[biome_lab] FAIL %s/%s dist=%.3f" % [keys[i], keys[j], d])
			elif d < 0.15:
				print("[biome_lab] close %s/%s dist=%.3f%s" % [keys[i], keys[j], d, " (allowed)" if exempt else ""])
	print("[biome_lab] %s %d patches, %d pairs under %.2f" % ["PASS" if fails == 0 else "FAIL", keys.size(), fails, MIN_DIST])
	get_tree().quit(0 if fails == 0 else 1)

func _alike(a: String, b: String) -> bool:
	for pair in ALIKE:
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			return true
	return false

func _mean(img: Image) -> Color:
	var small := img.duplicate() as Image
	small.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
	sum /= float(small.get_width() * small.get_height())
	return Color(sum.x, sum.y, sum.z)

## Mostly flat ground at 1 m (the ground band), a mound for the dry and rock slope bands and a
## shore on +x down to the shallows.
func _height(x: float, z: float) -> float:
	var h := 1.0
	h += 3.2 * exp(-(Vector2(x + 9.0, z + 3.0).length_squared()) / 14.0)
	h -= clampf((x - 11.0) / 5.0, 0.0, 1.0) * 1.4
	return h

func _patch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := PATCH / float(GRID)
	for zi in GRID:
		for xi in GRID:
			var x0 := -PATCH * 0.5 + xi * step
			var z0 := -PATCH * 0.5 + zi * step
			var quad := [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				st.set_color(Color.WHITE)
				st.add_vertex(Vector3(p.x, _height(p.x, p.y), p.y))
	st.generate_normals()
	return st.commit()

## Tile ids as island_runtime stamps them: a dirt square (2) and a mud strip (6), so the
## override layers show too.
func _tile_map() -> ImageTexture:
	var n := int(PATCH)
	var img := Image.create(n, n, false, Image.FORMAT_R8)
	img.fill(Color.BLACK)
	for z in range(24, 30):
		for x in range(6, 12):
			img.set_pixel(x, z, Color(2.0 / 255.0, 0.0, 0.0))
	for z in range(10, 13):
		for x in range(14, 26):
			img.set_pixel(x, z, Color(6.0 / 255.0, 0.0, 0.0))
	return ImageTexture.create_from_image(img)
