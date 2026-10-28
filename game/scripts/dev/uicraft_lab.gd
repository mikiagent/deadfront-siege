extends Node3D
## UICRAFT shots (docs/design/ui-redesign-spec.md §7 D1 / D2 / D3) from the running build: the craft
## stations sheet, the place-materials view and build mode (drawer + placement row), saved as
## d1_craft_<w>x<h>.png, d3_place_<w>x<h>.png, d2_build_<w>x<h>.png in --shot-dir. Windowed:
##   Godot --path game --resolution 1600x900 -- --lab=uicraft_lab --shot-dir=DIR [--canvas=844x390]
## Prints "[uicraft] shot <path>" per screen and "[uicraft] DONE".

var _player: Player
var _hud: HuntHud
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
		_out = OS.get_user_data_dir().path_join("uicraft")
	DirAccess.make_dir_recursive_absolute(_out)
	if _canvas != Vector2i.ZERO:
		DisplayMode.canvas_override = _canvas
		DisplayMode.fit(get_tree().root)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	(kit["debug"] as Label).visible = false
	var bench := CraftStation.make(&"workbench")
	if bench:
		bench.position = Vector3(10, 0, 0)
		add_child(bench)
	_run.call_deferred()

func _give(id: StringName, lvl: int, attrs: Dictionary = {}) -> void:
	_player.inventory.add(ItemStack.make(id, 1, attrs, lvl))

func _run() -> void:
	get_tree().create_timer(90.0).timeout.connect(func () -> void: get_tree().quit(1))
	await get_tree().create_timer(0.6).timeout
	_player.skills.trees["weapon_tools"] = {"level": 12, "xp": 0.0, "unlocked": []}
	_give(&"stone", 6, {"sharp_section": 2})
	_give(&"stone", 3)
	_give(&"branch", 8, {"firm": 2})
	_give(&"branch", 4, {"soft": 1})
	_give(&"twine", 15, {"tough_fiber": 2, "black_sheen": 1})
	_give(&"twine", 10)
	_give(&"twine", 12, {"soft_fiber": 1})
	_give(&"twine", 6)
	var view := Vector2i(get_viewport().get_visible_rect().size)
	var tag := "%dx%d" % [view.x, view.y]
	# D1: by hand, Weapons & Tools, the knife selected.
	var craft := _player.craft_ui as CraftUI
	craft._station = ""
	craft._category = "weapon_tools"
	craft._selected_id = "improvised_stone_knife"
	craft.show_ui()
	await _settle()
	await _shot("d1_craft_" + tag)
	# D3: the capture net's slots, the first placed.
	craft.open_place("capture_net_i")
	await _settle()
	craft._place.place_focused()
	await _settle()
	await _shot("d3_place_" + tag)
	craft.hide_ui()
	# D2: the drawer, then a wall ghost with ROTATE / SAVE / CANCEL.
	var build := BuildUI.ensure(_player)
	build.open()
	await _settle()
	await _shot("d2_build_" + tag)
	build.pick_piece(&"wall")
	await _settle()
	await _shot("d2_place_" + tag)
	_player.placer.cancel()
	print("[uicraft] DONE")
	get_tree().quit(0)

func _settle() -> void:
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("[uicraft] %s: no pixels (run windowed)" % name)
		return
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("[uicraft] shot %s" % path)
