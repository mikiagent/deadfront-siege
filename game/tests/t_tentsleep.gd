extends SceneTree
## TENTSLEEP (owner, verbatim): "sleeping in a tent doesn't place me within the actual tent. When
## sleeping in the tent, put the player inside laying down and use the occlusion to see through the
## tent slightly transparent" and "make it so you can stay in the tent for as long as you would like.
## It kicks you out when you are no longer exhausted".
## Sleep in a tent: her whole skeleton lies inside the footprint along the ridge, sleep_down then the
## sleep loop plays, her collision ignores the tent, the tent fades to about half. Exhaustion reaches 0
## and she stays inside, no use spent yet; Get up (the hex) steps her out of the door, restores the
## collision, the tent goes opaque, the use and Well Rested land once. A real hit restores the same.
## A straw roll still ends on its own. Windowed (not headless) it also writes the PNGs.
## Usage: godot --headless --path game --script res://tests/t_tentsleep.gd

const SHOTS := "res://../docs/orchestration/reports/tentsleep/"

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var rt
var cam
var Occl

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
	print("[t_tentsleep] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _seconds(s: float) -> void:
	await create_timer(s).timeout

func _run() -> void:
	get_root().get_node("Game").max_creatures_per_island = 0
	get_root().get_node("Game").debug_overlay = false
	Occl = load("res://scripts/world/occlusion.gd")
	host = Node3D.new()
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = world.runtime
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	cam = (load("res://scripts/camera/iso_camera.gd") as GDScript).new()
	host.add_child(cam)
	cam.current = true
	cam.set("_target", player)
	var dig = load("res://scripts/items/digestion.gd").of(player)
	dig.rows().clear()
	dig.starter_given = true
	dig.schedule(&"starter", 1.0, 1.0e9)
	# Open ground east of the camp, clear of the camp tent, bonfire and bench.
	var at: Vector3 = _clear_site(rt._camp_pos)
	at.y = rt.surface_y(at.x, at.z)
	player.global_position = at + Vector3(0, 3, 0)
	await _frames(10)
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	rt.weather.raining = false
	rt.weather.set("_rain_cd", 1.0e9)
	var tent = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"tent")
	# Door (local +X) toward the camera, so she walks out toward the viewer and the shot sees the doorway.
	cam.set("min_size", 5.0)
	cam.set("size", 5.5)
	if cam.has_method("_snap"):
		cam._snap()
	await _frames(2)
	# Door (local +X) toward the camera, so she walks out toward the viewer and the shot sees the doorway.
	var back: Vector3 = cam.global_basis.z
	# Placed tents turn in 90 deg steps (set_grid_pose): the step whose door is nearest the camera.
	tent.rotation.y = snappedf(atan2(-back.z, back.x), PI * 0.5)
	tent.position = at
	rt.add_child(tent)
	await _frames(5)
	var half: Vector3 = 0.5 * (tent.get_node("Shape").shape as BoxShape3D).size

	# --- lie down in the tent
	player.global_position = tent.global_transform * Vector3(1.8, 0, 0) + Vector3(0, 1, 0)
	await _frames(10)
	player.vitals.fatigue = 80.0
	player._last_hit_taken_s = -999.0
	player.sim.start_sleep(tent)
	_expect(player._sleep_left > 0.0, "the tent sleep starts")
	await _frames(3)
	_expect(player.anim.current_clip == &"sleep_down", "she lies down with sleep_down (%s)" % player.anim.current_clip)
	await _seconds(3.5)
	_expect(_inside(tent, player.global_position, half), "her body is inside the tent footprint (local %s, half %s)" % [_local(tent, player.global_position), half])
	_expect(player.anim.current_clip == &"sleep" and player.anim._sleeping, "the sleep loop plays (%s)" % player.anim.current_clip)
	var ext := _bone_extent(tent)
	_expect(ext.x <= half.x + 0.1 and ext.y <= half.z + 0.1, "every bone lies inside the tent (|x| %.2f <= %.2f, |z| %.2f <= %.2f)" % [ext.x, half.x, ext.y, half.z])
	_expect(player.get_collision_exceptions().has(tent), "her collision ignores the tent while she is inside")
	var fade := _tent_fade(tent, true)
	var opacity: float = 1.0 - fade * Occl.BETWEEN_DROP
	_expect(opacity >= 0.4 and opacity <= 0.55, "the occupied tent is see-through: %.0f%% opacity (fade %.2f)" % [opacity * 100.0, fade])
	await _shot("asleep_in_tent")

	# --- exhaustion reaches 0 and she stays
	await _seconds(tent.sleep_duration())
	_expect(player.vitals.fatigue < 1.0, "the sleep cleared exhaustion (%.2f)" % player.vitals.fatigue)
	_expect(player._sleep_left > 0.0 and player.sim._slept_full and player.anim._sleeping, "at 0 exhaustion she is still asleep (left %.3f)" % player._sleep_left)
	_expect(_inside(tent, player.global_position, half), "and still inside the tent")
	_expect(int(tent.sleeps_left) == 6 and not player.statuses.has(&"well_rested"), "nothing is paid out until she gets up (uses %d)" % tent.sleeps_left)
	var hexes: Array = player.context_actions()
	_expect(hexes.size() == 1 and str(hexes[0]["id"]) == "get_up", "the one hex is Get up %s" % [hexes])
	await _shot("rested_still_inside")

	# --- Get up
	player.context_action("get_up")
	await _frames(2)
	_expect(player._sleep_left <= 0.0 and not player.anim._sleeping, "Get up wakes her")
	_expect(player.anim.current_clip == &"sleep_up", "she gets up with sleep_up (%s)" % player.anim.current_clip)
	var loc := _local(tent, player.global_position)
	_expect(loc.x > half.x + 0.3 and absf(loc.z) < 0.5, "she stands outside the doorway (local %s)" % loc)
	_expect(not player.get_collision_exceptions().has(tent), "her collision with the tent is back")
	_expect(int(tent.sleeps_left) == 5, "the completed sleep spent one use (%d left)" % tent.sleeps_left)
	var wr = player.statuses.get_instance(&"well_rested")
	_expect(wr != null, "Well Rested on getting up")
	var wr_t: float = wr.time_left if wr else -1.0
	player.sim.get_up()
	await _frames(2)
	var wr2 = player.statuses.get_instance(&"well_rested")
	_expect(int(tent.sleeps_left) == 5 and wr2 != null and wr2.time_left <= wr_t, "the rewards land once (uses %d)" % tent.sleeps_left)
	await _seconds(1.0)
	_expect(_tent_fade(tent, false) < 0.05, "the tent is opaque again (fade %.2f)" % _tent_fade(tent, false))
	await _seconds(1.5)
	await _shot("awake_outside")

	# --- a real hit
	player.vitals.fatigue = 80.0
	player._last_hit_taken_s = -999.0
	player.sim.start_sleep(tent)
	await _seconds(1.5)
	_expect(player._sleep_left > 0.0 and _inside(tent, player.global_position, half), "asleep inside again")
	player.vitals.take_damage(1.0)
	await _frames(2)
	_expect(player._sleep_left <= 0.0 and not player.anim._sleeping, "a real hit wakes her")
	loc = _local(tent, player.global_position)
	_expect(loc.x > half.x + 0.3, "the hit puts her outside the doorway (local %s)" % loc)
	_expect(not player.get_collision_exceptions().has(tent), "and her collision is back")
	_expect(int(tent.sleeps_left) == 5, "an unfinished sleep spends no use (%d)" % tent.sleeps_left)
	await _seconds(1.0)
	_expect(_tent_fade(tent, false) < 0.05, "the tent is opaque after the hit (fade %.2f)" % _tent_fade(tent, false))

	# --- a straw roll still ends on its own
	await _seconds(2.5)
	var roll = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"straw_roll")
	roll.position = at + Vector3(-4.0, 0.0, 3.0)
	roll.position.y = rt.surface_y(roll.position.x, roll.position.z)
	rt.add_child(roll)
	await _frames(3)
	player.global_position = roll.wake_anchor() + Vector3(0, 1, 0)
	await _frames(5)
	player.vitals.fatigue = 60.0
	player._last_hit_taken_s = -999.0
	player.sim.start_sleep(roll)
	_expect(player._sleep_left > 0.0, "the straw roll sleep starts")
	for i in 40:
		if player._sleep_left <= 0.0:
			break
		player.sim._tick_sleep(0.5)
	_expect(player._sleep_left <= 0.0 and not player.get_collision_exceptions().has(roll), "a straw roll sleep ends on its own, collision back")
	_finish()

## Least (`least`) or most faded of the tent's see-through meshes: each mesh is its own occlusion object.
func _tent_fade(b: Node3D, least: bool) -> float:
	var out := 1.0 if least else 0.0
	var n := 0
	for gi in b.find_children("*", "GeometryInstance3D", true, false):
		if Occl.mode_of(gi) == "" or int(gi.get_meta(&"occl_surfaces", 0)) == 0:
			continue
		n += 1
		out = minf(out, Occl.fade_of(gi)) if least else maxf(out, Occl.fade_of(gi))
	return out if n > 0 else -1.0

## Open ground near the camp with no harvest node within 4 m and clear of the camp's own pieces, so the
## shot shows the tent and not a reed bed.
func _clear_site(camp: Vector3) -> Vector3:
	var best := camp + Vector3(9.0, 0.0, 4.0)
	var best_d := -1.0
	for r in [8.0, 10.0, 12.0, 14.0]:
		for k in 16:
			var c: Vector3 = camp + Vector3(cos(k * TAU / 16.0), 0.0, sin(k * TAU / 16.0)) * r
			var near := INF
			for n in rt._harvest_nodes.values():
				if is_instance_valid(n):
					near = minf(near, Vector2(n.global_position.x - c.x, n.global_position.z - c.z).length())
			if near > best_d:
				best_d = near
				best = c
	best.y = rt.surface_y(best.x, best.z)
	print("[t_tentsleep] site %s, nearest harvest node %.1f m" % [best, best_d])
	return best

func _local(b: Node3D, at: Vector3) -> Vector3:
	return b.global_transform.affine_inverse() * at

func _inside(b: Node3D, at: Vector3, half: Vector3) -> bool:
	var q := _local(b, at)
	return absf(q.x) < half.x and absf(q.z) < half.z

## Largest |x| and |z| of any bone in the tent's frame.
func _bone_extent(b: Node3D) -> Vector2:
	var sk: Skeleton3D = player.rig.skeleton
	var out := Vector2.ZERO
	for i in sk.get_bone_count():
		var q := _local(b, sk.global_transform * sk.get_bone_global_pose(i).origin)
		out = Vector2(maxf(out.x, absf(q.x)), maxf(out.y, absf(q.z)))
	return out

func _shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var path := ProjectSettings.globalize_path(SHOTS + tag + ".png")
	get_root().get_texture().get_image().save_png(path)
	print("[t_tentsleep] shot %s" % path)

func _finish() -> void:
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_tentsleep] PASS")
		quit(0)
	else:
		print("[t_tentsleep] FAIL count=%d" % failures.size())
		quit(1)
