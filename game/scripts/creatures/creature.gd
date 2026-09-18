class_name Creature
extends CharacterBody3D
## Wild or tamed animal. Stats come from CreatureDef; tames keep the wild block (R2).

signal aggroed(who: Node)
signal captured
signal dismissed

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

func spawn(p_def: CreatureDef, p_variant: StringName = &"", p_pack: int = 0) -> void:
	def = p_def
	variant = p_variant
	pack_id = p_pack
	add_to_group("creatures")
	view.setup(def, variant)
	health.setup(def.hp)
	# ASSUMPTION: pet hunger budget is 0.4 * wild HP when JSON has no hunger field.
	hunger_max = def.hp * 0.4
	hunger = hunger_max
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
	_make_brain()
	_make_drip()
	print("[creature] %s spawned pack=%s" % [def.id, pack_id])

func on_anim_event(kind: String, clip: String) -> void:
	anim.on_event(kind, clip)

func move_to(world_pos: Vector3) -> void:
	agent.target_position = world_pos

func stop_move() -> void:
	agent.target_position = global_position

func face_towards(world_pos: Vector3, _delta: float) -> void:
	var p := world_pos
	p.y = global_position.y
	if p.distance_squared_to(global_position) < 0.0001:
		return
	look_at(p, Vector3.UP)

func apply_species_on_hit(clip: StringName, target: Node) -> void:
	CreatureAttack.apply_for(self, clip, target)

func capturable() -> bool:
	return is_capturable and health.hp > 0.0 and def.tameable

func _physics_process(delta: float) -> void:
	_fall_guard()
	if not is_on_floor():
		velocity += get_gravity() * delta
	if health.dead or statuses.has(&"knockdown") or statuses.has_flag(&"cannot_act"):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_label()
		return
	var speed := def.move_speed_mps * statuses.move_mult()
	if is_pet and hunger <= 0.0:
		speed *= 0.85
	if not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		var to := next - global_position
		to.y = 0.0
		if to.length_squared() > 0.0001:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			face_towards(next, delta)
			var frac := clampf(speed / 8.0, 0.0, 1.0)
			anim.play_locomotion(frac)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
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
	elif def.mapped_archetype() == &"raptor_pack":
		brain = RaptorPackBrain.new()
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

func _on_kd_end() -> void:
	is_capturable = false

func _on_damaged(_amount: float, source: Node) -> void:
	if health.dead:
		return
	if statuses.has(&"groggy") and not statuses.has(&"knockdown"):
		statuses.apply(&"knockdown", source)
		anim.play_clip(&"knockdown")
		get_tree().create_timer(4.0).timeout.connect(func () -> void:
			if is_instance_valid(self) and not health.dead:
				statuses.clear_id(&"knockdown")
				anim.release_knockdown()
				is_capturable = false
		)
		return
	if not str(anim.current_clip).begins_with("attack"):
		anim.play_clip(&"hit_react")
	if source:
		aggroed.emit(source)
		if brain:
			brain.on_aggro(source)

func _on_died(_source: Node) -> void:
	anim.play_clip(&"death")
	collision_layer = 0
	collision_mask = 1
	stop_move()
	var corpse := Corpse.new()
	corpse.setup(self)
	get_parent().add_child(corpse)
	corpse.global_position = global_position

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
