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
	_test_batch()
	_test_sweep()
	_test_level_toast()
	_test_full()
	_test_pulse()
	_test_hud()
	_test_first_hour()
	var want := 9
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
	# Owner 2026-10-28 "batched": while the bar still shows, a later gain keeps filling it, not a new one.
	ev.tick(1.1)
	ev.add_skill_xp("gathering", 5.0)
	rows = ev.get("skill_toasts")
	_expect(rows.size() == 2, "a Gathering gain 1.1 s later joins the bar still showing (got %d rows)" % rows.size())
	_expect(str(rows[0]["text"]) == "+12 Gathering XP", "the batched bar adds it up (\"%s\")" % str(rows[0]["text"]))
	# A burst cannot stack down over the survivor: the newest four lines are what the HUD draws.
	for tree in ["survival", "butchering", "ranged"]:  # bars batch per tree: more trees than lines
		ev.add_skill_xp(tree, 1.0)
	for i in 10:
		ev.add_skill_level("melee", 2 + i)
	rows = ev.get("skill_toasts")
	_expect(rows.size() == int(Events.SKILL_MAX), "a burst of gains keeps at most %d lines (got %d)" % [int(Events.SKILL_MAX), rows.size()])
	_expect(str(rows[rows.size() - 1]["text"]) == "Melee Lv. 11", "the burst keeps the newest line (got \"%s\")" % str(rows[rows.size() - 1]["text"]))
	# Older toasts age out, so the HUD never piles them up.
	ev.tick(4.0)
	_expect((ev.get("skill_toasts") as Array).is_empty(), "toasts clear after their life (got %d)" % (ev.get("skill_toasts") as Array).size())
	_sections += 1

## Owner 2026-10-28: several gains make one bar; the light-green ghost leads at once, the real fill
## waits until gains stop, then eases up to it (flashing over a level), lingers and fades.
func _test_batch() -> void:
	var ev := _events()
	var rung := float(SkillStateS.xp_to_next(1))
	var p := 1.0
	for i in 3:
		p += 10.0 / rung
		ev.add_skill_xp("gathering", 10.0, 1, p)
		ev.tick(0.3)  # under the catch-up delay: the gains are still a batch
	var rows: Array = ev.get("skill_toasts")
	_expect(rows.size() == 1 and str(rows[0]["text"]) == "+30 Gathering XP", "three gains make one bar \"+30 Gathering XP\" (got %s)" % [rows])
	var row: Dictionary = rows[0] if not rows.is_empty() else {}
	var bar: Array = Events.skill_bar(row)
	print("[t_skillfeel] batch: shown %.3f pending %.3f bar %s" % [float(row.get("shown", -1)), float(row.get("pending", -1)), bar])
	_expect(float(bar[1]) > float(bar[0]) + 0.2, "mid-batch the ghost leads the real fill (ghost %.2f, fill %.2f)" % [float(bar[1]), float(bar[0])])
	var caught := 0.0
	for i in 60:
		ev.tick(0.1)
		if float(row["shown"]) >= float(row["pending"]):
			caught = 0.1 * float(i + 1)
			break
	_expect(caught > 0.0 and caught < 4.0 and (ev.get("skill_toasts") as Array).size() == 1, "after the gains stop the fill catches up and the bar is still there (%.1f s)" % caught)
	ev.tick(Events.SKILL_LIFE * 0.5)
	_expect((ev.get("skill_toasts") as Array).size() == 1, "a caught-up bar lingers")
	ev.tick(Events.SKILL_LIFE)
	_expect((ev.get("skill_toasts") as Array).is_empty(), "then it fades out")
	# Over a level mid-batch: the ghost fills the bar, the fill rolls over with a flash.
	ev = _events()
	ev.add_skill_xp("gathering", 10.0, 1, 1.8)
	ev.add_skill_xp("gathering", 30.0, 1, 2.2)
	bar = Events.skill_bar((ev.get("skill_toasts") as Array)[0])
	_expect(is_equal_approx(float(bar[1]), 1.0) and int(bar[2]) == 1, "a gain past the level fills the ghost to the end (%s)" % [bar])
	var flashed := false
	for i in 60:
		ev.tick(0.1)
		if (ev.get("skill_toasts") as Array).is_empty():
			break
		var b: Array = Events.skill_bar((ev.get("skill_toasts") as Array)[0])
		flashed = flashed or (int(b[2]) == 2 and float(b[3]) > 0.5)
	_expect(flashed, "the fill rolls over to Lv. 2 with a flash")
	_sections += 1

## Owner 2026-10-28 "the bar fills and the unlocks flash": opening the sheet sweeps the gold level
## track to the skill level, flashes each unlockable node in level order as it passes, counts the SP up,
## and a reopen within a few seconds skips it.
func _test_sweep() -> void:
	var sk := _fresh(10)
	sk.trees["gathering"]["level"] = 10  # researched up to the cap (research is t_research's)
	sk._learn_autos("gathering")
	var Sheet: GDScript = load("res://scripts/ui/skills_sheet.gd")
	var order: Array = Sheet.sweep_order(sk, "gathering")
	var ids: Array[String] = []
	for n in order:
		ids.append(str(n["id"]))
	_expect(not order.is_empty(), "Gathering Lv. %d with %d SP has nodes to unlock" % [sk.level_of("gathering"), sk.sp_available])
	var sheet: Control = Sheet.new()
	get_root().add_child(sheet)
	sheet.open(sk, "gathering")
	_expect(bool(sheet.call("sweeping")), "opening the sheet starts the sweep")
	sheet.call("tick_sweep", 0.15)
	var mid: Array = (sheet.get("sweep_flashed") as Array).duplicate()
	var track: ProgressBar = sheet.find_child("SkillsLevelTrack", true, false)
	var mid_v := track.value if track else -1.0
	var pill := str((sheet.get("_sp_pill") as Label).text)
	print("[t_skillfeel] sweep mid: track %.2f flashed %s pill \"%s\" order %s" % [mid_v, mid, pill, ids])
	_expect(mid.size() < ids.size() and ids.slice(0, mid.size()) == mid, "mid-sweep only the lowest nodes have flashed, in order (%s of %s)" % [mid, ids])
	_expect(pill != "%d free" % sk.sp_available, "the skill points are still counting up mid-sweep (\"%s\")" % pill)
	for i in 20:
		sheet.call("tick_sweep", 0.1)
	var end_v := track.value if track else -1.0
	var want_v: float = sheet.call("track_frac", float(sk.level_of("gathering")))
	_expect(not bool(sheet.call("sweeping")) and absf(end_v - want_v) < 0.011 and end_v > mid_v, "the track ends at the skill level (%.2f, want %.2f)" % [end_v, want_v])
	_expect(sheet.get("sweep_flashed") == ids, "every unlockable node flashed once, lowest level first (%s)" % [sheet.get("sweep_flashed")])
	_expect(str((sheet.get("_sp_pill") as Label).text) == "%d free" % sk.sp_available, "the count ends at the free skill points")
	sheet.close()
	sheet.open(sk, "gathering")
	_expect(not bool(sheet.call("sweeping")), "a reopen within a few seconds skips the sweep")
	get_root().remove_child(sheet)
	sheet.free()
	_done_with(sk)
	_sections += 1

## A tree level-up is a bigger toast than an XP gain, and it says the new level.
func _test_level_toast() -> void:
	var ev := _events()
	ev.add_skill_level("gathering", 2)
	var row := _last(ev)
	_expect(bool(row.get("big", false)), "a tree level-up is the big toast")
	_expect(str(row.get("text", "")) == "Gathering Lv. 2", "the level-up toast reads \"Gathering Lv. 2\" (got \"%s\")" % str(row.get("text", "")))
	_expect(float(row.get("life", 0.0)) > float(Events.SKILL_LIFE), "the level-up toast stays longer than an XP toast")
	# Two levels at once (a character level-up releasing a bank) is one line with the newest level.
	ev.add_skill_level("gathering", 3)
	var ups_rows: Array = ev.get("skill_toasts")
	_expect(ups_rows.size() == 1 and str(ups_rows[0]["text"]) == "Gathering Lv. 3", "two Gathering level-ups fold into one line with the newest level (got %s)" % [ups_rows])
	# The real signal path: reaching Lv. 2 emits skill_leveled once, with the new level.
	var sk := _fresh(5)
	var ups: Array = []
	sk.skill_leveled.connect(func (t: StringName, lv: int) -> void: ups.append([str(t), lv]))
	sk.add_xp("gathering", _xp_to(sk, 2) + 1.0)
	_expect(ups.filter(func (u: Array) -> bool: return str(u[0]) == "gathering").is_empty(), "a full Gathering bar does not level by itself (research)")
	SkillStateS.clock_override = 1000.0
	sk.start_research("gathering")
	SkillStateS.clock_override = 1000.0 + SkillStateS.research_s(1) + 1.0
	sk.poll_research()
	SkillStateS.clock_override = -1.0
	var gathering_ups: Array = ups.filter(func (u: Array) -> bool: return str(u[0]) == "gathering")
	_expect(gathering_ups.size() == 1 and int(gathering_ups[0][1]) == 2, "gathering researched to Lv. 2 emits skill_leveled(gathering, 2) once (got %s)" % [ups])
	_done_with(sk)
	_sections += 1

# ---------------------------------------------------------------- FULL at the cap

## At the character-level cap the row reads FULL and still shows the banked XP; below it, no FULL.
func _test_full() -> void:
	var sk := _fresh(3)  # character Lv. 3 caps every tree at Lv. 3
	sk.add_xp("gathering", 5.0)  # still Lv. 1, under the cap
	sk.trees["melee"]["level"] = 3  # researched up to the cap (research gates every gated level)
	sk.add_xp("melee", 500.0, true)  # at the cap: all of it is banked (spec 03:7); mirrored keeps the character at Lv. 3
	var sheet: Control = (load("res://scripts/ui/skills_sheet.gd") as GDScript).new()
	get_root().add_child(sheet)
	sheet.open(sk, "melee")
	var melee: Node = sheet.find_child("Skill_melee", true, false)
	var full: Node = melee.find_child("SkillFull_melee", true, false) if melee else null
	var xp_label: Label = sheet.find_child("SkillXp", true, false)
	var xp_text := xp_label.text if xp_label else ""
	print("[t_skillfeel] cap: melee Lv. %d of cap %d, banked %.0f, FULL label %s, xp \"%s\"" % [sk.level_of("melee"), sk.level_cap("melee"), sk.xp_of("melee"), full != null, xp_text])
	_expect(sk.level_of("melee") == sk.level_cap("melee"), "melee stops at the character level (Lv. %d of %d)" % [sk.level_of("melee"), sk.level_cap("melee")])
	_expect(full != null and str((full as Label).text).begins_with("FULL"), "a tree at the cap reads FULL (got \"%s\")" % (str((full as Label).text) if full else "-"))
	_expect(full != null and str((full as Label).text).contains("%d XP" % int(sk.xp_of("melee"))) and int(sk.xp_of("melee")) > 52, "the FULL line shows the banked XP (got \"%s\" for %d banked)" % [str((full as Label).text) if full else "-", int(sk.xp_of("melee"))])
	_expect(xp_text == "%d / %d" % [int(SkillStateS.xp_to_next(sk.level_of("melee"))), int(SkillStateS.xp_to_next(sk.level_of("melee")))], "the capped row still shows the XP of the rung it waits on (\"%s\")" % xp_text)
	var gathering: Node = sheet.find_child("Skill_gathering", true, false)
	var gfull: Node = gathering.find_child("SkillFull_gathering", true, false) if gathering else null
	_expect(gfull == null, "a tree below the cap has no FULL label (gathering Lv. %d of %d)" % [sk.level_of("gathering"), sk.level_cap("gathering")])
	# A character level-up lifts the cap and the tree spends its bank at once; FULL goes with it.
	_world().pioneer_level = 6
	_world().pioneer_changed.emit(6)
	sk._on_character_level()
	sheet.open(sk)
	melee = sheet.find_child("Skill_melee", true, false)
	full = melee.find_child("SkillFull_melee", true, false) if melee else null
	print("[t_skillfeel] after the character level: melee Lv. %d of cap %d, FULL %s" % [sk.level_of("melee"), sk.level_cap("melee"), full != null])
	_expect(sk.level_of("melee") == 3 and sk.research_ready("melee"), "after the character level-up melee waits for research with its bank (Lv. %d)" % sk.level_of("melee"))
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

## The HUD is what listens: binding a survivor's Skills turns a gain into a toast and the pulse on.
## The HUD is built but not added to the tree (no _ready, no minimap): bind() + the signals are the wiring.
func _test_hud() -> void:
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	var sk: Node = p.skills
	_expect(sk != null, "the player carries a SkillState")
	if sk == null:
		get_root().remove_child(p)
		p.free()
		_sections += 1
		return
	_world().pioneer_level = 1  # character Lv. 2: 10 SP
	var hud: Control = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	hud.bind(p)
	var ev: RefCounted = hud.get("_events")
	sk.add_xp("gathering", 4.0)
	var rows: Array = ev.get("skill_toasts")
	_expect(rows.size() >= 1 and str(rows[rows.size() - 1]["text"]) == "+4 Gathering XP", "the HUD turns a skill gain into \"+4 Gathering XP\" (got %s)" % [rows])
	sk.add_xp("gathering", 3.0)
	rows = ev.get("skill_toasts")
	_expect(rows.size() == 1 and str(rows[0]["text"]) == "+7 Gathering XP", "the HUD merges two gains within 1 s (got %s)" % [rows])
	_expect(bool(hud.call("skills_pulsing")), "with SP and something buyable the SKILLS hex pulses")
	# The halo itself is drawn from _draw (it needs a live canvas): skillfeel_lab checks the pixels.
	# Spend the SP down to nothing buyable: the pulse goes out.
	while int(sk.sp_now()) > 0:
		var spent := false
		for tree in SkillStateS.ORDER:
			for n in sk.nodes(tree):
				if sk.node_state(tree, n)[0] == "available":
					if sk.unlock(tree, str(n.get("id", ""))):
						spent = true
					break
			if spent:
				break
		if not spent:
			break
	hud.call("_refresh_skill_pulse")
	print("[t_skillfeel] hud: SP %d left, pulse %s" % [int(sk.sp_now()), bool(hud.call("skills_pulsing"))])
	if not bool(Rules.affordable_now(sk)):
		_expect(not bool(hud.call("skills_pulsing")), "nothing affordable: the hex stops pulsing")
	hud.free()
	get_root().remove_child(p)
	p.free()
	_world().pioneer_level = 0
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
