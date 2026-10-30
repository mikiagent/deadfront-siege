extends SceneTree
## POSEFIX (owner): "character is stuck bending sideways? weird bug." The survivor's clips do not all key
## the same bones: swim, swim_idle, the state idles (tired, exhausted), the rummage and some work loops key
## Spine and the feet, the rest (idle, walk, run, idle_cold ...) leave them out. The AnimationPlayer was
## not deterministic, so a bone the new clip does not key kept the old clip's last pose: out of the water
## she stood and walked bent sideways at the waist (~23 deg) for good. PlayerView now makes her rig's
## player deterministic: an unkeyed bone falls back to its rest pose.
## Checks: every state idle starts and ends near the plain idle's spine (side tilt) and loops seamlessly;
## after any clip at any frame, the plain idle stands within a few degrees of a fresh idle in under a
## second; leaving swim / exhausted / tired / cold returns to the plain idle. Windowed it writes the PNGs.
## Usage: godot --headless --path game --script res://tests/t_posefix.gd

const SHOTS := "res://../docs/orchestration/reports/posefix/"
const SIDE_TOL := 5.0   ## deg, hips -> head tilt to the side vs the plain idle
const BACK_TOL := 4.0   ## deg, both axes, plain idle after another clip vs a fresh idle
const SETTLE_S := 0.8   ## the idle blend is 0.5 s

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var rig
var ap: AnimationPlayer
var shot_tag := OS.get_environment("POSEFIX_TAG")

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
	print("[t_posefix] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

## Hips -> Head in the rig's frame: x = side tilt, y = forward lean, degrees.
func _tilt() -> Vector2:
	var sk: Skeleton3D = rig.skeleton
	var d: Vector3 = sk.get_bone_global_pose(sk.find_bone("Head")).origin - sk.get_bone_global_pose(sk.find_bone("Hips")).origin
	var l: Vector3 = rig.global_basis.inverse() * (sk.global_basis * d)
	return Vector2(rad_to_deg(atan2(l.x, l.y)), rad_to_deg(atan2(-l.z, l.y)))

func _pose_at(clip: StringName, t: float) -> Vector2:
	ap.play(clip, 0.0)
	ap.seek(t, true)
	return _tilt()

func _run() -> void:
	get_root().get_node("Game").max_creatures_per_island = 0
	get_root().get_node("Game").debug_overlay = false
	host = Node3D.new()
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"tutorial_isle", Vector3(0, 1, 0), false)
	await process_frame
	var rt = world.runtime
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	var cam = (load("res://scripts/camera/iso_camera.gd") as GDScript).new()
	host.add_child(cam)
	cam.current = true
	cam._target = player
	var at: Vector3 = rt.get("_camp_pos") if rt.get("_camp_pos") != null else Vector3.ZERO
	at.y = rt.surface_y(at.x, at.z) + 1.0
	player.global_position = at
	cam.set("min_size", 4.0)
	cam.set("size", 4.5)
	cam._snap()
	await _frames(10)
	for c in get_nodes_in_group("creatures"):
		c.queue_free()
	rig = player.rig
	ap = rig.anim_player
	var anim = player.anim
	# The test drives PlayerAnim itself; PlayerSim would pick clips from her real speed and the island.
	player.set_physics_process(false)
	rt.weather.raining = true
	rt.weather.set("_rain_cd", 1.0e9)
	rt.weather.soak(player, 2)

	# --- 1. the clips: every state idle starts and ends at the plain idle's side tilt, and loops
	var rest := _pose_at(&"idle", 0.0)
	for c: StringName in [&"idle"] + anim.MOOD_IDLES:
		if not rig.has_clip(c):
			continue
		var len: float = ap.get_animation(c).length
		var a := _pose_at(c, 0.0)
		var b := _pose_at(c, len)
		_expect(absf(a.x - rest.x) <= SIDE_TOL and absf(b.x - rest.x) <= SIDE_TOL,
			"%s starts and ends upright to the side (%.1f / %.1f deg, idle %.1f)" % [c, a.x, b.x, rest.x])
		_expect(a.distance_to(b) <= 1.0, "%s loops without a pop (start %s, end %s)" % [c, a, b])

	# --- 2. the root cause: after any clip, at any frame, the plain idle is the plain idle
	var fresh := _pose_at(&"idle", 0.0)
	var worst := ""
	var worst_d := 0.0
	for c in ap.get_animation_list():
		var len: float = ap.get_animation(c).length
		for k in 5:
			_pose_at(c, len * k / 4.0)
			var v := _pose_at(&"idle", 0.0)
			var dv := maxf(absf(v.x - fresh.x), absf(v.y - fresh.y))
			if dv > worst_d:
				worst_d = dv
				worst = "%s@%d%%" % [c, k * 25]
	_expect(worst_d <= BACK_TOL, "no clip leaves a bone bent in the idle after it (worst %s: %.1f deg)" % [worst, worst_d])

	# --- 3. in play: leave each state, the plain idle is back within SETTLE_S
	anim.revive()
	await _settle()
	await _shot("0_idle_in_rain")
	player.swimming = true
	anim._physics_tick(0.0)
	await create_timer(1.5).timeout
	_expect(anim.current_clip in [&"swim_idle", &"swim"], "she treads water (%s)" % anim.current_clip)
	player.swimming = false
	anim.swim_lift = 0.0
	anim._physics_tick(0.0)
	await _settle()
	await _shot("1_after_swim")
	_check_idle("out of the water")
	anim.play_rummage(true)
	await create_timer(2.5).timeout
	anim.stop_rummage()
	await create_timer(2.2).timeout
	anim._physics_tick(0.0)
	await _settle()
	_check_idle("after the bag rummage")
	for f in [0.8, 0.6]:
		player.vitals.fatigue = f * player.vitals.effective_max_fatigue()
		anim._physics_tick(0.0)
		await create_timer(1.3).timeout
		var want: StringName = &"idle_exhausted" if f >= anim.EXHAUSTED_AT else &"idle_tired"
		_expect(anim.current_clip == want or not rig.has_clip(want), "fatigue %.0f%% plays %s (%s)" % [f * 100, want, anim.current_clip])
		player.vitals.fatigue = 0.0
		anim._physics_tick(0.0)
		await _settle()
		_check_idle("rested after %s" % want)
	var w = rt.weather
	w.cold = 0.9
	anim._physics_tick(0.0)
	await create_timer(1.3).timeout
	_expect(anim.current_clip == &"idle_cold" or not rig.has_clip(&"idle_cold"), "cold plays idle_cold (%s)" % anim.current_clip)
	w.cold = 0.0
	anim._physics_tick(0.0)
	await _settle()
	_check_idle("warm again")
	_finish()

func _settle() -> void:
	await create_timer(SETTLE_S).timeout

func _check_idle(when: String) -> void:
	var v := _tilt()
	var keep := ap.current_animation_position
	var now_clip := ap.current_animation
	_expect(player.anim.current_clip == &"idle" and now_clip == &"idle", "%s: back to the plain idle (%s / %s)" % [when, player.anim.current_clip, now_clip])
	# The same idle frame on a clean skeleton: reset, sample, restore.
	var sk: Skeleton3D = rig.skeleton
	var saved: Array = []
	for b in sk.get_bone_count():
		saved.append([sk.get_bone_pose_position(b), sk.get_bone_pose_rotation(b), sk.get_bone_pose_scale(b)])
	sk.reset_bone_poses()
	ap.seek(keep, true)
	var fresh := _tilt()
	for b in sk.get_bone_count():
		sk.set_bone_pose_position(b, saved[b][0])
		sk.set_bone_pose_rotation(b, saved[b][1])
		sk.set_bone_pose_scale(b, saved[b][2])
	_expect(absf(v.x - fresh.x) <= BACK_TOL and absf(v.y - fresh.y) <= BACK_TOL,
		"%s: she stands like a fresh idle (side %.1f vs %.1f, lean %.1f vs %.1f)" % [when, v.x, fresh.x, v.y, fresh.y])

func _shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var path := ProjectSettings.globalize_path(SHOTS + (shot_tag + "_" if shot_tag != "" else "") + tag + ".png")
	get_root().get_texture().get_image().save_png(path)
	print("[t_posefix] shot %s" % path)

func _finish() -> void:
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_posefix] PASS")
		quit(0)
	else:
		print("[t_posefix] FAIL %d: %s" % [failures.size(), failures])
		quit(1)
