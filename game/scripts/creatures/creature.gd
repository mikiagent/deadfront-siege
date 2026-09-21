class_name Creature
extends CharacterBody3D
## Wild or tamed animal. Stats come from CreatureDef; tames keep the wild block (R2).

signal aggroed(who: Node)
signal captured
signal dismissed
signal combat_float(amount: float, kind: StringName)
## A status just landed on this creature (plates float its name in the status colour).
signal status_float(id: StringName)

## Set by the attacker just before health.take_damage: &"hit", &"weak", &"strong" or &"crit".
## Read once by _on_damaged for the floating number, then reset.
var next_hit_kind: StringName = &"hit"

const STATUS_COLORS := {
	"bleed": Color(0.95, 0.3, 0.3), "deep_bleed": Color(0.85, 0.15, 0.15), "bleeding_target": Color(0.95, 0.3, 0.3),
	"venom": Color(0.45, 0.95, 0.35), "poisoned_target": Color(0.45, 0.95, 0.35), "infected_wound": Color(0.6, 0.8, 0.3),
	"groggy": Color(1.0, 0.86, 0.35), "dizziness": Color(1.0, 0.86, 0.35), "knockdown": Color(1.0, 0.62, 0.25),
	"fracture": Color(0.85, 0.88, 1.0), "snared": Color(0.8, 0.7, 0.5), "pinned": Color(0.8, 0.7, 0.5),
	"enraged": Color(0.95, 0.25, 0.15), "deafened": Color(0.7, 0.7, 0.85),
}

static func status_color(id: StringName) -> Color:
	return STATUS_COLORS.get(str(id), Color(0.9, 0.9, 0.9))

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
var genetics: CreatureGenetics
var spawn_tile: Vector2i = Vector2i.ZERO
var spawn_home: Vector3 = Vector3.ZERO
var last_aggro_s: float = -999.0
var last_damaged_s: float = -999.0
var _last_tap_s: float = -999.0
var tame_feeds: float = 0.0
var tame_window_left: float = 0.0
var tame_cooldown_left: float = 0.0
var tame_attempting: bool = false

# Wild creatures recover slowly after a real break from combat. Pool sub-point healing so
# plates get readable ticks instead of a floating-number event every frame.
const WILD_REGEN_DELAY_S := 8.0
const WILD_REGEN_RATE := 0.01
var _wild_regen_pool: float = 0.0

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
var _aggro_ring: MeshInstance3D
## Stagger: 0.3 s frozen hurt window after a hit, at most once per second.
var stagger_left: float = 0.0
var _stagger_immune_until: float = -1.0
var _aggro_ring_r: float = -1.0
var _aggro_ring_t: float = 0.0
## Pet regen accumulates here and is applied in one tick per second, so the heal float
## pops once a second instead of every frame.
var _pet_regen_pool: float = 0.0
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
	# No visibility range: the iso camera sits 40 m from the survivor (IsoCamera.distance), so the
	# old 26 m cut-off culled every creature mesh and only the plates showed.
	_set_vis_range(view, 0.0)
	if genetics == null:
		genetics = CreatureGenetics.roll()
	health.setup(stat_value(&"health"))
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
	statuses.applied.connect(_on_status_applied)
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
	# A chase target drifts a little every frame. Keep following the current path and let the
	# 0.5 s replan pick the drift up; only a big jump (new tile) replans at once. Replanning on
	# every drift restarted the path at this tile's centre and left chasers jittering in place.
	var was_active := _path_active
	var moved := _path_goal.distance_to(world_pos)
	_path_goal = world_pos
	_path_active = true
	if not was_active or moved > 1.2 or _path_points.is_empty():
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

func stat_value(stat: StringName) -> float:
	var base := 0.0
	match stat:
		&"health": base = def.hp
		&"melee_defense", &"ranged_defense": base = def.defense
		&"melee_attack", &"ranged_attack": base = def.attack
		&"accuracy": base = 100.0
		&"speed": base = def.speed
	return base * (genetics.multiplier(stat) if genetics else 1.0)

func defense_for(ranged: bool = false) -> float:
	return stat_value(&"ranged_defense" if ranged else &"melee_defense")

func attack_for(ranged: bool = false) -> float:
	return stat_value(&"ranged_attack" if ranged else &"melee_attack")

func accuracy_chance() -> float:
	if is_pet and pet_record:
		return pet_record.accuracy_chance()
	return clampf(0.90 + (stat_value(&"accuracy") - 100.0) * 0.004, 0.72, 0.99)

func crit_chance() -> float:
	if is_pet and pet_record:
		return pet_record.crit_chance()
	return clampf(0.05 + (stat_value(&"accuracy") - 85.0) * 0.003, 0.02, 0.16)

func dodge_chance() -> float:
	if is_pet and pet_record:
		return pet_record.dodge_chance(def)
	return clampf(0.04 + (stat_value(&"speed") / maxf(1.0, def.speed) - 0.85) * 0.20, 0.04, 0.10)

func move_speed_mps() -> float:
	return stat_value(&"speed") / 100.0

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
	# A fresh tame is no longer a combat target. Do not carry wild damage/aggro plate timers
	# into the bonded state, which left the old health plate hanging over the new pet.
	last_damaged_s = -999.0
	last_aggro_s = -999.0
	_last_tap_s = -999.0
	_wild_regen_pool = 0.0
	if brain:
		brain.queue_free()
		brain = null
	_make_brain()
	_apply_pet_passthrough()

## Pets never body-block the survivor: a mutual collision exception, applied once the
## player node is around. Enemies and everything else still collide with pets normally.
var _pet_passthrough_done: bool = false

func _apply_pet_passthrough() -> void:
	if _pet_passthrough_done or not is_pet:
		return
	var p := get_tree().get_first_node_in_group("player") as PhysicsBody3D
	if p == null:
		return
	add_collision_exception_with(p)
	_pet_passthrough_done = true

func _physics_process(delta: float) -> void:
	_fall_guard()
	_apply_pet_passthrough()
	FieldTame.tick(self, delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	stagger_left = maxf(0.0, stagger_left - delta)
	if health.dead or statuses.has(&"knockdown") or statuses.has_flag(&"cannot_act") or stagger_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_update_label()
		return
	var speed := (pet_record.speed / 100.0 if is_pet and pet_record else move_speed_mps()) * statuses.move_mult()
	if not is_pet and brain and (brain.state == &"approach" or brain.state == &"attack"):
		# ASSUMPTION: wild animals chase at 70 % of their listed speed so a survivor can outrun them.
		speed *= float(brain.profile.get("chase_speed_mult", 0.7)) if brain.get("profile") != null else 0.7
	if is_pet and hunger <= 0.0:
		speed *= 0.85
	var locomote := Vector3.ZERO
	if _path_active:
		if _use_tile_path():
			locomote = _tile_path_direction(delta)
		else:
			if not agent.is_navigation_finished():
				var next := agent.get_next_path_position()
				var to := next - global_position
				to.y = 0.0
				if to.length_squared() > 0.0001:
					locomote = to.normalized()
			# Runtime nav maps can take a frame to sync and sparse labs occasionally return the
			# current point. A nearby AI goal is still safe to steer toward directly.
			if locomote.length_squared() <= 0.0:
				var direct := _path_goal - global_position
				direct.y = 0.0
				if direct.length() > 0.3 and direct.length() <= 12.0:
					locomote = direct.normalized()
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
	_update_aggro_ring(delta)
	# Wild dinosaurs recover 1 % max HP/s after eight quiet seconds. Both recent damage and
	# aggro hold the lock, and an AI target keeps it locked even if no hit has landed yet.
	var wild_calm := not is_pet and not health.dead and health.hp < health.max_hp \
		and _now_s() - last_damaged_s > WILD_REGEN_DELAY_S \
		and _now_s() - last_aggro_s > WILD_REGEN_DELAY_S \
		and (brain == null or brain.attack_target == null)
	if wild_calm:
		_wild_regen_pool += health.max_hp * WILD_REGEN_RATE * delta
		var wild_tick := maxf(1.0, health.max_hp * WILD_REGEN_RATE)
		if _wild_regen_pool >= wild_tick:
			health.heal(_wild_regen_pool)
			_wild_regen_pool = 0.0
	else:
		_wild_regen_pool = 0.0
	# Pets heal 2 % of max HP per second once 6 s have passed without a hit and nothing is targeted.
	# The heal is pooled and applied once it reaches a full second's worth, so the floating
	# "+HP" text ticks about once a second instead of spamming every rendered frame.
	if is_pet and not health.dead and health.hp < health.max_hp and _now_s() - last_damaged_s > 6.0 and (brain == null or brain.attack_target == null):
		_pet_regen_pool += health.max_hp * 0.02 * delta
		var tick := maxf(1.0, health.max_hp * 0.02)
		if _pet_regen_pool >= tick:
			health.heal(_pet_regen_pool)
			_pet_regen_pool = 0.0
	else:
		_pet_regen_pool = 0.0
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
	elif def and def.mapped_archetype() == &"raptor_pack":
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

## Red dotted ring on the ground at the leash radius while this creature hunts the survivor.
## Step outside it and the chase ends (CreatureBrain._disengage_track). Vertices follow the
## terrain so the ring reads on slopes; rebuilt at 10 Hz while the creature moves.
func _update_aggro_ring(delta: float) -> void:
	var show := not is_pet and not health.dead and brain != null and brain.has_method("hunting_player") and brain.hunting_player()
	if not show:
		if _aggro_ring and _aggro_ring.visible:
			_aggro_ring.visible = false
		return
	if _aggro_ring == null:
		_aggro_ring = MeshInstance3D.new()
		_aggro_ring.name = "AggroRing"
		_aggro_ring.top_level = true
		_aggro_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.95, 0.12, 0.1, 0.8)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = true  # a gameplay marker: never hidden by grass or slopes
		m.render_priority = 2
		_aggro_ring.material_override = m
		_aggro_ring.mesh = ImmediateMesh.new()
		add_child(_aggro_ring)
		print("[ai] %s aggro ring r=%.1f" % [def.id, brain.aggro_radius()])
	_aggro_ring.visible = true
	_aggro_ring_t -= delta
	var r: float = brain.aggro_radius()
	if _aggro_ring_t > 0.0 and absf(r - _aggro_ring_r) < 0.01:
		return
	_aggro_ring_t = 0.1
	_aggro_ring_r = r
	var im := _aggro_ring.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := global_position
	var dashes := int(clampf(r * 3.0, 24.0, 96.0))
	var w := 0.07
	var rt := World.runtime if World else null
	var has_surf := rt != null and rt.has_method("surface_y")
	for i in dashes:
		var a0 := TAU * float(i) / float(dashes)
		var a1 := a0 + TAU / float(dashes) * 0.55
		var quad: Array[Vector3] = []
		for pair in [[a0, r - w], [a0, r + w], [a1, r + w], [a1, r - w]]:
			var p := centre + Vector3(cos(pair[0]) * pair[1], 0.0, sin(pair[0]) * pair[1])
			p.y = (rt.surface_y(p.x, p.z) if has_surf else centre.y) + 0.15
			quad.append(p)
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[1])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[0])
		im.surface_add_vertex(quad[2])
		im.surface_add_vertex(quad[3])
	im.surface_end()
	_aggro_ring.global_transform = Transform3D.IDENTITY

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
	var kind := next_hit_kind
	next_hit_kind = &"hit"
	combat_float.emit(_amount, kind)
	view.flash_damage(0.18 if kind == &"crit" else 0.1)
	var burst_col := Color(1, 1, 1)
	match kind:
		&"weak": burst_col = Color(0.6, 0.6, 0.6)
		&"strong": burst_col = Color(1.0, 0.6, 0.15)
		&"crit": burst_col = Color(1.0, 0.15, 0.1)
	hit_burst(burst_col, 0.16 if kind == &"crit" else 0.1, 22 if kind == &"crit" else 12)
	if brain:
		brain.note_damage(_amount)
	if statuses.has(&"groggy") and not statuses.has(&"knockdown"):
		statuses.apply(&"knockdown", source)
		anim.play_clip(&"knockdown")
		return
	if _now_s() >= _stagger_immune_until:
		stagger_left = 0.45 if kind == &"crit" else 0.3
		_stagger_immune_until = _now_s() + 1.0
	if not str(anim.current_clip).begins_with("attack"):
		var authored: Dictionary = def.pipeline.get("authored_clips", {})
		if authored.has("hit_react") or not view.using_glb:
			view.flinch(1.4 if kind == &"crit" else 1.0)  # no real hurt clip: shove + nod instead
		else:
			anim.play_clip(&"hit_react")
	if source:
		aggroed.emit(source)
		if brain:
			brain.on_aggro(source)

func _on_died(_source: Node) -> void:
	anim.play_clip(&"death")
	# The dead creature stops physics processing before _update_aggro_ring can hide it. Remove the
	# top-level world marker here so a dead dinosaur never leaves a red leash circle behind.
	if _aggro_ring:
		_aggro_ring.queue_free()
		_aggro_ring = null
	if is_pet and pet_record:
		pet_record.start_respawn()  # down for RESPAWN_TIME; PETS sheet shows the countdown ring
	# Pet XP: a kill by the pet pays 10 + tier/3; a survivor kill with the pet fighting within
	# 15 m pays 3 + tier/6. Levels raise the pet's HP, attack and defense.
	if not is_pet:
		var killer_pet: Creature = _source as Creature if (_source is Creature and (_source as Creature).is_pet) else null
		var owner := get_tree().get_first_node_in_group("player") as Player
		var pets: Array[Creature] = owner.live_pets() if owner else []
		for pet in pets:
			if pet == null or pet.pet_record == null or pet.health.dead:
				continue
			var amount := 0.0
			if killer_pet == pet:
				amount = 10.0 + float(def.tier) / 3.0
			elif pet.global_position.distance_to(global_position) <= 15.0:
				amount = 3.0 + float(def.tier) / 6.0  # assist: fighting alongside whoever landed the kill
			if amount > 0.0:
				var gained := pet.pet_record.add_xp(amount)
				pet.level = pet.pet_record.level
				pet.combat_float.emit(amount, &"xp")
				if gained > 0:
					pet.health.max_hp = pet.pet_record.hp
					pet.health.hp = minf(pet.health.max_hp, pet.health.hp + pet.health.max_hp * 0.25)
					pet.hit_burst(Color(1.0, 0.9, 0.4), 0.2, 24, 0.7)
					if owner:
						owner.notice("%s reached Lv. %d!" % [str(pet.def.species), pet.pet_record.level])
				print("[pet] +%.0f xp -> lv %d" % [amount, pet.pet_record.level])
	if not is_pet and (_source is Player or (_source is Creature and (_source as Creature).is_pet)):
		var p := _source as Player if _source is Player else get_tree().get_first_node_in_group("player") as Player
		if p and p.skills:
			p.skills.add_xp("melee", 4 + def.tier / 5)
		else:
			World.add_xp(4 + def.tier / 5)
		print("[combat] %s killed: +%d xp" % [def.id, 4 + def.tier / 5])
	view.set_status_fx(0.35, Color(0.62, 0.62, 0.62), 0.0)
	collision_layer = 0
	collision_mask = 1
	stop_move()
	# Bonded animals enter their respawn cooldown without creating a harvestable corpse or
	# loot bag. Wild kills still use the normal corpse/loot flow.
	if not is_pet:
		var corpse := Corpse.new()
		corpse.setup(self)
		get_parent().add_child(corpse)
		corpse.global_position = global_position

## Status landed: float its name over the plate and puff a burst in its colour. The lasting
## look (blood drip, venom tint, wobble) is _status_fx every frame.
func _on_status_applied(id: StringName, _stacks: int) -> void:
	if health.dead:
		return
	status_float.emit(id)
	hit_burst(status_color(id), 0.2, 20, 0.55)

## One-shot particle puff at chest height. Frees itself.
func hit_burst(col: Color, radius: float = 0.1, count: int = 12, life: float = 0.4) -> void:
	if not is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.position = Vector3(0, def.height_meters * 0.55, 0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = maxf(0.08, def.height_meters * 0.25)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.2
	mat.initial_velocity_max = 2.6
	mat.gravity = Vector3(0, -3.0, 0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.color = col
	p.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = radius * 0.5
	draw.height = radius
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = col
	dm.vertex_color_use_as_albedo = true
	draw.material = dm
	p.draw_pass_1 = draw
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

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
		# No tile path (target on a blocked tile, or off the grid): steer straight at it when it is
		# close instead of freezing; move_and_slide handles the bumps.
		var direct := _path_goal - global_position
		direct.y = 0.0
		if direct.length() > 0.3 and direct.length() <= 12.0:
			return direct.normalized()
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
	# Path exhausted: close the last gap to the goal directly (the last point is a tile centre).
	var tail := _path_goal - global_position
	tail.y = 0.0
	if tail.length() > 0.3 and tail.length() <= 2.0:
		return tail.normalized()
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
	# Skip waypoints already behind us (same rule as the survivor): a fresh path starts at this
	# tile's centre, and walking back to it every replan is the in-place jitter.
	while _path_points.size() > _path_index + 1:
		var p0 := _path_points[_path_index]
		var p1 := _path_points[_path_index + 1]
		var seg := p1 - p0
		seg.y = 0.0
		var rel := global_position - p0
		rel.y = 0.0
		if seg.dot(rel) > 0.0 and rel.length() < 1.5:
			_path_index += 1
		else:
			break
	if _path_points.size() == 1 and _path_points[0].distance_to(global_position) <= 0.25:
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
	# island_def is set before IslandRuntime.build() starts spawning creatures. Use it first:
	# World.runtime is intentionally assigned only after build completes, so consulting runtime
	# first made every starter creature fall back to its species tier (often Lv. 20).
	if World != null:
		var resolved := ProgressionScaling.resolved_spawn_level(def.tier, World.island_def, int(Data.world_rules.get("level_cap", 60)))
		if resolved != def.tier or int(World.island_def.get("level_override", 0)) > 0:
			return resolved
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
