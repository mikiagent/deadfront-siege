class_name PetGrowth
extends RefCounted
## Baby growth and care for bred pets (W2-BREED). baby -> juvenile -> adolescent -> adult over the
## real-time stage durations in breeding.json "growth". Everything is timestamp-based: advance() can
## run at any moment (load, UI open, a tick) and gives the same result. A fed baby grows at full rate,
## an unfed one at neglect_rate; nothing here can kill a pet. Cuddles on a timer raise imprint, which
## lifts every stat by imprint_bonus at 100 %.

static func cfg() -> Dictionary:
	return Data.breeding.get("growth", {})

static func stages() -> Array:
	return cfg().get("stages", [])

## Real seconds from hatch to adult at full rate.
static func total_s() -> float:
	var t := 0.0
	for st in stages():
		t += float(st.get("s", 0.0))
	return maxf(1.0, t)

static func is_baby(rec: PetRecord) -> bool:
	return rec != null and rec.maturity < 1.0

static func stage(rec: PetRecord) -> StringName:
	if rec == null or rec.maturity >= 1.0:
		return &"adult"
	var at := rec.maturity * total_s()
	var acc := 0.0
	for st in stages():
		acc += float(st.get("s", 0.0))
		if at < acc:
			return StringName(str(st.get("id", "baby")))
	return &"adult"

## Multiplier on every stat: baby_stat_frac -> 1 with maturity, times the imprint bonus.
## Rises monotonically with maturity and imprint; exactly 1.0 for an adult with no imprint (every tame).
static func stat_factor(rec: PetRecord) -> float:
	var c := cfg()
	var grown := lerpf(float(c.get("baby_stat_frac", 0.3)), 1.0, clampf(rec.maturity, 0.0, 1.0))
	return grown * (1.0 + float(c.get("imprint_bonus", 0.2)) * clampf(rec.imprint, 0.0, 1.0))

## Model scale for the creature view (integrator hook: summon applies it).
static func body_scale(rec: PetRecord) -> float:
	return lerpf(float(cfg().get("baby_scale", 0.35)), 1.0, clampf(rec.maturity, 0.0, 1.0))

## Starts the growth clock of a newborn: fed for one interval, first cuddle due after one interval.
static func start(rec: PetRecord, born_at: int) -> void:
	rec.born_at = born_at
	rec.maturity = 0.0
	rec.imprint = 0.0
	rec.growth_at = born_at
	rec.fed_until = born_at + int(cfg().get("feed_interval_s", 1200)) ## ASSUMPTION: a newborn starts fed.
	rec.cuddle_at = born_at + int(cfg().get("cuddle_interval_s", 1800))
	rec.recompute()

## Brings maturity up to `now`. Returns true when it changed (stats were recomputed).
static func advance(rec: PetRecord, now: int) -> bool:
	if rec == null or rec.maturity >= 1.0 or rec.growth_at <= 0 or now <= rec.growth_at:
		return false
	var dt := float(now - rec.growth_at)
	var fed := clampf(float(rec.fed_until - rec.growth_at), 0.0, dt)
	var grown := fed + (dt - fed) * float(cfg().get("neglect_rate", 0.5))
	rec.maturity = minf(1.0, rec.maturity + grown / total_s())
	rec.growth_at = now
	rec.recompute()
	return true

## Seconds until adult if it stays fed (UI countdown).
static func adult_in_s(rec: PetRecord) -> float:
	return maxf(0.0, (1.0 - rec.maturity) * total_s())

## Feeds a growing baby one item of its diet from `inv` (preferred, then accepted food). The fed
## window restarts from now; feeding early does not stack windows.
static func feed(rec: PetRecord, inv: Inventory, now: int) -> bool:
	if not is_baby(rec) or inv == null:
		return false
	var def := Data.creature(rec.species)
	if def == null:
		return false
	var food: StringName = &""
	for id in def.preferred_food + def.accepted_food:
		if inv.find_first(id) >= 0:
			food = id
			break
	if food == &"":
		return false
	advance(rec, now)
	inv.remove_at(inv.find_first(food), 1)
	rec.fed_until = now + int(cfg().get("feed_interval_s", 1200))
	return true

static func cuddle_ready(rec: PetRecord, now: int) -> bool:
	return is_baby(rec) and now >= rec.cuddle_at

## Imprint per cuddle: one cuddle per interval over the full growth makes 100 %.
static func imprint_per_cuddle() -> float:
	var interval := maxf(1.0, float(cfg().get("cuddle_interval_s", 1800)))
	return 1.0 / maxf(1.0, floorf(total_s() / interval))

static func cuddle(rec: PetRecord, now: int) -> bool:
	if not cuddle_ready(rec, now):
		return false
	advance(rec, now)
	rec.imprint = minf(1.0, rec.imprint + imprint_per_cuddle())
	rec.cuddle_at = now + int(cfg().get("cuddle_interval_s", 1800))
	rec.recompute()
	return true

## Everything the Animals screen needs for one pet (integrator hook: baby care buttons).
static func care_state(rec: PetRecord, now: int) -> Dictionary:
	return {
		"stage": stage(rec),
		"maturity": rec.maturity,
		"imprint": rec.imprint,
		"hungry": is_baby(rec) and now > rec.fed_until,
		"cuddle_ready": cuddle_ready(rec, now),
		"cuddle_in_s": maxi(0, rec.cuddle_at - now) if is_baby(rec) else 0,
		"adult_in_s": adult_in_s(rec),
		"scale": body_scale(rec),
	}
