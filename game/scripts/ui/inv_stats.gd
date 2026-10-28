class_name InvStats
extends RefCounted
## The survivor's numbers for Character, Detailed Stats and My Info (spec 13 s13-15), ported from
## INVUI: read from the rules combat and the bag use, never accumulated, so nothing counts twice.
## Attack = Hunt's swing damage x the Melee bonus, Defense = the armour a bite reads, Accuracy = the
## hit chance before dodge.

## Snapshot keys in display order: [key, label, format].
const ROWS := [
	["attack", "Attack", "%d"], ["defense", "Defense", "%d"], ["accuracy", "Accuracy", "%d%%"],
	["crit", "Critical chance", "%.1f%%"], ["max_health", "Max health", "%d"], ["energy", "Max energy", "%d"],
	["capacity", "Bag capacity", "%d"], ["gather_power", "Held tool power", "%.2fx"],
	["heat", "Heat resistance", "%d"], ["cold", "Cold resistance", "%d"],
]

static func snapshot(player: Player) -> Dictionary:
	if player == null:
		return {}
	var inv := player.inventory
	var tune := CombatTuning.section("player_melee")
	var melee := player.skills.level_of("melee") if player.skills else 0
	var w := inv.equipped_weapon()
	if w and w.is_broken():
		w = null # a broken weapon fights as bare hands (Hunt._weapon)
	var swing := player.hunt._swing_damage(w) if player.hunt else float(tune.get("unarmed_damage", 8.0))
	var tool := inv.equipped_gather_tool()
	var climate := player.climate_resistance()
	var def_mult: float = player.statuses.defense_mult() if player.statuses else 1.0
	var acc_mult: float = player.statuses.accuracy_mult() if player.statuses else 1.0
	var out := {
		"attack": swing * (1.0 + float(tune.get("damage_per_melee_level", 0.01)) * melee),
		"defense": (CombatTuning.num("creature_melee", "player_base_defense", 20.0) + inv.equipped_armor()) * def_mult,
		"accuracy": 100.0 * float(tune.get("base_accuracy", 1.0)) * acc_mult,
		"crit": 100.0 * (float(tune.get("crit_base", 0.08)) + float(tune.get("crit_per_melee_level", 0.002)) * melee),
		"max_health": (player.vitals.max_health if player.vitals else 0.0) + inv.equipped_health_bonus(),
		"energy": player.vitals.max_energy if player.vitals else 0.0,
		"capacity": inv.slot_count,
		"gather_power": tool.gather_power() if tool else 0.0,
		"heat": roundi(float(climate.get("heat", 0.0))),
		"cold": roundi(float(climate.get("cold", 0.0))),
	}
	for group: String in powers_data():
		out[group + "_power"] = power(player, group)
	return out

## data/inv_ui.json "powers": {combat: {label, trees}, crafting: ..., gathering: ...}.
static func powers_data() -> Dictionary:
	var p: Dictionary = (InvAttributes.data().get("powers", {}) as Dictionary).duplicate()
	p.erase("_about")
	return p

## A power row: the highest skill level among its group's trees.
static func power(player: Player, group: String) -> int:
	var best := 0
	for tree: Variant in (powers_data().get(group, {}) as Dictionary).get("trees", []):
		best = maxi(best, player.skills.level_of(str(tree)) if player and player.skills else 0)
	return best

## "58" / "96%" / "1.40x" for a snapshot key.
static func fmt(key: String, v: Variant) -> String:
	for r: Array in ROWS:
		if r[0] == key:
			return str(r[2]) % (roundi(float(v)) if str(r[2]).contains("%d") else float(v))
	return str(v)
