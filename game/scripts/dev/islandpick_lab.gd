extends Node3D
## ISLANDPICK measuring lab (windowed; the pick screen needs a renderer for the shots).
## Opens the real Tamed Island pick over a bare host, measures what is on screen, saves shots into
## --shot-dir, then proves the pick is permanent (a second pick is refused, a save + load keeps it)
## and that a save from before the picker still builds its old island.
## Run:
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=islandpick_lab --shot-dir=/tmp/islandpick_shots
## Prints exactly one line: [islandpick] RESULT shapes= previews_shown= pick_persists= final_warning=
## old_save_ok= ui_min_px= and quits.

const RUN_DIR := "user://runs/islandpick_lab"
const FIX := "res://tests/fixtures/"

var _args := {}
var _shot_dir := ""
var _pick: Node
var _shots := 0
var _shapes := 0
var _previews := 0
var _final := 0
var _min_px := 0.0
var _persists := 0
var _old_ok := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_shot_dir = str(_args.get("shot-dir", ""))
	Game.debug_overlay = false
	Game.shot_path = ""
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	# A bare host: the pick screen's own layout, no HUD or island behind it.
	var host := Node3D.new()
	host.name = "IslandPickLab"
	add_child(host)
	WorldLighting.install(host, "temperate")
	World.set("creation_pending", false)
	for n in get_tree().get_nodes_in_group(&"character_creation"):
		n.free()
	World.set("home_shape", &"")
	World.set("home_terrain", &"")
	_shapes = (World.get("home_shapes") as Array).size()
	# The pick exactly as World.start_new opens it.
	_pick = (load("res://scripts/ui/island_pick.gd") as GDScript).instance_on(host)
	_pick.call("open")
	await _frames(4)
	_previews = int(_pick.call("preview_count"))
	_final = 1 if bool(_pick.call("warning_visible")) else 0
	_min_px = _measure_min_target()
	var view := get_viewport().get_visible_rect().size
	print("[islandpick] view=%s k=%.2f cards=%d previews=%d final_warning=%d min_px=%.0f" % [
		view, float(_pick.get("_k")), (World.get("home_shapes") as Array).size(), _previews, _final, _min_px])
	await _shot("pick_%dx%d" % [int(view.x), int(view.y)])
	# Selected state: tap the rocky card (the reference's warm frame and gold tick).
	var card := _pick.find_child("Shape_rocky", true, false) as Button
	if card:
		card.pressed.emit()
		await _frames(2)
		await _shot("pick_selected_%dx%d" % [int(view.x), int(view.y)])
	# The previews on their own, at card size: one map per shape.
	await _sheet()
	# Close the screen: the permanence checks below are about the data, and a closed pick must not
	# look like a second pick screen to the old-save check.
	_pick.queue_free()
	await _frames(2)
	# The real save needs a survivor (SaveGame refuses without one), exactly as the game has it.
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 4.0)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	await _frames(2)
	# Permanence, measured through the real World API and a real save + load.
	_persists = await _check_persists(host)
	# A save from before the picker: the legacy island, no second pick.
	_old_ok = await _check_old_save(host)
	print("[islandpick] RESULT shapes=%d previews_shown=%d pick_persists=%d final_warning=%d old_save_ok=%d ui_min_px=%d" % [
		_shapes, _previews, _persists, _final, _old_ok, int(round(_min_px))])
	await _frames(2)
	get_tree().quit(0)

## Smallest tap target the pick actually drew, logical px (the canvas may be scaled).
func _measure_min_target() -> float:
	var lo := INF
	for c in _pick.get_children():
		lo = minf(lo, _walk_min(c))
	return 0.0 if lo == INF else lo

func _walk_min(n: Node) -> float:
	var lo := INF
	if n is Button and (n as Button).is_visible_in_tree():
		var r := (n as Control).get_global_rect()
		lo = minf(lo, minf(r.size.x, r.size.y))
	for c in n.get_children():
		lo = minf(lo, _walk_min(c))
	return lo

## The five preview textures as one contact sheet, so the look is judged from the maps themselves.
func _sheet() -> void:
	var textures: Dictionary = _pick.get("_previews")
	if _shot_dir == "" or textures.is_empty():
		return
	# TextureRect draws through the normal renderer: put the five in a row over the pick's backdrop.
	var row := HBoxContainer.new()
	row.name = "PreviewSheet"
	row.position = Vector2(20, 20)
	row.add_theme_constant_override("separation", 8)
	_pick.add_child(row)
	for id in World.call("shape_ids"):
		var tex: Texture2D = textures.get(str(id))
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(160, 160)
		var pv := TextureRect.new()
		pv.texture = tex
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(pv)
		row.add_child(box)
	await _frames(3)
	await _shot("previews")
	row.queue_free()
	await _frames(1)

func _shot(tag: String) -> void:
	if _shot_dir == "":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img:
		var out := "%s/%s.png" % [_shot_dir, tag]
		img.save_png(out)
		_shots += 1
		print("[islandpick-shot] %s %dx%d" % [out, img.get_width(), img.get_height()])

## One permanent pick: World.pick_shape holds the first, refuses the second, and the save row
## carries it back through a fresh load (the same landmass seed).
func _check_persists(host: Node) -> int:
	var sg := load("res://scripts/core/save_game.gd") as GDScript
	_clean()
	World.set("creation_pending", false)
	World.set("home_shape", &"")
	var want := int((World.call("shape_def", &"forest") as Dictionary).get("seed", 0))
	var first: bool = World.call("pick_shape", &"forest")
	var second: bool = World.call("pick_shape", &"rocky")
	World.call("finish_creation")
	World.call("load_island", host, &"home_grassland", Vector3(0, 1, 18), false)
	await _frames(2)
	var rt: Node3D = World.get("runtime")
	var built_ok := false
	if rt:
		var sh = rt.get("_shape")
		built_ok = sh != null and int(sh.seed) == want
	var saved: bool = sg.call("save_now")
	var stored := ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sg.get("path")))
	if parsed is Dictionary:
		stored = str(((parsed as Dictionary).get("home", {}) as Dictionary).get("shape", ""))
	World.set("home_shape", &"")
	World.set("home_terrain", &"")
	World.set("runtime", null)
	sg.call("load_now", host)
	await _frames(2)
	var back: String = str(World.get("home_shape"))
	var rt2: Node3D = World.get("runtime")
	var same := false
	if rt2:
		var sh2 = rt2.get("_shape")
		same = sh2 != null and int(sh2.seed) == want
	var third: bool = World.call("pick_shape", &"coastal")
	print("[islandpick] persists first=%s second=%s saved=%s stored=%s back=%s same_island=%s third=%s built=%s" % [
		first, second, saved, stored, back, same, third, built_ok])
	return 1 if first and not second and saved and stored == "forest" and back == "forest" and same and not third and built_ok else 0

## An old save (no home.shape): home_shape stays "", the stock seed-17 legacy island builds, and the
## save row added on re-save is empty so the island never moves.
func _check_old_save(host: Node) -> int:
	var sg := load("res://scripts/core/save_game.gd") as GDScript
	_clean()
	World.set("home_shape", &"")
	World.set("home_terrain", &"")
	World.set("runtime", null)
	var f := FileAccess.open(sg.get("path"), FileAccess.WRITE)
	if f == null:
		return 0
	f.store_string(FileAccess.get_file_as_string(FIX + "save_v0.json"))
	f.close()
	sg.call("load_now", host)
	await _frames(2)
	World.call("finish_creation")
	var rt: Node3D = World.get("runtime")
	var stock := false
	if rt:
		var sh = rt.get("_shape")
		stock = sh != null and int(sh.seed) == 17 and bool(sh.legacy)
	var clean_load: bool = str(sg.get("blocked_reason")) == ""
	var no_screen := get_tree().get_nodes_in_group(&"island_pick").is_empty()
	var saved: bool = sg.call("save_now")
	var stored := "x"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sg.get("path")))
	if parsed is Dictionary:
		stored = str(((parsed as Dictionary)["home"] as Dictionary).get("shape", "x"))
	print("[islandpick] old_save loaded=%s shape='%s' stock=%s no_pick_screen=%s saved=%s row='%s'" % [
		clean_load, str(World.get("home_shape")), stock, no_screen, saved, stored])
	return 1 if clean_load and str(World.get("home_shape")) == "" and stock and no_screen and saved and stored == "" else 0

func _clean() -> void:
	var sg := load("res://scripts/core/save_game.gd") as GDScript
	sg.set("blocked_reason", "")
	var dir := ProjectSettings.globalize_path(RUN_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
