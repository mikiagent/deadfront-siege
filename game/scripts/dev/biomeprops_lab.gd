extends Node3D
## BIOMEPROPS lab: every biome prop kind the island places, standing in one row on the home island,
## shot with the game camera. Two frames are saved (a wide row and a close pass over the two biggest
## landforms) and one `[biomeprops] RESULT ...` line is printed, measured from the live scene.
##
## Windowed: Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##   --lab=biomeprops_lab --shot-dir=DIR
## Needs a window: headless never fires RenderingServer.frame_post_draw, so the PNGs below cannot be
## taken there. The headless acceptance for the same facts is game/tests/t_biomeprops.gd.
##
## RESULT keys:
##   kinds         biome kinds listed in props.json (a kind whose models are all res:// biome GLBs)
##   vcol_ok       kinds whose drawn model takes its albedo from COLOR_0
##   scale_ok      kinds whose drawn model's AABB height sits in 0.5x..3x of its radius_m
##   placed        kinds actually placed by island_props on the home island
##   missing_files model paths in props.json that do not exist
##   lum_min       darkest mean luminance across the kinds' stored vertex paint (a linear-stored
##                 build reads ~0.04-0.18 here, i.e. the grey/black slabs the owner saw)

const KIND_GAP := 9.0
const ROW_Z := -12.0
const OUT_PREFIX := "biomeprops"

var _shot_dir := ""
var _kinds: Dictionary = {}
var _rows: Array[Dictionary] = []
var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
	if _shot_dir == "":
		_shot_dir = "user://biomeprops_shots"
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 90.0)
	_player = kit["player"]
	_cam = kit["cam"]
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	Game.debug_overlay = false
	(kit["nav"] as Node).queue_free()
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	print("[boot] lab=biomeprops_lab")
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var rt: Node = World.runtime
	if rt == null:
		print("[biomeprops] RESULT kinds=0 vcol_ok=0 scale_ok=0 placed=0 missing_files=0 lum_min=0")
		get_tree().quit(1)
		return
	_kinds = _biome_kinds()
	var placed_kinds := _placed_kinds(rt)
	var missing := 0
	var vcol_ok := 0
	var scale_ok := 0
	var lum_min := 9.9
	var ground := rt.call("surface_y", 0.0, ROW_Z) as float
	var i := 0
	var names: Array[String] = []
	for k in _kinds:
		names.append(k)
	names.sort()
	for kind in names:
		var row: Dictionary = _kinds[kind]
		var paths: Array = row["models"]
		var path := str(paths[0])
		if not ResourceLoader.exists(path):
			missing += 1
			continue
		var radius := float((row["row"] as Dictionary).get("radius_m", 1.0))
		var info := _model_info(path)
		if float(info["height"]) >= 0.5 * radius and float(info["height"]) <= 3.0 * radius:
			scale_ok += 1
		lum_min = minf(lum_min, float(info["lum"]))
		var at := Vector3(-KIND_GAP * (names.size() - 1) * 0.5 + KIND_GAP * i, ground, ROW_Z)
		var batch := VegBatch.get_for(self, path)
		if batch == null:
			continue
		if bool(info["vcol"]):
			vcol_ok += 1
		var longest := maxf(0.05, float(info["longest"]))
		# ASSUMPTION: drawn at the middle of its size_m range, as island_props does.
		var size_m: Array = (row["row"] as Dictionary).get("size_m", [2.0, 2.0])
		var want := (float(size_m[0]) + float(size_m[1])) * 0.5
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (want / longest)), at)
		batch.add(xf)
		var label := Label3D.new()
		label.text = "%s\n%.1fm r=%.1f" % [kind, float(info["height"]) * (want / longest), radius]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.012
		label.modulate = Color(0.06, 0.06, 0.08)
		label.position = at + Vector3(0, 3.2, 5.0)
		add_child(label)
		_rows.append({"kind": kind, "path": path, "xf": xf})
		i += 1
	for b in get_children():
		if b is VegBatch:
			(b as VegBatch).commit()
	_player.global_position = Vector3(0, ground + 1.0, ROW_Z + 16.0)
	_cam.size = maxf(24.0, KIND_GAP * float(names.size()) * 0.42)
	_cam._snap()
	await _settle()
	await _save(OUT_PREFIX + "_row.png")
	# Close pass over the two biggest landforms, so the vertex paint is readable at detail.
	var big: Array[Dictionary] = []
	for r in _rows:
		if r["kind"] in ["mesa_cliff", "cliff_rock", "rock_spire", "basalt_column"]:
			big.append(r)
	for r in big:
		_player.global_position = (r["xf"] as Transform3D).origin + Vector3(0, 1.0, 7.0)
		_cam._snap()
		await _settle()
		await _save(OUT_PREFIX + "_%s.png" % str(r["kind"]))
		break
	var line := "[biomeprops] RESULT kinds=%d vcol_ok=%d scale_ok=%d placed=%d missing_files=%d lum_min=%.3f" % [
		_kinds.size(), vcol_ok, scale_ok, placed_kinds, missing, lum_min]
	print(line)
	get_tree().quit(0)

## True when there is no window to draw into: frame_post_draw never fires headless, so the run
## measures and prints like the test would, without the PNGs (used for a quick check from a shell).
func _headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _settle() -> void:
	for i in 12:
		await get_tree().process_frame

func _save(name: String) -> void:
	if _headless():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("[biomeprops] no frame to save (headless?)")
		return
	var path := _shot_dir.path_join(name)
	img.save_png(path)
	print("[biomeprops] shot %s %s" % [path, img.get_size()])

## Kinds in props.json whose models are res://assets/nature/biome/*.glb, with their row.
func _biome_kinds() -> Dictionary:
	var out := {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/props.json"))
	if not d is Dictionary:
		return out
	var kinds: Variant = (d as Dictionary).get("kinds", {})
	if not kinds is Dictionary:
		return out
	for k in (kinds as Dictionary):
		var row: Variant = (kinds as Dictionary)[k]
		if not row is Dictionary:
			continue
		var models: Variant = (row as Dictionary).get("models", [])
		if not models is Array:
			continue
		var mine: Array[String] = []
		for m in models:
			if str(m).begins_with("res://assets/nature/biome/"):
				mine.append(str(m))
		if not mine.is_empty():
			out[str(k)] = {"row": row, "models": mine}
	return out

## How many of those kinds island_props actually placed on this island.
func _placed_kinds(rt: Node) -> int:
	var props: Variant = rt.get("props")
	if props == null:
		return 0
	var seen := {}
	for r in props.get("_rows"):
		if str(r.get("path", "")).begins_with("res://assets/nature/biome/"):
			seen[str(r.get("kind", ""))] = true
	return seen.size()

## Measured facts of one model file: AABB height/longest side, vertex-colour albedo, and the mean
## luminance of its stored COLOR_0.
func _model_info(path: String) -> Dictionary:
	var out := {"height": 0.0, "longest": 1.0, "vcol": false, "lum": 0.0}
	var packed: Variant = load(path)
	if not packed is PackedScene:
		return out
	var inst: Node = (packed as PackedScene).instantiate()
	var lum := 0.0
	var n := 0
	var vcol := true
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		var size := mesh.get_aabb().size
		out["height"] = maxf(float(out["height"]), size.y)
		out["longest"] = maxf(float(out["longest"]), maxf(size.x, maxf(size.y, size.z)))
		for s in mesh.get_surface_count():
			var mat: Variant = mesh.surface_get_material(s)
			vcol = vcol and mat is BaseMaterial3D and (mat as BaseMaterial3D).vertex_color_use_as_albedo
		if mesh.get_surface_count() > 0 and (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0:
			var cols: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			for c in cols:
				lum += c.get_luminance()
				n += 1
	out["vcol"] = vcol
	out["lum"] = lum / float(n) if n > 0 else 0.0
	inst.free()
	return out
