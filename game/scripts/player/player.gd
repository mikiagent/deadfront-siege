class_name Player
extends CharacterBody3D
## Camera-relative movement plus gather, hunt, inventory, mount and pets.

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var accel: float = 30.0
@export var turn_speed: float = 14.0

@onready var visual: Node3D = $Visual
@onready var agent: NavigationAgent3D = get_node_or_null("Agent")

var inventory: Inventory = Inventory.new(20)
var vitals: Vitals
var statuses: StatusEffects
var hunt: Hunt
var placer: BuildPlacer
var bonded: Array[PetRecord] = []
var summoned_pet: Creature
var mounted_on: Creature
var rolling: bool = false
var gather_target: HarvestNode
var nav_active: bool = false
var ui: InventoryUI

var _roll_left: float = 0.0
var _gather_left: float = 0.0
var _gathering: bool = false
var _mount_saved_parent: Node
var _force_clip_map: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert",
]

func _ready() -> void:
	add_to_group("player")
	if agent == null:
		agent = NavigationAgent3D.new()
		agent.name = "Agent"
		add_child(agent)
	vitals = Vitals.new()
	vitals.name = "Vitals"
	add_child(vitals)
	statuses = StatusEffects.new()
	statuses.name = "StatusEffects"
	add_child(statuses)
	hunt = Hunt.new()
	hunt.name = "Hunt"
	add_child(hunt)
	hunt.setup(self)
	placer = BuildPlacer.new()
	placer.name = "Placer"
	add_child(placer)
	if has_node("Shape"):
		pass

func nav_to(pos: Vector3) -> void:
	nav_active = true
	agent.target_position = pos

func clear_nav() -> void:
	nav_active = false
	agent.target_position = global_position

func face_world(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		visual.rotation.y = atan2(to.x, to.z)

func receive_creature_hit(_who: Creature, _clip: StringName) -> void:
	vitals.add_fatigue(2.0)

func _physics_process(delta: float) -> void:
	if statuses == null or vitals == null:
		move_and_slide()
		return
	if not is_on_floor() and mounted_on == null:
		velocity += get_gravity() * delta
	if _roll_left > 0.0:
		_roll_left -= delta
		if _roll_left <= 0.0:
			rolling = false
	if mounted_on and is_instance_valid(mounted_on):
		_mounted_move(delta)
		return
	if statuses.has_flag(&"cannot_act"):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.0:
		clear_nav()
		gather_target = null
		_gathering = false
	var dir := _cam_dir(input)
	var can_sprint := Input.is_action_pressed("sprint") and not statuses.has_flag(&"no_sprint")
	var target_speed := sprint_speed if can_sprint else walk_speed
	target_speed *= statuses.move_mult()
	if vitals.exhausted:
		target_speed *= 0.7
	if nav_active and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		var to := next - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			dir = to.normalized()
	elif nav_active:
		nav_active = false
		_on_arrived()
		dir = Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(dir * target_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if dir.length_squared() > 0.0:
		var target_yaw := atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)
		vitals.add_fatigue(delta * (0.8 if can_sprint else 0.25))
	if _gathering:
		_gather_left -= delta
		if _gather_left <= 0.0:
			_finish_gather()
	move_and_slide()

func _cam_dir(input: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var dir := Vector3.ZERO
	if cam and input.length_squared() > 0.0:
		var fwd := -cam.global_basis.z
		fwd.y = 0.0
		var right := cam.global_basis.x
		right.y = 0.0
		dir = (right.normalized() * input.x + fwd.normalized() * -input.y).normalized()
	return dir

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if ui:
			ui.visible = not ui.visible
		return
	if event.is_action_pressed("roll"):
		_try_roll()
		return
	if event.is_action_pressed("attack"):
		_try_attack_key()
		return
	if event.is_action_pressed("interact"):
		_interact()
		return
	if event.is_action_pressed("craft"):
		if placer.placing == &"":
			placer.begin(&"makeshift_taming_pen")
		else:
			placer.cancel()
		return
	if event.is_action_pressed("bandage"):
		_use_medicine()
		return
	if event.is_action_pressed("hunt_chase"):
		if hunt:
			hunt.hold = not hunt.hold
		return
	if Game.lab_force_clips:
		for i in 9:
			if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_1 + i:
				_force_clip(i)
				return
	else:
		if event.is_action_pressed("tactic_1"):
			hunt.use_tackle()
		elif event.is_action_pressed("tactic_2"):
			hunt.use_kick()
		elif event.is_action_pressed("tactic_4"):
			hunt.use_net()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if placer.placing != &"":
			placer.confirm(self)
			get_viewport().set_input_as_handled()
			return
		if get_viewport().gui_get_hovered_control() != null:
			return
		_tap_world()

func _tap_world() -> void:
	var hit := _ray()
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	if col is HarvestNode:
		_begin_gather(col as HarvestNode)
	elif col is Creature:
		var c := col as Creature
		if c.is_pet:
			_pet_interact(c)
		else:
			hunt.start(c)
	elif col is Bonfire:
		if global_position.distance_to((col as Node3D).global_position) < 2.5:
			(col as Bonfire).cauterise(self)
	elif col is TamingPen:
		_pen_interact(col as TamingPen)

func _begin_gather(node: HarvestNode) -> void:
	if vitals.exhausted:
		print("[item] too exhausted to gather")
		return
	var why := node.can_gather(inventory)
	if why != "" and why != "depleted":
		print("[item] refused %s: %s" % [node.node_id, why])
		return
	if why == "depleted":
		print("[item] refused %s: depleted" % node.node_id)
		return
	gather_target = node
	_gathering = false
	nav_to(node.global_position)

func _on_arrived() -> void:
	if gather_target and is_instance_valid(gather_target):
		face_world(gather_target.global_position)
		_gathering = true
		_gather_left = gather_target.gather_seconds
		vitals.add_fatigue(1.5)

func _finish_gather() -> void:
	_gathering = false
	if gather_target == null or not is_instance_valid(gather_target):
		return
	var why := gather_target.can_gather(inventory)
	if why != "":
		print("[item] refused %s: %s" % [gather_target.node_id, why])
		return
	var stack := gather_target.roll_yield()
	var attrs := stack.attributes.duplicate(true)
	var before := stack.count
	var left := inventory.add(stack)
	print("[item] +%d %s %s" % [before - left, stack.def_id, attrs])
	gather_target.mark_gathered()
	gather_target = null

func _try_roll() -> void:
	if rolling or statuses.has_flag(&"no_roll") or statuses.has_flag(&"cannot_act"):
		return
	rolling = true
	_roll_left = 0.4
	var fwd := -visual.global_basis.z
	velocity.x = fwd.x * 12.0
	velocity.z = fwd.z * 12.0
	print("[combat] roll")

func _try_attack_key() -> void:
	if Game.lab_flat_attack:
		var c := _nearest_creature()
		if c:
			c.health.take_damage(100.0, self)
			print("[combat] lab F 100 → %s hp=%.0f" % [c.def.id, c.health.hp])
		return
	if hunt.target == null:
		var c := _nearest_creature()
		if c:
			hunt.start(c)

func _force_clip(i: int) -> void:
	var c := _nearest_creature()
	if c == null:
		return
	c.anim.play_clip(_force_clip_map[i], true)

func _nearest_creature() -> Creature:
	var best: Creature = null
	var best_d := 9999.0
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.health.dead:
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best

func _use_medicine() -> void:
	if inventory.consume(&"bandage", 1):
		statuses.clear_id(&"bleed")
		print("[item] used bandage")
		return
	if inventory.consume(&"pressure_dressing", 1):
		statuses.clear_id(&"deep_bleed")
		print("[item] used pressure_dressing")

func _interact() -> void:
	if mounted_on:
		dismount()
		return
	var pen := _nearest_group("taming_pen") as TamingPen
	if pen and global_position.distance_to(pen.global_position) < 3.0:
		_pen_interact(pen)
		return
	var fire := _nearest_group("bonfire") as Bonfire
	if fire and global_position.distance_to(fire.global_position) < 2.5:
		fire.cauterise(self)
		return
	if summoned_pet and is_instance_valid(summoned_pet) and global_position.distance_to(summoned_pet.global_position) < 2.8:
		_pet_interact(summoned_pet)

func _pen_interact(pen: TamingPen) -> void:
	if pen.running:
		pen.feed(self)
	else:
		pen.try_insert(self)

func _pet_interact(c: Creature) -> void:
	if c.pet_record == null:
		return
	if &"mount" in c.pet_record.tamed_role:
		mount(c)
		return
	if ui:
		ui.show_pet_bag(c.pet_record)

func mount(c: Creature) -> void:
	if c.pet_record == null or not (&"mount" in c.pet_record.tamed_role):
		return
	mounted_on = c
	_mount_saved_parent = get_parent()
	reparent(c.view.mount_socket())
	position = Vector3.ZERO
	print("[capture] mounted %s" % c.def.id)

func dismount() -> void:
	if mounted_on == null:
		return
	var pos := mounted_on.global_position + Vector3(1.2, 0, 0)
	var host := _mount_saved_parent if _mount_saved_parent else mounted_on.get_parent()
	reparent(host)
	global_position = pos
	mounted_on = null
	print("[capture] dismounted")

func _mounted_move(delta: float) -> void:
	global_position = mounted_on.view.mount_socket().global_position
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := _cam_dir(input)
	if dir.length_squared() > 0.0:
		var speed := mounted_on.def.move_speed_mps
		mounted_on.velocity.x = dir.x * speed
		mounted_on.velocity.z = dir.z * speed
		mounted_on.face_towards(mounted_on.global_position + dir, delta)
	else:
		mounted_on.velocity.x = 0.0
		mounted_on.velocity.z = 0.0

func bond_from_inventory() -> void:
	var idx := inventory.find_first(&"tamed_animal")
	if idx < 0:
		return
	if bonded.size() >= Data.bonded_cap():
		print("[capture] bonded cap %d" % Data.bonded_cap())
		return
	var stack := inventory.remove_at(idx, 1)
	var species := StringName(str(stack.attributes.get("species", "velociraptor")))
	var def := Data.creature(species)
	var grade := StringName(str(stack.attributes.get("grade", "B")))
	var rec := PetRecord.from_def(def, grade, StringName(str(stack.attributes.get("variant", ""))))
	bonded.append(rec)
	print("[capture] bonded %s grade=%s hp=%.0f atk=%.0f def=%.0f spd=%.0f" % [
		species, grade, rec.hp, rec.attack, rec.defense, rec.speed])

func summon_pet(index: int = 0) -> void:
	if summoned_pet and is_instance_valid(summoned_pet):
		summoned_pet.queue_free()
		summoned_pet = null
		print("[capture] dismissed")
		return
	if bonded.is_empty():
		return
	var rec := bonded[clampi(index, 0, bonded.size() - 1)]
	var def := Data.creature(rec.species)
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	get_parent().add_child(c)
	c.global_position = global_position + Vector3(1.5, 0, 0)
	c.is_pet = true
	c.pet_record = rec
	c.spawn(def, rec.variant)
	c.hunger = rec.hunger
	c.hunger_max = rec.hunger_max
	c.health.max_hp = rec.hp
	c.health.hp = rec.hp
	summoned_pet = c
	rec.summoned = true
	print("[capture] summoned %s hp=%.0f (wild hp=%.0f)" % [def.id, c.health.max_hp, def.hp])

func _ray() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _nearest_group(group: String) -> Node3D:
	var best: Node3D = null
	var best_d := 999.0
	for n in get_tree().get_nodes_in_group(group):
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best
