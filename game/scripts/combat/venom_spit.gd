class_name VenomSpit
extends Node3D
## SP-DILOPHOSAURUS: the dilophosaurus' venom glob. TacticalBrain fires it on the spit clip's hit frame from the
## mouth at where the prey stood (no homing: stepping or rolling out of the ground ring dodges it). It flies a low
## arc at a fixed speed; on arrival it hits the prey if the prey is still within radius of the aim point, through
## CreatureAttack with the clip &"spit" (so a roll in its window, a wall in between and the hit roll all apply, and
## the species' Venom rides on the hit), then splashes.

signal landed(hit: bool)

const SPLASH_S := 0.5

var shooter: Creature
var target: Node3D
var mult := 1.0
var radius := 1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _len := 0.4
var _t := 0.0
var _arc := 0.3
var _done := false
var _glob: MeshInstance3D

static func fire(p_shooter: Creature, p_target: Node3D, from: Vector3, to: Vector3, speed: float, p_mult: float, p_radius: float) -> VenomSpit:
	var s := VenomSpit.new()
	s.name = "VenomSpit"
	s.shooter = p_shooter
	s.target = p_target
	s.mult = p_mult
	s.radius = p_radius
	s._from = from
	s._to = to
	s._len = maxf(0.12, from.distance_to(to) / maxf(1.0, speed))
	s._arc = 0.06 * from.distance_to(to)
	s.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p_shooter.get_parent().add_child(s)
	s.global_position = from
	return s

## Seconds the glob flies (the brain keeps the ring up until it lands).
func flight_s() -> float:
	return _len

func _ready() -> void:
	_glob = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	sph.radial_segments = 10
	sph.rings = 5
	_glob.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.85, 0.18)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.75, 0.1)
	mat.emission_energy_multiplier = 1.4
	_glob.material_override = mat
	_glob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glob)
	# two trailing droplets so the glob reads as liquid in flight
	for k in 2:
		var d := MeshInstance3D.new()
		var ds := SphereMesh.new()
		ds.radius = 0.09 - 0.03 * k
		ds.height = ds.radius * 2.0
		ds.radial_segments = 8
		ds.rings = 4
		d.mesh = ds
		d.material_override = mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.position = Vector3(0, 0, 0.28 + 0.22 * k)
		_glob.add_child(d)

func _physics_process(delta: float) -> void:
	if _done:
		_t += delta
		_glob.scale = Vector3.ONE * (1.0 + 4.0 * _t / SPLASH_S) * Vector3(1.0, 0.25, 1.0)
		if _t >= SPLASH_S:
			queue_free()
		return
	_t = minf(_len, _t + delta)
	var f := _t / _len
	var p := _from.lerp(_to, f) + Vector3.UP * _arc * 4.0 * f * (1.0 - f)
	var dir := p - global_position
	global_position = p
	if dir.length_squared() > 1e-6:
		_glob.look_at(global_position + dir, Vector3.UP)
	if _t >= _len:
		_land()

func _land() -> void:
	_done = true
	_t = 0.0
	var hit := false
	if is_instance_valid(target) and is_instance_valid(shooter) and not shooter.health.dead:
		var gap := Vector2(target.global_position.x - _to.x, target.global_position.z - _to.z).length()
		var tr := (target as Creature).body_radius() if target is Creature else 0.35
		if gap <= radius + tr:
			hit = CreatureAttack.apply_for(shooter, &"spit", target, mult)
			if hit and target is Player:
				(target as Player).receive_creature_hit(shooter, &"spit")
		elif target is Player or target is Creature:
			CombatAvoid.avoided(target, shooter, &"dodge")  # she stepped out of the ring
	print("[combat] %s venom spit %s" % [shooter.def.id if is_instance_valid(shooter) else "?", "hit" if hit else "missed"])
	landed.emit(hit)
