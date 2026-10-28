class_name Digestion
extends RefCounted
## Spec 32 §2/§13 DigestionEffect: the delayed share of a meal's Energy, paid out over time and
## persisted with its *remaining* amount, so a reload can never pay the same share twice.
##
## One row per eaten item (a meal and a tea can digest at once):
##   {id, def_id, total, remaining, rate (per second), seconds}
## Time is authoritative seconds of play (tick deltas), not wall clock: a save keeps `remaining`, and
## loading resumes at the published rate. # ASSUMPTION: energy that does not fit under the current
## Energy ceiling waits in the row instead of being discarded, so a buff or a level-up that raises the
## ceiling later still gets the meal it paid for (spec 32 §2 asks for this to be defined).
##
## The store lives on the Player node as metadata ("foodfx_digestion"), like BuffSlots, so no
## player.gd edit is needed.

const META := "foodfx_digestion"

var _rows: Array[Dictionary] = []
var _next_id: int = 1
## Energy actually paid since the last call that read it (tests and the lab measure this).
var paid_since_read: float = 0.0

static func of(player: Player) -> Digestion:
	if player == null:
		return null
	if player.has_meta(META):
		var d: Variant = player.get_meta(META)
		if d is Digestion:
			return d as Digestion
	var made := Digestion.new()
	made.seed_starter()  # STARVING: every survivor starts fed; a save's own record replaces this on load
	player.set_meta(META, made)
	return made

func rows() -> Array[Dictionary]:
	return _rows

## FULLFATIGUE (owner 2026-10-28: "fullness should affect exhaustion"): the stomach model the HUD ring and the
## fatigue rate share. ASSUMPTION: no satiety meter exists (PRD :72/:1030), so fullness is what still digests:
## each row's foods.json `fullness` (0-100, cap defaults.caps.fullness) x its undigested Energy share, summed,
## over the cap. 0 = empty, 1 = a full stomach, above 1 = overfull. Band edges are ASSUMPTION.
const FALLBACK_FULLNESS := 10.0  ## a digesting food with no foods.json fullness counts as a snack
const EMPTY_BELOW := 0.1
const HUNGRY_BELOW := 0.4
const NORMAL_BELOW := 0.7
const OVERFULL_ABOVE := 1.0
const STATES: Array[StringName] = [&"empty", &"hungry", &"normal", &"full", &"overfull"]
## A new survivor (and an old save with nothing digesting, once) starts with one starter meal digesting so
## she begins "normal", not "empty" at x2 exhaustion. ASSUMPTION: fullness 60 for 15 min, 1 Energy in all
## (it reads normal ~5 min, hungry until ~12.5 min, then empty); the flag is saved so it is given once.
const STARTER_ID := "starter"
const STARTER_FULLNESS := 60.0
const STARTER_SECONDS := 900.0
var starter_given: bool = false

## Seed the starter meal if it was never given and nothing digests. Marks it given either way.
func seed_starter() -> bool:
	if starter_given:
		return false
	starter_given = true
	if not _rows.is_empty():
		return false
	schedule(StringName(STARTER_ID), 1.0, STARTER_SECONDS)
	return true

func fullness() -> float:
	var cap := maxf(1.0, FoodEffects.cap_for("fullness"))
	var sum := 0.0
	for row in _rows:
		var total := float(row.get("total", 0.0))
		if total <= 0.0:
			continue
		var id := str(row.get("def_id", ""))
		var full := STARTER_FULLNESS if id == STARTER_ID else float(FoodEffects.entry_for(StringName(id)).get("fullness", FALLBACK_FULLNESS))
		sum += full * clampf(float(row.get("remaining", 0.0)) / total, 0.0, 1.0)
	return sum / cap

## 0..1: the longest digestion's time left over its digest time (0 when nothing digests).
func saturation() -> float:
	var best := 0.0
	for row in _rows:
		var secs := float(row.get("seconds", 0.0))
		var rate := float(row.get("rate", -1.0))
		if secs > 0.0 and rate > 0.0:
			best = maxf(best, clampf(float(row.get("remaining", 0.0)) / rate / secs, 0.0, 1.0))
	return best

static func state_for(f: float) -> StringName:
	if f > OVERFULL_ABOVE:
		return &"overfull"
	if f >= NORMAL_BELOW:
		return &"full"
	if f >= HUNGRY_BELOW:
		return &"normal"
	if f >= EMPTY_BELOW:
		return &"hungry"
	return &"empty"

## The fatigue-gain multiplier for a state: rules.json fatigue.fullness_mult, 1.0 when unset.
static func fatigue_mult_for(state: StringName) -> float:
	var table: Variant = (Data.world_rules.get("fatigue", {}) as Dictionary).get("fullness_mult", {})
	return float((table as Dictionary).get(str(state), 1.0)) if table is Dictionary else 1.0

func total_remaining() -> float:
	var t := 0.0
	for r in _rows:
		t += float(r.get("remaining", 0.0))
	return t

## Schedule the delayed share of one eaten instance. A zero (or negative) share schedules nothing.
func schedule(def_id: StringName, energy: float, seconds: float) -> Dictionary:
	if energy <= 0.0:
		return {}
	var span := maxf(0.0, seconds)
	var row := {
		"id": "dig%d" % _next_id,
		"def_id": str(def_id),
		"total": energy,
		"remaining": energy,
		# A meal with no digestion window pays the rest at the next tick instead of being lost.
		"seconds": span,
		"rate": energy / span if span > 0.0 else -1.0,
	}
	_next_id += 1
	_rows.append(row)
	return row

## Advance every row by `delta` seconds and pay what fits under the ceiling. Returns the paid Energy.
func tick(player: Player, delta: float) -> float:
	if _rows.is_empty() or player == null or player.vitals == null:
		return 0.0
	var paid_total := 0.0
	for r in _rows.duplicate():
		var rate := float(r.get("rate", -1.0))
		var want := float(r.get("remaining", 0.0)) if rate < 0.0 else minf(float(r.get("remaining", 0.0)), rate * delta)
		var room := player.vitals.effective_max_energy() - player.vitals.energy
		var pay := clampf(want, 0.0, maxf(0.0, room))
		if pay > 0.0:
			player.vitals.energy = clampf(player.vitals.energy + pay, 0.0, player.vitals.effective_max_energy())
			r["remaining"] = maxf(0.0, float(r.get("remaining", 0.0)) - pay)
			paid_total += pay
		if float(r.get("remaining", 0.0)) <= 0.0001 and not is_equal_approx(rate, 0.0):
			if float(r.get("remaining", 0.0)) <= 0.0:
				_rows.erase(r)
		elif rate < 0.0:
			r["rate"] = -1.0  # a zero-length row pays whenever there is room
	paid_since_read += paid_total
	return paid_total

# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	return {"rows": _rows.duplicate(true), "next_id": _next_id, "starter_given": starter_given}

func from_dict(raw: Dictionary) -> void:
	_rows.clear()
	var list: Variant = raw.get("rows", [])
	if list is Array:
		for r: Variant in list:
			if not r is Dictionary:
				continue
			var row: Dictionary = (r as Dictionary).duplicate(true)
			if float(row.get("remaining", 0.0)) <= 0.0:
				continue
			_rows.append(row)
	_next_id = maxi(1, int(raw.get("next_id", _rows.size() + 1)))
	starter_given = bool(raw.get("starter_given", false))
