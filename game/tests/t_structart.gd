extends SceneTree
## Structure-set checks: every building kind resolves to a GLB; Blender GLBs import with the one
## shared atlas material, stay under 4k triangles, match the manifest AABB within 5 %, carry the
## named pivot nodes, and the four drying-rack stages are distinct models.
## Run: Godot --headless --path game --script res://tests/t_structart.gd

const ATLAS_MAT := "res://assets/props/blender/structures_atlas.tres"
const ATLAS_PNG := "res://assets/props/blender/structures_atlas.png"
const GRID := 8
## Atlas tile order (lib.TILES); only the tiles the stage check reads.
const TILE_INDEX := {"wood": 0, "bark": 3, "meat_raw": 24, "meat_drying": 25, "meat_dried": 26}
## Owner rule: the stages must read by value, not hue alone. Minimum Rec.709 luma steps between
## tile means, and dried must stay clear of the rack's own bark poles.
const STAGE_LUMA_STEP := 10.0
const DRIED_VS_FRAME := 20.0
const STAND_INS := ["floor", "wall", "wall_doorway", "roof"]
const MAX_TRIS := 4000
const TOL := 0.05

var failures: Array[String] = []
var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	# Data is an autoload; `--script` compiles this before singletons exist.
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	var data: Node = get_root().get_node("Data")
	var buildings: Dictionary = (data.get("props_manifest") as Dictionary).get("buildings", {})
	_check_rows(buildings)
	_check_stages(buildings)
	_check_pivots(buildings)
	_check_atlas()
	_check_replacement_marks(buildings)
	if failures.is_empty():
		print("[t_structart] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_structart] FAIL %s" % f)
		quit(1)
	return true

func _check_rows(buildings: Dictionary) -> void:
	var blender := 0
	for kind: String in buildings:
		var row: Dictionary = buildings[kind]
		var glb := str(row.get("glb", ""))
		if glb == "":
			var model := str(row.get("model", ""))
			if model == "" or not ResourceLoader.exists("res://assets/props/kenney/%s.glb" % model):
				failures.append("%s resolves to no GLB" % kind)
			elif str(row.get("art_status", "")) != "REPLACE":
				failures.append("%s uses a Kenney placeholder without art_status REPLACE" % kind)
			continue
		blender += 1
		_check_glb(kind, glb, row.get("aabb_m", []))
	if blender < 20:
		failures.append("only %d kinds use Blender GLBs" % blender)

func _check_glb(kind: String, path: String, aabb_m: Variant) -> void:
	if not ResourceLoader.exists(path):
		failures.append("%s: %s missing" % [kind, path])
		return
	var root := (load(path) as PackedScene).instantiate() as Node3D
	var tris := 0
	var mats := {}
	for mi: MeshInstance3D in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			tris += (idx as PackedInt32Array).size() / 3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			var m := mi.get_active_material(s)
			mats[m.resource_path if m else "<none>"] = true
	if tris > MAX_TRIS:
		failures.append("%s: %d tris" % [kind, tris])
	if mats.size() != 1 or not mats.has(ATLAS_MAT):
		failures.append("%s: materials %s, want only %s" % [kind, mats.keys(), ATLAS_MAT])
	var size := _aabb(root, Transform3D.IDENTITY).size
	if aabb_m is Array and (aabb_m as Array).size() >= 3:
		var want := Vector3(float(aabb_m[0]), float(aabb_m[1]), float(aabb_m[2]))
		for k in 3:
			if absf(size[k] - want[k]) > TOL * maxf(want[k], 0.2):
				failures.append("%s: AABB %s vs manifest %s" % [kind, size, want])
				break
	else:
		failures.append("%s: no aabb_m" % kind)
	root.free()

func _check_stages(buildings: Dictionary) -> void:
	var row: Dictionary = buildings.get("drying_rack", {})
	var stages: Array = row.get("stages", [])
	var ids: Array[String] = []
	var uvs: Array[PackedVector2Array] = []
	for st: Dictionary in stages:
		ids.append(str(st.get("id", "")))
		_check_glb("drying_rack." + str(st.get("id", "")), str(st.get("glb", "")), row.get("aabb_m", []))
		var root := (load(str(st.get("glb", ""))) as PackedScene).instantiate() as Node3D
		var all_uv := PackedVector2Array()
		for mi: MeshInstance3D in _meshes(root):
			all_uv.append_array(mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] as PackedVector2Array)
		uvs.append(all_uv)
		root.free()
	if ids != ["empty", "raw", "drying", "dried"]:
		failures.append("drying_rack stages %s" % [ids])
		return
	# Raw, drying and dried hang the same strips; a stage only reads if its UVs (atlas tile) differ.
	for i in range(1, 4):
		for j in range(i + 1, 4):
			if uvs[i] == uvs[j]:
				failures.append("drying_rack %s and %s look identical" % [ids[i], ids[j]])
	if uvs[0].size() >= uvs[1].size():
		failures.append("empty drying rack is not lighter than the raw stage")
	print("[t_structart] drying_rack stages %s distinct" % [ids])

func _check_pivots(buildings: Dictionary) -> void:
	for pair: Array in [["fence_gate", "LeafL"], ["fence_gate", "LeafR"], ["catapult", "Arm"]]:
		var path := str((buildings.get(pair[0], {}) as Dictionary).get("glb", ""))
		if path == "" or not ResourceLoader.exists(path):
			failures.append("%s glb missing" % pair[0])
			continue
		var root := (load(path) as PackedScene).instantiate() as Node3D
		var n := root.find_child(pair[1], true, false) as Node3D
		if n == null:
			failures.append("%s has no %s node" % [pair[0], pair[1]])
		elif n.position.length() < 0.3:
			failures.append("%s/%s origin %s is not on its hinge/axle" % [pair[0], pair[1], n.position])
		root.free()

func _check_atlas() -> void:
	# Without mipmaps the grain aliases and shimmers at iso distance (the pier deck went moire).
	var tex := load(ATLAS_PNG) as Texture2D
	if tex == null or not tex.get_image().has_mipmaps():
		failures.append("%s imported without mipmaps" % ATLAS_PNG)
	var img := Image.load_from_file(ProjectSettings.globalize_path(ATLAS_PNG))
	if img == null:
		failures.append("cannot read %s" % ATLAS_PNG)
		return
	var luma := {}
	for tile: String in TILE_INDEX:
		luma[tile] = _tile_luma(img, int(TILE_INDEX[tile]))
	var order := ["meat_raw", "meat_drying", "meat_dried"]
	for i in range(order.size() - 1):
		if float(luma[order[i]]) - float(luma[order[i + 1]]) < STAGE_LUMA_STEP:
			failures.append("%s luma %.0f is not clearly darker than %s %.0f" % [order[i + 1], luma[order[i + 1]], order[i], luma[order[i]]])
	if float(luma["bark"]) - float(luma["meat_dried"]) < DRIED_VS_FRAME:
		failures.append("dried strips (luma %.0f) camouflage against the bark frame (%.0f)" % [luma["meat_dried"], luma["bark"]])
	print("[t_structart] stage luma raw %.0f drying %.0f dried %.0f, frame bark %.0f" % [luma["meat_raw"], luma["meat_drying"], luma["meat_dried"], luma["bark"]])

func _tile_luma(img: Image, index: int) -> float:
	var tile := img.get_width() / GRID
	var x0 := (index % GRID) * tile
	var y0 := (index / GRID) * tile
	var sum := 0.0
	var n := 0
	for y in range(y0, y0 + tile, 2):
		for x in range(x0, x0 + tile, 2):
			var c := img.get_pixel(x, y)  # PNG values are sRGB-encoded, which is what the review measured
			sum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			n += 1
	return sum / n * 255.0

func _check_replacement_marks(buildings: Dictionary) -> void:
	# Owner rule (2026-10-19): low-quality / low-poly assets are marked for replacement.
	for kind: String in STAND_INS:
		if str((buildings.get(kind, {}) as Dictionary).get("art_status", "")) != "REPLACE":
			failures.append("building-system stand-in %s is not marked REPLACE" % kind)
	for kind: String in buildings:
		var row: Dictionary = buildings[kind]
		if str(row.get("glb", "")) != "" and str(row.get("upgrade", "")) == "":
			failures.append("%s: low-poly Blender row has no upgrade path" % kind)

## Same corner-transform measure PropVisuals uses for colliders, kept local so this test does not
## depend on W1-BUILD's file.
func _aabb(n: Node, parent: Transform3D) -> AABB:
	var xf := parent * (n as Node3D).transform if n is Node3D else parent
	var box := AABB()
	var have := false
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		box = xf * (n as MeshInstance3D).mesh.get_aabb()
		have = true
	for c in n.get_children():
		var cb := _aabb(c, xf)
		if cb.size != Vector3.ZERO:
			box = box.merge(cb) if have else cb
			have = true
	return box

func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
