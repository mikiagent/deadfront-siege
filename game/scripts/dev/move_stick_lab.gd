extends Node3D
## CONTROLS B2 check in the real game: the floating move stick on the left half, under the real HUD.
## Boots home_grassland with the HUD (as gather_jitter_lab does) and drives the touch layer with injected
## touches, as a thumb would: press on open ground on the left half, drag inside the dead zone (nothing),
## drag part way (stick up, centred on the press, walk), push past the rim (knob clamps, sprint), release
## (gone, stops). Then a short tap there (it still reaches the game), and a press-drag that starts on a HUD
## hex on the left (the hex keeps it: no stick). Saves stick_walk / stick_run shots.
## Windowed: --resolution 844x390 -- --lab=move_stick_lab --touch [--shot-dir=DIR]
## Prints "[stick] ..." lines, then "[stick] PASS" (exit 0) or FAIL lines (exit 1).

const SPEED_TOL := 0.1  ## m/s

var _fails: Array[String] = []
var _out := ""
var _player: Player
var _stick: FloatStick

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("move-stick")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var tc := get_node("/root/TouchControls")
	_stick = tc.joystick as FloatStick
	var view := get_viewport().get_visible_rect().size
	print("[stick] view=%dx%d touch=%s" % [view.x, view.y, tc.enabled])
	_expect(tc.enabled and _stick != null and _stick.is_visible_in_tree(), "the touch layer is on (--touch) and carries the floating stick")
	if not _expect_ok():
		_finish()
		return
	# Where a left thumb rests, above the bottom rail (open ground on both layouts).
	var press := (view * Vector2(0.16, 0.6)).round()
	var walk := _player.walk_speed * _player.statuses.move_mult()
	var sprint := _player.sprint_speed * _player.statuses.move_mult()
	_touch(press, true)
	await _frames(2)
	_drag(press + Vector2(8, 0))
	await _frames(4)
	_expect(not _stick.active and _speed() < 0.01 and not _player.nav_active, "inside the %.0f px dead zone: no stick, no move, no tap" % FloatStick.DEAD_ZONE_PX)
	_drag(press + Vector2(30, -12))
	await get_tree().create_timer(0.6).timeout
	var v_walk := _speed()
	var centred := _stick.active and _stick._origin.distance_to(press) < 0.5
	print("[stick] part deflection: active=%s origin=%s press=%s knob=%.2f speed=%.2f m/s" % [_stick.active, _stick._origin, press, _stick.vector.length(), v_walk])
	_expect(centred, "past the dead zone the stick floats up centred on the press")
	_expect(absf(v_walk - walk) <= SPEED_TOL, "part deflection walks (%.2f m/s, want %.2f)" % [v_walk, walk])
	await _shot("stick_walk")
	_drag(press + Vector2(160, -70))
	await get_tree().create_timer(0.6).timeout
	var v_run := _speed()
	print("[stick] rim: knob=%.3f sprint=%s speed=%.2f m/s" % [_stick.vector.length(), Input.is_action_pressed("sprint"), v_run])
	_expect(_stick.vector.length() <= 1.0001 and absf(v_run - sprint) <= SPEED_TOL, "past the rim the knob clamps (%.3f) and sprints (%.2f m/s, want %.2f)" % [_stick.vector.length(), v_run, sprint])
	await _shot("stick_run")
	_touch(press + Vector2(160, -70), false)
	await get_tree().create_timer(0.5).timeout
	print("[stick] released: active=%s speed=%.2f nav=%s" % [_stick.active, _speed(), _player.nav_active])
	_expect(not _stick.active and _speed() < 0.05 and not _player.nav_active, "release hides the stick, stops the survivor and taps nothing")
	# A short tap where the stick lives still reaches the game (walks there, or opens what is under it).
	var radial: GatherRadial = _player.get("_gather_radial")
	_touch(press, true)
	_drag(press + Vector2(4, 3))
	_touch(press + Vector2(4, 3), false)
	await _frames(4)
	var reached := _player.nav_active or (radial != null and radial.is_open())
	print("[stick] short tap: nav=%s radial=%s stick=%s" % [_player.nav_active, radial != null and radial.is_open(), _stick.active])
	_expect(reached and not _stick.active, "a short tap on the left half still taps")
	_player.clear_nav()
	if radial:
		radial.close()
	await get_tree().create_timer(0.5).timeout
	# A press that lands on a HUD hex on the left half belongs to the hex.
	var hex := _left_hud_hex(view)
	_expect(hex != null, "a HUD hex on the left half")
	if hex:
		var on := hex.get_global_rect().get_center()
		_touch(on, true)
		_drag(on + Vector2(0, -40))
		await _frames(4)
		print("[stick] press on HUD hex at %s: stick=%s" % [on, _stick.active])
		_expect(not _stick.active and _speed() < 0.01, "a press-drag starting on a HUD hex floats no stick")
		_touch(on + Vector2(0, -40), false)
		await _frames(2)
	_finish()

## The visible HUD hex nearest the bottom-left corner (the MENU end of the rail).
func _left_hud_hex(view: Vector2) -> HexButton:
	var best: HexButton = null
	var best_d := INF
	for n in get_tree().root.find_children("*", "HexButton", true, false):
		var h := n as HexButton
		if h == null or not h.is_visible_in_tree() or h.get_global_rect().get_center().x > view.x * 0.5:
			continue
		var d := h.get_global_rect().get_center().distance_to(Vector2(0, view.y))
		if d < best_d:
			best_d = d
			best = h
	return best

func _speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Canvas point -> the window point Input wants.
func _win(at: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * at

func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = _win(at)
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = _win(at)
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		return  # headless: numbers only
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	print("[stick] shot %s" % path)

func _expect(ok: bool, message: String) -> void:
	print("[stick] %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		_fails.append(message)

func _expect_ok() -> bool:
	return _fails.is_empty()

func _finish() -> void:
	print("[stick] %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
