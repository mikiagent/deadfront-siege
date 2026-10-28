class_name LevelDisplay
extends RefCounted
## Display words every screen shares: the one player level, recipe levels, item names and stat lines.
## Before this the HUD, the bag and the fatigue panel showed three different numbers (pioneer level, pioneer level + 1, skill-tree average).
## The pioneer level (World.pioneer_level, fed by every skill XP grant) is the player level. It is
## stored from 0 but a new survivor reads "Lv. 1" (orchestrator 2026-10-20: Durango, ARK and the old bag start at 1).

## Shown where a level cannot be worked out yet (a recipe the bag cannot make).
const NONE := "Lv. —"

## The World autoload, resolved at runtime: `--script` test entry points compile this file before
## the engine registers autoloads, where a bare `World` identifier is a compile error.
static func world() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("World")

## The Data autoload, resolved at runtime for the same reason as world().
static func data() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("Data")

static func player_level() -> int:
	var w := world()
	return shown(int(w.get("pioneer_level")) if w else 0)

## The level a stored pioneer level reads as. World.pioneer_changed carries the stored value; a
## handler that formats it goes through here instead of re-reading World.
static func shown(stored: int) -> int:
	return stored + 1

## Every level label goes through here, so the format is the same on every screen.
static func label(level: int) -> String:
	return "Lv. %d" % level

static func player_label() -> String:
	return label(player_level())

static var _titles: Dictionary = {}

## The title a survivor at shown `level` holds: the highest titles.json key at or under it. A new
## survivor holds key 1, "Venture into the World", from character creation (orchestrator 2026-10-20).
static func current_title(level: int) -> String:
	if _titles.is_empty() and FileAccess.file_exists("res://data/skills/titles.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/titles.json"))
		_titles = parsed if parsed is Dictionary else {}
	var best := 0
	for key in _titles:
		if str(key).is_valid_int() and int(key) <= level and int(key) > best:
			best = int(key)
	return str(_titles.get(str(best), ""))

## Titles earned at shown `level`, lowest first: every titles.json key at or under it (the rule above).
static func earned_titles(level: int) -> PackedStringArray:
	current_title(level)  # loads _titles
	var keys: Array = _titles.keys().filter(func (k: Variant) -> bool: return str(k).is_valid_int() and int(k) <= level)
	keys.sort_custom(func (a: Variant, b: Variant) -> bool: return int(a) < int(b))
	var out: PackedStringArray = []
	for k: Variant in keys:
		out.append(str(_titles[k]))
	return out

## The title worn over her name: World.player_title while she has earned it, else "" (no line).
static func worn_title() -> String:
	var t := World.player_title
	return t if t != "" and earned_titles(player_level()).has(t) else ""

## A recipe's level: "Lv. 12", or NONE when the bag cannot make it yet. Crafting.preview_level
## reports the recipe's top level for an invalid pick, which read as "Lv. 60" on every row the
## player could not craft.
static func recipe_label(inv: Inventory, rec: Dictionary) -> String:
	if inv == null or not Crafting.picks_valid(inv, rec, Crafting.default_picks(inv, rec)):
		return NONE
	return label(Crafting.preview_level(inv, rec))

## Readable name for an item id or ingredient category ("lashing" -> "Lashing").
static func nice_name(id: String) -> String:
	var catalog := data()
	var d: ItemDef = catalog.item(StringName(id)) if catalog else null
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
