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
## HUNGER (owner-approved memo docs/design/hunger-and-tribe-automation.md Part 1, 2026-10-29 §1.4):
## "the stomach is a budget". Fullness is its own stored value in points (0-100, above 100 overfull):
## eating adds the food's foods.json `fullness` (add_fullness, from EatSession), and it drains at
## rules.json hunger.decay_per_min whether or not anything digests. Digestion still pays Energy over
## its 300 s window; only the stomach number changed. Bands: HungerBand below. Every number is an
## # ASSUMPTION from the memo; the data lives in rules.json, not here.
##
## The store lives on the Player node as metadata ("foodfx_digestion"), like BuffSlots, so no
## player.gd edit is needed.

const META := "foodfx_digestion"

## HUNGER band edges in points (rules.json hunger.*; these are the fallbacks and the HUD's colour stops).
const EMPTY_BELOW := 10.0
const PECKISH_BELOW := 30.0
const FED_BELOW := 70.0
const WELL_FED_BELOW := 100.0
## Overfull is a real state: a single large meal can push the stomach past its cap. ASSUMPTION.
const OVERFULL_MAX := 120.0
const DECAY_PER_MIN := 2.5
const BUFF_OFF_BELOW := 10.0
const STARVING_AFTER_S := 600.0
const STARVING_STACK_S := 180.0
const WELL_FED_REGEN := 0.2

var _rows: Array[Dictionary] = []
var _next_id: int = 1
## Energy actually paid since the last call that read it (tests and the lab measure this).
var paid_since_read: float = 0.0
## HUNGER: the stored stomach, in points. Saved; never derived from the rows any more.
var stored_fullness: float = 0.0
## Seconds she has been on an empty stomach (the Starving clock). Saved, so a reload keeps it.
var empty_for_s: float = 0.0
## The one-time starter meal was handed out (a new survivor starts Fed, not empty).
var starter_given: bool = false
## A new survivor starts fed. ASSUMPTION (memo leaves the start value open).
const STARTER_FULLNESS := 60.0

static func of(player: Player) -> Digestion:
	if player == null:
		return null
	if player.has_meta(META):
		var d: Variant = player.get_meta(META)
		if d is Digestion:
			return d as Digestion
	var made := Digestion.new()
	made.seed_starter()  # HUNGER: every survivor starts fed; a save's own record replaces this on load
	player.set_meta(META, made)
	return made

func rows() -> Array[Dictionary]:
	return _rows

# ---------------------------------------------------------------- hunger rules (rules.json)

static func _hunger() -> Dictionary:
	var rules: Dictionary = Data.world_rules if Data != null else {}
	var h: Variant = rules.get("hunger", {})
	return h as Dictionary if h is Dictionary else {}

## A number from the hunger block (data/world/rules.json), `fallback` when unset.
static func hunger_num(key: String, fallback: float) -> float:
	return _rule(key, fallback)

static func _rule(key: String, fallback: float) -> float:
	var h := _hunger()
	return float(h.get(key, fallback)) if h.has(key) else fallback

static func cap() -> float:
	return maxf(1.0, FoodEffects.cap_for("fullness"))

static func decay_per_s() -> float:
	return _rule("decay_per_min", DECAY_PER_MIN) / 60.0

static func buff_off_below() -> float:
	return _rule("buff_off_below", BUFF_OFF_BELOW)

static func starving_after_s() -> float:
	return _rule("starving_after_s", STARVING_AFTER_S)

static func starving_stack_s() -> float:
	return _rule("starving_stack_s", STARVING_STACK_S)

static func well_fed_regen() -> float:
	return _rule("well_fed_regen", WELL_FED_REGEN)

## The band a stomach value is in: overfull > 100 > well fed >= 70 > fed >= 30 > peckish >= 10 > empty.
static func state_for(f: float) -> StringName:
	if f > _rule("well_fed_below", WELL_FED_BELOW):
		return &"overfull"
	if f >= _rule("fed_below", FED_BELOW):
		return &"well_fed"
	if f >= _rule("peckish_below", PECKISH_BELOW):
		return &"fed"
	if f >= _rule("empty_below", EMPTY_BELOW):
		return &"peckish"
	return &"empty"

## The fatigue-gain multiplier for a band: rules.json hunger.fatigue_mult, 1.0 when unset.
static func fatigue_mult_for(state: StringName) -> float:
	var table: Variant = _hunger().get("fatigue_mult", {})
	return float((table as Dictionary).get(str(state), 1.0)) if table is Dictionary else 1.0

## Meal buffs are on while the stomach is above the off line.
static func fed_enough_for_buffs() -> float:
	return buff_off_below()

## The fed-time scale the HUD's outer ring counts against: a full stomach draining to the off line.
static func fed_full_seconds() -> float:
	return maxf(1.0, (cap() - buff_off_below()) / maxf(0.0001, decay_per_s()))

## Seconds of fed time the current stomach has left before a while_fed meal buff switches off.
func fed_seconds_from_fullness() -> float:
	return maxf(0.0, stored_fullness - buff_off_below()) / maxf(0.0001, decay_per_s())

# ---------------------------------------------------------------- the stomach

## HUNGER: the stored stomach in points (0-100, above 100 overfull).
func fullness() -> float:
	return stored_fullness

## Set the stomach directly (tests, a load rescue). Clamped to the overfull ceiling.
func set_fullness(points: float) -> void:
	stored_fullness = clampf(points, 0.0, OVERFULL_MAX)

## EatSession calls this with foods.json `fullness`: eating fills the stomach.
func add_fullness(points: float) -> float:
	var before := stored_fullness
	stored_fullness = clampf(stored_fullness + points, 0.0, OVERFULL_MAX)
	if before < _rule("empty_below", EMPTY_BELOW) and stored_fullness >= _rule("empty_below", EMPTY_BELOW):
		empty_for_s = 0.0  # eating lifts her out of empty: the Starving clock restarts
	return stored_fullness - before

## 0..1 of the fed time left for the HUD's outer ring: fullness above the buff-off line over the
## decay rate, against a full stomach. Only a while_fed meal buff lights it (0 otherwise).
func saturation(player: Player = null) -> float:
	if player != null:
		var slots := BuffSlots.of(player)
		if slots == null or not slots.has_while_fed():
			return 0.0
	var left := maxf(0.0, stored_fullness - buff_off_below()) / maxf(0.0001, decay_per_s())
	return clampf(left / fed_full_seconds(), 0.0, 1.0)

## Seed the starter meal if it was never given and the stomach is empty. Marks it given either way.
func seed_starter() -> bool:
	if starter_given:
		return false
	starter_given = true
	if stored_fullness > 0.0:
		return false
	stored_fullness = minf(STARTER_FULLNESS, cap())
	return true

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

## Advance the stomach and every row by `delta` seconds; pay what fits under the ceiling.
## The stomach drains at the flat HUNGER rate whether or not a row is still digesting.
func tick(player: Player, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	stored_fullness = maxf(0.0, stored_fullness - decay_per_s() * delta)
	if stored_fullness < _rule("empty_below", EMPTY_BELOW):
		empty_for_s += delta
	else:
		empty_for_s = 0.0
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

## HUNGER: the save carries the stomach and the Starving clock beside the digestion rows.
func to_dict() -> Dictionary:
	return {
		"rows": _rows.duplicate(true),
		"next_id": _next_id,
		"starter_given": starter_given,
		"fullness": stored_fullness,
		"empty_for_s": empty_for_s,
	}

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
	empty_for_s = maxf(0.0, float(raw.get("empty_for_s", 0.0)))
	if raw.has("fullness"):
		stored_fullness = clampf(float(raw.get("fullness", 0.0)), 0.0, OVERFULL_MAX)
	else:
		# HUNGER: a save from before the rework seeds the stomach once from the old formula (the
		# digesting meals' fullness x their undigested Energy share); the next save stores it.
		stored_fullness = _fullness_from_rows()

## The old fullness formula, used once to seed an old save: Σ food fullness x undigested share.
func _fullness_from_rows() -> float:
	var sum := 0.0
	for row in _rows:
		var total := float(row.get("total", 0.0))
		if total <= 0.0:
			continue
		var id := str(row.get("def_id", ""))
		var full := STARTER_FULLNESS if id == "starter" else float(FoodEffects.entry_for(StringName(id)).get("fullness", 0.0))
		sum += full * clampf(float(row.get("remaining", 0.0)) / total, 0.0, 1.0)
	return clampf(sum, 0.0, OVERFULL_MAX)
