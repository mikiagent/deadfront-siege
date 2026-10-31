extends Node3D
## UIGATHER captures (ui-redesign-spec §7 B1 / B2) on the home island with the real HUD: the field HUD
## with harvest pills, gathering (hex pie fill, yield card, XP feed), combat, and combat with the NET
## hex gold. Windowed only:
##   --resolution WxH -- --lab=uigather_lab --shot-dir=DIR --canvas=WxH
## Saves <shot>_<W>x<H>.png, prints "[uigather] shot <path>" and checks, then "[uigather] DONE".

var _out := ""
var _canvas := Vector2i(1600, 900)
var _player: Player
var _hud: HuntHud
var _failed := 0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("uigather")
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

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_failed += 1
	print("[uigather] %s %s" % ["ok" if ok else "FAIL", msg])

func _shot(n: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [n, _canvas.x, _canvas.y])
	img.save_png(path)
	print("[uigather] shot %s" % path)

## The nearest harvest node with two or more options, none needing a tool we lack.
func _rock() -> HarvestNode:
	var best: HarvestNode = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or hn.options().size() < 2 or not hn.has_harvests_left():
			continue
		var d := hn.global_position.distance_to(_player.global_position)
		if d < bd:
			bd = d
			best = hn
	return best

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	for id in [&"work_pick", &"work_axe", &"stone_knife"]:
		if Data.item(id):
			LabKit.give(_player, id, 1)
	var rock := _rock()
	_check(rock != null, "a multi-option harvest node is on the island")
	if rock == null:
		print("[uigather] DONE failed=%d" % (_failed + 1))
		get_tree().quit(1)
		return
	# B1 idle: stand a few metres off the node, pills label what is near.
	var off := Vector3(-3.0, 0.0, 1.5)
	_player.global_position = rock.global_position + off + Vector3.UP * 0.5
	await get_tree().create_timer(1.2).timeout
	await _shot("b1_field_hud")
	_check(not HudPills.hit_pills.is_empty(), "harvest pills are drawn and tappable (%d)" % HudPills.hit_pills.size())
	# B1 gathering: tap the node's pill (the real input path), pick its first open option.
	var pill_rect := Rect2()
	for d: Dictionary in HudPills.hit_pills:
		if d["node"] == rock:
			pill_rect = d["rect"]
	if pill_rect.has_area():
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = pill_rect.get_center()
		_hud._input(ev)
	else:
		_player._interact_tap_target(rock)
	await get_tree().create_timer(0.3).timeout
	var radial: GatherRadial = _player._gather_radial
	_check(radial.is_open() and radial.node == rock, "a tap on the pill opens the radial on its node")
	var want := 124.0 if _canvas.y > 500 else 64.0
	for b in radial._buttons:
		_check(b.size.x >= want - 0.5 and b.size.x >= 64.0, "gather hex is %.0f px (want %.0f)" % [b.size.x, want])
	var pick := 0
	for i in radial._buttons.size():
		if not radial._buttons[i].disabled:
			pick = i
			break
	radial._on_pick(pick)
	var t0 := Time.get_ticks_msec()
	var landed := false
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		if not (_hud.get("top_feed") as TopFeed).rows.is_empty():
			landed = true
			break
	_check(landed, "a gathered unit raises its top-middle gain row")
	# Mid-way through the next unit: the pressed hex pie-filled, the others locked.
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
		if radial.active_index >= 0 and radial._buttons[radial.active_index].fill_ratio >= 0.55:
			break
	if radial.is_open() and radial.active_index >= 0:
		var b := radial._buttons[radial.active_index]
		_check(b.fill_ratio > 0.0, "the running hex pie-fills (%.2f)" % b.fill_ratio)
		for i in radial._buttons.size():
			if i != radial.active_index:
				_check(radial._buttons[i].disabled, "hex %d is disabled while one runs" % i)
	var yb: Rect2 = _hud.drawn_blocks.get("toast0", Rect2())
	_check(yb.has_area() and Rect2(Vector2.ZERO, Vector2(_canvas)).encloses(yb), "the yield card is on screen (%s)" % yb)
	await _shot("b1_field_hud_gathering")
	_player.actions.stop_gather_cycle()
	_player.gather_target = null
	await get_tree().create_timer(0.5).timeout
	# B2 combat: a zebraceratops held still, 60 % HP, bleeding.
	var z := _spawn(&"zebraceratops", Vector3(4.5, 0, 2.0))
	_check(z != null, "zebraceratops spawned")
	if z:
		z.process_mode = Node.PROCESS_MODE_DISABLED
		z.health.hp = z.health.max_hp * 0.46
		z.statuses.apply(&"bleed")
		_player.hunt.start(z)
		_player.hunt.auto = false
		await get_tree().create_timer(1.0).timeout
		_check(_hud._skill_hexes[0].fill != UiTokens.GOLD, "NET is not gold above 30 %")
		await _shot("b2_combat_hud")
		# B2 net ready: under 30 %, groggy, a net and the technique in hand.
		LabKit.give(_player, &"capture_net_i", 1)
		Data.set_survival_unlocked(&"capture_technique_I", true)
		z.health.hp = z.health.max_hp * 0.26
		z.statuses.apply(&"groggy")
		await get_tree().create_timer(0.6).timeout
		_check(not _hud._skill_hexes[0].disabled and _hud._skill_hexes[0].fill == UiTokens.GOLD, "NET turns gold at or under 30 %")
		await _shot("b2_combat_hud_net_ready")
	print("[uigather] DONE failed=%d" % _failed)
	get_tree().quit(0)

func _spawn(species: StringName, offset: Vector3) -> Creature:
	var sp := Spawner.new()
	sp.species = species
	sp.count = 1
	sp.radius = 0.5
	sp.as_pack = false
	sp.position = _player.global_position + offset
	World.runtime.add_child(sp)
	var made := sp.spawn_now()
	if made.is_empty():
		return null
	var c: Creature = made[0]
	c.global_position = _player.global_position + offset
	return c
