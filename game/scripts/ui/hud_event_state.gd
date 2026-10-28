class_name HudEventState
extends RefCounted
## Short-lived HUD messages and hit effects. HuntHud renders this state but no longer owns its lifecycle.

var toasts: Array = []
var notices: Array = []
var bites: Array = []
var player_floats: Array = []
## Skill XP toasts (spec 25 §7 "it gives you an xp amount"): {tree, amount, level, text, big, life, t}.
## Gains of one tree inside SKILL_MERGE seconds add up into one toast; a tree level-up is a bigger one.
var skill_toasts: Array = []

## Seconds within which two gains of one tree share a toast.
const SKILL_MERGE := 1.0
## How long an XP toast and a level-up toast stay (the big one reads longer).
const SKILL_LIFE := 1.6
const SKILL_LEVEL_LIFE := 3.0
## At most this many skill lines on screen at once, newest kept: a burst of gains (or several tree
## levels from one banked grant) must not stack down over the survivor.
const SKILL_MAX := 4

## "+4 Gathering XP", the same words the HUD draws and the test reads.
static func skill_text(tree: String, amount: float) -> String:
	return "+%d %s XP" % [int(round(amount)), str(SkillState.NAMES.get(tree, tree))]

func add_skill_xp(tree: String, amount: float, level: int = 0) -> void:
	if amount <= 0.0:
		return
	# A level-up line of the same tree is not merged into: the level is the bigger news and sits above.
	for entry in skill_toasts:
		if str(entry["tree"]) == tree and not bool(entry["big"]) and float(entry["t"]) < SKILL_MERGE:
			entry["amount"] = float(entry["amount"]) + amount
			entry["text"] = skill_text(tree, float(entry["amount"]))
			entry["level"] = level if level > 0 else int(entry["level"])
			entry["t"] = 0.0
			return
	skill_toasts.append({"tree": tree, "amount": amount, "level": level, "text": skill_text(tree, amount), "big": false, "life": SKILL_LIFE, "t": 0.0})
	_trim_skill()

## Consecutive level-ups of one tree fold into one line with the newest level ("Survival Lv. 6"): a
## character level-up releases the banked XP of every tree at once, and four lines for two trees read
## as four separate events.
func add_skill_level(tree: String, level: int) -> void:
	for entry in skill_toasts:
		if str(entry["tree"]) == tree and bool(entry["big"]):
			entry["level"] = maxi(int(entry["level"]), level)
			entry["text"] = "%s %s" % [str(SkillState.NAMES.get(tree, tree)), LevelDisplay.label(int(entry["level"]))]
			entry["t"] = 0.0
			return
	skill_toasts.append({"tree": tree, "amount": 0.0, "level": level, "text": "%s %s" % [str(SkillState.NAMES.get(tree, tree)), LevelDisplay.label(level)], "big": true, "life": SKILL_LEVEL_LIFE, "t": 0.0})
	_trim_skill()

## Keeps the newest SKILL_MAX lines: the oldest gain gives way rather than the stack growing over the HUD.
func _trim_skill() -> void:
	while skill_toasts.size() > SKILL_MAX:
		skill_toasts.pop_front()

func add_bite(amount: float, heavy: bool) -> void:
	bites.append({"t": 0.0, "heavy": heavy, "x": randf_range(-6.0, 6.0)})
	player_floats.append({"t": 0.0, "n": amount, "x": randf_range(-18.0, 18.0)})

## A text float over the survivor (REST's recovery: "+3 HP", "-1 fatigue"), `dy` px below the damage row.
func add_float(text: String, color: Color, dy: float = 0.0) -> void:
	player_floats.append({"t": 0.0, "txt": text, "col": color, "x": 0.0, "dy": dy})

func add_notice(text: String) -> void:
	for entry in notices:
		if entry["text"] == text and entry["t"] < 1.5:
			entry["t"] = 0.0
			return
	notices.append({"text": text, "t": 0.0})

func add_toast(id: StringName, count: int) -> void:
	for entry in toasts:
		if entry["id"] == id and entry["t"] < 0.6:
			entry["n"] += count
			entry["t"] = 0.0
			return
	toasts.append({"id": id, "n": count, "t": 0.0})

func tick(delta: float) -> void:
	for entry in toasts:
		entry["t"] += delta
	toasts = toasts.filter(func(entry: Dictionary) -> bool: return entry["t"] < 1.3)
	for entry in skill_toasts:
		entry["t"] = float(entry["t"]) + delta
	skill_toasts = skill_toasts.filter(func(entry: Dictionary) -> bool: return float(entry["t"]) < float(entry["life"]))
	for entry in notices:
		entry["t"] += delta
	notices = notices.filter(func(entry: Dictionary) -> bool: return entry["t"] < 3.2)
	for entry in bites:
		entry["t"] += delta
	bites = bites.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.5)
	for entry in player_floats:
		entry["t"] += delta
	player_floats = player_floats.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.95)
