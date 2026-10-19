class_name StoneProjectile
extends Node3D
## Visible shot on a gravity arc aimed to land on the aim point. Segment ray prevents
## tunneling; no homing or area damage.
var source: Player
var weapon: ItemStack
var velocity := Vector3.FORWARD * SPEED
var damage := 0.0
var skill_level := 0
var range_left := 12.0
const SPEED := 18.0

## Launch velocity at SPEED that drops onto `offset` (lifted by the fall over the flight time).
static func launch_velocity(offset: Vector3) -> Vector3:
	var flight := offset.length() / SPEED
	var g := CombatTuning.num("ranged", "gravity", 9.8)
	return offset / maxf(0.001, flight) + Vector3.UP * 0.5 * g * flight

func _ready() -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9,0.85,0.55)
	visual.material_override = mat
	add_child(visual)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	velocity.y -= CombatTuning.num("ranged", "gravity", 9.8) * delta
	var step := velocity * delta
	var distance := minf(range_left, step.length())
	var end := global_position + step.normalized() * distance
	var query := PhysicsRayQueryParameters3D.create(global_position, end)
	query.exclude = [source.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var victim := hit.get("collider") as Creature
		if victim and not victim.health.dead and not victim.is_pet:
			impact(victim)
		queue_free()
		return
	global_position = end
	range_left -= distance
	if range_left <= 0: queue_free()

func impact(victim: Creature) -> void:
	var dodge := victim.dodge_chance() + victim.statuses.evasion_add() * CombatTuning.top("evasion_add_scale", 0.01)
	if not CombatTuning.roll(CombatTuning.hit_chance(source.statuses.accuracy_mult(), dodge)):
		victim.combat_float.emit(0.0, &"dodge")
		return
	var tune := CombatTuning.section("ranged")
	var raw := maxf(damage * float(tune.get("min_damage_frac", 0.05)), damage - victim.defense_for(true) * victim.statuses.defense_mult() * float(tune.get("defense_factor", 0.5)))
	var dealt := raw * (1.0 + 0.01 * skill_level) * CombatCounters.multiplier(victim.def.archetype, &"blunt")
	victim.next_hit_kind = Hunt.effectiveness(victim, &"blunt")
	victim.health.take_damage(dealt, source)
	if source.skills: source.skills.add_xp("ranged", int(tune.get("xp_per_hit", 2)))
	source.hunt.wear_weapon(weapon)
	source.hunt.apply_counter_hit(weapon, victim)
	if victim.brain is TyrantBrain: (victim.brain as TyrantBrain).blunt_counter()
	print("[ranged] hit %s blunt=%.1f" % [victim.def.id, dealt])
