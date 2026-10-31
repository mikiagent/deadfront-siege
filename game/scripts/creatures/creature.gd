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
## ALPHAS: set by the Spawner before spawn() when this member won its group's alpha roll.
var alpha_spawn: bool = false
var spawn_tile: Vector2i = Vector2i.ZERO
var spawn_home: Vector3 = Vector3.ZERO
var last_aggro_s: float = -999.0
var last_damaged_s: float = -999.0
var _last_tap_s: float = -999.0
var tame_feeds: float = 0.0
var tame_window_left: float = 0.0
var tame_cooldown_left: float = 0.0
var tame_attempting: bool = false
## FOODTORPOR: 0..torpor_max(). Blunt hits, Sedative-coated hits and Tranquilizer Darts add it; it
## drains after a quiet spell. Weak + past FieldTame.torpor_ko_frac() = knocked out (capturable).
## Not saved: wild animals respawn fresh.
var torpor: float = 0.0
var _torpor_quiet_s: float = 0.0
## NATURES: rolled once at spawn from the animal's spawn seed (species + point + pack) and kept
## when it is tamed (PetRecord.nature). Knobs are read through nature_knob(): one source, default 1.
var nature: StringName = &""

# Wild creatures recover slowly after a real break from combat. Pool sub-point healing so
# plates get readable ticks instead of a floating-number event every frame.
const WILD_REGEN_DELAY_S := 8.0
const WILD_REGEN_RATE := 0.01
var _wild_regen_pool: float = 0.0

## ENERGY (owner 2026-10-28): running and special moves spend it, rest and walking refill it. No
## exhaustion. Below stop_frac the animal is winded: it cannot run or start a special until the pool
## is back above resume_frac (hysteresis). Numbers: ai.json "energy" (size default) or the species'
## own "energy" block. Not saved: a reload starts full (the pool refills in 10-30 s anyway).
var energy: float = 100.0
var energy_max: float = 100.0
var energy_regen_per_s: float = 10.0
var energy_drain_per_s: float = 10.0
var winded: bool = false
## Set by whoever moved the animal at a run this frame; ticked (drain or regen) next physics frame.
var running: bool = false

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
## PINFEEL: the victim this predator holds Pinned under one foot (pin_foot), or null.
var pin_victim: Node3D
var _fx_drip: GPUParticles3D
var _aggro_ring: MeshInstance3D
## Stagger: 0.3 s frozen hurt window after a hit, at most once per second.
var stagger_left: float = 0.0
## Shove (the survivor's kick): slid along _shove_v, decaying to 0 over _shove_s, while staggered.
var _shove_v := Vector3.ZERO
var _shove_s: float = 0.0
var _shove_left: float = 0.0
var _stagger_immune_until: float = -1.0
var _aggro_ring_r: float = -1.0
var _aggro_ring_t: float = 0.0
## Pet regen accumulates here and is applied in one tick per second, so the heal float
## pops once a second instead of every frame.
var _pet_regen_pool: float = 0.0
var _trail_origin: Vector3
var trap_left: float = 0.0
var trap_immunity_left: float = 0.0
var trap_move_mult: float = 1.0
var _last_bleed_pos: Vector3
var _path_points: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _path_goal: Vector3 = Vector3.ZERO
var _path_active: bool = false
var _path_replan_left: float = 0.0
var _path_blocked_left: float = 0.0
var _path_anchor: Vector3 = Vector3.ZERO
## Turning: the yaw budget left this physics frame (see face_towards) and the low-passed velocity
## the locomotion faces. ASSUMPTION: 0.15 s smoothing and no turning below 0.3 m/s (PRDs give none).
const FACE_VEL_TAU_S := 0.15
const FACE_MIN_SPEED_MPS := 0.3
## ASSUMPTION: walking may run up to 3 deg off its smoothed heading before the body turns.
const FACE_SLACK_RAD := 0.05
var _turn_frame: int = -1
var _turn_left: float = 0.0
var _face_vel: Vector3 = Vector3.ZERO

## p_runtime: the IslandRuntime placing this spawn (Spawner passes its parent), so ring level
## offsets apply even before World.runtime is assigned. p_tier_offset: the island row's tier_offset.
func spawn(p_def: CreatureDef, p_variant: StringName = &"", p_pack: int = 0, p_runtime: Node = null, p_tier_offset: int = 0, p_nature: StringName = &"") -> void:
	# A live character is not a moving floor. Giants must not ride a survivor away.
	platform_floor_layers = 0
	platform_wall_layers = 0
	def = p_def
	variant = p_variant if p_variant != &"" else CreatureView.pick_variant(p_def, "%s@%v" % [p_def.id, global_position.round()])
	# An alpha wears the species' alpha skin when it has one (pipeline.model_variants.alpha, the owner's alpha sheet).
	if p_variant == &"" and (alpha_spawn or (genetics != null and genetics.alpha)) and CreatureView.model_variants(p_def).has("alpha"):
		variant = &"alpha"
	_slide_counter += 1
	_slide_phase = _slide_counter
	pack_id = p_pack
	add_to_group("creatures")
	if genetics == null:
		# The colour roll is seeded off the animal's identity (spawn point), so a wild individual
		# keeps its colours when the caller reuses a seeded genetics roll for it.
		# Only the colour roll is seeded from the spawn point (a reload keeps the look); the IVs stay
		# random, as they always were.
		# GENETICS: the body size draws from the same seeded stream, after the colours.
		genetics = CreatureGenetics.for_species(def, null, CreatureColoration.seeded_rng(spawn_colour_key(def.id, global_position)))
	if alpha_spawn and not genetics.alpha:
		genetics.make_alpha()
	# SP-SMILODON: an alpha rolled by the genetics above (not asked for with alpha_spawn) wears the alpha skin too.
	if p_variant == &"" and is_alpha() and CreatureView.model_variants(def).has("alpha"):
		variant = &"alpha"
	view.setup(def, variant)
	# No visibility range: the iso camera sits 40 m from the survivor (IsoCamera.distance), so the
	# old 26 m cut-off culled every creature mesh and only the plates showed.
	_set_vis_range(view, 0.0)
	# One colour profile per individual, kept on the genetics record so taming carries it over.
	view.apply_coloration(genetics.coloration if genetics.coloration != null else CreatureColoration.neutral())
	if pet_record:  # SADDLES: the equipped saddle shows on the back, ridden or not
		_on_gear_changed()
		if not pet_record.gear.changed.is_connected(_on_gear_changed):
			pet_record.gear.changed.connect(_on_gear_changed)
	# GENETICS: the model (and everything parented to it: eyes, mount socket, saddle) at the body size;
	# an alpha's eyes glow brighter.
	view.apply_genome(size_scale(), float(CreatureGenetics.alpha_rules().get("eye_glow_mult", 2.5)) if is_alpha() else 1.0)
	level = _spawn_level(p_runtime, p_tier_offset)
	health.setup(stat_value(&"health"))
	health.healed.connect(_on_healed)
	setup_energy()
	# ASSUMPTION: pet hunger budget is 0.4 * wild HP when JSON has no hunger field.
	hunger_max = def.hp * 0.4
	hunger = hunger_max
	# NATURES: one nature per animal, seeded off the same identity the colour roll uses, so a reload
	# at the same spot rolls the same nature. Hidden callers may pass one in (p_nature) to override.
	nature = p_nature if p_nature != &"" else CreatureNatures.roll(CreatureNatures.spawn_key(def.id, global_position, pack_id), def.archetype)
	spawn_tile = BuildGrid.tile_of(global_position)
	# World.runtime is still null while an island builds, which put every home at y=0.
	spawn_home = BuildGrid.tile_centre(spawn_tile, p_runtime if p_runtime else (World.runtime if World else null))
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
	if Game and Game.debug_overlay:
		print("[creature] %s spawned pack=%s level=%d" % [def.id, pack_id, level])

## Identity key for a fresh wild spawn: species, rounded spawn point and a per-spawn serial.
## Seeding the colour roll from it keeps one animal's look stable for as long as it lives (taming
## reuses the genetics record), while a herd at different points and a respawned individual at the
## same point both come out as new animals instead of clones.
static var _spawn_serial: int = 0

func _on_gear_changed() -> void:
	if pet_record and is_instance_valid(view):
		view.show_saddle(pet_record.saddle())

static func spawn_colour_key(species: StringName, at: Vector3) -> String:
	_spawn_serial += 1
	return "%s@%d,%d,%d#%d" % [species, roundi(at.x), roundi(at.y), roundi(at.z), _spawn_serial]

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

## Steps yaw toward world_pos at def.turn_rate (rad/s), never snapping. Every caller in one physics
## frame shares one budget of turn_rate * physics step, so a brain and the locomotion facing the same
## frame cannot add up to more than the species can turn. delta is kept for the callers' signature.
func face_towards(world_pos: Vector3, _delta: float) -> void:
	var p := world_pos
	p.y = global_position.y
	if p.distance_squared_to(global_position) < 0.0001:
		return
	var to := (p - global_position).normalized()
	var target_yaw := atan2(-to.x, -to.z)
	var frame := Engine.get_physics_frames()
	if frame != _turn_frame:
		_turn_frame = frame
		_turn_left = turn_rate() * get_physics_process_delta_time()
	var before := rotation.y
	rotation.y = rotate_toward(before, target_yaw, _turn_left)
	_turn_left = maxf(0.0, _turn_left - absf(angle_difference(before, rotation.y)))

## Turn toward a heading at turn_rate with FACE_SLACK_RAD of slack: reversals inside the slack (the
## wobble a low-pass leaves, a rider's stick noise) cannot dither the yaw.
func face_heading(heading: Vector3, delta: float) -> void:
	var err := angle_difference(rotation.y, atan2(-heading.x, -heading.z))
	if absf(err) > FACE_SLACK_RAD:
		var yaw := rotation.y + err - signf(err) * FACE_SLACK_RAD
		face_towards(global_position + Vector3(-sin(yaw), 0.0, -cos(yaw)), delta)

func turn_rate() -> float:
	return def.turn_rate if def else 3.0

func apply_species_on_hit(clip: StringName, target: Node) -> void:
	CreatureAttack.apply_for(self, clip, target)

## The nature this animal has: its own, or (a pet whose brain was rebuilt) its record's.
func nature_id() -> StringName:
	if pet_record != null and pet_record.nature != &"":
		return pet_record.nature
	return nature

## One nature knob (natures.json, default merged in when the nature has none). The single place a
## brain, a combat hit or a taming rule reads a nature, so there is no second copy of the rules.
func nature_knob(knob: String, fallback: float = 1.0) -> float:
	var base: Variant = CreatureNatures.knobs(&"").get(knob, fallback)
	if nature_id() == &"":
		return (float(base) if not base is bool else (1.0 if bool(base) else 0.0)) * _alpha_knob(knob)
	var raw: Variant = CreatureNatures.knobs(nature_id()).get(knob, fallback)
	if raw is bool:
		return 1.0 if bool(raw) else 0.0
	return float(raw) * _alpha_knob(knob)

## ALPHAS: the class profile's alpha modifier (ai.json archetypes.<a>.tactics.alpha) on a wild alpha's
## tactic_* knobs: shorter cooldowns, heavier sequence weights. 1.0 for everything else.
func _alpha_knob(knob: String) -> float:
	if is_pet or not is_alpha() or not knob.begins_with("tactic_") or def == null:
		return 1.0
	var arch: Variant = (Data.creature_ai.get("archetypes", {}) as Dictionary).get(str(def.archetype), {})
	var tac: Variant = (arch as Dictionary).get("tactics", {}) if arch is Dictionary else {}
	var mod: Variant = (tac as Dictionary).get("alpha", {}) if tac is Dictionary else {}
	return float((mod as Dictionary).get(knob, 1.0)) if mod is Dictionary else 1.0

## True when this animal's nature sets a knob to true (auto_engage, protect_owner, fear_immune...).
func nature_flag(knob: String) -> bool:
	return nature_knob(knob, 0.0) > 0.0

## Feeds / window / pen wait for THIS animal: the species' number times its nature's multiplier.
## One place, read by FieldTame, the gather ring and the taming pen.
func feeds_needed() -> float:
	return maxf(1.0, def.feeds_needed * nature_knob("feeds_mult", 1.0))

func tame_window_seconds() -> float:
	return maxf(1.0, def.tame_window_seconds * nature_knob("tame_window_mult", 1.0))

func stat_value(stat: StringName) -> float:
	if is_pet and pet_record:
		return pet_record.stat_value(stat)  # PetStats is the one source for pets (W1-TAME hook 4)
	var base := 0.0
	match stat:
		&"health": base = def.hp * _level_factor()
		&"melee_defense", &"ranged_defense": base = def.defense * _level_factor()
		&"melee_attack", &"ranged_attack": base = def.attack * _level_factor()
		&"accuracy": base = 100.0
		&"speed": base = def.speed
	return base * (genetics.multiplier(stat) if genetics else 1.0) * alpha_stat_mult(stat)

## GENETICS: body size (1.0 = species as authored). Hook for anything sized off the body: the
## collision capsule, plates, and the ragdoll on its own branch (scale its bones' shapes by this).
func size_scale() -> float:
	return genetics.size if genetics != null else 1.0

## ALPHAS: a rare, much bigger and stronger individual (CreatureGenetics.make_alpha).
func is_alpha() -> bool:
	return genetics != null and genetics.alpha

## ALPHAS: ai.json alpha.stats for a wild alpha ("on steroids"); 1.0 otherwise. A tame keeps its
## size and colours but not this (pets read PetStats).
func alpha_stat_mult(stat: StringName) -> float:
	if is_pet or not is_alpha():
		return 1.0
	var st: Variant = CreatureGenetics.alpha_rules().get("stats", {})
	return float((st as Dictionary).get(str(stat), 1.0)) if st is Dictionary else 1.0

## ALPHAS: the buff a living wild alpha gives its packmates within alpha.aura.radius_m (key: attack,
## defense or speed); 1.0 outside the radius, for the alpha itself, for pets and for lone animals.
func pack_aura_mult(key: String) -> float:
	if is_pet or pack_id <= 0 or is_alpha() or not is_inside_tree():
		return 1.0
	var aura: Variant = CreatureGenetics.alpha_rules().get("aura", {})
	if not aura is Dictionary:
		return 1.0
	var r := float((aura as Dictionary).get("radius_m", 12.0))
	for m in PackIndex.members(self):
		if m != self and m.is_alpha() and global_position.distance_squared_to(m.global_position) <= r * r:
			return float((aura as Dictionary).get(key, 1.0))
	return 1.0

## Wild animals above their species tier hit and soak harder (rules.json wild_level_stat_rate).
## ASSUMPTION: at or below the tier they keep the listed stats (starter island unchanged).
## Read live, but Health's max is set once at spawn.
func _level_factor() -> float:
	if is_pet or def == null:
		return 1.0
	return 1.0 + float(maxi(0, level - def.tier)) * float(Data.world_rules.get("wild_level_stat_rate", 0.08))

## Collision capsule radius; brains size reach, pack slots and wake distance from it.
func body_radius() -> float:
	return maxf(0.18, def.real_length_m * 0.12 * size_scale())

## BIGREACH: the visible body's ground footprint in this body's local XZ (Rect2 x = local x across,
## y = local z nose to tail), from the model's mesh bounds at the current body size. Melee reach and
## the survivor's approach read it, so a long animal is hit at its flank, legs, head or tail.
var _footprint := Rect2()
var _footprint_size := -1.0

func footprint() -> Rect2:
	if _footprint_size == size_scale() or view == null or not is_inside_tree():
		return _footprint if _footprint_size > 0.0 else Rect2(-body_radius(), -body_radius(), body_radius() * 2.0, body_radius() * 2.0)
	var inv := global_transform.affine_inverse()
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for mi in view.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh == null or not (mi as MeshInstance3D).is_visible_in_tree():
			continue
		var b: AABB = inv * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	var r := body_radius()
	if lo.x > hi.x:
		lo = Vector3(-r, 0, -r)
		hi = Vector3(r, 0, r)
	_footprint = Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z)
	_footprint_size = size_scale()
	return _footprint

func defense_for(ranged: bool = false) -> float:
	return stat_value(&"ranged_defense" if ranged else &"melee_defense") * pack_aura_mult("defense")

## NATURES: the one place a nature's damage multiplier applies (Docile is less effective in combat).
## Every hit a creature lands reads this, survivors, pets and structures alike; the stat itself is
## unchanged, so the PETS sheet keeps showing the species numbers. A pet's multiplier already lives
## in PetRecord.stat_value (the one source for pet stats), so it is not applied twice here.
func attack_for(ranged: bool = false) -> float:
	if is_pet and pet_record:
		return pet_record.stat_value(&"ranged_attack" if ranged else &"melee_attack")
	return stat_value(&"ranged_attack" if ranged else &"melee_attack") * nature_knob("damage_dealt_mult", 1.0) * pack_aura_mult("attack")

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
	return stat_value(&"speed") / 100.0 * pack_aura_mult("speed")

# ---------------------------------------------------------------- energy

static func energy_rules() -> Dictionary:
	return Data.creature_ai.get("energy", {}) if Data else {}

## Pool and rates from the size default (bigger = larger pool, slower refill) or the species block.
func setup_energy() -> void:
	var r := energy_rules()
	var own: Dictionary = def.energy if def else {}
	var length := def.real_length_m if def else 1.0
	energy_max = float(own.get("max", float(r.get("pool_base", 80.0)) + float(r.get("pool_per_m", 6.0)) * length))
	var refill_s := float(r.get("refill_s_base", 10.0)) + float(r.get("refill_s_per_m", 0.5)) * length
	energy_regen_per_s = float(own.get("regen_per_s", energy_max / maxf(1.0, refill_s)))
	energy_drain_per_s = float(own.get("run_drain_per_s", r.get("run_drain_per_s", 10.0)))
	energy = energy_max
	winded = false

func energy_frac() -> float:
	return energy / maxf(1.0, energy_max)

## ai.json energy.run_speed_mult: every creature's run (and a ridden mount's) is this much faster.
static func run_speed_mult() -> float:
	return float(energy_rules().get("run_speed_mult", 1.0))

func can_sprint() -> bool:
	return not winded and energy > 0.0

func can_use_special(cost: float) -> bool:
	return cost <= 0.0 or (not winded and energy >= cost)

func spend_energy(cost: float) -> void:
	energy = maxf(0.0, energy - cost)
	if energy <= energy_max * float(energy_rules().get("stop_frac", 0.05)):
		winded = true

## Energy a special move costs: the species' clip entry {"energy_cost": n} or energy.costs[clip],
## else ai.json special_cost_frac[clip] x the pool. 0 = not a special (free).
func special_cost(clip: StringName) -> float:
	if def:
		var entry: Variant = def.clips.get(str(clip))
		if entry is Dictionary and (entry as Dictionary).has("energy_cost"):
			return float(entry["energy_cost"])
		var costs: Dictionary = def.energy.get("costs", {})
		if costs.has(str(clip)):
			return float(costs[str(clip)])
	return float((energy_rules().get("special_cost_frac", {}) as Dictionary).get(str(clip), 0.0)) * energy_max

## Spend a special's cost if the animal can afford it. False = refused (play a basic move instead).
func try_special(clip: StringName) -> bool:
	var cost := special_cost(clip)
	if not can_use_special(cost):
		return false
	spend_energy(cost)
	return true

## Walking pace: walk_frac of the run speed (ASSUMPTION 0.5). Winded animals and an unhurried mount move at it.
func walk_mps(run_mps: float) -> float:
	return run_mps * float(energy_rules().get("walk_frac", 0.5))

## One step of the pool: drain while running, else refill; winded clears at resume_frac.
func tick_energy(delta: float, is_running: bool) -> void:
	var r := energy_rules()
	if is_running:
		energy = maxf(0.0, energy - energy_drain_per_s * delta)
		if energy <= energy_max * float(r.get("stop_frac", 0.05)):
			winded = true
	else:
		# Refill by exhaustion: fresh refills fast, a winded animal slowly (ASSUMPTION multipliers).
		var regen_mult := float(r.get("regen_mult_winded", 1.0)) if winded else float(r.get("regen_mult_fresh", 1.0))
		energy = minf(energy_max, energy + energy_regen_per_s * regen_mult * delta)
		if winded and energy >= energy_max * float(r.get("resume_frac", 0.4)):
			winded = false

func _is_sprint_state() -> bool:
	return brain != null and str(brain.state) in (energy_rules().get("sprint_states", []) as Array)

## Fleeing ground speed from the already-slowed base (`base_mps`) and the slow factor. The floor is
## here, not inline in _physics_process, so a test can call the physics code path (t_ai).
## flee_min_mps: a low-IV grazer still outruns a walking survivor (traps and statuses still slow it).
func flee_speed(base_mps: float, slow: float = 1.0) -> float:
	if brain == null:
		return base_mps
	return maxf(base_mps * float(brain.profile.get("flee_speed_mult", 1.0)),
		float(brain.profile.get("flee_min_mps", 0.0)) * slow)

## ALPHATAG (owner 2026-10-29): an alpha is never capturable, stunned or not.
func capturable() -> bool:
	return is_capturable and health.hp > 0.0 and def.tameable and not is_alpha()

func field_tame_open() -> bool:
	return FieldTame.can_attempt(self)

func become_pet(rec: PetRecord) -> void:
	is_pet = true
	pet_record = rec
	pack_id = 0  # a tame leaves its wild pack: no more following the old alpha or its alerts
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
## Bodies this pet already ignores (see _apply_pet_passthrough): the survivor and the other pets.
var _pet_peers_aware: Dictionary = {}
## True while the survivor rides this creature (set by PlayerPets.mount / dismount).
var ridden: bool = false

func _apply_pet_passthrough() -> void:
	if not is_pet:
		return
	var p := PlayerRegistry.owner_of(self)
	if p != null and not _pet_passthrough_done:
		add_collision_exception_with(p)
		_pet_passthrough_done = true
	# PETFOLLOW: pets also pass through EACH OTHER. Their body capsules would otherwise let one
	# pet park in another's follow slot and deadlock the pair; they fan out to distinct slots, so
	# they still read as separate animals, and an enemy or the survivor still collides normally.
	# (The survivor's own exception above is kept: it is the one that was already there.)
	if p != null and not _pet_peers_aware.has(p):
		_pet_peers_aware[p] = true
	for n in get_tree().get_nodes_in_group("creatures"):
		var other := n as Creature
		if other == null or other == self or not other.is_pet:
			continue
		if not _pet_peers_aware.has(other):
			add_collision_exception_with(other)
			_pet_peers_aware[other] = true

func _physics_process(delta: float) -> void:
	tick_trap_control(delta)
	_fall_guard()
	_apply_pet_passthrough()
	FieldTame.tick(self, delta)
	tick_torpor(delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not ridden:  # a ridden mount's pool is ticked by PlayerPets.mounted_move
		tick_energy(delta, running)
		running = false
	if ridden:
		# PlayerPets.mounted_move drives a ridden mount: its velocity, facing, slide and locomotion clip.
		current_clip = anim.current_clip
		_status_fx()
		return
	stagger_left = maxf(0.0, stagger_left - delta)
	if pin_victim != null:
		_tick_pin(delta)
	_shove_left = maxf(0.0, _shove_left - delta)
	if health.dead or pin_victim != null or statuses.has(&"knockdown") or statuses.has_flag(&"cannot_act") or stagger_left > 0.0:
		var k := _shove_left / _shove_s if _shove_s > 0.0 and not health.dead else 0.0
		velocity.x = _shove_v.x * k
		velocity.z = _shove_v.z * k
		_slide()
		_update_label()
		return
	var slow := statuses.move_mult() * (trap_move_mult if trap_left > 0.0 else 1.0)
	var speed := (pet_record.speed / 100.0 if is_pet and pet_record else move_speed_mps()) * slow
	var base_speed := speed
	if not is_pet and brain:
		match brain.state:
			# ASSUMPTION (owner decision pending, dino-ai-06): chase at chase_speed_mult (0.7) so a survivor can outrun.
			&"approach", &"attack": speed *= float(brain.profile.get("chase_speed_mult", 0.7))
			&"flee": speed = flee_speed(speed, slow)
		if brain.speed_override >= 0.0:
			speed = brain.speed_override * slow  # TACTICS: circle at a walk, lunge at a run
	if is_pet and hunger <= 0.0:
		speed *= 0.85
	# ENERGY: a chase / flee / retreat runs on the pool; winded, it drops to a walk.
	var sprint := _is_sprint_state()
	if sprint and not can_sprint():
		speed = minf(speed, walk_mps(base_speed))
		sprint = false
	elif sprint:
		speed *= run_speed_mult()  # owner 2026-10-28: running is faster for every creature
	var locomote := Vector3.ZERO
	if brain and not is_pet and brain.line_dir != Vector3.ZERO:
		locomote = brain.line_dir
	elif _path_active:
		if _use_tile_path():
			locomote = _tile_path_direction(delta)
		else:
			if not agent.is_navigation_finished():
				locomote = _agent_direction()
			# Runtime nav maps can take a frame to sync and sparse labs occasionally return the
			# current point. A nearby AI goal is still safe to steer toward directly.
			if locomote.length_squared() <= 0.0:
				var direct := _path_goal - global_position
				direct.y = 0.0
				if direct.length() > 0.3 and direct.length() <= 12.0:
					locomote = direct.normalized()
	# No glide (owner 2026-10-31: compy, deinonychus and ankylosaurus charges "glide"): the body never slides
	# under a one-shot. An attack (or a timed windup) plays in place; any other one-shot (alert, sniff,
	# hit_react, feed) gives way to the stride-matched gait below. Leaps move the body themselves (_arc_step).
	if locomote.length_squared() > 0.0 and anim._busy and not anim.current_clip in CreatureAnim.LEAPS:
		if anim.timed_attack or anim.current_clip in CreatureAnim.ATTACKS:
			locomote = Vector3.ZERO
		else:
			anim.release_oneshot()
	if locomote.length_squared() > 0.0:
		var dir := locomote.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		# Face a low-passed velocity, not the raw nav step: path jitter must not become yaw jitter.
		_face_vel = _face_vel.lerp(Vector3(velocity.x, 0.0, velocity.z), 1.0 - exp(-delta / FACE_VEL_TAU_S))
		if brain and not is_pet and brain.strafe_face and is_instance_valid(brain.strafe_face):
			face_towards(brain.strafe_face.global_position, delta)  # TACTICS: sidestep facing the prey
		elif brain and not is_pet and brain.own_yaw:
			pass  # CARNOFEEL: the brain turns the body with its travel (the arc after a charge)
		elif _face_vel.length() > FACE_MIN_SPEED_MPS:
			face_heading(_face_vel, delta)
		# Stride-matched gait by direction: forward walk/run, walk_back, strafe_left/right (no glide); a
		# brain's named gait (the charge) wins when the rig has it.
		var facing_prey: bool = brain != null and not is_pet and brain.strafe_face != null and is_instance_valid(brain.strafe_face)
		if brain and not is_pet and brain.gait_clip != &"":
			anim.set_gait_clip(brain.gait_clip, speed, dir * speed, global_basis)
		else:
			anim.set_move_velocity(dir * speed, global_basis, CreatureAnim.FACING_SIDE_DOT if facing_prey else CreatureAnim.SIDE_DOT)
		running = sprint
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_face_vel = _face_vel.lerp(Vector3.ZERO, 1.0 - exp(-delta / FACE_VEL_TAU_S))
		if not anim._busy and not anim._forced:
			anim.play_idle(brain != null and not is_pet and brain.aware_idle())
	_slide()
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

## Shove the body `push` metres (flat) over `seconds`, staggered meanwhile; the slide respects walls and props.
## TELEPORT FIX (owner 2026-10-31: "Pachy is teleporting", "Smilodon kind of teleports too"): the survivor's kick
## moved the target its whole 3.5 m push in one physics frame (move_and_collide); now it slides there.
func shove(push: Vector3, seconds: float) -> void:
	push.y = 0.0
	if seconds <= 0.0 or push.length_squared() <= 0.0:
		return
	_shove_s = seconds
	_shove_left = seconds
	_shove_v = push * (2.0 / seconds)  # linear decay from 2d/T to 0 covers d metres
	stagger_left = maxf(stagger_left, seconds)

## An animal standing still on the ground has nothing to slide (most of the idle cost), so it
## slides only every IDLE_SLIDE_EVERY frames: often enough to notice a floor that went away. The
## dead always slide: the corpse teleports them and the cached is_on_floor() is stale.
## A fading creature has a collapsed scale; sliding it inverts a singular basis and logged an
## engine error every physics frame (found by the survivor bot).
const IDLE_SLIDE_EVERY := 8
## Which of the IDLE_SLIDE_EVERY frames this animal slides on: spawn order, not the instance id, so a
## replay (t_tactical) slides on the same frames.
static var _slide_counter: int = 0
var _slide_phase: int = 0

func _slide() -> void:
	if not health.dead and is_on_floor() and velocity.length_squared() < 0.000001 \
			and (Engine.get_physics_frames() + _slide_phase) % IDLE_SLIDE_EVERY != 0:
		return
	if absf(global_transform.basis.determinant()) > 0.0001:
		move_and_slide()

func _size_collision() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = body_radius()
	# BIGREACH: never wider than the visible body (a stegosaurus's 2.4 m capsule held the survivor a metre
	# off its 1.3 m flank). body_radius() stays the AI's spacing size; melee reads this shape.
	var fp := footprint()
	cap.radius = maxf(0.18, minf(cap.radius, minf(-fp.position.x, fp.end.x) + 0.1))
	cap.height = maxf(cap.radius * 2.0 + 0.1, def.height_meters * size_scale())
	shape.shape = cap
	shape.position.y = cap.height * 0.5
	agent.path_desired_distance = 0.45
	agent.target_desired_distance = 0.9
	agent.radius = cap.radius

func _make_brain() -> void:
	if is_pet:
		brain = PetBrain.new()
	elif def and def.id == &"megarex":
		brain = MegaRexBrain.new()  # MEGAREX: the boss rex, three phases
	elif def and def.id == &"tyrannosaurus":
		brain = TyrantBrain.new()
	elif def and def.archetype == &"club_tail":
		brain = ClubTailBrain.new()  # ANKYLOAI: tail toward the threat, rare hard club hits
	elif def and TacticalBrain.has_tactics(def):
		brain = TacticalBrain.new()
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

var _fx_last := Vector2(-1.0, -1.0)
var _fx_tint_last := Color.WHITE

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
		tint = UiTokens.POISON  # owner 2026-10-28: no green debuffs
	if statuses.has(&"groggy") or statuses.has(&"dizziness"):
		wobble = 1.0
	if statuses.has(&"fracture"):
		ap.speed_scale = 0.65
	_sync_status_emitters()
	# set_status_fx rewrites every material; call it on change, or while the hit flash decays.
	var fx := Vector2(dark, wobble)
	if fx != _fx_last or tint != _fx_tint_last or view._hit_flash_left > 0.0:
		_fx_last = fx
		_fx_tint_last = tint
		view.set_status_fx(dark, tint, wobble)

## Status particle presets on the body (statuses.json fx.particles, e.g. enraged "blood"): a body
## emitter that drips and a mouth emitter that flecks, sized to the animal. Cheap CPU particles
## (Compatibility renderer), at most STATUS_EMITTERS_MAX per creature, freed when the status ends.
const STATUS_EMITTERS_MAX := 2
var status_emitters: Dictionary = {}  ## status id -> Array[CPUParticles3D]

func _sync_status_emitters() -> void:
	var want: Dictionary = {}
	if not health.dead:
		for inst in statuses.instances():
			var sd := Data.status(inst.id)
			if sd and sd.fx_particles == &"blood" and want.is_empty():  # one blood set (2 emitters) at most
				want[inst.id] = sd
	for id in status_emitters.keys():
		if not want.has(id):
			for e in status_emitters[id]:
				if is_instance_valid(e):
					(e as Node).queue_free()
			status_emitters.erase(id)
	for id in want:
		if status_emitters.has(id):
			continue
		var col: Color = (want[id] as StatusDef).fx_color
		var body := StatusFx.make_emitter(&"drip", col)
		body.emission_sphere_radius = body_radius() * 0.8
		body.position = Vector3(0.0, def.height_meters * 0.5, 0.0)
		var mouth := StatusFx.make_emitter(&"blood", col)
		mouth.emission_sphere_radius = 0.15
		mouth.position = Vector3(0.0, def.height_meters * 0.75, -body_radius() - 0.2)  # the head end (the body faces -Z)
		for e in [body, mouth]:
			(e as CPUParticles3D).name = "StatusFx_%s" % id
			add_child(e)
		status_emitters[id] = [body, mouth]

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
## Step outside it and the chase ends (BrainFlight.track). Vertices follow the
## terrain so the ring reads on slopes; rebuilt at 10 Hz while the creature moves.
func _update_aggro_ring(delta: float) -> void:
	# Debug only (owner 2026-10-28: the ring looks unpolished in normal play).
	var show := Game.debug_overlay and not is_pet and not health.dead and brain != null and brain.has_method("hunting_player") and brain.hunting_player()
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
		if Game.debug_overlay:
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
	label.visible = Game.debug_overlay
	if not label.visible:
		return  # the text was formatted every frame for every animal even while hidden
	var st := brain.state if brain else brain_state
	label.text = "%s\nLv %d %s / %s" % [def.id, level, st, anim.current_clip]
	label.position.y = def.height_meters * size_scale() + 0.4

func _on_windup(clip: StringName) -> void:
	if brain is ClubTailBrain: return  # it rings where the club will pass, not ahead of the snout
	Telegraph.show_for(self, clip)

func _on_hit(clip: StringName) -> void:
	if brain is TyrantBrain or brain is ClubTailBrain: return  # those brains land their own hits (ClubTailBrain: from the club)
	if clip == &"spit":  # SP-DILOPHOSAURUS: the spit's hit frame launches the venom glob; it lands its own hit
		if brain is TacticalBrain:
			(brain as TacticalBrain).launch_spit()
		return
	var target := brain.attack_target if brain else null
	if target:
		# A contact attack lands at impact, not anywhere the target ran during windup. HITBOXES: the
		# clip's attacking part (jaw, club, horns, feet) must have swept through one of its hurtboxes.
		var offset := global_position - target.global_position
		if Hitbox.applies(self, target):
			var hit := Hitbox.strike(self, clip, target as Node3D, anim.hit_index)
			if hit.is_empty():
				if target is Player or target is Creature:
					CombatAvoid.avoided(target, self, &"miss")  # the jaws closed on air
				return
			Hitbox.mark(target, hit)
		elif brain and (Vector2(offset.x, offset.z).length() > brain.reach_to(target) + 0.3 or not part_hit(clip, target)):
			if target is Player or target is Creature:
				CombatAvoid.avoided(target, self, &"miss")  # it snapped at air: the prey was out of reach
			return
		if not CreatureAttack.apply_for(self, clip, target, brain.hit_damage_mult(clip, anim.hit_index) if brain else 1.0):
			return
		if target is Player:
			(target as Player).receive_creature_hit(self, clip)
		if brain is TacticalBrain:
			(brain as TacticalBrain).landed(clip, target)

## Where a move hits a body without hurtboxes (a structure; species JSON pipeline.hit_parts.<clip>: {bones,
## radius_m}). HITBOXES: against hurtboxes those bones are the move's parts in hitboxes.json instead: at
## the hit frame one of the named bones must be within radius_m (x body size) of the target's body, a vertical
## segment from its feet to its height. True when the species lists no parts for the clip or the rig lacks them.
func part_hit(clip: StringName, target: Node3D) -> bool:
	# A body variant may judge its hits at its own parts (SP-TRIKEALPHA: model_variants.alpha.hit_parts).
	var parts: Variant = CreatureView.variant_row(def, variant).get("hit_parts", def.pipeline.get("hit_parts")) if def else null
	var row: Variant = (parts as Dictionary).get(str(clip)) if parts is Dictionary else null
	var sk: Skeleton3D = view.rig.skeleton if view and view.rig else null
	if not (row is Dictionary) or sk == null or target == null:
		return true
	var tr := (target as Creature).body_radius() if target is Creature else 0.35
	var th := (target as Creature).def.height_meters * (target as Creature).size_scale() if target is Creature else 1.78
	var r := float((row as Dictionary).get("radius_m", 1.0)) * size_scale() + tr
	var base := target.global_position
	var found := false
	for b in (row as Dictionary).get("bones", []):
		var i := sk.find_bone(str(b))
		if i < 0:
			continue
		found = true
		var p := sk.global_transform * sk.get_bone_global_pose(i).origin
		var y := clampf(p.y, base.y, base.y + th)
		if p.distance_to(Vector3(base.x, y, base.z)) <= r:
			return true
	return not found

func _on_attack_done() -> void:
	pass

func _on_kd_start() -> void:
	is_capturable = true
	FieldTame.begin_window(self)

func _on_kd_end() -> void:
	is_capturable = false

## PINFEEL: Pinned landed on `victim` from this predator's hit. A rig with pin_foot plants the foot on it and
## holds until the status ends (_tick_pin); the victim is laid on its back and kept under the claws (PinHold).
func start_pin(victim: Node3D) -> void:
	if pin_victim != null or health.dead or ridden or not anim.start_pin():
		return
	pin_victim = victim
	stop_move()
	PinHold.lay_down(self, victim)
	print("[combat] %s pins %s" % [def.id, victim.name])

func end_pin() -> void:
	if pin_victim == null:
		return
	pin_victim = null
	anim.end_pin()

func _tick_pin(delta: float) -> void:
	if not PinHold.holds(self, pin_victim):
		end_pin()
		return
	PinHold.snap(self, pin_victim, delta)

func _on_status_removed(id: StringName) -> void:
	if id == &"pinned" and not statuses.has(&"knockdown"):
		anim.hold_down(false)
	if id != &"knockdown":
		return
	if statuses.has(&"pinned"):
		is_capturable = false  # still held down: the pin keeps the pose
		return
	if anim and anim._hold_knockdown:
		anim.release_knockdown()
	is_capturable = false
	if tame_attempting and def and tame_feeds + 0.001 < feeds_needed() and not is_pet:
		FieldTame.fail(self, null)

func torpor_max() -> float:
	return CombatTuning.num("torpor", "max", 100.0)

func torpor_frac() -> float:
	return clampf(torpor / maxf(1.0, torpor_max()), 0.0, 1.0)

## Add torpor from a hit; a weak animal pushed past the threshold collapses (the knockdown status,
## so the feeding tame window and the collapse clip follow the existing path).
func add_torpor(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or is_pet or health == null or health.dead:
		return
	torpor = minf(torpor_max(), torpor + amount)
	_torpor_quiet_s = 0.0
	if statuses != null and not statuses.has(&"knockdown") and def != null and def.tameable and FieldTame.capture_window(self):
		statuses.apply(&"knockdown", source)
		if anim:
			anim.play_clip(&"knockdown")
		print("[torpor] %s knocked out torpor=%.0f hp=%.0f%%" % [def.id, torpor, 100.0 * health.fraction()])

## ASSUMPTION: torpor holds while the animal is knocked down and for decay_delay_s after the last
## dose, then drains at decay_per_s (combat_tuning.json "torpor").
func tick_torpor(delta: float) -> void:
	if torpor <= 0.0 or (statuses != null and statuses.has(&"knockdown")):
		return
	_torpor_quiet_s += delta
	if _torpor_quiet_s >= CombatTuning.num("torpor", "decay_delay_s", 6.0):
		torpor = maxf(0.0, torpor - CombatTuning.num("torpor", "decay_per_s", 3.0) * delta)

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
	# A groggy animal collapses on the next hit once it is already capturable by health.
	# ASSUMPTION: the collapse itself still needs <= 30 % (spec 09's stun-at-any-HP is the
	# knockdown status from other sources); moving this above 30 % would collapse every
	# tackled animal, which is a balance change the spec does not ask for.
	if statuses.has(&"groggy") and not statuses.has(&"knockdown") 			and FieldTame.health_allows_capture(health.fraction()):
		statuses.apply(&"knockdown", source)
		anim.play_clip(&"knockdown")
		return
	var staggered := false
	var armored: bool = brain is TyrantBrain or (brain != null and brain.super_armor())  # a committed charge does not flinch
	if not armored and _now_s() >= _stagger_immune_until:
		stagger_left = 0.45 if kind == &"crit" else 0.3
		_stagger_immune_until = _now_s() + 1.0
		staggered = true
	if not armored and not anim.current_clip in CreatureAnim.ATTACKS:  # a hit never cuts a bite or the combo short
		var authored: Dictionary = def.pipeline.get("authored_clips", {})
		# The authored hurt clip plays when the rig has one (the test was inverted), gated by the
		# stagger's once-a-second immunity so a pinned animal can still fight back.
		if staggered and authored.has("hit_react") and view.using_glb and not anim._hold_knockdown:  # down (pin, knockdown): stays down
			anim.play_clip(&"hit_react")
			if view.planted:  # the clip may shove the body over its feet; hold them where they stand
				view.planted.pin(1.5, func() -> bool: return anim.current_clip == &"hit_react")
		else:
			view.flinch(1.4 if kind == &"crit" else 1.0)  # no real hurt clip: shove + nod instead
	if source:
		aggroed.emit(source)
		if brain:
			brain.on_aggro(source)

func _on_died(_source: Node) -> void:
	_sync_status_emitters()  # the dead stop bleeding with rage
	if not is_pet:
		var credited := _source
		if _source is FieldCatapult and is_instance_valid((_source as FieldCatapult).operator):
			credited = (_source as FieldCatapult).operator
		World.record_raid_kill(def.id, credited)
		if PlayerRegistry.credit_for(credited) != null:
			Tasks.note(&"hunt")  # TASKSCREEN: a kill by the survivor or her pet counts toward the hunt tasks
	pin_victim = null  # the death clip ends the pin pose; the victim's status runs out on its own
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
		var owner := PlayerRegistry.credit_for(_source)
		if owner == null:
			owner = PlayerRegistry.nearest(global_position)
		# Typed fallback: an untyped [] literal raised here when no survivor is around (headless kills).
		var pets: Array[Creature] = []
		if owner:
			pets = owner.live_pets()
		for pet in pets:
			if pet == null or pet.pet_record == null or pet.health.dead:
				continue
			var amount := 0.0
			if killer_pet == pet:
				amount = 10.0 + float(def.tier) / 3.0
			elif pet.global_position.distance_to(global_position) <= 15.0:
				amount = 3.0 + float(def.tier) / 6.0  # assist: fighting alongside whoever landed the kill
			amount *= kill_xp_mult()
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
		var p := PlayerRegistry.credit_for(_source)
		var xp := kill_xp(def.tier)
		if p and p.skills:
			p.skills.add_xp("melee", xp)
		else:
			World.add_xp(xp)
		print("[combat] %s killed: +%d xp" % [def.id, xp])
	view.set_status_fx(0.35, Color(0.62, 0.62, 0.62), 0.0)
	collision_layer = 0
	collision_mask = 1
	stop_move()
	# Bonded animals enter their respawn cooldown without creating a harvestable corpse or
	# loot bag. Wild kills still use the normal corpse/loot flow.
	var corpse: Corpse = null
	if not is_pet:
		corpse = Corpse.new()
		corpse.setup(self)
		get_parent().add_child(corpse)
		corpse.global_position = global_position
	# Client-side presentation: hit reaction, ragdoll (or death clip) and the corpse's resting place.
	Ragdoll.on_death(self, _source, corpse)

## ALPHAS: an alpha's kill pays ai.json alpha.xp_mult times the XP (bonus XP); 1.0 otherwise.
func kill_xp_mult() -> float:
	return float(CreatureGenetics.alpha_rules().get("xp_mult", 4.0)) if is_alpha() else 1.0

## The survivor's melee XP for this kill: 4 + tier / 5, times kill_xp_mult().
func kill_xp(tier: int) -> int:
	return int(round(float(4 + tier / 5) * kill_xp_mult()))

## Status landed: float its name over the plate and puff a burst in its colour. The lasting
## look (blood drip, venom tint, wobble) is _status_fx every frame.
func _on_status_applied(id: StringName, _stacks: int) -> void:
	if health.dead:
		return
	if id == &"pinned" and not statuses.has(&"knockdown"):
		anim.hold_down(true)  # PINFEEL: on the ground for the pin, in the knockdown pose
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

## NavigationAgent3D advances its waypoint by 3D distance, but lab nav meshes sit ~0.5 m above the
## floor, so it kept handing back the waypoint under our feet (an in-place jitter once brains
## stopped re-targeting every frame). Take the first waypoint that is far enough in the flat plane
## and not already behind us (the stuck start waypoint pulled the alpha back and forth in place).
func _agent_direction() -> Vector3:
	agent.get_next_path_position()  # refreshes the path for a new target; reading it alone went stale
	var path := agent.get_current_navigation_path()
	var here := Vector2(global_position.x, global_position.z)
	for i in range(agent.get_current_navigation_path_index(), path.size()):
		var wp := Vector2(path[i].x, path[i].z)
		if here.distance_to(wp) <= agent.path_desired_distance:
			continue
		if i + 1 < path.size():
			var nxt := Vector2(path[i + 1].x, path[i + 1].z)
			if here.distance_to(nxt) < wp.distance_to(nxt):
				continue  # already past this waypoint
		var to := wp - here
		return Vector3(to.x, 0.0, to.y).normalized()
	return Vector3.ZERO

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

## Starter overrides win; otherwise species tier + the ring's level_offset + the island row's
## tier_offset. The runtime comes from the Spawner because World.runtime is only assigned after
## the island build that spawns everything (the old lookup fell back to the bare tier).
func _spawn_level(rt: Node, tier_offset: int) -> int:
	var cap := int(Data.world_rules.get("level_cap", 60))
	var island: Dictionary = World.island_def if World else {}
	if int(island.get("level_override", 0)) > 0:
		return ProgressionScaling.resolved_spawn_level(def.tier, island, cap)
	if rt == null and World and World.runtime and get_parent() == World.runtime:
		rt = World.runtime
	if rt == null or not rt.has_method("ring_name"):
		return def.tier
	var rings: Dictionary = Data.world_rules.get("rings", {})
	var row: Variant = rings.get(str(rt.ring_name(global_position)), {})
	var offset := int((row as Dictionary).get("level_offset", 0)) if row is Dictionary else 0
	return clampi(def.tier + offset + tier_offset, 1, cap)

func _now_s() -> float:
	return float(Time.get_ticks_msec()) * 0.001

func _set_vis_range(n: Node, end_dist: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = end_dist
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		_set_vis_range(c, end_dist)

## Movement control only: brain/attacks stay live. Giant families reject light snares.
func apply_trap_control(heavy: bool) -> bool:
	if health.dead or is_pet or trap_left > 0.0 or trap_immunity_left > 0.0: return false
	var family := CombatCounters.family(def.archetype)
	if family in ["armored", "giant"] and not heavy: return false
	var row: Dictionary = CombatCounters.data().get("trap_control", {}).get(family, {})
	if row.is_empty(): return false
	trap_left = float(row.get("seconds", 0.0))
	trap_move_mult = float(row.get("move_mult", 1.0))
	status_float.emit(&"slowed" if trap_move_mult > 0.0 else &"rooted")
	return true

func tick_trap_control(delta: float) -> void:
	if trap_left > 0.0:
		trap_left = maxf(0.0, trap_left - delta)
		if trap_left == 0.0:
			trap_move_mult = 1.0
			trap_immunity_left = 10.0
	else:
		trap_immunity_left = maxf(0.0, trap_immunity_left - delta)
