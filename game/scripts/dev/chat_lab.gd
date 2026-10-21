extends Node3D
## Region chat lab (spec 20): a shared island with the real HUD and, in this process, a local
## NetServer and two more real NetClients (Mira, Rook) beside the game's own Game.net, all in one
## island room, exchanging real lines over localhost sockets (mode home: the survivor is on the
## private home island and Game.net in its room of one, as the game puts it there); System lines come from the game's own
## paths (the island arrival, a level-up, a HUD notice). The HUD's chat comes from the hooks patch;
## without it the lab attaches one itself and says so.
## Windowed: Godot --path game --resolution 844x390 -- --lab=chat_lab --chat=<mode> --shot=<png> --shot-delay=9
## [--rendering-method gl_compatibility]. Modes: region (default), system, picker, overlay, offline, home.
## --kb=<px>: a stand-in on-screen keyboard that tall (drawn grey). --tap: taps each craft station under
## the open screen and prints whether its menu opened, then the same tap with the screen shut.
## Prints "[chat_lab] ready mode=... region=N system=N" once the scene is set.

const ISLAND := "temperate_25"
const DIR := "user://chat_lab"

## Lab only: the server's clock runs behind while the first lines go out, so the shot shows older
## relative times as the reference does ("1h 28m ago"). The lines still travel the real socket path.
class LabServer extends NetServer:
	var behind := 0.0
	func wall_time() -> float:
		return super() - behind

var _mode := "region"
var _kb := -1.0
var _tap := false
var _hud: HuntHud
var _player: Player
var _chat: ChatHud
var _server: LabServer
var _clients: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chat="):
			_mode = a.substr(7)
		elif a.begins_with("--kb="):
			_kb = a.substr(5).to_float()
		elif a == "--tap":
			_tap = true
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland" if _mode == "home" else StringName(ISLAND), Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_chat = _hud.get("chat") as ChatHud
	if _chat == null:
		print("[chat_lab] WARNING: hunt_hud.gd has no chat hook (apply claude-mmo-chat-hooks.patch); attaching one here")
		_chat = ChatHud.attach(_hud)
		_chat.hex.position = Vector2(-200, -200)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	World.pioneer_level += 1
	World.pioneer_changed.emit(World.pioneer_level)
	_player.notice("Bag is full.")
	if _mode != "offline":
		await _talk()
	match _mode:
		"system":
			_chat.open(ChatLog.SYSTEM)
		"overlay":
			pass
		_:
			_chat.open(ChatLog.REGION)
			if _kb >= 0.0:
				_keyboard()
			if _tap:
				await _tap_stations()
			if _mode == "picker":
				for i in 3:
					await get_tree().process_frame
				(_chat.screen.find_child("Plus", true, false) as Button).pressed.emit()
	print("[chat_lab] ready mode=%s online=%s region=%d system=%d" % [_mode, Game.net.is_online(),
		_chat.feed.lines[ChatLog.REGION].size(), _chat.feed.lines[ChatLog.SYSTEM].size()])

func _keyboard() -> void:
	_chat.screen.keyboard_override = _kb
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var pad := ColorRect.new()
	pad.color = Color(0.16, 0.17, 0.19)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pad.offset_top = -_kb
	layer.add_child(pad)

func _tap_stations() -> void:
	await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	var menu := _player.station_craft.menu
	var first := Vector2(-1.0, -1.0)
	for st: Node3D in get_tree().get_nodes_in_group("craft_station"):
		var at := cam.unproject_position(st.global_position + Vector3(0, 0.7, 0))
		if cam.is_position_behind(st.global_position) or not Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(at):
			continue
		var before := menu.visible
		_click(at)
		for i in 3:
			await get_tree().process_frame
		print("[chat_lab] tap on the open screen at %s over %s: station menu before=%s after=%s screen_visible=%s" % [at, st.name, before, menu.visible, _chat.screen.visible])
		if first.x < 0.0:
			first = at
	if first.x < 0.0:
		print("[chat_lab] tap: no craft station on screen")
		return
	_chat.screen.close()
	_click(first)
	for i in 3:
		await get_tree().process_frame
	print("[chat_lab] control: the same tap at %s with the screen shut: station menu=%s" % [first, menu.visible])
	menu.hide_menu()
	_chat.open(ChatLog.REGION)

func _click(at: Vector2) -> void:
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)

func _talk() -> void:
	_rm_rf(ProjectSettings.globalize_path(DIR))  # a stale lock from a killed run would refuse the start
	_server = LabServer.new()
	add_child(_server)
	if _server.start(0, ProjectSettings.globalize_path(DIR), "127.0.0.1") != OK:
		print("[chat_lab] FAIL server did not start")
		return
	var url := "ws://127.0.0.1:%d" % _server.port
	Game.net.token_path = DIR.path_join("me.json")
	Game.net.connect_to(url, World.player_name if World.player_name != "" else "Survivor")
	_clients["me"] = Game.net
	for nm in ["Mira", "Rook"]:
		var c := NetClient.new()
		c.token_path = DIR.path_join("%s.json" % nm)
		add_child(c)
		c.connect_to(url, nm)
		_clients[nm] = c
	var end := Time.get_ticks_msec() + 5000
	while not _clients.values().all(func (c: NetClient) -> bool: return c.is_online()):
		if Time.get_ticks_msec() > end:
			print("[chat_lab] FAIL clients did not come online")
			return
		await get_tree().process_frame
	for c: NetClient in _clients.values():
		var j := c.request("presence.join", {"island": PresenceSender.room_name() if c == Game.net else ISLAND})
		await j.done
	var script := [[5640, "Rook", ":wow:"], [5280, "Mira", ":smile:"], [5280, "me", "hi"],
		[5100, "Rook", ":laugh:"], [5100, "me", ":)"], [5100, "Mira", "anyone trading stone axes?"],
		[5040, "Rook", ":skull:"], [5040, "me", ":skull:"], [4980, "me", "hi"],
		[60, "Mira", "raptors by the harbour, careful"], [0, "Rook", ":heart:"], [0, "Mira", "on my way"]]
	for step: Array in script:
		_server.behind = float(step[0])
		var req := (_clients[step[1]] as NetClient).request("chat.send", {"text": step[2]})
		await req.done
		if not req.ok:
			print("[chat_lab] FAIL %s: %s" % [step, req.msg])
	_server.behind = 0.0
	end = Time.get_ticks_msec() + 2000  # the last echo can land a frame after its reply
	while _chat.feed.lines[ChatLog.REGION].size() < script.size() and Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _rm_rf(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for sub in da.get_directories():
		_rm_rf(path.path_join(sub))
	for f in da.get_files():
		da.remove(f)
	DirAccess.remove_absolute(path)
