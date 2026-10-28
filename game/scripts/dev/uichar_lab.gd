extends Node3D
## UICHAR screenshots: Character, Skills and Orders on the home island, opened through the HUD's
## public entry points, one PNG each into --shot-dir (suffixed with the canvas, e.g. character_1600x900).
## Windowed: Godot --path game --resolution 1600x900 -- --lab=uichar_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("uichar")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	_player.ui.reparent(modals)
	(_player.craft_ui as Node).reparent(modals)
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _shot(tag: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var v := get_tree().root.get_visible_rect().size
	var path := _out.path_join("%s_%dx%d.png" % [tag, int(v.x), int(v.y)])
	img.save_png(path)
	print("[uichar] shot %s" % path)

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var inv := _player.inventory
	inv.add(ItemStack.make(&"stone_knife", 1, {}, 5))
	inv.equip_at(inv.find_first(&"stone_knife"))
	inv.add(ItemStack.make(&"work_pick", 1, {}, 3))
	inv.add(ItemStack.make(&"forager_vest", 1, {}, 2))
	inv.equip_at(inv.find_first(&"forager_vest"))
	_player.skills.sp_extra = 3
	_player.skills._recount_sp()
	_hud.open_character()
	_player.ui._character._on_equip_slot_pressed("weapon")
	await _shot("character")
	_player.ui.hide_ui()
	_hud.open_skills("melee")
	await _shot("skills")
	_hud._skills_sheet.close()
	_hud.open_orders()
	await _shot("orders")
	print("[uichar] DONE")
	get_tree().quit(0)
