class_name Food
extends RefCounted
## Eating restores Energy only (PRD §6.1). Energy = base × (1 + 0.35 × process_count) × level factor.
## Moving while eating cancels remaining restore and still applies Full (PRD §6.2).

const EAT_SECONDS := 3.0
const PROCESS_ENERGY_FACTOR := 0.35
const BUFFS_PATH := "res://data/food_buffs.json"

static var _buffs: Dictionary = {}

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
	return stack != null and &"poisoned" in stack.flags

static func energy_restore(stack: ItemStack) -> float:
	if stack == null:
		return 0.0
	var base := stack.scaled_food_energy()
	return base * (1.0 + PROCESS_ENERGY_FACTOR * float(stack.process_count))

static func buff_ids(stack: ItemStack) -> Array[StringName]:
	var out: Array[StringName] = []
	if stack == null:
		return out
	var d := stack.def()
	if d and d.food_buff != &"":
		out.append(d.food_buff)
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
	if is_poisoned(stack):
		lines.append("POISONED")
	var buffs := buff_ids(stack)
	if not buffs.is_empty():
		var names: PackedStringArray = []
		for b in buffs:
			names.append(str(b))
		lines.append("buffs: %s" % ", ".join(names))
	return "\n".join(lines)

static func can_eat(player: Player, stack: ItemStack) -> String:
	if player == null or stack == null or not is_food(stack):
		return "not_food"
	if player.statuses and player.statuses.has(&"full"):
		return "full"
	return ""

static func apply_raw_risks(player: Player, stack: ItemStack) -> void:
	if player == null or stack == null or not is_raw(stack):
		return
	var d := stack.def()
	var poison_p := d.poison_chance if d else 0.0
	var bad_p := d.tastes_bad_chance if d else 0.0
	if is_poisoned(stack) or (poison_p > 0.0 and randf() < poison_p):
		player.statuses.apply(&"stomachache", player)
		print("[food] stomachache from %s" % stack.def_id)
	elif bad_p > 0.0 and randf() < bad_p:
		player.statuses.apply(&"tastes_bad", player)
		print("[food] tastes_bad from %s" % stack.def_id)

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
	if not FileAccess.file_exists(BUFFS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUFFS_PATH))
	if parsed is Dictionary:
		var block: Variant = (parsed as Dictionary).get("buffs", {})
		if block is Dictionary:
			_buffs = block as Dictionary
