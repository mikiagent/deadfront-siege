extends Node3D
## STEGO lab: the stegosaurus beside the survivor on a real island. Idle and walking run the game's own
## physics step (gait, cadence, ground conform), then attack_primary, a real hit (_on_damaged) and death
## are posed; each toe is measured against the terrain at the camp spot and on the steepest nearby
## slope. Windowed runs save <out>_<island>_<stage>.png; --stego-perf times frames with 4 stegosauri
## in the game camera's view against none. Prints [stegolab] lines; exit 1 on a failed check.
## Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- --lab=stego_lab
##   [--stego-island=home_grassland] [--stego-out=/tmp/stego] [--stego-at=x,z] [--stego-perf]

const ID := &"stegosaurus"
const TOES: Array[String] = ["front_toe_L", "front_toe_R", "hind_toe_L", "hind_toe_R"]
## ASSUMPTION: a toe within 0.25 m of where it rests on flat ground reads as standing on the terrain.
const FOOT_TOL := 0.25

var island := &"home_grassland"
var out := "/tmp/stego"
var at := Vector2(10.0, 0.0)
var perf := false
var player: Player
var iso: Camera3D
var cam: Camera3D
var _flat: Dictionary = {}  ## toe -> its height above flat ground in idle (the sole sits below the bone)
var _fails: Array[String] = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stego-island="):
			island = StringName(a.substr(15))
		elif a.begins_with("--stego-out="):
			out = a.substr(12)
		elif a.begins_with("--stego-at="):
			var xz := a.substr(11).split(",")
			at = Vector2(float(xz[0]), float(xz[1]))
		elif a == "--stego-perf":
			perf = true
	var kit := LabKit.build(self, 60.0)
	player = kit["player"]
	iso = kit["cam"]
	(kit["ui"] as CanvasLayer).visible = false
	Game.debug_overlay = false
	Game.time_of_day = 0.42
	TouchControls.visible = false
	cam = Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	print("[boot] lab=stego_lab")
	call_deferred("_run")

func _check(ok: bool, what: String) -> void:
	print("[stegolab] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _run() -> void:
	# Flat floor first: where each toe rests in idle is the reference for the terrain checks.
	var flat := _spawn(Vector3(0.0, 0.0, -12.0), 0.0)
	await _wait(1.0)
	_check(flat.view.using_glb, "stegosaurus uses its GLB (using_glb=%s)" % flat.view.using_glb)
	if flat.view.using_glb:
		for t in TOES:
			_flat[t] = _toe(flat, t).y
		print("[stegolab] flat idle toe heights %s" % [_flat])
	flat.queue_free()
	World.harvested.clear()
	World.load_island(self, island, Vector3.ZERO, false)
	var kit_floor := get_node_or_null("Nav/Floor")
	if kit_floor:
		kit_floor.queue_free()
	for c in get_tree().get_nodes_in_group("creatures"):
		c.queue_free()
	await _wait(1.0)
	var s := _ground(Vector3(at.x, 0.0, at.y))
	var c := _spawn(s, 0.0)  # yaw 0: faces -Z
	_place_player(s + Vector3(0.0, 0.0, -6.5))
	c.set_physics_process(true)  # the game's step: settles on the terrain, idles
	await _wait(1.5)
	_feet(c, "%s camp spot" % island)
	await _shot(c, "idle")
	iso.current = true
	await _save("iso")
	# Walking: the game's own physics step to a goal (gait, cadence and ground conform as in play).
	c.global_position = _ground(s + Vector3(0.0, 0.0, c.move_speed_mps() * 1.5 + 1.0))
	c.reset_physics_interpolation()
	c.move_to(s)
	await _wait(1.5)
	var v := Vector2(c.velocity.x, c.velocity.z).length()
	_feet(c, "%s walking at %.2f m/s (%s x%.2f)" % [island, v, c.anim.current_clip, c.anim.cadence(c.anim.current_clip)], 2.0)
	await _shot(c, "walk")
	c.stop_move()
	await _wait(0.5)
	c.set_physics_process(false)  # posed from here: attack, hit, death
	await _wait(0.2)
	c.anim.play_clip(&"attack_primary")
	await _wait(_clip_len(c, &"attack_primary") * CreatureClips._hit_frac(&"attack_primary"))
	await _shot(c, "attack")
	await _wait(1.5)
	c._on_damaged(1.0, player)  # the game's hurt path: hit_react when the rig has an authored one
	_check(c.anim.current_clip == &"hit_react" or not c.view.using_glb, "real hit plays %s" % c.anim.current_clip)
	await _wait(0.15)
	c.brain.attack_target = player  # aggro ring as when it hunts the survivor
	c.brain.state = &"alert"
	c.mark_aggro_now()
	c._update_aggro_ring(1.0)
	await _shot(c, "hit")
	await _wait(1.0)
	c.anim.play_clip(&"death")
	await _wait(_clip_len(c, &"death") + 0.4)
	_feet(c, "%s dead" % island, 99.0)
	await _shot(c, "dead")
	c.queue_free()
	await _slope()
	if perf:
		await _perf()
	print("[stegolab] %s" % ("PASS" if _fails.is_empty() else "FAIL %s" % [_fails]))
	get_tree().quit(0 if _fails.is_empty() else 1)

## Steepest spot within 30 m of the camp, the animal facing up the slope.
func _slope() -> void:
	var rt = World.runtime
	var best := Vector3.ZERO
	var best_g := Vector2.ZERO
	for gx in range(-30, 31, 3):
		for gz in range(-30, 31, 3):
			var x := at.x + gx
			var z := at.y + gz
			var g := Vector2(rt.surface_y(x + 1.0, z) - rt.surface_y(x - 1.0, z), rt.surface_y(x, z + 1.0) - rt.surface_y(x, z - 1.0)) * 0.5
			if g.length() > best_g.length() and g.length() < 0.5:  # skip cliffs (> 26 deg)
				best_g = g
				best = Vector3(x, 0.0, z)
	var up := Vector3(best_g.x, 0.0, best_g.y).normalized()
	var c := _spawn(_ground(best), atan2(-up.x, -up.z) if up != Vector3.ZERO else 0.0)
	_place_player(_ground(best + up * 6.5))  # ahead of it, as at the camp spot: the side camera sees all four legs
	c.set_physics_process(true)  # the game's step settles it on the slope
	await _wait(1.5)
	_feet(c, "%s slope %.1f deg at %s" % [island, rad_to_deg(atan(best_g.length())), best])
	await _shot(c, "slope")
	c.queue_free()

## Frame time with 4 stegosauri standing (the game's physics step) in the game camera's view, then with none.
func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	iso.current = true
	var p := player.global_position
	var herd: Array[Creature] = []
	for k in 4:
		var c := _spawn(_ground(p + Vector3(-9.0 + 6.0 * k, 0.0, -6.0 - 5.0 * (k % 2))), 0.4 * k)
		c.set_physics_process(true)  # the game's step (idle, slide, conform) on top of skinning
		herd.append(c)
	await _wait(2.0)
	await _save("perf")
	var with4 := await _frame_ms(300)
	for c in herd:
		c.queue_free()
	await _wait(1.0)
	var none := await _frame_ms(300)
	print("[stegolab] perf renderer=%s size=%s 4 stegosauri %.3f ms/frame, none %.3f ms/frame, delta %.3f ms" % [
		RenderingServer.get_current_rendering_method(), get_viewport().get_visible_rect().size, with4, none, with4 - none])

func _frame_ms(frames: int) -> float:
	await get_tree().process_frame
	var t0 := Time.get_ticks_usec()
	for i in frames:
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)

func _spawn(pos: Vector3, yaw: float) -> Creature:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	var host: Node3D = World.runtime if World.runtime else self
	c.position = host.to_local(pos)
	c.rotation.y = yaw
	host.add_child(c)
	c.spawn(Data.creature(ID))
	c.set_physics_process(false)  # the lab poses it; no AI, no nav
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _place_player(feet: Vector3) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = _ground(feet) + Vector3.UP * (player.half_height() + 0.05)
	player.reset_physics_interpolation()

func _ground(p: Vector3) -> Vector3:
	var rt = World.runtime
	return Vector3(p.x, float(rt.surface_y(p.x, p.z)) if rt else 0.0, p.z)

func _toe(c: Creature, bone: String) -> Vector3:
	var sk := c.view.rig.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin

## Each toe's gap to the terrain under it, less its flat-ground rest height. tol 99 = report only.
func _feet(c: Creature, where: String, tol: float = FOOT_TOL) -> void:
	if not c.view.using_glb or _flat.is_empty():
		print("[stegolab] %s: no skeleton, feet not measured" % where)
		return
	var gaps: Array[String] = []
	var worst := 0.0
	for t in TOES:
		var p := _toe(c, t)
		var gap := p.y - _ground(p).y - float(_flat[t])
		gaps.append("%s %+.2f" % [t, gap])
		worst = maxf(worst, absf(gap))
	var line := "%s: toe to terrain %s m (worst %.2f)" % [where, ", ".join(gaps), worst]
	if tol >= 99.0:
		print("[stegolab] note " + line)
	else:
		_check(worst <= tol, line + " (want <= %.2f)" % tol)

func _clip_len(c: Creature, clip: StringName) -> float:
	var ap := c.anim.player
	return ap.get_animation(clip).length / maxf(0.01, c.anim.cadence(clip)) if ap and ap.has_animation(clip) else 1.0

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

## Side view at the animal's flank: nose to tail and the survivor in one frame, same depth.
func _shot(c: Creature, stage: String) -> void:
	var fwd := -c.global_basis.z
	var side := fwd.cross(Vector3.UP).normalized()
	var mid := c.global_position - fwd * 0.6 + Vector3.UP * 2.6  # tail 7.8 m behind, survivor 6.5 m ahead
	cam.current = true
	cam.look_at_from_position(mid + side * 18.0 + fwd * 4.0 + Vector3.UP * 2.0, mid)
	cam.reset_physics_interpolation()  # else the first frames lerp from the camera's last spot
	await _save(stage)

func _save(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().physics_frame  # let a moved camera and plates settle
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "%s_%s_%s.png" % [out, island, stage]
	get_viewport().get_texture().get_image().save_png(path)
	print("[stegolab] shot %s" % path)
