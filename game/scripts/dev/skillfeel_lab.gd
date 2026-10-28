extends Node3D
## SKILLFEEL (spec 25 §7, islands-and-loop-plan §3.3 "Skills"), windowed: boots the home island with the
## real HUD and shows the three pieces of skill feedback, saving a PNG of each: a skill XP toast, the
## skills sheet with a capped tree reading FULL and its banked XP, and the SKILLS hex pulsing while a
## node is affordable (then a fourth shot after the SP are spent and the pulse is out).
## Everything the RESULT line prints is measured from the live scene, never a constant.
## Windowed: --resolution 1600x900 -- --lab=skillfeel_lab --shot-dir=DIR [--tod=0.92] (also 844x390;
## add --rendering-method gl_compatibility for the web renderer).
## Prints exactly one "[skillfeel] RESULT k=v ..." line, then quits.

const FIRST_HOUR_LEVEL := 13
const FIRST_HOUR_TREES: Array[String] = ["gathering", "butchering", "cooking", "weapon_tools", "construction", "survival", "melee"]

var _out := ""
var _player: Player
var _hud: HuntHud
var _fails: PackedStringArray = []
var _r := {}
var _boxes := {}  # the rects the shots drew, captured while they were on screen

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("skillfeel")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--tod="):
			Game.time_of_day = float(a.substr(6))
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await _wait(2.5)
	# A character level that pays SP (Lv. 2 = 10 SP) and a tree with room to gain.
	World.pioneer_level = 1
	_player.skills._recount_sp()
	await _shot_xp()
	await _shot_full()
	await _shot_pulse()
	await _shot_spent()
	_first_hour()
	_r["ui_min_px"] = _min_tap_px()
	# The halo must be around the SKILLS hex itself, inside the view, and the toasts off every block.
	_check_boxes()
	if _fails.is_empty():
		var keys: Array[String] = []
		for k in _r:
			keys.append("%s=%s" % [k, _r[k]])
		print("[skillfeel] RESULT %s" % " ".join(keys))
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[skillfeel] FAIL %s" % f)
		print("[skillfeel] RESULT %s" % " ".join(_r.keys().map(func (k: String) -> String: return "%s=%s" % [k, _r[k]])))
		get_tree().quit(1)

# ---------------------------------------------------------------- the shots

## A gain of Gathering XP shows "+4 Gathering XP", then two more merge into it, and a tree level-up
## shows the bigger line above it.
func _shot_xp() -> void:
	var sk := _player.skills
	sk.add_xp("gathering", 4.0)
	await get_tree().process_frame
	sk.add_xp("gathering", 3.0)
	# The merge is checked here, while it is the newest line: later gains may push it off the stack.
	var merged := false
	for e in (_hud.get("_events") as HudEventState).skill_toasts:
		merged = merged or str(e["text"]) == "+7 Gathering XP"
	sk.add_xp("cooking", 2.0)
	# A level-up: enough XP for targeting Lv. 2 (tree and character both have room at Lv. 2).
	sk.add_xp("melee", SkillState.xp_to_next(1) + 1.0)
	await _wait(0.15)
	var rows: Array = (_hud.get("_events") as HudEventState).skill_toasts
	var texts: Array[String] = []
	for e in rows:
		texts.append(str(e["text"]))
	_boxes["toast"] = _hud.drawn_blocks.get("skilltoast0", Rect2())
	var has_merged := merged
	var has_big := false
	for e in rows:
		has_big = has_big or (bool(e["big"]) and str(e["text"]).begins_with("Melee Lv."))
	print("[skillfeel] toasts: %s" % ", ".join(texts))
	_r["toast_shown"] = 1 if has_merged and not rows.is_empty() else 0
	_r["level_toast_shown"] = 1 if has_big else 0
	await _shot("skilltoast")
	# Let them live out before the next step, or the sheet shot carries a stale toast.
	await _wait(HudEventState.SKILL_LEVEL_LIFE + 0.4)

## Melee at the character-level cap: the row reads FULL and names the XP it banks.
func _shot_full() -> void:
	var sk := _player.skills
	World.pioneer_level = 2  # character Lv. 3 caps every tree at Lv. 3
	_player.skills._on_character_level()
	sk.add_xp("melee", 200.0)  # more than the rung it waits on: the rest is banked and the row says so
	await get_tree().process_frame
	var capped: bool = sk.level_of("melee") >= sk.level_cap("melee")
	_hud.call("_toggle_skills", "")
	await get_tree().process_frame
	await get_tree().process_frame
	var sheet: Control = _hud.get("_skills_sheet")
	var full: Node = null
	var xp_text := ""
	var row: Node = null
	if sheet:
		row = sheet.find_child("Skill_melee", true, false)
		full = row.find_child("SkillFull_melee", true, false) if row else null
		var xl: Label = sheet.find_child("SkillXp", true, false)
		xp_text = xl.text if xl else ""
	var text := str((full as Label).text) if full else ""
	print("[skillfeel] FULL: melee Lv. %d of cap %d, banked %.0f, label \"%s\", xp \"%s\"" % [sk.level_of("melee"), sk.level_cap("melee"), sk.xp_of("melee"), text, xp_text])
	# "FULL · N XP banked" on a desktop, "FULL · N XP" on a compact canvas (the wider line was cut).
	var names_xp := text.contains("%d XP" % int(sk.xp_of("melee")))
	_r["full_shown"] = 1 if capped and full != null and text.begins_with("FULL") and names_xp else 0
	await _shot("skillsfull")
	_hud.call("_toggle_skills", "")
	await _wait(0.4)

## The SKILLS hex glows while a buyable node is affordable; after the SP are spent it stops.
func _shot_pulse() -> void:
	var sk := _player.skills
	World.pioneer_level = 5  # character Lv. 6: SP to spend
	_player.skills._on_character_level()
	_hud.call("_refresh_skill_pulse")
	await _wait(0.5)
	var affordable: bool = SkillRules.affordable_now(sk)
	var pulsing: bool = bool(_hud.call("skills_pulsing"))
	print("[skillfeel] pulse: SP %d, affordable %s, pulsing %s" % [int(sk.sp_now()), affordable, pulsing])
	_r["pulse_when_affordable"] = 1 if affordable and pulsing else 0
	await _shot("skillspulse")
	_boxes["pulse"] = _hud.drawn_blocks.get("skillpulse", Rect2())
	_boxes["hex"] = (_hud.get("_menu_hex") as HexButton).hex_rect()

## Spend every SP on something buyable until nothing is affordable: the halo goes out.
func _shot_spent() -> void:
	var sk := _player.skills
	var bought := 0
	while bought < 40 and SkillRules.affordable_now(sk):
		var spent := false
		for tree in SkillState.ORDER:
			for n in sk.nodes(tree):
				if sk.node_state(tree, n)[0] == "available" and sk.unlock(tree, str(n.get("id", ""))):
					spent = true
					bought += 1
				if spent:
					break
			if spent:
				break
		if not spent:
			break
	_hud.call("_refresh_skill_pulse")
	await _wait(0.5)
	var affordable: bool = SkillRules.affordable_now(sk)
	var pulsing: bool = bool(_hud.call("skills_pulsing"))
	print("[skillfeel] spent: bought %d, SP %d left, affordable %s, pulsing %s" % [bought, int(sk.sp_now()), affordable, pulsing])
	_r["no_pulse_when_not"] = 1 if not affordable and not pulsing else 0
	await _shot("skillsnopulse")

# ---------------------------------------------------------------- the numbers

## The 1-5 SP buys a new character has by the end of the first hour, per tree it touches.
func _first_hour() -> void:
	World.pioneer_level = FIRST_HOUR_LEVEL - 1
	var sk := _player.skills
	var ok := 0
	var lines: Array[String] = []
	for tree in FIRST_HOUR_TREES:
		var count := 0
		for n in sk.nodes(tree):
			if bool(n.get("auto", false)):
				continue
			var cost := int(n.get("sp", 0))
			if cost < 1 or cost > 5 or int(n.get("level", 1)) > mini(FIRST_HOUR_LEVEL, sk.level_cap(tree)):
				continue
			if SkillRules.buyable(sk, tree, str(n.get("id", ""))):
				count += 1
		if count >= 2:
			ok += 1
		lines.append("%s:%d" % [tree, count])
	print("[skillfeel] first hour at Lv. %d: %s" % [FIRST_HOUR_LEVEL, ", ".join(lines)])
	_r["first_hour_trees"] = FIRST_HOUR_TREES.size()
	_r["first_hour_trees_ok"] = ok
	_r["first_hour"] = ",".join(lines)

## The smallest tap target this feedback asks a finger for: the SKILLS hex the pulse sits on (the
## toasts are not interactive). Measured on the live HUD.
func _min_tap_px() -> int:
	var hex: Control = _hud.get("_menu_hex")
	var px := 0.0
	if hex:
		px = minf(hex.size.x, hex.size.y)
	print("[skillfeel] SKILLS hex %.0f x %.0f px on screen %s" % [hex.size.x if hex else 0.0, hex.size.y if hex else 0.0, get_viewport().get_visible_rect().size])
	return int(px)

## No toast and no halo over a HUD block, and the halo sits on the SKILLS hex. The boxes were captured
## while each shot was on screen (drawn_blocks is cleared every draw, and the last step has no halo).
func _check_boxes() -> void:
	var blocks: Dictionary = _hud.drawn_blocks
	var toast: Rect2 = _boxes.get("toast", Rect2())
	if not toast.has_area():
		_fails.append("no skill toast was drawn (the XP shot shows none)")
	for other in ["vitals", "quest", "map_title", "map_text", "plate"]:
		if blocks.has(other) and toast.intersects(blocks[other]):
			_fails.append("the skill toast %s covers %s %s" % [toast, other, blocks[other]])
	if toast.has_area() and toast.intersects(_hud.figure_rect()):
		_fails.append("the skill toast %s covers the survivor" % toast)
	var halo: Rect2 = _boxes.get("pulse", Rect2())
	var hex_rect: Rect2 = _boxes.get("hex", Rect2())
	if not halo.has_area():
		_fails.append("no skillpulse block: the halo was not drawn")
	elif not halo.encloses(hex_rect):
		_fails.append("the halo %s is not around the SKILLS hex %s" % [halo, hex_rect])
	if halo.has_area() and halo.intersects(_hud.figure_rect()):
		_fails.append("the halo %s covers the survivor" % halo)
	print("[skillfeel] drawn: toast=%s halo=%s hex=%s" % [toast, halo, hex_rect])

func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img and img.get_width() >= 8:
		var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
		img.save_png(path)
		print("[skillfeel] shot %s" % path)

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
