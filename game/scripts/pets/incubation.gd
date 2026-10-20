class_name Incubation
extends RefCounted
## Egg incubation (W2-BREED), node-free and timestamp-based. The egg stack itself carries the state
## (progress_s, tick_at), so a nest saved mid-incubation resumes and hatches on the same timestamp
## after a load. An egg only advances while its nest is inside the species' temperature range
## (breeding.json; from the species' climate unless overridden); out of range it pauses, never dies.

static func required_s(species: StringName) -> float:
	var sc := Breeding.species_cfg(species)
	return maxf(1.0, float(sc.get("incubation_s", Breeding.section("incubation").get("default_s", 3600))))

static func climate_temp(climate: String) -> float:
	var table := Breeding.section("climate_temp_c")
	return float(table.get(climate, table.get("any", 20.0)))

## [min, max] degrees C the egg needs: egg_temp_c override, else its home climate +- temp_margin_c.
static func egg_range(species: StringName) -> Vector2:
	var sc := Breeding.species_cfg(species)
	var o: Variant = sc.get("egg_temp_c")
	if o is Array and (o as Array).size() == 2:
		return Vector2(float(o[0]), float(o[1]))
	var def := Data.creature(species)
	var mid := climate_temp(str(def.climate) if def else "any")
	var margin := float(Breeding.section("incubation").get("temp_margin_c", 8.0))
	return Vector2(mid - margin, mid + margin)

static func nest_cfg(kind: StringName) -> Dictionary:
	return Breeding.section("nest_kinds").get(str(kind), {})

## A regulated incubator holds any egg in range; a nest sits at the island's climate + its offset.
static func temp_ok(species: StringName, kind: StringName, climate: String) -> bool:
	var n := nest_cfg(kind)
	if bool(n.get("regulated", false)):
		return true
	var t := climate_temp(climate) + float(n.get("temp_offset_c", 0.0))
	var r := egg_range(species)
	return t >= r.x and t <= r.y

static func start(egg: ItemStack, at: int) -> void:
	egg.attributes["progress_s"] = 0.0
	egg.attributes["tick_at"] = at
	egg.attributes["incubation_s"] = required_s(StringName(str(egg.attributes.get("species", ""))))

## Brings progress up to `at`. `in_range` is temp_ok() for this nest (assumed constant since the last tick).
static func advance(egg: ItemStack, at: int, in_range: bool) -> void:
	var a := egg.attributes
	var last := int(PetRecord._num(a.get("tick_at"), at))
	if at > last:
		var rate := 1.0 if in_range else float(Breeding.section("incubation").get("out_of_range_rate", 0.0))
		a["progress_s"] = PetRecord._num(a.get("progress_s"), 0.0) + float(at - last) * rate
	a["tick_at"] = maxi(at, last)

static func remaining_s(egg: ItemStack) -> float:
	var a := egg.attributes
	return maxf(0.0, PetRecord._num(a.get("incubation_s"), 3600.0) - PetRecord._num(a.get("progress_s"), 0.0))

static func ready(egg: ItemStack) -> bool:
	return egg != null and remaining_s(egg) <= 0.0

## Unix time the egg hatches if it stays in range.
static func hatch_at(egg: ItemStack) -> int:
	return int(PetRecord._num(egg.attributes.get("tick_at"), 0)) + ceili(remaining_s(egg))

## The newborn baby (not yet bonded; the caller bonds it through Bonding.try_bond). Born at the
## moment incubation completed, not when the hatch was noticed.
static func hatch(egg: ItemStack, rng: RandomNumberGenerator) -> PetRecord:
	if not ready(egg):
		return null
	var a := egg.attributes
	var over := PetRecord._num(a.get("progress_s"), 0.0) - PetRecord._num(a.get("incubation_s"), 0.0)
	var born := int(PetRecord._num(a.get("tick_at"), 0)) - int(maxf(0.0, over))
	return Breeding.baby_from(a, born, rng)
