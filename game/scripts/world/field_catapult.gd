class_name FieldCatapult
extends StaticBody3D
## Manual siege platform. Spends ammunition and can be destroyed by retaliating creatures.
var kind: StringName = &"catapult"
var persist_building := true
var build_cell := Vector2i.ZERO
var build_rot := 0
var hp := 200.0
var reload_left := 0.0
var operator: Player

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("catapult")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0,1.2,2.0)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	for spec in [[Vector3(2.0,0.25,2.0),Vector3(0,0.25,0)],[Vector3(0.25,1.5,0.25),Vector3(-0.7,1.0,0)],[Vector3(0.25,1.5,0.25),Vector3(0.7,1.0,0)],[Vector3(0.2,0.2,2.4),Vector3(0,1.4,0)]]:
		var mesh := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = spec[0]
		mesh.mesh = b
		mesh.position = spec[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4,0.25,0.12)
		mesh.material_override = mat
		add_child(mesh)
	for x in [-0.85,0.85]:
		for z in [-0.65,0.65]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.35
			cylinder.bottom_radius = 0.35
			cylinder.height = 0.18
			wheel.mesh = cylinder
			wheel.rotation.z = PI/2
			wheel.position = Vector3(x,0.35,z)
			add_child(wheel)
	var label := Label3D.new()
	label.name = "Label"
	label.position.y = 2.0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 8
	add_child(label)

func _physics_process(delta: float) -> void:
	reload_left = maxf(0, reload_left-delta)
	var label := get_node_or_null("Label") as Label3D
	if label:
		var text := "Catapult %.0f/200%s" % [hp, " Reload%d" % ceili(reload_left) if reload_left > 0 else ""]
		if label.text != text: label.text = text

func receive_siege_hit(amount: float) -> void:
	hp = maxf(0,hp-amount)
	if hp <= 0:
		queue_free()

func fire(player: Player, victim: Creature, poison: bool = false) -> bool:
	if hp <= 0 or is_queued_for_deletion() or reload_left > 0 or not is_instance_valid(player) or World.runtime == null or player.dead or player.rolling or player.anim._busy or player.statuses.has_flag(&"cannot_act") or not is_instance_valid(victim) or victim.health.dead or victim.is_pet: return false
	if not World.runtime.is_ancestor_of(victim) or not World.runtime.is_ancestor_of(player): return false
	if player.global_position.distance_to(global_position) > 3.0: return false
	var aim := victim.global_position
	var gap := Vector2(aim.x-global_position.x,aim.z-global_position.z).length()
	if gap < 8 or gap > 24: return false
	var ammo := &"toxin_pot" if poison else &"stone_shot"
	if not player.inventory.consume(ammo,1): return false
	operator = player
	player.hunt.hold = true
	player.hunt.auto = false
	player.clear_nav()
	reload_left = 3.0
	var shell := SiegeProjectile.new()
	shell.source = player
	shell.platform = self
	shell.poison = poison
	shell.start = global_position + Vector3(0,1.5,0)
	shell.landing = aim
	World.runtime.add_child(shell)
	shell.global_position = shell.start
	shell.reset_physics_interpolation()
	# Firing advertises the platform, even when the projectile misses.
	victim.brain.on_siege_fire(self)
	return true

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot,4)
	rotation.y = build_rot * PI/2

func _exit_tree() -> void:
	if World.runtime and World.runtime.get("build_grid") is BuildGrid:
		(World.runtime.get("build_grid") as BuildGrid).release(self)

func to_dict() -> Dictionary:
	return {"kind":"catapult","cell":[build_cell.x,build_cell.y],"rot":build_rot,"hp":hp,"reload_left":reload_left}

static func from_dict(row: Dictionary) -> FieldCatapult:
	var result := FieldCatapult.new()
	var cell: Array = row.get("cell",[0,0])
	if cell.size() >= 2: result.build_cell = Vector2i(int(cell[0]),int(cell[1]))
	result.build_rot = posmod(int(row.get("rot",0)),4)
	result.hp = clampf(float(row.get("hp",200)),0,200)
	result.reload_left = clampf(float(row.get("reload_left",0)),0,3)
	return result
