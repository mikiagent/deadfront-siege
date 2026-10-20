extends Node3D
## --lab=occlusion_lab: the see-through system (Occlusion) on one tall tree and one big rock
## ("between", spawned the way island_scatter batches them) and a test hut whose roof is "inside".
## The survivor's spot comes from the shot name: "rock", "inside" (under the roof), "outside"
## (beside the hut); anything else stands just behind the tree. --no-occlusion is the baseline.
## Headless: prints [occl] lines and quits.
## --occl-gates=<dir> (windowed): the owner's pixel gates (2026-10-20). Frames of the tree and the
## hut in set states (prop or survivor hidden, shadows off, the scene paused so poses match) are
## compared pixel by pixel; prints [occl] gate lines and saves <dir>/occl_gates_<renderer>.png
## (unfaded tree | faded tree, survivor behind both).
## --occl-perf (windowed): island_lab's island and camp view with the scatter hook applied; times
## frames with every occludable prop on and released, alternating, and prints [occl] perf. With
## --shot it only stands the survivor behind the camp tree for the picture.

const TREE := "res://assets/nature/generated/tree-common-a.glb"
const ROCK := "res://assets/nature/Rock_1.glb"
## Iso camera sits towards +x/+z, so an offset along SIGHT puts a prop between it and the survivor.
const SIGHT := Vector3(0.7071, 0.0, 0.7071)
const TREE_SPOT := Vector3(0, 0, 0)
const ROCK_SPOT := Vector3(-11, 0, -4)
const HUT_SPOT := Vector3(10, 0, -6)
## Off the sight line: across the view, so nothing stands between the camera and the survivor.
const ASIDE := Vector3(-6, 0, 6)
const PERF_FRAMES := 240
const PERF_ROUNDS := 4
## Frames skipped after each switch: a released prop recompiles its pipeline once.
const PERF_SETTLE := 30
## A pixel differs when any channel moves more than this (of 255); renders are deterministic.
const DIFF := 8
const WIN := 48
const WIN_STEP := 16

var _player: Player
var _cam: IsoCamera
var _tree: VegBatch
var _rock: VegBatch
var _roof: Node3D

func _ready() -> void:
	var kit := LabKit.build(self, 60.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 14.0
	var args := OS.get_cmdline_user_args()
	var gates := ""
	for a in args:
		if a.begins_with("--occl-gates="):
			gates = a.substr(13)
	if Game.shot_path != "" or "--occl-perf" in args or gates != "":
		TouchControls.visible = false
		TouchControls.enabled = false
		(kit["ui"] as CanvasLayer).visible = false
	if "--occl-perf" in args:
		_perf.call_deferred()
		return
	_tree = _prop(TREE, TREE_SPOT + SIGHT * 5.0, 9.0)
	_rock = _prop(ROCK, ROCK_SPOT + SIGHT * 1.5, 3.0)
	_roof = _hut(HUT_SPOT)
	# The tree opts in before its cells exist, as island_scatter's hook does mid-scatter; the rock after.
	var tree_n := Occlusion.make_occludable(_tree, Occlusion.BETWEEN)
	_tree.commit()
	_rock.commit()
	var rock_n := Occlusion.make_occludable(_rock, Occlusion.BETWEEN)
	var roof_n := Occlusion.make_occludable(_roof, Occlusion.INSIDE)
	var spot := TREE_SPOT
	if Game.shot_path.contains("rock"):
		spot = ROCK_SPOT
	elif Game.shot_path.contains("inside"):
		spot = HUT_SPOT
	elif Game.shot_path.contains("outside"):
		spot = HUT_SPOT + Vector3(-4.5, 0, 1.5)
	_place(spot)
	_player.rotation.y = PI * 0.25  # facing the camera
	print("[occl] enabled=%s tree=%d rock=%d roof=%d" % [Occlusion.enabled, tree_n, rock_n, roof_n])
	if gates != "":
		_gates.call_deferred(gates)
	elif DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(0.5).timeout.connect(_report)

func _report() -> void:
	# The tree's cells committed after its hook ran: a non-zero count proves the late-child path.
	print("[occl] tree=%d rock=%d roof=%s fade=%.2f" % [
		int(_tree.get_meta(&"occl_surfaces", 0)), int(_rock.get_meta(&"occl_surfaces", 0)),
		Occlusion.mode_of(_roof), Occlusion.fade_of(_roof)])
	get_tree().quit(0)

func _place(spot: Vector3, snap: bool = true) -> void:
	_player.global_position = spot + Vector3(0, 1.0, 0)
	_player.reset_physics_interpolation()
	if snap:
		_cam._snap()

## One prop through VegBatch, the same path island_scatter uses, scaled to `height` metres.
func _prop(path: String, pos: Vector3, height: float) -> VegBatch:
	var b := VegBatch.get_for(self, path)
	var s := height / VegBatch.mesh_height(path)
	b.add(Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.6).scaled(Vector3.ONE * s), pos))
	return b

## Four posts (always solid) under a slab and a pitched cap: the "Roof" node is what fades.
func _hut(at: Vector3) -> Node3D:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.31, 0.2)
	var thatch := StandardMaterial3D.new()
	thatch.albedo_color = Color(0.62, 0.5, 0.3)
	for c in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.25, 2.6, 0.25)
		post.mesh = pm
		post.material_override = wood
		post.position = at + Vector3(c.x, 1.3, c.y)
		add_child(post)
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.position = at + Vector3(0, 2.6, 0)
	add_child(roof)
	var slab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(5.0, 0.2, 5.0)
	slab.mesh = sm
	slab.material_override = wood
	slab.position.y = 0.1
	roof.add_child(slab)
	var cap := MeshInstance3D.new()
	var cm := PrismMesh.new()
	cm.size = Vector3(5.4, 1.6, 5.4)
	cap.mesh = cm
	cap.set_surface_override_material(0, thatch)
	cap.position.y = 1.0
	roof.add_child(cap)
	return roof

## The owner's gates, in this renderer. Every frame is taken with the scene paused (same pose).
func _gates(dir: String) -> void:
	Game.debug_overlay = false
	var body := _player.find_children("*", "GeometryInstance3D", true, false)
	var tree_cell := _tree.cell_for(0)
	await _wait(10)  # the tree's cell is filed a frame after it arrives
	# Side by side first, running and with shadows: the unfaded tree (released) and the faded one.
	Occlusion.release(_tree)
	var ref := await _shot(20)
	Occlusion.make_occludable(_tree, Occlusion.BETWEEN)
	var faded := await _shot(30)
	_save_pair(ref, faded, dir)
	# Paused: poses, camera and light hold still; this coroutine waits on frame signals, which still fire.
	get_tree().paused = true
	# Shadows off from here: a shadow on the ground is not the prop's own pixels.
	for g: GeometryInstance3D in body + [tree_cell] + _roof.find_children("*", "GeometryInstance3D", true, false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_show(body, false)
	tree_cell.visible = false
	var bg := await _shot(20)
	tree_cell.visible = true
	Occlusion.release(_tree)
	var full := await _shot(20)
	Occlusion.make_occludable(_tree, Occlusion.BETWEEN)
	_place(TREE_SPOT + ASIDE, false)
	var idle := await _shot(30)
	_place(TREE_SPOT, false)
	var kept := await _shot(30)
	_show(body, true)
	tree_cell.visible = false
	var surv := await _shot(20)
	tree_cell.visible = true
	var both := await _shot(30)
	Occlusion.release(_tree)
	var both_ref := await _shot(20)
	Occlusion.make_occludable(_tree, Occlusion.BETWEEN)
	var t := _tree_gates(bg, full, kept, idle, surv, both, both_ref)
	# The hut: the survivor (hidden) under the roof, then beside the hut.
	_place(HUT_SPOT)
	_show(body, false)
	_roof.visible = false
	var hbg := await _shot(20)
	_roof.visible = true
	Occlusion.release(_roof)
	var hfull := await _shot(20)
	Occlusion.make_occludable(_roof, Occlusion.INSIDE)
	var hin := await _shot(30)
	_place(HUT_SPOT + Vector3(-4.5, 0, 1.5), false)
	var hout := await _shot(30)
	var h := _roof_gates(hbg, hfull, hin, hout)
	var ok := t and h
	print("[occl] gates %s renderer=%s" % ["PASS" if ok else "FAIL", RenderingServer.get_current_rendering_method()])
	get_tree().quit(0 if ok else 1)

func _wait(frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw

## `frames` lets every 0.25 s fade finish before the capture.
func _shot(frames: int) -> PackedByteArray:
	await _wait(frames)
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_data()

func _show(nodes: Array, on: bool) -> void:
	for n: GeometryInstance3D in nodes:
		n.visible = on

func _diff(a: PackedByteArray, b: PackedByteArray, i: int) -> bool:
	return absi(a[i] - b[i]) > DIFF or absi(a[i + 1] - b[i + 1]) > DIFF or absi(a[i + 2] - b[i + 2]) > DIFF

## Tree: kept share, worst 48 px window, survivor shown, nothing changes when nothing is in the way.
func _tree_gates(bg: PackedByteArray, full: PackedByteArray, kept: PackedByteArray, idle: PackedByteArray,
		surv: PackedByteArray, both: PackedByteArray, both_ref: PackedByteArray) -> bool:
	var w := get_viewport().get_texture().get_width()
	var h := bg.size() / 3 / w
	var sat_full := PackedInt32Array()
	var sat_kept := PackedInt32Array()
	sat_full.resize((w + 1) * (h + 1))
	sat_kept.resize((w + 1) * (h + 1))
	var n_full := 0
	var n_kept := 0
	var n_idle := 0
	var n_surv := 0
	var n_shown := 0
	var n_shown_ref := 0
	var n_covered := 0
	var n_covered_shown := 0
	for y in h:
		var row_f := 0
		var row_k := 0
		for x in w:
			var i := (y * w + x) * 3
			if _diff(full, bg, i):
				n_full += 1
				row_f += 1
				if _diff(kept, bg, i):
					n_kept += 1
					row_k += 1
			if _diff(idle, full, i):
				n_idle += 1
			if _diff(surv, bg, i):
				n_surv += 1
				var through := not _diff(both, surv, i)
				if through:
					n_shown += 1
				if not _diff(both_ref, surv, i):
					n_shown_ref += 1
				else:
					n_covered += 1
					if through:
						n_covered_shown += 1
			var s := (y + 1) * (w + 1) + x + 1
			sat_full[s] = sat_full[s - w - 1] + row_f
			sat_kept[s] = sat_kept[s - w - 1] + row_k
	# Windows whose pixels are mostly tree: coverage there is the kept share of that window's tree.
	var worst := 1.0
	var windows := 0
	for y in range(0, h - WIN, WIN_STEP):
		for x in range(0, w - WIN, WIN_STEP):
			var f := _box(sat_full, w, x, y)
			if f * 2 < WIN * WIN:
				continue
			windows += 1
			worst = minf(worst, float(_box(sat_kept, w, x, y)) / float(f))
	var kept_share := float(n_kept) / maxf(1.0, float(n_full))
	var shown := float(n_shown) / maxf(1.0, float(n_surv))
	var shown_ref := float(n_shown_ref) / maxf(1.0, float(n_surv))
	var idle_share := float(n_idle) / float(w * h)
	var g1 := kept_share >= 0.40 and kept_share <= 0.60
	var g2 := windows > 0 and worst >= 0.30
	var g3 := shown >= 0.50 and shown_ref < 0.5  # and the survivor really is behind the tree
	var g4 := idle_share < 0.001
	print("[occl] gate tree_kept=%.3f of %d px (0.40..0.60) %s" % [kept_share, n_full, _pf(g1)])
	print("[occl] gate tree_min_window=%.3f over %d windows of %d px (>=0.30) %s" % [worst, windows, WIN, _pf(g2)])
	print("[occl] gate survivor_shown=%.3f of %d px (>=0.50; unfaded tree shows %.3f, must be <0.5; of the %d px the tree covers %.3f show through) %s" % [
		shown, n_surv, shown_ref, n_covered, float(n_covered_shown) / maxf(1.0, float(n_covered)), _pf(g3)])
	print("[occl] gate idle_change=%.5f of the frame (<0.001, occludable but not in the way) %s" % [idle_share, _pf(g4)])
	return g1 and g2 and g3 and g4

## Roof: a faint outline while the survivor is under it, unchanged from outside.
func _roof_gates(bg: PackedByteArray, full: PackedByteArray, inside: PackedByteArray, outside: PackedByteArray) -> bool:
	var n_full := 0
	var n_kept := 0
	var n_out := 0
	for i in range(0, bg.size(), 3):
		if _diff(full, bg, i):
			n_full += 1
			if _diff(inside, bg, i):
				n_kept += 1
		if _diff(outside, full, i):
			n_out += 1
	var kept_share := float(n_kept) / maxf(1.0, float(n_full))
	var out_share := float(n_out) / float(bg.size() / 3)
	var g1 := n_full > 1000 and kept_share >= 0.05 and kept_share <= 0.30
	var g2 := out_share < 0.001
	print("[occl] gate roof_kept_inside=%.3f of %d px (0.05..0.30, a faint outline) %s" % [kept_share, n_full, _pf(g1)])
	print("[occl] gate roof_change_outside=%.5f of the frame (<0.001) %s" % [out_share, _pf(g2)])
	return g1 and g2

func _box(sat: PackedInt32Array, w: int, x: int, y: int) -> int:
	var s := w + 1
	return sat[(y + WIN) * s + x + WIN] - sat[y * s + x + WIN] - sat[(y + WIN) * s + x] + sat[y * s + x]

func _pf(ok: bool) -> String:
	return "PASS" if ok else "FAIL"

## Crops both frames around the tree and survivor and saves them side by side, left unfaded.
func _save_pair(a: PackedByteArray, b: PackedByteArray, dir: String) -> void:
	var w := get_viewport().get_texture().get_width()
	var h := a.size() / 3 / w
	var ia := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, a)
	var ib := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, b)
	var c := get_viewport().get_camera_3d()
	var top := c.unproject_position(TREE_SPOT + SIGHT * 5.0 + Vector3(0, 9.5, 0))
	var foot := c.unproject_position(TREE_SPOT + SIGHT * 5.0)
	var side := (foot.y - top.y) * 0.45
	var r := Rect2i(Vector2i(int(foot.x - side), int(top.y - 20)), Vector2i(int(side * 2), int(foot.y - top.y + 40))).intersection(Rect2i(0, 0, w, h))
	var out := Image.create(r.size.x * 2 + 8, r.size.y, false, Image.FORMAT_RGB8)
	out.fill(Color.BLACK)
	out.blit_rect(ia, r, Vector2i.ZERO)
	out.blit_rect(ib, r, Vector2i(r.size.x + 8, 0))
	var path := dir.path_join("occl_gates_%s.png" % RenderingServer.get_current_rendering_method())
	out.save_png(path)
	print("[occl] side-by-side %s" % path)

## island_lab's view (temperate_25, size 19, distance 28) with the survivor at a tree, as its camp shot.
func _perf() -> void:
	_cam.size = 19.0
	_cam.distance = 28.0
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	(get_node("Nav") as Node3D).visible = false  # as island_lab: the kit floor stays, hidden
	var occ: Array[Node] = []
	for n in World.runtime.get_children():
		if Occlusion.mode_of(n) != "":
			occ.append(n)
	var tree: Node3D
	for n in get_tree().get_nodes_in_group("harvest"):
		var h := n as HarvestNode
		if h and h.falls_to_log and (tree == null or h.global_position.distance_to(_player.global_position) < tree.global_position.distance_to(_player.global_position)):
			tree = h
	# Stand on the tree's far side so its crown is on the sight line (the worst case: a fade active).
	var at := tree.global_position - SIGHT * 1.8
	_player.global_position = Vector3(at.x, World.runtime.surface_y(at.x, at.z) + 1.0, at.z)
	_cam._snap()
	if Game.shot_path != "":
		return  # --shot: the island view with the camp tree faded, no timing
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--occl-perf-scale="):
			# Supersampled 3D: makes the GPU the bottleneck when the display caps the frame rate anyway.
			get_viewport().scaling_3d_scale = float(arg.substr(18))
	# x: wall time between drawn frames (run with --disable-vsync, so it is the real frame cost),
	# y: CPU render time. Rounds alternate on/off so drift and other load hit both alike.
	var ms := {true: Vector2.ZERO, false: Vector2.ZERO}
	var faded := 0
	for r in PERF_ROUNDS * 2:
		var on := r % 2 == 0
		for n in occ:
			if on:
				Occlusion.make_occludable(n, Occlusion.BETWEEN)
			else:
				Occlusion.release(n)
		for i in PERF_SETTLE:
			await RenderingServer.frame_post_draw
		if on:
			faded = Occlusion.driver()._active.size()
		var t0 := Time.get_ticks_usec()
		for i in PERF_FRAMES:
			await RenderingServer.frame_post_draw
			ms[on] += Vector2(0.0, RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		ms[on].x += float(Time.get_ticks_usec() - t0) / 1000.0
	var n_frames := float(PERF_ROUNDS * PERF_FRAMES)
	var a: Vector2 = ms[true] / n_frames
	var b: Vector2 = ms[false] / n_frames
	# The driver's own per-frame work (sight test + fades), timed in isolation with every prop on.
	for n in occ:
		Occlusion.make_occludable(n, Occlusion.BETWEEN)
	for i in PERF_SETTLE:
		await RenderingServer.frame_post_draw
	var drv := Occlusion.driver()
	var chest := _player.global_position + Vector3.UP * Occlusion.CHEST_UP_M
	var t1 := Time.get_ticks_usec()
	for i in 200:
		drv.step_between(drv.in_the_way(chest, _cam.global_basis.z), 0.0, -_cam.global_basis.z)
	var drv_ms := float(Time.get_ticks_usec() - t1) / 200.0 / 1000.0
	var objs := 0
	for k in drv._owned:
		objs += (drv._owned[k] as Array).size()
	print("[occl] perf scale3d=%.1f props=%d objects=%d fading=%d on frame=%.3f cpu=%.3f | off frame=%.3f cpu=%.3f | delta frame=%.3f ms, driver=%.3f ms/frame" % [
		get_viewport().scaling_3d_scale, occ.size(), objs, faded, a.x, a.y, b.x, b.y, a.x - b.x, drv_ms])
	get_tree().quit(0)
