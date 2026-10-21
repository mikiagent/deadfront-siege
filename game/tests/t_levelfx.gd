extends SceneTree
## LEVELFX acceptance (owner 2026-10-21: "make it flashy. Level ups should have light effect
## animations. Also watch out for glitchy movement of UI and player"). With the real HUD, survivor
## and camera (LabKit):
## - a character level-up spawns the big light at the survivor's feet (pillar, two rings, rays,
##   flash, sparkles, a shadowless OmniLight) and the HUD celebration;
## - a skill category level-up spawns the small one (no pillar, fewer sparkles, a weaker light) and
##   the skill banner; the occupation's head start (an emit of skill_changed) celebrates nothing;
## - every light frees itself on time and leaves the survivor's children as they were;
## - one XP grant worth two character levels and two categories queues: one celebration and one
##   light at a time, each starting only after the last has faded, the two character levels merged;
## - the camera keeps no shake offset and stays put while the survivor stands; the celebration's
##   block does not move between frames;
## - particle counts stay in a phone budget, the sparkle quad and its material are shared between
##   level-ups (a fresh BaseMaterial3D per level-up recompiled its shader every time: a 120 ms frame
##   on gl_compatibility); the light's life comes from data/level_fx.json.
## Fails on the base: no light, no skill celebration, no queue.
## Usage: godot --headless --path game --script res://tests/t_levelfx.gd

const FX_GROUP := &"level_up_fx"
const SPARKS_MAX := 64  ## sparkles per light, phone budget
const LIGHT_RANGE_MAX := 8.0

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist: game classes are loaded at run
## time and used untyped (the t_player pattern).
var world: Node
var player
var hud
var cam
var cel
var _char_mesh: Mesh  ## the first character light's sparkle quad

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
	print("[t_levelfx] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	world = get_root().get_node("World")
	world.pioneer_level = 2
	world.pioneer_xp = 0
	host = Node3D.new()
	host.name = "TLevelFx"
	get_root().add_child(host)
	var lab_kit = load("res://scripts/dev/lab_kit.gd")
	var kit: Dictionary = lab_kit.build(host, 30.0)
	player = kit["player"]
	cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.get_script() == load("res://scripts/ui/hunt_hud.gd"):
			hud = c
	await _frames(40)  # she lands on the floor; the warm-up copy comes and goes
	cel = hud.get("_levelups")
	_expect(cel != null, "the HUD holds a level-up queue (_levelups)")
	await _test_character()
	await _test_skill()
	await _test_burst()
	await _test_occupation()
	Engine.time_scale = 1.0
	_finish()

func _test_character() -> void:
	var children: int = player.get_child_count()
	var cam_at: Vector3 = cam.global_position
	world.add_xp(world.xp_for_level(world.pioneer_level) - world.pioneer_xp)
	await _frames(3)
	var fxs := _fxs()
	_expect(fxs.size() == 1, "character level-up: one light effect (got %d)" % fxs.size())
	if fxs.is_empty():
		return
	var fx: Node3D = fxs[0]
	var parts := _parts(fx)
	_expect(str(fx.get("kind")) == "character" and fx.get_parent() == player, "character level-up: the big light, a child of the survivor (kind %s)" % fx.get("kind"))
	_expect(absf(fx.position.y + float(player.half_height())) < 0.01, "character level-up: the light stands at her feet (y %.2f)" % fx.position.y)
	_expect(parts["meshes"] >= 5 and parts["has_pillar"], "character level-up: pillar, rings, rays and flash (%d meshes, pillar %s)" % [parts["meshes"], parts["has_pillar"]])
	_expect(parts["light"] != null and not (parts["light"] as OmniLight3D).shadow_enabled and (parts["light"] as OmniLight3D).omni_range <= LIGHT_RANGE_MAX, "character level-up: a shadowless OmniLight of at most %.0f m" % LIGHT_RANGE_MAX)
	_expect(parts["sparks"] > 0 and parts["sparks"] <= SPARKS_MAX, "character level-up: sparkles within the phone budget (%d <= %d)" % [parts["sparks"], SPARKS_MAX])
	_char_mesh = parts["spark_mesh"]
	var want_life := float((_json().get("character", {}) as Dictionary).get("life", -1.0))
	_expect(absf(float(fx.get("life")) - want_life) < 0.001, "character level-up: its life comes from level_fx.json (%.2f s)" % want_life)
	_expect(cel != null and str(cel.call("showing_key")).begins_with("character:%d" % (world.pioneer_level + 1)), "character level-up: the HUD celebrates Lv. %d (%s)" % [world.pioneer_level + 1, cel.call("showing_key") if cel else "no queue"])
	var rec := await _watch(float(fx.get("life")) + 0.3, true)
	_expect(float(rec["light_max"]) > 1.0, "character level-up: the light flares (peak energy %.1f)" % rec["light_max"])
	_expect(_fxs().is_empty() and player.get_child_count() == children, "character level-up: the light frees itself (children %d, was %d)" % [player.get_child_count(), children])
	_expect(rec["blocks"] > 0, "character level-up: the HUD draws its block (%d frames)" % rec["blocks"])
	_expect(float(rec["block_jump"]) == 0.0, "character level-up: the HUD block does not move between frames (max %.2f px)" % rec["block_jump"])
	_expect(float(rec["cam_offset"]) == 0.0 and float(rec["trauma"]) == 0.0, "character level-up: no camera shake (offset %.4f, trauma %.3f)" % [rec["cam_offset"], rec["trauma"]])
	_expect(cam.global_position.distance_to(cam_at) < 0.01 and float(rec["cam_step"]) < 0.001, "character level-up: the camera stays put (moved %.4f m, max step %.5f m)" % [cam.global_position.distance_to(cam_at), rec["cam_step"]])
	await _quiet()

func _test_skill() -> void:
	var s = player.skills
	var lv: int = s.level_of("survival")
	var big_sparks := int(((_json().get("character", {}) as Dictionary).get("sparkles", {}) as Dictionary).get("amount", 0))
	s.add_xp("survival", s.xp_to_next(lv) - s.xp_of("survival"), true)
	_expect(s.level_of("survival") == lv + 1, "skill level-up: survival rose to Lv. %d" % s.level_of("survival"))
	await _frames(3)
	var fxs := _fxs()
	_expect(fxs.size() == 1, "skill level-up: one light effect (got %d)" % fxs.size())
	if fxs.is_empty():
		return
	var parts := _parts(fxs[0])
	_expect(str(fxs[0].get("kind")) == "skill" and not parts["has_pillar"] and parts["meshes"] >= 1, "skill level-up: the small light, a ring and no pillar (kind %s, %d meshes)" % [fxs[0].get("kind"), parts["meshes"]])
	_expect(parts["sparks"] > 0 and parts["sparks"] < big_sparks, "skill level-up: fewer sparkles than a character level-up (%d < %d)" % [parts["sparks"], big_sparks])
	_expect(cel != null and str(cel.call("showing_key")) == "skill:survival:%d" % (lv + 1), "skill level-up: the HUD shows Survival Lv. %d (%s)" % [lv + 1, cel.call("showing_key") if cel else "no queue"])
	var rec := await _watch(float(fxs[0].get("life")) + 0.3, true)
	var big := float(((_json().get("character", {}) as Dictionary).get("light", {}) as Dictionary).get("energy", 0.0))
	_expect(float(rec["light_max"]) > 0.0 and float(rec["light_max"]) < big, "skill level-up: a weaker light (peak %.1f < %.1f)" % [rec["light_max"], big])
	_expect(_fxs().is_empty(), "skill level-up: the light frees itself")
	_expect(rec["blocks"] > 0 and float(rec["block_jump"]) == 0.0, "skill level-up: the skill banner is drawn and stays put (%d frames, max jump %.2f px)" % [rec["blocks"], rec["block_jump"]])
	_expect(float(rec["cam_offset"]) == 0.0, "skill level-up: no camera shake")
	await _quiet()

## Two character levels, then survival and gathering, from one grant: queued, merged, one at a time.
## Survival holds banked XP at its cap first: SkillState hears pioneer_changed before the HUD and
## releases it, so survival's level-up arrives before the character level that freed it.
func _test_burst() -> void:
	var s = player.skills
	s.add_xp("survival", 5000.0, true)
	await _quiet()
	var before: int = world.pioneer_level
	var need: int = world.xp_for_level(before) - world.pioneer_xp + world.xp_for_level(before + 1)
	var lv_g: int = s.level_of("gathering")
	s.add_xp("gathering", float(need))
	var after: int = world.pioneer_level
	_expect(after == before + 2 and s.level_of("gathering") > lv_g, "burst: one grant gave two character levels (%d -> %d) and gathering levels (%d -> %d)" % [before + 1, after + 1, lv_g, s.level_of("gathering")])
	if cel == null:
		return
	var pending: Array = cel.get("queue")
	var chars := pending.filter(func (e: Dictionary) -> bool: return e["kind"] == &"character").size()
	_expect(chars == 1 and pending.size() == 3, "burst: queued as one character level-up (merged) and one per category (%s)" % [pending.map(func (e: Dictionary) -> String: return "%s:%s:%d" % [e["kind"], e["tree"], e["level"]])])
	Engine.time_scale = 3.0
	var rec := await _watch(40.0, false)
	Engine.time_scale = 1.0
	var order: Array = rec["order"]
	print("[t_levelfx] burst order %s" % [order])
	_expect(order.size() == 3 and str(order[0]) == "character:%d" % (after + 1), "burst: the character level-up shows first, at the new level, then the categories (%s)" % [order])
	_expect(order.has("skill:gathering:%d" % s.level_of("gathering")) and order.has("skill:survival:%d" % s.level_of("survival")), "burst: gathering and survival each show their top level once")
	_expect(int(rec["fx_max"]) <= 1, "burst: one light effect at a time (max %d)" % rec["fx_max"])
	_expect(rec["char_meshes"] > 0 and rec["new_meshes"] == 0, "burst: the character light reuses the first one's sparkle quad and material (%d frames, %d with a new one)" % [rec["char_meshes"], rec["new_meshes"]])
	_expect(rec["overlaps"] == 0, "burst: each celebration starts after the last has faded (%d early starts)" % rec["overlaps"])
	_expect(float(rec["block_jump"]) == 0.0, "burst: no celebration moves between frames (max %.2f px)" % rec["block_jump"])
	_expect(float(rec["cam_offset"]) == 0.0 and float(rec["cam_step"]) < 0.001, "burst: the camera neither shakes nor moves (offset %.4f, step %.5f m)" % [rec["cam_offset"], rec["cam_step"]])
	_expect(_fxs().is_empty() and str(cel.call("showing_key")) == "", "burst: everything ends on its own")

## SkillState.apply_occupation emits skill_changed (Lv. 20) without a level gained by play: no light.
func _test_occupation() -> void:
	player.skills.apply_occupation("soldier")
	await _frames(4)
	_expect(_fxs().is_empty() and (cel == null or str(cel.call("showing_key")) == ""), "occupation head start: nothing celebrates")

## Frames until `seconds` pass (or, unless `fixed`, until nothing shows or glows): the order the
## celebrations show in, the most lights alive at once, early starts (a celebration replacing one
## that had not faded), the largest move of the drawn block while the same level-up shows, the
## camera's shake offset, trauma and largest per-frame step, and the lights' peak energy.
func _watch(seconds: float, fixed: bool) -> Dictionary:
	var out := {"order": [], "fx_max": 0, "overlaps": 0, "block_jump": 0.0, "blocks": 0, "cam_offset": 0.0, "trauma": 0.0, "cam_step": 0.0, "light_max": 0.0, "char_meshes": 0, "new_meshes": 0}
	var fade := float((_json().get("hud", {}) as Dictionary).get("fade_s", 0.45))
	var t := 0.0
	var last_key := ""
	var last_fading := 0.0
	var last_block := Rect2()
	var last_cam: Vector3 = cam.global_position
	var quiet := 0
	while t < seconds:
		await process_frame
		t += cam.get_process_delta_time()
		var fxs := _fxs()
		out["fx_max"] = maxi(out["fx_max"], fxs.size())
		for fx in fxs:
			var parts := _parts(fx)
			var l: OmniLight3D = parts["light"]
			if l:
				out["light_max"] = maxf(out["light_max"], l.light_energy)
			if str(fx.get("kind")) == "character":
				out["char_meshes"] += 1
				out["new_meshes"] += 0 if parts["spark_mesh"] == _char_mesh else 1
		var key: String = str(cel.call("showing_key")) if cel else ""
		var block: Rect2 = (hud.get("drawn_blocks") as Dictionary).get("levelup", Rect2())
		if key != "" and block.has_area():
			out["blocks"] += 1
			if key == last_key and last_block.has_area():
				out["block_jump"] = maxf(out["block_jump"], block.position.distance_to(last_block.position) + absf(block.size.y - last_block.size.y))
		if key != "" and key != last_key:
			(out["order"] as Array).append(key)
			if last_key != "" and last_fading < fade - 0.1:
				out["overlaps"] += 1
		if key != "":
			var cur: Dictionary = cel.get("current")
			last_fading = float(cur["t"]) - float(cur["out"]) if float(cur["out"]) >= 0.0 else 0.0
		last_key = key if key != "" else last_key
		last_block = block if key != "" else Rect2()
		out["cam_offset"] = maxf(out["cam_offset"], absf(cam.h_offset) + absf(cam.v_offset))
		out["trauma"] = maxf(out["trauma"], float(cam.trauma))
		out["cam_step"] = maxf(out["cam_step"], cam.global_position.distance_to(last_cam))
		last_cam = cam.global_position
		quiet = quiet + 1 if (key == "" and fxs.is_empty()) else 0
		if not fixed and quiet > 5:
			break
	return out

func _parts(fx: Node) -> Dictionary:
	var out := {"meshes": 0, "has_pillar": false, "light": null, "sparks": 0, "spark_mesh": null}
	for c in fx.get_children():
		if c is MeshInstance3D:
			out["meshes"] += 1
			out["has_pillar"] = out["has_pillar"] or (c as MeshInstance3D).mesh is CylinderMesh
		elif c is OmniLight3D:
			out["light"] = c
		elif c is CPUParticles3D:
			out["sparks"] += (c as CPUParticles3D).amount
			out["spark_mesh"] = (c as CPUParticles3D).mesh
		elif c is GPUParticles3D:
			out["sparks"] += (c as GPUParticles3D).amount
	return out

func _fxs() -> Array:
	return get_nodes_in_group(FX_GROUP)

func _json() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/level_fx.json")) if FileAccess.file_exists("res://data/level_fx.json") else null
	return parsed if parsed is Dictionary else {}

## Ends what still shows and waits out any light.
func _quiet() -> void:
	if cel:
		cel.call("clear")
	var t := 0.0
	while not _fxs().is_empty() and t < 5.0:
		await process_frame
		t += cam.get_process_delta_time()
	await _frames(2)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _finish() -> void:
	if failures.is_empty():
		print("[t_levelfx] PASS")
		quit(0)
		return
	for f in failures:
		print("[t_levelfx] FAIL %s" % f)
	print("[t_levelfx] FAIL count=%d" % failures.size())
	quit(1)
