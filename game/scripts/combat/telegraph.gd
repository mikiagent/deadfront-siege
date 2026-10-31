class_name Telegraph
extends Node3D
## Yellow ring at the heavy-attack impact. It lives until the attack actually lands plus
## LINGER, so a roll timed on the impact still counts. Deafened hides the ring, never the
## dodge window.

const LINGER := 0.1

static var _active: Array[Telegraph] = []

static func show_for(creature: Creature, clip: StringName) -> void:
	var player := PlayerRegistry.local()
	var t := Telegraph.new()
	t.name = "Telegraph"
	creature.get_parent().add_child(t)
	var ahead := 2.2 if clip == &"attack_heavy" else 1.2
	var radius := 1.8 if clip == &"attack_heavy" else 1.1
	if clip == &"bite_combo":  # the MEGA chomp snaps straight ahead, just past the snout
		ahead = creature.body_radius() + 1.0
		radius = 1.4
		# CARNOFEEL tactics.combo_ring_ahead_m: a long snout chomps metres past its chest (the carnotaurus' ~4.5 m)
		var tb := creature.brain as TacticalBrain
		if tb and tb.tac.has("combo_ring_ahead_m"):
			ahead = float(tb.tac["combo_ring_ahead_m"]) * creature.size_scale()
	var impact := creature.global_position + -creature.global_transform.basis.z * ahead
	t.global_position = impact
	t._build(radius, creature)
	t.visible = not (player and player.statuses.has_flag(&"hide_telegraphs"))
	t.clip = clip
	t._life = _clip_seconds(creature, clip) + LINGER  # fallback if the hit never fires
	if creature.anim and not creature.anim.attack_hit.is_connected(t._on_attacker_hit):
		creature.anim.attack_hit.connect(t._on_attacker_hit)
	_active.append(t)

## Live rings for this attacker (combat_rules_lab counts them at the hit frame).
static func live_for(attacker: Creature) -> int:
	var n := 0
	for t in _active:
		if is_instance_valid(t) and t.attacker == attacker and t._life > 0.0:
			n += 1
	return n

static func _clip_seconds(creature: Creature, clip: StringName) -> float:
	var ap := creature.anim.player if creature.anim else null
	return ap.get_animation(clip).length if ap and ap.has_animation(clip) else 0.6

## True when the survivor is inside this attacker's live ring and her roll is still in its opening
## window (RollRules): the ring tells her when to press, the window is what actually dodges.
static func player_dodged(attacker: Creature) -> bool:
	var player := PlayerRegistry.nearest(attacker.global_position)
	if player == null or player.sim == null or not player.sim.roll_invulnerable():
		return false
	for t in _active:
		if t.attacker == attacker and t.covers(player.global_position):
			return true
	return false

var attacker: Creature
var _radius: float = 1.5
var _life: float = 0.9
var clip: StringName  # only this clip's hit ends the ring; a stray hit from another clip does not

func _build(radius: float, who: Creature) -> void:
	attacker = who
	_radius = radius
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.88
	torus.outer_radius = radius
	ring.mesh = torus
	ring.position.y = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _on_attacker_hit(hit_clip: StringName) -> void:
	if hit_clip == clip:
		_life = minf(_life, LINGER)

func covers(pos: Vector3) -> bool:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return d <= _radius

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_active.erase(self)
		queue_free()

## Raid visual information survives deafened; damage is fixed-facing, not a homing cue.
static func show_tyrant(creature: Creature, radius: float, duration: float, clip: StringName) -> Telegraph:
	var t := Telegraph.new()
	creature.get_parent().add_child(t)
	t.global_position = creature.global_position
	t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	t._build(radius,creature)
	t._life = duration + 0.15
	var label := Label3D.new()
	label.text = {&"attack_heavy": "STOMP - ROLL OR GET BEHIND", &"tail_swipe": "TAIL - ROLL OR GET CLEAR",
			&"bite_shake": "BITE & SHAKE - ROLL OR GET BEHIND", &"alert": "ROAR - GET CLEAR"}.get(clip, "BITE - ROLL OR GET BEHIND")
	label.position.y = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	t.add_child(label)
	_active.append(t)
	return t

func _exit_tree() -> void:
	_active.erase(self)
	if is_instance_valid(attacker) and attacker.anim and attacker.anim.attack_hit.is_connected(_on_attacker_hit):
		attacker.anim.attack_hit.disconnect(_on_attacker_hit)

## TACTICS pounce: a ring on the prey for the windup and the leap (the brain moves it with the prey until
## take-off). Rolling inside it at the hit time is a dodge (player_dodged), like the heavy ring.
static func show_pounce(creature: Creature, at: Vector3, radius: float, duration: float, text: String = "POUNCE - ROLL!") -> Telegraph:
	var t := Telegraph.new()
	t.name = "PounceTelegraph"
	creature.get_parent().add_child(t)
	t.global_position = at
	t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	t._build(radius, creature)
	t.clip = &"pounce"
	t._life = duration + LINGER
	var player := PlayerRegistry.local()
	t.visible = not (player and player.statuses.has_flag(&"hide_telegraphs"))
	var label := Label3D.new()
	label.text = text
	label.position.y = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	t.add_child(label)
	_active.append(t)
	return t

## ANKYLOAI club moves: a ring where the tail club will pass, with the move's name, for the whole wind-up and strike
## window. Rolling inside it at the strike is a dodge (player_dodged), like the heavy ring. Survives deafened (the
## tyrant's rule: the swing is fixed, not a homing cue).
static func show_club(creature: Creature, at: Vector3, radius: float, duration: float, text: String) -> Telegraph:
	var t := Telegraph.new()
	t.name = "ClubTelegraph"
	creature.get_parent().add_child(t)
	t.global_position = Vector3(at.x, creature.global_position.y, at.z)
	t.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	t._build(radius, creature)
	t.clip = &"club"
	t._life = duration + LINGER
	var label := Label3D.new()
	label.text = text
	label.position.y = 2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	t.add_child(label)
	_active.append(t)
	return t
