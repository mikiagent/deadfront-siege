class_name LevelDisplay
extends RefCounted
## Display words every screen shares: the one player level, recipe levels, item names and stat lines.
## Before this the HUD, the bag and the fatigue panel showed three different numbers (pioneer level, pioneer level + 1, skill-tree average).
## ASSUMPTION: the pioneer level (World.pioneer_level, fed by every skill XP grant) is the player
## level, shown as stored, matching the HUD badge, XP bar and level-up banner.

## Shown where a level cannot be worked out yet (a recipe the bag cannot make).
const NONE := "Lv. —"

static func player_level() -> int:
	return World.pioneer_level

## Every level label goes through here, so the format is the same on every screen.
static func label(level: int) -> String:
	return "Lv. %d" % level

static func player_label() -> String:
	return label(player_level())

## A recipe's level: "Lv. 12", or NONE when the bag cannot make it yet. Crafting.preview_level
## reports the recipe's top level for an invalid pick, which read as "Lv. 60" on every row the
## player could not craft.
static func recipe_label(inv: Inventory, rec: Dictionary) -> String:
	if inv == null or not Crafting.picks_valid(inv, rec, Crafting.default_picks(inv, rec)):
		return NONE
	return label(Crafting.preview_level(inv, rec))

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
