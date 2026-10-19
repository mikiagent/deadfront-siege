class_name Telegraph
extends Node3D
## Yellow ring at the heavy-attack impact. It lives until the attack actually lands plus
## LINGER, so a roll timed on the impact still counts. Deafened hides the ring, never the
## dodge window.

const LINGER := 0.1

static var _active: Array[Telegraph] = []

static func show_for(creature: Creature, clip: StringName) -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	var t := Telegraph.new()
	t.name = "Telegraph"
	creature.get_parent().add_child(t)
	var impact := creature.global_position + -creature.global_transform.basis.z * (2.2 if clip == &"attack_heavy" else 1.2)
	t.global_position = impact
	var radius := 1.8 if clip == &"attack_heavy" else 1.1
	t._build(radius, creature)
	t.visible = not (player and player.statuses.has_flag(&"hide_telegraphs"))
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

static func player_dodged(attacker: Creature) -> bool:
	var player := attacker.get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.rolling:
		return false
	for t in _active:
		if t.attacker == attacker and t.covers(player.global_position):
			return true
	return false

var attacker: Creature
var _radius: float = 1.5
var _life: float = 0.9

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

func _on_attacker_hit(_clip: StringName) -> void:
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
	label.text = "STOMP - ROLL OR GET BEHIND" if clip == &"attack_heavy" else "BITE - ROLL OR GET BEHIND"
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
