class_name Telegraph
extends Node3D
## Yellow ring at the heavy-attack impact. Hidden while the player is deafened.

static var _active: Array[Telegraph] = []

static func show_for(creature: Creature, clip: StringName) -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	if player and player.statuses.has_flag(&"hide_telegraphs"):
		return
	var t := Telegraph.new()
	t.name = "Telegraph"
	creature.get_parent().add_child(t)
	var impact := creature.global_position + -creature.global_transform.basis.z * (2.2 if clip == &"attack_heavy" else 1.2)
	t.global_position = impact
	var radius := 1.8 if clip == &"attack_heavy" else 1.1
	t._build(radius, creature)
	_active.append(t)

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
	var decal := Decal.new()
	decal.size = Vector3(radius * 2.0, 3.0, radius * 2.0)
	decal.modulate = Color(1.0, 0.86, 0.15, 0.85)
	add_child(decal)
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
	add_child(ring)

func covers(pos: Vector3) -> bool:
	var d := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
	return d <= _radius

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_active.erase(self)
		queue_free()
