extends SceneTree
## PINFEEL (owner 2026-10-30): "pinned should force the player/animal in the lying down animation or something like
## that. It would be cool if the trex or whatever physically pinned the target with a foot".
##  1. Pinned puts a survivor down (knockdown, then the struggling `pinned` loop) and an animal in its knockdown
##     pose, and neither can move while it lasts; an animal pinned is not opened for capture.
##  2. A T. rex stomp that lands Pinned plays pin_foot: the claws (PinHold.foot_point) end within FOOT_TOL of the
##     survivor's chest (Spine2), the foot up off the ground on her; a bite never pins.
##  3. When Pinned runs out on its timer the rex lets go (idle), the survivor stands and walks again.
## Usage: godot --headless --path game --script res://tests/t_pinfeel.gd  -> "[t_pinfeel] PASS"

const FOOT_TOL := 0.45  # m: toes on a lying survivor's chest (Spine2 is inside the body, ~0.16 m up)

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var CA: GDScript
var PH: GDScript

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
		print("[t_pinfeel] FAIL %s" % msg)
	else:
		print("[t_pinfeel] ok %s" % msg)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	data = get_root().get_node("Data")
	CA = load("res://scripts/combat/creature_attack.gd")
	PH = load("res://scripts/combat/pin_hold.gd")
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
	CombatTuning.force_dodge = 0.0
	CombatTuning.force_accuracy = 1.0
	await _test_survivor_pose()
	await _test_animal_pose()
	await _test_rex_foot_pin()
	if failures.is_empty():
		print("[t_pinfeel] PASS")
		quit(0)
	else:
		print("[t_pinfeel] FAIL %d" % failures.size())
		quit(1)

func _player(at: Vector3):
	var p = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.position = at
	host.add_child(p)
	return p

func _creature(id: StringName, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## 1a. Survivor: down, then the struggle loop; tap-to-walk does nothing while it lasts.
func _test_survivor_pose() -> void:
	var p = _player(Vector3(-20, 0.9, 0))
	await _frames(3)
	_expect(p.rig.has_clip(&"pinned") and p.rig.anim_player.get_animation(&"pinned").loop_mode == Animation.LOOP_LINEAR, "survivor has the looping pinned clip")
	p.statuses.apply(&"pinned")
	await _frames(2)
	_expect(p.anim.current_clip == &"knockdown", "Pinned: she goes down first (clip %s)" % p.anim.current_clip)
	var at: Vector3 = p.global_position
	p.nav_to(at + Vector3(6, 0, 0))
	await _frames(int(Engine.physics_ticks_per_second * 1.4))
	_expect(p.anim.current_clip == &"pinned" and p.rig.anim_player.current_animation == &"pinned", "then struggles on her back in the pinned loop (clip %s, playing %s)" % [p.anim.current_clip, p.rig.anim_player.current_animation])
	_expect(_flat(p.global_position - at).length() < 0.05, "she cannot walk while pinned (moved %.2f m)" % _flat(p.global_position - at).length())
	p.anim.on_damaged()
	_expect(p.anim.current_clip == &"pinned", "a hit while pinned does not stand her up into a flinch")
	p.clear_nav()
	p.queue_free()

## 1b. Animal: its knockdown pose for the pin, no capture window, cannot move; stands when the pin ends.
func _test_animal_pose() -> void:
	var c = _creature(&"velociraptor", Vector3(20, 0, 0))
	await _frames(3)
	var pb: AnimationNodeStateMachinePlayback = c.anim.tree.get("parameters/playback")
	c.statuses.apply(&"pinned")
	c.move_to(c.global_position + Vector3(0, 0, 8))
	var at: Vector3 = c.global_position
	await _frames(30)
	_expect(c.anim.current_clip == &"knockdown" and pb.get_current_node() == &"knockdown", "a pinned raptor lies in its knockdown pose (tree at %s)" % pb.get_current_node())
	_expect(not c.anim._can_move() and _flat(c.global_position - at).length() < 0.05, "and does not move (moved %.2f m)" % _flat(c.global_position - at).length())
	_expect(not c.is_capturable, "the pin opens no capture window")
	c.statuses.clear_id(&"pinned")
	await _frames(10)
	_expect(c.anim.current_clip == &"idle" and c.anim._can_move(), "Pinned gone: it gets up (clip %s)" % c.anim.current_clip)
	c.queue_free()

## 2 + 3. T. rex stomp -> pin_foot on the survivor's chest -> released when Pinned runs out.
func _test_rex_foot_pin() -> void:
	var p = _player(Vector3(0, 0.9, 0))
	get_root().get_node("Game").god_mode = true  # the stomp would kill a fresh survivor; the pin is under test
	var rex = _creature(&"tyrannosaurus", Vector3(0, 0, 4.0))  # faces -Z, at the survivor
	await _frames(3)
	_expect(rex.anim.has_state(&"pin_foot"), "the T. rex has a pin_foot state")
	var sk: Skeleton3D = rex.view.rig.skeleton
	var mt := sk.get_bone_global_pose(sk.find_bone("Metatarsal.R"))
	var toe := sk.get_bone_global_pose(sk.find_bone("Toe.R"))
	var along := (toe.origin - mt.origin).normalized().dot(mt.basis.y.normalized())
	_expect(along > 0.99, "bone +Y runs along the bone (PinHold.TOE_REACH relies on it): %.3f" % along)
	# fairness: a bite does not pin, only the telegraphed stomp does
	CA._apply_token(&"pinned", &"attack_primary", p, rex)
	_expect(not p.statuses.has(&"pinned") and rex.pin_victim == null, "a T. rex bite does not pin")
	var landed: bool = CA.apply_for(rex, &"attack_heavy", p)
	_expect(landed and p.statuses.has(&"pinned"), "the stomp lands Pinned")
	_expect(rex.pin_victim == p and rex.anim.current_clip == &"pin_foot", "the T. rex plants a foot on her (clip %s)" % rex.anim.current_clip)
	await _frames(int(Engine.physics_ticks_per_second * 1.6))
	var foot: Vector3 = PH.foot_point(rex)
	var chest: Vector3 = PH.chest_point(p)
	var pb: AnimationNodeStateMachinePlayback = rex.anim.tree.get("parameters/playback")
	_expect(pb.get_current_node() == &"pin_foot", "the tree holds pin_foot (%s)" % pb.get_current_node())
	_expect(foot.distance_to(chest) <= FOOT_TOL, "the claws are on her chest: %.2f m apart (tolerance %.2f), foot %.2f m up" % [foot.distance_to(chest), FOOT_TOL, foot.y])
	_expect(foot.y > chest.y and foot.y > 0.2, "the foot is up on her, not on the ground (%.2f m)" % foot.y)
	_expect(p.anim.current_clip == &"pinned", "she struggles under the foot (clip %s)" % p.anim.current_clip)
	var rex_at: Vector3 = rex.global_position
	var left: float = p.statuses.get_instance(&"pinned").time_left
	await _frames(int(Engine.physics_ticks_per_second * (left + 0.4)))
	_expect(not p.statuses.has(&"pinned"), "Pinned ran out on its timer")
	_expect(rex.pin_victim == null and not rex.anim.is_pinning() and rex.anim.current_clip == &"idle", "the T. rex lets go (clip %s)" % rex.anim.current_clip)
	_expect(_flat(rex.global_position - rex_at).length() < 0.05, "the T. rex held still through the pin")
	_expect(p.anim.current_clip != &"pinned" and p.anim.current_clip != &"knockdown" and p.statuses.can_act(), "she stands up and can act (clip %s)" % p.anim.current_clip)
	var at: Vector3 = p.global_position
	p.nav_to(at + Vector3(-6, 0, 0))
	await _frames(30)
	_expect(_flat(p.global_position - at).length() > 0.3, "and walks again (moved %.2f m)" % _flat(p.global_position - at).length())
	rex.queue_free()
	p.queue_free()
