extends SceneTree
## LEGSFIX (owner): "where did my legs go?" / "the testing agents have my player model halfway in the
## ground". A new game and every sail land her at the dock's arrival point. On the north-up camera the
## dock shed's roof stood between the camera and her legs there, half faded, so her lower half looked
## gone. She now lands IslandRuntime.LANDING_ROW rows behind the base.
## Checks, on the tutorial isle and the home island, landed the way the game lands her: her leg meshes
## are visible, her feet stand on the floor (not in it), and no other visible mesh lies on the sight line
## from the camera to her knees, hips or feet. Windowed it writes the PNGs.
## Usage: godot --headless --path game --script res://tests/t_legsfix.gd

const SHOTS := "res://../docs/orchestration/reports/legsfix/"

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var shot_tag := OS.get_environment("LEGSFIX_TAG")

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_legsfix] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	get_root().get_node("Game").max_creatures_per_island = 0
	get_root().get_node("Game").debug_overlay = false
	var world := get_root().get_node("World")
	for island: StringName in [&"tutorial_isle", &"home_grassland"]:
		host = Node3D.new()
		get_root().add_child(host)
		world.load_island(host, island, Vector3(0, 1, 0), false)
		await process_frame
		var rt = world.runtime
		player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
		host.add_child(player)
		var cam = (load("res://scripts/camera/iso_camera.gd") as GDScript).new()
		host.add_child(cam)
		cam.current = true
		cam._target = player
		player.global_position = rt.arrival_point() + Vector3.UP  # as World / Tutorial land her
		cam._snap()
		await _frames(30)
		for c in get_nodes_in_group("creatures"):
			c.queue_free()
		await _frames(30)
		await _check(island, cam)
		await _shot("%s_landing" % island)
		host.queue_free()
		await process_frame
	_finish()

func _check(island: StringName, cam: Camera3D) -> void:
	var sk: Skeleton3D = player.rig.skeleton
	var legs: Array = (player.equipment.body.get("legs", []) as Array) if player.equipment else []
	if legs.is_empty():
		legs = player.rig.mesh_root.find_children("*", "MeshInstance3D", true, false)
	_expect(not legs.is_empty() and legs.all(func (m) -> bool: return (m as MeshInstance3D).is_visible_in_tree()),
		"%s: her leg meshes are visible (%d)" % [island, legs.size()])
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, player.global_position + Vector3.DOWN * 4.0, 0xFFFFFFFF, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var floor_y: float = (hit.get("position", Vector3.ZERO) as Vector3).y
	var foot := _bone(sk, "LeftToeBase")
	var hips := _bone(sk, "Hips")
	_expect(not hit.is_empty() and player.is_on_floor(), "%s: she stands on a floor (%s)" % [island, hit.get("collider")])
	_expect(foot.y >= floor_y - 0.08 and foot.y <= floor_y + 0.25, "%s: her toes are on the floor, not in it (toe %.2f, floor %.2f)" % [island, foot.y, floor_y])
	_expect(hips.y - floor_y >= 0.8, "%s: her hips stand %.2f m above the floor" % [island, hips.y - floor_y])
	var eye := cam.global_position
	var blockers: Array[String] = []
	for bn in ["LeftLeg", "RightLeg", "Hips", "LeftFoot", "RightFoot"]:
		var at := _bone(sk, bn)
		for g in get_root().find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			if player.is_ancestor_of(gi) or not gi.is_visible_in_tree() or gi is Label3D or gi is Sprite3D or gi is GPUParticles3D:
				continue
			var box: AABB = gi.global_transform * gi.get_aabb()
			if box.size.length() > 40.0 or box.has_point(at):  # terrain, water, sky; or what she stands inside (a ring)
				continue
			if box.intersects_segment(at, eye) != null and box.end.y > at.y + 0.3:
				blockers.append("%s>%s" % [bn, gi.name])
	_expect(blockers.is_empty(), "%s: nothing stands between the camera and her legs %s" % [island, blockers])

func _bone(sk: Skeleton3D, name: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin

func _shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var path := ProjectSettings.globalize_path(SHOTS + (shot_tag + "_" if shot_tag != "" else "") + tag + ".png")
	get_root().get_texture().get_image().save_png(path)
	print("[t_legsfix] shot %s" % path)

func _finish() -> void:
	await process_frame
	if failures.is_empty():
		print("[t_legsfix] PASS")
		quit(0)
	else:
		print("[t_legsfix] FAIL %d: %s" % [failures.size(), failures])
		quit(1)
