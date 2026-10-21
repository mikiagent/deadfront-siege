extends Node3D
## CLAIMFIX shot lab: boots the home island with the real HUD, then (a) presses CLAIM while land is
## already held so the confirm panel shows, and (b) opens the build placer with the pointer still on
## the bottom-left rail so the ghost and its ROTATE / PLACE / CANCEL row can be seen where they land.
## Saves <shot-dir>/claimfix_<step>_<w>x<h>.png and prints [claimfixlab] lines.
## Windowed: --resolution 1600x900 -- --lab=claimfix_lab --shot-dir=DIR [--step=panel|ghost]
## (844x390 too; add --rendering-method gl_compatibility to check the web renderer).

var _out := ""
var _step := "panel"
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("claimfix")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--step="):
			_step = a.substr(7)
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
	await get_tree().create_timer(2.0).timeout
	var rt := World.runtime
	var own: Rect2i = rt.claims[0]
	if _step == "panel":
		# One plot east of the camp plot: an expansion the panel offers.
		var tile := Vector2i(own.end.x + own.size.x / 2, own.get_center().y)
		_player.global_position = BuildGrid.tile_centre(tile, rt) + Vector3(0.0, 0.1, 0.0)
		await get_tree().physics_frame
		_player.actions.claim()
		await get_tree().create_timer(0.6).timeout
		print("[claimfixlab] panel open=%s text=%s" % [_hud.claim_panel_open(), _hud.claim_panel_text().replace("\n", " ")])
	else:
		_player.global_position = BuildGrid.tile_centre(own.get_center(), rt) + Vector3(0.0, 0.1, 0.0)
		await get_tree().physics_frame
		Game.pointer = Vector2(16.0, get_viewport().get_visible_rect().size.y - 46.0)
		_player.placer.begin(&"basket")
		await get_tree().create_timer(0.5).timeout
		var hexes: Array = _hud.get("_place_hexes")
		var rects: Array = []
		for h in hexes:
			rects.append(h.call("hex_rect"))
		print("[claimfixlab] ghost=%s placer hexes=%s" % [_player.placer.get("_ghost_root").global_position, rects])
		print("[claimfixlab] taken=%s" % [_hud.taken_rects()])
		var st := _player.station_craft.held_slot
		print("[claimfixlab] held visible=%s rect=%s group=%s" % [st.is_visible_in_tree(), st.get_global_rect(), st.size])
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	var path := _out.path_join("claimfix_%s_%dx%d.png" % [_step, int(vp.x), int(vp.y)])
	get_viewport().get_texture().get_image().save_png(path)
	print("[claimfixlab] saved %s" % path)
	get_tree().quit(0)
