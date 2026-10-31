extends Node3D
## Combat ability cooldown hexes (owner 2026-10-31: "circular, going clockwise ... the timer countdown in the
## button"). Starts a hunt on a frozen zebraceratops, kicks it, and saves the HUD right after the kick,
## mid-cooldown and ready, then the three lock states (Winded, out of stamina, Knockdown), then quits.
## Windowed only: Godot --path game --position 6000,3000 --resolution 1688x780 -- --skip-charcreate
##   --lab=cooldown_ui_lab --shot-dir=DIR [--canvas=844x390]
## Prints "[cooldownui] shot <path> kick_left=<s>" per frame, then "[cooldownui] DONE".

var _out := ""
var _player: Player

func _ready() -> void:
	var canvas := Vector2i(844, 390)
	_out = OS.get_user_data_dir().path_join("cooldown-ui")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			canvas = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayMode.canvas_override = canvas
	DisplayMode.fit(get_tree().root)
	Game.debug_overlay = false
	Game.max_creatures_per_island = 0
	_player = LabKit.build(self, 40.0)["player"]
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var sp := Spawner.new()
	sp.species = &"zebraceratops"
	sp.count = 1
	sp.radius = 0.1
	sp.position = _player.global_position + Vector3(0.0, 0.0, 2.6)
	add_child(sp)
	var prey := sp.spawn_now()[0]
	await get_tree().create_timer(0.5).timeout
	prey.process_mode = Node.PROCESS_MODE_DISABLED  # a still target: only the HUD changes between shots
	var hunt := _player.hunt
	hunt.auto = false
	hunt.auto_ability = false
	hunt.start(prey)
	await get_tree().create_timer(1.0).timeout
	hunt.use_kick()
	if hunt.cooldown_left(&"kick") <= 0.0:
		print("[cooldownui] kick refused (%s): committing the cooldown directly" % hunt.last_notice)
		hunt.commit_tactic(&"kick", float(CombatTuning.section("kick").get("cooldown", 6.0)), 0.45)
	await _shot("1_kick_just_used")
	while hunt.cooldown_left(&"kick") > 2.6:
		await get_tree().process_frame
	await _shot("2_kick_mid_cooldown")
	while hunt.cooldown_left(&"kick") > 0.0:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	await _shot("3_kick_ready")
	_player.statuses.apply(&"winded")
	await _shot("4_lock_winded")
	_player.statuses.clear_id(&"winded")
	_player.vitals.energy = 2.0
	await _shot("5_lock_no_stamina")
	_player.vitals.energy = _player.vitals.max_energy
	_player.statuses.apply(&"knockdown")
	await _shot("6_lock_knockdown")
	print("[cooldownui] DONE")
	get_tree().quit(0)

func _shot(shot_name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		push_error("[cooldownui] %s: no pixels (run windowed)" % shot_name)
		return
	var path := _out.path_join(shot_name + ".png")
	img.save_png(path)
	print("[cooldownui] shot %s kick_left=%.2f" % [path, _player.hunt.cooldown_left(&"kick")])
