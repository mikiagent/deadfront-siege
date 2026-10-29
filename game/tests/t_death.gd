extends SceneTree
## EYESDEATH acceptance (owner 2026-10-28: "am still alive at 0 health for a while before You died shows up").
## - the HP text rounds up, so a survivor at 0.4 HP reads 1, never 0 while alive;
## - a hit that takes her to 0 emits Vitals.died in the same frame and marks the Player dead;
## - dead, she neither regenerates nor walks, and the death card is fully up within 1.2 s.
## Usage: godot --headless --path game --script res://tests/t_death.gd -> "[t_death] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D

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
	print("[t_death] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("[t_death] FAIL watchdog")
		quit(1))
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 20.0)
	var player = kit["player"]
	var hud = null
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			hud = c
	_expect(hud != null, "the lab kit has a HuntHud")
	for _i in 5:
		await process_frame
	var v = player.vitals
	var HUD: GDScript = load("res://scripts/ui/hunt_hud.gd")
	v.health = 0.4
	_expect(HUD.hp_label(v).begins_with("1 /"), "0.4 HP reads as 1, not 0 (%s)" % HUD.hp_label(v))
	v.health = 99.2
	_expect(HUD.hp_label(v).begins_with("100 /"), "99.2 HP reads as 100 (%s)" % HUD.hp_label(v))
	# A real hit to 0: died in the same frame.
	v.health = 5.0
	var died_frame := [-1]
	v.died.connect(func() -> void: died_frame[0] = Engine.get_process_frames())
	var hit_frame := Engine.get_process_frames()
	v.take_damage(7.5)
	_expect(died_frame[0] == hit_frame, "died fires in the hit's frame (hit %d, died %d)" % [hit_frame, died_frame[0]])
	_expect(v.dead and player.dead and v.health == 0.0, "the hit leaves her dead at 0 HP")
	_expect(HUD.hp_label(v).begins_with("0 /"), "dead reads 0 (%s)" % HUD.hp_label(v))
	# The card is fully up within 1.2 s; she does not regenerate or move meanwhile.
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	var full_at := -1.0
	var start: Vector3 = player.global_position
	while t < 2.0:
		await process_frame
		t = (Time.get_ticks_msec() - t0) / 1000.0
		if full_at < 0.0 and hud != null and hud.get("_death_alpha") >= 1.0 and hud.get("_death_panel").visible:
			full_at = t
	_expect(full_at >= 0.0 and full_at <= 1.2, "the death card is fully up %.2f s after the hit (<= 1.2 s)" % full_at)
	_expect(v.health == 0.0, "no regen while dead (%.2f HP)" % v.health)
	_expect(Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length() < 0.05,
		"she does not move while dead")
	_host.queue_free()
	await process_frame
	if _fails.is_empty():
		print("[t_death] PASS")
		quit(0)
	else:
		print("[t_death] FAIL count=%d" % _fails.size())
		quit(1)
