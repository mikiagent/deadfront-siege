class_name Blueprints
extends RefCounted
## Placeable blueprints (owner's spec 30 §§2-9), loaded once from data/blueprints.json. Every number
## lives in that file: a blueprint names tag-based ingredient slots, the Construction level and the
## learned construction-tree node it needs, its footprint, its construction workload and the finished
## station's tags and level source. BlueprintDefinition stays separate from ConstructionSite (world
## escrow) and CraftStation (a finished, working station), as spec 30 §14 asks.

const PATH := "res://data/blueprints.json"

static var _rows: Dictionary = {}

static func all() -> Dictionary:
	if _rows.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for row: Variant in (parsed as Dictionary).get("blueprints", []):
				if row is Dictionary and str((row as Dictionary).get("id", "")) != "":
					_rows[str((row as Dictionary)["id"])] = row
	return _rows

static func of(id: StringName) -> Dictionary:
	return all().get(str(id), {}) as Dictionary

static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in all():
		out.append(all()[id] as Dictionary)
	return out

static func category_of(bp: Dictionary) -> String:
	return str(bp.get("category", "storage_workbench"))

static func footprint(bp: Dictionary) -> Vector2i:
	var fp: Variant = bp.get("footprint", [2, 1])
	if fp is Array and (fp as Array).size() >= 2:
		return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	return Vector2i.ONE

## Every prerequisite the survivor does not meet, in the order the details panel shows them
## (spec 30 §3: "Show precise unmet prerequisites instead of only disabling the button").
static func unmet(player: Player, bp: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var need := int(bp.get("construction_level", 0))
	var level := player.skills.level_of("construction") if player and player.skills else 0
	if level < need:
		out.append("Construction %s (you are %s)" % [LevelDisplay.label(need), LevelDisplay.label(level)])
	var node := str(bp.get("skill_node", ""))
	if node != "" and player and player.skills and not player.skills.is_unlocked("construction", node):
		out.append("learn %s (%s, %d SP)" % [_node_name(node), SkillState.NAMES.get("construction", "Construction"),
			_node_sp(node)])
	return out

static func _node_sp(node_id: String) -> int:
	var sk := PlayerRegistry.local()
	if sk and sk.skills:
		for n in sk.skills.nodes("construction"):
			if str(n.get("id", "")) == node_id:
				return int(n.get("sp", 0))
	return 0

static func _node_name(node_id: String) -> String:
	var sk := PlayerRegistry.local()
	if sk and sk.skills:
		for n in sk.skills.nodes("construction"):
			if str(n.get("id", "")) == node_id:
				return str(n.get("name", node_id))
	return node_id.capitalize()

## Spec 30 §9: avg = weighted average of the level-contributing exact ingredients, then
## min(clamp(avg, blueprint_min, blueprint_max), Construction level).
## `levels` carries one entry per contributing unit (so quantities weight themselves).
static func result_level(bp: Dictionary, levels: Array, construction_level: int) -> int:
	if levels.is_empty():
		return 0
	var total := 0
	for l in levels:
		total += maxi(1, l)
	var avg := int(floor(float(total) / float(levels.size())))
	var lo := int(bp.get("level_min", 1))
	var hi := int(bp.get("level_max", 60))
	return mini(clampi(avg, lo, hi), maxi(1, construction_level))

## Whether an instance satisfies a slot's accepted tags and minimum level. Tags are the item's
## categories (data/items.json), never its display name (spec 30 §10).
static func fits(slot: Dictionary, s: ItemStack) -> bool:
	if s == null or s.def() == null:
		return false
	if s.level < int(slot.get("min_level", 1)):
		return false
	var tags: Array = slot.get("accepted_tags", [])
	if tags.is_empty():
		return true
	for t: Variant in tags:
		if s.def().has_category(StringName(str(t))):
			return true
	return false

static func slot_label(slot: Dictionary) -> String:
	var label := str(slot.get("label", ""))
	if label != "":
		return label
	var tags: Array = slot.get("accepted_tags", [])
	return str(tags[0]).replace("_", " ").capitalize() if not tags.is_empty() else str(slot.get("slot_id", "?"))
