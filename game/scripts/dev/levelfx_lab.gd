extends Node3D
## LEVELFX lab (owner 2026-10-21: "make it flashy. Level ups should have light effect animations. Also
## watch out for glitchy movement of UI and player"). The home island with the real HUD: a character
## level-up and a skill level-up at the survivor, by day and by night, shot at the effect's peak and
## mid-way. Then frame sequences: one XP grant worth several level-ups (they queue: one celebration
## and one light effect at a time, never two texts on top of each other), a level-up while the
## survivor walks (the effect stays on her feet, the camera neither shakes nor jumps, the HUD text
## does not move between frames), and the frame cost of a character level-up against idle frames.
## Windowed: Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility]
##   -- --lab=levelfx_lab --shot-dir=DIR   (also 844x390)
## Headless (no shots, no frame cost): Godot --headless --path game -- --lab=levelfx_lab
## Frame cost only (three idle-vs-level-up samples; add --disable-vsync): -- --lab=levelfx_lab --cost-only
## Prints "[levelfx] ..." lines, then "[levelfx] PASS" (exit 0) or FAIL lines (exit 1). The base HUD
## has no light effect and no skill celebration, so on it the lab prints what it saw and FAILs.

const PEAK_S := 0.5   ## the pillar is up, the rays are full, LEVEL UP has settled
const MID_S := 1.1    ## the pillar fades, the rings are wide, the reward lines are in
const DRAIN_MAX_S := 40.0
const FX_GROUP := &"level_up_fx"

var _out := ""
var _player: Player
var _hud: HuntHud
var _cam: IsoCamera
var _fails: Array[String] = []
var _shots: PackedStringArray = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Game.debug_overlay = false  # before the HUD builds: players never see the DEBUG hex
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await _wait(1.5)
	var rt := World.runtime as IslandRuntime
	var at := rt._camp_pos + Vector3(6.0, 0.0, 5.0)  # open grass beside the camp
	_player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + _player.half_height() + 0.05, at.z)
	_player.reset_physics_interpolation()
	_cam._snap()
	if "--cost-only" in OS.get_cmdline_user_args():
		Game.time_of_day = 0.45
		await _wait(1.0)
		for i in 3:  # the first is the session's first level-up (only the warm-up copy came before it)
			await _cost()
		_finish()
		return
	# Lv. 3, survival at its cap: any skill XP also feeds survival, which would level beside the
	# category the skill shots show.
	World.add_xp(World.xp_for_level(0) + World.xp_for_level(1))
	_player.skills.add_xp("survival", 5000.0, true)
	await _quiet()
	for phase in [["day", 0.45], ["night", 0.93]]:
		Game.time_of_day = float(phase[1])
		await _wait(0.8)
		await _character(str(phase[0]))
		await _skill(str(phase[0]))
	Game.time_of_day = 0.45
	await _wait(0.5)
	await _burst()
	await _walking()
	await _cost()
	_finish()

## One character level-up, exactly: shots at its peak and mid-way, then it plays out.
func _character(tag: String) -> void:
	await _quiet()
	var lv := LevelDisplay.player_level()
	World.add_xp(World.xp_for_level(lv - 1) - World.pioneer_xp)
	var fx := await _shots_of("char_%s" % tag)
	_expect(fx.has("character"), "%s: a character level-up spawns a light effect at the survivor (saw %s)" % [tag, fx])
	_expect(_hud.drawn_blocks.has("levelup"), "%s: the HUD celebrates the character level-up" % tag)
	await _drain()

## One skill category level-up (processing; survival sits at its cap so it only banks the XP).
func _skill(tag: String) -> void:
	await _quiet()
	var s := _player.skills
	var lv := s.level_of("processing")
	if lv >= s.level_cap("processing"):
		World.add_xp(World.xp_for_level(LevelDisplay.player_level() - 1) - World.pioneer_xp)
		_player.skills.add_xp("survival", 5000.0, true)
		await _quiet()
		lv = s.level_of("processing")
	s.add_xp("processing", SkillState.xp_to_next(lv) - s.xp_of("processing"), true)
	_expect(s.level_of("processing") == lv + 1, "%s: processing rose to Lv. %d" % [tag, s.level_of("processing")])
	var fx := await _shots_of("skill_%s" % tag)
	_expect(fx.has("skill") and not fx.has("character"), "%s: a skill level-up spawns the small light effect only (saw %s)" % [tag, fx])
	_expect(_hud.drawn_blocks.has("levelup"), "%s: the HUD celebrates the skill level-up" % tag)
	await _drain()

## Waits PEAK_S and MID_S on the effect's clock (process frames since the level-up) and shoots both.
## Returns the kinds of light effect seen.
func _shots_of(name: String) -> Array:
	var seen: Array = []
	var t := 0.0
	for spec in [["peak", PEAK_S], ["mid", MID_S]]:
		while t < float(spec[1]):
			await get_tree().process_frame
			t += get_process_delta_time()
			for k in _fx_kinds():
				if not seen.has(k):
					seen.append(k)
		await _shot("%s_%s" % [name, spec[0]])
	print("[levelfx] %s fx=%s levelup_block=%s" % [name, seen, _hud.drawn_blocks.get("levelup", "none")])
	return seen

## Several level-ups from one XP grant (gathering: two character levels, gathering and survival).
## Every frame: at most one light effect and one celebration; the order they show in; no frame where
## the celebration's block jumps while it shows.
func _burst() -> void:
	await _quiet()
	var before := LevelDisplay.player_level()
	var need := World.xp_for_level(before - 1) - World.pioneer_xp + World.xp_for_level(before)
	_player.skills.add_xp("gathering", float(need))
	print("[levelfx] burst: Lv. %d -> Lv. %d, gathering Lv. %d, survival Lv. %d" % [before, LevelDisplay.player_level(), _player.skills.level_of("gathering"), _player.skills.level_of("survival")])
	var rec := await _record(DRAIN_MAX_S, true)
	_expect(int(rec["max_fx"]) <= 1, "burst: one light effect at a time (max %d)" % rec["max_fx"])
	_expect((rec["order"] as Array).size() >= 3, "burst: the level-ups show one after another (%s)" % [rec["order"]])
	_expect(float(rec["max_block_jump"]) <= 0.5, "burst: a celebration's block never jumps while it shows (max %.2f px)" % rec["max_block_jump"])

## A character level-up while the survivor walks (1.5 s of a 14 m walk, twice: without and with one):
## the effect stays on her feet, the camera gets no shake offset, the HUD block stays put. The camera's
## velocity jerk (largest change of its per-frame velocity) is printed for both walks; it depends on
## frame pacing, so it is reported, not gated.
func _walking() -> void:
	await _quiet()
	var from := _player.global_position
	_player.nav_to(from + Vector3(14.0, 0.0, 0.0))
	var calm := await _record(1.5, false)
	_player.clear_nav()
	_player.global_position = from
	_player.reset_physics_interpolation()
	_cam._snap()
	await _wait(0.3)
	_player.nav_to(from + Vector3(14.0, 0.0, 0.0))
	World.add_xp(World.xp_for_level(LevelDisplay.player_level() - 1) - World.pioneer_xp)
	var lit := await _record(1.5, false)
	_player.clear_nav()
	print("[levelfx] walking: cam velocity jerk calm=%.2f m/s lit=%.2f m/s; fx off feet max=%.4f m; cam offset max=%.4f; block jump max=%.2f px" % [
		calm["max_cam_jerk"], lit["max_cam_jerk"], lit["max_fx_off"], lit["max_cam_offset"], lit["max_block_jump"]])
	_expect(float(lit["max_cam_offset"]) == 0.0, "walking level-up: no camera shake offset (max %.4f)" % lit["max_cam_offset"])
	_expect(float(lit["max_fx_off"]) <= 0.01, "walking level-up: the light effect stays on the survivor's feet (max %.4f m off)" % lit["max_fx_off"])
	_expect(float(lit["max_block_jump"]) <= 0.5, "walking level-up: the HUD celebration does not move between frames (max %.2f px)" % lit["max_block_jump"])
	await _drain()

## Frame cost: 90 idle frames, then the 100 frames of one character level-up (its light and the
## HUD celebration). Frame time, the viewport's CPU render time and draw calls; frames over 25 ms are
## listed. GPU time is not measured: Godot reports 0 for it on this Mac's gl_compatibility.
func _cost() -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _quiet()
	var vp := get_viewport().get_viewport_rid()
	var idle := await _sample(90, vp)
	World.add_xp(World.xp_for_level(LevelDisplay.player_level() - 1) - World.pioneer_xp)
	var lit := await _sample(100, vp)
	print("[levelfx] cost %dx%d %s: idle frame %.2f ms (max %.2f) render cpu %.2f ms draws %.0f (max %d) | level-up frame %.2f ms (max %.2f) render cpu %.2f ms draws %.0f (max %d)" % [
		get_tree().root.size.x, get_tree().root.size.y, RenderingServer.get_current_rendering_method(),
		idle["frame"], idle["frame_max"], idle["cpu"], idle["draws"], idle["draws_max"],
		lit["frame"], lit["frame_max"], lit["cpu"], lit["draws"], lit["draws_max"]])
	print("[levelfx] cost slow frames (> 25 ms): idle %s | level-up %s" % [idle["slow"], lit["slow"]])
	await _drain()

func _sample(frames: int, vp: RID) -> Dictionary:
	var out := {"frame": 0.0, "frame_max": 0.0, "cpu": 0.0, "draws": 0.0, "draws_max": 0, "slow": []}
	for i in frames:
		await get_tree().process_frame
		var dt := get_process_delta_time() * 1000.0
		if dt > 25.0:
			(out["slow"] as Array).append("f%d=%.0fms" % [i, dt])
		var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		out["frame"] += dt / frames
		out["frame_max"] = maxf(out["frame_max"], dt)
		out["cpu"] += RenderingServer.viewport_get_measured_render_time_cpu(vp) / frames
		out["draws"] += float(draws) / frames
		out["draws_max"] = maxi(out["draws_max"], draws)
	return out

## Per frame for up to `seconds` (or until nothing celebrates, when `until_quiet`): light effects
## alive, the celebration's block and how far it moved since the last frame while it showed the same
## level-up, the camera's shake offset, the camera's velocity jerk (change of its velocity between
## frames, m/s) and how far each effect sits from the survivor's feet.
func _record(seconds: float, until_quiet: bool) -> Dictionary:
	var out := {"max_fx": 0, "order": [], "max_block_jump": 0.0, "max_cam_offset": 0.0, "max_cam_jerk": 0.0, "max_fx_off": 0.0, "frames": 0}
	var t := 0.0
	var last_key := ""
	var last_block := Rect2()
	var last_cam := _cam.global_position
	var last_vel := Vector3.ZERO
	var quiet_frames := 0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		out["frames"] += 1
		var fxs := get_tree().get_nodes_in_group(FX_GROUP)
		out["max_fx"] = maxi(out["max_fx"], fxs.size())
		var feet := _player.get_global_transform_interpolated().origin - Vector3(0.0, _player.half_height(), 0.0)
		for fx in fxs:
			out["max_fx_off"] = maxf(out["max_fx_off"], (fx as Node3D).get_global_transform_interpolated().origin.distance_to(feet))
		var key := _showing()
		var block: Rect2 = _hud.drawn_blocks.get("levelup", Rect2())
		if key != "" and key == last_key and block.has_area() and last_block.has_area():
			out["max_block_jump"] = maxf(out["max_block_jump"], block.position.distance_to(last_block.position))
		if key != "" and key != last_key:
			(out["order"] as Array).append(key)
		last_key = key
		last_block = block
		out["max_cam_offset"] = maxf(out["max_cam_offset"], absf(_cam.h_offset) + absf(_cam.v_offset))
		var vel := (_cam.global_position - last_cam) / maxf(get_process_delta_time(), 0.001)
		if out["frames"] > 2:
			out["max_cam_jerk"] = maxf(out["max_cam_jerk"], (vel - last_vel).length())
		last_vel = vel
		last_cam = _cam.global_position
		quiet_frames = quiet_frames + 1 if (key == "" and fxs.is_empty()) else 0
		if until_quiet and quiet_frames > 10:
			break
	print("[levelfx] record %.1f s, %d frames: order=%s max_fx=%d block_jump=%.2f px cam_offset=%.4f cam_jerk=%.2f m/s fx_off=%.4f m" % [
		t, out["frames"], out["order"], out["max_fx"], out["max_block_jump"], out["max_cam_offset"], out["max_cam_jerk"], out["max_fx_off"]])
	return out

## The level-up the HUD shows now, "" when none: "<kind>:<what>" from the celebration queue, else
## (the base HUD) the drawn stack's level line.
func _showing() -> String:
	var cel: Object = _hud.get("_levelups")
	if cel:
		return str(cel.call("showing_key"))
	if float(_hud.get("_levelup_t")) >= 0.0:
		return "character:%s" % (_hud.get("_levelup_lines") as Array)[0][0]
	return ""

func _fx_kinds() -> Array:
	var out: Array = []
	for fx in get_tree().get_nodes_in_group(FX_GROUP):
		out.append(str(fx.get("kind")))
	return out

## Lets the current celebrations and effects play out (they free themselves).
func _drain() -> void:
	var t := 0.0
	while t < DRAIN_MAX_S and (_showing() != "" or not get_tree().get_nodes_in_group(FX_GROUP).is_empty()):
		await get_tree().process_frame
		t += get_process_delta_time()
	_expect(t < DRAIN_MAX_S, "level-up celebrations and light effects end on their own (%.1f s)" % t)

## Clears what earlier steps left on screen.
func _quiet() -> void:
	var cel: Object = _hud.get("_levelups")
	if cel:
		cel.call("clear")
	_hud.set("_levelup_t", -1.0)
	for fx in get_tree().get_nodes_in_group(FX_GROUP):
		fx.queue_free()
	await _wait(0.3)

func _shot(name: String) -> void:
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	_shots.append(path)
	print("[levelfx] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)
	print("[levelfx] %s %s" % ["ok" if ok else "FAIL", msg])

func _finish() -> void:
	if _fails.is_empty():
		print("[levelfx] PASS shots=%d" % _shots.size())
		get_tree().quit(0)
		return
	for f in _fails:
		print("[levelfx] FAIL %s" % f)
	get_tree().quit(1)
