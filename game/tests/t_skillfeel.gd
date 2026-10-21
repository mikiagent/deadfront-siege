extends SceneTree
## SKILLFEEL: a skill gain says so, a capped tree says FULL, and the SKILLS hex asks for a tap when
## something is affordable. Spec 25 §7 ("a skill bar reads FULL when it has reached the character
## level; the XP gained is shown"), spec 03:7 (a category cannot pass the character level, its XP is
## banked) and islands-and-loop-plan §3.3 "Skills" (skill XP toast, FULL at the cap, a pulse on the
## Skills hex when a node is affordable).
## Also measures the first-hour node menu: for each tree the first hour touches, the nodes a new
## character can buy at 1-5 SP with a level by the end of it (SkillRules.buyable on the real data).
## Usage: godot --headless --path game --script res://tests/t_skillfeel.gd -> "[t_skillfeel] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

## The plan's first-hour target is character Lv. 11-13 (islands-and-loop-plan: "Hour-one targets:
## Lv 11-13"); a tree cannot pass the character level, so a node above Lv. 13 cannot be bought then.
## ASSUMPTION: 13 is the end of the first hour.
const FIRST_HOUR_LEVEL := 13
const FIRST_HOUR_TREES: Array[String] = ["gathering", "butchering", "cooking", "weapon_tools", "construction", "survival", "melee"]

var _fails: PackedStringArray = []
var _done := false
var _sections := 0
var SkillStateS: GDScript
var Rules: GDScript
var Events: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	SkillStateS = load("res://scripts/skills/skill_state.gd")
	Rules = load("res://scripts/skills/skill_rules.gd")
	Events = load("res://scripts/ui/hud_event_state.gd")
	_test_signal_and_text()
	_test_merge()
	_test_level_toast()
	_test_full()
	_test_pulse()
	_test_first_hour()
	var want := 6
	if _sections != want:
		_fails.append("only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if _fails.is_empty():
		print("[t_skillfeel] PASS %s" % _summary())
		quit(0)
	else:
		for f in _fails:
			print("[t_skillfeel] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _world() -> Node:
	return get_root().get_node("World")

## A fresh SkillState at character level `shown` (World.pioneer_level is stored from 0).
func _fresh(shown: int = 1) -> Node:
	_world().pioneer_level = shown - 1
	_world().pioneer_xp = 0
	var sk: Node = SkillStateS.new()
	get_root().add_child(sk)
	return sk

func _done_with(sk: Node) -> void:
	get_root().remove_child(sk)
	sk.free()
	_world().pioneer_level = 0
	_world().pioneer_xp = 0

func _events() -> RefCounted:
	return Events.new()

## XP a tree needs from Lv. 1 to `level` (for the level-up checks).
func _xp_to(sk: Node, level: int) -> float:
	var total := 0.0
	for l in range(1, level):
		total += SkillStateS.xp_to_next(l)
	return total

## The tree's last toast entry ("{tree, text, big, age}"), or {}.
func _last(ev: RefCounted) -> Dictionary:
	var rows: Array = ev.get("skill_toasts")
	return rows[rows.size() - 1] if not rows.is_empty() else {}

# ---------------------------------------------------------------- the toast

## A skill XP gain asks the HUD for a toast, with the tree's name and the amount gained.
func _test_signal_and_text() -> void:
	var sk := _fresh(1)
	var got: Array = []
	sk.skill_xp_gained.connect(func (t: StringName, a: float, _lv: int) -> void: got.append([str(t), a]))
	sk.add_xp("gathering", 4.0)
	_expect(got.size() == 1 and got[0][0] == "gathering" and is_equal_approx(float(got[0][1]), 4.0), "a skill gain emits skill_xp_gained(gathering, 4) (got %s)" % [got])
	var ev := _events()
	ev.add_skill_xp("gathering", 4.0)
	var row := _last(ev)
	_expect(str(row.get("text", "")) == "+4 Gathering XP", "the toast reads \"+4 Gathering XP\" (got \"%s\")" % str(row.get("text", "")))
	_expect(not bool(row.get("big", true)), "an ordinary gain is the small toast")
	# The Survival route proficiency every gain also feeds is mirrored, and a mirror has no voice: one
	# gain is one toast, never "+6 Butchering XP" and "+6 Survival XP" for the same action.
	got.clear()
	sk.add_xp("butchering", 6.0)
	_expect(got.size() == 1 and got[0][0] == "butchering", "a mirrored survival gain is not a toast of its own (got %s)" % [got])
	# Names come from SkillState, so a renamed tree keeps one spelling everywhere.
	_expect(str(Events.skill_text("weapon_tools", 3.0)) == "+3 Weapon / Tools XP", "toast text uses the tree's display name (got \"%s\")" % Events.skill_text("weapon_tools", 3.0))
	_done_with(sk)
	_sections += 1

## Several gains of one tree inside a second become one toast ("+7 Gathering XP"), not a stack.
func _test_merge() -> void:
	var ev := _events()
	ev.add_skill_xp("gathering", 4.0)
	ev.tick(0.4)
	ev.add_skill_xp("gathering", 3.0)
	var rows: Array = ev.get("skill_toasts")
	_expect(rows.size() == 1, "two Gathering gains within 1 s make one toast (got %d)" % rows.size())
	_expect(str(rows[0]["text"]) == "+7 Gathering XP", "the merged toast reads \"+7 Gathering XP\" (got \"%s\")" % str(rows[0]["text"]))
	# Another tree keeps its own toast.
	ev.add_skill_xp("cooking", 2.0)
	_expect((ev.get("skill_toasts") as Array).size() == 2, "a different tree gets its own toast (got %d)" % (ev.get("skill_toasts") as Array).size())
	# Past the merge window the same tree starts a new toast.
	ev.tick(1.1)
	ev.add_skill_xp("gathering", 5.0)
	rows = ev.get("skill_toasts")
	_expect(rows.size() == 3, "a Gathering gain 1.1 s later starts a new toast (got %d)" % rows.size())
	_expect(str(rows[rows.size() - 1]["text"]) == "+5 Gathering XP", "the new toast does not carry the old amount (\"%s\")" % str(rows[rows.size() - 1]["text"]))
	# Older toasts age out, so the HUD never piles them up.
	ev.tick(4.0)
	_expect((ev.get("skill_toasts") as Array).is_empty(), "toasts clear after their life (got %d)" % (ev.get("skill_toasts") as Array).size())
	_sections += 1

## A tree level-up is a bigger toast than an XP gain, and it says the new level.
func _test_level_toast() -> void:
	var ev := _events()
	ev.add_skill_level("gathering", 2)
	var row := _last(ev)
	_expect(bool(row.get("big", false)), "a tree level-up is the big toast")
	_expect(str(row.get("text", "")) == "Gathering Lv. 2", "the level-up toast reads \"Gathering Lv. 2\" (got \"%s\")" % str(row.get("text", "")))
	_expect(float(row.get("life", 0.0)) > float(Events.SKILL_LIFE), "the level-up toast stays longer than an XP toast")
	# The real signal path: reaching Lv. 2 emits skill_leveled once, with the new level.
	var sk := _fresh(5)
	var ups: Array = []
	sk.skill_leveled.connect(func (t: StringName, lv: int) -> void: ups.append([str(t), lv]))
	sk.add_xp("gathering", _xp_to(sk, 2) + 1.0)
	var gathering_ups: Array = ups.filter(func (u: Array) -> bool: return str(u[0]) == "gathering")
	_expect(gathering_ups.size() == 1 and int(gathering_ups[0][1]) == 2, "gathering reaching Lv. 2 emits skill_leveled(gathering, 2) once (got %s)" % [ups])
	_done_with(sk)
	_sections += 1

# ---------------------------------------------------------------- FULL at the cap

## At the character-level cap the row reads FULL and still shows the banked XP; below it, no FULL.
func _test_full() -> void:
	var sk := _fresh(3)  # character Lv. 3 caps every tree at Lv. 3
	sk.add_xp("gathering", 5.0)  # still Lv. 1, under the cap
	sk.add_xp("melee", 200.0)  # more than Lv. 1 -> 3 needs: the rest is banked (spec 03:7)
	var sheet: Control = (load("res://scripts/ui/skills_sheet.gd") as GDScript).new()
	get_root().add_child(sheet)
	sheet.open(sk)
	var melee: Node = sheet._box.find_child("Skill_melee", true, false)
	var full: Node = melee.find_child("SkillFull_melee", true, false) if melee else null
	var xp_text := ""
	for l in (melee.find_children("*", "Label", true, false) if melee else []):
		if (l as Label).text.ends_with(" XP"):
			xp_text = (l as Label).text
	print("[t_skillfeel] cap: melee Lv. %d of cap %d, banked %.0f, FULL label %s, xp \"%s\"" % [sk.level_of("melee"), sk.level_cap("melee"), sk.xp_of("melee"), full != null, xp_text])
	_expect(sk.level_of("melee") == sk.level_cap("melee"), "melee stops at the character level (Lv. %d of %d)" % [sk.level_of("melee"), sk.level_cap("melee")])
	_expect(full != null and str((full as Label).text).begins_with("FULL"), "a tree at the cap reads FULL (got \"%s\")" % (str((full as Label).text) if full else "-"))
	_expect(full != null and str((full as Label).text).contains("%d XP banked" % int(sk.xp_of("melee"))) and int(sk.xp_of("melee")) > 52, "the FULL line shows the banked XP (got \"%s\" for %d banked)" % [str((full as Label).text) if full else "-", int(sk.xp_of("melee"))])
	_expect(xp_text == "%d / %d XP" % [int(SkillStateS.xp_to_next(sk.level_of("melee"))), int(SkillStateS.xp_to_next(sk.level_of("melee")))], "the capped row still shows the XP of the rung it waits on (\"%s\")" % xp_text)
	var gathering: Node = sheet._box.find_child("Skill_gathering", true, false)
	var gfull: Node = gathering.find_child("SkillFull_gathering", true, false) if gathering else null
	_expect(gfull == null, "a tree below the cap has no FULL label (gathering Lv. %d of %d)" % [sk.level_of("gathering"), sk.level_cap("gathering")])
	# A character level-up lifts the cap and the tree spends its bank at once; FULL goes with it.
	_world().pioneer_level = 6
	_world().pioneer_changed.emit(6)
	sk._on_character_level()
	sheet.open(sk)
	melee = sheet._box.find_child("Skill_melee", true, false)
	full = melee.find_child("SkillFull_melee", true, false) if melee else null
	print("[t_skillfeel] after the character level: melee Lv. %d of cap %d, FULL %s" % [sk.level_of("melee"), sk.level_cap("melee"), full != null])
	_expect(sk.level_of("melee") > 3, "melee spends the banked XP after the character level-up (Lv. %d)" % sk.level_of("melee"))
	_expect(full == null, "FULL clears once the tree is under the cap again")
	get_root().remove_child(sheet)
	sheet.free()
	_done_with(sk)
	_sections += 1

# ---------------------------------------------------------------- the pulse

## "Is a buyable node affordable with the SP held" follows the SP, and the HUD reads it.
func _test_pulse() -> void:
	var sk := _fresh(1)  # Lv. 1 pays no SP (spec 03)
	_expect(not bool(Rules.affordable_now(sk)), "a Lv. 1 survivor with 0 SP has nothing to pulse for")
	var lv2 := _fresh(2)  # 10 SP
	_expect(int(lv2.sp_now()) == 10, "character Lv. 2 holds 10 SP (got %d)" % int(lv2.sp_now()))
	_expect(bool(Rules.affordable_now(lv2)), "with 10 SP a buyable node at Lv. 1 is affordable, so the hex pulses")
	# Spend until nothing buyable is left: the pulse must go out on its own.
	var bought := 0
	while bought < 40 and bool(Rules.affordable_now(lv2)):
		var done := false
		for tree in SkillStateS.ORDER:
			for n in lv2.nodes(tree):
				if int(n.get("sp", 0)) <= int(lv2.sp_now()) and lv2.node_state(tree, n)[0] == "available":
					if lv2.unlock(tree, str(n.get("id", ""))):
						bought += 1
						done = true
					break
			if done:
				break
		if not done:
			break
	print("[t_skillfeel] pulse: bought %d nodes, SP %d left, pulse %s" % [bought, int(lv2.sp_now()), bool(Rules.affordable_now(lv2))])
	_expect(not bool(Rules.affordable_now(lv2)) or int(lv2.sp_now()) > 0, "the pulse only claims what the SP can buy")
	# No SP, no pulse, whatever the tree levels.
	var rich := _fresh(60)
	rich.sp_extra = 0
	rich._recount_sp()
	_expect(bool(Rules.affordable_now(rich)), "a character Lv. 60 with SP pulses")
	_done_with(sk)
	_done_with(lv2)
	_done_with(rich)
	_sections += 1

# ---------------------------------------------------------------- the first hour

## The nodes a new character can buy in each tree the first hour touches, at 1-5 SP each, with a
## level the tree can hold by the end of the hour. Prints the table and what each one does.
func _test_first_hour() -> void:
	var sk := _fresh(FIRST_HOUR_LEVEL)
	var lines: Array[String] = []
	var ok := 0
	for tree in FIRST_HOUR_TREES:
		var rows: Array = first_hour_buys(sk, tree)
		if rows.size() >= 2:
			ok += 1
		var names: Array[String] = []
		for n in rows:
			names.append("%s (%d SP, Lv. %d)" % [str(n.get("name", n.get("id", ""))), int(n.get("sp", 0)), int(n.get("level", 1))])
		lines.append("%s: %d%s" % [tree, rows.size(), (" — " + ", ".join(names)) if not names.is_empty() else ""])
		print("[t_skillfeel]   first hour %s" % lines[lines.size() - 1])
	print("[t_skillfeel] first hour at Lv. %d: %d of %d trees have 2+ buys at 1-5 SP" % [FIRST_HOUR_LEVEL, ok, FIRST_HOUR_TREES.size()])
	# The count is real: every row it reports is buyable, cheap and reachable, and no cheap buyable
	# node is left out.
	for tree in FIRST_HOUR_TREES:
		var rows: Array = first_hour_buys(sk, tree)
		for n in rows:
			var st: Array = sk.node_state(tree, n)
			_expect(st[1] != SkillStateS.NOT_IN_GAME, "%s/%s reported in the first hour is really buyable" % [tree, n.get("id", "")])
			_expect(int(n.get("sp", 0)) >= 1 and int(n.get("sp", 0)) <= 5, "%s/%s costs 1-5 SP (%d)" % [tree, n.get("id", ""), int(n.get("sp", 0))])
			_expect(int(n.get("level", 1)) <= FIRST_HOUR_LEVEL, "%s/%s is under Lv. %d (%d)" % [tree, n.get("id", ""), FIRST_HOUR_LEVEL, int(n.get("level", 1))])
		var seen := 0
		for n in sk.nodes(tree):
			if bool(n.get("auto", false)) or int(n.get("sp", 0)) < 1 or int(n.get("sp", 0)) > 5 or int(n.get("level", 1)) > FIRST_HOUR_LEVEL:
				continue
			if Rules.buyable(sk, tree, str(n.get("id", ""))):
				seen += 1
		_expect(seen == rows.size(), "%s: the first-hour list holds every cheap buyable node (%d of %d)" % [tree, rows.size(), seen])
	_report["first_hour_trees"] = FIRST_HOUR_TREES.size()
	_report["first_hour_trees_ok"] = ok
	_report["first_hour"] = ", ".join(lines)
	_done_with(sk)
	_sections += 1

## The 1-5 SP buyable nodes of `tree` a tree at the character level can hold by the first hour's end.
func first_hour_buys(sk: Node, tree: String) -> Array:
	var out: Array = []
	for n in sk.nodes(tree):
		if bool(n.get("auto", false)):
			continue
		var cost := int(n.get("sp", 0))
		if cost < 1 or cost > 5 or int(n.get("level", 1)) > mini(FIRST_HOUR_LEVEL, sk.level_cap(tree)):
			continue
		if Rules.buyable(sk, tree, str(n.get("id", ""))):
			out.append(n)
	return out

var _report := {"first_hour_trees": 0, "first_hour_trees_ok": 0, "first_hour": ""}

func _summary() -> String:
	return "first_hour_trees=%d first_hour_trees_ok=%d [%s]" % [int(_report.first_hour_trees), int(_report.first_hour_trees_ok), str(_report.first_hour)]
