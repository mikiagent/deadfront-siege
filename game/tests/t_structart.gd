extends SceneTree
## Structure-set checks: every building kind resolves to a GLB; Blender GLBs import with the one
## shared atlas material, stay under 4k triangles, match the manifest AABB within 5 %, carry the
## named pivot nodes, and the four drying-rack stages are distinct models.
## Run: Godot --headless --path game --script res://tests/t_structart.gd

const ATLAS_MAT := "res://assets/props/blender/structures_atlas.tres"
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
