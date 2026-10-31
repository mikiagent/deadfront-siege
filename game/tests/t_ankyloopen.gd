extends SceneTree
## ANKYLOOPEN (owner 2026-10-31: "ankylosaurus gets stuck in hold/idle animation when the player initially attacks"). A calm,
## unprovoked ankylosaurus at the lab's spawn distance (8 m), facing her, side-on and tail-on; the survivor walks up with the
## lab's auto-attack (punch, auto kick / tackle) and opens on it. From her first hit that lands:
## - within REACT_S it reacts: it turns, moves or starts a move (not stood in idle or hold);
## - within ATTACK_S it starts an attack (a close move, a tail move or a joust run; a pivot or about-face does not count).
## Run: Godot --headless --path game --script res://tests/t_ankyloopen.gd  -> "[t_ankyloopen] PASS", exit 0.

const ID := &"ankylosaurus"
## ASSUMPTION (coordinator, owner's report): "within about 1 s of the first hit it turns or engages, within about 3 s it attacks".
const REACT_S := 1.0
const ATTACK_S := 3.0
const SPAWN_M := 8.0  ## lab_spawn_panel SPAWN_AHEAD_M
const DT := 1.0 / 60.0

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player: Node3D
var _watch := 0.0

func _process(delta: float) -> bool:
	if _started:
		_watch += delta
		if _watch > 240.0:
			print("[t_ankyloopen] FAIL watchdog")
			quit(1)
		return false
	if root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_ankyloopen] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").god_mode = true
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	host = Node3D.new()
	host.name = "TAnkyloOpenHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	player = kit["player"]
	for i in 10:
		await physics_frame
	for facing in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0]:  # its yaw away from her: 0 = head on, 180 = tail to her
		await _open(facing)
	root.get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_ankyloopen] PASS")
		quit(0)
	else:
		print("[t_ankyloopen] FAIL %d" % failures.size())
		quit(1)

func _open(facing: float) -> void:
	player.global_position = Vector3(0, player.global_position.y, 0)
	player.velocity = Vector3.ZERO
	player.sim.knock.cancel()
	player.statuses.clear_all()
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0, -SPAWN_M)
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, 0, -SPAWN_M) + Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(facing)) * 5.0, Vector3.UP)
	await physics_frame
	var b = c.brain
	var piv: Dictionary = b.get(&"pivots") if b.get(&"pivots") is Dictionary else {}
	var first := [-1.0]
	var t := 0.0
	var now := [0.0]  # a lambda captures locals by value: the clock goes through an array
	c.health.damaged.connect(func(_a: float, src: Node) -> void:
		if src == player and first[0] < 0.0:
			first[0] = now[0])
	player.hunt.start(c)
	player.hunt.auto = true
	var yaw0: float = c.rotation.y
	var pos0: Vector3 = c.global_position
	var react := -1.0
	var attack := -1.0
	var attack_id := &""
	var states := []
	for f in 14 * 60:
		await physics_frame
		t += DT
		now[0] = t
		if player.hunt.target != c:
			player.hunt.start(c)
		if states.is_empty() or states[-1] != str(b.state):
			states.append(str(b.state))
		if first[0] < 0.0:
			yaw0 = c.rotation.y
			pos0 = c.global_position
			continue
		var mid: StringName = b.move_id
		var jp: StringName = b.get(&"joust_phase") if b.get(&"joust_phase") != null else &""
		var turned := absf(angle_difference(c.rotation.y, yaw0)) > deg_to_rad(10.0)
		var moved: bool = (c.global_position - pos0).length() > 0.3
		if react < 0.0 and (mid != &"" or jp != &"" or turned or moved):
			react = t - first[0]
		var attacking: bool = jp == &"run" or (mid != &"" and not piv.has(mid) and not str(mid).begins_with("about"))
		if attack < 0.0 and attacking:
			attack = t - first[0]
			attack_id = mid if mid != &"" else &"joust"
		if attack >= 0.0 and react >= 0.0:
			break
		if t - first[0] > 6.0:
			break
	_expect(first[0] >= 0.0, "facing %d: her opening hit lands (at %.2f s)" % [int(facing), first[0]])
	_expect(react >= 0.0 and react <= REACT_S, "facing %d: it reacts within %.1f s of her first hit (%.2f s; states %s)" % [int(facing), REACT_S, react, str(states)])
	_expect(attack >= 0.0 and attack <= ATTACK_S, "facing %d: it starts an attack within %.1f s (%.2f s, %s; states %s, clip %s)" % [int(facing), ATTACK_S, attack, attack_id, str(states), c.anim.current_clip])
	player.hunt.stop()
	player.sim.knock.cancel()
	player.statuses.clear_all()
	c.queue_free()
	await physics_frame
	await physics_frame
