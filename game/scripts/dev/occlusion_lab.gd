extends Node3D
## --lab=occlusion_lab: the see-through system (Occlusion) on one tall tree and one big rock
## ("between", spawned the way island_scatter batches them) and a test hut whose roof is "inside".
## The survivor's spot comes from the shot name: "rock", "inside" (under the roof), "outside"
## (beside the hut); anything else stands just behind the tree. --no-occlusion is the baseline.
## Headless: prints [occl] lines and quits.
## --occl-perf (windowed): island_lab's island and camp view with the scatter hook applied; times
## frames with every occludable prop on and released, alternating, and prints [occl] perf.

const TREE := "res://assets/nature/generated/tree-common-a.glb"
const ROCK := "res://assets/nature/Rock_1.glb"
## Iso camera sits towards +x/+z, so an offset along SIGHT puts a prop between it and the survivor.
const SIGHT := Vector3(0.7071, 0.0, 0.7071)
const TREE_SPOT := Vector3(0, 0, 0)
const ROCK_SPOT := Vector3(-11, 0, -4)
const HUT_SPOT := Vector3(10, 0, -6)
const PERF_FRAMES := 240
const PERF_ROUNDS := 4
## Frames skipped after each switch: a released prop recompiles its pipeline once.
const PERF_SETTLE := 30

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
	if Game.shot_path != "" or "--occl-perf" in OS.get_cmdline_user_args():
		TouchControls.visible = false
		TouchControls.enabled = false
		(kit["ui"] as CanvasLayer).visible = false
	if "--occl-perf" in OS.get_cmdline_user_args():
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
	_player.global_position = spot + Vector3(0, 1.0, 0)
	_player.rotation.y = PI * 0.25  # facing the camera
	_cam._snap()
	print("[occl] enabled=%s tree=%d rock=%d roof=%d" % [Occlusion.enabled, tree_n, rock_n, roof_n])
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(0.5).timeout.connect(_report)

func _report() -> void:
	# The tree's cells committed after its hook ran: a non-zero count proves the late-child path.
	print("[occl] tree=%d rock=%d roof=%s fade=%.2f" % [
		int(_tree.get_meta(&"occl_surfaces", 0)), int(_rock.get_meta(&"occl_surfaces", 0)),
		Occlusion.mode_of(_roof), Occlusion.fade_of(_roof)])
	get_tree().quit(0)

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
	# Stand on the tree's far side so its crown is on the sight line (the worst case: dither active).
	var at := tree.global_position - SIGHT * 1.8
	_player.global_position = Vector3(at.x, World.runtime.surface_y(at.x, at.z) + 1.0, at.z)
	_cam._snap()
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var ms := {true: Vector3.ZERO, false: Vector3.ZERO}  # x cpu render, y gpu, z process
	for r in PERF_ROUNDS * 2:
		var on := r % 2 == 0
		for n in occ:
			if on:
				Occlusion.make_occludable(n, Occlusion.BETWEEN)
			else:
				Occlusion.release(n)
		for i in PERF_SETTLE:
			await RenderingServer.frame_post_draw
		for i in PERF_FRAMES:
			await RenderingServer.frame_post_draw
			ms[on] += Vector3(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
				RenderingServer.viewport_get_measured_render_time_gpu(vp), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var n_frames := float(PERF_ROUNDS * PERF_FRAMES)
	var a: Vector3 = ms[true] / n_frames
	var b: Vector3 = ms[false] / n_frames
	print("[occl] perf props=%d on cpu=%.3f gpu=%.3f process=%.3f | off cpu=%.3f gpu=%.3f process=%.3f | delta frame=%.3f ms" % [
		occ.size(), a.x, a.y, a.z, b.x, b.y, b.z, maxf(a.x, a.y) - maxf(b.x, b.y)])
	get_tree().quit(0)
