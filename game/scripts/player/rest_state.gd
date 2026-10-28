class_name RestState
extends RefCounted
## Rest (owner: "resting should sit you down and heal you and lower exhaustion"; spec 01:19-25). The
## survivor sits on the ground and recovers Health and fatigue until she moves, is hurt, fights or is
## hunted. The rate depends on where she sits (data/rest.json): in the open, by a lit fire, or at a
## tent, bed or shelter (PRD :118, :803). PlayerActions.rest() starts and stops it (the Rest hex, the
## X key); PlayerSim ticks it; Sleep at a tent or bed heals through heal() (its own drain eases fatigue). The pose is
## PlayerAnim.sit() / stand_up(); the HUD's Resting chip reads hud_lines() (HudRestBox draws them).
## Only hits, fights and creatures stand her up; a status tick does not (Player._on_vitals_damaged).

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
	return ""  # a bleed or a stomachache does not stop her: it slows the healing (spec 01:19), the chip says so

## The Rest hex shows where a tap can sit her down (combat hides every hex; mounted shows only Dismount).
func offered() -> bool:
	return not resting and p._sleep_left <= 0.0 and not p.in_water

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
	heal(where, delta)
	p.vitals.rest(fatigue_per_min(where) / 60.0 * delta)

## The Health half alone: Sleep calls this, since its own gradual drain moves exhaustion (player_sim).
func heal(where: StringName, delta: float) -> void:
	if not p.vitals.blocks_regen:
		p.vitals.heal(float(rates(where).get("hp_per_s", 0.0)) * delta)

## The place's fatigue recovery, slowed by whatever makes her tire faster (spec 01:19: hygiene and
## conditions affect recovery). ASSUMPTION: statuses.json fatigue_mult inverted, so Dirty (1.2), Very
## Dirty (1.5) and Thirsty (1.2) slow it and Clean (0.8) speeds it.
func fatigue_per_min(where: StringName) -> float:
	return float(rates(where).get("fatigue_per_min", 0.0)) / maxf(0.1, p.statuses.fatigue_mult())

## Health per second while she rests at `where`: the rest's rate plus passive regen, less what her
## statuses deal. A damage tick also pauses passive regen (vitals.gd REGEN_LOCK_S); blocks_regen stops both.
func net_hp_per_s(where: StringName) -> float:
	var dot := 0.0
	for inst in p.statuses.instances():
		var def := Data.status(inst.id)
		if def:
			dot += def.dps * float(inst.stacks) + def.dps_max_hp_frac * p.vitals.max_health
	if p.vitals.blocks_regen:
		return -dot
	return float(rates(where).get("hp_per_s", 0.0)) + (0.0 if dot > 0.0 else p.vitals.health_regen) - dot

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
	var v := p.vitals
	var hp := net_hp_per_s(where)
	var hp_line := "HP full"
	if v.health < v.effective_max_health():
		hp_line = ("No healing" if absf(hp) < 0.05 else "%+.1f HP/s" % hp) \
			+ _why(func (d: StatusDef) -> bool: return d.dps > 0.0 or d.dps_max_hp_frac > 0.0 or d.flags.has(&"blocks_regen"))
	var fat_line := "Rested"
	if v.fatigue >= 0.5 and sleeping:
		fat_line = "-%d fatigue/min" % roundi(p.sim.sleep_fatigue_per_min())  # the sleep's own drain
	elif v.fatigue >= 0.5:
		fat_line = "-%d fatigue/min" % roundi(fatigue_per_min(where)) + _why(func (d: StatusDef) -> bool: return d.fatigue_mult != 1.0)
	return PackedStringArray(["Sleeping" if sleeping else str(rates(where).get("label", "Resting")), hp_line, fat_line])

## " (stomachache, dirty)": her statuses that `pick` says change a rate, for the chip (spec 01:22).
func _why(pick: Callable) -> String:
	var names := PackedStringArray()
	for inst in p.statuses.instances():
		var def := Data.status(inst.id)
		if def and pick.call(def):
			names.append(def.display_name.to_lower())
	return "" if names.is_empty() else " (%s)" % ", ".join(names)

## A load (spec 01:22): sits her back down when the save was made resting. A save made standing gets
## her up at once, with no clip, so the loaded pose is the save's. Anything but a real true is standing.
func load_saved(saved: Variant) -> void:
	if resting:
		stop(false)
		if p.anim:
			p.anim.revive()
	if saved is bool and saved:
		start()

## PRD :285: the bonfire clears Wet, when she sits down by it or rests her way into its reach (not
## every frame: rain would only put it back).
func _set_place(where: StringName, sat_down: bool = false) -> void:
	if where == &"fire" and (sat_down or place != &"fire"):
		for id in ((data().get("fire_sitting", {}) as Dictionary).get("clears", []) as Array):
			p.statuses.clear_id(StringName(str(id)))
	place = where
