extends Node3D
## CRAFTRADIAL shots (docs/design/ui-redesign-spec.md §7 D4 / D5): the right-side craft panel (list and
## detail), the station radial on a workbench with its output row, the radial on the stone grill (the
## "oven"), the Construction panel half filled, and a kit's placement mode. Windowed, off screen:
##   Godot --path game --resolution 1600x900 --position 6000,3000 -- --lab=craftradial_lab --shot-dir=DIR [--canvas=844x390]
## Prints "[craftradial] shot <path>" per screen and "[craftradial] DONE".

var _player: Player
var _out := ""
var _canvas := Vector2i.ZERO
var _bench: CraftStation
var _grill: CraftStation

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			_canvas = Vector2i(int(wh[0]), int(wh[1]))
	if _out == "":
		_out = OS.get_user_data_dir().path_join("craftradial")
	DirAccess.make_dir_recursive_absolute(_out)
	if _canvas != Vector2i.ZERO:
		DisplayMode.canvas_override = _canvas
		DisplayMode.fit(get_tree().root)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	(kit["debug"] as Label).visible = false
	_bench = CraftStation.make(&"workbench")
	_bench.position = Vector3(2.5, 0, 0)
	add_child(_bench)
	_grill = CraftStation.make(&"stone_grill")
	_grill.position = Vector3(-6, 0, 4)
	add_child(_grill)
	_run.call_deferred()

func _give(id: StringName, n: int, lvl: int, attrs: Dictionary = {}) -> void:
	_player.inventory.add(ItemStack.make(id, n, attrs, lvl))

func _run() -> void:
	get_tree().create_timer(120.0).timeout.connect(func () -> void: get_tree().quit(1))
	await get_tree().create_timer(0.8).timeout
	_give(&"stone", 6, 4, {"sharp_section": 2})
	_give(&"branch", 8, 6, {"firm": 2})
	_give(&"twine", 10, 5)
	_give(&"large_leg_bone", 2, 18)
	_give(&"silver_chunk", 1, 50, {"firm": 4})
	var view := Vector2i(get_viewport().get_visible_rect().size)
	var tag := "%dx%d" % [view.x, view.y]
	var craft := _player.craft_ui as CraftUI
	# Craft panel: every pattern, the list page; then a recipe's detail.
	craft.toggle()
	await _settle()
	await _shot("craft_panel_" + tag)
	craft._choose_recipe("plank")
	await _settle()
	await _shot("craft_detail_" + tag)
	craft.hide_ui()
	# Radial on the workbench, its output row under it.
	_player.station_craft.open_station_menu(_bench)
	await _settle()
	await _shot("radial_workbench_" + tag)
	_player.station_craft.menu._on_pressed(&"remove")
	await _settle()
	await _shot("radial_remove_confirm_" + tag)
	_player.station_craft.close_menu()
	# Radial on the stone grill (the oven): COOK on top.
	_player.station_craft.open_station_menu(_grill)
	await _settle()
	await _shot("radial_oven_" + tag)
	_player.station_craft.close_menu()
	# Construction panel, half filled: planks in, pillars short, straps partly.
	var site := ConstructionSite.new()
	site.setup(&"basic_workbench", "Survivor")
	add_child(site)
	site.global_position = _player.global_position + Vector3(0, 0, 3)
	site.bind_bag(_player.inventory)
	for lv in [22, 14]:
		_give(&"plank_shape", 1, lv)
	_give(&"pillar_shape", 1, 16)
	_give(&"pillar_shape", 1, 4)
	_give(&"strap", 3, 2)
	for i in 2:
		site.deposit(0, site.first_fitting(_player.inventory, 0))
	for i in 3:
		site.deposit(2, site.first_fitting(_player.inventory, 2))
	craft.open_site(site)
	craft._place._select_slot(1)
	craft._place.toggle_pick(craft._place.candidates(1)[0])
	await _settle()
	await _shot("construction_" + tag)
	craft.hide_ui()
	# Placement mode for a kit (the Build page's tap): ghost, rotate / confirm / cancel.
	_give(&"workbench_kit", 1, 1)
	craft.toggle()
	craft._open_build()
	await _settle()
	await _shot("build_page_" + tag)
	craft.hide_ui()
	BuildUI.ensure(_player).pick_kit(&"workbench")
	await _settle()
	await _shot("placement_" + tag)
	_player.placer.cancel()
	print("[craftradial] DONE")
	get_tree().quit(0)

func _settle() -> void:
	for i in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("[craftradial] %s: no pixels (run windowed)" % name)
		return
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("[craftradial] shot %s" % path)
