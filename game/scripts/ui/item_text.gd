class_name ItemText
extends RefCounted
## Item words shared by craft, the station radial and the atlas: readable names and stat lines.

## Readable name for an item id or ingredient category ("lashing" -> "Lashing").
static func nice_name(id: String) -> String:
	var d := Data.item(StringName(id))
	if d and d.display_name != "":
		return d.display_name
	return id.replace("_", " ").capitalize()

## What the item does, from its definition (base values; crafted level scales them).
static func stat_lines(def: ItemDef) -> PackedStringArray:
	var out: PackedStringArray = []
	if def == null:
		return out
	if def.damage > 0.0:
		out.append("Damage %.0f" % def.damage)
	if def.attack_rate > 0.0:
		out.append("Attack rate %.1f/s" % def.attack_rate)
	if def.range_m > 0.0:
		out.append("Range %.0f m" % def.range_m)
	if def.armor_value > 0.0:
		out.append("Armor %.0f" % def.armor_value)
	if def.health_bonus > 0.0:
		out.append("Health +%.0f" % def.health_bonus)
	if def.food_energy > 0.0:
		out.append("Energy +%.0f" % def.food_energy)
	if def.capture_tier > 0:
		out.append("Capture tier %d" % def.capture_tier)
	if def.tool_class != &"none" and def.tool_class != &"":
		out.append("Tool: %s" % str(def.tool_class).capitalize())
	if def.max_durability > 0:
		out.append("Durability %d" % def.max_durability)
	return out
