extends SceneTree
## REST acceptance (owner: "resting should sit you down and heal you and lower exhaustion. I tried this
## on vercel and it didn't work"). On the home island, in the open, beside the camp bonfire and beside
## the camp tent: the Rest hex is offered out of combat; Rest sits the survivor down (sleep_down held on
## the seated frame, grounded, no sliding); Health rises and fatigue falls at data/rest.json's rate for
## that place, open < fire < shelter; Health never passes its maximum and fatigue never drops below 0;
## moving, a tap-to-walk, damage, a hit (combat) and a creature closing in each end it with the
## stand-up; it is refused in combat, but a status that deals damage (a raw-meat Stomachache, a bleed)
## neither refuses it nor stands her up: it shows in the chip's net Health rate, and Dirty slows the
## fatigue rate (spec 01:19); Sleep at the tent with a Stomachache completes; the hex hides in water;
## the X key and online intents go through PlayerActions; the bonfire clears Wet and shifts climate
## fatigue (PRD :285); the HUD chip shows the live rates right under the chip row (below the Claim hex
## only when it stands there); a save made mid-rest loads back seated, one made standing loads standing.
## Sleep at the tent heals and lowers fatigue while asleep, not only on its last frame. Fails on the
## base: it has no Rest at all.
## Usage: godot --headless --path game --script res://tests/t_rest.gd

const SPOT_M := 1.9 ## how far from the fire or the tent the survivor sits (the rest lab's spots)
const RATE_TOL := 0.06 ## measured over whole physics frames; the 0.5 s place recheck is the only slack

var failures: Array[String] = []
var _started := false
var host: Node3D
## `godot --script` compiles this file before the autoloads exist, so game classes are loaded at
## run time and used untyped (the t_player pattern).
var player
var rest
var rt
var data: Node
var places: Dictionary = {}

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/rest.json")) if FileAccess.file_exists("res://data/rest.json") else null
	places = (parsed as Dictionary).get("places", {}) if parsed is Dictionary else {}
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_rest] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	get_root().get_node("Game").max_creatures_per_island = 0  # no wandering aggro: the numbers are the rest's alone
	host = Node3D.new()
	host.name = "TRest"
	get_root().add_child(host)
	var world := get_root().get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	rt = world.runtime
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	player.global_position = rt._camp_pos + Vector3(0, 1, 0)
	await _frames(5)
	_clear_creatures()
	rt.weather.raining = false
	rt.weather.set("_rain_cd", 1.0e9)
	var fire: Node3D = rt.get_node_or_null("CampFire")
	var tent: Node3D = rt.get_node_or_null("CampShed")
	_expect(fire != null and tent != null, "the home camp has its bonfire and tent")
	var spots := {"open": _open_spot(), "fire": _beside(fire, false), "shelter": _beside(tent, true)}
	rest = player.sim.get("rest")
	_test_hex(spots)
	await _test_sleep_recovers(spots["shelter"])
	if rest == null:
		_expect(false, "PlayerSim has a RestState (the base has no Rest action at all)")
		_finish()
		return
	_expect(places.has("open") and places.has("fire") and places.has("shelter"), "data/rest.json has the open, fire and shelter rates")
	await _test_sit(spots["open"])
	for where in ["open", "fire", "shelter"]:
		await _test_rate(where, spots[where])
	await _test_rate("shelter", spots["shelter"], &"dirty")
	_expect(_rate(&"open", "hp_per_s") < _rate(&"fire", "hp_per_s") and _rate(&"fire", "hp_per_s") < _rate(&"shelter", "hp_per_s")
		and _rate(&"open", "fatigue_per_min") < _rate(&"fire", "fatigue_per_min") and _rate(&"fire", "fatigue_per_min") < _rate(&"shelter", "fatigue_per_min"),
		"recovery grows open < fire < shelter (spec 01:19, PRD :118)")
	await _test_clamps(spots["shelter"])
	await _test_sit_to_sleep(spots["shelter"])
	await _test_cancels(spots["open"])
	await _test_refusals(spots["open"])
	await _test_status_ticks(spots["shelter"])
	await _test_fire_effects(spots["fire"], spots["open"])
	await _test_hud(spots["fire"], spots["open"])
	_test_intents(spots["open"])
	await _test_save_load(spots["fire"])
	_finish()

func _finish() -> void:
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_rest] PASS")
		quit(0)
	else:
		print("[t_rest] FAIL count=%d" % failures.size())
		quit(1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _seconds(s: float) -> void:
	await create_timer(s).timeout

func _clear_creatures() -> void:
	for c in get_nodes_in_group("creatures"):
		c.queue_free()

func _rate(where: StringName, key: String) -> float:
	return float((places.get(str(where), {}) as Dictionary).get(key, 0.0))

# ---------------------------------------------------------------- spots

## Dry, open grass 18-30 m from the camp with no fire, bedding or building within 8 m.
func _open_spot() -> Vector3:
	var camp: Vector3 = rt._camp_pos
	for r in [18.0, 22.0, 26.0, 30.0]:
		for k in 16:
			var a := TAU * float(k) / 16.0
			var at := camp + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if rt.surface_y(at.x, at.z) < 0.4:
				continue
			var clear := true
			for g in ["placed_building", "craft_station", "harvest", "harbour"]:
				for n in get_nodes_in_group(g):
					if n is Node3D and (n as Node3D).global_position.distance_to(at) < 8.0:
						clear = false
			if clear:
				return at
	return camp + Vector3(20, 0, 0)

## SPOT_M from a building, on the side facing the camp centre (or away from it).
func _beside(n: Node3D, toward_camp: bool) -> Vector3:
	var c := n.global_position
	var to: Vector3 = (rt._camp_pos - c) * (1.0 if toward_camp else -1.0)
	to.y = 0.0
	if to.length_squared() < 0.01:
		to = Vector3(0, 0, 1)
	return c + to.normalized() * SPOT_M

## Stand up, clear the state a previous case left, and stand on `at`, hurt and tired, out of combat.
func _reset(at: Vector3) -> void:
	if rest and rest.resting:
		rest.stop(false)
	player._sleep_left = 0.0
	player.clear_nav()
	player.hunt.stop()
	player.anim.revive()
	player.visual.position.y = 0.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + 1.0, at.z)
	player.statuses.from_array([])
	player.vitals.health = 40.0
	player.vitals.fatigue = 60.0
	player.vitals.health_regen = 0.8
	player._last_hit_taken_s = -999.0
	await _frames(6)

func _ids() -> Array:
	var ids: Array = []
	for a in player.context_actions():
		ids.append(str(a["id"]))
	return ids

# ---------------------------------------------------------------- cases

func _test_hex(spots: Dictionary) -> void:
	for where in spots:
		player.global_position = Vector3(spots[where].x, rt.surface_y(spots[where].x, spots[where].z) + 1.0, spots[where].z)
		_expect("rest" in _ids(), "%s: the Rest hex is offered %s" % [where, _ids()])
	_expect(InputMap.has_action("rest") and InputMap.action_get_events("rest").any(func (e: InputEvent) -> bool:
		return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_X), "desktop: the X key is the rest action")
	var icons: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_icons.json")) as Dictionary).get("icons", {})
	_expect(str(icons.get("rest", "")).ends_with("/rest.svg") and ResourceLoader.exists(str(icons.get("rest", ""))), "the Rest hex has its own white icon")

## Sleep at the camp tent heals and lowers fatigue while asleep (the base held fatigue flat for the
## whole 10 s and cleared it on the last frame; Health only had the 0.8 HP/s everyone gets standing).
func _test_sleep_recovers(at: Vector3) -> void:
	await _reset(at)
	player.vitals.health_regen = 0.0  # what moves now is the sleep's own
	player.sim.start_sleep()
	_expect(player._sleep_left > 0.0, "the Sleep flow starts at the camp tent")
	var hp0: float = player.vitals.health
	var f0: float = player.vitals.fatigue
	await _seconds(4.0)
	_expect(player._sleep_left > 0.0, "still asleep 4 s in")
	_expect(player.vitals.health > hp0 + 4.0, "asleep 4 s: Health rose %.1f -> %.1f" % [hp0, player.vitals.health])
	_expect(player.vitals.fatigue < f0 - 1.0, "asleep 4 s: fatigue fell %.2f -> %.2f before the sleep ends" % [f0, player.vitals.fatigue])
	if rest:
		_expect(rest.hud_lines().size() == 3 and rest.hud_lines()[0] == "Sleeping", "the chip shows Sleeping with its rates %s" % [rest.hud_lines()])
	await _seconds(6.5)
	_expect(player._sleep_left <= 0.0 and player.vitals.fatigue < 1.0, "a completed tent sleep still clears fatigue (%.2f)" % player.vitals.fatigue)
	await _seconds(2.2)

func _test_sit(at: Vector3) -> void:
	await _reset(at)
	var ap: AnimationPlayer = player.rig.anim_player
	player.context_action("rest")
	_expect(rest.resting and player.anim.is_sitting(), "the Rest hex sits her down")
	_expect(not "rest" in _ids(), "while resting the hex is gone (move to get up, as Sleep)")
	var p0: Vector3 = player.global_position
	await _seconds(1.4)
	_expect(player.anim.current_clip == &"sleep_down" and not ap.is_playing() and absf(ap.current_animation_position - 1.0) < 0.1,
		"seated: sleep_down held on its seated frame (clip=%s playing=%s t=%.2f), not lying down and not a T-pose" % [player.anim.current_clip, ap.is_playing(), ap.current_animation_position])
	_expect(player.visual.position.y < -0.5, "seated on the ground: the visual is grounded as for sleep (y=%.2f)" % player.visual.position.y)
	await _seconds(1.0)
	var slid := Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length()
	_expect(slid < 0.02 and rest.resting, "no sliding while seated (%.3f m)" % slid)

## HP and fatigue move at the place's rate: passive regen off, fatigue gains added back from the log.
## With `status` (Dirty), fatigue recovery is the rate over its fatigue_mult (spec 01:19: hygiene).
func _test_rate(where: String, at: Vector3, status: StringName = &"") -> void:
	await _reset(at)
	if status != &"":
		player.statuses.apply(status)
	rest.start()
	await _frames(2)
	_expect(rest.place == StringName(where), "%s spot reads as %s (got %s)" % [where, where, rest.place])
	player.vitals.health_regen = 0.0
	var hp0: float = player.vitals.health
	var f0: float = player.vitals.fatigue
	var gained0 := _gained()
	var n := 120
	await _frames(n)
	var secs := float(n) / float(Engine.physics_ticks_per_second)
	var hp_rate: float = (player.vitals.health - hp0) / secs
	var fat_rate: float = (f0 - player.vitals.fatigue + _gained() - gained0) / secs * 60.0
	var want_hp := _rate(StringName(where), "hp_per_s")
	var want_fat := _rate(StringName(where), "fatigue_per_min")
	if status != &"":
		var mult: float = float(data.status(status).fatigue_mult)
		_expect(mult > 1.0, "%s makes her tire faster (fatigue_mult %.2f)" % [status, mult])
		want_fat /= mult
		where += " " + str(status)
		_expect(rest.hud_lines()[2] == "-%d fatigue/min (%s)" % [roundi(want_fat), status], "the chip names it: %s" % [rest.hud_lines()])
	_expect(rest.resting and absf(hp_rate - want_hp) <= want_hp * RATE_TOL, "%s: Health +%.2f/s (data %.2f)" % [where, hp_rate, want_hp])
	_expect(absf(fat_rate - want_fat) <= want_fat * RATE_TOL, "%s: fatigue -%.2f/min (data %.2f)" % [where, fat_rate, want_fat])
	player.vitals.health_regen = 0.8

func _gained() -> float:
	var total := 0.0
	for k in player.vitals.fatigue_log:
		total += float(player.vitals.fatigue_log[k])
	return total

func _test_clamps(at: Vector3) -> void:
	await _reset(at)
	player.vitals.health = player.vitals.effective_max_health() - 0.2
	player.vitals.fatigue = 0.3
	rest.start()
	await _seconds(2.0)
	_expect(player.vitals.health <= player.vitals.effective_max_health() and is_equal_approx(player.vitals.health, player.vitals.effective_max_health()),
		"Health stops at its maximum (%.3f / %.0f)" % [player.vitals.health, player.vitals.effective_max_health()])
	_expect(player.vitals.fatigue >= 0.0 and player.vitals.fatigue < 0.05, "fatigue stops at 0 (%.3f)" % player.vitals.fatigue)
	var lines: PackedStringArray = rest.hud_lines()
	_expect(lines.size() == 3 and lines[1] == "HP full" and lines[2] == "Rested", "the chip says HP full and Rested %s" % [lines])

## Sleep chosen while seated at the tent lies down from the sit (no jump back to standing).
func _test_sit_to_sleep(at: Vector3) -> void:
	await _reset(at)
	var ap: AnimationPlayer = player.rig.anim_player
	rest.start()
	await _seconds(1.3)
	player.context_action("sleep")
	await _frames(2)
	_expect(not rest.resting and player._sleep_left > 0.0 and player.anim.current_clip == &"sleep_down" and ap.is_playing() and ap.current_animation_position >= 0.99,
		"Sleep from the sit lies down from the seated frame (clip=%s t=%.2f)" % [player.anim.current_clip, ap.current_animation_position])
	player.vitals.take_damage(1.0)  # ends the sleep for the next case
	await _seconds(2.5)

func _test_cancels(at: Vector3) -> void:
	var ap: AnimationPlayer = player.rig.anim_player
	# Move keys / joystick.
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	_expect(not rest.resting and player.anim.current_clip == &"sleep_up" and ap.current_animation_position < 1.2,
		"a move key gets her up with the stand-up (clip=%s t=%.2f)" % [player.anim.current_clip, ap.current_animation_position])
	await _seconds(1.6)
	_expect(player.anim.current_clip == &"idle" and absf(player.visual.position.y) < 0.05,
		"stood up: idle, visual back at standing height (y=%.2f)" % player.visual.position.y)
	# Tap-to-walk.
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	player.nav_to(player.global_position + Vector3(3, 0, 0))
	await _frames(2)
	_expect(not rest.resting and player.anim.current_clip == &"sleep_up", "a tap on the ground gets her up")
	# Damage.
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	player.vitals.take_damage(5.0)
	await _frames(2)
	_expect(not rest.resting and player.anim.current_clip == &"sleep_up", "damage gets her up with the stand-up, not a flinch from the floor (clip=%s)" % player.anim.current_clip)
	# A hit (combat starts) with the damage arriving later.
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	player._last_hit_taken_s = Time.get_ticks_msec() * 0.001
	await _frames(2)
	_expect(not rest.resting, "entering combat gets her up")
	# A creature closing in on her.
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = player.global_position + Vector3(12, 0, 0)
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # the rule under test, not the AI
	c.brain.attack_target = player
	c.brain.state = &"approach"
	await _seconds(0.7)
	_expect(not rest.resting, "a creature hunting her gets her up")
	_expect("rest" in _ids() and rest.refusal() != "", "while hunted, Rest is refused: %s" % rest.refusal())
	c.queue_free()
	await _frames(2)

func _test_refusals(at: Vector3) -> void:
	await _reset(at)
	player._last_hit_taken_s = Time.get_ticks_msec() * 0.001
	_expect(not rest.start() and not rest.resting, "refused just after a hit: %s" % rest.refusal())
	player._last_hit_taken_s = -999.0
	_expect(rest.start() and rest.resting, "allowed again out of combat")
	rest.stop(false)
	player.statuses.apply(&"bleed")
	_expect(rest.refusal() == "" and rest.start() and rest.resting, "allowed while bleeding (it slows the healing; refusal '%s')" % rest.refusal())
	rest.stop(false)
	player.in_water = true
	_expect(not "rest" in _ids(), "in water the Rest hex is hidden, not offered and refused %s" % [_ids()])
	player.in_water = false
	await _frames(2)

## The owner's report again: raw meat gives a Stomachache (300 s, 0.2 dps, no cure). Its ticks must not
## refuse Rest, stand her up or end a Sleep (the base's damaged signal ended both within 3 s).
func _test_status_ticks(at: Vector3) -> void:
	await _reset(at)
	player.statuses.apply(&"stomachache")
	player.context_action("rest")
	_expect(rest.resting, "with a Stomachache the Rest hex sits her down at the tent")
	await _seconds(1.5)
	var hp0: float = player.vitals.health
	var f0: float = player.vitals.fatigue
	await _seconds(3.0)
	var dps: float = float(data.status(&"stomachache").dps)
	var want: float = _rate(&"shelter", "hp_per_s") - dps  # each tick also pauses passive regen
	var got: float = (player.vitals.health - hp0) / 3.0
	_expect(rest.resting and player.anim.is_sitting() and player.anim.current_clip == &"sleep_down",
		"4.5 s of Stomachache ticks: still seated (resting=%s clip=%s)" % [rest.resting, player.anim.current_clip])
	_expect(absf(got - want) <= 0.15 and player.vitals.fatigue < f0 - 1.0,
		"net Health +%.2f/s (rest %.1f - %.1f dps), fatigue %.2f -> %.2f" % [got, _rate(&"shelter", "hp_per_s"), dps, f0, player.vitals.fatigue])
	var lines: PackedStringArray = rest.hud_lines()
	_expect(lines[1] == "%+.1f HP/s (stomachache)" % want, "the chip shows the net rate and why: %s" % [lines])
	player.statuses.apply(&"deep_bleed")
	lines = rest.hud_lines()
	_expect(lines[1].begins_with("-") and lines[1].contains("deep bleed"), "a Deep Bleed blocks the healing and the chip says so: %s" % [lines])
	player.statuses.clear_id(&"deep_bleed")
	player.vitals.take_damage(1.0)  # a hit (not a tick) still gets her up
	await _frames(2)
	_expect(not rest.resting and player.anim.current_clip == &"sleep_up", "a real hit still gets her up (clip=%s)" % player.anim.current_clip)
	# Sleep at the tent with the Stomachache: it completes.
	await _reset(at)
	player.statuses.apply(&"stomachache")
	player.sim.start_sleep()
	var left0: float = player._sleep_left
	await _seconds(left0 + 0.6)
	_expect(player.statuses.has(&"stomachache") and player._sleep_left <= 0.0 and player.vitals.fatigue < 1.0,
		"Sleep at the tent with a Stomachache completes: fatigue %.2f (the base woke her on the first tick)" % player.vitals.fatigue)
	await _seconds(2.2)

func _test_fire_effects(fire_at: Vector3, open_at: Vector3) -> void:
	await _reset(fire_at)
	player.statuses.apply(&"wet")
	rest.start()
	await _frames(2)
	_expect(not player.statuses.has(&"wet"), "sitting by the bonfire clears Wet (PRD :285)")
	_expect(is_equal_approx(rest.climate_mult("cold"), 0.8) and is_equal_approx(rest.climate_mult("heat"), 1.2), "by the fire: cold fatigue x0.8, heat x1.2 (PRD :285)")
	await _reset(open_at)
	rest.start()
	await _frames(2)
	_expect(is_equal_approx(rest.climate_mult("cold"), 1.0), "in the open: no climate change")

func _test_hud(at: Vector3, open_at: Vector3) -> void:
	await _reset(at)
	var hud = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	var layer := CanvasLayer.new()
	host.add_child(layer)
	hud.bind(player)
	layer.add_child(hud)
	await _frames(3)
	_expect(rest.hud_lines().is_empty(), "standing: no Resting chip")
	rest.start()
	await _frames(3)
	var lines: PackedStringArray = rest.hud_lines()
	var want_hp: float = _rate(&"fire", "hp_per_s") + player.vitals.health_regen
	_expect(lines.size() == 3 and lines[0] == str(places["fire"]["label"]) and lines[1] == "+%.1f HP/s" % want_hp
		and lines[2] == "-%d fatigue/min" % roundi(_rate(&"fire", "fatigue_per_min")), "by the fire the chip reads %s" % [lines])
	hud.queue_redraw()
	await process_frame
	await process_frame
	_expect(hud.drawn_blocks.has("rest"), "the HUD draws the Resting chip's rates (blocks %s)" % [hud.drawn_blocks.keys()])
	var row: Rect2 = hud.drawn_blocks.get("statuses", Rect2())
	var box: Rect2 = hud.drawn_blocks.get("rest", Rect2())
	_expect(row.size.y > 0.0 and box.position.y >= row.end.y - 4.0 and box.position.y <= row.end.y + 4.0,
		"no Claim hex: the rates box sits right under the chip row (row ends %.0f, box starts %.0f)" % [row.end.y, box.position.y])
	# In the open the Claim hex stands beside the chips: the box goes below it.
	rest.stop(false)
	await _reset(open_at)
	rest.start()
	await _seconds(0.5)
	hud.queue_redraw()
	await process_frame
	await process_frame
	var claim: Control = null
	for c in hud.get_children():
		if c is Control and str(c.get("caption")).begins_with("CLAIM"):
			claim = c
	box = hud.drawn_blocks.get("rest", Rect2())
	_expect(claim != null and not Rect2(claim.position, claim.size).intersects(box),
		"with the Claim hex there the box clears it (hex %s, box %s)" % [Rect2(claim.position, claim.size) if claim else null, box])
	layer.queue_free()

func _test_intents(at: Vector3) -> void:
	if rest.resting:
		rest.stop(false)
	player.actions.online = true
	player.actions.sent.clear()
	player.actions.rest()
	_expect(not rest.resting and player.actions.sent.size() == 1 and player.actions.sent[0] == {"op": "act.rest", "a": {"on": true}},
		"online: Rest is an act.rest intent, nothing applied locally %s" % [player.actions.sent])
	player.actions.online = false
	player.global_position = Vector3(at.x, rt.surface_y(at.x, at.z) + 1.0, at.z)
	var press := InputEventAction.new()
	press.action = &"rest"
	press.pressed = true
	player.controls.handle_unhandled(press)
	_expect(rest.resting, "offline: the X key (rest action) sits her down")
	player.controls.handle_unhandled(press)
	_expect(not rest.resting, "the X key again gets her up")

## Spec 01:22: an active rest survives a save and reload, with Health and fatigue as saved.
func _test_save_load(at: Vector3) -> void:
	await _reset(at)
	rest.start()
	await _seconds(1.3)
	var SG: GDScript = load("res://scripts/core/save_game.gd")
	_expect(SG.save_now(), "a save mid-rest writes")
	var saved: Dictionary = load("res://scripts/core/save_migrations.gd").read(SG.path).get("data", {})
	_expect(saved.get("player", {}).get("resting", null) == true, "the save records the rest")
	var hp: float = float(saved["player"]["vitals"]["health"])
	var fat: float = float(saved["player"]["vitals"]["fatigue"])
	rest.stop(false)
	player.anim.revive()
	player.visual.position.y = 0.0
	player.vitals.health = 90.0
	player.vitals.fatigue = 5.0
	SG.load_now(host)
	await _frames(3)
	rt = get_root().get_node("World").runtime
	_expect(rest.resting and player.anim.is_sitting(), "after the reload she is resting again")
	_expect(absf(player.vitals.health - hp) < 1.0 and absf(player.vitals.fatigue - fat) < 0.2,
		"Health %.1f and fatigue %.2f are the saved %.1f and %.2f" % [player.vitals.health, player.vitals.fatigue, hp, fat])
	await _seconds(1.0)
	_expect(rest.place == &"fire" and player.vitals.fatigue < fat, "the reloaded rest goes on by the fire (%s, %.2f)" % [rest.place, player.vitals.fatigue])
	# A save made standing loads standing, even when she sat down after it.
	rest.stop(false)
	player.anim.revive()
	player.visual.position.y = 0.0
	await _frames(3)
	_expect(SG.save_now(), "a save while standing writes")
	rest.start()
	await _seconds(1.3)
	SG.load_now(host)
	await _seconds(0.5)
	_expect(not rest.resting and not player.anim.is_sitting() and player.anim.current_clip == &"idle" and absf(player.visual.position.y) < 0.05,
		"a standing save loads standing (resting=%s clip=%s visual_y=%.2f)" % [rest.resting, player.anim.current_clip, player.visual.position.y])
