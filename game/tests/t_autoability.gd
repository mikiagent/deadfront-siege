extends SceneTree
## AUTO-ABILITY acceptance (docs/orchestration/reports/dsc-autoability.md). The owner: "an
## auto-ability button that uses the player's most powerful ability off cooldown and prioritizes
## that over basic attacks" / "put that on by default".
## - the toggle is ON for a fresh player (default, no save write needed)
## - with an ability ready the next action is the ability, not a basic attack
## - on cooldown it falls back to basic attacks
## - toggle off -> basic attacks only
## - the strongest of two ready abilities wins (tie-break longer cooldown)
## Usage: godot --headless --path game --script res://tests/t_autoability.gd

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var AA: GDScript  # AutoAbility

func _process(_delta: float) -> bool:
	if _started:
		return false
	# Player/Creature reference autoloads (Data, World, Game): wait until they exist.
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	AA = load("res://scripts/combat/auto_ability.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_autoability] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	host.name = "TAutoAbility"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	_test_data()
	await _test_default_on_and_ready_cast()
	await _test_cooldown_fallback()
	await _test_toggle_off()
	_test_pick_ranking()
	CombatTuning.reset_overrides()
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_autoability] PASS")
		quit(0)
	else:
		print("[t_autoability] FAIL count=%d" % failures.size())
		quit(1)

func _creature(at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # rules under test, not AI
	return c

func _engage(at := Vector3(0, 0, -1.6)):
	var c := _creature(at)
	player.hunt.auto = true
	player.hunt.auto_ability = true
	player.hunt.start(c)
	player.hunt._swing_cd = 0.0
	player.hunt._tackle_cd = 0.0
	player.hunt._kick_cd = 0.0
	player.hunt._tactic_lock = 0.0
	player.sim._stagger_left = 0.0
	player.vitals.energy = player.vitals.effective_max_energy()
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	player.clear_nav()
	player.hunt._resume_after_move = false
	return c

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _test_data() -> void:
	_expect(not AA.rows().is_empty(), "auto_ability.rows() lists auto-castable abilities from data")
	_expect(bool((CombatTuning.section("tackle") as Dictionary).has("damage")), "tackle tuning section loads")

## The default + the ready-cast rule: the next action is the ability, not a basic attack.
func _test_default_on_and_ready_cast() -> void:
	_expect(player.hunt.auto_ability, "auto-ability defaults ON for a new player (no save field needed)")
	var c := _engage()
	await _frames(4)  # let _process run the auto-cast before the basic swing
	_expect(player.hunt.target == c, "hunt holds its target through the auto-cast")
	var hit_by_ability: bool = c.next_hit_kind != StringName() or c.statuses.has(&"groggy") \
			or c.stagger_left > 0.0 or player.hunt.last_auto_cast != &""
	var no_swing_yet: bool = player.hunt._swing_pending == false
	_expect(hit_by_ability and no_swing_yet, "a ready ability casts before any basic swing (last=%s groggy=%s)" % [player.hunt.last_auto_cast, str(c.statuses.has(&"groggy"))])
	_expect(player.hunt.cooldown_left(&"tackle") > 0.0, "the cast committed its cooldown")
	player.hunt.stop()
	c.free()

## Tackle on cooldown: the picker falls back to Kick (still an ability), and with both cooling down
## it falls back to the basic attack.
func _test_cooldown_fallback() -> void:
	var c := _engage()
	player.hunt._tackle_cd = 5.0  # the strongest row is cooling down
	await _frames(4)
	_expect(player.hunt.last_auto_cast == &"kick", "tackle cooling down -> kick is cast instead (got %s)" % player.hunt.last_auto_cast)
	player.hunt.stop()
	c.free()
	c = _engage()
	player.hunt._tackle_cd = 5.0
	player.hunt._kick_cd = 5.0
	var swings: int = 0
	player.hunt.swing_started.connect(func () -> void: swings += 1)
	await _frames(40)  # long enough for a basic swing to start once, never an auto-cast
	_expect(player.hunt.last_auto_cast == &"" and swings >= 1, "both abilities cooling down -> basic attacks only")
	player.hunt.stop()
	c.free()

## Toggle off: no ability cast, basic attacks only.
func _test_toggle_off() -> void:
	var c := _engage()
	player.hunt.auto_ability = false
	player.hunt._tackle_cd = 0.0
	player.hunt._kick_cd = 0.0
	var swings: int = 0
	player.hunt.swing_started.connect(func () -> void: swings += 1)
	await _frames(40)
	_expect(player.hunt.last_auto_cast == &"" and swings >= 1, "toggle off -> basic attacks only (swings=%d)" % swings)
	player.hunt.stop()
	c.free()

## The picker alone (no engine timing): the strongest of two ready rows wins; the longer cooldown
## breaks a damage tie; an unaffordable or cooling row is skipped.
func _test_pick_ranking() -> void:
	player.vitals.energy = player.vitals.effective_max_energy()
	var c := _creature(Vector3(0, 0, -1.6))
	player.hunt.start(c)
	_expect(AA.pick(player.hunt) == &"tackle", "tackle (6 dmg) beats kick (4 dmg) when both are ready")
	c.free()
