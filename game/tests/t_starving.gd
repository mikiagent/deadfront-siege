extends SceneTree
## STARVING acceptance (owner 2026-10-28: "if you're starving, it should show up like a status effect and you
## should lose health"; "starving and poison cant directly kill you but they can get you to 1HP"):
##   Starving appears only after rules.json hunger.starving_after_s on an empty stomach and clears when a
##   meal lifts her out of it; it grows a stack every hunger.starving_stack_s (max 3); each tick takes
##   0.1 HP/s per stack (statuses.json) at the status's own amber colour (never green, never the poison
##   purple); its box beside her and the vignette show and go with it.
##   Starving and poison stop at 1 HP; bleed still kills; at 1 HP from starving a creature bite still kills.
## Usage: godot --headless --path game --script res://tests/t_starving.gd -> "[t_starving] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _data: Node
var DIG: GDScript
var TOK: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_starving] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_data = root.get_node("Data")
	DIG = load("res://scripts/items/digestion.gd")
	TOK = load("res://scripts/ui/ui_tokens.gd")
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("quick_row_y"):
			_hud = c
	root.get_node("World").load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # the test drives PlayerSim and the ticks
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	_test_data()
	await _test_appears_and_clears()
	await _test_nonlethal()
	_test_dot_never_interrupts()
	if _fails.is_empty():
		print("[t_starving] PASS")
		quit(0)
	else:
		print("[t_starving] FAIL count=%d" % _fails.size())
		quit(1)

func _test_data() -> void:
	var def = _data.status(&"starving")
	_expect(def != null and def.kind == &"effect" and def.nonlethal and def.fx_vignette and is_equal_approx(def.dps, 0.1) and def.max_stacks == 3, "starving: an effect, nonlethal, vignette, 0.25 HP/s, up to 3 stacks")
	var c: Color = def.fx_color
	_expect(c.is_equal_approx(TOK.STARVING), "its colour is UiTokens.STARVING (%s)" % c)
	_expect(not (c.s > 0.25 and c.h > 0.2 and c.h < 0.47) and not c.is_equal_approx(TOK.POISON), "not green, not the poison purple (hue %.2f)" % c.h)
	var icons: GDScript = load("res://scripts/ui/ui_icons.gd")
	_expect(icons.path_for(def.fx_icon).ends_with("starving.svg"), "its own glyph (%s)" % icons.path_for(def.fx_icon))
	for id in [&"venom", &"poisoned", &"stomachache", &"starving"]:
		_expect(_data.status(id).nonlethal, "%s is nonlethal" % id)
	for id in [&"bleed", &"deep_bleed", &"pinned"]:
		_expect(not _data.status(id).nonlethal, "%s stays lethal" % id)

func _sim(dt: float = 0.0) -> void:
	_player.sim.tick(dt)

func _test_appears_and_clears() -> void:
	var dig = DIG.of(_player)
	var v = _player.vitals
	v.health = v.effective_max_health()
	dig.rows().clear()
	_player.sim.starving_s = 0.0
	dig.empty_for_s = 0.0
	dig.set_fullness(60.0)  # fed band
	_sim()
	_expect(v.fullness_state == &"fed" and not _player.statuses.has(&"starving"), "fed: no Starving")
	dig.set_fullness(15.0)  # peckish band
	_player.sim.starving_s = 700.0  # a long hungry spell never makes her starve
	dig.empty_for_s = 700.0
	_sim()
	_expect(v.fullness_state == &"peckish" and not _player.statuses.has(&"starving"), "peckish: no Starving yet")
	dig.set_fullness(0.0)
	_player.sim.starving_s = 0.0
	dig.empty_for_s = 0.0
	_sim()
	_player.sim.starving_s = 100.0  # 100 s empty: still under hunger.starving_after_s
	dig.empty_for_s = 100.0
	_sim()
	_expect(v.fullness_state == &"empty" and not _player.statuses.has(&"starving"), "empty for 100 s: no Starving yet")
	_player.sim.starving_s = DIG.starving_after_s()  # past the ten minutes
	dig.empty_for_s = _player.sim.starving_s
	_sim()
	_expect(_player.statuses.has(&"starving") and _player.statuses.get_instance(&"starving").stacks == 1, "empty past %.0f s: Starving, one stack" % DIG.starving_after_s())
	await _frames(4)
	var sx = _hud.get("_status_fx")
	_expect(sx.boxes.has(&"starving"), "its box shows beside her")
	_expect(sx.vignette_alpha > 0.0, "the vignette shows (%.2f)" % sx.vignette_alpha)
	# The rate: 0.5 s ticks of 0.1 HP/s per stack, numbers in its own colour.
	var inst = _player.statuses.get_instance(&"starving")
	var after: float = DIG.starving_after_s()
	for stacks in [1, 3]:
		var secs: float = after if stacks == 1 else after + DIG.starving_stack_s() * 2.0
		_player.sim.starving_s = secs
		dig.empty_for_s = secs
		_sim()
		_expect(inst.stacks == stacks, "%.0f s starving: %d stack(s) (%d)" % [secs, stacks, inst.stacks])
		var hp: float = v.health
		var per: float = _data.status(&"starving").dps * float(stacks) * 0.5
		var before: int = _hud.get("_events").player_floats.size()
		_player.statuses._dot(inst)
		_expect(absf((hp - v.health) - per) < 0.0001, "a tick at %d stack(s) takes %.3f HP (%.3f)" % [stacks, per, hp - v.health])
		var floats: Array = _hud.get("_events").player_floats
		if floats.size() == before + 1:
			_expect((floats[floats.size() - 1]["col"] as Color).is_equal_approx(TOK.STARVING), "its tick number is the starving amber")
		else:
			_expect(false, "a tick adds one number (%d -> %d)" % [before, floats.size()])
	# Eating lifts her out of empty: Starving clears at once, the box and the vignette go.
	dig.add_fullness(40.0)
	_sim()
	_expect(v.fullness_state != &"empty" and not _player.statuses.has(&"starving") and _player.sim.starving_s == 0.0, "a meal clears Starving (%s)" % v.fullness_state)
	await _frames(4)
	_expect(not sx.boxes.has(&"starving") and sx.vignette_alpha == 0.0, "its box and the vignette are gone")

## HUNGER memo Part 1 s1.4 step 3 (owner 2026-10-29: "let me harvest berries while im hungry"): a status
## tick hurts but never cancels a gather or ends a sleep; a real hit still does both.
func _test_dot_never_interrupts() -> void:
	var dig = DIG.of(_player)
	var v = _player.vitals
	_player.statuses.from_array([])
	v.revive(v.effective_max_health())
	_player.dead = false
	_player._sleep_left = 0.0
	dig.set_fullness(0.0)
	_player.sim.starving_s = DIG.starving_after_s() + 1.0
	dig.empty_for_s = _player.sim.starving_s
	_sim()
	_expect(_player.statuses.has(&"starving"), "she is starving for the interrupt check")
	# A real harvest node (the island's own bushes are not guaranteed on this lab terrain).
	var node := HarvestNode.new()
	_host.add_child(node)
	node.setup(&"probe_bush", &"berry", 1, 2, {}, &"none", Color.GREEN)
	_expect(not node.depleted, "a live harvest node exists to gather from")
	_player.gather_target = node
	_player._sleep_left = 30.0
	var hp: float = v.health
	_player.statuses._dot(_player.statuses.get_instance(&"starving"))
	_expect(v.health < hp, "the starving tick lands (%.2f -> %.2f)" % [hp, v.health])
	_expect(_player.gather_target == node, "a status tick does not cancel the gather")
	_expect(_player._sleep_left > 0.0, "a status tick does not end the sleep (%.1f s left)" % _player._sleep_left)
	# A real hit still cancels both: the guard is specific to status ticks.
	v.take_damage(3.0)
	_expect(_player.gather_target == null, "a hit cancels the gather")
	_expect(_player._sleep_left <= 0.0, "a hit ends the sleep")
	node.queue_free()
	_player.statuses.from_array([])
	_player.sim.starving_s = 0.0
	dig.set_fullness(60.0)

func _test_nonlethal() -> void:
	var dig = DIG.of(_player)
	var v = _player.vitals
	# Starving alone stops at 1 HP.
	dig.set_fullness(0.0)
	_player.sim.starving_s = DIG.starving_after_s() + 1.0
	dig.empty_for_s = _player.sim.starving_s
	_sim()
	v.health = 1.3
	var inst = _player.statuses.get_instance(&"starving")
	for i in 40:
		_player.statuses._dot(inst)
	_expect(is_equal_approx(v.health, 1.0) and not v.dead, "starving alone stops at 1 HP (%.2f)" % v.health)
	# Poison alone stops at 1 HP.
	dig.add_fullness(40.0)
	_sim()
	_player.statuses.apply(&"venom")
	v.health = 2.0
	for i in 20:
		_player.statuses._dot(_player.statuses.get_instance(&"venom"))
	_expect(is_equal_approx(v.health, 1.0) and not v.dead, "venom alone stops at 1 HP (%.2f)" % v.health)
	_player.statuses.clear_id(&"venom")
	# Bleed still kills.
	_player.statuses.apply(&"bleed")
	v.health = 0.5
	for i in 20:
		if v.dead:
			break
		_player.statuses._dot(_player.statuses.get_instance(&"bleed"))
	_expect(v.dead, "bleed can still kill (health %.2f, dead %s)" % [v.health, v.dead])
	_player.statuses.from_array([])
	v.revive(1.0)
	_player.dead = false
	await _frames(2)
	# Starved to 1 HP, a creature bite still kills.
	dig.set_fullness(0.0)
	_player.sim.starving_s = DIG.starving_after_s() + 1.0
	dig.empty_for_s = _player.sim.starving_s
	_sim()
	v.health = 1.2
	for i in 40:
		_player.statuses._dot(_player.statuses.get_instance(&"starving"))
	_expect(is_equal_approx(v.health, 1.0), "starved down to 1 HP (%.2f)" % v.health)
	var raptor = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	_host.add_child(raptor)
	raptor.global_position = _player.global_position + Vector3(1.0, 0.0, 0.0)
	raptor.spawn(_data.creature(&"velociraptor"))
	raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED
	var CA: GDScript = load("res://scripts/combat/creature_attack.gd")
	for i in 60:  # the hit roll can miss; keep biting until one lands
		if CA._deal_damage(raptor, _player):
			break
	_expect(v.dead, "at 1 HP from starving, a creature bite still kills (health %.2f)" % v.health)
	raptor.queue_free()
