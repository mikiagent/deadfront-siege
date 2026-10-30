extends SceneTree
## SKILLBUY: every skill node whose effect the game really runs must be buyable, so a survivor's
## skill points buy something. A fresh survivor at character Lv. 3 (and the occupation tree at Lv. 20)
## buys at least one node in each tree it has nodes to buy in; buying spends SP, the sheet shows the
## node learned (green, no Unlock button) and the node's effect is measurable.
## A node whose effect the game does not run stays marked "not in the game yet".
## Usage: godot --headless --path game --script res://tests/t_skillbuy.gd

const OCCUPATIONS_PATH := "res://data/skills/occupations.json"

var failures: Array[String] = []
var _done := false
var _sections := 0
var SkillStateS: GDScript
var Rules: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	SkillStateS = load("res://scripts/skills/skill_state.gd")
	Rules = load("res://scripts/skills/skill_rules.gd")
	_test_counts_at_character_level()
	_test_occupations_buy()
	_test_sheet_and_effect()
	var want := 3
	if _sections != want:
		failures.append("only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if failures.is_empty():
		print("[t_skillbuy] PASS %s" % _summary())
		quit(0)
	else:
		for f in failures:
			print("[t_skillbuy] FAIL %s" % f)
		quit(1)
	return true

var _report := {"buyable": 0, "unavailable": 0, "trees": {}}

func _summary() -> String:
	return "buyable=%d unavailable=%d per-tree %s" % [_report.buyable, _report.unavailable, JSON.stringify(_report.trees)]

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _world() -> Node:
	return get_root().get_node("World")

## A fresh SkillState with the character level set to Lv. `char_level` (World.pioneer_level is stored from 0).
func _fresh(char_level: int) -> Node:
	_world().pioneer_level = char_level - 1
	_world().pioneer_xp = 0
	var sk: Node = SkillStateS.new()
	get_root().add_child(sk)
	return sk

func _done_with(sk: Node) -> void:
	get_root().remove_child(sk)
	sk.free()
	_world().pioneer_level = 0
	_world().pioneer_xp = 0

func _occupations() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OCCUPATIONS_PATH))
	return (parsed as Dictionary).get("occupations", []) if parsed is Dictionary else []

## Non-auto nodes at or under the tree's current level: what that tree has to sell now.
func _level_nodes(sk: Node, tree: String) -> Array:
	var out: Array = []
	for n in sk.nodes(tree):
		if not bool(n.get("auto", false)) and int(n.get("level", 1)) <= sk.level_of(tree):
			out.append(n)
	return out

## Trees a survivor "has levels in": a tree with a non-auto node for sale at or under its current level.
## A node the game does not run yet (NOT_IN_GAME) does not count: KNIFESPLIT ungated the Stone Dagger
## recipe, so weapon_tools' only Lv. 1 node (Makeshift Shovel / Hoe) gates nothing until Lv. 5.
func _level_trees(sk: Node) -> Array[String]:
	var out: Array[String] = []
	for tree in SkillStateS.ORDER:
		if _level_nodes(sk, tree).any(func (n: Dictionary) -> bool: return sk.node_state(tree, n)[1] != SkillStateS.NOT_IN_GAME):
			out.append(tree)
	return out

func _counts(sk: Node) -> Dictionary:
	var buyable := 0
	var unavailable := 0
	for tree in SkillStateS.ORDER:
		var b := 0
		var u := 0
		for n in sk.nodes(tree):
			if bool(n.get("auto", false)):
				continue
			if sk.node_state(tree, n)[1] == SkillStateS.NOT_IN_GAME:
				u += 1
			else:
				b += 1
		_report.trees[tree] = "buyable=%d unavailable=%d" % [b, u]
		buyable += b
		unavailable += u
	_report.buyable = buyable
	_report.unavailable = unavailable
	return {"buyable": buyable, "unavailable": unavailable}

## The headline numbers: per tree at character Lv. 3 and Lv. 20, and the total the target is set on.
func _test_counts_at_character_level() -> void:
	for lv in [3, 20]:
		var sk := _fresh(lv)
		var c := _counts(sk)
		print("[t_skillbuy] character Lv. %d: buyable=%d unavailable=%d" % [lv, c.buyable, c.unavailable])
		for tree in SkillStateS.ORDER:
			print("[t_skillbuy]   %-13s %s" % [tree, _report.trees[tree]])
		_done_with(sk)
	# Character Lv. 3 with no occupation is the playtest case (SP 20, Lv. 3).
	var sk3 := _fresh(3)
	_counts(sk3)
	print("[t_skillbuy] totals: %s" % _summary())
	_expect(_report.unavailable <= 106, "at most 106 of the 213 nodes stay 'not in the game yet' (got %d, buyable %d)" % [_report.unavailable, _report.buyable])
	_done_with(sk3)
	_sections += 1

## A fresh survivor at character Lv. 3 with each occupation buys at least one node in every tree it
## has levels in, spends SP for it, and reaching Lv. 20 in the occupation tree opens its nodes too.
func _test_occupations_buy() -> void:
	for row in _occupations():
		var occ := str(row.get("id", ""))
		var sk := _fresh(3)
		sk.apply_occupation(occ)
		_expect(sk.level_of(str(row.get("tree", ""))) >= 20, "%s starts with %s at Lv. 20 (got %d)" % [occ, row.get("tree", ""), sk.level_of(str(row.get("tree", "")))])
		var sp_before: int = sk.sp_available
		_expect(sp_before > 0, "%s at character Lv. 3 has SP to spend (got %d)" % [occ, sp_before])
		var lines: Array[String] = []
		for tree in _level_trees(sk):
			var bought := ""
			# The cheapest node the tree can offer now: SP are shared, so one purchase per tree in turn.
			var best: Dictionary = {}
			for n in _level_nodes(sk, tree):
				if sk.node_state(tree, n)[0] == "available" and (best.is_empty() or int(n.get("sp", 0)) < int(best.get("sp", 0))):
					best = n
			if not best.is_empty():
				var sp: int = sk.sp_available
				var cost := int(best.get("sp", 0))
				if sk.unlock(tree, str(best.get("id", ""))):
					bought = "%s (SP %d -> %d)" % [best.get("id", ""), sp, sk.sp_available]
					_expect(sk.sp_available == sp - cost, "%s/%s costs its %d SP (SP went %d -> %d)" % [tree, best.get("id", ""), cost, sp, sk.sp_available])
					_expect(sk.node_state(tree, best)[0] == "owned", "%s/%s reads learned after the purchase" % [tree, best.get("id", "")])
			var state := "NONE"
			if bought == "":
				for n in _level_nodes(sk, tree):
					if sk.node_state(tree, n)[0] == "locked" and sk.node_state(tree, n)[1] != SkillStateS.NOT_IN_GAME:
						state = "locked: %s %s" % [n.get("id", ""), sk.node_state(tree, n)[1]]
						break
			lines.append("%s: %s" % [tree, bought if bought != "" else state])
			_expect(bought != "", "%s (character Lv. 3): buys a node in %s, a tree it has levels in (%s, SP %d)" % [occ, tree, bought if bought != "" else state, sk.sp_available])
		print("[t_skillbuy] %s: %s" % [occ, ", ".join(lines)])
		_done_with(sk)
	_sections += 1

func _button_texts(node: Node) -> Array:
	var out: Array = []
	for b in node.find_children("*", "Button", true, false):
		out.append(str((b as Button).text))
	return out

## The sheet agrees with the money, and a stat effect is measurable: Defense's Max Health raises
## the survivor's health cap through SkillRules.ability.
func _test_sheet_and_effect() -> void:
	var sk := _fresh(20)
	sk.trees["defense"]["level"] = 20
	sk._learn_autos("defense")
	sk._recount_sp()
	var sheet: Control = (load("res://scripts/ui/skills_sheet.gd") as GDScript).new()
	get_root().add_child(sheet)
	sheet.open(sk, "defense")
	var row: Node = sheet.get("_box").get_node_or_null("SkillsNode_max_health_1")
	_expect(row != null, "the sheet lists Max Health 1 as a node row, not a 'not in the game yet' line")
	var buttons := 0
	if row:
		buttons = _button_texts(row).count("Unlock")
	_expect(buttons == 1, "Max Health 1 shows an Unlock button before the purchase (got %d)" % buttons)
	var before: int = Rules.ability(sk, "max_health")
	_expect(sk.unlock("defense", "max_health_1"), "Max Health 1 is bought at Defense Lv. 20")
	var after: int = Rules.ability(sk, "max_health")
	print("[t_skillbuy] effect: max_health ability %d -> %d, vitals cap %.0f -> %.0f" % [before, after, 100.0 + before, 100.0 + after])
	_expect(after == 10, "Max Health 1 gives +10 max health (ability %d -> %d)" % [before, after])
	sheet.open(sk, "defense")
	row = sheet.get("_box").get_node_or_null("SkillsNode_max_health_1")
	var unlock_after := 0
	if row:
		unlock_after = _button_texts(row).count("Unlock")
	_expect(row != null and unlock_after == 0, "after the purchase the sheet row has no Unlock button (row %s, buttons %d)" % [row != null, unlock_after])
	get_root().remove_child(sheet)
	sheet.free()
	_done_with(sk)
	_sections += 1
