extends SceneTree
## BIOMEPROPS acceptance: the biome props the island places must render correctly.
##
## Every kind in data/world/props.json that names a res://assets/nature/biome/*.glb model is checked:
##   - the file exists and loads as a scene with a MeshInstance3D that carries a material;
##   - that material takes its albedo from the vertex colour (COLOR_0), the only paint these models
##     carry (one Principled "biome_vcol" material, no texture: tools/blender/biome_props/bp_lib.py);
##   - the imported material treats COLOR_0 as sRGB, and the mesh really stores the authored sRGB
##     numbers - Godot's glTF importer sets vertex_color_is_srgb=true, so linear-stored data came out
##     double-darkened and every prop read as a grey/black slab on the deployed build;
##   - the mesh AABB fits the kind's declared radius_m: height between 0.5x and 3x of it, so a
##     prop's collider and its model describe the same object;
##   - island_props actually places the kind on the home island (a kind that never appears is a
##     broken row, not scenery).
## Run: Godot --headless --path game --script res://tests/t_biomeprops.gd -> "[t_biomeprops] PASS".
## Scripts are load()ed on the first frame: a --script file compiles before the autoloads exist.

const WATCHDOG_S := 180.0
const BIOME_DIR := "res://assets/nature/biome/"
## The kinds the owner reported missing, and that this job re-enables.
const REQUIRED := ["rock_spire", "mesa_cliff", "basalt_column", "termite_mound", "aloe"]
## Stored COLOR_0 is the authored sRGB palette; linear-stored data measured 0.02-0.05 mean luminance
## on basalt/obsidian and 0.13-0.18 on sandstone (the shipped bug). sRGB storage keeps every model
## well above this floor.
const MIN_MEAN_LUM := 0.15

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	var timer := create_timer(WATCHDOG_S)
	timer.timeout.connect(func () -> void:
		print("[t_biomeprops] FAIL watchdog %.0fs" % WATCHDOG_S)
		quit(2))
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_biomeprops] FAIL %s" % what)

func _run() -> void:
	_test_models()
	await _test_placement()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_biomeprops] PASS")
		quit(0)
	else:
		print("[t_biomeprops] FAIL count=%d" % _fails.size())
		quit(1)

## The kinds in props.json that name a biome model, and the models of each.
func _kinds() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/props.json"))
	var out := {}
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
			if str(m).begins_with(BIOME_DIR):
				mine.append(str(m))
		if not mine.is_empty():
			out[str(k)] = {"row": row, "models": mine}
	return out

func _test_models() -> void:
	var kinds := _kinds()
	_expect(not kinds.is_empty(), "props.json names at least one res://assets/nature/biome/ model")
	for k in REQUIRED:
		_expect(kinds.has(k), "props.json has the %s kind pointing at a biome model" % k)
	var checked := 0
	for kind: String in kinds:
		var row: Dictionary = kinds[kind]["row"]
		var radius := float(row.get("radius_m", 0.0))
		_expect(radius > 0.0, "%s declares a radius_m" % kind)
		var lo := 0.5 * radius
		var hi := 3.0 * radius
		for path: String in kinds[kind]["models"]:
			checked += 1
			_expect(ResourceLoader.exists(path), "%s: %s ships" % [kind, path])
			if not ResourceLoader.exists(path):
				continue
			var packed: Variant = load(path)
			_expect(packed is PackedScene, "%s: %s loads as a scene" % [kind, path])
			if not packed is PackedScene:
				continue
			var inst: Node = (packed as PackedScene).instantiate()
			var meshes := inst.find_children("*", "MeshInstance3D", true, false)
			_expect(not meshes.is_empty(), "%s: %s has a MeshInstance3D" % [kind, path])
			var h := 0.0
			var vcol := false
			var all_vcol := true
			var srgb_flag := true
			var mean_lum := 0.0
			var samples := 0
			for n in meshes:
				var mi := n as MeshInstance3D
				var mesh: Mesh = mi.mesh
				if mesh == null:
					all_vcol = false
					continue
				h = maxf(h, mesh.get_aabb().size.y)
				var has_colour: bool = (mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0
				for s in mesh.get_surface_count():
					var mat: Variant = mesh.surface_get_material(s)
					if not mat is BaseMaterial3D:
						all_vcol = false
						continue
					var bm := mat as BaseMaterial3D
					vcol = vcol or bm.vertex_color_use_as_albedo
					all_vcol = all_vcol and bm.vertex_color_use_as_albedo
					srgb_flag = srgb_flag and (bm.vertex_color_is_srgb or not bm.vertex_color_use_as_albedo)
				if has_colour and mesh.get_surface_count() > 0:
					var cols: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
					for c in cols:
						mean_lum += c.get_luminance()
						samples += 1
			_expect(all_vcol, "%s: %s takes its albedo from the vertex colour" % [kind, path])
			_expect(srgb_flag, "%s: %s reads COLOR_0 as sRGB, as the exporter now writes it" % [kind, path])
			_expect(samples > 0, "%s: %s carries a COLOR_0 attribute" % [kind, path])
			if samples > 0:
				mean_lum /= float(samples)
				_expect(mean_lum >= MIN_MEAN_LUM,
					"%s: %s stores sRGB paint, not linear (mean luminance %.3f < %.2f: the prop renders as a dark slab)" % [kind, path, mean_lum, MIN_MEAN_LUM])
			_expect(h >= lo and h <= hi,
				"%s: %s is %.2f m tall, outside 0.5x..3x of radius_m %.2f (%.2f..%.2f)" % [kind, path, h, radius, lo, hi])
			print("[t_biomeprops] %-13s %-46s h=%5.2f band=%4.2f..%4.2f vcol=%s lum=%.3f" % [kind, path.get_file(), h, lo, hi, all_vcol, mean_lum])
			inst.free()
	print("[t_biomeprops] models checked=%d kinds=%d" % [checked, kinds.size()])

## island_props places the re-enabled kinds. The home island is grassland, so its biome weights have
## no canyon/basalt ground: mesa_cliff and basalt_column only appear where props.json allows them
## (desert_35 = canyon, volcanic_60 = basalt). A kind that appears on none of the three is a dead row.
const ISLANDS := [&"home_grassland", &"desert_35", &"volcanic_60"]

func _test_placement() -> void:
	var host := Node3D.new()
	host.name = "TBiomePropsHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 6.0)
	(kit["nav"] as Node).queue_free()
	var world: Node = root.get_node("World")
	var anywhere := {}
	for id: StringName in ISLANDS:
		world.load_island(host, id, Vector3(0, 1, 18), false)
		await process_frame
		await physics_frame
		var rt: Node = world.runtime
		_expect(rt != null, "%s builds a runtime" % id)
		if rt == null:
			continue
		var props: Variant = rt.get("props")
		_expect(props != null, "%s builds the island_props layer" % id)
		if props == null:
			continue
		var placed := {}
		var biome_rows := 0
		for r in props.get("_rows"):
			var kind := str(r.get("kind", ""))
			if not str(r.get("path", "")).begins_with(BIOME_DIR):
				continue
			biome_rows += 1
			placed[kind] = int(placed.get(kind, 0)) + 1
			anywhere[kind] = int(anywhere.get(kind, 0)) + 1
			var batch: Variant = r.get("batch")
			var good := batch != null
			if good:
				good = (batch as VegBatch).cell_for(int(r.get("idx", -1))) != null
			_expect(good, "%s/%s: the placed prop is drawn by a batch cell" % [id, kind])
		print("[t_biomeprops] placed %s=%s" % [id, placed])
		_expect(biome_rows > 0, "%s places biome props at all (got %d)" % [id, biome_rows])
	print("[t_biomeprops] placed anywhere=%s" % anywhere)
	for k in REQUIRED:
		_expect(anywhere.has(k), "%s is placed by island_props somewhere (props.json row reaches the scatter)" % k)
	_expect(int(anywhere.get("aloe", 0)) >= 3, "aloe appears more than once (got %d)" % int(anywhere.get("aloe", 0)))
	host.queue_free()
