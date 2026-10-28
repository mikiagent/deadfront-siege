extends Node3D
## DAYNIGHT capture lab: the real HUD over the home island, the clock held still and stepped by the lab
## (the dial only reads it). For each variant: a 2x2 day panel (dawn, noon, dusk, midnight, row-major),
## an 8-frame sunrise strip (4x2, 05:24 to 07:05) and, with --video, numbered frames of a sped-up day for ffmpeg.
## Windowed: --resolution 1600x900 -- --lab=daynight_lab --shot-dir=DIR [--variants=a,b,c] [--video] [--full]
## Prints "[daynight] shot <path>" per file, then "[daynight] DONE". Video: ffmpeg -framerate 24 -i
## DIR/frames_<v>_<size>/%04d.png -vf scale=iw*2:ih*2:flags=neighbor -c:v libx264 -pix_fmt yuv420p -crf 23 out.mp4

const DAY := [0.25, 0.5, 0.75, 0.0]
const VIDEO_FRAMES := 240

var _out := ""
var _variants := PackedStringArray(["a", "b", "c"])
var _video := false
var _full := false
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("daynight")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--variants="):
			_variants = a.substr(11).split(",")
		elif a == "--video":
			_video = true
		elif a == "--full":
			_full = true
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
	await get_tree().create_timer(3.0).timeout
	Game.set_process(false)  # the lab steps the clock; nothing else moves it
	var view := get_tree().root.get_visible_rect().size
	var tag := "%dx%d" % [view.x, view.y]
	for v in _variants:
		DayNightDial.variant = StringName(v)
		_hud._layout()
		var crop := _crop(view)
		var panels: Array[Image] = []
		for t: float in DAY:
			panels.append(await _shot(t, crop))
		_save(_grid(panels, 2), "daynight_%s_%s_day.png" % [v, tag])
		var rise: Array[Image] = []
		for i in 8:
			rise.append(await _shot(lerpf(DayNightDial.RISE - 0.035, DayNightDial.RISE + 0.035, float(i) / 7.0), crop))
		_save(_grid(rise, 4), "daynight_%s_%s_sunrise.png" % [v, tag])
		if _video:
			var dir := _out.path_join("frames_%s_%s" % [v, tag])
			DirAccess.make_dir_recursive_absolute(dir)
			for i in VIDEO_FRAMES:
				var img := await _shot(fposmod(0.15 + float(i) / VIDEO_FRAMES, 1.0), crop, 1)
				img.save_png(dir.path_join("%04d.png" % i))
			print("[daynight] frames %s" % dir)
	print("[daynight] DONE")
	get_tree().quit(0)

## The dial and the minimap with some room around them (even sizes for x264), or the whole view.
func _crop(view: Vector2) -> Rect2i:
	if _full:
		return Rect2i(Vector2i.ZERO, Vector2i(view))
	var dial := _hud.get("_daynight") as Control
	var r := dial.get_global_rect().merge((_hud.get("_minimap") as Control).get_global_rect()).grow(40.0)
	r = r.intersection(Rect2(Vector2.ZERO, view))
	var out := Rect2i(r)
	out.size = out.size / 2 * 2
	return out

func _shot(t: float, crop: Rect2i, frames: int = 3) -> Image:
	Game.time_of_day = t
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_tree().root.get_texture().get_image().get_region(crop)

func _grid(imgs: Array[Image], cols: int) -> Image:
	var w := imgs[0].get_width()
	var h := imgs[0].get_height()
	var rows := ceili(float(imgs.size()) / cols)
	var out := Image.create(w * cols + 4 * (cols - 1), h * rows + 4 * (rows - 1), false, imgs[0].get_format())
	out.fill(Color(0.1, 0.1, 0.1))
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 4), (i / cols) * (h + 4)))
	return out

func _save(img: Image, file: String) -> void:
	var at := _out.path_join(file)
	img.save_png(at)
	print("[daynight] shot %s" % at)
