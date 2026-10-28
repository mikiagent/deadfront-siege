extends Node3D
## NAVZOOM capture: the home island with the real HUD, then every frame of the nav menu opening, held,
## and closing, saved as <shot-dir>/f_NNN.png (open starts at frame OPEN_AT, close at CLOSE_AT).
## Run with --fixed-fps 30 so each saved frame is 1/30 s of transition however slow the readback is.
## Windowed: --fixed-fps 30 --resolution 1600x900 -- --lab=navzoom_lab --shot-dir=DIR
## Prints "[navzoom] DONE <n> frames" and quits.

const OPEN_AT := 4
const CLOSE_AT := 40
const FRAMES := 66

var _out := ""
var _hud: HuntHud

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(4.0).timeout
	for i in FRAMES:
		if i == OPEN_AT or i == CLOSE_AT:
			_hud._toggle_sheet(&"menu")
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png(_out.path_join("f_%03d.png" % i))
		await get_tree().process_frame
	print("[navzoom] DONE %d frames in %s" % [FRAMES, _out])
	get_tree().quit(0)
