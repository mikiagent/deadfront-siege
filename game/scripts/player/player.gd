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
const GATHER_FATIGUE_PER_UNIT := 1.5 / 4.0 # ASSUMPTION: per-unit fatigue is one quarter of legacy per-gather cost.
const HOLD_WALK_DELAY := 0.25
const HOLD_WALK_RETARGET := 0.15
const TAP_PICK_RADIUS := 0.6

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
var _corpse_slot: int = -1
var _ctx_cd: float = 0.0
var tame_target: Creature
var tame_food_id: StringName = &""
var nav_active: bool = false
var _path_points: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.ZERO
var _path_replan_left: float = 0.0
var _path_anchor: Vector3 = Vector3.ZERO
var _path_blocked_left: float = 0.0
var ui: InventoryUI
var craft_ui
var in_water: bool = false
var _wet_acc: float = 0.0

var _roll_left: float = 0.0
var _gather_left: float = 0.0
var _gathering: bool = false
var _gather_unit_time: float = 1.0
var _gather_ring
var _gather_radial: GatherRadial
var _right_hand_anchor: Marker3D
var _hips_anchor: Marker3D
var _mount_hips_offset: Vector3 = Vector3.ZERO
var _mount_saved_parent: Node
var _ground_marker: MeshInstance3D
var _hold_walk_candidate: bool = false
var _hold_walk_elapsed: float = 0.0
var _hold_walk_retarget_left: float = 0.0
var _touch_context: StringName = &"explore"
var _shoreline_logged: bool = false
var _lantern: OmniLight3D
var _lantern_phase: float = randf() * TAU
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
	_setup_lantern()
	_setup_ground_marker()
	_setup_gather_ring()
	_setup_gather_radial()
	vitals.damaged.connect(_on_vitals_damaged)
	vitals.died.connect(_on_vitals_died)
	if has_node("Shape"):
		pass

func nav_to(pos: Vector3) -> void:
	if nav_active and _path_goal.distance_to(pos) <= 0.3:
		return
	nav_active = true
	_path_goal = pos
	_path_replan_left = 0.0
	_path_anchor = global_position
	_path_blocked_left = 0.0
	if _use_tile_path():
		_request_tile_path()
	else:
		agent.target_position = pos

func clear_nav() -> void:
	nav_active = false
	_path_points = PackedVector3Array()
	_path_index = 0
	agent.target_position = global_position

func face_world(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		visual.rotation.y = atan2(-to.x, -to.z)  # RiggedModel faces -Z; yaw so -Z points at the target

func receive_creature_hit(_who: Creature, _clip: StringName) -> void:
	_cancel_gather_and_butcher()
	vitals.add_fatigue(2.0, &"combat")
	if anim:
		if statuses and statuses.has_flag(&"knockdown"):
			anim.play_clip(&"knockdown")
		else:
			anim.on_damaged()

func _physics_process(delta: float) -> void:
	_fall_guard()
	_tick_hold_walk(delta)
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
		_sync_touch_context()
		return
	if statuses.has_flag(&"cannot_act"):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if anim:
			anim._physics_tick(0.0)
		_sync_touch_context()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.0:
		clear_nav()
		_clear_ground_marker()
		_cancel_gather_and_butcher()
	var dir := _cam_dir(input)
	var can_sprint := Input.is_action_pressed("sprint") and not statuses.has_flag(&"no_sprint")
	var target_speed := sprint_speed if can_sprint else walk_speed
	target_speed *= statuses.move_mult()
	if vitals.exhausted:
		target_speed *= 0.7
	if nav_active:
		if _use_tile_path():
			var next_dir := _tile_nav_dir(delta)
			if next_dir.length_squared() > 0.0:
				dir = next_dir
			else:
				nav_active = false
				_on_arrived()
				dir = Vector3.ZERO
		elif not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var to := next - global_position
			to.y = 0.0
			if to.length_squared() > 0.0001:
				dir = to.normalized()
		else:
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
		if tame_target and is_instance_valid(tame_target):
			_update_tame_ring(1.0 - (_gather_left / maxf(0.001, _gather_unit_time)))
		else:
			_update_gather_ring(1.0 - (_gather_left / maxf(0.001, _gather_unit_time)))
		if _gather_left <= 0.0:
			if tame_target and is_instance_valid(tame_target):
				_finish_tame_feed()
			else:
				_finish_gather()
	move_and_slide()
	_shoreline_guard()
	_drive_lantern()
	if anim:
		var spd := Vector2(velocity.x, velocity.z).length()
		anim._physics_tick(spd)
	_sync_touch_context()

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
	if placer and placer.placing != &"":
		if event.is_action_pressed("place_rotate"):
			placer.rotate_clockwise()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("place_confirm"):
			placer.confirm(self)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("place_cancel"):
			placer.cancel()
			get_viewport().set_input_as_handled()
			return
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
			if _tap_blocked():
				_hold_walk_candidate = false
				return
			placer.tap_ground()
			_hold_walk_candidate = false
			get_viewport().set_input_as_handled()
			return
		if _tap_blocked():
			_hold_walk_candidate = false
			return
		if _gather_radial and _gather_radial.is_open():
			_gather_radial.close()  # tap outside the hexes dismisses the radial; the tap still acts
		var tap_kind := _tap_world()
		_hold_walk_candidate = tap_kind == &"ground"
		_hold_walk_elapsed = 0.0
		_hold_walk_retarget_left = 0.0

func _tap_blocked() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return true
	if TouchControls.enabled and TouchControls.blocks_screen_point(Game.pointer):
		return true
	return false

func _tap_world() -> StringName:
	var hit := _ray()
	if hit.is_empty():
		return &""
	var picked := _pick_interactable(hit)
	if picked != null:
		_interact_tap_target(picked)
		return &"interact"
	var tile := BuildGrid.tile_of(hit.position)
	var tile_center := BuildGrid.tile_centre(tile, World.runtime)
	var nav_pos := _closest_nav_point(tile_center)
	var marker_tile := BuildGrid.tile_of(nav_pos)
	var marker_pos := BuildGrid.tile_centre(marker_tile, World.runtime)
	_cancel_gather_and_butcher()
	if hunt:
		hunt.stop()
	nav_to(nav_pos)
	_show_ground_marker(marker_pos)
	return &"ground"

func _interact_tap_target(col: Object) -> void:
	_clear_ground_marker()
	_cancel_gather_and_butcher()
	if not (col is Creature and not (col as Creature).is_pet) and hunt:
		hunt.stop()
	if col is HarvestNode:
		var hn := col as HarvestNode
		var opts := hn.options()
		if opts.size() > 1 and _gather_radial:
			_gather_radial.open(hn, opts, inventory)
		else:
			if opts.size() == 1:
				hn.select_option(0)
			_begin_gather(hn)
	elif col is Corpse:
		(col as Corpse).note_tapped()
		_open_corpse_radial(col as Corpse)
	elif col is Creature:
		var c := col as Creature
		c.note_tapped()
		if Game and Game.has_method("reveal_creature_plate"):
			Game.reveal_creature_plate(c, 3.0)
		if c.is_pet:
			_pet_interact(c)
		elif FieldTame.can_attempt(c):
			_begin_field_tame(c)
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

func _pick_interactable(hit: Dictionary) -> Object:
	var ray_col: Object = hit.get("collider", null)
	if _is_interactable(ray_col):
		return ray_col
	var at: Vector3 = hit.get("position", global_position)
	var query := PhysicsShapeQueryParameters3D.new()
	var bubble := SphereShape3D.new()
	bubble.radius = TAP_PICK_RADIUS
	query.shape = bubble
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var results := get_world_3d().direct_space_state.intersect_shape(query, 16)
	var best: Object = null
	var best_d := 9999.0
	for row in results:
		var col: Object = row.get("collider", null)
		if not _is_interactable(col):
			continue
		var n := col as Node3D
		if n == null:
			continue
		var d := n.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = col
	return best

func _is_interactable(col: Object) -> bool:
	if col is HarvestNode or col is Corpse or col is Creature or col is Bonfire or col is TamingPen:
		return true
	if col is Node:
		var n := col as Node
		return n.is_in_group("harbour") or n.is_in_group("cargo_warp") or n.is_in_group("placed_building")
	return false

func _closest_nav_point(pos: Vector3) -> Vector3:
	if _use_tile_path():
		var tile := BuildGrid.tile_of(pos)
		return BuildGrid.tile_centre(tile, World.runtime)
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return pos
	return NavigationServer3D.map_get_closest_point(map, pos)

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
	_stop_gather_cycle(false)
	butcher_target = null
	gather_target = node
	nav_to(_closest_nav_point(node.global_position))

func _begin_butcher(corpse: Corpse) -> void:
	if vitals.exhausted:
		print("[item] too exhausted to butcher")
		return
	var why := corpse.can_butcher(inventory)
	if why == "empty":
		print("[item] refused butcher %s: %s" % [corpse.species, why])
		return
	var tool := inventory.find_gather_tool(&"knife")
	if tool and why == "":
		print("[item] auto-equip %s knife" % tool.def_id)
	_stop_gather_cycle(false)
	gather_target = null
	tame_target = null
	tame_food_id = &""
	butcher_target = corpse
	nav_to(_closest_nav_point(corpse.global_position))

func _begin_field_tame(creature: Creature) -> void:
	if not FieldTame.can_attempt(creature):
		return
	var food := FieldTame.food_in_bag(inventory, creature)
	if food == &"":
		print("[tame] refused: %s" % FieldTame.refuse_message(creature))
		return
	if hunt:
		hunt.stop()
	_stop_gather_cycle(false)
	gather_target = null
	butcher_target = null
	tame_target = creature
	tame_food_id = food
	nav_to(_closest_nav_point(creature.global_position))

func _on_arrived() -> void:
	_clear_ground_marker()
	if gather_target and is_instance_valid(gather_target):
		face_world(gather_target.global_position)
		var why := gather_target.can_gather(inventory)
		if why != "":
			print("[item] refused %s: %s" % [gather_target.node_id, why])
			_stop_gather_cycle()
			gather_target = null
			return
		_start_gather_cycle(gather_target.gather_seconds)
	elif tame_target and is_instance_valid(tame_target):
		face_world(tame_target.global_position)
		_start_tame_feed()
	elif butcher_target and is_instance_valid(butcher_target):
		face_world(butcher_target.global_position)
		if _corpse_slot >= 0:
			_corpse_take_timer(butcher_target, _corpse_slot)
		else:
			butcher_target.open_loot(self)
		butcher_target = null

func _start_tame_feed() -> void:
	if tame_target == null or not is_instance_valid(tame_target):
		_clear_tame_target()
		return
	if not FieldTame.can_attempt(tame_target):
		_clear_tame_target()
		return
	if tame_food_id == &"" or inventory.find_first(tame_food_id) < 0:
		print("[tame] refused: %s" % FieldTame.refuse_message(tame_target))
		_clear_tame_target()
		return
	_gathering = true
	_gather_unit_time = FieldTame.FEED_SECONDS
	_gather_left = _gather_unit_time
	if anim:
		anim.on_gather()
	_update_tame_ring(0.0)

func _finish_tame_feed() -> void:
	_gathering = false
	if tame_target == null or not is_instance_valid(tame_target):
		_clear_tame_target()
		return
	var food := tame_food_id
	if food == &"":
		food = FieldTame.food_in_bag(inventory, tame_target)
	FieldTame.apply_feed(self, tame_target, food)
	_clear_tame_target()

func _clear_tame_target() -> void:
	tame_target = null
	tame_food_id = &""
	_stop_gather_cycle()

func _update_tame_ring(progress: float) -> void:
	if _gather_ring == null:
		return
	if tame_target and is_instance_valid(tame_target):
		if _gather_ring.has_method("show_for_tame"):
			_gather_ring.show_for_tame(tame_target, progress, tame_food_id)
		else:
			_gather_ring.fade_out()
	else:
		_gather_ring.fade_out()

func _finish_gather() -> void:
	_gathering = false
	if gather_target == null or not is_instance_valid(gather_target):
		_stop_gather_cycle()
		return
	var why := gather_target.can_gather(inventory)
	if why != "":
		print("[item] refused %s: %s" % [gather_target.node_id, why])
		_stop_gather_cycle()
		gather_target = null
		return
	if gather_target.required_tool_class != &"" and gather_target.required_tool_class != &"none":
		var tool_ok := inventory.wear_gather_tool(gather_target.required_tool_class)
		if not tool_ok:
			_stop_gather_cycle()
			gather_target = null
			return
	var stack := gather_target.roll_yield()
	var attrs := stack.attributes.duplicate(true)
	var before := stack.count
	var left := inventory.add(stack)
	var gained := before - left
	if gained <= 0:
		print("[item] refused %s: inventory_full" % gather_target.node_id)
		_stop_gather_cycle()
		gather_target = null
		return
	if left > 0:
		stack.count = gained
	gather_target.consume_unit()
	print("[item] +%d %s %s (pool %d/%d)" % [gained, stack.def_id, attrs, gather_target.pool_units_left(), gather_target.pool_max])
	World.add_xp(1)
	toast(stack.def_id, gained)
	vitals.add_fatigue(GATHER_FATIGUE_PER_UNIT, &"gather")
	if gather_target.pool_units_left() <= 0:
		_stop_gather_cycle()
		gather_target = null
		return
	_start_gather_cycle(gather_target.gather_seconds)

func _start_gather_cycle(seconds: float) -> void:
	_gathering = true
	_gather_unit_time = maxf(0.1, seconds)
	_gather_left = _gather_unit_time
	if anim:
		anim.on_gather()
	_update_gather_ring(0.0)

func _stop_gather_cycle(fade_ring: bool = true) -> void:
	_gathering = false
	_gather_left = 0.0
	if _gather_ring:
		if fade_ring:
			_gather_ring.fade_out()
		else:
			_gather_ring.clear_now()

func _update_gather_ring(progress: float) -> void:
	if _gather_ring == null:
		return
	if gather_target and is_instance_valid(gather_target):
		_gather_ring.show_for(gather_target, progress)
	else:
		_gather_ring.fade_out()

func _cancel_gather_and_butcher() -> void:
	gather_target = null
	butcher_target = null
	tame_target = null
	tame_food_id = &""
	_stop_gather_cycle()

func _setup_ground_marker() -> void:
	_ground_marker = MeshInstance3D.new()
	_ground_marker.name = "GroundMarker"
	_ground_marker.top_level = true
	_ground_marker.visible = false
	var tile := PlaneMesh.new()
	tile.size = Vector2(1.0, 1.0)
	_ground_marker.mesh = tile
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.85, 0.55, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground_marker.material_override = mat
	add_child(_ground_marker)

func _show_ground_marker(at: Vector3) -> void:
	if _ground_marker == null:
		return
	_ground_marker.global_position = at + Vector3(0.0, 0.05, 0.0)
	_ground_marker.visible = true

func _clear_ground_marker() -> void:
	if _ground_marker:
		_ground_marker.visible = false

func _setup_gather_ring() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 56
	layer.name = "GatherRingLayer"
	add_child(layer)
	var script := load("res://scripts/ui/gather_ring.gd") as GDScript
	if script:
		_gather_ring = script.new()
		layer.add_child(_gather_ring)

func _tick_hold_walk(delta: float) -> void:
	if not Input.is_action_pressed("tap"):
		_hold_walk_candidate = false
		_hold_walk_elapsed = 0.0
		return
	if not _hold_walk_candidate:
		return
	_hold_walk_elapsed += delta
	if _hold_walk_elapsed < HOLD_WALK_DELAY:
		return
	_hold_walk_retarget_left -= delta
	if _hold_walk_retarget_left > 0.0:
		return
	_hold_walk_retarget_left = HOLD_WALK_RETARGET
	_retarget_hold_walk()

func _retarget_hold_walk() -> void:
	if _tap_blocked():
		return
	var hit := _ray()
	if hit.is_empty():
		return
	var col: Object = hit.get("collider", null)
	if _is_interactable(col):
		return
	var tile := BuildGrid.tile_of(hit.position)
	var tile_center := BuildGrid.tile_centre(tile, World.runtime)
	var nav_pos := _closest_nav_point(tile_center)
	_cancel_gather_and_butcher()
	nav_to(nav_pos)
	_show_ground_marker(BuildGrid.tile_centre(BuildGrid.tile_of(nav_pos), World.runtime))

func _use_tile_path() -> bool:
	return World.runtime != null and World.runtime.get("pathing") != null and get_parent() == World.runtime

func _request_tile_path() -> void:
	if not _use_tile_path():
		return
	var p: Variant = World.runtime.get("pathing")
	if p == null:
		return
	_path_points = p.path(global_position, _path_goal, 96)
	_path_index = 0
	if _path_points.size() > 1 and _path_points[0].distance_to(global_position) <= 0.25:
		_path_index = 1

func _tile_nav_dir(delta: float) -> Vector3:
	_path_replan_left -= delta
	if _path_points.is_empty() or _path_replan_left <= 0.0:
		_request_tile_path()
		_path_replan_left = 0.5
	if _path_points.is_empty():
		return Vector3.ZERO
	while _path_index < _path_points.size():
		var next := _path_points[_path_index]
		var to := next - global_position
		to.y = 0.0
		if to.length() <= 0.25:
			_path_index += 1
			continue
		_track_tile_blocked(delta)
		return to.normalized()
	return Vector3.ZERO

func _track_tile_blocked(delta: float) -> void:
	if global_position.distance_to(_path_anchor) > 0.06:
		_path_anchor = global_position
		_path_blocked_left = 0.0
		return
	_path_blocked_left += delta
	if _path_blocked_left >= 0.35:
		_request_tile_path()
		_path_blocked_left = 0.0
		_path_anchor = global_position

func _sync_touch_context() -> void:
	if TouchControls == null:
		return
	var want := _derive_touch_context()
	if want != _touch_context:
		_touch_context = want
		TouchControls.set_context(_touch_context)
	TouchControls.set_hurt_overlay(_has_bleed_status())

func _derive_touch_context() -> StringName:
	if placer and placer.placing != &"":
		return &"place"
	if mounted_on and is_instance_valid(mounted_on):
		return &"mounted"
	if hunt and hunt.target and is_instance_valid(hunt.target):
		return &"hunt"
	return &"explore"

func _has_bleed_status() -> bool:
	return statuses != null and (statuses.has(&"bleed") or statuses.has(&"deep_bleed"))

func debug_tap_screen(screen_pos: Vector2) -> StringName:
	Game.pointer = screen_pos
	return _tap_world()

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
		ui.show_storage(b.storage, self)
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
	q.exclude = [self]
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
	_cancel_gather_and_butcher()
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

func _shoreline_guard() -> void:
	if World.runtime == null or not World.runtime.has_method("surface_y"):
		return
	if World.runtime.surface_y(global_position.x, global_position.z) >= -0.40:
		return  # ankle-deep wading is fine (reference); deeper is blocked
	var out := Vector2(global_position.x, global_position.z)
	if out.length_squared() < 0.0001:
		out = Vector2(0.0, 1.0)
	var inward := -out.normalized()
	global_position.x += inward.x * 0.55
	global_position.z += inward.y * 0.55
	velocity.x = 0.0
	velocity.z = 0.0
	if not _shoreline_logged and Game.debug_overlay:
		_shoreline_logged = true
		print("[world] shoreline blocked")

func _setup_lantern() -> void:
	_lantern = OmniLight3D.new()
	_lantern.name = "HipLantern"
	_lantern.omni_range = 10.0
	_lantern.omni_attenuation = 1.6
	_lantern.light_color = Color(1.0, 0.82, 0.55)
	_lantern.light_energy = 0.0
	_lantern.shadow_enabled = false
	var anchor := hips_anchor()
	if anchor:
		anchor.add_child(_lantern)
		_lantern.position = Vector3.ZERO
	else:
		add_child(_lantern)
		_lantern.position = Vector3(0.0, 0.9, 0.0)

func _drive_lantern() -> void:
	if _lantern == null:
		return
	var anchor := hips_anchor()
	if anchor and _lantern.get_parent() != anchor:
		_lantern.reparent(anchor)
		_lantern.position = Vector3.ZERO
	var from_noon := absf(Game.time_of_day - 0.5) * 2.0
	var night := smoothstep(0.35, 1.0, from_noon)
	var flicker := 1.0 + sin((Time.get_ticks_msec() * 0.001) * 7.0 + _lantern_phase) * 0.05
	_lantern.light_energy = 4.0 * night * flicker


func _setup_gather_radial() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GatherRadialLayer"
	layer.layer = 55
	add_child(layer)
	_gather_radial = GatherRadial.new()
	_gather_radial.name = "GatherRadial"
	layer.add_child(_gather_radial)
	_gather_radial.picked.connect(_on_gather_option_picked)

func _on_gather_option_picked(anchor: Node3D, index: int) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	if anchor is Corpse:
		var opts := (anchor as Corpse).loot_options(inventory)
		if index < opts.size():
			_begin_corpse_take(anchor as Corpse, int(opts[index]["slot"]))
		return
	if not (anchor is HarvestNode):
		return
	var node := anchor as HarvestNode
	node.select_option(index)
	print("[item] option %s x%d-%d %.1fs" % [node.yield_def_id, node.yield_min, node.yield_max, node.gather_seconds])
	_begin_gather(node)

## Lab/test helper: open the radial on a node as a tap would.
func debug_open_radial(node: HarvestNode) -> void:
	if node and _gather_radial:
		_gather_radial.open(node, node.options(), inventory)

func display_name() -> String:
	var meta := _survivor_meta()
	return str(meta.get("display_name", "Survivor"))

# ---------------------------------------------------------------- corpse radial

func _open_corpse_radial(corpse: Corpse) -> void:
	if corpse == null or _gather_radial == null:
		return
	var opts := corpse.loot_options(inventory)
	if opts.is_empty():
		print("[item] refused butcher %s: empty" % corpse.species)
		return
	_gather_radial.open_options(corpse, "%s Corpse" % corpse.species_display_name(), corpse.level, 1.0, opts, inventory)

func _begin_corpse_take(corpse: Corpse, slot: int) -> void:
	if vitals.exhausted:
		print("[item] too exhausted to butcher")
		return
	_stop_gather_cycle(false)
	gather_target = null
	tame_target = null
	tame_food_id = &""
	butcher_target = corpse
	_corpse_slot = slot
	nav_to(_closest_nav_point(corpse.global_position))

func _corpse_take_timer(corpse: Corpse, slot: int) -> void:
	_corpse_slot = -1
	if anim:
		anim.on_gather()
	vitals.add_fatigue(1.0, &"gather")
	var t := get_tree().create_timer(1.6)
	t.timeout.connect(func () -> void:
		if corpse == null or not is_instance_valid(corpse):
			return
		var st := corpse.take_slot(slot, self)
		if st == null:
			return
		var before := st.count
		var left := inventory.add(st)
		print("[item] +%d %s (loot %s)" % [before - left, st.def_id, corpse.species])
		World.add_xp(2)
		toast(st.def_id, before - left)
	)

# ---------------------------------------------------------------- toasts + context actions (HUD)

func toast(id: StringName, n: int) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("toast"):
		hud.toast(id, n)

## Context hexes shown by the HUD, bottom-right (reference: drink/wash by water, cook at the fire…).
func context_actions() -> Array:
	var out: Array = []
	if mounted_on:
		out.append({"id": "dismount", "glyph": "⤓", "label": "Dismount"})
		return out
	var near_water := in_water
	if not near_water and World.runtime and World.runtime.has_method("surface_y"):
		near_water = World.runtime.surface_y(global_position.x, global_position.z) < 0.15
	if near_water:
		out.append({"id": "drink", "glyph": "💧", "label": "Drink"})
		out.append({"id": "wash", "glyph": "🫧", "label": "Wash"})
	var fire := _nearest_group("bonfire")
	if fire and global_position.distance_to(fire.global_position) < 2.8:
		out.append({"id": "cook", "glyph": "🍖", "label": "Cook"})
		if statuses and (statuses.has(&"bleed") or statuses.has(&"deep_bleed")):
			out.append({"id": "cauterise", "glyph": "🔥", "label": "Cauterise"})
	var corpse := _nearest_group("corpse")
	if corpse and global_position.distance_to(corpse.global_position) < 3.0:
		out.append({"id": "loot", "glyph": "🎒", "label": "Loot"})
	var harbour := _nearest_group("harbour")
	if harbour and global_position.distance_to(harbour.global_position) < 5.0:
		out.append({"id": "harbour", "glyph": "⚓", "label": "Harbour"})
	var warp := _nearest_group("cargo_warp")
	if warp and global_position.distance_to(warp.global_position) < 2.8:
		out.append({"id": "warp", "glyph": "📦", "label": "Cargo warp"})
	var pen := _nearest_group("taming_pen")
	if pen and global_position.distance_to(pen.global_position) < 3.0:
		out.append({"id": "pen", "glyph": "🪤", "label": "Pen"})
	return out

func context_action(id: String) -> void:
	match id:
		"dismount":
			dismount()
		"drink":
			# ASSUMPTION: a drink restores 5 energy; wash clears 2 fatigue (no dirty status yet).
			vitals.energy = minf(vitals.max_energy, vitals.energy + 5.0)
			print("[item] drink energy=%.0f" % vitals.energy)
		"wash":
			vitals.rest(2.0)
			print("[item] wash fatigue=%.0f" % vitals.fatigue)
		"cook":
			if craft_ui:
				craft_ui.toggle()
		"cauterise":
			var fire := _nearest_group("bonfire") as Bonfire
			if fire:
				fire.cauterise(self)
		"loot":
			var corpse := _nearest_group("corpse") as Corpse
			if corpse:
				_open_corpse_radial(corpse)
		"harbour":
			var h := _nearest_group("harbour")
			if h:
				h.open()
		"warp":
			var w := _nearest_group("cargo_warp")
			if w:
				w.use(self)
		"pen":
			var pen := _nearest_group("taming_pen") as TamingPen
			if pen:
				_pen_interact(pen)
