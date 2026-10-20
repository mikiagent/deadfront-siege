class_name SkillState
extends Node
## The twelve Durango skill trees (game/data/skills/trees.json) on Durango's 1-60 scale: level and
## XP per tree (every tree starts at Lv. 1), skill points earned per level (trees.json sp_budget),
## nodes bought with SP or learned free ("auto") once their level is reached, and the occupation
## that seeded Lv. 20 in one tree. A tree cannot pass the character level (spec 03). Effects of
## learned nodes are read through SkillRules. Owned by the player as "Skills".

signal skill_changed(tree: StringName, level: int)

const TREES_PATH := "res://data/skills/trees.json"
const OCCUPATIONS_PATH := "res://data/skills/occupations.json"
const ORDER: Array[String] = ["survival", "gathering", "butchering", "processing", "melee", "ranged", "defense", "weapon_tools", "tailoring", "construction", "cooking", "farming"]
const GLYPHS := {"survival": "🧭", "gathering": "🌿", "butchering": "🔪", "processing": "⚙", "melee": "⚔", "ranged": "🏹", "defense": "🛡", "weapon_tools": "🔨", "tailoring": "🧵", "construction": "🏗", "cooking": "🍲", "farming": "🌾"}
const NAMES := {"survival": "Survival", "gathering": "Gathering", "butchering": "Butchering", "processing": "Processing", "melee": "Melee", "ranged": "Ranged", "defense": "Defense", "weapon_tools": "Weapon / Tools", "tailoring": "Tailoring", "construction": "Construction", "cooking": "Cooking", "farming": "Farming"}
const MAX_LEVEL := 60
const MIN_LEVEL := 1
const OCCUPATION_LEVEL := 20
## Save revision of to_dict. 1 (no key): trees stored from 0, SP stored as a free number.
const REV := 2

var trees: Dictionary = {}   # id -> {level: int, xp: float, unlocked: Array}
var defs: Dictionary = {}    # id -> tree definition from trees.json
var budget: Dictionary = {}
var sp_available: int = 0
var sp_spent: int = 0
var sp_earned: int = 0      # every SP the levels paid; available = earned - cost of learned nodes
var occupation: String = ""
var config: Dictionary = {}  # trees.json minus the trees (bonded_base, category_cap, reference)

func _ready() -> void:
	_load()
	if World and World.has_signal("island_changed"):
		World.island_changed.connect(func (_id: StringName) -> void: add_xp("survival", 5))
	if World and World.has_signal("pioneer_changed"):
		World.pioneer_changed.connect(func (_lv: int) -> void: _resolve_all())

func _load() -> void:
	var root: Dictionary = {}
	if FileAccess.file_exists(TREES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREES_PATH))
		if parsed is Dictionary:
			root = parsed
	budget = root.get("sp_budget", {"per_level": [10, 12, 14, 16], "level_bands": [20, 40, 55, 60]})
	config = root.duplicate()
	config.erase("trees")
	var td: Dictionary = root.get("trees", {})
	for id in ORDER:
		defs[id] = td.get(id, {"nodes": []})
		if not trees.has(id):
			trees[id] = {"level": MIN_LEVEL, "xp": 0.0, "unlocked": []}
		_learn_autos(id)

## XP needed to go from `level` to the next. ASSUMPTION: 20 + 8 per level (level 60 ≈ 15k XP total).
static func xp_to_next(level: int) -> float:
	return 20.0 + float(level) * 8.0

func level_of(tree: String) -> int:
	return int(trees.get(tree, {}).get("level", MIN_LEVEL))

func xp_of(tree: String) -> float:
	return float(trees.get(tree, {}).get("xp", 0.0))

func add_xp(tree: String, amount: float, mirrored: bool = false) -> void:
	if not trees.has(tree) or amount <= 0.0:
		return
	if not mirrored and World and World.has_method("add_xp"):
		World.add_xp(int(ceil(amount)))  # every skill gain is also general player XP (one bar)
	if tree != "survival":
		add_xp("survival", amount, true) # any play advances the passive route proficiency
	var t: Dictionary = trees[tree]
	if int(t["level"]) >= MAX_LEVEL:
		return
	t["xp"] = float(t["xp"]) + amount
	_resolve(tree)

## Level-ups the banked XP allows. At the character-level cap the bar fills and waits (the rest is
## dropped; ASSUMPTION, spec 03 only asks for consistency) until World.pioneer_changed lifts it.
func _resolve(tree: String) -> void:
	var t: Dictionary = trees[tree]
	var cap := level_cap(tree)
	while int(t["level"]) < cap and float(t["xp"]) >= xp_to_next(int(t["level"])):
		t["xp"] = float(t["xp"]) - xp_to_next(int(t["level"]))
		t["level"] = int(t["level"]) + 1
		var sp := sp_for_level(int(t["level"]))
		sp_available += sp
		sp_earned += sp
		print("[skill] %s %d (+%d SP)" % [tree, int(t["level"]), sp])
		_learn_autos(tree)
		skill_changed.emit(StringName(tree), int(t["level"]))
	if int(t["level"]) >= cap:
		t["xp"] = minf(float(t["xp"]), xp_to_next(int(t["level"])))

func _resolve_all() -> void:
	for id in ORDER:
		_resolve(id)

## Highest level `tree` may reach now: the character level (spec 03), but never below a level the
## occupation granted (ASSUMPTION: the Lv. 20 head start predates the cap and keeps working).
func level_cap(tree: String) -> int:
	var cap := character_level() if str(config.get("category_cap", "character_level")) == "character_level" else MAX_LEVEL
	if tree == occupation_tree():
		cap = maxi(cap, OCCUPATION_LEVEL)
	return mini(MAX_LEVEL, cap)

func occupation_tree() -> String:
	for row in occupations():
		if str(row.get("id", "")) == occupation:
			return str(row.get("tree", ""))
	return ""

## Learn every auto node whose level and prerequisite are met (free, spec 12 "Lv1 AUTO").
func _learn_autos(tree: String) -> void:
	var owned: Array = trees[tree]["unlocked"]
	for n in nodes(tree):
		var id := str(n.get("id", ""))
		var req: Variant = n.get("requires", null)
		if bool(n.get("auto", false)) and not owned.has(id) and level_of(tree) >= int(n.get("level", 1)) \
				and (req == null or str(req) == "" or owned.has(str(req))):
			owned.append(id)

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
	if bool(node.get("auto", false)) and level_of(tree) < int(node.get("level", 1)):
		return ["locked", "learned free at %s %d" % [NAMES.get(tree, tree), int(node.get("level", 1))]]
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
## Auto nodes cannot be refunded, and a node stays while a learned node needs it (spec 03).
## The effect leaves with it: a refunded survival node clears its Data capture mirror too.
func refund(tree: String, node_id: String) -> bool:
	var arr: Array = trees[tree]["unlocked"]
	if not arr.has(node_id):
		return false
	for n in nodes(tree):
		if str(n.get("id", "")) == node_id:
			if bool(n.get("auto", false)):
				print("[skill] cannot refund %s: learned automatically" % node_id)
				return false
			var deps := SkillRules.learned_dependents(self, tree, node_id)
			if not deps.is_empty():
				print("[skill] cannot refund %s: %s needs it" % [node_id, ", ".join(deps)])
				return false
			arr.erase(node_id)
			var cost := int(n.get("sp", 0))
			sp_available += cost
			sp_spent -= cost
			if tree == "survival":
				_mirror_survival(node_id, false)
			print("[skill] refunded %s (+%d SP)" % [node_id, cost])
			skill_changed.emit(StringName(tree), level_of(tree))
			return true
	return false

func _mirror_survival(node_id: String, on: bool) -> void:
	if Data.survival_nodes.has(StringName(node_id)):
		Data.set_survival_unlocked(StringName(node_id), on)
	var roman := _roman_id(node_id)
	if roman != "" and Data.survival_nodes.has(StringName(roman)):
		Data.set_survival_unlocked(StringName(roman), on)

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
			sp_earned += granted
			_learn_autos(tree)
			print("[skill] %s 20 (occupation %s, +%d SP)" % [tree, id, granted])
			skill_changed.emit(StringName(tree), now)
		return
	print("[skill] unknown occupation %s" % id)

## Character level 1-60 (spec 03): the one player level every screen shows (LevelDisplay, fed by
## every skill XP grant through World.add_xp). With no World (pure data checks) nothing caps.
func character_level() -> int:
	if World == null:
		return MAX_LEVEL
	return clampi(LevelDisplay.player_level(), MIN_LEVEL, MAX_LEVEL)

func character_progress() -> float:
	return World.pioneer_progress() if World else 0.0

func to_dict() -> Dictionary:
	var out := {"rev": REV, "occupation": occupation, "sp_available": sp_available, "sp_spent": sp_spent, "sp_earned": sp_earned, "trees": {}}
	for id in ORDER:
		var t: Dictionary = trees[id]
		out["trees"][id] = {"level": int(t["level"]), "xp": float(t["xp"]), "unlocked": (t["unlocked"] as Array).duplicate()}
	return out

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	occupation = str(d.get("occupation", ""))
	var rev := int(d.get("rev", 1))
	var td: Dictionary = d.get("trees", {})
	var bound := 0  # most SP these levels can have paid
	for id in ORDER:
		var row: Dictionary = td.get(id, {}) if td.get(id) is Dictionary else {}
		var stored := int(row.get("level", MIN_LEVEL if rev >= REV else 0))
		# rev 1 paid SP for levels 1..L and stored a new tree as 0; it now reads Lv. 1.
		bound += SkillRules.paid_for_level(self, stored) + (sp_for_level(1) if rev < REV and stored >= 1 else 0)
		trees[id] = {"level": clampi(stored, MIN_LEVEL, MAX_LEVEL), "xp": float(row.get("xp", 0.0)), "unlocked": (row.get("unlocked", []) as Array).duplicate()}
	# SP are derived, never trusted: earned (rev 1: what its levels paid) minus what the learned
	# nodes cost today, so a cost changed in trees.json refunds or charges the difference.
	sp_earned = bound if rev < REV else clampi(int(d.get("sp_earned", 0)), 0, bound)
	for id in ORDER:
		_learn_autos(id)
	_recount_sp()
	for id in ORDER:
		if id == "survival":
			for nid in trees[id]["unlocked"]:
				_mirror_survival(str(nid), true)
	print("[skill] restored %d trees (rev %d, SP %d/%d)" % [ORDER.size(), rev, sp_available, sp_earned])

func _recount_sp() -> void:
	sp_spent = 0
	for id in ORDER:
		for n in nodes(id):
			if is_unlocked(id, str(n.get("id", ""))):
				sp_spent += int(n.get("sp", 0))
	sp_available = maxi(0, sp_earned - sp_spent)
