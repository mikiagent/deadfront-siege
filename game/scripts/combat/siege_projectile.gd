class_name SiegeProjectile
extends Node3D
## Fixed landing aim, visible arc and radius. Hits geometry on the way; never homes.
var source: Player
var platform: FieldCatapult
var poison := false
var start := Vector3.ZERO
var landing := Vector3.ZERO
var elapsed := 0.0
const FLIGHT := 1.2
var marker: MeshInstance3D

func _ready() -> void:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	sphere.mesh = mesh
	add_child(sphere)
	marker = MeshInstance3D.new()
	marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var tor := TorusMesh.new()
	tor.inner_radius = 1.8
	tor.outer_radius = 2.0
	marker.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.4,1,0.25) if poison else Color(1,0.8,0.2)
	marker.material_override = mat
	get_parent().add_child(marker)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.global_position = landing + Vector3(0,0.1,0)
	marker.reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source):
		queue_free()
		return
	elapsed += delta
	var fraction := clampf(elapsed/FLIGHT,0,1)
	var end := start.lerp(landing,fraction) + Vector3.UP * sin(fraction*PI)*5.0
	var query := PhysicsRayQueryParameters3D.create(global_position,end)
	query.exclude = [source.get_rid()]
	if is_instance_valid(platform): query.exclude.append(platform.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		explode(hit.get("position",end),hit.get("collider") as Creature)
		return
	global_position = end
	if fraction >= 1: explode(end)

func explode(at: Vector3, direct: Creature = null) -> void:
	for node in get_tree().get_nodes_in_group("creatures"):
		var victim := node as Creature
		if victim == null or victim.health.dead or victim.is_pet: continue
		if victim != direct and victim.global_position.distance_to(at) > 2.0: continue
		# Ground burst must still have line of sight to the target, not reach through walls.
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.3,victim.global_position+Vector3.UP)
		if is_instance_valid(platform): query.exclude = [platform.get_rid()]
		var block := get_world_3d().direct_space_state.intersect_ray(query)
		if not block.is_empty() and block.get("collider") != victim: continue
		if poison:
			victim.statuses.apply(&"poisoned_target",source)
			var inst := victim.statuses.get_instance(&"poisoned_target")
			if inst and is_instance_valid(platform): inst.siege_origin = weakref(platform)
		else:
			var damage := maxf(12.0,240.0-victim.defense_for(true)*victim.statuses.defense_mult()*0.5) * CombatCounters.multiplier(victim.def.archetype,&"blunt")
			victim.health.take_damage(damage,platform if is_instance_valid(platform) else source)
			if victim.brain is TyrantBrain: (victim.brain as TyrantBrain).blunt_counter()
		if is_instance_valid(platform): victim.brain.on_aggro(platform)
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(marker): marker.queue_free()
