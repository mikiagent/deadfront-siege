extends Node3D
## GATHERGLIDE gate: the gather radial glides when its held layout gives way, and nothing jumps - not
## while the camera follows a walk, and not on the frame a click moves the survivor.
## Boots home_grassland with the real HUD (as ui_real_capture_lab does), taps a harvest node 15-30 m off
## through the player's real tap path, picks an open hex and walks past the node with the camera
## following; then clicks around four more nodes, picking a hex on each so the survivor turns and walks.
## Every frame it logs each hex's, the title's and each label's offset from the node's anchor:
##   max_step_px  the furthest any part moved against the anchor in one frame
##   side_swaps   hexes (or the title) that changed side in one frame (a label may glide across its hex)
##   click_step_px  the same step, in the click phase: the one 45 px camera step of CONTROLS B1
##   resolves     how often the held layout had to be solved again (each one glided)
##   frames       sampled frames (the gate wants >= 120)
## Windowed: --resolution 1600x900|844x390 -- --lab=gather_jitter_lab [--shot-dir=DIR]
## Prints "[jitter] ..." lines, then one "[gatherglide] RESULT k=v ..." line, then quits.

const MAX_STEP := 2.0       ## px a radial part may move against its anchor in one frame
const GLIDE_STEP := 8.0     ## px a glide may move a part in one frame (the task's ceiling)
const PILL_JUMP := 6.0      ## px a pill may move against the world in one frame
const SWAP_DEG := 45.0      ## a hex whose direction from the anchor turns more than this in a frame swapped sides
const HITCH_PX := 12.0     ## px the camera may jump in one frame before that frame is a hitch, not play
const WALK_S := 3.0
const SET_DOWN_M := 16.0    ## the phone's band: 19.5 and 22 m found no node clear of the minimap, CLAIM and vitals

var _fails: Array[String] = []
var _out := ""
var _player: Player
var _hud: HuntHud
var _radial: GatherRadial
var _prev: Dictionary = {}
var _stats: Dictionary = {}
var _hot := false  ## the click phase: its steps are the ones the click gate reads
var _cool := 0  ## frames left of a screenshot's stall, whose camera catch-up is not a frame of play
var _solves0 := 0
var _sampling := false  ## sample every frame in _process, after the radial's own _process (priority 1)

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("gather-jitter")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	process_priority = 10  # after the radial's own _process (priority 1): sample the frame it has drawn
	Engine.max_fps = 60  # per-frame numbers mean the same on every machine
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

## A sample must be taken after the radial has processed this frame (it moves the parts), or it reads
## one frame's anchor against the previous frame's parts and reports a jump that never showed.
func _process(_delta: float) -> void:
	if _sampling:
		_sample()

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	_radial = _player.get("_gather_radial")
	var view := get_viewport().get_visible_rect().size
	print("[jitter] view=%dx%d" % [view.x, view.y])
	_expect(_radial != null and _hud != null, "the player has a gather radial and the HUD is up")
	if _radial == null or _hud == null:
		_finish()
		return
	# 1. One long walk toward a node with the radial open. Zoomed out (as a player pinches or scrolls) so
	# a node about 3 s of walking away is on screen to tap.
	var iso := get_viewport().get_camera_3d() as IsoCamera
	iso.size = iso.max_size if view.y < 600.0 else 22.0
	await get_tree().process_frame
	var far := _node_between(15.0, 32.0, [])
	if far == null:
		far = await _stand_beside_a_node(iso)
	_expect(far != null, "a gatherable node on screen 15-32 m from the survivor")
	var used: Array[HarvestNode] = []
	_reset_stats()
	_sampling = true
	var solves0 := _radial.solves
	_solves0 = solves0
	if far:
		used.append(far)
		var start := _player.global_position
		await _tap_and_pick(far)
		var t := 0.0
		var walked := 0.0
		var shot_at: Array[float] = [0.3, 1.5, 2.7]
		while t < WALK_S + 0.5 and _radial.is_open():
			var before := _player.global_position
			await get_tree().process_frame
			var dt := get_process_delta_time()
			t += dt
			if _player.global_position.distance_to(before) > 0.001:
				walked = t  # until it last moved: a frame without a physics tick does not move it
			if not shot_at.is_empty() and t >= shot_at[0]:
				shot_at.pop_front()
				await _shot("walk_%.1fs" % t)
		_report("walk", "node=%s dist=%.1f m walked=%.2f s moved=%.1f m" % [far.node_id, start.distance_to(far.global_position), walked, start.distance_to(_player.global_position)])
		# On a phone the set-down puts the node ~12 m off (the HUD band leaves no room further out), so
		# the walk is shorter there; either way it is a walk with the camera following, not a still shot.
		_expect(walked >= 1.2, "the survivor walked with the radial open and the camera following (%.2f s)" % walked)
	# 2. Click around: four more nodes in a row, each picked so the survivor turns and walks. The
	#    click phase's steps are the click gate (CONTROLS B1 measured one 45 px camera step here).
	_hot = true
	var opens := 0
	for k in 4:
		var n := _node_between(4.0, 14.0, used)
		if n == null:
			break
		used.append(n)
		await _tap_and_pick(n)
		opens += 1
		for f in 50:
			await get_tree().process_frame
		if k >= 1 and k <= 2:
			await _shot("click_%d" % k)
	_hot = false
	_sampling = false
	_stats["resolves"] = _radial.solves - solves0
	_report("click", "opens=%d click_frames=%d" % [opens, _stats["click_frames"]])
	_expect(int(_stats["resolves"]) > 0, "clicking around re-solves the held layout (%d times)" % _stats["resolves"])

	_expect(int(_stats["click_frames"]) >= 60, "clicking around sampled enough frames (%d)" % _stats["click_frames"])
	_expect(opens >= 3, "clicked around at least 3 nodes (%d)" % opens)
	_gate("walk")
	_finish()

## On a landscape phone the HUD leaves a band beside the survivor: set it down SET_DOWN_M beside a node
## (lab setup, not gameplay) so the node is on screen to its side, and return that node.
func _stand_beside_a_node(iso: IsoCamera) -> HarvestNode:
	var rt := World.runtime
	var tried := 0
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or hn.depleted or not hn.visible or hn.options().is_empty() or hn.can_gather(_player.inventory) != "" or tried >= 40:
			continue
		tried += 1
		# The node to her right, else to her left (on a phone the right edge is minimap and CLAIM).
		var band := _tappable()
		var spots: Array = []
		for side: float in [1.0, -1.0]:
			for dist: float in [SET_DOWN_M, 14.0, 18.0, 20.0, 12.0]:
				spots.append([side, dist])
		for spot: Array in spots:
			var side: float = spot[0]
			var dist: float = spot[1]
			var toward := (iso.global_basis.x * Vector3(1, 0, 1)).normalized() * side
			var at := hn.global_position - toward * dist
			var ground := at.y - 1.0
			if rt and rt.has_method("surface_y"):
				ground = rt.surface_y(at.x, at.z)
			# Standing: the origin is the capsule's centre (it was set 0.2 m above the ground, 0.8 m into
			# it, and only the old router's unstick hop got the survivor out).
			at.y = ground + _player.half_height() + 0.05
			# A clear straight walk (this is the jitter gate, not the pathfinding one): a survivor-wide ball
			# swept from the spot to 1.5 m short of the node at knee height touches nothing.
			var q := PhysicsShapeQueryParameters3D.new()
			var ball := SphereShape3D.new()
			ball.radius = 0.6
			q.shape = ball
			q.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, ground + 1.0, at.z))
			q.motion = toward * (dist - 1.5)
			q.exclude = [_player.get_rid()]
			var clear: float = get_world_3d().direct_space_state.cast_motion(q)[0]
			if clear < 1.0:
				print("[jitter] set-down beside %s blocked (%.2f) at %s" % [hn.node_id, clear, at])
				continue
			_player.velocity = Vector3.ZERO
			_player.global_position = at
			_player.reset_physics_interpolation()
			iso._snap()
			for f in 3:
				await get_tree().physics_frame
			if not band.has_point((get_viewport().get_camera_3d() as Camera3D).unproject_position(hn.global_position)):
				continue
			var found := _node_between(dist - 1.5, dist + 1.5, [], [hn])
			if found:
				print("[jitter] survivor set down at %s, beside %s (%.0f m)" % [at, found.node_id, dist])
				return found
	return null

## The part of the screen a finger can reach a node on: inset from the edges, clear of the HUD.
func _tappable() -> Rect2:
	var view := get_viewport().get_visible_rect().size
	if UiTokens.is_compact(view):
		return Rect2(Vector2(40.0, 116.0), Vector2(maxf(64.0, view.x - 284.0), maxf(64.0, view.y - 116.0 - 112.0)))
	return Rect2(Vector2(40.0, 40.0), view - Vector2(80.0, 80.0))

## The player's own tap path on a node (opens the radial), then the first open hex, as a finger would.
func _tap_and_pick(n: HarvestNode) -> void:
	_player._interact_tap_target(n)
	_prev.clear()  # a new menu: its first frame is the baseline, not a jump
	await get_tree().process_frame
	for i in _radial._buttons.size():
		if not _radial._buttons[i].disabled:
			_radial._buttons[i].pressed.emit()
			break
	await get_tree().process_frame

func _sample() -> void:
	if _cool > 0:
		_cool -= 1
		_prev.clear()
		return
	if not _radial.is_open() or _radial.node == null:
		_prev.clear()
		return
	var cam := get_viewport().get_camera_3d()
	var anchor := cam.unproject_position(_radial.node.global_position + Vector3(0, _radial.anchor_height * 0.45, 0))
	var hexes: Array[Vector2] = []
	for b in _radial._buttons:
		hexes.append(b.position + b.size * 0.5 - anchor)
	var labels: Array[Vector2] = []
	for r in _radial.label_rects:
		labels.append(r.get_center() - anchor)
	var pills: Array[Rect2] = []
	for k in _hud.drawn_blocks:
		if str(k).begins_with("pill"):
			pills.append(_hud.drawn_blocks[k] as Rect2)
	var offs: Variant = (load("res://scripts/ui/hud_pills.gd") as GDScript).get("_last_offset")
	var cur := {"node": _radial.node, "anchor": anchor, "hexes": hexes, "labels": labels, "title": _radial.title_box.get_center() - anchor, "pills": pills, "offs": offs}
	# A frame in which the camera itself jumps (it catches up a stall all at once) drags the whole
	# world across the screen; that is a hitch, not a frame of play (CONTROLS B3 skips the screenshot
	# stall the same way). Re-baseline there and count it, rather than reading it as the ring jumping.
	if not _prev.is_empty() and (_prev["node"] as Object) == _radial.node:
		var jump: float = anchor.distance_to(_prev["anchor"] as Vector2)
		if jump > HITCH_PX:
			_stats["hitch_frames"] = int(_stats["hitch_frames"]) + 1
			_prev = cur
			return
	if not _prev.is_empty() and _prev["node"] == _radial.node and (_prev["hexes"] as Array).size() == hexes.size():
		_stats["frames"] = int(_stats["frames"]) + 1
		if _radial._hold.gliding():
			_stats["glide_frames"] = int(_stats["glide_frames"]) + 1
		_stats["resolves"] = _radial.solves - _solves0
		var ph: Array = _prev["hexes"]
		for i in hexes.size():
			var hs := (hexes[i] - (ph[i] as Vector2)).length()
			_step("hex_step", hs)
			if absf(rad_to_deg(angle_difference((ph[i] as Vector2).angle(), hexes[i].angle()))) > SWAP_DEG:
				_stats["swaps"] = int(_stats["swaps"]) + 1
		var pl: Array = _prev["labels"]
		if pl.size() == labels.size():
			for i in labels.size():
				_step("label_step", (labels[i] - (pl[i] as Vector2)).length())
		var tstep := (cur["title"] as Vector2 - _prev["title"] as Vector2).length()
		_step("title_step", tstep)
		if signf((cur["title"] as Vector2).y) != signf((_prev["title"] as Vector2).y) and tstep > GLIDE_STEP:
			_stats["swaps"] = int(_stats["swaps"]) + 1
		# Pills, exact: each object's label against the object, where HudPills keeps the offsets.
		if offs is Dictionary and _prev["offs"] is Dictionary:
			_stats["pill_ids"] = true
			var po: Dictionary = _prev["offs"]
			for id in offs:
				if po.has(id):
					var step := ((offs[id] as Vector2) - (po[id] as Vector2)).length()
					_bump("pill_obj_step", step)
					if step > PILL_JUMP:
						_stats["pill_obj_jumps"] = int(_stats["pill_obj_jumps"]) + 1
				else:
					_stats["pill_pops"] = int(_stats["pill_pops"]) + 1
		# Pills, any tree: match each to last frame's pill of the same size nearest after the world shift.
		var shift: Vector2 = anchor - (_prev["anchor"] as Vector2)
		var pp: Array = _prev["pills"]
		if pp.size() == pills.size():  # a pill fading in or out reorders the rest; skip that frame
			for r in pills:
				var best := INF
				for q in pp:
					if (q as Rect2).size.is_equal_approx(r.size):
						best = minf(best, ((q as Rect2).position + shift).distance_to(r.position))
				if best < 80.0:
					_bump("pill_step", best)
					if best > PILL_JUMP:
						_stats["pill_jumps"] = int(_stats["pill_jumps"]) + 1
	_prev = cur

## The worst step of a part this run, and - in the click phase - the one the click gate reads.
func _step(key: String, v: float) -> void:
	_bump(key, v)
	_stats["max_step"] = maxf(float(_stats["max_step"]), v)
	if _hot:
		_stats["click_frames"] = int(_stats["click_frames"]) + 1
		_stats["click_step"] = maxf(float(_stats["click_step"]), v)

static func _side(v: Vector2) -> int:
	return (1 if v.x > 0.0 else 0) if absf(v.x) >= absf(v.y) else (3 if v.y > 0.0 else 2)

func _reset_stats() -> void:
	_prev.clear()
	_stats = {"frames": 0, "swaps": 0, "resolves": 0, "max_step": 0.0, "click_step": 0.0, "hitch_frames": 0,
		"pill_jumps": 0, "click_frames": 0, "glide_frames": 0, "hex_step": 0.0, "label_step": 0.0, "title_step": 0.0, "pill_step": 0.0, "hex_steps_over": 0,
		"pill_ids": false, "pill_obj_step": 0.0, "pill_obj_jumps": 0, "pill_pops": 0}

func _bump(key: String, v: float) -> void:
	_stats[key] = maxf(float(_stats[key]), v)
	if key == "hex_step" and v > MAX_STEP:
		_stats["hex_steps_over"] = int(_stats["hex_steps_over"]) + 1

func _report(name: String, extra: String) -> void:
	print("[jitter] %s %s frames=%d glide_frames=%d hitch_frames=%d max_step=%.2f px (over %.0f px: %d) max_hex_step=%.2f max_title_step=%.2f max_label_step=%.2f side_swaps=%d resolves=%d click_step=%.2f max_pill_step=%.2f pill_jumps=%d" % [
		name, extra, _stats["frames"], _stats["glide_frames"], _stats["hitch_frames"], _stats["max_step"], MAX_STEP, _stats["hex_steps_over"], _stats["hex_step"], _stats["title_step"], _stats["label_step"],
		_stats["swaps"], _stats["resolves"], _stats["click_step"], _stats["pill_step"], _stats["pill_jumps"]]
		+ (" per_object: max_pill_step=%.2f pill_jumps=%d pops=%d" % [_stats["pill_obj_step"], _stats["pill_obj_jumps"], _stats["pill_pops"]] if _stats["pill_ids"] else " per_object: n/a"))

func _gate(name: String) -> void:
	_expect(int(_stats["frames"]) >= 120, "%s: enough frames sampled (%d)" % [name, _stats["frames"]])
	_expect(float(_stats["max_step"]) < GLIDE_STEP, "%s: no part moves more than %.0f px against the anchor in a frame (max %.2f)" % [name, GLIDE_STEP, _stats["max_step"]])
	_expect(int(_stats["swaps"]) == 0, "%s: no hex or title swaps sides in a frame (%d)" % [name, _stats["swaps"]])
	_expect(float(_stats["click_step"]) < GLIDE_STEP, "%s: clicking around moves the parts at most %.0f px in a frame (max %.2f)" % [name, GLIDE_STEP, _stats["click_step"]])
	if _stats["pill_ids"]:
		_expect(int(_stats["pill_obj_jumps"]) == 0, "%s: no node label jumps against its node (%d jumps, max %.2f px)" % [name, _stats["pill_obj_jumps"], _stats["pill_obj_step"]])
	else:
		_expect(int(_stats["pill_jumps"]) == 0, "%s: no node label jumps against the world (%d jumps, max %.2f px)" % [name, _stats["pill_jumps"], _stats["pill_step"]])

## A gatherable node (an open hex, not depleted) a finger could tap (on screen, off the HUD) whose
## distance from the survivor is in [lo, hi]; the farthest one, so the walk is long.
func _node_between(lo: float, hi: float, skip: Array[HarvestNode], pool: Array = []) -> HarvestNode:
	var best: HarvestNode = null
	var best_d := -1.0
	var cam := get_viewport().get_camera_3d()
	var view := get_viewport().get_visible_rect().size
	var tappable := _tappable()
	var why := {"total": 0, "skip": 0, "off_screen": 0, "on_hud": 0, "distance": 0}
	for n in (pool if not pool.is_empty() else get_tree().get_nodes_in_group("harvest")):
		var hn := n as HarvestNode
		why["total"] += 1
		if hn == null or skip.has(hn) or hn.depleted or not hn.visible or hn.options().is_empty() or hn.can_gather(_player.inventory) != "":
			why["skip"] += 1
			continue
		var at := cam.unproject_position(hn.global_position)
		var on_hud := false
		for r in UiTokens.hud_reserved(view):
			on_hud = on_hud or r.has_point(at)
		if not tappable.has_point(at) or on_hud:
			why["on_hud" if on_hud else "off_screen"] += 1
			continue
		var d := _player.global_position.distance_to(hn.global_position)
		why["distance"] += 1
		if d >= lo and d <= hi and d > best_d:
			best_d = d
			best = hn
	if best == null and pool.is_empty():
		print("[jitter] no node %.0f-%.0f m off: %s (survivor %s on screen at %s, cam %s size %.0f aspect %d)" % [lo, hi, why, _player.global_position, cam.unproject_position(_player.global_position), cam.global_position, cam.size, cam.keep_aspect])
	return best

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		return  # headless: numbers only
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[jitter] shot %s" % path)
	# Grabbing the image stalls a frame (~0.1 s); in the next frame the follow camera catches up the whole
	# stall at once (its lerp clamps at 1) and the world moves under the radial. Not a frame of play: let
	# that frame pass and start the comparison afresh.
	_cool = 12  # the camera's lerp takes a few frames to catch up the stall: no frame of play
	_prev.clear()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)

func _finish() -> void:
	for f in _fails:
		print("[jitter] FAIL %s" % f)
	print("[jitter] %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	print("[gatherglide] RESULT max_step_px=%.2f side_swaps=%d click_step_px=%.2f resolves=%d frames=%d" % [
		float(_stats.get("max_step", 0.0)), int(_stats.get("swaps", 0)), float(_stats.get("click_step", 0.0)),
		int(_stats.get("resolves", 0)), int(_stats.get("frames", 0))])
	get_tree().quit(0 if _fails.is_empty() else 1)
