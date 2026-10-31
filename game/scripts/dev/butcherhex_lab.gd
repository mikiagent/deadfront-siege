extends Node3D
## BUTCHERHEX shots: the part fan on a Lv. 54 tarbosaurus carcass (the owner's Durango reference), the
## white part icons on each hex, seconds on top, count below, "Name Lv. 54" beside it, and the red
## tool_needed badge on the parts a knife or a Butchering node does not reach yet. Then the same fan
## without a knife, and one cut running. Windowed, off screen:
##   Godot --path game --resolution 1600x900 --position 6000,3000 -- --skip-charcreate --lab=butcherhex_lab --shot-dir=DIR [--canvas=844x390]
## With --sheet it shoots only the contact sheet: every part icon and the badge on a fan hex, its id under it.
## Prints "[butcherhex] shot <path>" per screen and "[butcherhex] DONE"; quits on its own.

var _player: Player
var _out := ""
var _canvas := Vector2i.ZERO

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			_canvas = Vector2i(int(wh[0]), int(wh[1]))
	if _out == "":
		_out = OS.get_user_data_dir().path_join("butcherhex")
	DirAccess.make_dir_recursive_absolute(_out)
	if _canvas != Vector2i.ZERO:
		DisplayMode.canvas_override = _canvas
		DisplayMode.fit(get_tree().root)
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	(kit["debug"] as Label).visible = false
	_run.call_deferred()

func _run() -> void:
	get_tree().create_timer(90.0).timeout.connect(func () -> void: get_tree().quit(1))
	await get_tree().create_timer(0.8).timeout
	var view := Vector2i(get_viewport().get_visible_rect().size)
	var tag := "%dx%d" % [view.x, view.y]
	if "--sheet" in OS.get_cmdline_user_args():
		await _sheet()
		get_tree().quit(0)
		return
	var corpse := await _carcass()
	if corpse == null:
		push_error("[butcherhex] no carcass")
		get_tree().quit(1)
		return
	# 1. No knife: every part wears the tool badge.
	corpse.open_loot(_player)
	await _settle()
	await _shot("carcass_noknife_" + tag)
	_player._gather_radial.close()
	# 2. A stone knife, Butchering 0: meat, leg bone and hide open; dense bone and the skull plate wait on nodes.
	_player.inventory.add(ItemStack.make(&"stone_knife", 1, {}, 5))
	corpse.open_loot(_player)
	await _settle()
	await _shot("carcass_" + tag)
	# 3. The meat cut running: its hex pie-fills, the others lock.
	var fan: GatherRadial = corpse.picker()
	if fan != null:
		fan._on_pick(0)
		await get_tree().create_timer(0.5).timeout
		await _settle()
		await _shot("carcass_cutting_" + tag)
	print("[butcherhex] DONE")
	get_tree().quit(0)

## A Lv. 54 tarbosaurus killed beside the survivor; returns its carcass.
func _carcass() -> Corpse:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = _player.global_position + Vector3(1.8, 0, 1.2)
	c.spawn(Data.creature(&"tarbosaurus"), &"")
	c.level = 54  # the owner's reference carcass
	await get_tree().create_timer(0.3).timeout
	c.health.take_damage(999999.0, _player)
	await get_tree().create_timer(0.6).timeout
	for n in get_tree().get_nodes_in_group("corpse"):
		if n is Corpse:
			(n as Corpse).level = 54
			_player.global_position = (n as Corpse).global_position + Vector3(0.0, 0.0, 1.6)
			return n
	return null

## The contact sheet: each icon on a desktop fan hex (white on HUD_FILL), seconds and count as the fan
## draws them, the id under the hex, and a locked hex wearing the tool_needed badge.
func _sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.13)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var parts: Dictionary = {}
	var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(UiIcons.MANIFEST))
	for id: String in (m as Dictionary)["icons"]:
		if id.begins_with("part_"):
			parts[id] = true
	var ids: Array = parts.keys()
	ids.append("tool_needed")
	var cols := 6
	for i in ids.size():
		var b := HexButton.new(124.0)
		b.icon = UiIcons.icon(StringName(ids[i]))
		b.fill = UiTokens.HUD_FILL
		b.rim_color = UiTokens.HUD_RIM
		b.rim_width = 4.0
		b.top_text = "1.6s"
		b.bottom_text = "3"
		b.caption = str(ids[i]).trim_prefix("part_")
		if ids[i] == "part_skull":
			GatherRadial._set_badge(b, true, false, "needs Butchering 2")
		b.position = Vector2(60 + (i % cols) * 250, 40 + (i / cols) * 210)
		layer.add_child(b)
	await _settle()
	await _shot("icons_sheet")

func _settle() -> void:
	for i in 8:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("[butcherhex] %s: no pixels (run windowed)" % name)
		return
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("[butcherhex] shot %s" % path)
