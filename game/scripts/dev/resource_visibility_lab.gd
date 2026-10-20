extends Node3D
## Regression lab: resources beside a player far from island origin stay rendered and tappable.

const FAR_X := 112.0
var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 18.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_player.global_position = Vector3(FAR_X, 1.0, 0.0)
	_cam._target = _player
	_cam.size = 15.0
	_cam._snap()
	var floor := get_node_or_null("Floor") as Node3D
	if floor:
		floor.global_position.x = FAR_X
	var batch := VegBatch.get_for(self, "res://assets/nature/BirchTree_3.glb")
	if batch == null:
		push_error("[resource_visibility] missing regression asset")
		get_tree().quit(1)
		return
	for i in 5:
		var p := Vector3(FAR_X - 5.0 + float(i) * 2.5, 0.0, -1.0 + float(i % 2) * 3.0)
		var node: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
		node.position = p
		add_child(node)
		node.setup(StringName("far_tree_%d" % i), &"wood_log", 1, 1, {}, &"none", Color(0.35, 0.6, 0.25), 1.0, 60.0, "BirchTree", false, 4)
		var h := VegBatch.mesh_height("res://assets/nature/BirchTree_3.glb")
		var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (5.5 / h)), p)
		node.set_batched_visual(batch, batch.add(xf))
	# One more tree past the island origin, ~190 m from the camera: its cell must be range-culled.
	var far_idx := batch.add(Transform3D(Basis.IDENTITY, Vector3(-60.0, 0.0, -60.0)))
	batch.commit()
	# Cells, not the whole island batch, are culled. Every cell holding a tree beside the survivor
	# must be in range of the camera, measured both to the cell origin and to its AABB centre.
	var cam_pos := _cam.global_position
	var worst := 0.0
	var range_end := 0.0
	for i in 5:
		var cell := batch.cell_for(i)
		if cell == null:
			push_error("[resource_visibility] tree %d has no cell" % i)
			get_tree().quit(1)
			return
		var centre: Vector3 = cell.global_transform * cell.get_aabb().get_center()
		worst = maxf(worst, maxf(cam_pos.distance_to(cell.global_position), cam_pos.distance_to(centre)))
		range_end = cell.visibility_range_end
	var far_cell := batch.cell_for(far_idx)
	var far_d := cam_pos.distance_to(far_cell.global_position)
	print("[resource_visibility] player_from_batch_origin=%.1f cells=%d near_cell_cam_dist=%.1f range_end=%.1f far_cell_cam_dist=%.1f instances=%d" % [
		_player.global_position.distance_to(batch.global_position), batch.get_child_count(), worst, range_end, far_d, batch.instance_count()])
	if is_zero_approx(range_end) or worst >= range_end:
		push_error("[resource_visibility] a cell beside the survivor is outside its visibility range")
		get_tree().quit(1)
		return
	if far_d <= far_cell.visibility_range_end or far_cell == batch.cell_for(0):
		push_error("[resource_visibility] the far cell is not range-culled")
		get_tree().quit(1)
		return
	var sample := get_tree().get_first_node_in_group("harvest") as HarvestNode
	var tap := sample.get_node_or_null("TapZone") as Area3D if sample else null
	if sample == null or tap == null or tap.collision_layer == 0:
		push_error("[resource_visibility] nearby visual lost its interaction body")
		get_tree().quit(1)
		return
	print("[resource_visibility] PASS nearby cells render, the far cell is culled, interaction lifetime matches")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().quit(0)
