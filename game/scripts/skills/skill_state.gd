class_name SkillState
extends Node
## The twelve Durango skill trees (game/data/skills/trees.json): proficiency level and XP per
## tree, skill points earned per level (trees.json sp_budget), nodes unlocked with SP, and the
## occupation that seeded proficiency 20 in one tree. Owned by the player as "Skills".

signal skill_changed(tree: StringName, level: int)

const TREES_PATH := "res://data/skills/trees.json"
const OCCUPATIONS_PATH := "res://data/skills/occupations.json"
const ORDER: Array[String] = ["survival", "gathering", "butchering", "processing", "melee", "ranged", "defense", "weapon_tools", "tailoring", "construction", "cooking", "farming"]
const GLYPHS := {"survival": "🧭", "gathering": "🌿", "butchering": "🔪", "processing": "⚙", "melee": "⚔", "ranged": "🏹", "defense": "🛡", "weapon_tools": "🔨", "tailoring": "🧵", "construction": "🏗", "cooking": "🍲", "farming": "🌾"}
const NAMES := {"survival": "Survival", "gathering": "Gathering", "butchering": "Butchering", "processing": "Processing", "melee": "Melee", "ranged": "Ranged", "defense": "Defense", "weapon_tools": "Weapon / Tools", "tailoring": "Tailoring", "construction": "Construction", "cooking": "Cooking", "farming": "Farming"}
const MAX_LEVEL := 60

var trees: Dictionary = {}   # id -> {level: int, xp: float, unlocked: Array}
var defs: Dictionary = {}    # id -> tree definition from trees.json
var budget: Dictionary = {}
var sp_available: int = 0
var sp_spent: int = 0
var occupation: String = ""

func _ready() -> void:
	_load()
	if World and World.has_signal("island_changed"):
		World.island_changed.connect(func (_id: StringName) -> void: add_xp("survival", 5))

func _load() -> void:
	var root: Dictionary = {}
	if FileAccess.file_exists(TREES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREES_PATH))
		if parsed is Dictionary:
			root = parsed
	budget = root.get("sp_budget", {"per_level": [10, 12, 14, 16], "level_bands": [20, 40, 55, 60]})
	var td: Dictionary = root.get("trees", {})
	for id in ORDER:
		defs[id] = td.get(id, {"nodes": []})
		if not trees.has(id):
			trees[id] = {"level": 0, "xp": 0.0, "unlocked": []}

## XP needed to go from `level` to the next. ASSUMPTION: 20 + 8 per level (level 60 ≈ 15k XP total).
static func xp_to_next(level: int) -> float:
	return 20.0 + float(level) * 8.0

func level_of(tree: String) -> int:
	return int(trees.get(tree, {}).get("level", 0))

func xp_of(tree: String) -> float:
	return float(trees.get(tree, {}).get("xp", 0.0))

func add_xp(tree: String, amount: float) -> void:
	if not trees.has(tree) or amount <= 0.0:
		return
	if World and World.has_method("add_xp"):
		World.add_xp(int(ceil(amount)))  # every skill gain is also general player XP (one bar)
	var t: Dictionary = trees[tree]
	if int(t["level"]) >= MAX_LEVEL:
		return
	t["xp"] = float(t["xp"]) + amount
	while int(t["level"]) < MAX_LEVEL and float(t["xp"]) >= xp_to_next(int(t["level"])):
		t["xp"] = float(t["xp"]) - xp_to_next(int(t["level"]))
		t["level"] = int(t["level"]) + 1
		var sp := sp_for_level(int(t["level"]))
		sp_available += sp
		print("[skill] %s %d (+%d SP)" % [tree, int(t["level"]), sp])
		skill_changed.emit(StringName(tree), int(t["level"]))

func sp_for_level(level: int) -> int:
	var per: Array = budget.get("per_level", [10, 12, 14, 16])
	var bands: Array = budget.get("level_bands", [20, 40, 55, 60])
	for i in bands.size():
		if level <= int(bands[i]):
			return int(per[mini(i, per.size() - 1)])
	return int(per[per.size() - 1])

func nodes(tree: String) -> Array:
	return (defs.get(tree, {}) as Dictionary).get("nodes", [])

func is_unlocked(tree: String, node_id: String) -> bool:
	return (trees.get(tree, {}).get("unlocked", []) as Array).has(node_id)

## "owned" | "available" | "locked" (with a reason in the second slot)
func node_state(tree: String, node: Dictionary) -> Array:
	var id := str(node.get("id", ""))
	if is_unlocked(tree, id):
		return ["owned", ""]
	if level_of(tree) < int(node.get("level", 1)):
		return ["locked", "needs %s %d" % [NAMES.get(tree, tree), int(node.get("level", 1))]]
	var req: Variant = node.get("requires", null)
	if req != null and str(req) != "" and not is_unlocked(tree, str(req)):
		return ["locked", "needs %s" % str(req)]
	if sp_available < int(node.get("sp", 0)):
		return ["locked", "needs %d SP" % int(node.get("sp", 0))]
	return ["available", ""]

func unlock(tree: String, node_id: String) -> bool:
	for n in nodes(tree):
		if str(n.get("id", "")) != node_id:
			continue
		var st := node_state(tree, n)
		if st[0] != "available":
			print("[skill] cannot unlock %s: %s" % [node_id, st[1] if st[1] != "" else st[0]])
			return false
		var cost := int(n.get("sp", 0))
		sp_available -= cost
		sp_spent += cost
		(trees[tree]["unlocked"] as Array).append(node_id)
		if tree == "survival":
			Data.set_survival_unlocked(StringName(node_id), true)
			# trees.json numbers these nodes capture_technique_1..5, survival.json numbers the
			# same nodes capture_technique_I..V. With no id in common the bridge never fired, so
			# Data.has_capture_technique() was permanently false: net capture always bailed and
			# every skill-gated rare butchering drop was unreachable. Mirror to both spellings.
			var roman := _roman_id(node_id)
			if roman != "":
				Data.set_survival_unlocked(StringName(roman), true)
		print("[skill] unlocked %s (%s, %d SP)" % [node_id, tree, cost])
		skill_changed.emit(StringName(tree), level_of(tree))
		return true
	return false

## "capture_technique_3" -> "capture_technique_III", or "" when the id has no trailing number.
static func _roman_id(node_id: String) -> String:
	var cut := node_id.rfind("_")
	if cut <= 0:
		return ""
	var tail := node_id.substr(cut + 1)
	if not tail.is_valid_int():
		return ""
	const NUMERALS := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	var n := int(tail)
	if n < 1 or n >= NUMERALS.size():
		return ""
	return "%s_%s" % [node_id.substr(0, cut), NUMERALS[n]]


## Refund a node (trees.json refund rules are day-limited; ASSUMPTION: free while there is no clock for it).
func refund(tree: String, node_id: String) -> bool:
	var arr: Array = trees[tree]["unlocked"]
	if not arr.has(node_id):
		return false
	for n in nodes(tree):
		if str(n.get("id", "")) == node_id:
			arr.erase(node_id)
			var cost := int(n.get("sp", 0))
			sp_available += cost
			sp_spent -= cost
			print("[skill] refunded %s (+%d SP)" % [node_id, cost])
			return true
	return false

static func occupations() -> Array:
	if not FileAccess.file_exists(OCCUPATIONS_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OCCUPATIONS_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("occupations", [])
	return []

func apply_occupation(id: String) -> void:
	for row in occupations():
		if str(row.get("id", "")) != id:
			continue
		var tree := str(row.get("tree", "gathering"))
		occupation = id
		if trees.has(tree):
			var was := int(trees[tree]["level"])
			var now := maxi(was, 20)
			trees[tree]["level"] = now
			trees[tree]["xp"] = 0.0
			# Those levels have to pay out, or a new survivor opens a skill screen showing a
			# level-20 tree, a wall of affordable-looking nodes and 0 SP to spend on any of them.
			var granted := 0
			for lvl in range(was + 1, now + 1):
				granted += sp_for_level(lvl)
			sp_available += granted
			print("[skill] %s 20 (occupation %s, +%d SP)" % [tree, id, granted])
			skill_changed.emit(StringName(tree), now)
		return
	print("[skill] unknown occupation %s" % id)

## Character level: ASSUMPTION sum of tree levels / 4, capped at 60.
func character_level() -> int:
	var total := 0
	for id in ORDER:
		total += level_of(id)
	return mini(MAX_LEVEL, int(total / 4))

func character_progress() -> float:
	var total := 0
	for id in ORDER:
		total += level_of(id)
	return float(total % 4) / 4.0

func to_dict() -> Dictionary:
	var out := {"occupation": occupation, "sp_available": sp_available, "sp_spent": sp_spent, "trees": {}}
	for id in ORDER:
		var t: Dictionary = trees[id]
		out["trees"][id] = {"level": int(t["level"]), "xp": float(t["xp"]), "unlocked": (t["unlocked"] as Array).duplicate()}
	return out

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	occupation = str(d.get("occupation", ""))
	sp_available = int(d.get("sp_available", 0))
	sp_spent = int(d.get("sp_spent", 0))
	var td: Dictionary = d.get("trees", {})
	for id in ORDER:
		var row: Dictionary = td.get(id, {})
		trees[id] = {"level": int(row.get("level", 0)), "xp": float(row.get("xp", 0.0)), "unlocked": (row.get("unlocked", []) as Array).duplicate()}
		if id == "survival":
			for nid in trees[id]["unlocked"]:
				if Data.survival_nodes.has(StringName(str(nid))):
					Data.set_survival_unlocked(StringName(str(nid)), true)
	print("[skill] restored %d trees" % ORDER.size())
