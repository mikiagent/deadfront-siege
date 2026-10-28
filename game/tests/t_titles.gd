extends SceneTree
## TITLES (owner: "Titles should display italicized over the player's name"): Wear on the Character
## sheet's Titles tab puts the title on its own line above the survivor's name (the nameplate rect grows
## upward, the name's line stays put); Remove takes the line away; the title face is the Roboto Condensed
## UI font slanted; World.player_title survives save + load; a save without the field loads with none.
## Usage: godot --headless --path game --script res://tests/t_titles.gd -> "[t_titles] PASS", exit 0/1.

const FIX := "res://tests/fixtures/save_v3_inst_golden.json"

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var W: Node
var SG: GDScript
var HL: GDScript
var LD: GDScript
var UT: GDScript
var HH: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_titles] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _plate() -> Rect2:
	return HL.nameplate_rect(_hud.get_viewport().get_camera_3d(), _player, _hud._font)

func _toggle(sheet: Control, title: String) -> Button:
	for row: Node in sheet._titles_view.get_children():
		var l := row.get_child(0) as Label
		if l.text == title:
			return row.find_child("TitleToggle", false, false) as Button
	return null

func _run() -> void:
	W = root.get_node("World")
	SG = load("res://scripts/core/save_game.gd")
	HL = load("res://scripts/ui/hud_layout.gd")
	LD = load("res://scripts/ui/level_display.gd")
	UT = load("res://scripts/ui/ui_tokens.gd")
	HH = load("res://scripts/ui/hunt_hud.gd")
	_host = Node3D.new()
	_host.name = "TTitlesHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_character"):
			_hud = c
	W.home_terrain = &"meadow"
	W.load_island(_host, &"home_grassland", Vector3(0, 1, 12), false)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	W.player_name = "Milan"
	W.pioneer_level = 6
	W.player_title = ""
	await _frames(3)
	var earned: PackedStringArray = LD.earned_titles(LD.player_level())
	_expect(earned.size() >= 2, "level %d has earned titles (%s)" % [LD.player_level(), ", ".join(earned)])
	var bare: Rect2 = _plate()
	_expect(_player.display_title() == "", "a new save wears no title")
	# Choose from the Titles tab.
	_hud.open_character()
	await _frames(2)
	var sheet: Control = _player.ui._character
	(sheet._tab_btns["Titles"] as Button).pressed.emit()
	await _frames(2)
	var pick := earned[1]
	var wear := _toggle(sheet, pick)
	_expect(wear != null and wear.text == "Wear", "the earned title %s has a Wear button" % pick)
	if wear:
		wear.pressed.emit()
	await _frames(2)
	_expect(W.player_title == pick and _player.display_title() == pick, "Wear sets the worn title (%s)" % W.player_title)
	var lv: int = LD.player_level()
	var unearned := ""
	for row: Node in sheet._titles_view.get_children():
		if row.find_child("TitleToggle", false, false) == null:
			unearned = (row.get_child(0) as Label).text
	_expect(unearned != "" and not LD.earned_titles(lv).has(unearned), "an unearned title (%s) has no Wear button" % unearned)
	var plate: Rect2 = _plate()
	_expect(is_equal_approx(plate.end.y, bare.end.y) and plate.position.y < bare.position.y - 10.0,
		"the title line sits above the name: plate grows upward (%s -> %s)" % [bare, plate])
	var tf: Font = UT.ui_italic()
	_expect(tf is FontVariation and (tf as FontVariation).base_font.resource_path == UT.UI_FONT_PATH,
		"the title draws in Roboto Condensed (%s)" % (tf as FontVariation).base_font.resource_path if tf is FontVariation else "not a FontVariation")
	_expect(tf is FontVariation and absf((tf as FontVariation).variation_transform.x.y - 0.2) < 0.01, "the title face is slanted 0.2 (italic)")
	_expect(HL.TITLE_PX < HH.NAME_PX and HL.TITLE_INK.v < 0.95, "the title is smaller and dimmer than the name")
	var remove := _toggle(sheet, pick)
	_expect(remove != null and remove.text == "Remove", "the worn title's button reads Remove")
	# Save + load keep it.
	_expect(SG.save_now(), "save writes")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	_expect(saved is Dictionary and str((saved as Dictionary).get("player_title", "")) == pick, "the save holds player_title")
	W.player_title = ""
	SG.load_now(_host)
	await _frames(2)
	_expect(SG.blocked_reason == "" and W.player_title == pick, "load restores the worn title (%s)" % W.player_title)
	# Clearing removes the line.
	W.pioneer_level = 6
	sheet.refresh()
	remove = _toggle(sheet, pick)
	if remove:
		remove.pressed.emit()
	await _frames(2)
	_expect(W.player_title == "" and _player.display_title() == "", "Remove clears the title")
	_expect(_plate().is_equal_approx(bare), "no title, no extra line (%s vs %s)" % [_plate(), bare])
	# An old save without the field.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX))
	_expect(not old.has("player_title"), "the fixture predates player_title")
	W.player_title = pick
	var f := FileAccess.open(SG.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	SG.load_now(_host)
	await _frames(2)
	_expect(SG.blocked_reason == "" and W.player_title == "", "an old save loads with no title (blocked='%s', title='%s')" % [SG.blocked_reason, W.player_title])
	if _fails.is_empty():
		print("[t_titles] PASS")
		quit(0)
	else:
		print("[t_titles] FAIL count=%d" % _fails.size())
		quit(1)
