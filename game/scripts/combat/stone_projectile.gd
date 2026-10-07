class_name StoneProjectile
extends Node3D
## Straight visible shot. Segment ray prevents tunneling; no homing or area damage.
var source: Player
var weapon: ItemStack
var direction := Vector3.FORWARD
var damage := 0.0
var skill_level := 0
var range_left := 12.0
const SPEED := 18.0

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
	var distance := minf(range_left, SPEED * delta)
	var end := global_position + direction * distance
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
	if randf() < victim.dodge_chance():
		victim.combat_float.emit(0.0, &"dodge")
		return
	var raw := maxf(damage * 0.05, damage - victim.defense_for(true) * victim.statuses.defense_mult() * 0.5)
	var dealt := raw * (1.0 + 0.01 * skill_level) * CombatCounters.multiplier(victim.def.archetype, &"blunt")
	victim.next_hit_kind = Hunt.effectiveness(victim, &"blunt")
	victim.health.take_damage(dealt, source)
	if source.skills: source.skills.add_xp("ranged", 2)
	source.hunt.apply_counter_hit(weapon, victim)
	if victim.brain is TyrantBrain: (victim.brain as TyrantBrain).blunt_counter()
	print("[ranged] hit %s blunt=%.1f" % [victim.def.id, dealt])
