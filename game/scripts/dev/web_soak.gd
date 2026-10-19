extends Node
## Deterministic in-engine route used by tools/production_soak.mjs.
## It drives real menu and travel methods while the browser harness watches pixels and logs.
## Native runs (desktop or --headless, `-- --web-soak`) click the bench themselves and exit 0/1,
## so the route is also a local gate. Every wait has a timeout: the old route awaited
## World.island_changed forever when the sail gate said "Needs Survival 20".

## The whole route must finish inside this; a hang becomes "[soak] FAIL watchdog".
const WATCHDOG_S := 180.0
## Seconds a travel may take before the route fails.
const TRAVEL_S := 30.0
## The route seeds Survival 20 and stones and travels (travel() saves). It must never reach a real
## player's save: production serves this route to anyone who opens /?soak=1.
const SOAK_SAVE := "user://soak_save.json"
var _done := false
var _failed := false
var _real_save := ""
var _real_md5 := ""

func run(host: Node) -> void:
	print("[soak] start")
	print("[soak] stamp %s" % Game.build_stamp)
	_isolate_save()
	get_tree().create_timer(WATCHDOG_S, true, false, true).timeout.connect(func () -> void:
		if not _done:
			_fail("watchdog: route not finished after %.0f s" % WATCHDOG_S))
	await get_tree().create_timer(1.0).timeout
	for node in get_tree().root.find_children("CharacterCreation", "CharacterCreation", true, false):
		node.free()
	World.home_terrain = &"meadow"
	World.t_stones = maxi(World.t_stones, 20)
	World.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await _checkpoint("world-entered")

	# Real input acceptance for the two-stage CraftStation flow. Project the live bench
	# and generated CRAFT hex to screen, then feed touch press/release pairs through Godot.
	var player := get_tree().get_first_node_in_group("player") as Player
	var bench := get_tree().get_first_node_in_group("workbench") as Node3D
	if player == null or bench == null:
		_fail("station acceptance missing player or workbench")
		return
	# The route sails to temperate_25, whose harbour gate needs Survival 20 (route_level = tier - 5).
	# Seeded like camp_travel_probe: the soak proves the release, not earned progression.
	player.skills.trees["survival"]["level"] = maxi(player.skills.level_of("survival"), World.route_level(&"temperate_25"))
	var tap_zone := bench.get_node_or_null("TapZone") as Area3D
	if tap_zone == null or not player._is_interactable(tap_zone) or player._unwrap_tap(tap_zone) != bench:
		_fail("workbench tap zone missing or does not route to station")
		return
	var cam := get_viewport().get_camera_3d()
	# Put the survivor in a deterministic station-relative spot and let the following camera settle.
	# A moving navigation target made the projected browser click stale before Chrome received it.
	player.clear_nav()
	player.global_position = bench.global_position + Vector3(-3.0, 0.5, 3.0)
	await get_tree().create_timer(1.0).timeout
	var bench_screen := cam.unproject_position(bench.global_position + Vector3(0, 0.5, 0))
	# Browser harness sees this marker and sends a real Chrome mouse click into the canvas.
	# Touchscreen/input-parser synthesis does not cover desktop canvas GUI routing.
	var view_size := get_viewport().get_visible_rect().size
	print("[soak] desktop_click_norm %.6f %.6f" % [bench_screen.x / view_size.x, bench_screen.y / view_size.y])
	if not OS.has_feature("web"):
		await _click(bench_screen)  # no browser harness here to send the real click
	# Console delivery and Playwright mouse injection are asynchronous to the game frame.
	await get_tree().create_timer(4.0).timeout
	if player.station_craft == null or not player.station_craft.menu.visible \
			or player.station_craft.menu._ring3d == null or not player.station_craft.menu._ring3d.visible:
		_fail("first workbench touch did not open ring")
		return
	await _checkpoint("station-ring-open")
	var craft_button := player.station_craft.menu._buttons[0] as Control
	craft_button.pressed.emit()
	await get_tree().create_timer(0.25).timeout
	if player.craft_ui == null or not player.craft_ui.visible:
		_fail("second CRAFT touch did not open sheet")
		return
	await _checkpoint("station-craft-open")
	player.craft_ui.hide()
	await _touch(cam.unproject_position(bench.global_position + Vector3(0, 0.5, 0)))
	await get_tree().create_timer(0.25).timeout
	player.global_position = bench.global_position + Vector3(8, 0, 0)
	await get_tree().create_timer(0.25).timeout
	if player.station_craft.menu.visible:
		_fail("walking away did not dismiss station ring")
		return
	await _checkpoint("station-walkaway-dismissed")

	var world_ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
	world_ui.show_harbour()
	await _checkpoint("harbour-open")
	world_ui.hide_all()
	await _checkpoint("harbour-closed")

	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		_fail("HUD not found")
		return
	hud._toggle_sheet(&"pets")
	await _checkpoint("pets-open")
	hud._close_sheet()
	hud._toggle_sheet(&"build")
	await _checkpoint("build-open")
	hud._close_sheet()
	await _checkpoint("build-closed")

	print("[soak] loading temperate_25")  # the browser harness times load frames apart from play
	World.travel(&"temperate_25", &"sail")
	if not await _arrived(&"temperate_25"):
		return
	await _checkpoint("travelled")
	print("[soak] loading home_grassland")  # the browser harness times load frames apart from play
	World.travel(&"home_grassland", &"harbour_home")
	if not await _arrived(&"home_grassland"):
		return
	await _checkpoint("returned-home")
	if _failed:
		return
	if _save_md5(_real_save) != _real_md5:
		_fail("route changed the real save %s" % _real_save)
		return
	print("[soak] real save untouched (%s)" % ("absent" if _real_md5.is_empty() else _real_md5.left(8)))
	_done = true
	print("[soak] PASS")
	_quit_native(0)

## Point every save of this session at a throwaway file and remember the real one's hash.
## The redirect is a static var, so it lasts for the whole page: later autosaves stay off it too.
func _isolate_save() -> void:
	var save_script := load("res://scripts/core/save_game.gd") as GDScript
	_real_save = save_script.path
	_real_md5 = _save_md5(_real_save)
	save_script.path = SOAK_SAVE
	if FileAccess.file_exists(SOAK_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SOAK_SAVE))

static func _save_md5(p: String) -> String:
	return FileAccess.get_md5(p) if FileAccess.file_exists(p) else ""

## Wait for a travel to land, at most TRAVEL_S.
func _arrived(island: StringName) -> bool:
	var left := TRAVEL_S
	while left > 0.0:
		if World.island_id == island and World.runtime != null and is_instance_valid(World.runtime):
			return true
		await get_tree().create_timer(0.25).timeout
		left -= 0.25
	_fail("travel to %s did not arrive in %.0f s (island=%s)" % [island, TRAVEL_S, World.island_id])
	return false

## Native runs exit with the verdict; the browser page stays up for the harness to read.
func _quit_native(code: int) -> void:
	if not OS.has_feature("web"):
		get_tree().quit(code)

func _checkpoint(name: String) -> void:
	await get_tree().create_timer(0.25).timeout
	print("[soak] checkpoint %s" % name)

func _fail(message: String) -> void:
	if _done:
		return
	_done = true
	_failed = true
	push_error("[soak] FAIL %s" % message)
	print("[soak] FAIL %s" % message)
	_quit_native(1)

## A left click at a screen point through the normal input path (motion, press, release).
func _click(pos: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = pos
	move.global_position = pos
	Input.parse_input_event(move)
	await get_tree().process_frame
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.position = pos
		mb.global_position = pos
		mb.pressed = pressed
		Input.parse_input_event(mb)
		await get_tree().process_frame

func _touch(pos: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 7
	down.position = pos
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.index = 7
	up.position = pos
	up.pressed = false
	Input.parse_input_event(up)

