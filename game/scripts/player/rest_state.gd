class_name RestState
extends RefCounted
## Rest (owner: "resting should sit you down and heal you and lower exhaustion"; spec 01:19-25). The
## survivor sits on the ground and recovers Health and fatigue until she moves, is hurt, fights or is
## hunted. The rate depends on where she sits (data/rest.json): in the open, by a lit fire, or at a
## tent, bed or shelter (PRD :118, :803). PlayerActions.rest() starts and stops it (the Rest hex, the
## X key); PlayerSim ticks it; Sleep at a tent or bed recovers through recover() as well. The pose is
## PlayerAnim.sit() / stand_up(); the HUD's Resting chip reads hud_lines().

const PATH := "res://data/rest.json"
const PLACE_RECHECK_S := 0.5

static var _data: Dictionary = {}

var p: Player
var resting: bool = false
## Where she sits: &"open", &"fire" or &"shelter" (data/rest.json places), re-read twice a second.
var place: StringName = &"open"
var _recheck_left: float = 0.0

func _init(player: Player) -> void:
	p = player

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"_load_failed": true}
		if not parsed is Dictionary:
			push_error("[rest] %s did not parse" % PATH)
	return _data

## A place's row: {"label", "hp_per_s", "fatigue_per_min"} ({} for an unknown place).
static func rates(where: StringName) -> Dictionary:
	return (data().get("places", {}) as Dictionary).get(str(where), {})

## "" when she can sit down now, "dead" (say nothing), else the reason to show.
func refusal() -> String:
	if p.dead:
		return "dead"
	if p.mounted_on:
		return "Dismount to rest."
	if p._sleep_left > 0.0:
		return "Already sleeping."
	if p.rolling or p.statuses.has_flag(&"cannot_act"):
		return "Can't rest right now."
	if p.in_water:
		return "Can't rest in water."
	if in_combat() or hunted():
		return "Can't rest in combat."
	for inst in p.statuses.instances():
		var def := Data.status(inst.id)
		if def and (def.dps > 0.0 or def.dps_max_hp_frac > 0.0):
			return "Treat your %s before resting." % def.display_name.to_lower()  # its ticks would stand her up
	return ""

func start() -> bool:
	if resting:
		return true
	var why := refusal()
	if why != "":
		if why != "dead":
			p.notice(why)
		return false
	p.clear_nav()
	p.view.clear_ground_marker()
	p.actions.cancel_work()
	resting = true
	_set_place(place_now(), true)
	_recheck_left = PLACE_RECHECK_S
	if p.anim:
		p.anim.sit()
	p.notice("%s - move to get up" % str(rates(place).get("label", "Resting")))
	print("[rest] sit place=%s" % place)
	return true

## Get up: the stand-up clip unless another clip already took the pose (`stand` false).
func stop(stand: bool = true) -> void:
	if not resting:
		return
	resting = false
	if stand and p.anim:
		p.anim.stand_up()
	print("[rest] stand")

func toggle() -> bool:
	if resting:
		stop()
		return true
	return start()

## PlayerSim, every physics frame. True while she sits: the caller holds still instead of walking.
func tick(delta: float) -> bool:
	if not resting:
		return false
	if p.dead or (p.anim and not p.anim.is_sitting()):
		stop(false)  # death, a meal, a knockdown: another clip already has her up
		return false
	if p.sim.input_vector().length_squared() > 0.04 or p.nav_active:
		stop()
		return false
	_recheck_left -= delta
	var alarm := in_combat()
	if _recheck_left <= 0.0:
		_recheck_left = PLACE_RECHECK_S
		alarm = alarm or hunted()
		_set_place(place_now())
	if alarm:
		stop()
		p.notice("Up! Something is after you.")
		return false
	recover(place, delta)
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if not p.is_on_floor():
		p.velocity += p.get_gravity() * delta
	p.move_and_slide()
	return true

## One frame of recovery at `where`: Health (unless a status blocks regen) and fatigue. Vitals clamps
## both, so neither goes below 0 nor above its maximum.
func recover(where: StringName, delta: float) -> void:
	var r := rates(where)
	if not p.vitals.blocks_regen:
		p.vitals.heal(float(r.get("hp_per_s", 0.0)) * delta)
	p.vitals.rest(float(r.get("fatigue_per_min", 0.0)) / 60.0 * delta)

## The best place within reach: a shelter building, else a lit fire (a placed campfire burns until it
## is gone, bonfires always), else the open.
func place_now() -> StringName:
	var d := data()
	var kinds: Array = d.get("shelter_kinds", [])
	var reach := float(d.get("shelter_reach_m", 3.2))
	for n in p.get_tree().get_nodes_in_group("placed_building"):
		var b := n as Node3D
		if b and str(b.get("kind")) in kinds and p.global_position.distance_to(b.global_position) <= reach:
			return &"shelter"
	reach = float(d.get("fire_reach_m", 3.0))
	for n in p.get_tree().get_nodes_in_group("craft_station"):
		if n is Bonfire and p.global_position.distance_to((n as Bonfire).global_position) <= reach:
			return &"fire"
	return &"open"

## Hunting a creature, or hit within combat_lock_s.
func in_combat() -> bool:
	var lock := float(data().get("combat_lock_s", 5.0))
	return (p.hunt != null and p.hunt.target != null and is_instance_valid(p.hunt.target)) \
		or Time.get_ticks_msec() * 0.001 - p._last_hit_taken_s < lock

## A creature has her as its target and is closing in or attacking.
func hunted() -> bool:
	for n in p.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and c.brain and c.brain.attack_target == p and c.brain.hunting_player():
			return true
	return false

## PRD :285: sitting by the fire, heat fatigue +20 % and cold fatigue -20 % (Player.tick_climate_fatigue).
func climate_mult(group: String) -> float:
	if not resting or place != &"fire":
		return 1.0
	return float((data().get("fire_sitting", {}) as Dictionary).get(group + "_fatigue_mult", 1.0))

## The Resting chip's lines: what she is doing and the live recovery rates; empty when she is up.
func hud_lines() -> PackedStringArray:
	var sleeping := p._sleep_left > 0.0
	if not resting and not sleeping:
		return PackedStringArray()
	var where := &"shelter" if sleeping else place
	var r := rates(where)
	var v := p.vitals
	var hp := 0.0 if v.blocks_regen else float(r.get("hp_per_s", 0.0)) + v.health_regen
	var hp_line := "HP full" if v.health >= v.effective_max_health() else ("+%.1f HP/s" % hp if hp > 0.0 else "No healing")
	var fat_line := "Rested" if v.fatigue < 0.5 else "-%d fatigue/min" % roundi(float(r.get("fatigue_per_min", 0.0)))
	return PackedStringArray(["Sleeping" if sleeping else str(r.get("label", "Resting")), hp_line, fat_line])

## PRD :285: the bonfire clears Wet, when she sits down by it or rests her way into its reach (not
## every frame: rain would only put it back).
func _set_place(where: StringName, sat_down: bool = false) -> void:
	if where == &"fire" and (sat_down or place != &"fire"):
		for id in ((data().get("fire_sitting", {}) as Dictionary).get("clears", []) as Array):
			p.statuses.clear_id(StringName(str(id)))
	place = where
