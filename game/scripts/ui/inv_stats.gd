class_name InvStats
extends RefCounted
## The survivor's numbers for Character, Detailed Stats and Equipment / My Info (spec 13 s13-15),
## read from the same rules combat and the bag use, so the screen shows what the game does:
## Attack is Hunt's own swing damage x the Melee bonus (hunt.gd land_hit), Defense the armour the
## creature bite reads (creature_attack.gd), Accuracy Hunt's hit chance before dodge. Every value is
## computed from what is worn now, never accumulated, so nothing can count twice.

## Snapshot keys in display order, with labels and formats (Detailed Stats and the compare rows).
const ROWS := [
	["attack", "Attack", "%d"], ["defense", "Defense", "%d"], ["accuracy", "Accuracy", "%d%%"],
	["crit", "Critical chance", "%.1f%%"], ["max_health", "Max health", "%d"], ["energy", "Max energy", "%d"],
	["capacity", "Bag capacity", "%d"], ["gather_power", "Held tool power", "%.2fx"],
	["heat", "Heat resistance", "%d"], ["cold", "Cold resistance", "%d"],
]

## Every number the screens show, for the gear worn now.
static func snapshot(player: Player) -> Dictionary:
	return _stats(player, player.inventory)

## The same numbers if bag slot `index` went into `slot` (&"tool" = held), worked out on a copy of
## the bag through Inventory's own equip rules: the real one is never touched. {} when refused.
static func with_candidate(player: Player, index: int, slot: StringName) -> Dictionary:
	var inv := player.inventory
	var what := Inventory.new(inv.base_slots)
	what.slot_count = inv.slot_count
	what.slots = inv.slots.duplicate()
	what.equipment = inv.equipment.duplicate()
	what.equipped_tool_index = inv.equipped_tool_index
	if slot == &"tool":
		what.set_equipped_tool_index(index)
	elif not what.equip_at(index, slot):
		return {}
	return _stats(player, what)

static func _stats(player: Player, inv: Inventory) -> Dictionary:
	var tune := CombatTuning.section("player_melee")
	var melee := player.skills.level_of("melee") if player.skills else 0
	var w := inv.equipped_weapon()
	if w and w.is_broken():
		w = null # a broken weapon fights as bare hands (Hunt._weapon)
	var swing := player.hunt._swing_damage(w) if player.hunt else float(tune.get("unarmed_damage", 8.0))
	var tool := inv.equipped_gather_tool()
	var climate := player.climate_resistance()
	var out := {
		"attack": swing * (1.0 + float(tune.get("damage_per_melee_level", 0.01)) * melee),
		"defense": (CombatTuning.num("creature_melee", "player_base_defense", 20.0) + inv.equipped_armor()) * player.statuses.defense_mult(),
		"accuracy": 100.0 * float(tune.get("base_accuracy", 1.0)) * player.statuses.accuracy_mult(),
		"crit": 100.0 * (float(tune.get("crit_base", 0.08)) + float(tune.get("crit_per_melee_level", 0.002)) * melee),
		"max_health": player.vitals.max_health + inv.equipped_health_bonus(),
		"energy": player.vitals.max_energy,
		"capacity": inv.slot_count,
		"gather_power": tool.gather_power() if tool else 0.0,
		"heat": roundi(float(climate.get("heat", 0.0))),
		"cold": roundi(float(climate.get("cold", 0.0))),
	}
	for group: String in powers_data():
		out[group + "_power"] = power(player, group)
	return out

## data/inv_ui.json "powers": {combat: {label, trees, icon}, crafting: ..., gathering: ...}.
static func powers_data() -> Dictionary:
	var p: Dictionary = (InvView.data().get("powers", {}) as Dictionary).duplicate()
	p.erase("_about")
	return p

## A power row: the highest skill level among its group's trees (design assumption 10).
static func power(player: Player, group: String) -> int:
	var best := 0
	for tree: String in (powers_data().get(group, {}) as Dictionary).get("trees", []):
		best = maxi(best, player.skills.level_of(tree) if player.skills else 0)
	return best

## "58" / "96%" / "1.40x" for a snapshot key (whole-number rows round, they do not truncate).
static func fmt(key: String, v: Variant) -> String:
	for r in ROWS:
		if r[0] == key:
			return str(r[2]) % (roundi(float(v)) if str(r[2]).contains("%d") else v)
	return str(v)

## Rows that differ between two snapshots: [label, before, after, gain?] (spec 13 s15 compare).
static func diff(a: Dictionary, b: Dictionary) -> Array:
	var out := []
	for r in ROWS:
		var k: String = r[0]
		if b.has(k) and fmt(k, a.get(k, 0)) != fmt(k, b[k]):
			out.append([r[1], fmt(k, a.get(k, 0)), fmt(k, b[k]), float(b[k]) > float(a.get(k, 0))])
	return out
