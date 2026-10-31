extends SceneTree
## STUN COOLDOWN (owner 2026-10-31: "the hurt animation shouldn't stunlock, stun should be on a cooldown (maybe you can
## stun every 3s or so?)"). A medium animal hit every frame for 7 s is staggered (and plays hit_react) at most once per
## Creature.STAGGER_COOLDOWN_S; hits between still do damage.
## Run: Godot --headless --path game --script res://tests/t_stuncd.gd  -> "[t_stuncd] PASS", exit 0.

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_stuncd] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	data = root.get_node("Data")
	host = Node3D.new()
	root.add_child(host)
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = Vector3(0, 0.1, 0)
	host.add_child(c)
	c.spawn(data.creature(&"pachycephalosaurus"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.max_hp = 1000000.0
	c.health.hp = 1000000.0
	await physics_frame
	var cd: float = c.STAGGER_COOLDOWN_S
	var starts: Array[float] = []
	var t0 := Time.get_ticks_msec() * 0.001
	var was := false
	var hp0: float = c.health.hp
	while Time.get_ticks_msec() * 0.001 - t0 < 7.0:
		c.health.take_damage(1.0, null)
		var now: bool = c.stagger_left > 0.0
		if now and not was:
			starts.append(Time.get_ticks_msec() * 0.001 - t0)
		was = now
		await physics_frame
	_expect(c.health.hp < hp0, "hits between staggers still do damage")
	_expect(starts.size() >= 2, "it is staggered again once the cooldown is over (%d staggers)" % starts.size())
	var ok := true
	for i in range(1, starts.size()):
		ok = ok and starts[i] - starts[i - 1] >= cd - 0.05
	_expect(ok, "at most one stagger per %.1f s (starts %s)" % [cd, str(starts)])
	if failures.is_empty():
		print("[t_stuncd] PASS")
		quit(0)
	else:
		print("[t_stuncd] FAIL %d" % failures.size())
		quit(1)
