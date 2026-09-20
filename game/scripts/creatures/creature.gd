class_name Creature
extends CharacterBody3D
## Wild or tamed animal. Stats come from CreatureDef; tames keep the wild block (R2).

signal aggroed(who: Node)
signal captured
signal dismissed
signal combat_float(amount: float, kind: StringName)

var def: CreatureDef
var variant: StringName = &""
var pack_id: int = 0
var is_pet: bool = false
var is_capturable: bool = false
var current_clip: StringName = &"idle"
var brain_state: StringName = &"roam"
var pet_record: PetRecord
var hunger: float = 0.0
var hunger_max: float = 0.0
var level: int = 1
var spawn_tile: Vector2i = Vector2i.ZERO
var spawn_home: Vector3 = Vector3.ZERO
var last_aggro_s: float = -999.0
var last_damaged_s: float = -999.0
var _last_tap_s: float = -999.0
var tame_feeds: float = 0.0
var tame_window_left: float = 0.0
var tame_cooldown_left: float = 0.0
var tame_attempting: bool = false

@onready var agent: NavigationAgent3D = $Agent
@onready var view: CreatureView = $View
@onready var health: Health = $Health
@onready var statuses: StatusEffects = $StatusEffects
@onready var anim: CreatureAnim = $Anim
@onready var shape: CollisionShape3D = $Shape
@onready var label: Label3D = $Label
@onready var ap: AnimationPlayer = $AnimationPlayer
@onready var at: AnimationTree = $AnimationTree

var brain: CreatureBrain
var _fx_drip: GPUParticles3D
var _trail_origin: Vector3
var _last_bleed_pos: Vector3
var _path_points: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.ZERO
var _path_active: bool = false
var _path_replan_left: float = 0.0
var _path_blocked_left: float = 0.0
var _path_anchor: Vector3 = Vector3.ZERO

func spawn(p_def: CreatureDef, p_variant: StringName = &"", p_pack: int = 0) -> void:
	def = p_def
	variant = p_variant
	pack_id = p_pack
	add_to_group("creatures")
	view.setup(def, variant)
	_set_vis_range(view, 26.0)
	health.setup(def.hp)
	health.healed.connect(_on_healed)
	# ASSUMPTION: pet hunger budget is 0.4 * wild HP when JSON has no hunger field.
	hunger_max = def.hp * 0.4
	hunger = hunger_max
	level = _spawn_level_from_ring()
	spawn_tile = BuildGrid.tile_of(global_position)
	spawn_home = BuildGrid.tile_centre(spawn_tile, World.runtime if World else null)
	_size_collision()
	var clip_player := view.animation_player()
	if clip_player == null:
		CreatureClips.attach(ap, view, def)
		clip_player = ap
	anim.setup(clip_player, at)
	anim.attack_windup.connect(_on_windup)
	anim.attack_hit.connect(_on_hit)
	anim.attack_done.connect(_on_attack_done)
	anim.knockdown_started.connect(_on_kd_start)
	anim.knockdown_ended.connect(_on_kd_end)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	statuses.removed.connect(_on_status_removed)
	_make_brain()
	_make_drip()
	if Game and Game.has_method("ensure_creature_plates"):
		Game.ensure_creature_plates()
	print("[creature] %s spawned pack=%s" % [def.id, pack_id])

func on_anim_event(kind: String, clip: String) -> void:
	anim.on_event(kind, clip)

func move_to(world_pos: Vector3) -> void:
	if _path_active and _use_tile_path() and _path_goal.distance_to(world_pos) <= 0.25:
		return
	_path_goal = world_pos
	_path_active = true
	_path_replan_left = 0.0
	_path_blocked_left = 0.0
	_path_anchor = global_position
	if not _use_tile_path():
		agent.target_position = world_pos

func stop_move() -> void:
	_path_active = false
	_path_points = PackedVector3Array()
	_path_index = 0
	agent.target_position = global_position

func face_towards(world_pos: Vector3, _delta: float) -> void:
	var p := world_pos
	p.y = global_position.y
	if p.distance_squared_to(global_position) < 0.0001:
		return
	var to := (p - global_position).normalized()
	var target_yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, _delta * 10.0))

func apply_species_on_hit(clip: StringName, target: Node) -> void:
	CreatureAttack.apply_for(self, clip, target)

func capturable() -> bool:
	return is_capturable and health.hp > 0.0 and def.tameable

func field_tame_open() -> bool:
	return FieldTame.can_attempt(self)

func become_pet(rec: PetRecord) -> void:
	is_pet = true
	pet_record = rec
	hunger = rec.hunger
	hunger_max = rec.hunger_max
	tame_attempting = false
	tame_feeds = 0.0
	tame_window_left = 0.0
	if brain:
		brain.queue_free()
		brain = null
	_make_brain()

func _physics_process(delta: float) -> void:
	_fall_guard()
	FieldTame.tick(self, delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if health.dead or statuses.has(&"knockdown") or statuses.has_flag(&"cannot_act"):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_label()
		return
	var speed := def.move_speed_mps * statuses.move_mult()
	if not is_pet and brain and (brain.state == &"approach" or brain.state == &"attack"):
		# ASSUMPTION: wild animals chase at 70 % of their listed speed so a survivor can outrun them.
		speed *= float(brain.profile.get("chase_speed_mult", 0.7)) if brain.get("profile") != null else 0.7
	if is_pet and hunger <= 0.0:
		speed *= 0.85
	var locomote := Vector3.ZERO
	if _path_active:
		if _use_tile_path():
			locomote = _tile_path_direction(delta)
		elif not agent.is_navigation_finished():
			var next := agent.get_next_path_position()
			var to := next - global_position
			to.y = 0.0
			if to.length_squared() > 0.0001:
				locomote = to.normalized()
	if locomote.length_squared() > 0.0:
		var sep := _separation_steer()
		var dir := (locomote + sep).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		face_towards(global_position + dir, delta)
		var frac := clampf(speed / 8.0, 0.0, 1.0)
		anim.play_locomotion(frac)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if not anim._busy and not anim._forced:
			anim.play_idle()
	move_and_slide()
	current_clip = anim.current_clip
	_status_fx()
	_blood_trail()
	_update_label()
	if is_pet and pet_record:
		var drain := hunger_max / 1800.0 * delta * (1.0 / maxf(0.5, pet_record.hunger_efficiency))
		hunger = maxf(0.0, hunger - drain)
		pet_record.hunger = hunger

func _size_collision() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(0.18, def.real_length_m * 0.12)
	cap.height = maxf(cap.radius * 2.0 + 0.1, def.height_meters)
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	agent.path_desired_distance = 0.45
	agent.target_desired_distance = 0.9
	agent.radius = cap.radius

func _make_brain() -> void:
	if is_pet:
		brain = PetBrain.new()
	else:
		brain = CreatureBrain.new()
	brain.name = "Brain"
	add_child(brain)
	brain.setup(self)

func _make_drip() -> void:
	_fx_drip = GPUParticles3D.new()
	_fx_drip.emitting = false
	_fx_drip.amount = 24
	_fx_drip.lifetime = 0.6
	_fx_drip.position = Vector3(0, def.height_meters * 0.5, 0)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0, -4, 0)
	mat.color = Color(0.45, 0.02, 0.04)
	_fx_drip.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.03
	draw.height = 0.06
	_fx_drip.draw_pass_1 = draw
	add_child(_fx_drip)
	_last_bleed_pos = global_position

func _status_fx() -> void:
	var dark := 0.0
	var tint := Color.WHITE
	var wobble := 0.0
	if statuses.has(&"bleed") or statuses.has(&"deep_bleed") or statuses.has(&"bleeding_target"):
		dark = 0.35
		_fx_drip.emitting = true
	else:
		_fx_drip.emitting = false
	if statuses.has(&"venom") or statuses.has(&"poisoned_target"):
		tint = Color(0.35, 0.85, 0.3)
	if statuses.has(&"enraged"):
		tint = Color(0.9, 0.25, 0.15)
	if statuses.has(&"groggy") or statuses.has(&"dizziness"):
		wobble = 1.0
	if statuses.has(&"fracture"):
		ap.speed_scale = 0.65
	view.set_status_fx(dark, tint, wobble)

func _blood_trail() -> void:
	if not statuses.has(&"bleeding_target"):
		return
	if global_position.distance_to(_last_bleed_pos) < 1.5:
		return
	_last_bleed_pos = global_position
	var decal := Decal.new()
	decal.size = Vector3(0.45, 2.0, 0.45)
	decal.modulate = Color(0.45, 0.02, 0.04, 0.8)
	decal.position = global_position + Vector3(0, 0.05, 0)
	get_parent().add_child(decal)
	get_tree().create_timer(20.0).timeout.connect(decal.queue_free)

func _update_label() -> void:
	if label == null:
		return
	var st := brain.state if brain else brain_state
	label.text = "%s\n%s / %s" % [def.id, st, anim.current_clip]
	label.position.y = def.height_meters + 0.4
	label.visible = Game.debug_overlay

func _on_windup(clip: StringName) -> void:
	Telegraph.show_for(self, clip)

func _on_hit(clip: StringName) -> void:
	var target := brain.attack_target if brain else null
	if target:
		apply_species_on_hit(clip, target)
		if target is Player:
			(target as Player).receive_creature_hit(self, clip)

func _on_attack_done() -> void:
	pass

func _on_kd_start() -> void:
	is_capturable = true
	FieldTame.begin_window(self)

func _on_kd_end() -> void:
	is_capturable = false

func _on_status_removed(id: StringName) -> void:
	if id != &"knockdown":
		return
	if anim and anim._hold_knockdown:
		anim.release_knockdown()
	is_capturable = false
	if tame_attempting and def and tame_feeds + 0.001 < def.feeds_needed and not is_pet:
		FieldTame.fail(self, null)

func mark_aggro_now() -> void:
	last_aggro_s = _now_s()

func note_tapped() -> void:
	_last_tap_s = _now_s()

func tapped_recently(seconds: float) -> bool:
	return _now_s() - _last_tap_s <= seconds

func _on_damaged(_amount: float, source: Node) -> void:
	if health.dead:
		return
	last_damaged_s = _now_s()
	combat_float.emit(_amount, &"hit")
	view.flash_damage(0.1)
	if brain:
		brain.note_damage(_amount)
	if statuses.has(&"groggy") and not statuses.has(&"knockdown"):
		statuses.apply(&"knockdown", source)
		anim.play_clip(&"knockdown")
		return
	if not str(anim.current_clip).begins_with("attack"):
		anim.play_clip(&"hit_react")
	if source:
		aggroed.emit(source)
		if brain:
			brain.on_aggro(source)

func _on_died(_source: Node) -> void:
	anim.play_clip(&"death")
	view.set_status_fx(0.35, Color(0.62, 0.62, 0.62), 0.0)
	collision_layer = 0
	collision_mask = 1
	stop_move()
	var corpse := Corpse.new()
	corpse.setup(self)
	get_parent().add_child(corpse)
	corpse.global_position = global_position

func _on_healed(amount: float) -> void:
	combat_float.emit(amount, &"heal")

func on_status_tick_damage(id: StringName, amount: float) -> void:
	if id == &"bleed" or id == &"deep_bleed" or id == &"bleeding_target":
		combat_float.emit(amount, &"dot")
	else:
		combat_float.emit(amount, &"hit")

func _fall_guard() -> void:
	# Same rule as the player: below -15 m the creature is put back on the surface.
	if global_position.y > -15.0:
		return
	var y := 1.0
	if World.runtime and World.runtime.has_method("surface_y"):
		y = World.runtime.surface_y(global_position.x, global_position.z) + 0.5
	velocity = Vector3.ZERO
	global_position.y = y
	print("[creature] %s fell out of the world; re-seated at y=%.2f" % [def.id if def else "?", y])

func _use_tile_path() -> bool:
	if World == null or World.runtime == null:
		return false
	if get_parent() != World.runtime:
		return false
	return World.runtime.get("pathing") != null

func _tile_path_direction(delta: float) -> Vector3:
	if not _path_active:
		return Vector3.ZERO
	_path_replan_left -= delta
	if _path_replan_left <= 0.0 or _path_points.is_empty():
		_replan_path()
		_path_replan_left = 0.5
	if _path_points.is_empty():
		return Vector3.ZERO
	while _path_index < _path_points.size():
		var next := _path_points[_path_index]
		var to_next := next - global_position
		to_next.y = 0.0
		if to_next.length() <= 0.25:
			_path_index += 1
			continue
		_track_blocked(delta)
		return to_next.normalized()
	_path_active = false
	return Vector3.ZERO

func _track_blocked(delta: float) -> void:
	if global_position.distance_to(_path_anchor) > 0.06:
		_path_anchor = global_position
		_path_blocked_left = 0.0
		return
	_path_blocked_left += delta
	if _path_blocked_left >= 0.35:
		_replan_path()
		_path_blocked_left = 0.0
		_path_anchor = global_position

func _replan_path() -> void:
	if not _use_tile_path():
		return
	var p: Variant = World.runtime.get("pathing")
	if p == null:
		return
	_path_points = p.path(global_position, _path_goal, 72)
	_path_index = 0
	if _path_points.size() > 1 and _path_points[0].distance_to(global_position) <= 0.25:
		_path_index = 1

func _separation_steer() -> Vector3:
	var want := agent.radius * 0.6
	if want <= 0.0:
		return Vector3.ZERO
	var steer := Vector3.ZERO
	for n in get_tree().get_nodes_in_group("creatures"):
		var other := n as Creature
		if other == null or other == self or other.health.dead:
			continue
		var to_me := global_position - other.global_position
		to_me.y = 0.0
		var d := to_me.length()
		if d <= 0.001 or d > want:
			continue
		steer += to_me.normalized() * (1.0 - d / want)
	if steer.length_squared() <= 0.0:
		return Vector3.ZERO
	return steer.normalized()

func _spawn_level_from_ring() -> int:
	if World == null or World.runtime == null:
		return def.tier
	if get_parent() != World.runtime:
		return def.tier
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var ring: StringName = World.runtime.ring_name(global_position)
	var row: Dictionary = rings.get(str(ring), {})
	return maxi(1, def.tier + int(row.get("level_offset", 0)))

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001

func _set_vis_range(n: Node, end_dist: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = end_dist
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		_set_vis_range(c, end_dist)
