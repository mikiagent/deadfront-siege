extends SceneTree
## RUMMAGE (owner 2026-10-28: the survivor opens a bag in the wild and rummages while the bag menu is up).
## PlayerAnim.play_rummage(true) plays rummage_in then loops rummage with the satchel prop shown and in sync;
## play_rummage(false) plays rummage_out, then idle with the satchel hidden; walking off ends it at once.
## The satchel sits on the ground in front of her while she kneels. Station work: play_work(kind) loops
## work_* (the hammer shows on work_hammer only here), stop_work() idles; play_oneshot(&"kick_dirt") ends in idle.
## Usage: godot --headless --path game --script res://tests/t_rummage.gd
##        windowed with `-- --shots <dir>` it also saves front and side frames across in / loop / out.

var failures: Array[String] = []
var _started := false
var player
var shots := ""

func _process(_delta: float) -> bool:
	if _started or get_root().get_node_or_null("World") == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		shots = args[args.find("--shots") + 1]
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_rummage] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	player.global_position = world.runtime._camp_pos + Vector3(7, 1, 7)  # clear of the camp's tent and fire, for the shots
	await _frames(30)
	var anim = player.anim
	_expect(player.rig != null and player.rig.has_clip(&"rummage_in") and player.rig.has_clip(&"rummage")
		and player.rig.has_clip(&"rummage_out"), "the survivor has rummage_in, rummage and rummage_out")
	_expect(player.rig.anim_player.get_animation(&"rummage").loop_mode == Animation.LOOP_LINEAR, "rummage loops")
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.current = true
	anim.play_rummage(true)
	await _frames(2)
	_expect(anim.current_clip == &"rummage_in", "play_rummage(true) kneels into rummage_in (%s)" % anim.current_clip)
	var sat: Node3D = anim._satchel
	_expect(sat != null and sat.is_visible_in_tree(), "the satchel shows while rummaging")
	if sat == null:
		_finish()
		return
	_expect(sat.get_parent() == player.rig.mesh_root, "the satchel shares the survivor's model root")
	await _shoot(cam, "in", player.rig.anim_player.get_animation(&"rummage_in").length)
	_expect(anim.current_clip == &"rummage" and anim._satchel_ap.current_animation == &"rummage",
		"rummage_in hands over to the rummage loop, satchel in sync (%s / %s)" % [anim.current_clip, anim._satchel_ap.current_animation])
	# while kneeling the satchel is on the ground in front of her
	var bag_bone: int = (sat.find_child("Skeleton3D", true, false) as Skeleton3D).find_bone("Satchel")
	var sk: Skeleton3D = sat.find_child("Skeleton3D", true, false)
	var bag_pos: Vector3 = sk.global_transform * sk.get_bone_global_pose(bag_bone).origin
	var feet_y: float = player.rig.global_position.y
	var fwd: Vector3 = player.rig.mesh_root.global_basis.z.normalized()  # the survivor faces the model root's +Z
	var ahead: float = (bag_pos - player.rig.global_position).dot(fwd) / player.rig.mesh_root.global_basis.get_scale().x
	_expect(absf(bag_pos.y - feet_y) < 0.05, "the satchel stands on the ground (%.3f vs feet %.3f)" % [bag_pos.y, feet_y])
	_expect(bag_bone >= 0 and ahead > 0.3 and ahead < 0.8, "the satchel is in front of her knees (%.2f model m ahead)" % ahead)
	await _shoot(cam, "loop", 5.0)
	_expect(anim.current_clip == &"rummage", "the loop keeps going until told to stop")
	anim.play_rummage(false)
	await _frames(2)
	_expect(anim.current_clip == &"rummage_out" and sat.visible, "play_rummage(false) shuts the bag and stands (%s)" % anim.current_clip)
	await _shoot(cam, "out", player.rig.anim_player.get_animation(&"rummage_out").length + 0.4)
	_expect(not anim.is_rummaging() and not sat.visible, "after rummage_out she idles and the satchel is gone (%s)" % anim.current_clip)
	# walking off cancels
	anim.play_rummage(true)
	await _frames(10)
	anim._physics_tick(1.5, false)
	await _frames(2)
	_expect(not anim.is_rummaging() and not sat.visible, "walking off ends the rummage (%s)" % anim.current_clip)
	# station work loops (play_work / stop_work) and the worksite kick (play_oneshot)
	for c in anim.WORK_CLIPS + [&"kick_dirt"]:
		_expect(player.rig.has_clip(c), "the survivor has %s" % c)
	anim.play_work(&"hammer")
	await _frames(2)
	_expect(anim.current_clip == &"work_hammer" and anim.is_working(), "play_work(&\"hammer\") plays work_hammer (%s)" % anim.current_clip)
	_expect(anim._hammer.size() > 0 and anim._hammer[0].is_visible_in_tree(), "the hammer is in her hand while hammering")
	await _shoot(cam, "work_hammer", 4.2)
	_expect(anim.current_clip == &"work_hammer", "work_hammer loops until stopped")
	anim.play_work(&"stir")
	await _frames(2)
	_expect(anim.current_clip == &"work_stir" and not anim._hammer[0].visible, "work_stir has no hammer")
	anim.stop_work()
	await _frames(2)
	_expect(not anim.is_working(), "stop_work() returns to the idle (%s)" % anim.current_clip)
	anim.play_oneshot(&"kick_dirt")
	await _frames(2)
	_expect(anim.current_clip == &"kick_dirt", "play_oneshot(&\"kick_dirt\") plays (%s)" % anim.current_clip)
	await _shoot(cam, "kick_dirt", 1.9)
	_expect(anim.current_clip != &"kick_dirt", "kick_dirt returns to the idle (%s)" % anim.current_clip)
	_finish()

## Wait `secs`; with --shots, save front and side frames on the way (8 per clip phase).
func _shoot(cam: Camera3D, tag: String, secs: float) -> void:
	if shots == "":
		await create_timer(secs).timeout
		return
	var n := 8
	for i in n:
		var c: Vector3 = player.rig.global_position + Vector3(0, 0.55, 0)
		var fwd: Vector3 = player.rig.mesh_root.global_basis.z.normalized()  # the survivor faces the model root's +Z
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		for v in [["front", fwd * 2.6 + Vector3(0, 1.4, 0)], ["side", side * 2.6 + Vector3(0, 0.6, 0)]]:
			cam.look_at_from_position(c + v[1], c)
			await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s/%s_%s_%d.png" % [shots, tag, v[0], i])
		await create_timer(secs / n).timeout

func _finish() -> void:
	if failures.is_empty():
		print("[t_rummage] PASS")
		quit(0)
	else:
		print("[t_rummage] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
