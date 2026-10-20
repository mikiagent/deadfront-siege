extends SceneTree
## Structart review shot (W1-STRUCTART acceptance, adapted from the 2026-10-18 audit set-up): boot the real build_lab windowed, place a small base through the real
## BuildPlacer.confirm path, swap each placed visual for its Blender GLB (swap_visual below, the
## integrator hook previewed) and screenshot the base plus a close-up of the four drying racks
## (<out>_racks.png). No save/load, no repo writes.
## Run: Godot --path game [--rendering-method gl_compatibility] --resolution 1600x900 \
##   --script $PWD/tools/blender/structures/built_base_shot.gd -- --lab=build_lab --out=<png>

var _out := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	change_scene_to_file(str(ProjectSettings.get_setting("application/run/main_scene")))
	_go.call_deferred()

func _go() -> void:
	var lab: Node = null
	for i in 400:
		await process_frame
		lab = root.find_child("BuildLab", true, false)
		if lab and lab.get("_player") != null and lab.call("_grid") != null:
			break
	if lab == null:
		print("[audit] no lab"); quit(1); return
	for i in 60:
		await process_frame
	var player: Node = lab.get("_player")
	var IS := load("res://scripts/items/item_stack.gd")
	var kits := {"tent_kit": 1, "basket_kit": 3, "fence_kit": 8, "gate_kit": 1, "workbench_kit": 1, "campfire_kit": 1, "stone_grill_kit": 1, "well_kit": 1, "mortar_kit": 1, "catapult_kit": 1, "field_small_kit": 1, "steamer_kit": 1, "sign_kit": 1, "smoker_kit": 1, "drying_rack_kit": 4, "crock_pot_kit": 1, "stone_fire_pit_kit": 1}
	for k in kits:
		player.inventory.add(IS.make(StringName(k), kits[k]))
	var grid: Node = lab.call("_grid")
	var anchor: Vector2i = lab.call("_find_anchor_cell")
	player.global_position = grid.tile_centre(anchor + Vector2i(3, 3), grid.runtime) + Vector3(0, 1, 0)
	var placer: Node = player.get("placer")
	var plan := [
		[&"tent", Vector2i(0, 0), 0], [&"basket", Vector2i(4, 0), 0], [&"basket", Vector2i(5, 0), 0],
		[&"workbench", Vector2i(4, 2), 0], [&"campfire", Vector2i(6, 2), 0], 
		[&"well", Vector2i(11, 3), 0], [&"mortar", Vector2i(6, 0), 0], [&"smoker", Vector2i(0, -3), 0],
		[&"fence", Vector2i(0, 5), 0], [&"fence", Vector2i(2, 5), 0], [&"gate", Vector2i(4, 5), 0], [&"fence", Vector2i(6, 5), 0],
		 [&"sign", Vector2i(8, 3), 0],
		[&"steamer", Vector2i(7, 4), 0], [&"catapult", Vector2i(10, 6), 0],
		[&"drying_rack", Vector2i(10, -3), 0], [&"drying_rack", Vector2i(12, -3), 0], [&"drying_rack", Vector2i(12, -1), 0], [&"drying_rack", Vector2i(12, 1), 0],
		[&"stone_fire_pit", Vector2i(6, -3), 0],
	]
	for p in plan:
		var target: Vector2i = anchor + p[1]
		player.global_position = grid.tile_centre(target + Vector2i(1, 2), grid.runtime) + Vector3(0, 1, 0)
		placer.begin(p[0])
		placer.set("cell", target)
		placer.set("rot_step", p[2])
		placer.call("_sync_grid_state")
		var ok: bool = placer.confirm(player)
		print("[audit] place %s at %s ok=%s reason=%s" % [p[0], target, ok, placer.get("reason")])
		placer.cancel()
	# STRUCTART: preview the integrator hook by swapping each placed visual for its Blender GLB.
	var stages := ["empty", "raw", "drying", "dried"]
	var racks := 0
	var swapped := 0
	var nodes: Array = root.get_tree().get_nodes_in_group("placed_building")
	nodes.sort_custom(func(a, b): return a.global_position.x * 100.0 + a.global_position.z < b.global_position.x * 100.0 + b.global_position.z)
	for n in nodes:
		var st := ""
		if str(n.get("kind")) == "drying_rack":
			st = stages[racks % 4]
			racks += 1
		if swap_visual(n, st):
			swapped += 1
	print("[audit] swapped %d visuals, racks %d" % [swapped, racks])
	player.global_position = grid.tile_centre(anchor + Vector2i(4, 2), grid.runtime) + Vector3(0, 1, 0)
	var cam: Node = lab.get("_cam")
	if cam:
		cam.set("size", 22.0)
		cam.call("_snap")
	for i in 30:
		await process_frame
	var ghost_tile: Vector2i = anchor + Vector2i(8, 8)
	var gp: Vector3 = grid.tile_centre(ghost_tile, grid.runtime)
	var game: Node = root.get_node("Game")
	game.set("pointer", (cam as Camera3D).unproject_position(gp))
	for i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(_out)
	print("[audit] shot %s" % _out)
	# Close-up on the four drying-rack stages.
	player.global_position = grid.tile_centre(anchor + Vector2i(10, 0), grid.runtime) + Vector3(0, 1, 0)
	cam.set("size", 10.0)
	cam.call("_snap")
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img2 := root.get_viewport().get_texture().get_image()
	var out2 := _out.replace(".png", "_racks.png")
	img2.save_png(out2)
	print("[audit] shot %s" % out2)
	quit(0)

## Manifest GLB for a kind, or for one of its processing stages (`stages[i].glb`, the lookup W2-PROCESS uses).
func glb_path(kind: StringName, stage: String = "") -> String:
	var row: Variant = ((root.get_node("Data").get("props_manifest") as Dictionary).get("buildings", {}) as Dictionary).get(str(kind), {})
	if not row is Dictionary:
		return ""
	if stage == "":
		return str((row as Dictionary).get("glb", ""))
	for st: Variant in (row as Dictionary).get("stages", []):
		if st is Dictionary and str((st as Dictionary).get("id", "")) == stage:
			return str((st as Dictionary).get("glb", ""))
	return ""

## Preview of the integrator hook: swap a placed building's Kenney or procedural visual for its
## Blender GLB. Returns false when the kind has no glb row.
func swap_visual(building: Node3D, stage: String = "") -> bool:
	var kind := StringName(str(building.get("kind")))
	if kind == &"" and building.get("station_id") != null:
		kind = StringName(str(building.get("station_id")))
	if kind == &"gate":
		kind = &"fence_gate"
	var path := glb_path(kind, stage)
	if path == "" or not ResourceLoader.exists(path):
		return false
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	for child in building.get_children():
		# FieldCatapult builds its body from bare MeshInstance3D children; buildings use Prop.
		if child.name == &"Prop" or child.name == &"FallbackMesh" or (child is MeshInstance3D and child.name != &"Foundation"):
			building.remove_child(child)
			child.queue_free()
	inst.name = "Prop"
	building.add_child(inst)
	return true
