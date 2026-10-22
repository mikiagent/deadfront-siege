extends Node3D
## SWITCH2D lab (owner 2026-10-21: "keep buildings 3D and make resources 2D"): the home island and a
## tropical island, each drawn twice - every resource as a flat card (resource_render "card") and as
## the old 3D props ("model") - with the real HUD, survivor and camera. Measures what the gate reads
## from the live scene: how many resources are painted cards, baked cards, or still 3D models; how
## many cards are flat grey/blank on screen; the median frame time of each mode; that a tap on a card
## selects its node; that a spent berry bush shows its empty card; and the worst angle between a
## card's normal and the camera.
##   --lab=switch2d_lab --shot-dir=DIR [--islands=home_grassland,tropical_25] [--tod=0.92]
## Saves <shot-dir>/switch2d_<island>_<cards|models>.png and prints one
## "[switch2d] RESULT k=v ..." line, then quits.
## ASSUMPTION: the tropical island is tropical_25 (the task names it; the catalogue id is tropical_25).

const ISLANDS: Array[String] = ["home_grassland", "tropical_25"]
## The lab quits itself: a stuck setup must not hold the gate's window open.
const WATCHDOG_S := 115.0
## Frames timed per mode (the first ones compile pipelines and stream the island in).
const PERF_WARMUP := 20
const PERF_FRAMES := 150
## Passes per mode, best median wins (see _time_mode).
const PERF_PASSES := 3
## Cards flat enough to draw as "grey" in the image test: a real painted card is never this flat.
const GREY_STDDEV := 6.0
## On-screen rects smaller than this are not judged: a hanging vine or a grass tuft a few pixels
## across is mostly transparent fringe, so its rect says nothing about whether its texture loaded.
const MIN_RECT_PX := 120
## Cards further than this from the camera's focus (the survivor) are not judged: a grass tuft or
## hanging vine 30 m out is a few thin pixels, so its rect cannot tell a loaded texture from a blank
## one. The long lens puts the camera ~160 m back, so distance is measured to the view's focus.
const JUDGE_MAX_M := 25.0
## How far a pixel must differ from the ground behind the card to count as the card's art (only the
## core of a sprite, not the anti-aliased fringe that blends into the ground), and how few art pixels
## mean the card drew nothing.
const ART_MIN_DIFF := 0.14
const MIN_ART_PIXELS := 8

var _shot_dir := ""
var _islands: Array[String] = []
var _player: Player
var _cam: IsoCamera
var _rules: Dictionary
var _fails: PackedStringArray = []
# Results, accumulated over the islands measured.
var _painted := 0
var _baked := 0
var _models := 0
var _grey := 0
var _tap_ok := 0
var _empty_ok := 0
var _facing := 0.0
var _ms_cards: Array[float] = []
var _ms_models: Array[float] = []
var _phase := &"idle"
var _frames: Array[float] = []
var _last_us := 0
var _shot_n := 0
var _checked_total := 0
## Where _stand_in_props put the survivor, so the shots are framed there again after the tap check
## has walked him to a bush.
var _patch_pos := Vector3.ZERO

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
		elif a.begins_with("--islands="):
			_islands.clear()
			for s in a.substr(10).split(","):
				if s.strip_edges() != "":
					_islands.append(s.strip_edges())
	if _islands.is_empty():
		_islands = ISLANDS.duplicate()
	if _shot_dir == "":
		_shot_dir = OS.get_user_data_dir().path_join("switch2d")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	Game.debug_overlay = false
	# Frame times, not the display's refresh rate: without this both modes read the vsync cap.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	var floor_node := get_node_or_null("Floor")
	if floor_node:
		floor_node.queue_free()
	(kit["ui"] as CanvasLayer).visible = true
	TouchControls.visible = false
	TouchControls.enabled = false
	_rules = get_tree().root.get_node("Data").world_rules
	print("[boot] lab=switch2d_lab islands=%s shot_dir=%s" % [",".join(_islands), _shot_dir])
	_watchdog()
	_run.call_deferred()

## Prints a RESULT line with whatever was measured when the run overruns, then quits.
func _watchdog() -> void:
	await get_tree().create_timer(WATCHDOG_S).timeout
	if not is_inside_tree():
		return
	_fails.append("watchdog: the lab overran %.0f s" % WATCHDOG_S)
	_report()
	get_tree().quit(1)

func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	for island in _islands:
		await _measure_island(island)
	_report()
	get_tree().quit(0 if _fails.is_empty() else 1)

## The one line the gate reads, then the verdict lines.
func _report() -> void:
	# Each island is timed in both modes from the same camera, so the pair is the fair comparison:
	# the line reports the summed per-island medians (same view twice, island-to-island variance out).
	if _checked_total < 3:
		_fails.append("fewer than 3 whole cards were on screen across the islands to judge (%d)" % _checked_total)
	var ms_cards := _sum(_ms_cards)
	var ms_models := _sum(_ms_models)
	print("[switch2d] RESULT painted_nodes=%d baked_nodes=%d model_nodes=%d grey_cards=%d ms_cards=%.2f ms_models=%.2f tap_ok=%d empty_ok=%d facing_err_deg=%.2f shots=%d" % [
		_painted, _baked, _models, _grey, ms_cards, ms_models, _tap_ok, _empty_ok, _facing, _shot_n])
	if _fails.is_empty():
		print("[switch2d] PASS")
	else:
		for f in _fails:
			print("[switch2d] FAIL %s" % f)

## One island in both modes: cards first (count, judge, tap, empty, shots, timing), then the old 3D
## look for the frame-time comparison and its shot.
func _measure_island(island: String) -> void:
	_rules["resource_render"] = "card"
	World.home_terrain = &"meadow"
	World.load_island(self, StringName(island), Vector3(0, 1, 18), false)
	await _settle(1.5)
	_player.reset_physics_interpolation()
	_cam.set("_target", _player)
	_cam.call("_snap")
	await _settle(0.6)
	_stand_in_props()
	await _settle(0.5)
	_count_cards(island)
	_check_buildings(island)
	await _settle(0.3)
	await _judge_cards()
	await _tap_and_empty()
	_return_to_patch()
	await _shoot("%s_cards" % island)
	if island == _islands[0]:
		await _shoot_shading()
		await _shoot_night()
	await _time_mode(&"perf_cards")
	# The same island and camera with the old 3D props: the like-for-like frame-time comparison.
	_rules["resource_render"] = "model"
	World.load_island(self, StringName(island), Vector3(0, 1, 18), false)
	await _settle(1.5)
	_player.reset_physics_interpolation()
	_cam.set("_target", _player)
	_cam.call("_snap")
	await _settle(0.6)
	await _shoot("%s_models" % island)
	await _time_mode(&"perf_models")

## Stands the survivor in the island's densest patch of resources and points the camera at it, so
## the judged frame and the shots are of cards rather than of an empty meadow.
func _stand_in_props() -> void:
	var nodes: Array = get_tree().get_nodes_in_group("harvest")
	var best: Node3D = null
	var best_n := -1
	var camp: Vector3 = World.runtime.get("_camp_pos") if World.runtime else Vector3.ZERO
	for n in nodes:
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		var p: Vector3 = (n as Node3D).global_position
		if Vector2(p.x - camp.x, p.z - camp.z).length() > 70.0:
			continue
		var count := 0
		for m in nodes:
			if m is Node3D and (m as Node3D).global_position.distance_to(p) < 10.0:
				count += 1
		if count > best_n:
			best_n = count
			best = n as Node3D
	if best == null:
		_fails.append("no resource patch to stand in")
		return
	var at: Vector3 = best.global_position
	_player.clear_nav()
	# Inside the patch (not at its edge) and zoomed in like the game's normal view, so the cards are
	# big enough in the frame to judge their art, size and planting.
	_patch_pos = at + Vector3(1.2, 1.0, 1.2)
	_player.global_position = _patch_pos
	_cam.size = 14.0
	_player.reset_physics_interpolation()
	_cam.set("_target", _player)
	_cam.call("_snap")
	print("[switch2d] standing in a patch of %d resources near %s" % [maxi(best_n, 0), at])

## Puts the survivor and camera back on the judged patch: _tap_and_empty walks him to another bush,
## and a shot taken from there frames empty meadow instead of the cards.
func _return_to_patch() -> void:
	if _patch_pos == Vector3.ZERO:
		return
	_player.clear_nav()
	_player.global_position = _patch_pos
	_player.reset_physics_interpolation()
	_cam.set("_target", _player)
	_cam.call("_snap")

## Every resource node on the island: is it a painted card, a baked card, or still a 3D model?
func _count_cards(island: String) -> void:
	var painted := 0
	var baked := 0
	var models := 0
	for node in get_tree().get_nodes_in_group("harvest"):
		if not is_instance_valid(node):
			continue
		var card: Variant = node.get("_card")
		var batch: Variant = node.get("_batch")
		if card is CardProp and is_instance_valid(card):
			if (card as Node).has_meta(&"sprite"):
				painted += 1
			else:
				baked += 1
		elif batch != null:
			models += 1
		elif node.get_node_or_null("VisualGlb") != null:
			models += 1
	_painted += painted
	_baked += baked
	_models += models
	print("[switch2d] %s %s cards: painted=%d baked=%d models=%d" % [_elapsed(), island, painted, baked, models])
	if painted == 0:
		_fails.append("%s drew no painted cards" % island)

## Builders stay 3D: placed buildings on this island must have meshes and no card under them.
func _check_buildings(island: String) -> void:
	var buildings := 0
	var bad := 0
	for b in get_tree().get_nodes_in_group("placed_building"):
		buildings += 1
		if b.find_children("*", "CardProp", true, false).size() > 0:
			bad += 1
	print("[switch2d] %s buildings=%d drawn_as_cards=%d" % [island, buildings, bad])
	if bad > 0:
		_fails.append("%d building(s) drew as cards on %s" % [bad, island])

## Samples the drawn frame under each card: a card whose on-screen pixels have (almost) no variance
## is flat grey - a texture that failed to load, the failure the gate counts. Also measures the
## worst angle between any card's normal and the direction to the camera.
func _judge_cards() -> void:
	# Two frames: the viewport image of a frame the renderer has finished drawing (frame_post_draw
	# can wait forever on a window that is not presenting).
	# force_draw, then one frame: get_texture()'s image is the last frame the renderer finished, which
	# can still be the previous camera view (the island and camera move just before this), and a stale
	# image makes every rect sample the ground beside its card.
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_fails.append("no viewport image for the grey-card check")
		return
	var size := img.get_size()
	var checked := 0
	for node in get_tree().get_nodes_in_group("harvest"):
		if not is_instance_valid(node):
			continue
		var card: Variant = node.get("_card")
		if not (card is CardProp) or not is_instance_valid(card):
			continue
		var n3 := card as Node3D
		if not n3.visible:
			continue
		var mi := n3.get_node_or_null("Card") as MeshInstance3D
		if mi == null:
			continue
		var cam := get_viewport().get_camera_3d()
		var focus := _cam.focus_point() if _cam else n3.global_position
		if Vector2(focus.x - n3.global_position.x, focus.z - n3.global_position.z).length() > JUDGE_MAX_M:
			continue
		# Facing: the quad's normal against the camera's view axis. ASSUMPTION: a card parallel to the
		# view plane is the owner's "align with the camera angle at all times"; the ray from the card
		# to the camera would read 15-20 deg off for a card far from the focus even when it is exactly
		# parallel (perspective), so the view axis is the honest measure of alignment.
		var normal := mi.global_basis.orthonormalized().z
		var to_cam := -cam.global_basis.z
		var err := rad_to_deg(acos(clampf(absf(normal.dot(to_cam)), 0.0, 1.0)))
		_facing = maxf(_facing, err)
		# On-screen rect of the card's own quad (its basis is the camera's, so two corners span it).
		var half_x := mi.global_basis.x.normalized() * (mi.get_aabb().size.x * 0.5)
		var half_y := mi.global_basis.y.normalized() * (mi.get_aabb().size.y * 0.5)
		# The quad is offset from its node by the pivot compensation, so the rect must follow the quad's
		# own mesh centre; using the node's origin samples grass beside the sprite.
		var c: Vector3 = mi.global_transform * mi.get_aabb().get_center()
		var pts: Array[Vector2] = []
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p: Vector3 = c + half_x * sx + half_y * sy
				if cam.is_position_behind(p):
					pts.clear()
					break
				pts.append(cam.unproject_position(p))
		if pts.size() != 4:
			continue
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		# Only cards fully on screen are judged: a clipped card's rect also covers half the island.
		var view := Rect2(Vector2.ZERO, Vector2(size))
		# The floor scales with the frame: a card that covers 120 px of a 900 px tall view covers ~52 px of
		# a 390 px one, and judging only desktop-sized rects left the phone run with nothing to judge.
		var min_px := maxf(12.0, MIN_RECT_PX * float(size.y) / 900.0)
		if not view.encloses(r) or r.size.x < min_px or r.size.y < min_px:
			continue
		# The brief's own measure: the standard deviation of every pixel in the card's on-screen
		# rect. A card with its texture (art over ground) varies; a blank or flat grey quad does
		# not. Every pixel, so a thin sprite (bamboo stems, hanging vines) is sampled where its art
		# is, not on a coarse grid that steps over it.
		var step := 1 if r.size.x * r.size.y <= 40000.0 else maxi(1, int(sqrt(r.size.x * r.size.y / 40000.0)))
		var mean := 0.0
		var sq := 0.0
		var n := 0
		for y in range(int(r.position.y), int(r.end.y), step):
			for x in range(int(r.position.x), int(r.end.x), step):
				var l := img.get_pixel(x, y).get_luminance()
				mean += l
				sq += l * l
				n += 1
		if n < 16:
			continue
		checked += 1
		_checked_total += 1
		mean /= float(n)
		var sd := sqrt(maxf(0.0, sq / float(n) - mean * mean)) * 255.0
		if n3.name.contains("blackberries") or checked <= 3:
			print("[switch2d] probe %s sd=%.1f mean=%.3f n=%d rect=%s" % [n3.name, sd, mean, n, r])
		if sd < GREY_STDDEV:
			_grey += 1
			print("[switch2d] grey card %s at %s %.0fx%.0f px (stddev %.1f)" % [n3.name, r.position, r.size.x, r.size.y, sd])
		if checked >= 60:
			break
	print("[switch2d] judged %d cards on screen, grey=%d, facing_err=%.2f" % [checked, _grey, _facing])
	if _facing > 2.0:
		_fails.append("a card is %.2f deg off the camera" % _facing)

## A tap on a card's screen position selects its node; a spent berry bush shows its empty card.
func _tap_and_empty() -> void:
	var node = null
	for n in get_tree().get_nodes_in_group("harvest"):
		if not is_instance_valid(n) or not (n.get("_card") is CardProp):
			continue
		if n.pool_units_left() <= 0 or n.can_gather(_player.inventory) != "":
			continue
		var mi := (n.get("_card") as Node3D).get_node_or_null("Card") as MeshInstance3D
		if mi == null:
			continue
		_player.clear_nav()
		var away: Vector3 = n.global_position + Vector3(3.0, 0.0, 3.0)
		_player.global_position = Vector3(away.x, n.global_position.y + 1.0, away.z)
		node = n
		break
	if node == null:
		_fails.append("no gatherable card to tap")
		return
	await _settle(0.4)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_cam.set("_target", _player)
		_cam.call("_snap")
	await _settle(0.2)
	var at := Vector3(node.global_position.x, node.global_position.y + 0.7, node.global_position.z)
	var screen: Vector2 = cam.unproject_position(at)
	var picked: StringName = _player.debug_tap_screen(screen)
	var selected: bool = _player.gather_target == node or (_player._gather_radial != null and _player._gather_radial.is_open())
	if selected:
		_tap_ok = 1
	else:
		_fails.append("a tap on card %s did not select it (picked=%s)" % [node.node_id, picked])
	if _player._gather_radial != null and _player._gather_radial.is_open():
		_player._gather_radial.close()
	_player.actions.cancel_work()
	_player.gather_target = null
	# The empty card: spend a bush's pools through the game's own consume path.
	var bush = null
	for n in get_tree().get_nodes_in_group("harvest"):
		if is_instance_valid(n) and n.has_method("has_empty_card") and n.has_empty_card() and n.pool_units_left() > 0:
			bush = n
			break
	if bush == null:
		_fails.append("no berry bush with an empty card")
		return
	var opts: Array = bush.options()
	for i in opts.size():
		for k in 80:
			bush.select_option(i)
			if bush.pool_units_left() <= 0:
				break
			bush.consume_unit()
	bush.select_option(0)
	await get_tree().process_frame
	var empty: Variant = bush.get("_card_empty")
	var full: Variant = bush.get("_card")
	if bush.depleted and empty is CardProp and (empty as Node3D).visible and full is CardProp and not (full as Node3D).visible:
		_empty_ok = 1
		print("[switch2d] empty card shows on depleted %s" % bush.node_id)
	else:
		_fails.append("a depleted bush did not show its empty card (%s)" % bush.node_id)

## The owner's art is lit, not unlit: the same four painted sprites twice on one row, the left of each
## pair through the flat camera-facing normal (SHADE_PAINTED: sun colour and energy, so night and shade
## still darken it), the right pair emission-only (SHADE_PAINTED_UNLIT: the paint at full brightness
## whatever the sun does). Saved as <shot-dir>/switch2d_painted_shading.png.
func _shoot_shading() -> void:
	var root := Node3D.new()
	root.name = "ShadingStrip"
	add_child(root)
	var ids: Array[String] = []
	for family in ["Plant", "WildGrass", "PalmTree", "MangoBush"]:
		for row in CardProp.sprites_for_family(family):
			ids.append(str((row as Dictionary).get("id", "")))
			break
	# Zoomed in on the row: the pairs fill the frame, so the lit/unlit difference is visible.
	var keep_size: float = _cam.size
	_cam.size = 9.0
	var i := 0
	var cam_right: Vector3 = _cam.global_basis.x
	var cam_right_flat := Vector3(cam_right.x, 0.0, cam_right.z).normalized()
	for id in ids:
		var row: Dictionary = CardProp.sprite(id)
		if row.is_empty():
			continue
		for lit in [true, false]:
			var card := CardProp.new()
			root.add_child(card)
			var at := _player.global_position + cam_right_flat * (float(i) * 2.6 - 4.0) + (Vector3.ZERO if lit else cam_right_flat * 1.1)
			card.global_position = Vector3(at.x, _player.global_position.y - 1.0, at.z)
			var h := clampf(float(row.get("height_m", 1.0)), 1.0, 4.0)
			card.setup_painted(row, h, CardProp.SHADE_PAINTED if lit else CardProp.SHADE_PAINTED_UNLIT)
		i += 1
	# The island's own cards stand in the same meadow at this zoom, so hide them for the shot: the
	# comparison is the four strip pairs on clear grass, lit (left) and unlit (right).
	var hidden: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("harvest"):
		if n is Node3D and (n as Node3D).visible:
			(n as Node3D).visible = false
			hidden.append(n as Node3D)
	await _settle(0.5)
	await _shoot("painted_shading")
	for n in hidden:
		if is_instance_valid(n):
			n.visible = true
	_cam.size = keep_size
	print("[switch2d] shading strip: lit (left of each pair) vs unlit (right) — %d sprites" % ids.size())
	root.queue_free()

## Night: the painted cards take the sun's colour and energy, so the island still darkens (the reason
## the lit flat normal, not emission-only, is the default). Saved as switch2d_night_cards.png.
func _shoot_night() -> void:
	var keep := Game.time_of_day
	Game.time_of_day = 0.92  # ASSUMPTION: 0.92 is night in this project's day curve (Game.phase_name)
	await _settle(1.2)
	await _shoot("night_cards")
	Game.time_of_day = keep
	await _settle(0.6)

## Saves the current frame and counts it.
func _shoot(name: String) -> void:
	# force_draw then one frame, not RenderingServer.frame_post_draw: that signal can never fire on a
	# window that is not presenting (this lab stalled past its watchdog once), and two plain frames
	# can return the *previous* view - which shot the camp instead of the patch and a lit day at night.
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		_fails.append("no image for shot %s" % name)
		return
	var path := _shot_dir.path_join("switch2d_%s.png" % name)
	img.save_png(path)
	_shot_n += 1
	print("[switch2d] %s shot %s" % [_elapsed(), path])

## Median frame time over PERF_FRAMES frames in this mode (after PERF_WARMUP), best of PERF_PASSES.
## The same island and camera are timed in both modes, so the pair is the like-for-like comparison; the
## best pass is used because these labs share the machine with other agents' Godot instances, and load
## can only make a pass slower, never faster.
func _time_mode(mode: StringName) -> void:
	var best := INF
	for pass_i in PERF_PASSES:
		_frames.clear()
		_last_us = 0
		_phase = mode
		for i in PERF_WARMUP + PERF_FRAMES:
			await get_tree().process_frame
		var arr := _frames.duplicate()
		arr = arr.slice(mini(PERF_WARMUP, arr.size()))
		_phase = &"idle"
		var med := _median(arr)
		print("[switch2d] %s %s pass %d frames=%d median=%.2f ms" % [_elapsed(), mode, pass_i + 1, arr.size(), med])
		best = minf(best, med)
	if mode == &"perf_cards":
		_ms_cards.append(best)
	else:
		_ms_models.append(best)
	print("[switch2d] %s %s best median=%.2f ms" % [_elapsed(), mode, best])

func _process(_delta: float) -> void:
	if not (_phase == &"perf_cards" or _phase == &"perf_models"):
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_frames.append(float(now - _last_us) / 1000.0)
	_last_us = now

## Sum of the per-island medians (empty -> 0, and the gate then fails on the ratio).
## Mean colour of a sampled rect (clamped to the image).
func _average(img: Image, rect: Rect2i) -> Color:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return Color(0, 0, 0)
	var c := Color(0, 0, 0)
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			c += img.get_pixel(x, y)
			n += 1
	return c / float(maxi(1, n))

func _sum(a: Array[float]) -> float:
	var t := 0.0
	for v in a:
		t += v
	return t

func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _elapsed() -> String:
	return "%.1fs" % (Time.get_ticks_msec() / 1000.0)
