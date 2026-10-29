class_name ItemTags
extends RefCounted
## An item's classification tags (owner 2026-10-28: "the bag lists how it's classified (strap,
## tendon, edible, meat)"). The canonical list is the def's `categories` in data/items.json: recipes
## already accept a slot by category, so a tag IS a category (tendon tagged strap fills a strap slot,
## tagged food it eats through the normal eat flow). Stable API for other systems (craft radial,
## construction slots): ItemTags.tags(id), ItemTags.has_tag(id, tag), ItemTags.label(tag).

## Every tag of an item id, in data order; [] for an unknown id.
static func tags(id: StringName) -> Array[StringName]:
	var d: ItemDef = _def(id)
	return d.categories.duplicate() if d else ([] as Array[StringName])

static func has_tag(id: StringName, tag: StringName) -> bool:
	var d: ItemDef = _def(id)
	return d != null and d.has_category(tag)

## The chip text: "strap_material" -> "Strap Material". Bookkeeping tags (tier_*, _*) read "".
static func label(tag: StringName) -> String:
	var t := str(tag)
	return "" if t.begins_with("tier_") or t.begins_with("_") else t.capitalize()

## The Data autoload by name: a `--script` test compiles this before autoloads exist.
static func _def(id: StringName) -> ItemDef:
	var loop := Engine.get_main_loop()
	var data: Node = (loop as SceneTree).get_root().get_node_or_null("Data") if loop is SceneTree else null
	return data.call("item", id) as ItemDef if data else null
