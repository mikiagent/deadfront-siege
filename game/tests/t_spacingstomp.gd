extends SceneTree
## SPACING STOMP: the overhanging theropods' stomp.
##  - every species in SPECIES loads the spacing_stomp clip and builds a SpacingStomp; an animal without the clip has none;
##  - live, for a TacticalBrain theropod (ceratosaurus, spinosaurus) and a TyrantBrain one (tyrannosaurus, megarex): with
##    the survivor tucked under the chest, it stomps within about 1 s, the slam shakes the ground, she is knocked down and
##    ends at the bite's jaw reach (from its attack_primary hitbox) +-0.3 m, and the follow-up bite lands on her;
##  - she is not stomped when she already stands at bite reach.
## Run: Godot --headless --path game --script res://tests/t_spacingstomp.gd  -> "[t_spacingstomp] PASS", exit 0.

const SPECIES: Array[StringName] = [&"tyrannosaurus", &"megarex", &"allosaurus", &"majungasaurus", &"ceratosaurus", &"tarbosaurus", &"spinosaurus", &"carnotaurus"]
const LIVE: Array[StringName] = [&"ceratosaurus", &"tyrannosaurus", &"megarex", &"allosaurus", &"majungasaurus", &"tarbosaurus", &"spinosaurus", &"carnotaurus"]
const REACH_TOL := 0.3
const PlayerKnock_FALL := 2  ## PlayerKnock.Phase.FALL
const PlayerKnock_LIE := 3  ## PlayerKnock.Phase.LIE

var failures: Array[String] = []
var _started := false
var data: Node
var SS: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	SS = load("res://scripts/combat/spacing_stomp.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_spacingstomp] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	for id in LIVE:
		await _test_live(id)
	await _test_roster()
	if failures.is_empty():
		print("[t_spacingstomp] PASS")
		quit(0)
	else:
		print("[t_spacingstomp] FAIL %d" % failures.size())
		quit(1)

func _arena() -> Array:
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.vitals.max_health = 100000.0
	player.vitals.health = 100000.0
	return [host, player]

func _spawn(host: Node3D, id: StringName, at: Vector3, face: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	c.look_at(face, Vector3.UP)
	return c

func _test_roster() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var i := 0
	for id in SPECIES:
		var c = _spawn(host, id, Vector3(-80 + 22 * i, 0.1, 80), Vector3(-80 + 22 * i, 0.1, 0))
		i += 1
		await physics_frame
		_expect(c.anim.has_state(&"spacing_stomp") and c.brain.spacing != null, "%s has the spacing stomp" % id)
	var raptor = _spawn(host, &"velociraptor", Vector3(60, 0.1, -60), Vector3(0, 0.1, 0))
	await physics_frame
	_expect(raptor.brain.spacing == null, "a velociraptor (no overhang, no clip) has none")
	host.free()

func _test_live(id: StringName) -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _spawn(host, id, Vector3(0, 0.1, -20), Vector3(0, 0.1, 0))
	for _f in 3:
		await physics_frame
	var b = c.brain
	var st = b.spacing
	if st == null:
		_expect(false, "%s has a spacing stomp" % id)
		host.free()
		return
	c.remove_meta(&"thero_roar_at")
	c.set_meta(&"thero_roar_at", Time.get_ticks_msec() * 0.001)  # no roar in the way: the stomp is under test
	var fwd: Vector3 = -c.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	if b.stomp != null:
		b.stomp.cd = 999.0  # BIGSTOMP ticks first and owns its ring when ready; the spacing stomp is under test here
	var reach: float = st.bite_reach(player)
	# tucked under the chest: a third of the way out to the jaws
	player.global_position = c.global_position + fwd * reach * 0.35 + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._set_state(&"attack" if b.state != &"attack" else b.state)
	var t := 0.0
	var started_at := -1.0
	var knocked := false
	var shook := 0.0
	var after := 0.0
	root.get_node("Game").god_mode = true  # every hit and reaction lands, no damage: she lives through the throw
	var hit_follow := -1.0
	var frame_at := Transform3D()
	var lay := false
	var o_follow := Vector2(INF, 0)
	var hp_follow := -1.0
	while t < 6.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if started_at < 0.0 and st.stomps > 0:
			started_at = t
		shook = maxf(shook, st.last_shake)
		knocked = knocked or player.statuses.has(&"knockdown") or player.sim.knock.active()
		if st.phase == &"after" and frame_at == Transform3D():
			frame_at = c.global_transform  # the body where the foot came down: her landing is judged from it
		var kp: int = player.sim.knock.phase
		if not lay and st.stomps > 0 and (kp == PlayerKnock_FALL or kp == PlayerKnock_LIE):
			var rel: Vector3 = frame_at.affine_inverse() * player.global_position  # where the shove (and a throw's tumble) left her
			o_follow = Vector2(-rel.z, rel.x)
			lay = kp == PlayerKnock_LIE  # the first frame lying is the landing; a grab out of the fall keeps its last one
		if st.followed != &"":
			if hp_follow < 0.0:
				hp_follow = player.vitals.health
				hit_follow = player._last_hit_taken_s
			after += 1.0 / Engine.physics_ticks_per_second
			if after > 2.2:
				break
	_expect(started_at >= 0.0 and started_at <= 1.0, "%s: tucked under the chest, it stomps (after %.2f s)" % [id, started_at])
	_expect(shook > 0.0, "%s: the slam shakes the ground (%.2f)" % [id, shook])
	_expect(knocked, "%s: she is knocked down" % id)
	_expect(absf(o_follow.x - st.last_reach) <= REACH_TOL, "%s: she lands at the bite's reach (%.2f m ahead, lying, jaw reach %.2f m, pushed %.2f m)" % [id, o_follow.x, st.last_reach, st.last_push])
	_expect(st.followed != &"", "%s: the brain follows up with %s" % [id, st.followed])
	_expect(player._last_hit_taken_s > hit_follow, "%s: the follow-up %s lands on her" % [id, st.followed])
	root.get_node("Game").god_mode = false
	# standing at bite reach already: no stomp
	host.free()
	var a2 := await _arena()
	host = a2[0]
	player = a2[1]
	c = _spawn(host, id, Vector3(0, 0.1, -20), Vector3(0, 0.1, 0))
	for _f in 3:
		await physics_frame
	st = c.brain.spacing
	player.global_position = c.global_position + fwd * st.bite_reach(player) + Vector3.UP * 0.1
	_expect(not st.tucked(player), "%s: at bite reach she is not tucked in" % id)
	host.free()
