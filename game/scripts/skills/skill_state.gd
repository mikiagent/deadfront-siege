class_name SkillState
extends Node
## The twelve Durango skill trees (game/data/skills/trees.json) on Durango's 1-60 scale: level and
## XP per tree (every tree starts at Lv. 1), skill points earned per CHARACTER level (spec 03, trees.json sp_budget),
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
## node_state's lock for a node the game reads nothing from (spec 12:215); the sheet folds these rows.
const NOT_IN_GAME := "not in the game yet"

var trees: Dictionary = {}   # id -> {level: int, xp: float, unlocked: Array}
var defs: Dictionary = {}    # id -> tree definition from trees.json
var budget: Dictionary = {}
var sp_available: int = 0
var sp_spent: int = 0
var sp_earned: int = 0      # SP the character level has paid plus sp_extra (derived); available = earned - cost of learned nodes
var sp_extra: int = 0       # one-time SP outside character levels (spec 03 "extras"); a rev-1 save's unspent SP land here
var occupation: String = ""
var config: Dictionary = {}  # trees.json minus the trees (bonded_base, category_cap, refund, reference)
var refund_day: int = -1     # UTC day refunds_today counts (optional save fields, no rev bump)
var refunds_today: int = 0
var refused: String = ""     # why the last refund was refused, for the sheet
var _rules_cache: Dictionary = {} # SkillRules' lookups over trees.json and Data.recipes (built once, see SkillRules._index)

func _ready() -> void:
	_load()
	if World and World.has_signal("island_changed"):
		World.island_changed.connect(func (_id: StringName) -> void: add_xp("survival", 5))
	if World and World.has_signal("pioneer_changed"):
		World.pioneer_changed.connect(func (_lv: int) -> void: _on_character_level())

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
	_rules_cache = {} # built from defs
	for id in ORDER:
		defs[id] = td.get(id, {"nodes": []})
		if not trees.has(id):
			trees[id] = {"level": MIN_LEVEL, "xp": 0.0, "unlocked": []}
		_learn_autos(id)
	_recount_sp()

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
		print("[skill] %s %d" % [tree, int(t["level"])])
		_learn_autos(tree)
		skill_changed.emit(StringName(tree), int(t["level"]))
	if int(t["level"]) >= cap:
		t["xp"] = minf(float(t["xp"]), xp_to_next(int(t["level"])))

## A character level-up pays its SP (spec 03: SP come from character levels, not tree levels)
## and releases tree levels that were waiting at the old cap.
func _on_character_level() -> void:
	_recount_sp()
	for id in ORDER:
		_resolve(id)

## Highest level `tree` may reach now: the character level (spec 03), but never below a level the
## occupation granted. Docs conflict, open owner decision (W2-SKILLS report): spec 03:7 and skills.md:7
## cap every tree at the character level, PRD 5.1 starts the occupation tree at 20; until the owner
## rules, the Lv. 20 head start keeps working.
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
	if not bool(node.get("auto", false)) and not SkillRules.buyable(self, tree, id):
		return ["locked", NOT_IN_GAME]
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
		(trees[tree]["unlocked"] as Array).append(node_id)
		_recount_sp() # SP stay derived (earned - cost of learned nodes), never adjusted by hand
		if tree == "survival":
			_mirror_survival(node_id, true)
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


## Refund a node. Auto nodes cannot be refunded, and a node stays while a learned node needs it
## (spec 03). The daily limit is refund_block(). The effect leaves with it: a refunded survival node
## clears its Data capture mirror too. A refusal leaves its reason in `refused`.
func refund(tree: String, node_id: String) -> bool:
	refused = ""
	var arr: Array = trees[tree]["unlocked"]
	if not arr.has(node_id):
		return false
	for n in nodes(tree):
		if str(n.get("id", "")) == node_id:
			var why := refund_reason(tree, node_id)
			if why != "":
				return _refuse(node_id, why)
			_roll_day()
			refunds_today += 1
			arr.erase(node_id)
			var cost := int(n.get("sp", 0))
			_recount_sp()
			if tree == "survival":
				_mirror_survival(node_id, false)
			print("[skill] refunded %s (+%d SP, %d today)" % [node_id, cost, refunds_today])
			skill_changed.emit(StringName(tree), level_of(tree))
			return true
	return false

## "" when the learned node `node_id` can be refunded now, else why not. A query, so the sheet can
## grey the Refund button and say why before the tap; refund() refuses with the same text.
func refund_reason(tree: String, node_id: String) -> String:
	var names := {}
	for n in nodes(tree):
		names[str(n.get("id", ""))] = str(n.get("name", n.get("id", "")))
	for n in nodes(tree):
		if str(n.get("id", "")) == node_id:
			if bool(n.get("auto", false)):
				return "learned automatically"
			var deps: Array = SkillRules.learned_dependents(self, tree, node_id)
			if not deps.is_empty():
				return "%s needs it" % ", ".join(deps.map(func (d: String) -> String: return str(names.get(d, d))))
			return refund_block()
	return ""

func _refuse(node_id: String, why: String) -> bool:
	refused = "Cannot refund: " + why
	print("[skill] cannot refund %s: %s" % [node_id, why])
	return false

## "" while a refund is free today, else why not. docs/design/skills.md:9 "5 free unlearns a day,
## then 30 Warp Gems, max 10 a day"; spec 03:37 keeps it configurable (trees.json refund).
## ASSUMPTION: a day is a UTC calendar day.
## shortcut: Warp Gems do not exist, so past free_per_day it refuses; charge warp_gems_each here,
## up to max_per_day, once that currency exists.
## A query only (a sheet may call it to grey a button): the day roll-over happens in refund().
func refund_block() -> String:
	var used := refunds_today if refund_day == _today() else 0
	var rule: Dictionary = config.get("refund", {})
	var free := mini(int(rule.get("free_per_day", 5)), int(rule.get("max_per_day", 10)))
	if used < free:
		return ""
	return "the %d free refunds of the day are used, more tomorrow" % free

static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _roll_day() -> void:
	if refund_day != _today():
		refund_day = _today()
		refunds_today = 0

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
			# ASSUMPTION: the head start grants levels (and their auto nodes), not SP; spec 03 pays
			# SP only for character levels, so a new survivor starts with 0 SP like everyone else.
			_learn_autos(tree)
			print("[skill] %s 20 (occupation %s)" % [tree, id])
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
	var out := {"rev": REV, "occupation": occupation, "sp_available": sp_available, "sp_spent": sp_spent, "sp_earned": sp_earned, "sp_extra": sp_extra, "refund_day": refund_day, "refunds_today": refunds_today, "trees": {}}
	for id in ORDER:
		var t: Dictionary = trees[id]
		out["trees"][id] = {"level": int(t["level"]), "xp": float(t["xp"]), "unlocked": (t["unlocked"] as Array).duplicate()}
	return out

func from_dict(d: Dictionary) -> void:
	sp_extra = 0
	refund_day = int(d.get("refund_day", -1)) # optional; save_sanitizer makes both numbers (H6)
	refunds_today = maxi(0, int(d.get("refunds_today", 0)))
	if d.is_empty():
		_recount_sp() # no skills block (pre-skills saves): SP still follow the loaded character level
		return
	occupation = str(d.get("occupation", ""))
	var rev := int(d.get("rev", 1))
	if rev >= REV:
		sp_extra = maxi(0, int(d.get("sp_extra", 0))) # bounded by save_sanitizer (H6)
	var td: Dictionary = d.get("trees", {})
	for id in ORDER:
		var row: Dictionary = td.get(id, {}) if td.get(id) is Dictionary else {}
		# rev 1 stored a new tree as 0; it now reads Lv. 1.
		var stored := int(row.get("level", MIN_LEVEL if rev >= REV else 0))
		trees[id] = {"level": clampi(stored, MIN_LEVEL, MAX_LEVEL), "xp": float(row.get("xp", 0.0)), "unlocked": (row.get("unlocked", []) as Array).duplicate()}
	# SP are derived, never read from the save: what the character level paid (World.pioneer_level is
	# restored before the skills) plus sp_extra, minus what the learned nodes cost today.
	for id in ORDER:
		_learn_autos(id)
	_recount_sp()
	if rev < REV:
		# A rev-1 save earned its SP per tree level. It keeps every node and every unspent SP: what the
		# character level does not cover becomes a one-time extra (spec 03 allows one-time SP).
		sp_extra = maxi(0, int(d.get("sp_available", 0)) + sp_spent - sp_earned)
		_recount_sp()
	for id in ORDER:
		if id == "survival":
			for nid in trees[id]["unlocked"]:
				_mirror_survival(str(nid), true)
	print("[skill] restored %d trees (rev %d, SP %d/%d)" % [ORDER.size(), rev, sp_available, sp_earned])

## SP to spend now. Recounts first: the HUD's level-up banner listens to the same
## World.pioneer_changed as this node and may run first, so sp_available can still hold the old level's SP.
func sp_now() -> int:
	_recount_sp()
	return sp_available

func _recount_sp() -> void:
	sp_earned = SkillRules.paid_for_level(self, character_level()) + sp_extra
	sp_spent = 0
	for id in ORDER:
		for n in nodes(id):
			if is_unlocked(id, str(n.get("id", ""))):
				sp_spent += int(n.get("sp", 0))
	sp_available = maxi(0, sp_earned - sp_spent)
