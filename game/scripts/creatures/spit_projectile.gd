class_name SpitProjectile
extends Node3D
## Dilophosaurus venom spit: a straight glob aimed where the target stood at release. It does
## not home, so a sidestep or a roll dodges it. On contact it lands the spitter's own attack
## (hit roll, damage, venom) through CreatureAttack; a wall or the ground stops it.

## Counters for labs and tests.
static var stats: Dictionary = {"launched": 0, "hit": 0, "dodged": 0, "missed": 0, "last_launch_dist": 0.0}

var source: Creature
var target: Node3D
var clip: StringName = &"attack_heavy"
var hit_radius: float = 0.3
var _vel := Vector3.ZERO
var _left: float = 2.0
var _done := false

static func launch(from: Creature, at: Node3D, speed: float, radius: float, p_clip: StringName) -> SpitProjectile:
	var s := SpitProjectile.new()
	s.name = "Spit"
	s.source = from
	s.target = at
	s.hit_radius = radius
	s.clip = p_clip
	from.get_parent().add_child(s)
	var mouth := from.global_position + Vector3.UP * from.def.height_meters * 0.75 - from.global_basis.z * from.body_radius()
	var aim := at.global_position
	aim.y = MeleeQuery.feet_y(at) + MeleeQuery.body_height(at) * 0.55
	s.global_position = mouth
	var spd := maxf(1.0, speed)
	s._vel = (aim - mouth).normalized() * spd
	s._left = mouth.distance_to(aim) / spd + 0.5  # flies a little past the aim point, then is spent
	s._build()
	stats["launched"] = int(stats["launched"]) + 1
	stats["last_launch_dist"] = Vector2(from.global_position.x - at.global_position.x, from.global_position.z - at.global_position.z).length()
	return s

func _build() -> void:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	sphere.radial_segments = 10
	sphere.rings = 6
	m.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.95, 0.3)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)

func _physics_process(delta: float) -> void:
	if _done:
		return
	var from := global_position
	var to := from + _vel * delta
	if EcoSense.first_blocker(self, from, to, [source, target]) != null:
		_finish("missed")
		return
	global_position = to
	_left -= delta
	if is_instance_valid(target) and MeleeQuery.point_gap(target, global_position) <= hit_radius:
		_resolve()
	elif _left <= 0.0:
		_finish("missed")

func _resolve() -> void:
	if target is Player and (target as Player).rolling:
		_finish("dodged")
		return
	if is_instance_valid(source) and not source.health.dead and CreatureAttack.apply_for(source, clip, target):
		if target is Player:
			(target as Player).receive_creature_hit(source, clip)
		_finish("hit")
		return
	_finish("missed")

func _finish(how: String) -> void:
	_done = true
	stats[how] = int(stats[how]) + 1
	if Game and Game.debug_overlay:
		print("[eco] spit %s" % how)
	queue_free()
