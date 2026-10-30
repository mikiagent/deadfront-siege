extends SceneTree
## SLOWLEVELS skill research (owner 2026-10-28: "you have to research the skill when the progress fills
## up", "you have to manually start the skill research"). A full bar never levels a gated tree and never
## starts a timer by itself; the player starts it; it completes after research_s on the clock; a save in
## the middle keeps the remaining time; one research at a time; the character level is untouched.
## Usage: godot --headless --path game --script res://tests/t_research.gd -> "[t_research] PASS".

var _fails: PackedStringArray = []
var _done := false
var SS: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	SS = load("res://scripts/skills/skill_state.gd")
	_run()
	SS.set("clock_override", -1.0)
	if _fails.is_empty():
		print("[t_research] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_research] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _fresh(shown: int) -> Node:
	var w := get_root().get_node("World")
	w.pioneer_level = shown - 1
	w.pioneer_xp = 0
	var sk: Node = SS.new()
	get_root().add_child(sk)
	return sk

func _run() -> void:
	SS.set("clock_override", 1000000.0)
	var sk := _fresh(10)
	var w := get_root().get_node("World")
	var need: float = SS.xp_to_next(1)
	sk.add_xp("gathering", need + 5.0, true)
	_expect(sk.level_of("gathering") == 1 and sk.research_ready("gathering"), "a full Gathering bar stays Lv. 1 and reads research ready (Lv. %d)" % sk.level_of("gathering"))
	# No player action: time passes, nothing starts.
	SS.set("clock_override", 1000000.0 + 10.0 * 86400.0)
	sk.poll_research()
	_expect(not sk.researching() and sk.level_of("gathering") == 1, "a full bar with no player action never starts a timer, even 10 days later")
	_expect(sk.level_of("survival") > 1, "Survival is exempt and still levels by itself (Lv. %d)" % sk.level_of("survival"))
	# The player starts it.
	var t0 := 2000000.0
	SS.set("clock_override", t0)
	_expect(sk.start_research("gathering") == "", "Start Research begins the countdown")
	var dur: float = SS.research_s(1)
	_expect(is_equal_approx(sk.research_left(), dur), "the countdown is research_s(1) = %.0f s (left %.0f)" % [dur, sk.research_left()])
	# One at a time.
	sk.add_xp("melee", SS.xp_to_next(1), true)
	_expect(sk.start_research("melee") != "" and sk.researching("gathering") and not sk.researching("melee"), "a second research is refused while one runs")
	# Save mid-research, load into a fresh state: the same end, the same time left.
	SS.set("clock_override", t0 + dur * 0.5)
	var saved: Dictionary = sk.to_dict()
	var sv: Dictionary = JSON.parse_string(JSON.stringify(saved))  # through JSON like a real save
	var lv_before: int = w.pioneer_level
	var sk2 := _fresh(10)
	sk2.from_dict(sv)
	_expect(sk2.researching("gathering") and absf(sk2.research_left() - dur * 0.5) < 1.0, "a save mid-research keeps its remaining time (%.0f of %.0f)" % [sk2.research_left(), dur * 0.5])
	# Not done before the end, done after it.
	SS.set("clock_override", t0 + dur - 1.0)
	sk2.poll_research()
	_expect(sk2.level_of("gathering") == 1, "one second early the level has not come")
	var ups: Array = []
	sk2.skill_leveled.connect(func (t: StringName, l: int) -> void: ups.append([str(t), l]))
	SS.set("clock_override", t0 + dur + 0.5)
	sk2.poll_research()
	_expect(sk2.level_of("gathering") == 2 and not sk2.researching() and ups == [["gathering", 2]], "after the countdown Gathering is Lv. 2 with one level-up signal (%s)" % [ups])
	_expect(is_equal_approx(sk2.xp_of("gathering"), 5.0), "the level spends its rung, the rest stays (%.1f)" % sk2.xp_of("gathering"))
	_expect(w.pioneer_level == lv_before, "research never moves the character level")
	# Offline: a save whose end passed while closed lands the level on load.
	sk.from_dict(sv)
	SS.set("clock_override", t0 + dur * 3.0)
	var sk3 := _fresh(10)
	sk3.from_dict(sv)
	_expect(sk3.level_of("gathering") == 2 and not sk3.researching(), "a research that ended while the game was closed completes on load")
	# The curve: the owner's anchor, and growth.
	_expect(absf(SS.research_s(49) - 172800.0) < 1.0, "49 -> 50 takes 48 h (%.0f s)" % SS.research_s(49))
	_expect(SS.research_s(1) < SS.research_s(20) and SS.research_s(20) < SS.research_s(49), "research grows with level")
	# An old save without the key loads with no research.
	var old := sv.duplicate(true)
	old.erase("research")
	var sk4 := _fresh(10)
	sk4.from_dict(old)
	_expect(not sk4.researching(), "a save without research loads with none")
	for n in [sk, sk2, sk3, sk4]:
		get_root().remove_child(n)
		n.free()
	w.pioneer_level = 0
