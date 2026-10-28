class_name WaterAccess
extends RefCounted
## Fresh water beside the survivor (spec 17; PRD :105, :314): the Drink / Wash / Fill context
## hexes, their effects, and the dirt that washing clears. Fresh water is the river: terrain under
## the water plane on the river's MUD tiles (IslandTerrain). The sea is salt (PRD :315): it shows
## no hexes; standing in it makes the survivor Wet (PRD :284), not Thirsty. Every effect is a status in
## statuses.json, never a meter (PRD :72, 6.3). Tunables: data/water.json. PlayerActions calls the
## verbs, so the server path stays in one place.

const PATH := "res://data/water.json"
## Hidden grime count on the Player (Object meta).
const GRIME := &"water_grime"
## ASSUMPTION: below 1.3 m the survivor wades; at/above it they swim. Wading is 60 % pace,
## swimming 45 %, tuned for readable movement on the mobile camera rather than simulation.
## 1.3 m is chest-deep on the 2 m survivor, and treading water (float centre at the plane, swim_idle
## lift -0.4) puts her feet 1.3 m under it: shallower, she trod water with her legs in the riverbed (INVIS).
const SWIM_DEPTH_M := 1.3
const WADE_SPEED_MULT := 0.60
const SWIM_SPEED_MULT := 0.45

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"_load_failed": true}
		if not parsed is Dictionary:
			push_error("[water] %s did not parse" % PATH)
	return _data

## Terrain under the water plane: the survivor's feet are in water (river or sea).
static func in_water(pos: Vector3) -> bool:
	var rt := World.runtime as IslandRuntime
	return rt != null and rt.surface_y(pos.x, pos.z) < HarbourSite.WATER_Y

static func depth(pos: Vector3) -> float:
	var rt := World.runtime as IslandRuntime
	if rt == null:
		return 0.0
	return maxf(0.0, HarbourSite.WATER_Y - rt.surface_y(pos.x, pos.z))

static func is_swimming(pos: Vector3) -> bool:
	return depth(pos) >= SWIM_DEPTH_M

static func movement_speed_multiplier(pos: Vector3) -> float:
	var d := depth(pos)
	if d <= 0.0:
		return 1.0
	return SWIM_SPEED_MULT if d >= SWIM_DEPTH_M else WADE_SPEED_MULT

## River water. IslandTerrain marks the river channel and its banks MUD (the mouth's shallows too);
## the open sea never is. The fresh-water mask is kept from the build, so a harvested tile stays fresh.
static func is_fresh(pos: Vector3) -> bool:
	return in_water(pos) and IslandTerrain.fresh_water_at_world(World.runtime as IslandRuntime, pos.x, pos.z)

## Fresh water underfoot or within about reach_m: 17 heightmap lookups (feet, 8 directions at half
## and full reach), cheap enough for the HUD's 0.3 s refresh or every frame.
static func near_fresh(pos: Vector3) -> bool:
	if is_fresh(pos):
		return true
	var reach := float(data().get("reach_m", 2.0))
	for r: float in [reach * 0.5, reach]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			if is_fresh(pos + Vector3(cos(a) * r, 0.0, sin(a) * r)):
				return true
	return false

## Drink: clears Thirsty and grants Quenched, which cuts heat fatigue (PRD :314, 6.3).
static func drink(p: Player) -> bool:
	if not _at_water(p):
		return false
	p.statuses.clear_by_item(&"drink")
	p.statuses.apply(&"quenched")
	p.notice("Quenched: heat tires you less")
	print("[water] drink")
	return true

## Wash: clears Dirty and Very dirty and grants Clean, -20 % fatigue gain for 6 min (PRD 6.4, :447).
static func wash(p: Player) -> bool:
	if not _at_water(p):
		return false
	p.statuses.clear_by_item(&"wash")
	p.set_meta(GRIME, 0.0)
	p.statuses.apply(&"clean")
	p.notice("Clean: fatigue rises slower")
	print("[water] wash")
	return true

## Fill one empty bucket from the river (PRD :314 "fill containers"). The water keeps the bucket's
## level, as the well's fill_bucket recipe does.
static func fill(p: Player) -> bool:
	if not _at_water(p):
		return false
	var i := p.inventory.find_first(&"empty_bucket")
	if i < 0:
		p.notice("You need an empty bucket")
		return false
	var level := p.inventory.slots[i].level
	p.inventory.consume(&"empty_bucket", 1)
	if p.inventory.add(ItemStack.make(&"water_bucket", 1, {}, level)) > 0:
		p.inventory.add(ItemStack.make(&"empty_bucket", 1, {}, level))  # no room: undo, keep the bucket
		p.notice("Your bag has no room for the water bucket")
		return false
	p.toast(&"water_bucket", 1)
	print("[water] fill water_bucket lv%d" % level)
	return true

## Work makes the survivor dirty (data/water.json dirt; ASSUMPTION): Dirty, then Very dirty.
## shortcut: the count lives in Object meta, not the save; a reload keeps the status and restarts
## the count at its threshold (grime()). Save it with the player if Very dirty comes too late.
static func soil(p: Player, cause: StringName) -> void:
	var dirt: Dictionary = data().get("dirt", {})
	var g := grime(p) + float(dirt.get(str(cause), 0.0))
	p.set_meta(GRIME, g)
	if g >= float(dirt.get("very_dirty_at", 60.0)):
		if not p.statuses.has(&"very_dirty"):
			p.statuses.clear_id(&"dirty")
			p.statuses.clear_id(&"clean")
			p.statuses.apply(&"very_dirty")
	elif g >= float(dirt.get("dirty_at", 20.0)) and not p.statuses.has(&"dirty") and not p.statuses.has(&"very_dirty"):
		p.statuses.clear_id(&"clean")
		p.statuses.apply(&"dirty")

static func grime(p: Player) -> float:
	var dirt: Dictionary = data().get("dirt", {})
	var g := float(p.get_meta(GRIME, 0.0))
	if p.statuses.has(&"very_dirty"):
		g = maxf(g, float(dirt.get("very_dirty_at", 60.0)))
	elif p.statuses.has(&"dirty"):
		g = maxf(g, float(dirt.get("dirty_at", 20.0)))
	return g

## The verbs re-check the water: the HUD hides the hexes away from it, a sent intent may not.
static func _at_water(p: Player) -> bool:
	if near_fresh(p.global_position):
		return true
	p.notice("No fresh water here")
	return false
