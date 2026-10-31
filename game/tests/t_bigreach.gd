extends SceneTree
## BIGREACH (owner: "im trying to attack the stegosaurus and it wont let me hit it"; "Triceratops has a
## similar problem"). For every modelled species: the survivor against its side, rear and front (HITBOXES:
## touching its visible body, a hurtbox at her height, or held off by its collider within a swing of one)
## swings and the hit lands; FAR_M clear of its footprint the swing is refused. Then auto-attack from 10 m on
## the triceratops and stegosaurus: she walks up to a part she can reach and lands hits.
## Usage: godot --headless --path game --script res://tests/t_bigreach.gd  -> "[t_bigreach] PASS"

const APPROACH_S := 10.0
## HITBOXES: this clear of its footprint nothing she swings reaches it (fist or blade ~1.3 m from her centre).
const FAR_M := 1.5
## Held off by its collider, a hurtbox within this of her body is still in a swing's reach (fist ~0.65 m past her).
const SIDE_GAP_M := 0.45

var failures: Array[String] = []
var _started := false
var host: Node3D
var player
var data: Node
var MQ: GDScript

func _process(_delta: float) -> bool:
	if _started or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_bigreach] %s %s" % ["ok" if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	data = get_root().get_node("Data")
	MQ = load("res://scripts/combat/melee_query.gd")
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(30, 0.9, 30)
	host.add_child(player)
	get_root().get_node("Game").god_mode = true
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	await _frames(5)
	var PANEL = load("res://scripts/dev/lab_spawn_panel.gd")
	for id in PANEL.all_species():
		if CreatureDef.has_model(id):
			await _touch_checks(id)
	for id in [&"triceratops", &"stegosaurus"]:
		for dir in [Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			await _approach(id, dir, false)
		await _approach(id, Vector3.RIGHT, true)  # its AI on: it fights back, turns and moves
	get_root().get_node("Game").god_mode = false
	print("[t_bigreach] %s" % ("PASS" if failures.is_empty() else "FAIL %d" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _spawn(id: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.spawn(data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.setup(1e9)
	return c

## Outward distance from the centre to where her capsule touches the body along dir (local = world here).
## HITBOXES: the visible body is its hurtboxes. Walking in along dir, the first spot where her capsule (feet to
## head) touches a hurtbox, or where the collider stops her. -1 when the collider stops her more than
## SIDE_GAP_M from every hurtbox at her height (as under a T. rex's tail): no swing reaches from there, and
## the auto-attack approach below walks her to a part she can reach.
func _touch_dist(c, dir: Vector3) -> float:
	var floor_d: float = MQ.body_radius(c) + MQ.body_radius(player) + 0.02
	var caps: Array = load("res://scripts/combat/hurtboxes.gd").of(c).world_capsules()
	var r_p: float = MQ.body_radius(player)
	var d := 20.0
	while d > floor_d - 0.001:
		if _gap(c.global_position + dir * d, caps, r_p) <= 0.0:
			return d + 0.02
		d -= 0.02
	return floor_d if _gap(c.global_position + dir * floor_d, caps, r_p) <= SIDE_GAP_M else -1.0

## Her capsule standing at foot to the nearest hurtbox (0 or less: touching).
func _gap(foot: Vector3, caps: Array, r_p: float) -> float:
	var best := INF
	for cap in caps:
		var pts := Geometry3D.get_closest_points_between_segments(foot + Vector3(0, r_p, 0), foot + Vector3(0, 1.78 - r_p, 0), cap[0], cap[1])
		best = minf(best, pts[0].distance_to(pts[1]) - float(cap[2]) - r_p)
	return best

func _place(at: Vector3) -> void:
	player.global_position = Vector3(at.x, 0.9, at.z)
	player.velocity = Vector3.ZERO
	player.clear_nav()

func _touch_checks(id: StringName) -> void:
	var c = _spawn(id)
	await _frames(3)
	var h = player.hunt
	for side in [["side", Vector3.RIGHT], ["rear", Vector3.BACK], ["front", Vector3.FORWARD]]:
		var dir: Vector3 = side[1]
		var d := _touch_dist(c, dir)
		if d < 0.0:
			print("[t_bigreach] skip %s %s: its collider holds her off every part at her height" % [id, side[0]])
			continue
		h.stop()
		_place(dir * d)
		await _frames(2)  # the colliders settle: a capsule wider than the mesh shoves her out
		h.start(c)
		h.auto = false
		h._swing_cd = 0.0
		h._swing_pending = false
		var landed := [0]
		var cb := func(_t): landed[0] += 1
		h.hit_landed.connect(cb)
		var hp: float = c.health.hp
		var started: bool = h.swing_now()
		await create_timer(h.hit_delay(null) + 0.1).timeout
		h.hit_landed.disconnect(cb)
		var hit: bool = started and c.health.hp < hp
		_expect(hit, "%s %s: touching at %.2f m from centre, the swing lands (started %s, gap %.2f)" % [id, side[0], d, started, MQ.surface_gap(player, c)])
		# 1 m past the edge reach: no swing.
		h._swing_cd = 0.0
		h._swing_pending = false
		var far_d := d
		while true:  # out until her body is FAR_M clear of its whole footprint (a raised tail runs past the touch)
			_place(dir * far_d)
			if MQ.surface_gap(player, c) >= FAR_M:
				break
			far_d += 0.1
		await _frames(2)
		var far: bool = h.swing_now()
		_expect(not far, "%s %s: %.1f m clear of its footprint the swing is refused" % [id, side[0], MQ.surface_gap(player, c)])
		h.stop()
		h.auto = true
	c.queue_free()
	await _frames(2)

func _approach(id: StringName, dir: Vector3, live: bool) -> void:
	var c = _spawn(id)
	if live:
		c.brain.process_mode = Node.PROCESS_MODE_INHERIT
		c.brain.attack_target = player
	await _frames(3)
	var h = player.hunt
	_place(dir * (_touch_dist(c, dir) + 10.0))
	await _frames(2)
	var hp: float = c.health.hp
	h.auto = true
	h.auto_ability = false  # the basic swing itself, not a tackle from 2.4 m
	h.hold = false
	var landed := [0]
	var cb := func(_t): landed[0] += 1
	h.hit_landed.connect(cb)
	h.start(c)
	var t := 0.0
	while t < APPROACH_S and landed[0] < 2:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	h.hit_landed.disconnect(cb)
	_expect(landed[0] >= 2 and c.health.hp < hp, "%s%s from 10 m %s: auto-attack walks up and lands %d swings (%.1f s, gap %.2f)" % [id, " (AI on)" if live else "", dir, landed[0], t, MQ.surface_gap(player, c)])
	h.stop()
	h.auto_ability = true
	c.queue_free()
	await _frames(2)
