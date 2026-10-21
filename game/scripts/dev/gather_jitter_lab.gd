extends Node3D
## CONTROLS B1 gate: the gather radial and the node labels hold still while the camera follows a walk.
## Boots home_grassland with the real HUD (as ui_real_capture_lab does), taps a harvest node about 20 m
## off through the player's real tap path, picks an open hex and logs every frame of the walk: each
## hex's offset from the node's anchor, the title box and the option labels (relative to the anchor), and
## the HUD's node-label pills (relative to the world, which an orthographic camera shifts uniformly).
## Then it "clicks around": taps four more nodes in a row, picking a hex on each so the survivor walks.
## Gate: per frame a hex, the title or a label moves <= 2 px against its anchor, nothing swaps sides,
## and no pill jumps (> 6 px against its own object, from HudPills' per-object offsets). A base without
## those offsets is measured by matching each pill to last frame's pill of its size, which also counts a
## label that hides while another of its kind shows (reported apart as pops where the offsets exist).
## Windowed: --resolution 1600x900 -- --lab=gather_jitter_lab [--shot-dir=DIR]
## Prints "[jitter] ..." lines, then "[jitter] PASS" (exit 0) or FAIL lines (exit 1).

const MAX_STEP := 2.0       ## px a radial part may move against its anchor in one frame
const PILL_JUMP := 6.0      ## px a pill may move against the world in one frame
const SWAP_DEG := 45.0      ## a hex whose direction from the anchor turns more than this in a frame swapped sides
const WALK_S := 3.0

var _fails: Array[String] = []
var _out := ""
var _player: Player
var _hud: HuntHud
var _radial: GatherRadial
var _prev: Dictionary = {}
var _stats: Dictionary = {}

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("gather-jitter")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
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

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	_radial = _player.get("_gather_radial")
	var view := get_viewport().get_visible_rect().size
	print("[jitter] view=%dx%d" % [view.x, view.y])
	if OS.get_cmdline_user_args().has("--trace"):
		print("[trace] radial prio=%d cam prio=%d cam=%s radial thread group=%d" % [_radial.process_priority, get_viewport().get_camera_3d().process_priority, get_viewport().get_camera_3d().get_path(), _radial.process_thread_group])
	_expect(_radial != null and _hud != null, "the player has a gather radial and the HUD is up")
	if _radial == null or _hud == null:
		_finish()
		return
	# 1. One long walk toward a node with the radial open. Zoomed out (as a player pinches or scrolls) so
	# a node about 3 s of walking away is on screen to tap.
	var iso := get_viewport().get_camera_3d() as IsoCamera
	# A landscape phone shows ~ a third of the ground: there the lab uses the old camera's full zoom-out
	# (28 m; players now stop at IsoCamera.MAX_SIZE) so the node 16 m beside her is on screen. Both zooms
	# are the old camera's, scaled with the pitch so as much ground shows up and down the screen (CAMERA).
	var keep := sin(deg_to_rad(absf(IsoCamera.pitch_deg()))) / sin(deg_to_rad(absf(IsoCamera.ORTHO_PITCH_DEG)))
	iso.size = (22.0 if view.y >= 600.0 else IsoCamera.ORTHO_MAX_SIZE) * keep
	iso._snap()  # the perspective camera moves back for a zoom in its own _process, after this frame's search
	await get_tree().process_frame
	var far := _node_between(15.0, 30.0, [])
	if far == null:
		far = await _stand_beside_a_node(iso)
	_expect(far != null, "a gatherable node on screen 15-30 m from the survivor")
	var used: Array[HarvestNode] = []
	if far:
		used.append(far)
		_reset_stats()
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
			_sample()
			if not shot_at.is_empty() and t >= shot_at[0]:
				shot_at.pop_front()
				await _shot("walk_%.1fs" % t)
		_report("walk", "node=%s dist=%.1f m walked=%.2f s moved=%.1f m" % [far.node_id, start.distance_to(far.global_position), walked, start.distance_to(_player.global_position)])
		_expect(walked >= WALK_S - 0.5, "the survivor walked toward the node for about %.0f s with the radial open (%.2f s)" % [WALK_S, walked])
		_gate("walk")
	# 2. Click around: four more nodes in a row, each picked so the survivor turns and walks.
	_reset_stats()
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
			_sample()
		if k == 1:
			await _shot("click_%d" % k)
	_report("click", "opens=%d" % opens)
	_expect(opens >= 3, "clicked around at least 3 nodes (%d)" % opens)
	_gate("click")
	_finish()

## On a landscape phone the HUD leaves a band beside the survivor: set it down 16 m left of a node
## (lab setup, not gameplay) so the node is on screen to its right, and return that node.
func _stand_beside_a_node(iso: IsoCamera) -> HarvestNode:
	var right := iso.global_basis.x * Vector3(1, 0, 1)
	var rt := World.runtime
	var tried := 0
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or hn.depleted or not hn.visible or hn.options().is_empty() or hn.can_gather(_player.inventory) != "" or tried >= 40:
			continue
		tried += 1
		var at := hn.global_position - right.normalized() * 16.0
		if rt and rt.has_method("surface_y"):
			at.y = rt.surface_y(at.x, at.z) + 0.2
		# A clear straight walk (this is the jitter gate, not the pathfinding one): a survivor-wide ball
		# swept from the spot to 1.5 m short of the node at knee height touches nothing.
		var q := PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.6
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.8)
		q.motion = right.normalized() * 14.0
		q.exclude = [_player.get_rid()]
		if get_world_3d().direct_space_state.cast_motion(q)[0] < 1.0:
			continue
		_player.velocity = Vector3.ZERO
		_player.global_position = at
		_player.reset_physics_interpolation()
		iso._snap()
		for f in 3:
			await get_tree().physics_frame
		var found := _node_between(14.0, 17.0, [], [hn])
		if found:
			print("[jitter] survivor set down at %s, beside %s" % [at, found.node_id])
			return found
	return null

## The player's own tap path on a node (opens the radial), then the first open hex, as a finger would.
func _tap_and_pick(n: HarvestNode) -> void:
	_player._interact_tap_target(n)
	_prev.clear()  # a new menu: its first frame is the baseline, not a jump
	await get_tree().process_frame
	_sample()
	for i in _radial._buttons.size():
		if not _radial._buttons[i].disabled:
			_radial._buttons[i].pressed.emit()
			break
	await get_tree().process_frame
	_sample()

func _sample() -> void:
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
	if OS.get_cmdline_user_args().has("--trace"):
		print("[trace] f=%d dt=%.4f cam=%s anchor=%s hex0=%s player=%s" % [Engine.get_process_frames(), get_process_delta_time(), cam.global_position, anchor, _radial._buttons[0].position if not _radial._buttons.is_empty() else Vector2.ZERO, _player.global_position])
	var offs: Variant = (load("res://scripts/ui/hud_pills.gd") as GDScript).get("_last_offset")
	var cur := {"node": _radial.node, "anchor": anchor, "hexes": hexes, "labels": labels, "title": _radial.title_box.get_center() - anchor, "pills": pills, "offs": offs}
	if not _prev.is_empty() and _prev["node"] == _radial.node and (_prev["hexes"] as Array).size() == hexes.size():
		_stats["frames"] = int(_stats["frames"]) + 1
		var ph: Array = _prev["hexes"]
		for i in hexes.size():
			var hs := (hexes[i] - (ph[i] as Vector2)).length()
			_bump("hex_step", hs)
			if hs > MAX_STEP and int(_stats["hex_steps_over"]) <= 6:
				print("[jitter]   hex %d moved %.1f px against the anchor: anchor %s -> %s, hex %s, frame %d dt %.3f cam %s, gathering=%s nav=%s" % [i, hs, _prev["anchor"], anchor, _radial._buttons[i].position, Engine.get_process_frames(), get_process_delta_time(), cam.global_position, _player._gathering, _player.nav_active])
			if absf(rad_to_deg(angle_difference((ph[i] as Vector2).angle(), hexes[i].angle()))) > SWAP_DEG:
				_stats["swaps"] = int(_stats["swaps"]) + 1
		var pl: Array = _prev["labels"]
		if pl.size() == labels.size():
			for i in labels.size():
				var step := (labels[i] - (pl[i] as Vector2)).length()
				_bump("label_step", step)
				# A label that crossed its hex (left <-> right, above <-> below) swapped sides.
				if i < hexes.size() and _side(labels[i] - hexes[i]) != _side((pl[i] as Vector2) - (ph[i] as Vector2)):
					_stats["swaps"] = int(_stats["swaps"]) + 1
		var tstep := (cur["title"] as Vector2 - _prev["title"] as Vector2).length()
		_bump("title_step", tstep)
		if signf((cur["title"] as Vector2).y) != signf((_prev["title"] as Vector2).y):
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
						if OS.get_cmdline_user_args().has("--trace"):
							var others := {}
							for key in _hud.drawn_blocks:
								if not str(key).begins_with("pill"):
									others[key] = _hud.drawn_blocks[key]
							print("[trace] pill jump %.1f px: %s; now: %s; last frame (shifted): %s; figure %s; vel %s; blocks %s; radial title %s labels %s" % [best, r, pills, pp.map(func (q: Rect2) -> Rect2: return Rect2(q.position + shift, q.size)), HudLayout.figure_rect(_hud), _player.velocity, others, _radial.title_box, _radial.label_rects])
	_prev = cur

static func _side(v: Vector2) -> int:
	return (1 if v.x > 0.0 else 0) if absf(v.x) >= absf(v.y) else (3 if v.y > 0.0 else 2)

func _reset_stats() -> void:
	_prev.clear()
	_stats = {"frames": 0, "swaps": 0, "pill_jumps": 0, "hex_step": 0.0, "label_step": 0.0, "title_step": 0.0, "pill_step": 0.0, "hex_steps_over": 0,
		"pill_ids": false, "pill_obj_step": 0.0, "pill_obj_jumps": 0, "pill_pops": 0}

func _bump(key: String, v: float) -> void:
	_stats[key] = maxf(float(_stats[key]), v)
	if key == "hex_step" and v > MAX_STEP:
		_stats["hex_steps_over"] = int(_stats["hex_steps_over"]) + 1

func _report(name: String, extra: String) -> void:
	print("[jitter] %s %s frames=%d max_hex_step=%.2f px (frames over %.0f px: %d) max_title_step=%.2f max_label_step=%.2f swaps=%d max_pill_step=%.2f pill_jumps=%d" % [
		name, extra, _stats["frames"], _stats["hex_step"], MAX_STEP, _stats["hex_steps_over"], _stats["title_step"], _stats["label_step"], _stats["swaps"], _stats["pill_step"], _stats["pill_jumps"]]
		+ (" per_object: max_pill_step=%.2f pill_jumps=%d pops=%d" % [_stats["pill_obj_step"], _stats["pill_obj_jumps"], _stats["pill_pops"]] if _stats["pill_ids"] else " per_object: n/a"))

func _gate(name: String) -> void:
	_expect(int(_stats["frames"]) >= 30, "%s: enough frames sampled (%d)" % [name, _stats["frames"]])
	_expect(float(_stats["hex_step"]) <= MAX_STEP, "%s: each hex's offset from the anchor changes <= %.0f px per frame (max %.2f)" % [name, MAX_STEP, _stats["hex_step"]])
	_expect(float(_stats["title_step"]) <= MAX_STEP, "%s: the title holds still against the anchor (max %.2f px/frame)" % [name, _stats["title_step"]])
	_expect(float(_stats["label_step"]) <= MAX_STEP, "%s: option labels hold still against the anchor (max %.2f px/frame)" % [name, _stats["label_step"]])
	_expect(int(_stats["swaps"]) == 0, "%s: no hex, label or title swaps sides (%d)" % [name, _stats["swaps"]])
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
	var tappable := Rect2(Vector2(40, 40), view - Vector2(80, 80))
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

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)

func _finish() -> void:
	for f in _fails:
		print("[jitter] FAIL %s" % f)
	print("[jitter] %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
