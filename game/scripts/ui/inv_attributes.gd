class_name InvAttributes
extends RefCounted
## Spec 04 material attributes on an instance, sorted into positive (gold), negative (grey) and rare
## (green) for the inspect panel and the rare marker (spec 13 s10-11). Only keys listed in
## data/inv_ui.json attribute_classes are traits; technical keys (tint, hardness, ...) never show.

## {positive: [{key, label, level}], negative: [...], rare: [...]}; level 0 = a trait with no level.
static func sections(stack: ItemStack) -> Dictionary:
	var out := {"positive": [], "negative": [], "rare": []}
	if stack == null:
		return out
	var classes: Dictionary = InvView.data().get("attribute_classes", {})
	for k: Variant in stack.attributes:
		var row: Variant = classes.get(str(k))
		if not row is Dictionary or not out.has(str(row.get("class", ""))):
			continue
		var v: Variant = stack.attributes[k]
		if v == null or (v is bool and not v):
			continue
		var lvl := int(v) if (v is int or v is float) else 0
		(out[str(row.class)] as Array).append({"key": str(k), "label": str(row.get("label", k)), "level": lvl})
	for k in out:
		(out[k] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.label) < str(b.label))
	return out

static func has_rare(stack: ItemStack) -> bool:
	return not (sections(stack).rare as Array).is_empty()

## "Firm Lv. 8", or just "Black Sheen" for a trait without a level.
static func line(row: Dictionary) -> String:
	return "%s %s" % [row.label, LevelDisplay.label(int(row.level))] if int(row.level) > 0 else str(row.label)
