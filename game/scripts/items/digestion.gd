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
	player.set_meta(META, made)
	return made

func rows() -> Array[Dictionary]:
	return _rows

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
	return {"rows": _rows.duplicate(true), "next_id": _next_id}

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
