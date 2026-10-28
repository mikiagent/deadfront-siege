class_name InvAttributes
extends RefCounted
## Spec 04 material traits on one instance, sorted into positive (gold), negative (grey) and rare
## (green) for the item card and the grid's rare mark (spec 13 s10-11). Ported from INVUI; the rare
## list is rules.json crafting.rare_attributes (Crafting.rare_attributes), the gold and grey ones are
## data/inv_ui.json attribute_classes. Any other attribute (tint, hardness, quality, look) is not a trait.

const CLASSES := ["positive", "negative", "rare"]
## The card's colours: gold positive, grey negative, green rare (spec 13 s2 / s11).
const COLORS := {"positive": Color("#D9B65A"), "negative": Color("#A6A69B"), "rare": Color("#67B84E")}

static var _data: Dictionary = {}

## data/inv_ui.json, read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/inv_ui.json"))
		_data = parsed if parsed is Dictionary else {"_missing": true}
	return _data

## "positive" / "negative" / "rare", or "" when `key` is not a trait.
static func class_of(key: String) -> String:
	if Crafting.is_rare_attribute(StringName(key)):
		return "rare"
	var row: Variant = (data().get("attribute_classes", {}) as Dictionary).get(key)
	return str((row as Dictionary).get("class", "")) if row is Dictionary else ""

## {positive: [{key, label, level}], negative: [...], rare: [...]}; level 0 = a trait without a level
## (W2-GATHER stamps a rare trait as true, CRAFTFEEL as 1).
static func sections(stack: ItemStack) -> Dictionary:
	var out := {"positive": [], "negative": [], "rare": []}
	if stack == null:
		return out
	var classes: Dictionary = data().get("attribute_classes", {})
	for k: Variant in stack.attributes:
		var cls := class_of(str(k))
		var v: Variant = stack.attributes[k]
		if cls == "" or v == null or (v is bool and not v) or ((v is int or v is float) and float(v) <= 0.0):
			continue
		var row: Variant = classes.get(str(k))
		var label := str((row as Dictionary).get("label", "")) if row is Dictionary else ""
		(out[cls] as Array).append({"key": str(k), "label": label if label != "" else str(k).capitalize(),
			"level": int(v) if (v is int or v is float) else 0})
	for k: String in out:
		(out[k] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.label) < str(b.label))
	return out

static func has_rare(stack: ItemStack) -> bool:
	return not (sections(stack).rare as Array).is_empty()

## "Firm Lv. 8", or just "Black Sheen" for a trait without a level.
static func line(row: Dictionary) -> String:
	return "%s %s" % [row.label, LevelDisplay.label(int(row.level))] if int(row.level) > 0 else str(row.label)
