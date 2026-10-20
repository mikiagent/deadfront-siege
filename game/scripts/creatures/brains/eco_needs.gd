class_name EcoNeeds
extends RefCounted
## Wild hunger and thirst (brain.needs) and the errands that fix them: eat_corpse, graze and
## drink. Fullness runs 0..1 (1 = fed / quenched) and drains while the brain thinks, so animals
## frozen by the AI LOD far from every player do not starve. Carnivores also hunt (the brain's
## approach/attack states do the hunting; this only picks the prey).

const SEARCH_EVERY_S := 1.0
const EAT_EVERY_S := 1.5
## ASSUMPTION: one meat unit fills a third of a stomach, a graze half, a drink all of it; an errand
## that has not arrived after ERRAND_MAX_S gives up (blocked path, water moved by a gate).
const MEAT_FILL := 0.34
const GRAZE_FILL := 0.5
const GRAZE_S := 4.0
const DRINK_S := 4.0
const ERRAND_MAX_S := 30.0
const ERRANDS: Array[StringName] = [&"eat_corpse", &"graze", &"drink"]

var hunger: float = 1.0
var thirst: float = 1.0
var food_target: Node3D
var water_point: Vector3 = Vector3.INF
var graze_point: Vector3 = Vector3.INF
var _b: CreatureBrain
var _search_at: float = 0.0
var _act_left: float = 0.0
var _errand_left: float = 0.0
var _eat_cd: float = 0.0

func _init(brain: CreatureBrain) -> void:
	_b = brain
	# ASSUMPTION: wild animals spawn 50-100 % fed and watered, so a fresh island has no feeding frenzy.
	hunger = randf_range(0.5, 1.0)
	thirst = randf_range(0.5, 1.0)
	brain.state_changed.connect(_on_state_changed)

## Leaving an errand by any route (spotted, hit, woken) releases the held feed pose.
func _on_state_changed(prev: StringName, next: StringName) -> void:
	if prev in ERRANDS and not next in ERRANDS:
		food_target = null
		_act_left = 0.0
		var c := _b.creature
		if c and c.anim and c.anim._forced:
			c.anim.play_clip(&"idle")

func is_hungry() -> bool:
	return hunger < float(_b.profile.get("hungry_below", 0.35))

func is_thirsty() -> bool:
	return thirst < float(_b.profile.get("thirsty_below", 0.3))

func diet() -> StringName:
	return StringName(str(_b.profile.get("diet", "herbivore" if _b._is_herbivore() else "carnivore")))

func busy() -> bool:
	return _b.state in ERRANDS

func drain(dt: float) -> void:
	hunger = maxf(0.0, hunger - dt / maxf(1.0, float(_b.profile.get("hunger_full_s", 480.0))))
	thirst = maxf(0.0, thirst - dt / maxf(1.0, float(_b.profile.get("thirst_full_s", 360.0))))

## One think for the needs layer. Runs an errand in progress, or starts one from a calm state.
## True when it handled the tick.
func tick(dt: float) -> bool:
	if busy():
		_errand(dt)
		return true
	if not (_b.state == &"roam" or _b.state == &"disengage") or _b._valid_target():
		return false
	if not (is_hungry() or is_thirsty()):
		return false
	return _choose()

## Water first (the quick fix), then food by diet. A pack follower eats with its alpha.
func _choose() -> bool:
	var now := _b._now_s()
	if now < _search_at:
		return false
	_search_at = now + SEARCH_EVERY_S
	var leader := _b._pack_leader()
	if leader and leader != _b.creature and not _b._is_herbivore():
		var lb := leader.brain
		if lb and lb.needs and lb.state == &"eat_corpse" and is_hungry() and EcoSense.has_meat(lb.needs.food_target as Corpse):
			food_target = lb.needs.food_target
			_start(&"eat_corpse")
			return true
		return false  # packs travel and hunt behind the alpha
	if is_thirsty():
		var w := _b.sense.find_water(float(_b.profile.get("water_search_m", 40.0)))
		if w != Vector3.INF:
			water_point = w
			_start(&"drink")
			return true
	if not is_hungry():
		return false
	if diet() == &"herbivore":
		var centre := _b._herd_center()
		var roam := float(_b.profile.get("roam_tiles", 6.0))
		var want := centre + Vector3(randf_range(-roam, roam), 0.0, randf_range(-roam, roam))
		graze_point = _b._walkable_probe(centre, want, int(roam) + 3)
		_start(&"graze")
		return true
	var corpse := _b.sense.find_corpse(float(_b.profile.get("food_search_m", 30.0)))
	if corpse:
		food_target = corpse
		_start(&"eat_corpse")
		return true
	if diet() == &"carnivore":
		var prey := _b.sense.find_prey()
		if prey:
			_b.hunt_prey(prey)
			return true
	return false

func _start(errand: StringName) -> void:
	_errand_left = ERRAND_MAX_S
	_act_left = 0.0
	_eat_cd = 0.0
	_b._set_state(errand)

func _errand(dt: float) -> void:
	_errand_left -= dt
	if _errand_left <= 0.0:
		end()
		return
	match _b.state:
		&"drink":
			if _arrive(water_point, 1.0, dt):
				thirst = 1.0
				end()
		&"graze":
			if _arrive(graze_point, 0.8, dt):
				hunger = minf(1.0, hunger + GRAZE_FILL)
				if is_hungry():
					_choose_again()
				else:
					end()
		&"eat_corpse":
			var corpse := food_target as Corpse
			if not EcoSense.has_meat(corpse) or hunger >= float(_b.profile.get("sated_above", 0.95)):
				end()
				return
			if _arrive(corpse.global_position, 1.3, dt, true):
				pass
	# Feeding animals still watch for the survivor and pets (and run from them, or fight).
	if busy():
		_b._scan()

## Walk to p; once there, stand and feed for the errand's time. Returns true when it finished.
## eat=true feeds in bites from the corpse until full or the meat is gone.
func _arrive(p: Vector3, extra: float, dt: float, eat: bool = false) -> bool:
	if p == Vector3.INF:
		end()
		return false
	var c := _b.creature
	if _b._flat_dist_to(p) > c.body_radius() + extra:
		c.move_to(p)
		_act_left = 0.0
		return false
	c.stop_move()
	c.face_towards(p, 1.0)
	if _act_left <= 0.0:
		_act_left = DRINK_S if _b.state == &"drink" else GRAZE_S
		c.anim.play_clip(&"feed", true)
	if eat:
		_eat_cd -= dt
		if _eat_cd <= 0.0:
			_eat_cd = EAT_EVERY_S
			var corpse := food_target as Corpse
			if corpse.loot.consume_by_category(&"meat", 1):
				hunger = minf(1.0, hunger + MEAT_FILL * clampf(4.0 / maxf(1.0, c.def.real_length_m), 0.25, 2.0))
		return false
	_act_left -= dt
	return _act_left <= 0.0

func _choose_again() -> void:
	_search_at = 0.0
	end()
	_choose()

## Back to roaming (the brain's normal idle); _on_state_changed releases the pose.
func end() -> void:
	if busy():
		_b._set_state(&"roam")
