extends Node3D
## TREADMILL capture lab: the real HUD, the survivor's exhaustion driven by the lab so the belt shows
## each tier running right, Well Rested (paused) and a sleep easing left.
## Stills: --resolution 1600x900 -- --lab=treadmill_lab --shot-dir=DIR [--tag=before]
##   -> DIR/<tag>_<WxH>.png, a column of crops (rested, worn, tired, exhausted, sleeping, well rested).
## Video: add --video and run with --write-movie OUT.avi --fixed-fps 30: one pass through the tiers;
##   prints "[treadmill] crop x y w h" for ffmpeg's crop filter.

const STATES := [["rested", 12.0, 0.12, false], ["worn", 37.0, 0.12, false], ["tired", 62.0, 0.2, false],
		["exhausted", 87.0, 0.3, false], ["sleeping", 50.0, -2.0, false], ["well rested", 20.0, 0.0, true]]

var _out := ""
var _tag := "after"
var _video := false
var _hud: HuntHud
var _player: Player
var _f := 10.0
var _rate := 0.0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("treadmill")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a == "--video":
			_video = true
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 40.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	_run.call_deferred()

func _process(delta: float) -> void:
	if _player == null or _player.vitals == null:
		return
	_f = clampf(_f + _rate * delta, 0.0, 100.0)
	_player.vitals.fatigue = _f

func _drive(f: float, rate: float, rested: bool) -> void:
	_f = f
	_rate = rate
	if rested:
		_player.statuses.apply(&"well_rested")
	else:
		_player.statuses.clear_id(&"well_rested")

func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	var view := get_tree().root.get_visible_rect().size
	var crop := _crop()
	if _video:
		print("[treadmill] crop %d %d %d %d" % [crop.position.x, crop.position.y, crop.size.x, crop.size.y])
		await _video_pass()
		get_tree().quit(0)
		return
	var shots: Array[Image] = []
	for s: Array in STATES:
		_drive(s[1], s[2], s[3])
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		shots.append(get_tree().root.get_texture().get_image().get_region(crop))
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var img := Image.create(w, (h + 4) * shots.size() - 4, false, shots[0].get_format())
	img.fill(Color(0.1, 0.1, 0.1))
	for i in shots.size():
		img.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(0, i * (h + 4)))
	var at := _out.path_join("%s_%dx%d.png" % [_tag, view.x, view.y])
	img.save_png(at)
	print("[treadmill] shot %s" % at)
	print("[treadmill] DONE")
	get_tree().quit(0)

## Rested creep, a ramp through every tier, Well Rested pause, then a sleep running left.
func _video_pass() -> void:
	_drive(8.0, 0.1, false)
	await get_tree().create_timer(2.0).timeout
	_rate = 7.0
	while _f < 97.0:
		await get_tree().process_frame
	_rate = 0.3
	await get_tree().create_timer(1.5).timeout
	_drive(30.0, -6.0, false)
	await get_tree().create_timer(2.0).timeout
	_drive(18.0, 0.0, true)
	await get_tree().create_timer(3.0).timeout

## The vitals block (face, tier word, belt) with a margin; even sizes for x264.
func _crop() -> Rect2i:
	var r: Rect2 = _hud.drawn_blocks.get("vitals", Rect2(0, 0, 320, 120))
	r = r.grow(6.0).intersection(get_tree().root.get_visible_rect())
	var out := Rect2i(r)
	out.size = out.size / 2 * 2
	return out
