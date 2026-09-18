class_name Player
extends CharacterBody3D
## Camera-relative movement plus gather, hunt, inventory, mount and pets.

const SURVIVOR_JSON := "res://data/characters/survivor.json"
const SURVIVOR_BASE_GLB := "res://assets/characters/survivor/survivor.glb"
const SURVIVOR_ANIM_DIR := "res://assets/characters/survivor/anim"
const PLAYER_CLIPS: Array[StringName] = [
	&"idle", &"walk", &"run", &"hit_react", &"death",
	&"attack_primary", &"attack_heavy", &"roll", &"gather", &"knockdown", &"mount_idle",
]

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 8.5
@export var accel: float = 30.0
@export var turn_speed: float = 14.0

@onready var visual: Node3D = $Visual
@onready var rig: RiggedModel = $Visual/Rig
@onready var anim: PlayerAnim = $Anim
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
var butcher_target: Corpse
var nav_active: bool = false
var ui: InventoryUI
var craft_ui
var in_water: bool = false
var _wet_acc: float = 0.0

var _roll_left: float = 0.0
var _gather_left: float = 0.0
var _gathering: bool = false
var _right_hand_anchor: Marker3D
var _hips_anchor: Marker3D
var _mount_hips_offset: Vector3 = Vector3.ZERO
var _mount_saved_parent: Node
var _force_clip_map: Array[StringName] = [
	&"idle", &"walk", &"run", &"attack_primary", &"attack_heavy",
	&"hit_react", &"knockdown", &"death", &"alert",
]

func _ready() -> void:
	if Game.lab_name != "" and get_parent() and get_parent().name == "DefaultPlayfield":
		visible = false
		set_physics_process(false)
		return
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
	_setup_survivor()
	vitals.damaged.connect(_on_vitals_damaged)
	vitals.died.connect(_on_vitals_died)
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
		visual.rotation.y = atan2(-to.x, -to.z)  # RiggedModel faces -Z; yaw so -Z points at the target

func receive_creature_hit(_who: Creature, _clip: StringName) -> void:
	vitals.add_fatigue(2.0, &"combat")
	if anim:
		if statuses and statuses.has_flag(&"knockdown"):
			anim.play_clip(&"knockdown")
		else:
			anim.on_damaged()

func _physics_process(delta: float) -> void:
	_fall_guard()
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
		if anim:
			anim._physics_tick(0.0)
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
		var target_yaw := atan2(-dir.x, -dir.z)  # RiggedModel faces -Z (the old capsule faced +Z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, turn_speed * delta)
		vitals.add_fatigue(delta * (0.8 if can_sprint else 0.25), &"walk")
	vitals.fatigue_gain_mult = 0.5 if _in_coziness() else 1.0
	if in_water:
		_wet_acc += delta
		var need := float(Data.world_rules.get("wet_after_seconds_in_water", 5))
		if _wet_acc >= need:
			statuses.apply(&"wet", null)
	else:
		_wet_acc = 0.0
	if _gathering:
		_gather_left -= delta
		if _gather_left <= 0.0:
			_finish_gather()
	move_and_slide()
	if anim:
		var spd := Vector2(velocity.x, velocity.z).length()
		anim._physics_tick(spd)

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
		if placer.placing != &"":
			placer.cancel()
			return
		if craft_ui:
			craft_ui.toggle()
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
	if event.is_action_pressed("tap"):
		if placer.placing != &"":
			placer.confirm(self)
			get_viewport().set_input_as_handled()
			return
		if _tap_blocked():
			return
		_tap_world()

func _tap_blocked() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return true
	if TouchControls.enabled and TouchControls.blocks_screen_point(Game.pointer):
		return true
	return false

func _tap_world() -> void:
	var hit := _ray()
	if hit.is_empty():
		return
	var col: Object = hit.get("collider")
	if col is HarvestNode:
		_begin_gather(col as HarvestNode)
	elif col is Corpse:
		_begin_butcher(col as Corpse)
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
	elif col is Node and (col as Node).is_in_group("harbour"):
		col.open()
	elif col is Node and (col as Node).is_in_group("cargo_warp"):
		col.use(self)
	elif col is Node and (col as Node).is_in_group("placed_building"):
		_building_interact(col)

func _begin_gather(node: HarvestNode) -> void:
	if vitals.exhausted:
		print("[item] too exhausted to gather")
		return
	if node.required_tool_class != &"" and node.required_tool_class != &"none":
		var tool := inventory.find_gather_tool(node.required_tool_class)
		if tool == null:
			print("[item] refused %s: need tool %s" % [node.node_id, node.required_tool_class])
			return
		print("[item] auto-equip %s %s" % [tool.def_id, node.required_tool_class])
	var why := node.can_gather(inventory)
	if why != "" and why != "depleted":
		print("[item] refused %s: %s" % [node.node_id, why])
		return
	if why == "depleted":
		print("[item] refused %s: depleted" % node.node_id)
		return
	butcher_target = null
	gather_target = node
	_gathering = false
	nav_to(node.global_position)

func _begin_butcher(corpse: Corpse) -> void:
	if vitals.exhausted:
		print("[item] too exhausted to butcher")
		return
	var why := corpse.can_butcher(inventory)
	if why != "":
		print("[item] refused butcher %s: %s" % [corpse.species, why])
		return
	var tool := inventory.find_gather_tool(&"knife")
	if tool:
		print("[item] auto-equip %s knife" % tool.def_id)
	gather_target = null
	butcher_target = corpse
	_gathering = false
	nav_to(corpse.global_position)

func _on_arrived() -> void:
	if gather_target and is_instance_valid(gather_target):
		face_world(gather_target.global_position)
		_gathering = true
		_gather_left = gather_target.gather_seconds
		vitals.add_fatigue(1.5, &"gather")
		if anim:
			anim.on_gather()
	elif butcher_target and is_instance_valid(butcher_target):
		face_world(butcher_target.global_position)
		_gathering = true
		_gather_left = 1.4
		vitals.add_fatigue(2.0, &"gather")
		if anim:
			anim.on_gather()

func _finish_gather() -> void:
	_gathering = false
	if butcher_target and is_instance_valid(butcher_target):
		butcher_target.butcher(self)
		butcher_target = null
		return
	if gather_target == null or not is_instance_valid(gather_target):
		return
	var why := gather_target.can_gather(inventory)
	if why != "":
		print("[item] refused %s: %s" % [gather_target.node_id, why])
		return
	if gather_target.required_tool_class != &"" and gather_target.required_tool_class != &"none":
		inventory.wear_gather_tool(gather_target.required_tool_class)
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
	if anim:
		anim.on_roll()
	print("[combat] roll")

func _try_attack_key() -> void:
	if Game.lab_flat_attack:
		var c := _nearest_creature()
		if c:
			play_attack()
			c.health.take_damage(100.0, self)
			print("[combat] lab F 100 → %s hp=%.0f" % [c.def.id, c.health.hp])
		return
	if hunt.target == null:
		var c := _nearest_creature()
		if c:
			hunt.start(c)

func play_attack(heavy: bool = false) -> void:
	if anim:
		anim.on_attack(heavy)

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
	var corpse := _nearest_group("corpse") as Corpse
	if corpse and global_position.distance_to(corpse.global_position) < 2.8:
		_begin_butcher(corpse)
		return
	var harbour := _nearest_group("harbour")
	if harbour and global_position.distance_to(harbour.global_position) < 4.0:
		harbour.open()
		return
	var warp := _nearest_group("cargo_warp")
	if warp and global_position.distance_to(warp.global_position) < 2.8:
		warp.use(self)
		return
	var basket := _nearest_group("basket")
	if basket and global_position.distance_to(basket.global_position) < 2.8:
		_building_interact(basket)
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
	position = -_mount_hips_offset
	if anim:
		anim.play_clip(&"mount_idle")
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
	if anim:
		anim._physics_tick(0.0)

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

func _building_interact(b: Node) -> void:
	if str(b.get("kind")) == "basket" and b.get("storage") and ui:
		if summoned_pet and is_instance_valid(summoned_pet) and summoned_pet.pet_record and summoned_pet.pet_record.bag:
			_dump_pet_into(b.storage)
		ui.show_storage(b.storage)
		return
	if str(b.get("kind")) == "sign":
		print("[world] sign: %s" % (str(b.get("sign_text")) if str(b.get("sign_text")) != "" else "(blank)"))
		return
	if World.is_home() and Input.is_action_pressed("sprint"):
		b.pack_up(self)

func _dump_pet_into(dest: Inventory) -> void:
	var bag := summoned_pet.pet_record.bag
	for i in bag.slot_count:
		var s := bag.slots[i]
		if s == null:
			continue
		var taken := bag.remove_at(i, s.count)
		if taken:
			dest.add(taken)
	print("[item] pet dumped into basket")

func _in_coziness() -> bool:
	if not is_inside_tree():
		return false
	for n in get_tree().get_nodes_in_group("coziness"):
		var a := n as Area3D
		if a and a.overlaps_body(self):
			return true
	return false

func tick_climate_fatigue(delta: float, climate: String) -> void:
	if vitals == null:
		return
	var clim: Dictionary = Data.world_climates.get(climate, {})
	var resists: Array = clim.get("resist", [])
	if resists.is_empty():
		return
	# ASSUMPTION: unmatched climate resist costs 4 fatigue/min at night/dawn/dusk (PRD §4.4 has no number).
	var phase := Game.phase_name()
	if phase == &"day":
		return
	if "cold_weak" in resists or "heat_weak" in resists:
		vitals.add_fatigue(delta * (4.0 / 60.0), &"climate")

func _ray() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mouse := Game.pointer
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

func _setup_survivor() -> void:
	var meta := _survivor_meta()
	var pipeline: Dictionary = meta.get("pipeline", {})
	var axis := str(pipeline.get("forward_axis", "+Z"))
	var height := float(meta.get("height_meters", 1.72))
	if rig == null:
		print("[player] missing Rig node")
		return
	if not rig.setup(SURVIVOR_BASE_GLB, SURVIVOR_ANIM_DIR, axis, height, "player", true, float(pipeline.get("source_height_m", height))):
		print("[player] survivor GLB missing %s" % SURVIVOR_BASE_GLB)
		return
	_bind_rig_markers()
	if anim:
		anim.setup(self, rig)

func _bind_rig_markers() -> void:
	_right_hand_anchor = _marker_from_socket(rig.hand_socket, "RightHand")
	_hips_anchor = _marker_from_socket(rig.hips_socket, "Hips")
	_mount_hips_offset = Vector3.ZERO
	if _hips_anchor:
		_mount_hips_offset = to_local(_hips_anchor.global_position)

func _marker_from_socket(socket: BoneAttachment3D, fallback_name: String) -> Marker3D:
	if socket == null:
		return null
	for child in socket.get_children():
		if child is Marker3D:
			return child as Marker3D
	var marker := Marker3D.new()
	marker.name = fallback_name
	socket.add_child(marker)
	return marker

func right_hand_anchor() -> Marker3D:
	return _right_hand_anchor

func hips_anchor() -> Marker3D:
	return _hips_anchor

func _survivor_meta() -> Dictionary:
	if not FileAccess.file_exists(SURVIVOR_JSON):
		return {"height_meters": 1.72, "pipeline": {"forward_axis": "+Z"}}
	var f := FileAccess.open(SURVIVOR_JSON, FileAccess.READ)
	if f == null:
		return {"height_meters": 1.72, "pipeline": {"forward_axis": "+Z"}}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {"height_meters": 1.72, "pipeline": {"forward_axis": "+Z"}}

func _on_vitals_damaged() -> void:
	if anim == null:
		return
	if statuses and statuses.has_flag(&"knockdown"):
		anim.play_clip(&"knockdown")
	else:
		anim.on_damaged()

func _on_vitals_died() -> void:
	if anim:
		anim.on_death()

func _fall_guard() -> void:
	# Never let the player fall out of the world: below -15 m, put her back on the surface.
	if global_position.y > -15.0:
		return
	var y := 1.0
	if World.runtime and World.runtime.has_method("surface_y"):
		y = World.runtime.surface_y(global_position.x, global_position.z) + 1.0
	velocity = Vector3.ZERO
	global_position.y = y
	print("[player] fell out of the world; re-seated at y=%.2f" % y)
