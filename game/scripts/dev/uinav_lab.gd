extends Node3D
## UINAV captures (ui-redesign-spec §7 B3 / B4) on the home island with the real HUD: the nav menu,
## warnings + station radial + eating + respawn ring, the claim confirm, the fatigue panel and the
## death card. Windowed only:
##   --resolution WxH -- --lab=uinav_lab --shot-dir=DIR --canvas=WxH
## Saves <shot>_<W>x<H>.png and prints "[uinav] shot <path>", then "[uinav] DONE".

var _out := ""
var _canvas := Vector2i(1600, 900)
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("uinav")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			_canvas = Vector2i(int(wh[0]), int(wh[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayMode.canvas_override = _canvas
	DisplayMode.fit(get_tree().root)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _shot(n: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [n, _canvas.x, _canvas.y])
	img.save_png(path)
	print("[uinav] shot %s" % path)

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	# B3: the nav menu with a skills and an animals notice.
	_hud.notify_menu(&"skills", 2)
	_hud.notify_menu(&"animals", 1, true)
	_hud.call("_toggle_sheet", &"menu")
	await get_tree().create_timer(0.3).timeout
	await _shot("b3_nav_menu")
	_hud.call("_close_sheet")
	# B4: warnings and an ok notice, a station radial, eating, a pet's respawn ring.
	_hud.notice("Too heavy to carry more · 101 / 100")
	_hud.notice("Need a stone knife to butcher this")
	_hud.get("_events").add_notice("Game saved · 08:32", true)
	var st := _station()
	if st:
		var sid := StringName(str(st.get("station_id")))
		_player.global_position = st.global_position + Vector3(-1.5, 0.5, 2.5)
		await get_tree().create_timer(0.4).timeout
		_player.station_craft.menu.show_for(st, StationMenu.actions_for(sid, _player))
	var ep := _player.eat_session.progress_ui
	ep.show_eat(&"grilled_meat", 0.0)
	ep.set_progress(0.6)
	var ring_rec := PetRecord.new()
	ring_rec.respawn_left = 4.0
	var ring := RespawnRing.new(ring_rec)
	ring.custom_minimum_size = Vector2(120, 120) if _canvas.y > 500 else Vector2(84, 84)
	ring.size = ring.custom_minimum_size
	ring.position = Vector2(_canvas.x * 0.5 + 120.0, _canvas.y * 0.5 - ring.size.y - 30.0)
	_hud.add_child(ring)
	await get_tree().create_timer(0.6).timeout
	await _shot("b4_toasts_radials")
	ring.queue_free()
	ep.hide_eat()
	_player.station_craft.menu.hide_menu()
	_hud.get("_events").notices.clear()
	# B4: the claim confirm.
	_hud.open_claim_confirm()
	await get_tree().create_timer(0.3).timeout
	await _shot("b4_claim")
	_hud.claim_confirm_cancel()
	# B4: the fatigue panel.
	_player.vitals.fatigue = 60.0
	var fp := _hud.get("_fatigue_panel") as FatiguePanel
	fp.player = _player
	fp.toggle()
	await get_tree().create_timer(0.6).timeout
	await _shot("b4_fatigue")
	fp.toggle()
	# B4: the death card.
	_player.downed_by = "a Velociraptor"
	_player.dead = true
	await get_tree().create_timer(1.8).timeout
	await _shot("b4_death")
	print("[uinav] DONE")
	get_tree().quit(0)

func _station() -> Node3D:
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group("craft_station"):
		if n is Node3D and n.get("station_id") != null:
			var sid := str(n.get("station_id"))
			if sid in ["bonfire", "campfire"]:
				return n
			if best == null:
				best = n
	return best
