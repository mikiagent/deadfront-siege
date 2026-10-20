class_name Food
extends RefCounted
## Eating restores Energy only (PRD §6.1). Energy = base × (1 + 0.35 × process_count) × level factor.
## Moving while eating cancels remaining restore and still applies Full (PRD §6.2).

const EAT_SECONDS := 3.0
const PROCESS_ENERGY_FACTOR := 0.35
const BUFFS_PATH := "res://data/food_buffs.json"
const PROCESSING_PATH := "res://data/processing.json"

static var _buffs: Dictionary = {}
static var _rules: Dictionary = {}
## Added to the wall clock: labs and tests fast-forward spoilage and station jobs with it.
static var clock_skew_s: float = 0.0

## The clock spoilage and process stations run on: wall time, so both keep going while the
## game is closed. # ASSUMPTION: offline time counts (owner: queues keep running while away).
static func now_s() -> float:
	return Time.get_unix_time_from_system() + clock_skew_s

## processing.json, parsed once.
static func rules() -> Dictionary:
	if _rules.is_empty() and FileAccess.file_exists(PROCESSING_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROCESSING_PATH))
		if parsed is Dictionary:
			_rules = parsed as Dictionary
	return _rules

## Seconds a fresh stack of this item keeps before it spoils; 0 = never.
static func spoil_seconds(d: ItemDef) -> int:
	if d == null:
		return 0
	var spoil: Dictionary = rules().get("spoil", {})
	for k in spoil.get("keeps", []):
		if d.has_category(StringName(str(k))):
			return 0
	var by_cat: Dictionary = spoil.get("by_category", {})
	for c in d.categories:
		if by_cat.has(str(c)):
			return maxi(0, int(by_cat[str(c)]))
	return 0

## Start the spoil clock on a new stack (ItemStack.make).
static func stamp_spoil(stack: ItemStack) -> void:
	var secs := spoil_seconds(stack.def())
	stack.spoil_at = int(now_s()) + secs if secs > 0 else 0

static func is_spoiled(stack: ItemStack) -> bool:
	return stack != null and stack.spoil_at > 0 and now_s() >= float(stack.spoil_at)

## Seconds left before the stack spoils; -1 when it never does.
static func spoil_left(stack: ItemStack) -> float:
	if stack == null or stack.spoil_at <= 0:
		return -1.0
	return maxf(0.0, float(stack.spoil_at) - now_s())

static func is_food(stack: ItemStack) -> bool:
	if stack == null:
		return false
	var d := stack.def()
	if d == null:
		return false
	return d.has_category(&"food") or d.food_energy != 0.0

static func is_raw(stack: ItemStack) -> bool:
	if stack == null:
		return false
	if &"raw" in stack.flags:
		return true
	var d := stack.def()
	return d != null and d.raw

static func is_poisoned(stack: ItemStack) -> bool:
	return stack != null and (&"poisoned" in stack.flags or is_spoiled(stack))

static func energy_restore(stack: ItemStack) -> float:
	if stack == null:
		return 0.0
	var base := stack.scaled_food_energy()
	var e := base * (1.0 + PROCESS_ENERGY_FACTOR * float(stack.process_count))
	if is_spoiled(stack):
		e *= float((rules().get("spoil", {}) as Dictionary).get("spoiled_energy_mult", 0.25))
	return e

static func buff_ids(stack: ItemStack) -> Array[StringName]:
	var out: Array[StringName] = []
	if stack == null:
		return out
	var d := stack.def()
	if d and d.food_buff != &"":
		out.append(d.food_buff)
	var kept := str((rules().get("item_buffs", {}) as Dictionary).get(str(stack.def_id), ""))
	if kept != "" and not is_spoiled(stack) and StringName(kept) not in out:
		out.append(StringName(kept))
	var attr := str(stack.attributes.get("food_buff", ""))
	if attr != "" and StringName(attr) not in out:
		out.append(StringName(attr))
	return out

static func inspector_text(stack: ItemStack) -> String:
	if stack == null:
		return ""
	var d := stack.def()
	var title := d.display_name if d else str(stack.def_id)
	var lines: PackedStringArray = [
		title,
		"energy %.1f  (base×process)" % energy_restore(stack),
		"level %d  process %d" % [stack.level, stack.process_count],
	]
	if is_raw(stack):
		lines.append("RAW")
	lines.append_array(spoil_lines(stack))
	if is_poisoned(stack):
		lines.append("POISONED")
	var buffs := buff_ids(stack)
	if not buffs.is_empty():
		var names: PackedStringArray = []
		for b in buffs:
			names.append(str(b))
		lines.append("buffs: %s" % ", ".join(names))
	return "\n".join(lines)

## "SPOILED" or "spoils in 12m" for tooltips and the inspector; empty for food that keeps.
static func spoil_lines(stack: ItemStack) -> PackedStringArray:
	var out: PackedStringArray = []
	if is_spoiled(stack):
		out.append("SPOILED")
	elif spoil_left(stack) >= 0.0:
		var left := int(spoil_left(stack))
		out.append("spoils in %s" % ("%dh %02dm" % [left / 3600, (left / 60) % 60] if left >= 3600 else "%dm" % maxi(1, ceili(left / 60.0))))
	return out

static func can_eat(player: Player, stack: ItemStack) -> String:
	if player == null or stack == null or not is_food(stack):
		return "not_food"
	if player.statuses and player.statuses.has(&"full"):
		return "full"
	return ""

## The raw-food roll alone: &"stomachache", &"tastes_bad" or &"". Seed `rng` to reproduce it.
static func raw_risk_roll(stack: ItemStack, rng: RandomNumberGenerator = null) -> StringName:
	if stack == null or not is_raw(stack):
		return &""
	var d := stack.def()
	var poison_p := d.poison_chance if d else 0.0
	var bad_p := d.tastes_bad_chance if d else 0.0
	if is_poisoned(stack) or (poison_p > 0.0 and _roll(rng) < poison_p):
		return &"stomachache"
	if bad_p > 0.0 and _roll(rng) < bad_p:
		return &"tastes_bad"
	return &""

static func apply_raw_risks(player: Player, stack: ItemStack, rng: RandomNumberGenerator = null) -> StringName:
	var hit := raw_risk_roll(stack, rng)
	if hit != &"" and player and player.statuses:
		player.statuses.apply(hit, player)
		print("[food] %s from %s" % [hit, stack.def_id])
	return hit

static func _roll(rng: RandomNumberGenerator) -> float:
	return rng.randf() if rng else randf()

static func apply_buffs(player: Player, stack: ItemStack) -> void:
	if player == null or stack == null:
		return
	_ensure_buffs()
	for bid in buff_ids(stack):
		var row: Dictionary = _buffs.get(str(bid), {})
		if row.is_empty():
			continue
		if player.has_method("apply_food_buff"):
			player.apply_food_buff(bid, row)
		print("[food] buff %s %.0fs" % [bid, float(row.get("duration", 0.0))])

static func feed_pet(player: Player, creature: Creature, stack: ItemStack) -> bool:
	if player == null or creature == null or not creature.is_pet or stack == null:
		return false
	if not _pet_accepts(creature, stack):
		print("[food] pet refused %s" % stack.def_id)
		return false
	var idx := -1
	for i in player.inventory.slot_count:
		if player.inventory.slots[i] == stack:
			idx = i
			break
	if idx < 0:
		idx = player.inventory.find_first(stack.def_id)
	if idx < 0:
		return false
	var taken := player.inventory.remove_at(idx, 1)
	if taken == null:
		return false
	var fill := energy_restore(taken) * 10.0
	creature.hunger = minf(creature.hunger_max, creature.hunger + fill)
	if creature.pet_record:
		creature.pet_record.hunger = creature.hunger
	print("[food] fed pet +%.0f hunger now=%.0f" % [fill, creature.hunger])
	return true

static func _pet_accepts(creature: Creature, stack: ItemStack) -> bool:
	var d := stack.def()
	if d == null:
		return false
	var herb := creature.def != null and creature.def.is_herbivore_diet()
	if herb:
		return d.has_category(&"fruit") or d.has_category(&"stalk") or d.diet == &"herbivore" \
			or d.has_category(&"pet_feed") and d.diet == &"herbivore"
	# Carnivore: water+meat+edible, or carnivore feed / meatballs.
	return d.has_category(&"meat") or d.diet == &"carnivore" \
		or (d.has_category(&"pet_feed") and d.diet == &"carnivore")

static func _ensure_buffs() -> void:
	if not _buffs.is_empty():
		return
	if FileAccess.file_exists(BUFFS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUFFS_PATH))
		if parsed is Dictionary:
			var block: Variant = (parsed as Dictionary).get("buffs", {})
			if block is Dictionary:
				_buffs = (block as Dictionary).duplicate()
	# Preserved-food buffs live beside the processing rules (items.json is W2-DATA's).
	var kept: Variant = rules().get("buffs", {})
	if kept is Dictionary:
		_buffs.merge(kept as Dictionary)
