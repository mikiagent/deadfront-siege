extends SceneTree
## FORGEART: every placeable kind resolves to a real model, never the fallback box (the forge and
## anvil W2-DATA added had no props_manifest row and placed as a box). The forge and anvil stations
## attach their Blender GLBs by data, take the kit's footprint, stand at survivor scale, and the
## forge's ember bed faces the iso camera.
## Run: Godot --headless --path game --script res://tests/t_forgeart.gd

const STATIONS := ["forge", "anvil"]
const EMBER_TILE := 23  # lib.TILES index of "ember" in the 8x8 structures atlas
const GRID := 8
const MIN_EMBER_M2 := 0.12  # camera-projected glowing area: the ember bed, not a stray coal

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
	_check_placeables(data)
	for kind: String in STATIONS:
		_check_station(data, StringName(kind))
	_check_ember_faces_camera()
	if failures.is_empty():
		print("[t_forgeart] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_forgeart] FAIL %s" % f)
		quit(1)
	return true

func _check_placeables(data: Node) -> void:
	var pv: GDScript = load("res://scripts/world/prop_visuals.gd")
	var n := 0
	for id: StringName in data.get("items"):
		var kind: StringName = data.call("item", id).place_as
		if kind == &"":
			continue
		n += 1
		var path := str(pv.call("model_path", kind))
		if path == "" or not ResourceLoader.exists(path):
			failures.append("%s (place_as %s) resolves to no model and places as the fallback box" % [id, kind])
	print("[t_forgeart] %d placeable kits checked" % n)

func _check_station(data: Node, kind: StringName) -> void:
	var station: Node3D = (load("res://scripts/world/craft_station.gd") as GDScript).call("make", kind)
	get_root().add_child(station)
	var prop := station.get_node_or_null("Prop") as Node3D
	var glb := str(((data.get("props_manifest") as Dictionary).get("buildings", {}).get(str(kind), {}) as Dictionary).get("glb", ""))
	if prop == null or station.get_node_or_null("FallbackMesh") != null:
		failures.append("%s placed without its model (FallbackMesh box)" % kind)
	elif not glb.begins_with("res://assets/props/blender/") or prop.scene_file_path != glb:
		failures.append("%s shows %s, not its Blender GLB %s" % [kind, prop.scene_file_path, glb])
	var kit: Variant = data.call("item", StringName("%s_kit" % kind))
	var fp: Vector2i = (load("res://scripts/world/prop_visuals.gd") as GDScript).call("footprint", kind)
	if kit == null or fp != kit.footprint:
		failures.append("%s footprint %s, kit says %s" % [kind, fp, kit.footprint if kit else "no kit"])
	# Scale against the survivor (data/characters/survivor.json height_meters): the chimney clears
	# his head, the anvil face sits near knuckle height.
	var tall := float((JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/survivor.json")) as Dictionary).get("height_meters", 1.78))
	var h := _aabb(prop, Transform3D.IDENTITY).size.y if prop else 0.0
	var lo := tall * 1.2 if kind == &"forge" else tall * 0.4
	var hi := tall * 1.8 if kind == &"forge" else tall * 0.55
	if h < lo or h > hi:
		failures.append("%s is %.2f m tall, want %.2f-%.2f m next to the %.2f m survivor" % [kind, h, lo, hi, tall])
	print("[t_forgeart] %s model %s footprint %s height %.2f m (survivor %.2f m)" % [kind, glb.get_file(), fp, h, tall])
	station.free()

## Area of ember-tile faces turned to the iso camera (pitch -35.264, yaw 45), projected.
func _check_ember_faces_camera() -> void:
	var to_cam := Basis.from_euler(Vector3(deg_to_rad(-35.264), deg_to_rad(45.0), 0.0)).z
	var root := (load("res://assets/props/blender/forge.glb") as PackedScene).instantiate() as Node3D
	var area := 0.0
	for mi: MeshInstance3D in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			for t in range(0, idx.size(), 3):
				var c := (uv[idx[t]] + uv[idx[t + 1]] + uv[idx[t + 2]]) / 3.0
				if int(c.y * GRID) * GRID + int(c.x * GRID) != EMBER_TILE:
					continue
				var cr := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]) * 0.5
				area += maxf(0.0, cr.dot(to_cam))
	root.free()
	print("[t_forgeart] forge ember bed faces the camera: %.2f m2 (min %.2f)" % [area, MIN_EMBER_M2])
	if area < MIN_EMBER_M2:
		failures.append("forge ember bed shows %.2f m2 to the camera (min %.2f)" % [area, MIN_EMBER_M2])

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
