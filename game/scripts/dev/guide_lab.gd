extends Node3D
## GUIDE gate (durango-prompts 22): the walkthrough finger on the real home island and HUD, from a fresh
## scratch save (labs save under user://runs/guide_lab, wiped at launch). Every tap is a real input
## event through the engine, so the finger is proven not to eat input.
##   1. The finger shows within 1 s, on the nearest safe branch tree (tip <= 24 px from it) or clamped to
##      the edge pointing at it; the survivor walks until the tree is on screen.
##   2. A tap on the tree opens the radial; for 3 s while the survivor walks the tip stays inside the
##      Branch hex every frame.
##   3. A tap at the tip picks Branch; the finger hides within a frame and never comes back for the order,
##      also after a save and a reload; the next order's finger shows and stays.
##   4. It hides under the bag, craft, the menu and skills sheets and the creature plate.
## Windowed: --resolution 1600x900 -- --lab=guide_lab [--shot-dir=DIR] (844x390 too; either renderer).
## Prints "[guide] PASS" (exit 0) or "[guide] FAIL ..." lines (exit 1).

const TIP_PX := 24.0

var _out := ""
var _player: Player
var _hud: HuntHud
var _finger: GuideFinger
var _fails: Array[String] = []
var _t0 := 0
var _pick_frame := -1
var _pick_item := ""

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("guide")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false  # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	# Same layering as main.gd: bag and craft are modals above every other canvas layer.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	_player.ui.reparent(modals)
	(_player.craft_ui as Node).reparent(modals)
	_finger = _player.get_node_or_null("GuideLayer/GuideFinger") as GuideFinger
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()

func _run() -> void:
	_expect(_finger != null, "PlayerView mounts the finger (GuideLayer/GuideFinger)")
	if _finger == null:
		_finish()
		return
	var layer := _finger.get_parent() as CanvasLayer
	_expect(layer.layer > 65 and layer.layer < 96 and _finger.mouse_filter == Control.MOUSE_FILTER_IGNORE, "finger on layer %d (66-95) and ignores the mouse" % layer.layer)
	_expect(World.objective == 0 and World.guide_done.is_empty(), "fresh save: order 1, nothing shown yet")
	# 1. Shows within 1 s on the chosen tree.
	while not _finger.visible and Time.get_ticks_msec() - _t0 < 3000:
		await get_tree().process_frame
	var shown_ms := Time.get_ticks_msec() - _t0
	print("[guide] finger shown after %d ms (step %s clamped=%s)" % [shown_ms, _finger.step_id, _finger.clamped])
	_expect(_finger.visible and shown_ms <= 1000, "the finger shows within 1 s of the island (%d ms)" % shown_ms)
	# The camera snaps onto the survivor over the first frames: judge the aim once it has settled, at the
	# end of a frame (after every _process), so the finger and the camera are read from the same frame.
	await get_tree().create_timer(maxf(0.1, 1.0 - shown_ms / 1000.0)).timeout
	await RenderingServer.frame_post_draw
	var tree := _finger.target as HarvestNode
	var rule := Guide.pick_node(_player.global_position, &"branch", get_tree().get_nodes_in_group("harvest"), Guide.threats(get_tree()), tree)
	print("[guide] chosen tree %s at %.1f m" % [tree, _player.global_position.distance_to(tree.global_position) if tree else -1.0])
	_expect(tree != null and tree == rule, "the finger is on the nearest safe branch tree (%s; the rule picks %s)" % [tree, rule])
	if tree == null:
		_finish()
		return
	_check_on_tree(tree)
	await _shot("node")
	var middle := get_viewport().get_visible_rect().grow(-get_viewport().get_visible_rect().size.y * 0.2)
	if not middle.has_point(_cam().unproject_position(Guide.aim_point(tree))):
		# Follow the finger: walk until the tree is well on screen (by the edges the radial runs into the HUD).
		_player.nav_to(_player._closest_nav_point(tree.global_position))
		var t := 0.0
		while t < 15.0 and (_finger.target == null or not middle.has_point(_cam().unproject_position(Guide.aim_point(_finger.target)))):
			await get_tree().process_frame
			t += get_process_delta_time()
		_player.clear_nav()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		tree = _finger.target as HarvestNode
		print("[guide] walked %.1f s; tree on screen=%s" % [t, not _finger.clamped])
		_expect(not _finger.clamped and tree != null, "walking toward the finger brings its tree on screen")
		if tree == null:
			_finish()
			return
		_check_on_tree(tree)
		await _shot("node_near")
	# 2. A real tap on the tree opens the radial; the tip follows the Branch hex while the survivor walks.
	var radial := _player._gather_radial
	radial.picked.connect(func (_n: Node3D, i: int) -> void:
		_pick_frame = Engine.get_process_frames()
		_pick_item = str((radial.options[i] as Dictionary).get("item", "")))
	await _tap(_cam().unproject_position(Guide.aim_point(tree)))
	await get_tree().create_timer(0.3).timeout
	_expect(radial.is_open() and radial.hex_rect_for(&"branch").has_area(), "a tap on the tree opens the radial with a Branch hex")
	# Walk sideways toward the tree's side of the screen, so it drifts to the middle while the radial follows.
	var tree_x := _cam().unproject_position(Guide.aim_point(tree)).x
	var side := _cam().global_basis.x.normalized() * (5.0 if tree_x > get_viewport().get_visible_rect().get_center().x else -5.0)
	var start := _player.global_position
	_player.nav_to(_player._closest_nav_point(start + Vector3(side.x, 0.0, side.z)))
	var frames := 0
	var off := 0
	var t2 := 0.0
	var shot_taken := false
	var hex := Rect2()
	while t2 < 3.0:
		await get_tree().process_frame
		t2 += get_process_delta_time()
		frames += 1
		hex = radial.hex_rect_for(&"branch")
		if not (_finger.visible and hex.has_point(_finger.tip)):
			off += 1
			if off <= 3:
				print("[guide] frame %d: tip %s outside Branch hex %s (shown=%s)" % [frames, _finger.tip, hex, _finger.visible])
		if t2 > 1.5 and not shot_taken:
			shot_taken = true
			await _shot("hex")
	var moved := start.distance_to(_player.global_position)
	_player.clear_nav()
	print("[guide] radial walk: %d frames, %d with the tip off the Branch hex, survivor moved %.1f m" % [frames, off, moved])
	_expect(frames > 30 and off == 0 and moved > 1.0, "tip inside the Branch hex every frame for 3 s while the survivor walks (%d of %d off, moved %.1f m)" % [off, frames, moved])
	await get_tree().create_timer(0.3).timeout
	# 3. A tap at the tip picks Branch, and the finger hides within a frame and stays gone.
	var tip := _finger.tip
	await _tap(tip)
	var hidden_frame := -1
	for k in 4:
		if not _finger.visible and hidden_frame < 0:
			hidden_frame = Engine.get_process_frames()
		await get_tree().process_frame
	print("[guide] tap at %s picked %s on frame %d; finger hidden from frame %d" % [tip, _pick_item, _pick_frame, hidden_frame])
	_expect(_pick_item == "branch", "a tap at the tip picks Branch (picked \"%s\")" % _pick_item)
	_expect(_pick_frame >= 0 and hidden_frame >= 0 and hidden_frame - _pick_frame <= 1, "the finger hides within 1 frame of the pick")
	_expect(World.guide_done.has("branches"), "order 1 is marked done for the guide")
	await _shot("gone")
	var back := await _seen_for(2.0)
	_expect(back == 0, "the finger stays hidden for the rest of order 1 (%d frames shown)" % back)
	# ... also after a save and a reload.
	_expect(SaveGame.save_now(), "the scratch save writes")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path))
	_expect(saved is Dictionary and (saved as Dictionary).get("guide_done", []).has("branches"), "the save holds guide_done [branches] (%s)" % SaveGame.path)
	World.guide_done = PackedStringArray()
	SaveGame.load_now(self)
	await get_tree().create_timer(0.6).timeout
	print("[guide] reloaded: order %d guide_done=%s" % [World.objective, World.guide_done])
	_expect(World.objective == 0 and World.guide_done.has("branches"), "after the reload order 1 is still current and still done for the guide")
	back = await _seen_for(1.5)
	_expect(back == 0, "no finger for order 1 after the reload (%d frames shown)" % back)
	# The next order's finger shows, once, and stays.
	LabKit.give(_player, &"branch", 3)
	var t3 := 0.0
	while not (_finger.visible and _finger.step_id == "stone") and t3 < 2.0:
		await get_tree().process_frame
		t3 += get_process_delta_time()
	print("[guide] next order %s: finger on %s after %.2f s" % [_finger.step_id, _finger.target, t3])
	_expect(_finger.visible and _finger.step_id == "stone", "order 2's finger shows")
	var flicker := 0
	var was := true
	for k in 60:
		await get_tree().process_frame
		if was and not _finger.visible:
			flicker += 1
		was = _finger.visible
	_expect(flicker == 0 and _finger.visible, "order 2's finger stays up (%d drops in 60 frames)" % flicker)
	await _shot("next")
	# 4. Hidden under the bag, craft, the sheets and the creature plate.
	await _covered("bag", func () -> void: _player.ui.visible = true, func () -> void: _player.ui.visible = false)
	var craft := _player.craft_ui as CraftUI
	await _covered("craft", craft.show_ui, craft.hide_ui)
	await _covered("menu sheet", func () -> void: _hud.call("_toggle_sheet", &"menu"), func () -> void: _hud.call("_close_sheet"))
	await _covered("skills sheet", func () -> void: _hud.call("_toggle_skills"), func () -> void: (_hud.get_node("SkillsSheet") as SkillsSheet).close())
	var wild: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and not c.is_pet and not c.health.dead:
			wild = c
			break
	_expect(wild != null, "a wild creature exists for the plate check")
	if wild:
		wild.process_mode = Node.PROCESS_MODE_DISABLED  # hold it still beside the survivor
		wild.global_position = _player.global_position + Vector3(3.0, 0.0, 2.0)
		await _covered("creature plate", func () -> void: _player.hunt.start(wild), func () -> void: pass, false)
	_finish()

## The finger is on `tree`: its tip within TIP_PX of it, or (off screen) on the edge pointing at it.
func _check_on_tree(tree: HarvestNode) -> void:
	var p := _cam().unproject_position(Guide.aim_point(tree))
	var dir := Vector2(sin(_finger.angle), -cos(_finger.angle))
	if _finger.clamped:
		var off := rad_to_deg(absf(dir.angle_to(p - _finger.tip)))
		print("[guide] tree off screen at %s: tip on the edge %s, finger %.0f deg off the tree" % [p, _finger.tip, off])
		_expect(off < 25.0 and get_viewport().get_visible_rect().has_point(_finger.tip), "edge-clamped finger points at the tree (%.0f deg off)" % off)
	else:
		var d := _finger.tip.distance_to(p)
		print("[guide] tree at %s: tip %s, %.1f px away" % [p, _finger.tip, d])
		_expect(d <= TIP_PX, "tip within %.0f px of the tree (%.1f)" % [TIP_PX, d])

## Open a cover, expect the finger gone; close it, expect it back (proves the cover hid it).
func _covered(what: String, open: Callable, close: Callable, reopens: bool = true) -> void:
	_expect(_finger.visible, "%s: finger up before it opens" % what)
	open.call()
	await _frames(3)
	print("[guide] %s open: finger shown=%s" % [what, _finger.visible])
	_expect(not _finger.visible, "the finger hides under the %s" % what)
	if what == "creature plate":
		await _shot("plate")
	close.call()
	await _frames(3)
	if reopens:
		_expect(_finger.visible, "the finger returns when the %s closes" % what)

## Frames the finger is up in the next `seconds`.
func _seen_for(seconds: float) -> int:
	var t := 0.0
	var n := 0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		n += 1 if _finger.visible else 0
	return n

func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()

## A real press and release at a canvas point, in window pixels, through the engine's input pipeline.
func _tap(pos: Vector2) -> void:
	var at := get_tree().root.get_final_transform() * pos
	var move := InputEventMouseMotion.new()
	move.position = at
	Input.parse_input_event(move)
	await _frames(1)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		Input.parse_input_event(ev)
		await _frames(1)

func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		_fails.append("%s: no pixels (run windowed, not --headless)" % name)
		return
	var at := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(at)
	print("[guide] shot %s finger=%s tip=%s" % [at, _finger.visible, _finger.tip])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)

func _finish() -> void:
	if _fails.is_empty():
		print("[guide] PASS shots=%s" % _out)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[guide] FAIL %s" % f)
		get_tree().quit(1)
