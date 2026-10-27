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
	var shots := ""
	for a in args:
		if a.begins_with("--occl-gates="):
			gates = a.substr(13)
		elif a.begins_with(O2_DIR_ARG):
			shots = a.substr(O2_DIR_ARG.length())
	if Game.shot_path != "" or "--occl-perf" in args or gates != "":
		TouchControls.visible = false
		TouchControls.enabled = false
		(kit["ui"] as CanvasLayer).visible = false
	if "--occl-perf" in args:
		_perf.call_deferred()
		return
	if "--occl2" in args or shots != "":
		# The gate passes --shot-dir= without --occl2: either flag asks for the occl2 measurement.
		var dir := shots
		if dir == "" and Game.shot_path != "":
			dir = Game.shot_path.get_base_dir()
		_occl2.call_deferred(dir, kit["ui"])
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


# --- OCCLUDE2 (--occl2): the survivor is always visible -------------------------------------------
## Three play-test cases (the harbour spawn under the shed, a dense bush clump, a tree's crown), each
## measured by an ID pass: the survivor is drawn in a flat colour (an unshaded override) and the share
## of their own pixels that still show that colour, with the props solid and with them faded, is the
## visible share. Then the fade is stepped frame by frame for its length and its biggest jump (a pop is
## a one-frame change over 0.25), and a fading tree's trunk is checked to keep every pixel.
## Prints one `[occlude2] RESULT ...` line, saves one PNG per case in --shot-dir, then quits.
const O2_ID := Color(1.0, 0.0, 1.0)  # the survivor's flat ID colour; nothing else in these shots is magenta
const O2_SETTLE := 30
const O2_FADE_STEP := 1.0 / 60.0
## Frames to settle before each frame of a measurement, so a material or a fade has landed.
const O2_FRAME := 4
## --shot-dir=DIR: where the occl2 shots go (its own flag; --shot alone makes Game quit after one shot).
const O2_DIR_ARG := "--shot-dir="
const BUSH := "res://assets/nature/generated/bush-berries-a.glb"

var _o2_dir := ""
var _o2_roots: Array = []

func _occl2(dir: String, ui: CanvasLayer) -> void:
	ui.visible = false
	TouchControls.visible = false
	TouchControls.enabled = false
	_o2_dir = dir if dir != "" else OS.get_user_data_dir().path_join("occlude2")
	DirAccess.make_dir_recursive_absolute(_o2_dir)
	Engine.max_fps = 60
	Game.debug_overlay = false
	var vis := {}
	vis["harbour"] = await _o2_case("harbour", _o2_harbour())
	vis["bush"] = await _o2_case("bush", _o2_bushes())
	vis["canopy"] = await _o2_case("canopy", _o2_canopy())
	var fade: Vector2 = await _o2_fade_probe()
	var trunk: float = await _o2_trunk_probe()
	var lo := minf(float(vis["harbour"]), minf(float(vis["bush"]), float(vis["canopy"])))
	print("[occlude2] RESULT vis_harbour=%.3f vis_bush=%.3f vis_canopy=%.3f fade_s=%.3f pops=%d trunk_alpha_min=%.3f vis_min=%.3f" % [
		float(vis["harbour"]), float(vis["bush"]), float(vis["canopy"]), fade.x, int(fade.y), trunk, lo])
	get_tree().quit(0)

## The harbour's own node, as island_runtime builds it, with the survivor under the shed on the deck.
func _o2_harbour() -> Node:
	var h: Node3D = (load("res://scripts/world/harbour.gd") as GDScript).new()
	h.name = "O2_harbour"
	add_child(h)
	_o2_roots = [h]
	var deck := float((load("res://scripts/world/harbour.gd") as GDScript).get_script_constant_map().get("DECK_H", 1.2))
	# The shed stands over z = +2.0 of the pier's local frame; the survivor stands under its roof.
	_place(h.global_position + Vector3(0.0, deck, 2.0))
	return h

## A clump of seven full-size bushes round the survivor, the densest three on the sight line.
func _o2_bushes() -> Node:
	var b: VegBatch = VegBatch.get_for(self, BUSH)
	b.name = "O2_bushes"
	var at := TREE_SPOT
	# Three bushes between the survivor and the camera, close enough to cover the body at iso pitch,
	# and four more round them: the play-test's "walked into a bush field".
	for off in [SIGHT * 0.9, SIGHT * 1.8 + Vector3(-0.7, 0, 0.7), SIGHT * 2.6 + Vector3(0.8, 0, -0.8)]:
		_bush(b, at + off, 2.2)
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.4
		_bush(b, at + Vector3(cos(a), 0, sin(a)) * 1.7, 2.0)
	Occlusion.auto_fade(b, 2.2)
	b.commit()
	_place(at)
	_o2_roots = [b]
	return b

func _bush(b: VegBatch, pos: Vector3, height: float) -> void:
	var s := height / VegBatch.mesh_height(BUSH)
	b.add(Transform3D(Basis.IDENTITY.rotated(Vector3.UP, float(pos.x * 7.0 + pos.z)).scaled(Vector3.ONE * s), pos))

## A tree whose crown hangs over the survivor: the canopy on the sight line, the trunk beside them.
func _o2_canopy() -> Node:
	var t: VegBatch = _prop(TREE, TREE_SPOT + SIGHT * 2.2, 9.0)
	Occlusion.auto_fade(t, 9.0)
	t.commit()
	_place(TREE_SPOT)
	_o2_roots = [t]
	return t

## Fades the props, measures, saves the picture, then clears the case.
func _o2_case(which: String, root: Node) -> float:
	await _o2_wait(O2_SETTLE)
	var vis := await _o2_visible()
	await _o2_save(which)
	print("[occlude2] case %s visible_before=%.3f visible_after=%.3f fade=%s" % [
		which, vis.x, vis.y, _o2_fade_of(root)])
	for c in _o2_roots:
		if is_instance_valid(c):
			Occlusion.release(c)
			c.queue_free()
	_o2_roots = []
	await _o2_wait(4)
	return vis.y

## The share of the survivor's own silhouette that shows them: with the props solid (the "before"
## number of this case) and with them faded by the system (the "after").
## A pixel shows the survivor when it looks different with the body drawn than without it, props the
## same: that needs no colour match (the ID colour comes out of the tonemapper shifted) and it works
## for a dithered prop, which is the whole question. The silhouette is the body's own pixels (body
## vs no body, props hidden), eroded by 2 px so antialiased edges do not count either way.
func _o2_visible() -> Vector2:
	var body: Array = _player.find_children("*", "GeometryInstance3D", true, false)
	var props: Array = []
	for n: Node in _o2_roots:
		if n is GeometryInstance3D:
			props.append(n)
		for c in n.find_children("*", "GeometryInstance3D", true, false):
			props.append(c)
	# Solid first: the props must not be faded while the "before" frames are taken. Their modes
	# (and trunk lines) are put back afterwards, so the faded frames use the system as shipped.
	# The occluders are not always the case root (the harbour registers each part), so collect every
	# node that actually carries a mode; measuring the root alone left the harbour faded in "before".
	var occs := _o2_occluders()
	var modes := {}
	for n: Node in occs:
		modes[n] = [Occlusion.mode_of(n), float(n.get_meta(&"occl_trunk", 0.0))]
		Occlusion.release(n)
	for p: GeometryInstance3D in props:
		p.visible = false
	_show(body, false)
	var bg := await _o2_frame()
	_show(body, true)
	var masked := await _o2_frame()
	for p: GeometryInstance3D in props:
		p.visible = true
	_show(body, false)
	var solid_off := await _o2_frame()
	_show(body, true)
	var solid_on := await _o2_frame()
	for n: Node in modes:
		var m: Array = modes[n]
		Occlusion.make_occludable(n, str(m[0]))
		if float(m[1]) > 0.0:
			Occlusion.set_trunk(n, float(m[1]))
	# The fade restarts when the occluders are re-made above, and a MultiMesh cell is only filed a frame
	# or two after it exists, so wait for the fade itself (a fixed frame count raced it at 844x390 and
	# made the canopy case swing between 0.56 and 0.74).
	await _o2_settled()
	_show(body, false)
	var faded_off := await _o2_frame()
	_show(body, true)
	var faded_on := await _o2_frame()
	var size := 0
	var before := 0
	var after := 0
	var w := get_viewport().get_texture().get_width()
	# The erosion is in pixels, so it eats a bigger share of the body on the phone: 2 px at 1600 wide
	# (a 2 px antialiased edge), 1 px at 844 (the same edge, half the pixels).
	var er := 2 if w >= 1200 else 1
	for i in range(0, bg.size(), 3):
		if not _diff(bg, masked, i):
			continue
		var x := (i / 3) % w
		var y := (i / 3) / w
		if not _o2_in(bg, masked, w, x - er, y) or not _o2_in(bg, masked, w, x + er, y) \
				or not _o2_in(bg, masked, w, x, y - er) or not _o2_in(bg, masked, w, x, y + er):
			continue
		size += 1
		if _diff(solid_off, solid_on, i):
			before += 1
		if _diff(faded_off, faded_on, i):
			after += 1
	var n := maxf(1.0, float(size))
	print("[occlude2] visible silhouette=%d solid=%d faded=%d" % [size, before, after])
	return Vector2(float(before) / n, float(after) / n)

## Every occludable node of the current case: the roots and any part under them that carries a mode.
func _o2_occluders() -> Array:
	var out: Array = []
	for r: Node in _o2_roots:
		if not is_instance_valid(r):
			continue
		if Occlusion.mode_of(r) != "":
			out.append(r)
		for c in r.find_children("*", "", true, false):
			if Occlusion.mode_of(c) != "":
				out.append(c)
	return out

## Waits until every case prop has finished fading (or 120 frames, so a failure cannot hang the lab).
func _o2_settled() -> void:
	for i in 120:
		var done := true
		for n: Node in _o2_occluders():
			if Occlusion.fade_of(n) < 0.999:
				done = false
		if done:
			break
		await _o2_wait(1)
	await _o2_wait(O2_FRAME)

## Is (x, y) a pixel of the survivor's silhouette (body vs no body, props hidden)?
func _o2_in(bg: PackedByteArray, masked: PackedByteArray, w: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w:
		return false
	var i := (y * w + x) * 3
	return i + 2 < bg.size() and _diff(bg, masked, i)

## One drawn frame after O2_FRAME frames of settle.
func _o2_frame() -> PackedByteArray:
	await _o2_wait(O2_FRAME)
	return await _o2_image()

## Is (x, y) a pixel the tree paints over the empty frame (same rule as the trunk band)?
func _tree_at(solid: PackedByteArray, empty: PackedByteArray, w: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w:
		return false
	var i := (y * w + x) * 3
	if i + 2 >= solid.size():
		return false
	return absi(solid[i] - empty[i]) + absi(solid[i + 1] - empty[i + 1]) + absi(solid[i + 2] - empty[i + 2]) > 20

func _o2_image() -> PackedByteArray:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img.get_data()

func _o2_wait(frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw

func _o2_fade_of(n: Node) -> String:
	if not is_instance_valid(n):
		return "-"
	return "%.2f" % Occlusion.fade_of(n)

func _o2_save(which: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _o2_dir.path_join("occlude2_%s_%dx%d.png" % [which, img.get_width(), img.get_height()])
	img.save_png(path)
	print("[occlude2] shot %s" % path)

## Steps one tree in and out by hand, frame by frame: how long the fade takes and its biggest one-frame
## jump (a pop is over 0.25). The driver's own _process is off for the duration.
func _o2_fade_probe() -> Vector2:
	var t: VegBatch = _prop(TREE, TREE_SPOT + SIGHT * 2.2, 9.0)
	Occlusion.auto_fade(t, 9.0)
	t.commit()
	_place(TREE_SPOT)
	await _o2_wait(8)
	var drv := Occlusion.driver()
	if drv == null:
		return Vector2.ZERO
	drv.set_process(false)
	await _o2_wait(1)
	drv._flush_pending()
	var chest := _player.global_position + Vector3.UP * Occlusion.CHEST_UP_M
	var hits: Dictionary = drv.in_the_way(chest, _cam.global_basis.z)
	var fwd := -_cam.global_basis.z
	var objs: Array = drv._owned.get(t.get_instance_id(), [])
	var secs := 0.0
	var worst := 0.0
	for phase in 2:
		var prev := _o2_tree_fade(objs)
		var steps := 0
		while steps < 240:
			var h: Dictionary = hits if phase == 0 else {}
			drv.step_between(h, O2_FADE_STEP, fwd)
			steps += 1
			var f := _o2_tree_fade(objs)
			worst = maxf(worst, absf(f - prev))
			prev = f
			if (phase == 0 and f >= 0.999) or (phase == 1 and f <= 0.001):
				break
		secs = maxf(secs, float(steps) * O2_FADE_STEP)
	drv.set_process(true)
	Occlusion.release(t)
	t.queue_free()
	await _o2_wait(4)
	print("[occlude2] fade objs=%d in_line=%d seconds=%.3f worst_step=%.3f" % [objs.size(), hits.size(), secs, worst])
	return Vector2(secs, 1.0 if worst > 0.25 else 0.0)

## The fade of the first instance object of `objs` (the tree on the sight line).
func _o2_tree_fade(objs: Array) -> float:
	for o: Occlusion.Obj in objs:
		if o.inst:
			return o.fade
	return 0.0

## How much of a faded tree's trunk still draws: the tree is photographed solid, faded and hidden, and
## every pixel the trunk band of the tree owns (it differs from the empty frame) must look the same
## faded as solid. The shader keeps the trunk solid, so a trunk pixel that changes is a leak.
func _o2_trunk_probe() -> float:
	var t: VegBatch = _prop(TREE, TREE_SPOT + SIGHT * 2.2, 9.0)
	Occlusion.auto_fade(t, 9.0)
	t.commit()
	_place(TREE_SPOT)
	await _o2_wait(8)
	var drv := Occlusion.driver()
	if drv:
		drv.set_process(false)
		await _o2_wait(1)
		drv._flush_pending()
	var chest := _player.global_position + Vector3.UP * Occlusion.CHEST_UP_M
	var hits: Dictionary = drv.in_the_way(chest, _cam.global_basis.z) if drv else {}
	var fwd := -_cam.global_basis.z
	for n: Node in _o2_roots:
		if is_instance_valid(n):
			n.visible = false
	# The survivor's own silhouette thins even a trunk (they must show through it), so take the body
	# out of these frames: this probe is about the trunk's pixels elsewhere.
	for g: GeometryInstance3D in _player.find_children("*", "GeometryInstance3D", true, false):
		g.visible = false
	if drv:
		drv.step_between({}, 1.0, fwd)
	await _o2_wait(6)
	var solid := await _o2_image()
	var cell := t.cell_for(0)
	if cell:
		cell.visible = false
	await _o2_wait(6)
	var empty := await _o2_image()
	if cell:
		cell.visible = true
	if drv:
		drv.step_between(hits, 1.0, fwd)
	await _o2_wait(6)
	var faded := await _o2_image()
	if cell:
		print("[occlude2] dbg cell occl_trunk=%s occl_fade=%s meta=%s" % [
			cell.get_instance_shader_parameter(&"occl_trunk"), cell.get_instance_shader_parameter(&"occl_fade"),
			t.get_meta(&"occl_trunk", "none")])
	var w := get_viewport().get_texture().get_width()
	var h := solid.size() / 3 / w
	var foot := _cam.unproject_position(TREE_SPOT + SIGHT * 2.2)
	var top := _cam.unproject_position(TREE_SPOT + SIGHT * 2.2 + Vector3(0, 9.0, 0))
	# The trunk band of tree-common-a scaled to 9 m: its crown starts at 4.4/8 of the model (4.95 m of
	# 9), so the lowest third of the tree on screen is trunk only (higher up the crown would dither).
	var y0 := maxi(int(top.y + (foot.y - top.y) * 0.62), 0)
	var y1 := mini(int(top.y + (foot.y - top.y) * 0.95), h)
	var kept := 0
	var same := 0
	for y in range(y0, y1):
		for x in w:
			var i := (y * w + x) * 3
			# Only the tree's own pixels in the band, two pixels inside its silhouette: its antialiased
			# edge and its soft shadow both shift by a level or two between frames, and neither is trunk.
			if absi(solid[i] - empty[i]) + absi(solid[i + 1] - empty[i + 1]) + absi(solid[i + 2] - empty[i + 2]) <= 20:
				continue
			if not _tree_at(solid, empty, w, x + 4, y) or not _tree_at(solid, empty, w, x - 4, y) \
					or not _tree_at(solid, empty, w, x, y + 4) or not _tree_at(solid, empty, w, x, y - 4):
				continue
			kept += 1
			if absi(solid[i] - faded[i]) + absi(solid[i + 1] - faded[i + 1]) + absi(solid[i + 2] - faded[i + 2]) <= 14:
				same += 1
	if drv:
		drv.set_process(true)
	Occlusion.release(t)
	t.queue_free()
	for g: GeometryInstance3D in _player.find_children("*", "GeometryInstance3D", true, false):
		g.visible = true
	for n: Node in _o2_roots:
		if is_instance_valid(n):
			n.visible = true
	await _o2_wait(4)
	print("[occlude2] trunk band y=%d..%d tree_pixels=%d unchanged=%d" % [y0, y1, kept, same])
	if OS.get_cmdline_user_args().has("--o2-dbg"):
		var i0 := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, solid)
		var i1 := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, faded)
		var i2 := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, empty)
		var r := Rect2i(0, y0, w, maxi(y1 - y0, 1))
		var out := Image.create(w, r.size.y * 3 + 8, false, Image.FORMAT_RGB8)
		out.fill(Color.BLACK)
		out.blit_rect(i0, r, Vector2i(0, 0))
		out.blit_rect(i1, r, Vector2i(0, r.size.y + 4))
		out.blit_rect(i2, r, Vector2i(0, r.size.y * 2 + 8))
		# Fourth strip: the band with the pixels that changed flagged white, so a leak is visible.
		var im := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, solid)
		for y in range(y0, y1):
			for x in w:
				var i := (y * w + x) * 3
				if absi(solid[i] - empty[i]) + absi(solid[i + 1] - empty[i + 1]) + absi(solid[i + 2] - empty[i + 2]) <= 20:
					continue
				if absi(solid[i] - faded[i]) + absi(solid[i + 1] - faded[i + 1]) + absi(solid[i + 2] - faded[i + 2]) > 14:
					im.set_pixel(x, y, Color.WHITE)
		var out2 := Image.create(w, r.size.y * 4 + 12, false, Image.FORMAT_RGB8)
		out2.fill(Color.BLACK)
		out2.blit_rect(out, Rect2i(0, 0, w, out.get_height()), Vector2i.ZERO)
		out2.blit_rect(im, r, Vector2i(0, out.get_height() + 4))
		out2.save_png(_o2_dir.path_join("occlude2_trunk_band.png"))
		print("[occlude2] trunk band shot %s" % _o2_dir.path_join("occlude2_trunk_band.png"))
	return float(same) / maxf(1.0, float(kept))
