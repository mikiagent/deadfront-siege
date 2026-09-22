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
	batch.commit()
	print("[resource_visibility] player_from_batch_origin=%.1f range_end=%.1f instances=%d" % [
		_player.global_position.distance_to(batch.global_position), batch.visibility_range_end, batch.multimesh.instance_count])
	if not is_zero_approx(batch.visibility_range_end):
		push_error("[resource_visibility] batched resources still have render-only distance culling")
		get_tree().quit(1)
		return
	var sample := get_tree().get_first_node_in_group("harvest") as HarvestNode
	var tap := sample.get_node_or_null("TapZone") as Area3D if sample else null
	if sample == null or tap == null or tap.collision_layer == 0:
		push_error("[resource_visibility] nearby visual lost its interaction body")
		get_tree().quit(1)
		return
	print("[resource_visibility] PASS visible lifetime matches interaction lifetime")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().quit(0)
