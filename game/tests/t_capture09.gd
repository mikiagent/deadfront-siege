extends SceneTree
## CAPTURE09 (spec 09 §1): a wild animal is capturable when it is stunned/collapsed (the existing
## `knockdown` status) at ANY HP, OR its HP is at or below 30 %. One rule, one place:
## FieldTame.capture_window(). The net's chance keeps using ACTUAL HP, the DoT guard uses the same
## window, and the "stun it" hint fires once per creature at <= 50 %.
## Run: Godot --headless --path game --script res://tests/t_capture09.gd -> "[t_capture09] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const HINT := "Stun the dinosaur to capture it safely."
const WATCHDOG_S := 60.0

var _fails: PackedStringArray = []
var _started := false
var _t0 := 0.0
var _host: Node3D
var _player  ## untyped: the Player class names autoloads, which do not exist at compile time
var FieldTameS: GDScript
var CaptureS: GDScript
var HealthS: GDScript
var StatusS: GDScript
var CreatureS: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	_t0 = Time.get_ticks_msec() * 0.001
	FieldTameS = load("res://scripts/pets/field_tame.gd")
	CaptureS = load("res://scripts/pets/capture_system.gd")
	HealthS = load("res://scripts/combat/health.gd")
	StatusS = load("res://scripts/combat/status_effects.gd")
	CreatureS = load("res://scripts/creatures/creature.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_capture09] FAIL %s" % what)
	else:
		print("[t_capture09] ok %s" % what)

func _run() -> void:
	_test_window()
	_test_chance_uses_actual_hp()
	_test_dot_guard_uses_window()
	await _test_hint_once()
	_finish()

func _finish() -> void:
	if _host and is_instance_valid(_host):
		_host.queue_free()
	if _fails.is_empty():
		print("[t_capture09] PASS")
		quit(0)
	else:
		print("[t_capture09] FAIL count=%d" % _fails.size())
		quit(1)

## A bare wild animal with only what the rule reads: def, health, statuses.
## FOODTORPOR: torpor defaults to full, so this file keeps checking spec 09's "weak" half; the
## torpor half is checked in _test_window and t_foodtorpor.
func _creature(species: StringName, hp_frac: float, stunned: bool = false, torpor_frac: float = 1.0):
	var cr = CreatureS.new()
	cr.def = (get_root().get_node("Data") as Node).creature(species)
	cr.health = HealthS.new()
	cr.health.setup(cr.def.hp)
	cr.add_child(cr.health)
	cr.statuses = StatusS.new()
	cr.add_child(cr.statuses)
	cr.health.hp = cr.def.hp * hp_frac
	cr.torpor = cr.torpor_max() * torpor_frac
	cr.is_capturable = true
	if stunned:
		cr.statuses.apply(&"knockdown")
	return cr

# ------------------------------------------------------------------ the window

func _test_window() -> void:
	var name := &"velociraptor"
	var stunned_80 = _creature(name, 0.80, true)
	_expect(FieldTameS.capture_window(stunned_80), "stunned at 80 %% HP is capturable (spec 09)")
	_expect(FieldTameS.can_attempt(stunned_80), "feeding tame opens on a stunned animal at 80 %% HP")
	stunned_80.free()

	var at_30 = _creature(name, 0.30, false)
	_expect(FieldTameS.capture_window(at_30), "unstunned at exactly 30 %% HP is capturable (<=, not <)")
	_expect(FieldTameS.can_attempt(at_30), "feeding tame opens at exactly 30 %% HP")
	at_30.free()

	var at_31 = _creature(name, 0.31, false)
	_expect(not FieldTameS.capture_window(at_31), "unstunned at 31 %% HP is not capturable")
	_expect(not FieldTameS.can_attempt(at_31), "feeding tame stays shut at 31 %% HP")
	at_31.free()

	var dead = _creature(name, 0.0, true)
	_expect(not FieldTameS.capture_window(dead), "a dead animal is not capturable, stunned or not")
	dead.free()

	var pet = _creature(name, 0.80, true)
	pet.is_pet = true
	_expect(not FieldTameS.capture_window(pet), "a pet is not capturable")
	pet.free()

	var untameable = _creature(&"allosaurus", 0.10, true)
	_expect(not FieldTameS.capture_window(untameable), "a non-tameable species is not capturable")
	untameable.free()

	var sober = _creature(name, 0.20, true, 0.59)
	_expect(not FieldTameS.capture_window(sober), "FOODTORPOR: stunned at 20 %% HP with torpor 59 %% (< 60 %%) is not capturable")
	sober.torpor = sober.torpor_max() * 0.60
	_expect(FieldTameS.capture_window(sober), "FOODTORPOR: the same animal at exactly 60 %% torpor is")
	sober.free()

	var nulled = FieldTameS.capture_window(null)
	_expect(not nulled, "no creature is not capturable")

# ------------------------------------------------------------------ chance

## Spec 09: the chance uses ACTUAL current HP, never a substituted 30 %.
func _test_chance_uses_actual_hp() -> void:
	var high = _creature(&"velociraptor", 0.80, true)
	var low = _creature(&"velociraptor", 0.20, true)
	for tier in [1, 2, 5]:
		var p_high: float = CaptureS.chance_for(high, tier)
		var p_low: float = CaptureS.chance_for(low, tier)
		_expect(p_high < p_low, "net tier %d: chance at 80 %% (%.2f) < chance at 20 %% (%.2f)" % [tier, p_high, p_low])
	# The formula shape is unchanged from the 30 % era; only the gate moved.
	_expect(is_equal_approx(CaptureS.chance_for(low, 1), clampf(0.35 * (1.5 - 0.20), 0.05, 0.90)), "chance formula is base x (1.5 - hp_fraction)")
	print("[t_capture09] chance high=%.2f low=%.2f" % [CaptureS.chance_for(high, 1), CaptureS.chance_for(low, 1)])
	# attempt() itself refuses above the window and accepts a stunned 80 % animal.
	_host = Node3D.new()
	_host.name = "TCapture09"
	get_root().add_child(_host)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_host.add_child(player)
	_player = player
	await process_frame
	var data: Node = get_root().get_node("Data")
	data.set_survival_unlocked(&"capture_technique_II", true)
	var net = (load("res://scripts/items/item_stack.gd") as GDScript).make(&"capture_net_ii", 1)
	player.inventory.add(net)
	var wild = _creature(&"velociraptor", 0.80, true)
	wild.genetics = (load("res://scripts/creatures/creature_genetics.gd") as GDScript).neutral()
	_expect(CaptureS.attempt(player, wild, 1), "attempt() nets a stunned animal at 80 %% HP")
	data.set_survival_unlocked(&"capture_technique_II", false)
	high.free()
	low.free()

# ------------------------------------------------------------------ DoT guard

func _test_dot_guard_uses_window() -> void:
	var cr = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	cr.def = (get_root().get_node("Data") as Node).creature(&"velociraptor")
	cr.health = HealthS.new()
	cr.health.setup(100.0)
	cr.add_child(cr.health)
	cr.statuses = StatusS.new()
	cr.add_child(cr.statuses)
	cr.statuses.apply(&"bleeding_target")
	var inst = cr.statuses.instances()[0]
	cr.health.hp = 80.0
	cr.statuses._dot(inst)
	_expect(cr.health.hp < 80.0, "bleed still hurts an unstunned 80 %% animal")
	cr.health.hp = 80.0
	cr.statuses.apply(&"knockdown")
	cr.statuses._dot(inst)
	_expect(is_equal_approx(cr.health.hp, 80.0), "bleed stops on a stunned 80 %% animal (never force damage in the window)")
	cr.free()

# ------------------------------------------------------------------ hint

## A real scene creature: the hint path reads health and statuses on a body in the tree.
func _spawn(host, species: StringName, hp_frac: float, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	var data: Node = get_root().get_node("Data")
	c.spawn(data.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.hp = c.health.max_hp * hp_frac
	return c

## At <= 50 % HP an unstunned animal gets one "stun it" hint, once per creature.
func _test_hint_once() -> void:
	var host = _host
	var player = _player
	await physics_frame
	player.global_position = Vector3(0, 0.9, 0)
	var hunting = _spawn(host, &"velociraptor", 0.40, player.global_position + Vector3(0, 0, -1.6))
	await physics_frame
	player.hunt.auto = false
	player.hunt.start(hunting)
	player.hunt.last_notice = ""
	for _i in 8:
		await process_frame
	_expect(player.hunt.last_notice == HINT, "the 50 %% hint says '%s' (got '%s')" % [HINT, player.hunt.last_notice])
	player.hunt.last_notice = ""
	for _i in 8:
		await process_frame
	_expect(player.hunt.last_notice == "", "the hint fires once per creature (got '%s')" % player.hunt.last_notice)
	# Above 50 % there is nothing to say.
	var fresh = _spawn(host, &"velociraptor", 0.60, player.global_position + Vector3(0, 0, -1.6))
	await physics_frame
	player.hunt.start(fresh)
	player.hunt.last_notice = ""
	for _i in 8:
		await process_frame
	_expect(player.hunt.last_notice == "", "no hint above 50 %% HP (got '%s')" % player.hunt.last_notice)
	hunting.free()
	fresh.free()
	player.hunt.stop()

# ------------------------------------------------------------------ watchdog

func _check_watchdog() -> bool:
	return Time.get_ticks_msec() * 0.001 - _t0 < WATCHDOG_S
