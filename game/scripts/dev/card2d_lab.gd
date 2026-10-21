extends Node3D
## CARD2D lab (spec 25 §1): the same resource layout twice on one patch of ground - the left half
## as today's batched 3D GLBs, the right half as baked swaying cards - with the survivor between them,
## so the trial is judged side by side and the frame times are measured.
## Headless: prints the [card2d] PASS line and quits.
## Windowed: Godot --path game --resolution 1600x900 -- --lab=card2d_lab --mode=split
##   --shot=<png>     save the frame after the scene has settled
##   --frames=<dir>   also save a 3 s PNG sequence (10 fps) so the sway can be seen
##   --mode=cards|models|split   what is drawn (cards only for the card timing, models only for theirs)
## Prints: [card2d] PASS kinds=<n> cards=<n> models=<n> ms_cards=<avg> ms_models=<avg>

const ROWS := 12
const COLS := 13  # ~150 props a side
const SPACING := 1.8
## The patches stand side by side ON SCREEN: with IsoCamera's yaw the screen's right axis is
## (0.7071, 0, -0.7071), so a world x/-z offset separates them left/right, not diagonally.
const SCREEN_RIGHT := Vector3(0.7071, 0.0, -0.7071)
const SCREEN_DEPTH := Vector3(0.7071, 0.0, 0.7071)
const HALF_OFFSET := 13.2
## Frames timed per phase after the switch (the first ones recompile pipelines).
const PERF_FRAMES := 90
const PERF_WARMUP := 20
const FRAME_FPS := 10.0
const FRAME_SECONDS := 3.0
## Trees stand at the back of each patch, so their crowns do not cover the small props.
const TREE_ROWS := 1

var _player: Player
var _cam: IsoCamera
var _models_root: Node3D
var _cards_root: Node3D
var _out_shot := ""
var _out_frames := ""
var _mode := "split"
var _kinds: Dictionary = {}
var _card_count := 0
var _model_count := 0
var _phase := &"build"
var _frames: Array[float] = []
var _perf_frames: Array[float] = []
var _perf_cards: Array[float] = []
var _perf_models: Array[float] = []
var _last_us := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_out_shot = a.substr(7)
		elif a.begins_with("--frames="):
			_out_frames = a.substr(9)
		elif a.begins_with("--mode="):
			_mode = a.substr(7)
	var kit := LabKit.build(self, 90.0)
	_player = kit["player"]
	_cam = kit["cam"]
	# Far enough out to hold both patches side by side (2 x 26 m + the gap) and the survivor between.
	_cam.size = 34.0
	_cam.distance = 40.0
	# In front of both patches, on the near side of the screen (the camera sits towards +x/+z).
	_player.global_position = SCREEN_DEPTH * (float(ROWS) * SPACING * 0.5 + 1.5) + Vector3(0, 1.05, 0)
	_player.rotation.y = PI * 0.25
	_cam._snap()
	Game.debug_overlay = false
	# Frame times, not the display's refresh rate: without this both halves read the vsync cap and
	# the comparison says nothing.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	_build()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cam-size="):
			_cam.size = float(a.substr(11))
			_cam._snap()
	print("[boot] lab=card2d_lab")
	_run.call_deferred()

## Two deterministic patches (same seed, so the layout is identical on both sides). The mirror is
## applied when placing, so the kind at (row, col) is the same prop on the left and the right.
func _build() -> void:
	_models_root = Node3D.new()
	_models_root.name = "Models3D"
	add_child(_models_root)
	_cards_root = Node3D.new()
	_cards_root.name = "Cards2D"
	add_child(_cards_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tree_paths: Array[String] = [
		"res://assets/nature/generated/tree-common-a.glb",
		"res://assets/nature/generated/tree-birch-a.glb",
		"res://assets/nature/generated/tree-acacia-a.glb",
	]
	var bush_paths: Array[String] = [
		"res://assets/nature/generated/bush-berries-a.glb",
		"res://assets/nature/generated/bush-berries-b.glb",
		"res://assets/nature/generated/bush-berries-a-empty.glb",
	]
	var small_paths: Array[String] = [
		"res://assets/nature/generated/grass-a.glb",
		"res://assets/nature/generated/plant-a.glb",
		"res://assets/nature/generated/wildgrass-a.glb",
	]
	var rock_paths: Array[String] = ["res://assets/nature/generated/rock-a.glb", "res://assets/nature/generated/rock-moss-a.glb"]
	var kinds: Array[String] = []
	for p in tree_paths:
		var c := CardProp.card_for_model(p)
		if c != "" and CardProp.baked(c):
			kinds.append(c)
	for p in bush_paths:
		var c := CardProp.card_for_model(p)
		if c != "" and CardProp.baked(c):
			kinds.append(c)
	for p in small_paths:
		var c := CardProp.card_for_model(p)
		if c != "" and CardProp.baked(c):
			kinds.append(c)
	for p in rock_paths:
		var c := CardProp.card_for_model(p)
		if c != "" and CardProp.baked(c):
			kinds.append(c)
	kinds.sort()
	for c in kinds:
		_kinds[c] = true
	var all_paths: Array[String] = []
	all_paths.append_array(tree_paths)
	all_paths.append_array(bush_paths)
	all_paths.append_array(small_paths)
	all_paths.append_array(rock_paths)
	var batches: Dictionary = {}
	for row in ROWS:
		for col in COLS:
			# Rows from the back: tall trees, then bushes, then rocks and ground cover, so the crowns
			# of the tall props do not cover the small ones in front of them.
			var path := ""
			if row < TREE_ROWS:
				path = tree_paths[rng.randi_range(0, tree_paths.size() - 1)]
			elif row < TREE_ROWS + 3:
				path = bush_paths[rng.randi_range(0, bush_paths.size() - 1)]
			elif row < TREE_ROWS + 5:
				path = rock_paths[rng.randi_range(0, rock_paths.size() - 1)]
			else:
				path = small_paths[rng.randi_range(0, small_paths.size() - 1)]
			var role := _role_of(path)
			var h := _height_for(rng, role)
			var across := (float(col) - float(COLS - 1) * 0.5) * SPACING + rng.randf_range(-0.4, 0.4)
			var deep := (float(row) - float(ROWS - 1) * 0.5) * SPACING + rng.randf_range(-0.4, 0.4)
			var at := SCREEN_RIGHT * across + SCREEN_DEPTH * deep
			_add_model(batches, path, at - SCREEN_RIGHT * HALF_OFFSET, h)
			_add_card(CardProp.card_for_model(path), at + SCREEN_RIGHT * HALF_OFFSET, h)

func _role_of(path: String) -> String:
	if path.contains("tree-"):
		return "tree"
	if path.contains("bush-"):
		return "bush"
	if path.contains("rock-"):
		return "rock"
	return "plant"

func _height_for(rng: RandomNumberGenerator, role: String) -> float:
	match role:
		"tree":
			return rng.randf_range(6.0, 9.5)
		"bush":
			return rng.randf_range(1.4, 2.0)
		"rock":
			return rng.randf_range(0.6, 1.1)
		_:
			return rng.randf_range(0.5, 0.9)

## A 3D prop through VegBatch, the path island_scatter uses, scaled to `height` metres.
func _add_model(batches: Dictionary, path: String, pos: Vector3, height: float) -> void:
	var batch: VegBatch = batches.get(path)
	if batch == null:
		batch = VegBatch.get_for(_models_root, path)
		if batch == null:
			return
		batches[path] = batch
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (height / VegBatch.mesh_height(path))), pos)
	batch.add(xf)
	_model_count += 1

func _add_card(card_id: String, pos: Vector3, height: float) -> void:
	if card_id == "" or not CardProp.baked(card_id):
		return
	var card := CardProp.new()
	card.name = "Card_%d" % _card_count
	_cards_root.add_child(card)
	card.position = pos
	if card.setup(card_id, height):
		_card_count += 1
	else:
		card.queue_free()

func _run() -> void:
	for c in _models_root.get_children():
		if c is VegBatch:
			(c as VegBatch).commit()
	_apply_mode()
	_phase = &"settle"
	await get_tree().create_timer(1.2).timeout
	if _out_frames != "":
		DirAccess.make_dir_recursive_absolute(_out_frames)
		await _capture_frames()
	if _out_shot != "":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out_shot)
		print("[card2d] shot %s" % _out_shot)
	await _measure()
	var ms_cards := _avg(_perf_cards)
	var ms_models := _avg(_perf_models)
	print("[card2d] PASS kinds=%d cards=%d models=%d ms_cards=%.2f ms_models=%.2f" % [
		_kinds.size(), _card_count, _model_count, ms_cards, ms_models])
	get_tree().quit(0)

func _avg(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var sum := 0.0
	for v in a:
		sum += v
	return sum / float(a.size())

func _apply_mode() -> void:
	match _mode:
		"cards":
			_models_root.visible = false
			_cards_root.visible = true
		"models":
			_models_root.visible = true
			_cards_root.visible = false
		_:
			_models_root.visible = true
			_cards_root.visible = true

## 3 s at 10 fps from the settled view; each frame waits for the draw so the PNG is the real frame.
func _capture_frames() -> void:
	var n := int(FRAME_SECONDS * FRAME_FPS)
	for i in n:
		await get_tree().create_timer(1.0 / FRAME_FPS).timeout
		await RenderingServer.frame_post_draw
		var t0 := Time.get_ticks_msec()
		var img := get_viewport().get_texture().get_image()
		var t1 := Time.get_ticks_msec()
		img.save_png(_out_frames.path_join("%03d.png" % i))
		print("[card2d] frame %d grab=%dms save=%dms" % [i, t1 - t0, Time.get_ticks_msec() - t1])
	print("[card2d] frames %d -> %s" % [n, _out_frames])

## Alternating phases with one half hidden; the average frame time of each is what the line reports.
func _measure() -> void:
	for round in 2:
		for m in ["cards", "models"]:
			_mode = m
			_apply_mode()
			_frames.clear()
			_last_us = 0
			_phase = StringName("perf_" + m)
			await _wait_frames(PERF_WARMUP + PERF_FRAMES)
			var arr := _perf_cards if m == "cards" else _perf_models
			for i in range(PERF_WARMUP, _frames.size()):
				arr.append(_frames[i])
			print("[card2d] phase=%s frames=%d avg=%.2f" % [m, _frames.size(), _avg(_frames.slice(PERF_WARMUP))])
			_frames.clear()
			_phase = &"settle"
	_mode = "split"
	_apply_mode()
	await _wait_frames(2)
	_phase = &"idle"

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _process(_delta: float) -> void:
	if not str(_phase).begins_with("perf_"):
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append(float(now - _last_us) / 1000.0)
	_last_us = now
