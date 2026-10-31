extends Node3D
## UIWORLD shots (windowed): boots the home island with the real HUD, opens the four restyled screens
## in each state the mockups show and saves one PNG each into --shot-dir:
## domain_declare, domain_plots, comms, radio, pen, pen_started, pen_tamed, island_pick.
## Run (desktop gate, then the landscape phone at 2x):
##   Godot --path game --resolution 1600x900 -- --lab=uiworld_lab --shot-dir=DIR --canvas=1600x900
##   Godot --path game --resolution 1688x780 -- --lab=uiworld_lab --shot-dir=DIR --canvas=844x390
## Prints "[uiworld] shot <path>" per screen, "[uiworld] min_px <screen> <n>" and "[uiworld] DONE".

var _out := ""
var _player: Player
var _hud: HuntHud
var _suffix := ""

func _ready() -> void:
	var canvas := Vector2i(1600, 900)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--canvas="):
			var wh := a.substr(9).split("x")
			canvas = Vector2i(int(wh[0]), int(wh[1]))
	if _out == "":
		_out = OS.get_user_data_dir().path_join("uiworld")
	DirAccess.make_dir_recursive_absolute(_out)
	_suffix = "_%dx%d" % [canvas.x, canvas.y]
	DisplayMode.canvas_override = canvas
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

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(shot_name: String, screen: Control = null) -> void:
	await _frames(3)
	await get_tree().create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var path := _out.path_join(shot_name + _suffix + ".png")
	img.save_png(path)
	print("[uiworld] shot %s" % path)
	if screen != null and screen.has_method("min_target_px"):
		print("[uiworld] min_px %s %.0f" % [shot_name, float(screen.call("min_target_px"))])

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var rt := World.runtime
	if rt != null:
		IslandClaims.clear_domain(rt)
	# F1 declare
	var dom := _hud.open_domain()
	await _shot("domain_declare", dom)
	# F1 plots: declare three plots next to the camp, the way Confirm does
	if rt != null:
		var cells: Array[Vector2i] = IslandClaims.eligible_cells(rt, IslandClaims.cell_of(rt, BuildGrid.tile_of(_player.global_position)), 4)
		var want: Array = []
		for c in cells:
			if want.is_empty() or IslandClaims.adjacent_to(c, _as_set(want)):
				want.append(c)
			if want.size() >= 3:
				break
		var out: Dictionary = IslandClaims.claim_cells(rt, want)
		print("[uiworld] claim %s -> %s" % [want, out])
	dom.select_tab("tamed_island")
	await _shot("domain_plots", dom)
	dom.close()
	# F3
	var comms := _hud.open_comms()
	await _shot("comms", comms)
	comms.select("committee")
	await _shot("comms_locked", comms)
	comms.select("company")
	comms.open_radio()
	await _shot("radio", comms.radio)
	comms.radio.close()
	# E2: a pen with two captured animals in the bag
	var pen := TamingPen.make()
	add_child(pen)
	pen.global_position = _player.global_position + Vector3(4, 0, 0)
	_player.inventory.add(ItemStack.make(&"captured_animal", 1, {"species": "zebraceratops", "level": 13, "nature": "docile"}))
	_player.inventory.add(ItemStack.make(&"captured_animal", 1, {"species": "velociraptor", "level": 9, "nature": "stubborn"}))
	_player.actions.pen_interact(pen)
	var ui := _hud.get("_world_sheets").get(&"pen") as TamingPenUI
	await _shot("pen", ui)
	ui.call("_on_tame")
	await _shot("pen_started", ui)
	# PENCLAIM: the wait ends with a success: the gold Taming successful card
	pen.force_result = 1
	pen.remaining = 0.0
	pen.resolve(_player)
	await _shot("pen_tamed", ui)
	ui.close()
	# A2
	var pick := IslandPick.instance_on(self)
	pick.open()
	await _shot("island_pick")
	print("[uiworld] DONE")
	get_tree().quit(0)

static func _as_set(a: Array) -> Dictionary:
	var d := {}
	for c in a:
		d[c] = true
	return d
