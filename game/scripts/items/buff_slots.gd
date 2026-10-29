class_name BuffSlots
extends RefCounted
## Spec 32 §4/§13 BuffSlotManager: timed food buffs in exclusive *groups*.
##
## The recovered rules distinguish an Enhanced Ability container (ordinary attribute/profession
## meals) and an Enhanced Survival container (survival drinks). They may be active at once; eating
## another food of the same group replaces that group's buff and only that one. A food that only
## restores Energy carries no buff, so it replaces nothing.
##
## Player.food_buffs (FoodBuffState) stays the mirror the rest of the game already reads (crafting
## ability, heat/cold resistance): every tick this node rewrites its own rows into that mirror, so
## there is still exactly one store the readers see and one owner of food-buff expiry.
##
## The store lives on the Player node as metadata ("foodfx_slots"), so no player.gd edit is needed
## and a survivor made with new() in a test has the same state a scene one does.
## On expiry, capacities are recomputed from the remaining rows and *current* values are clamped:
## a Maximum Fatigue bonus never subtracts from current fatigue and never touches a base stat
## (spec 32 §4 "Critical").

const META := "foodfx_slots"

var _rows: Array[Dictionary] = []
## Spec 32 §7 taste memory: flavour -> {"score": run length, "t": unix seconds}.
var taste_memory: Dictionary = {}
## Namespace of the rows this node owns inside FoodBuffState. Erasing by prefix (not by a list of the
## keys written last time) means a fresh instance - a survivor restored from a save - still clears rows
## an earlier life left behind.
const MIRROR_PREFIX := "fx_"

## The survivor's slots, created on first use and kept on the node.
static func of(player: Player) -> BuffSlots:
	if player == null:
		return null
	if player.has_meta(META):
		var s: Variant = player.get_meta(META)
		if s is BuffSlots:
			return s as BuffSlots
	var made := BuffSlots.new()
	player.set_meta(META, made)
	return made

func rows() -> Array[Dictionary]:
	return _rows

func ids() -> Array[String]:
	var out: Array[String] = []
	for r in _rows:
		out.append(str(r.get("id", "")))
	return out

func get_row(id: String) -> Dictionary:
	for r in _rows:
		if str(r.get("id", "")) == id:
			return r
	return {}

func by_group(group: String) -> Dictionary:
	for r in _rows:
		if str(r.get("group", "")) == group:
			return r
	return {}

## The buffs in `bundle_buffs` that would replace an active buff of their own group, in order:
## [{"group", "group_name", "old", "new"}]. The panel prints this as "replaces ..." (spec 32 §12).
func would_replace(bundle_buffs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Variant in bundle_buffs:
		if not b is Dictionary:
			continue
		var row: Dictionary = b as Dictionary
		var group := str(row.get("group", "enhanced_ability"))
		var old := by_group(group)
		if old.is_empty():
			continue
		if str(old.get("id", "")) == str(row.get("id", "")):
			continue
		out.append({
			"group": group,
			"group_name": str(row.get("group_name", group)),
			"old": str(old.get("display_name", old.get("id", ""))),
			"new": str(row.get("display_name", row.get("id", ""))),
		})
	return out

## Apply one bundle's buffs: each replaces its own group only. Returns what was replaced.
## HUNGER (memo Part 1 s1.4 step 4): a row whose bundle says `while_fed` lives until the stomach drops
## below hunger.buff_off_below. Its `time_left` is that fed time at the rate, so the HUD's outer ring
## can count it down; tick() also ends it the tick the stomach crosses the line (the authority).
## Rows without the flag keep their own timer.
func apply(player: Player, bundle_buffs: Array) -> Array[Dictionary]:
	var replaced: Array[Dictionary] = []
	for b: Variant in bundle_buffs:
		if not b is Dictionary:
			continue
		var row: Dictionary = b as Dictionary
		var id := str(row.get("id", ""))
		var group := str(row.get("group", "enhanced_ability"))
		if id == "" or float(row.get("duration", 0.0)) <= 0.0:
			continue
		var while_fed := bool(row.get("while_fed", false))
		var life := _life_seconds(player, float(row.get("duration", 0.0)), while_fed)
		var old := by_group(group)
		if not old.is_empty():
			if str(old.get("id", "")) == id:
				# Same food again: refresh rather than replace (spec 32 §11 step 7: only the group).
				old["duration"] = life
				old["time_left"] = life if while_fed else maxf(float(old.get("time_left", 0.0)), float(row.get("duration", 0.0)))
				old["while_fed"] = while_fed
				old["stats"] = (row.get("stats", {}) as Dictionary).duplicate(true)
				_sync(player)
				return replaced
			replaced.append({"group": group, "old": str(old.get("id", "")), "new": id})
			_rows.erase(old)
		_rows.append({
			"id": id,
			"group": group,
			"group_name": str(row.get("group_name", group)),
			"display_name": str(row.get("display_name", id)),
			"duration": life,
			"time_left": life,
			"stats": (row.get("stats", {}) as Dictionary).duplicate(true),
			"while_fed": while_fed,
		})
	_sync(player)
	return replaced

## How long a buff row lives: its own duration, or - for a while_fed meal - as long as the stomach can
## feed it (a bigger meal fills more, so it lasts longer, memo s1.4). The stomach's line is the authority
## (tick), so the row's timer is the fed time and never shorter than the dish's own duration.
static func _life_seconds(player: Player, duration: float, while_fed: bool) -> float:
	if not while_fed or player == null:
		return duration
	var dig := Digestion.of(player)
	if dig == null:
		return duration
	return maxf(duration, dig.fed_seconds_from_fullness())

## True while any active row is a while_fed meal buff (the HUD's outer ring only counts those).
func has_while_fed() -> bool:
	for r in _rows:
		if bool(r.get("while_fed", false)):
			return true
	return false

## Sum of one stat's `add` (minus `sub`) over active rows; 0.0 for a stat no buff carries.
func stat_add(stat: String) -> float:
	var total := 0.0
	for r in _rows:
		var stats: Dictionary = r.get("stats", {})
		if not stats.has(stat):
			continue
		var ops: Dictionary = stats[stat]
		total += float(ops.get("add", 0.0)) - float(ops.get("sub", 0.0))
	return total

func stat_mult(stat: String) -> float:
	var m := 1.0
	for r in _rows:
		var stats: Dictionary = r.get("stats", {})
		if stats.has(stat):
			m *= float((stats[stat] as Dictionary).get("mult", 1.0))
	return m

func tick(player: Player, delta: float) -> void:
	if _rows.is_empty():
		return
	var fed := Digestion.of(player)
	var off := fed == null or fed.fullness() < Digestion.buff_off_below()
	var expired: Array[Dictionary] = []
	for r in _rows:
		r["time_left"] = float(r.get("time_left", 0.0)) - delta
		# HUNGER: a while_fed meal buff ends the moment the stomach is below the off line.
		if bool(r.get("while_fed", false)) and off:
			expired.append(r)
		elif float(r["time_left"]) <= 0.0:
			expired.append(r)
	if not expired.is_empty():
		for r in expired:
			_rows.erase(r)
			print("[foodfx] buff expired %s (%s)" % [str(r.get("id", "")), str(r.get("group_name", ""))])
	_sync(player)

## Write the rows into the FoodBuffState mirror the rest of the game reads and recompute capacities.
func _sync(player: Player) -> void:
	if player == null or player.food_buffs == null:
		return
	var mirror: Dictionary = player.food_buffs.to_dict()
	for key: Variant in mirror.keys():
		if str(key).begins_with(MIRROR_PREFIX):
			mirror.erase(key)
	for r in _rows:
		var stats: Dictionary = r.get("stats", {})
		# Capacities are owned here (vitals bonus below), so they are not mirrored twice.
		var row := {}
		for stat: Variant in stats:
			var name := str(stat)
			if name == "max_fatigue" or name == "max_energy":
				continue
			var dst := FoodEffects.player_stat(name)
			if dst == "":
				continue
			var ops: Dictionary = stats[stat]
			var acc: Dictionary = row.get(dst, {})
			if ops.has("add"):
				acc["add"] = float(acc.get("add", 0.0)) + float(ops["add"])
			if ops.has("sub"):
				acc["add"] = float(acc.get("add", 0.0)) - float(ops["sub"])
			if ops.has("mult"):
				acc["mult"] = float(acc.get("mult", 1.0)) * float(ops["mult"])
			acc["stat"] = dst
			row[dst] = acc
		for dst: Variant in row:
			var key := "%s%s_%s" % [MIRROR_PREFIX, str(r.get("id", "")), str(dst)]
			var acc2: Dictionary = row[dst]
			acc2["stat"] = str(dst)
			acc2["duration"] = float(r.get("duration", 0.0))
			mirror[key] = {"time_left": float(r.get("duration", 0.0)), "row": acc2}
	player.food_buffs.from_dict(mirror)
	if player.vitals != null:
		player.vitals.sync_food_caps(stat_add("max_fatigue"), stat_add("max_energy"))

## Rebuild the FoodBuffState mirror and the capacity bonuses from the current rows. Public because a
## restore is not a tick: without it a loaded buff would sit in the slots and move no number for the
## readers that ask FoodBuffState (Crafting.crafting_ability, heat/cold resistance) until an expiry.
func sync(player: Player) -> void:
	_sync(player)

# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {
		"buffs": _rows.duplicate(true),
		"taste_memory": taste_memory.duplicate(true),
	}

func from_dict(raw: Dictionary) -> void:
	_rows.clear()
	var list: Variant = raw.get("buffs", [])
	if list is Array:
		for r: Variant in list:
			if not r is Dictionary:
				continue
			var row: Dictionary = (r as Dictionary).duplicate(true)
			if str(row.get("id", "")) == "" or float(row.get("time_left", 0.0)) <= 0.0:
				continue
			_rows.append(row)
	var mem: Variant = raw.get("taste_memory", {})
	taste_memory = (mem as Dictionary).duplicate(true) if mem is Dictionary else {}

## Load a saved slot payload *and* publish it: rows, mirror, capacities. This is the only correct way
## to restore buffs - from_dict alone leaves FoodBuffState holding whatever the previous life wrote.
func restore(player: Player, raw: Dictionary) -> void:
	from_dict(raw)
	_sync(player)
