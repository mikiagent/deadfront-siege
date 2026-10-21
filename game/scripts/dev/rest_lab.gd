extends Node3D
## Owner: "resting should sit you down and heal you and lower exhaustion". Stands a hurt, tired
## survivor (HP 40, fatigue 60) at three spots on the home island with the real HUD, tries every way
## a player could rest there, and samples pose, HP and fatigue for 30 s:
##   open   dry grass 18 m or more from the camp, no fire or bedding within 8 m
##   fire   1.9 m from the camp bonfire, on its side away from the camp
##   tent   1.9 m from the camp's public tent (a sleep spot)
##   tent_sleep  the same spot, the Sleep hex on purpose (beds and tents keep the Sleep flow)
##   tent_tap  the same, but a tap on the ground 5 s in (a tap-to-walk, as a phone player taps)
##   tent_sick  the tent with a raw-meat Stomachache (300 s, 0.2 dps, no cure) and Dirty: the round-1
##              review's case, where Rest was refused and Sleep ended on the first tick
##   tent_sleep_sick  the same Stomachache, the Sleep hex
## The attempt, in order: a "rest" context hex, else the "sleep" hex, else the interact key (E).
## Then a motion trace: the hips every physics frame through sit down and stand up (the owner's
## motion gate: no jump, snap or stutter between frames).
## Runs on any build: it only uses context_actions / context_action / interact and reads state with get().
## Headless: Godot --headless --path game res://scenes/dev/rest_lab.tscn -- --lab=rest_lab [--secs=30]
## Windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   res://scenes/dev/rest_lab.tscn -- --lab=rest_lab --shot-dir=DIR   (also 844x390)
## Prints "[restlab] spot=... ctx=[...] tried=..." then "[restlab] spot=... t=.. clip=.. hp=.. fat=.." every 5 s.

const SETTLE_S := 1.2

var _out := ""
var _secs := 30.0
var _verbose := false
var _player: Player
var _hud: HuntHud
var _cam: IsoCamera
var _rt: IslandRuntime

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--secs="):
			_secs = float(a.substr(7))
		elif a == "--trace":
			_verbose = true  # every frame of the motion trace
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0  # no wandering creature aggro: the numbers are the rest's alone
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_rt = World.runtime as IslandRuntime
	for n in get_tree().get_nodes_in_group("creature"):
		n.queue_free()
	Game.time_of_day = 0.45
	_no_rain()
	var fire := _rt.get_node_or_null("CampFire") as Node3D
	var tent := _rt.get_node_or_null("CampShed") as Node3D
	await _trial("open", _open_spot(), null)
	await _trial("fire", _beside(fire, 1.9, false), fire)  # the fire's far side, clear of the tent
	await _trial("tent", _beside(tent, 1.9, true), tent)
	await _trial("tent_sleep", _beside(tent, 1.9, true), tent, true)
	await _trial("tent_tap", _beside(tent, 1.9, true), tent)
	await _trial("tent_sick", _beside(tent, 1.9, true), tent, false, [&"stomachache", &"dirty"])
	await _trial("tent_sleep_sick", _beside(tent, 1.9, true), tent, true, [&"stomachache"])
	await _motion(_beside(fire, 1.9, false), fire)
	print("[restlab] done")
	get_tree().quit(0)

func _trial(spot: String, at: Vector3, face: Node3D, sleep: bool = false, sick: Array[StringName] = []) -> void:
	_player.clear_nav()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 1.0, at.z)
	_player.reset_physics_interpolation()
	if face:
		_player.face_world(face.global_position)
	_player.statuses.from_array([])
	for id in sick:
		_player.statuses.apply(id)
	_player.vitals.health = 40.0
	_player.vitals.fatigue = 60.0
	_player.vitals.energy = _player.vitals.max_energy
	_player._last_hit_taken_s = -999.0
	_cam._snap()
	await get_tree().create_timer(SETTLE_S).timeout
	var ids: Array = []
	for a in _player.context_actions():
		ids.append(str(a["id"]))
	if spot == "open" and _out != "":
		await _shot("open_hexes")  # the context row before acting: the Rest hex and its icon
	var tried := "interact_key"
	if "rest" in ids and not sleep:
		tried = "rest_hex"
		_player.context_action("rest")
	elif "sleep" in ids:
		tried = "sleep_hex"
		_player.context_action("sleep")
	else:
		_player.controls.interact()
	var p := _player.global_position
	print("[restlab] spot=%s pos=(%.1f, %.1f) fire=%.1fm tent=%.1fm ctx=%s tried=%s" % [spot, p.x, p.z,
		_dist(_rt.get_node_or_null("CampFire")), _dist(_rt.get_node_or_null("CampShed")), ids, tried])
	var log0: Dictionary = _player.vitals.fatigue_log.duplicate()
	var t := 0.0
	var shot_at := minf(4.0, _secs)
	var shot_done := _out == ""
	while t <= _secs + 0.001:
		_sample(spot, t)
		var step := 5.0
		if not shot_done and t < shot_at and t + step >= shot_at:
			await get_tree().create_timer(shot_at - t).timeout
			await _shot(spot)
			shot_done = true
			await get_tree().create_timer(t + step - shot_at).timeout
		else:
			await get_tree().create_timer(step).timeout
		t += step
		if spot == "tent_tap" and is_equal_approx(t, 5.0):
			_player.nav_to(_player.global_position + Vector3(3, 0, 0))
			print("[restlab] spot=%s t= 5 tapped the ground 3 m away" % spot)
	var gained: Dictionary = {}
	for k in _player.vitals.fatigue_log:
		var d := float(_player.vitals.fatigue_log[k]) - float(log0.get(k, 0.0))
		if d > 0.001:
			gained[k] = snappedf(d, 0.01)
	print("[restlab] spot=%s fatigue gained by source over %.0f s: %s" % [spot, _secs, gained])
	Input.action_press("move_left")  # stand up before the next spot
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	await get_tree().create_timer(2.5).timeout

## The hips (the rig's hips socket) every physics frame from Rest to seated, then from a move key to
## standing: the largest step between two frames, and the visual's height, for pops and sinking.
func _motion(at: Vector3, face: Node3D) -> void:
	var ids: Array = await _ids_at(at, face)
	if not "rest" in ids:
		print("[restlab] motion: no Rest on this build")
		return
	_player.context_action("rest")
	await _trace("sit", 1.6)
	Input.action_press("move_left")
	await get_tree().physics_frame
	Input.action_release("move_left")
	await _trace("stand", 1.6)

func _ids_at(at: Vector3, face: Node3D) -> Array:
	_player.clear_nav()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(at.x, _rt.surface_y(at.x, at.z) + 1.0, at.z)
	_player.reset_physics_interpolation()
	_player.face_world(face.global_position)
	_player.statuses.from_array([])  # the last trial's Stomachache would flinch her once she is up
	_player._last_hit_taken_s = -999.0
	await get_tree().create_timer(SETTLE_S).timeout
	var ids: Array = []
	for a in _player.context_actions():
		ids.append(str(a["id"]))
	return ids

func _trace(what: String, secs: float) -> void:
	var hips: Node3D = _player.hips_anchor()
	var prev := hips.global_position
	var worst := 0.0
	var worst_t := 0.0
	var t := 0.0
	var ground := _rt.surface_y(_player.global_position.x, _player.global_position.z)
	var low := INF
	while t < secs:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var now := hips.global_position
		if now.distance_to(prev) > worst:
			worst = now.distance_to(prev)
			worst_t = t
		low = minf(low, now.y - ground)
		prev = now
		if _verbose:
			var ap: AnimationPlayer = _player.rig.anim_player
			print("[restlab] trace %s t=%.3f hips=%.3f visual_y=%.3f clip=%s at=%.2f" % [what, t, now.y - ground, _player.visual.position.y, ap.current_animation, ap.current_animation_position])
	print("[restlab] motion %s: largest hips step %.3f m/frame at t=%.2f, lowest hips %.2f m above ground, clip=%s visual_y=%.2f" % [
		what, worst, worst_t, low, _player.anim.current_clip, _player.visual.position.y])

## Rain lands Wet at random (WorldWeather); the lab holds it off so every spot sees the same sky.
func _no_rain() -> void:
	_rt.weather.raining = false
	_rt.weather.set("_rain_cd", 1.0e9)

func _sample(spot: String, t: float) -> void:
	var v := _player.vitals
	var rest_obj: Variant = _player.sim.get("rest")
	var resting: Variant = rest_obj.get("resting") if rest_obj is Object else null
	var where: Variant = rest_obj.get("place") if rest_obj is Object else null
	var chips: Array = []
	for inst in _player.statuses.instances():
		chips.append(str(inst.id))
	var chip: Variant = rest_obj.call("hud_lines") if rest_obj is Object and (rest_obj as Object).has_method("hud_lines") else null
	print("[restlab] spot=%s t=%2.0f clip=%s visual_y=%.2f speed=%.2f resting=%s place=%s sleep_left=%.1f hp=%.1f fat=%.2f chips=%s rest_chip=%s" % [
		spot, t, _player.anim.current_clip, _player.visual.position.y, Vector2(_player.velocity.x, _player.velocity.z).length(),
		resting, where, _player._sleep_left, v.health, v.fatigue, chips, chip])

func _shot(spot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [spot, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[restlab] shot %s" % path)

func _dist(n: Node) -> float:
	return _player.global_position.distance_to((n as Node3D).global_position) if n else INF

## Dry, open grass 18-30 m from the camp with no fire, bedding or building within 8 m.
func _open_spot() -> Vector3:
	var camp := _rt._camp_pos
	for r in [18.0, 22.0, 26.0, 30.0]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var at := camp + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if _rt.surface_y(at.x, at.z) < 0.4:
				continue
			var clear := true
			for g in ["placed_building", "craft_station", "harvest", "harbour"]:
				for n in get_tree().get_nodes_in_group(g):
					if n is Node3D and (n as Node3D).global_position.distance_to(at) < 8.0:
						clear = false
			if clear:
				return at
	return camp + Vector3(20, 0, 0)

## A point `metres` from a building's centre, on the side facing the camp centre (or away from it).
func _beside(n: Node3D, metres: float, toward_camp: bool) -> Vector3:
	var c := n.global_position
	var to := (_rt._camp_pos - c) * (1.0 if toward_camp else -1.0)
	to.y = 0.0
	if to.length_squared() < 0.01:
		to = Vector3(0, 0, 1)
	return c + to.normalized() * metres
