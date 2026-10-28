class_name Player
extends CharacterBody3D
## The survivor. This node owns the state other systems read (bag, vitals, statuses, hunt, pets,
## work targets) and wires five parts that do the work: PlayerSim (movement, roll, routes, sleep),
## PlayerView (rig on the floor, markers, lantern, footsteps, the ear, UI hosts), PlayerInput
## (keys, pad, taps, context hexes), PlayerActions (every verb that changes the world; the only
## layer that will talk to the W3 server) and PlayerPets (summon, pet menu, riding).

## A footfall: foot 0/1, surface = island TileType under her (-1 off island, -2 water), speed m/s.
signal footstep(foot: int, surface: int, speed: float)

const MAX_PETS_OUT := PlayerPets.MAX_OUT
const GATHER_FATIGUE_PER_UNIT := PlayerActions.GATHER_FATIGUE_PER_UNIT

@export var walk_speed: float = 5.5
## Tap-to-walk pace (runs; keys/joystick without sprint walk). Faster than a chasing compy.
@export var run_speed: float = 7.0
@export var sprint_speed: float = 8.5
@export var accel: float = 30.0
@export var turn_speed: float = 14.0

@onready var visual: Node3D = $Visual
@onready var rig: RiggedModel = $Visual/Rig
@onready var anim: PlayerAnim = $Anim
@onready var agent: NavigationAgent3D = get_node_or_null("Agent")

var sim: PlayerSim
var view: PlayerView
var controls: PlayerInput
var actions: PlayerActions
var pets: PlayerPets

var inventory: Inventory = Inventory.new() # Inventory.BASE_SLOTS (pack 05)
var vitals: Vitals
var statuses: StatusEffects
var hunt: Hunt
var placer: BuildPlacer
var skills: SkillState
var equipment: PlayerEquipment
var ui: InventoryUI
var craft_ui
## The Craft/Build construction menu (BuildUI); HuntHud creates it on first use, so a lab without
## the HUD still opens sites through actions.building_interact only when one exists.
var build_ui
var station_craft: StationCraft
var eat_session: EatSession
var food_buffs := FoodBuffState.new()
var bonded: Array[PetRecord] = []
var mounted_on: Creature
## Saddled mounts (mount.json): the rig follows the saddle bone while this is set.
var _saddle_view: CreatureView
var rolling: bool = false
## Feet under the water plane (river or sea); PlayerSim sets it every physics frame (WaterAccess).
var in_water: bool = false
## Deep enough that the survivor is buoyant rather than wading; PlayerSim owns the transition.
var swimming: bool = false
## Persistent mobile/desktop sprint mode. The keyboard/gamepad hold action still works alongside it.
var sprint_toggled: bool = false
## The climate of the island the survivor is on, set by the island each frame. The fatigue panel reads it.
var current_climate: String = ""
## True from the fatal hit until respawn(): no input, no regen, creatures lose interest,
## the death clip plays once and the rig stays on the floor. The HUD shows You Died + Respawn.
var dead: bool = false
## Presentation only: who landed the hit that left the survivor down. Cleared on respawn.
var downed_by: String = ""
var _last_hit_taken_s: float = -999.0
## Skill node bonuses cached by the SP spent, so refresh_equipment_vitals (every frame) does not walk trees.json.
var _skills_bonus_sp: int = -1
var _skills_health_bonus: float = 0.0
var _sleep_left: float = 0.0

# Work in progress. PlayerActions drives these; labs, the HUD and the anim tick read them.
var gather_target: HarvestNode
var butcher_target: Corpse
var tame_target: Creature
var tame_food_id: StringName = &""
var _gathering: bool = false
var _gather_left: float = 0.0
var _gather_ring
var _gather_radial: GatherRadial
var _field_radial_target: FieldPlot
var _field_radial_opts: Array = []
# Tap-to-walk route (PlayerSim keeps the waypoints).
var nav_active: bool = false
var _path_goal: Vector3 = Vector3.ZERO

## Pets out right now (PlayerPets keeps the list). `summoned_pet` is the first one, for old callers.
var summoned_pets: Array[Creature]:
	get:
		return pets.live()
var summoned_pet: Creature:
	get:
		var out := summoned_pets
		return out[0] if not out.is_empty() else null
	set(v):
		if v and is_instance_valid(v) and not pets.summoned.has(v):
			pets.summoned.append(v)

## The parts exist from construction, so a Player made with new() (tests, fixtures) can act too.
func _init() -> void:
	sim = PlayerSim.new(self)
	view = PlayerView.new(self)
	controls = PlayerInput.new(self)
	actions = PlayerActions.new(self)
	pets = PlayerPets.new(self)

func _ready() -> void:
	if Game.lab_name != "" and get_parent() and get_parent().name == "DefaultPlayfield":
		visible = false
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	add_to_group(PlayerRegistry.GROUP)
	if agent == null:
		agent = _child(NavigationAgent3D.new(), "Agent")
	vitals = _child(Vitals.new(), "Vitals")
	statuses = _child(StatusEffects.new(), "StatusEffects")
	hunt = _child(Hunt.new(), "Hunt")
	hunt.setup(self)
	placer = _child(BuildPlacer.new(), "Placer")
	view.setup()
	skills = _child(SkillState.new(), "Skills")
	view.setup_ui()
	vitals.damaged.connect(_on_vitals_damaged)
	vitals.died.connect(_on_vitals_died)

func _child(n: Node, node_name: String) -> Node:
	n.name = node_name
	add_child(n)
	return n

func _physics_process(delta: float) -> void:
	refresh_equipment_vitals()
	sim.fall_guard()
	for rec in bonded:
		rec.tick_respawn(delta)
	if dead:
		sim.hold_still(delta)
	else:
		view.draw_path_line(delta)
		food_buffs.tick(delta)
		sim.tick_survival_xp(delta)
		sim.tick_autofeed(delta)
		controls.tick_hold_walk(delta)
		sim.tick(delta)
	view.tick(delta)

func _input(event: InputEvent) -> void:
	controls.handle_input(event)

func _unhandled_input(event: InputEvent) -> void:
	controls.handle_unhandled(event)

## Capsule half height: the body's origin is the capsule centre, her feet are this far below it.
# ASSUMPTION: a 2.0 m capsule holds the 1.72 m model with its 1.18 legibility lift (pc-misc-01).
func half_height() -> float:
	var shape := get_node_or_null("Shape") as CollisionShape3D
	var cap := shape.shape as CapsuleShape3D if shape else null
	return cap.height * 0.5 if cap else 1.0

func feet_position() -> Vector3:
	return global_position - Vector3(0.0, half_height(), 0.0)

func is_swimming() -> bool:
	return swimming

## The selected resource or animal that the follow camera should leave room for.
func camera_interest() -> Node3D:
	if hunt and hunt.target and is_instance_valid(hunt.target):
		return hunt.target
	if tame_target and is_instance_valid(tame_target):
		return tame_target
	if gather_target and is_instance_valid(gather_target):
		return gather_target
	if _gather_radial:
		var radial_target: Variant = _gather_radial.focus_node()
		if radial_target is Node3D and is_instance_valid(radial_target):
			return radial_target as Node3D
	return null

func toggle_sprint() -> bool:
	sprint_toggled = not sprint_toggled
	return sprint_toggled

## Combat mode targets the nearest wild animal; a second tap cleanly disengages.
func toggle_combat() -> bool:
	if hunt == null:
		return false
	if hunt.target and is_instance_valid(hunt.target):
		hunt.stop()
		return false
	var target := actions.nearest_creature(PlayerActions.ATTACK_SEEK_RANGE, false)
	if target == null:
		notice("No animal in range")
		return false
	hunt.start(target)
	return true

# ---------------------------------------------------------------- movement, facing

func nav_to(pos: Vector3) -> void:
	sim.nav_to(pos)

func clear_nav() -> void:
	sim.clear_nav()

## Turn toward a point over time (combat facing while swinging).
func face_world_smooth(pos: Vector3, delta: float, speed: float = 12.0) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to.x, -to.z), clampf(speed * delta, 0.0, 1.0))

func face_world(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		visual.rotation.y = atan2(-to.x, -to.z)  # RiggedModel faces -Z; yaw so -Z points at the target

func _nearest_group(group: String) -> Node3D:
	var best: Node3D = null
	var best_d := 999.0
	for n in get_tree().get_nodes_in_group(group):
		var d := global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best

# ---------------------------------------------------------------- verbs (PlayerActions)

## A station tap opens its hex interact menu over the station; CRAFT/COOK open the craft sheet.
func open_station_craft(st: Node3D) -> void:
	# A station click wins over an in-flight ground move. StationMenu intentionally dismisses
	# while nav_active, so leaving the old route alive made the ring open and close in one frame.
	clear_nav()
	if station_craft:
		station_craft.open_station_menu(st)

## From the craft menu: craft `count` of a recipe (walks to the station if needed).
func craft_recipe(rid: StringName, count: int = 1) -> void:
	actions.craft(rid, count)

func begin_eat_slot(index: int) -> bool:
	return actions.eat(index)

func apply_food_buff(buff_id: StringName, row: Dictionary) -> void:
	food_buffs.apply(buff_id, row)

func food_buff_mult(stat: String) -> float:
	return food_buffs.multiplier(stat)

func open_field(field: FieldPlot) -> void:
	if field == null or _gather_radial == null:
		return
	_field_radial_target = field
	_field_radial_opts = field.radial_options(self)
	_gather_radial.open_options(field, "Field", 1, 0.4, _field_radial_opts, inventory)

func coat_weapon() -> bool:
	return actions.coat_weapon()

func place_snare(id: StringName) -> bool:
	return actions.place_snare(id)

## Context hexes shown by the HUD, bottom-right (reference: drink/wash by water, cook at the fire…).
func context_actions() -> Array:
	return controls.context_actions()

func context_action(id: String) -> void:
	controls.context_action(id)

# Old entry points that labs, probes and the HUD still call; each forwards to its part.
func _try_roll() -> void: sim.try_roll(sim.cam_dir(sim.input_vector()))
func _start_sleep(spot: Node3D = null) -> void: sim.start_sleep(spot)
func _closest_nav_point(pos: Vector3) -> Vector3: return sim.closest_nav_point(pos)
func _begin_gather(node: HarvestNode) -> void: actions.begin_gather(node)
func _finish_gather() -> void: actions.finish_gather()
func _stop_gather_cycle(fade_ring: bool = true) -> void: actions.stop_gather_cycle(fade_ring)
func _cancel_gather_and_butcher() -> void: actions.cancel_work()
func _auto_equip_tool(tool_class: StringName) -> bool: return actions.auto_equip_tool(tool_class)
func _begin_field_tame(c: Creature) -> void: actions.begin_field_tame(c)
func _begin_corpse_take(corpse: Corpse, slot: int) -> void: actions.begin_corpse_take(corpse, slot)
func _building_interact(b: Node) -> void: actions.building_interact(b)
func _on_arrived() -> void: actions.on_arrived()
func _interact_tap_target(col: Object) -> void: controls.interact_tap_target(col)
func _is_interactable(col: Object) -> bool: return controls.is_interactable(col)
func _unwrap_tap(col: Object) -> Object: return controls.unwrap_tap(col)

## Lab/test helper: tap a screen point as a finger would.
func debug_tap_screen(screen_pos: Vector2) -> StringName:
	Game.pointer = screen_pos
	return controls.tap_world()

## Lab/test helper: open the radial on a node as a tap would.
func debug_open_radial(node: HarvestNode) -> void:
	if node and _gather_radial:
		_gather_radial.open(node, node.options(), inventory)

# ---------------------------------------------------------------- pets (PlayerPets)

func live_pets() -> Array[Creature]:
	return pets.live()

## Toggle one bonded record: dismiss it if it is out, else summon it (up to MAX_PETS_OUT out).
func summon_pet(index: int = 0) -> void:
	pets.summon(index)

func bond_from_inventory() -> void:
	pets.bond_from_inventory()

## Whistle: "attack" sics the pets on the current target, "heel" calls them back, "guard" is the default.
func pet_order(cmd: StringName) -> void:
	pets.order(cmd)

func feed_summoned_pet_slot(index: int) -> bool:
	return pets.feed_slot(index)

func mount(c: Creature) -> void:
	pets.mount(c)

func dismount() -> void:
	pets.dismount()

# ---------------------------------------------------------------- presentation hooks

func play_punch() -> void:
	if anim:
		anim.on_punch()

func play_attack(heavy: bool = false) -> void:
	if anim:
		anim.on_attack(heavy)

## Bite/crunch overlay and a red damage number over the survivor (HUD).
func take_hit_fx(amount: float, heavy: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("bite_on_player"):
		hud.bite_on_player(amount, heavy)

func toast(id: StringName, n: int) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("toast"):
		hud.toast(id, n)

## Short on-screen line for refusals and hints (was print-only, so the game looked stuck).
func notice(text: String) -> void:
	print("[ui] notice %s" % text)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("notice"):
		hud.notice(text)

func right_hand_anchor() -> Marker3D:
	return view.right_hand_anchor()

func hips_anchor() -> Marker3D:
	return view.hips_anchor()

func display_name() -> String:
	if World.player_name != "":
		return World.player_name
	return str(view.survivor_meta().get("display_name", "Survivor"))

# ---------------------------------------------------------------- damage, death, respawn

## Worn gear's health bonus, plus the skill nodes whose stat effect the game runs (Defense's Max Health I-III,
## Survival's Belly Fat 1): SkillRules.ability totals, recounted here so a purchase shows the next frame.
func refresh_equipment_vitals() -> void:
	if vitals and inventory:
		vitals.equipment_health_bonus = inventory.equipped_health_bonus()
		if skills and skills.sp_spent != _skills_bonus_sp:
			# Recount only when a purchase or refund changed (this runs every physics frame): the totals
			# walk every node in trees.json.
			_skills_bonus_sp = skills.sp_spent
			_skills_health_bonus = float(SkillRules.ability(skills, "max_health"))
			vitals.energy_bonus = float(SkillRules.ability(skills, "max_energy"))
		if skills:
			vitals.equipment_health_bonus += _skills_health_bonus
		vitals.health = minf(vitals.health, vitals.effective_max_health())

func receive_creature_hit(who: Creature, _clip: StringName) -> void:
	_last_hit_taken_s = Time.get_ticks_msec() * 0.001
	if who and who.def:
		downed_by = str(who.def.id).replace("_", " ").capitalize()
	actions.cancel_work()
	# Self-defence: bitten with no live target -> turn on the biter (auto-attack takes it from there).
	if not dead and hunt and who and not who.is_pet and not who.health.dead:
		var cur := hunt.target
		if cur == null or not is_instance_valid(cur) or cur.health.dead or global_position.distance_to(cur.global_position) > 6.0:
			hunt.start(who)
			print("[combat] retaliate %s" % who.def.id)
	if skills:
		skills.add_xp("defense", 1)
	vitals.add_fatigue(2.0, &"combat")
	WaterAccess.soil(self, &"hit")
	_flinch()
	sim.on_hit()

## Hit reaction clip; a roll in flight keeps its clip (the roll cancels the flinch, not the reverse).
func _flinch() -> void:
	if anim == null or rolling:
		return
	if statuses and statuses.has_flag(&"knockdown"):
		anim.play_clip(&"knockdown")
	else:
		anim.on_damaged()

func _on_vitals_damaged() -> void:
	if statuses.ticking and (sim.rest.resting or _sleep_left > 0.0 or sim._sleep_pending != null):
		return  # a bleed or stomachache tick hurts, but only hits and fights end a rest, a sleep or the walk to bed (spec 01:19)
	sim.interrupt_sleep()
	actions.cancel_work()
	_flinch()

func _on_vitals_died() -> void:
	if dead:
		return
	dead = true
	sim.interrupt_sleep()
	clear_nav()
	view.clear_ground_marker()
	actions.cancel_work()
	if hunt:
		hunt.stop()
	if mounted_on:
		dismount()
	if placer and placer.placing != &"":
		placer.cancel()
	if anim:
		anim.on_death()
	# Every wild dinosaur engaged with this survivor relocates beyond its immediate aggro ring.
	# This happens before respawn, so the new life never begins beside the same killer/pack.
	for node in get_tree().get_nodes_in_group("creatures"):
		var creature := node as Creature
		if creature and creature.brain and creature.brain.has_method("on_player_killed"):
			creature.brain.on_player_killed(global_position)
	print("[player] died")

## Respawn at the camp (home tile) with half health; statuses cleared. Called by the HUD button.
func respawn() -> void:
	if not dead:
		return
	dead = false
	downed_by = ""
	if statuses:
		statuses.clear_all()  # also gives back what a status took off max HP (SAVEFIX)
	vitals.revive(0.5)
	var at := global_position
	if World.runtime and World.runtime.get("_camp_pos") != null:
		at = World.runtime.get("_camp_pos") as Vector3
		if World.runtime.has_method("surface_y"):
			at.y = World.runtime.surface_y(at.x, at.z) + 0.6
		else:
			at.y += 0.6
	velocity = Vector3.ZERO
	global_position = at
	reset_physics_interpolation()
	if anim:
		anim.revive()
	print("[player] respawn at %s" % at)

# ---------------------------------------------------------------- climate

## Climate tokens in data/world/climates.json, grouped by what resists them. Weak = 1 point, high = 2,
## volcanic = 3. Humidity and sun add one point of pressure to the heat group, wind to the cold group.
const _HEAT_TOKENS := {"heat_weak": 1, "heat_high": 2, "heat_volcanic": 3}
const _COLD_TOKENS := {"cold_weak": 1, "cold_high": 2}

## Resistance points the survivor has now. ASSUMPTION: a Cooling or Warming Meal gives +1 (its "add"
## row), and the matching tailoring unlock gives +1. Clothing carries no climate value yet.
func climate_resistance() -> Dictionary:
	var heat := food_buffs.added("heat_resist")
	var cold := food_buffs.added("cold_resist")
	if skills:
		heat += 1.0 if skills.is_unlocked("tailoring", "heat_resist") else 0.0
		cold += 1.0 if skills.is_unlocked("tailoring", "cold_resist") else 0.0
	return {"heat": heat, "cold": cold}

## Resistance points the climate asks for: {"heat": n, "cold": n}.
func climate_needs(climate: String) -> Dictionary:
	var resists: Array = (Data.world_climates.get(climate, {}) as Dictionary).get("resist", [])
	var heat := 0
	var cold := 0
	for token in resists:
		heat = maxi(heat, int(_HEAT_TOKENS.get(str(token), 0)))
		cold = maxi(cold, int(_COLD_TOKENS.get(str(token), 0)))
	if heat > 0 and ("sun" in resists or "humidity" in resists):
		heat += 1
	if cold > 0 and "wind" in resists:
		cold += 1
	return {"heat": heat, "cold": cold}

## Unmet resistance points per group: {"heat": x, "cold": y}, never negative.
func climate_shortfall(climate: String) -> Dictionary:
	var need := climate_needs(climate)
	var have := climate_resistance()
	return {
		"heat": maxf(0.0, float(need["heat"]) - float(have["heat"])),
		"cold": maxf(0.0, float(need["cold"]) - float(have["cold"])),
	}

## Fatigue from climate = unmet resistance points x climate_per_min. Heat bites by day, cold at dawn,
## dusk and night. ASSUMPTION: the old rule charged only weak climates at night, nothing by day.
func tick_climate_fatigue(delta: float, climate: String) -> void:
	current_climate = climate
	if vitals == null:
		return
	var short := climate_shortfall(climate)
	var per_min := float((Data.world_rules.get("fatigue", {}) as Dictionary).get("climate_per_min", 4.0))
	var group := "heat" if Game.phase_name() == &"day" else "cold"
	var points := float(short[group])
	if points > 0.0:
		var mult := statuses.heat_fatigue_mult() if group == "heat" else 1.0  # Quenched (PRD :314)
		mult *= sim.rest.climate_mult(group)  # sitting by the fire (PRD :285)
		vitals.add_fatigue(delta * points * (per_min / 60.0) * mult, StringName("climate_" + group))
