class_name LoadingScreen
extends CanvasLayer
## LOADING (owner 2026-10-30: "we don't have loading for some reason. You should add loading screens in
## between"): the one overlay every slow or hard-cut transition shows. Above everything (layer 128),
## opaque, in the sheet chrome's type and colours: the destination title, a bar that follows the island
## build's real stages, and a tip from data/ui/loading_tips.json.
##
## `await LoadingScreen.run(title, work)`: fade in, run `work` (synchronous), fill the bar, fade out.
## The island build reports its stages through PerfTrace.mark -> stage(); each one forces a frame
## (RenderingServer.force_draw, at most every DRAW_GAP_MS) so the bar moves while the build holds the main thread, without making
## the build itself a coroutine. While the overlay is up the tree is paused and every input event is
## eaten, so nothing reaches the world. Headless runs (tests) skip the fades: `work` runs in the
## caller's frame exactly as it did before, and stage() never draws.

const LAYER := 128
const FADE_S := 0.18
const DRAW_GAP_MS := 200  # a forced frame costs ~14 ms (mostly the vsync swap): ~5 bar steps a second
const TIPS_PATH := "res://data/ui/loading_tips.json"
## The island build's PerfTrace marks (IslandRuntime.build and its helpers), in build order: the bar's
## fraction once that phase is done, and what runs next. Fractions are the cumulative share of a home
## build's [buildprofile] table (2026-10-30, ~3.1 s headless); a mark missing on some island just
## leaves the bar where it was.
const STAGES := {
	"shape.margins": [0.03, "Shaping the coast"],
	"shape.fill": [0.10, "Shaping the coast"],
	"shape.resettle": [0.14, "Raising the terrain"],
	"tiles.loop": [0.22, "Smoothing the shore"],
	"smooth.merge": [0.28, "Raising the terrain"],
	"terrain.mesh": [0.32, "Filling the sea"],
	"terrain": [0.33, "Charting the walkable ground"],
	"nav": [0.33, "Building the camp and harbour"],
	"camp": [0.36, "Growing the ground cover"],
	"cover.plan": [0.49, "Growing the ground cover"],
	"cover.group": [0.54, "Growing the ground cover"],
	"scatter.cover": [0.58, "Dressing the biome"],
	"dress.plan": [0.64, "Dressing the biome"],
	"scatter.dress": [0.67, "Marking the landmarks"],
	"scatter.landmarks": [0.71, "Placing trees, stone and plants"],
	"scatter.families": [0.75, "Placing trees, stone and plants"],
	"scatter": [0.76, "Placing props"],
	"props": [0.83, "Finding the paths"],
	"pathing": [0.90, "Waking the creatures"],
	"spawns": [0.98, "Raising the weather and sky"],
	"__end": [0.99, "Landing"],
}

static var current: LoadingScreen
## Every title shown, oldest first (tests read it; capped).
static var shown: Array[String] = []
## The furthest fraction the open overlay reached; 1.0 after a finished run.
static var last_progress := 0.0
static var _tips: Array[String] = []
static var _drawn_ms := 0
## What the forced frames cost the open overlay's build (the report's build-time impact).
static var draws := 0
static var draw_cost_us := 0
static var _rotate_s := 4.5

var progress := 0.0
var stage_text := "Getting ready"
var _root: Control
var _hexes: Control
var _title: Label
var _tip: Label
## The bar, its stage line and percent, and the emblem are painted straight into this server canvas
## item: a Control's redraw waits for the frame's deferred calls, which a forced frame mid-build never
## runs, so Labels and a ProgressBar would show the pre-build state until the build ends.
var _live: RID
var _bar_rect := Rect2()
var _emblem := Vector3.ZERO  # x, y centre, z circumradius
var _text_px := 16
var _tip_i := 0
var _tip_t := 0.0
var _spin := 0.0
var _shot_taken := false
var _closing := false
static var _paused_before := false

static func headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func active() -> bool:
	return current != null and is_instance_valid(current) and not current.is_queued_for_deletion() and not current._closing

## Opens (or retitles) the overlay. Returns at once; `await faded_in()` waits for the fade. An overlay
## still fading out (the boot one lifting off as the tutorial load starts) comes back instead of a second.
static func open(title: String) -> LoadingScreen:
	shown.append(title)
	if shown.size() > 32:
		shown.remove_at(0)
	if current != null and is_instance_valid(current) and current.is_inside_tree():
		if current._closing:
			current._closing = false
			current.progress = 0.0
			current.set_progress(0.0, "Getting ready")
		current.set_title(title)
		return current
	draws = 0
	draw_cost_us = 0
	var tree := Engine.get_main_loop() as SceneTree
	var ls := LoadingScreen.new()
	tree.root.add_child(ls)
	ls.set_title(title)
	current = ls
	return ls

## The work behind a transition, under the overlay. `work` runs once, synchronously.
static func run(title: String, work: Callable) -> void:
	var ls := open(title)
	await ls.faded_in()
	work.call()
	if is_instance_valid(ls):
		await ls.finish()

## The island build passed a PerfTrace mark. One bool check when no overlay is up.
static func stage(phase: String) -> void:
	if current == null or not STAGES.has(phase) or not is_instance_valid(current):
		return
	var row: Array = STAGES[phase]
	current.set_progress(float(row[0]), str(row[1]))
	# At most one forced frame per DRAW_GAP_MS: the bar reads as moving, the build pays a few frames.
	var now := Time.get_ticks_msec()
	if not headless() and now - _drawn_ms >= DRAW_GAP_MS:
		_drawn_ms = now
		var t0 := Time.get_ticks_usec()
		RenderingServer.force_draw(true, 0.0)
		draw_cost_us += Time.get_ticks_usec() - t0
		draws += 1
		current._dev_shot()

static func tips() -> Array[String]:
	if _tips.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH))
		if parsed is Dictionary:
			_rotate_s = maxf(1.0, float((parsed as Dictionary).get("rotate_s", 4.5)))
			for row in (parsed as Dictionary).get("tips", []):
				if row is Dictionary and str((row as Dictionary).get("text", "")) != "":
					_tips.append(str((row as Dictionary)["text"]))
		if _tips.is_empty():
			push_error("[loading] %s has no tips" % TIPS_PATH)
	return _tips

# ---------------------------------------------------------------- instance

func _init() -> void:
	name = "LoadingScreen"
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "LoadingRoot"
	_root.theme = SheetChrome.ui_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # no click or touch reaches the HUD or the world
	add_child(_root)
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = UiTokens.HEADER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_hexes = Control.new()
	_hexes.name = "HexMotif"
	_hexes.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hexes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hexes.draw.connect(_draw_lattice)
	_root.add_child(_hexes)
	_title = SheetChrome.label("", 40, UiTokens.TEXT, true)
	_title.name = "LoadingTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)
	_tip = SheetChrome.label("", 18, UiTokens.TEXT, false, true)
	_tip.name = "LoadingTip"
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_tip)
	_live = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_live, _root.get_canvas_item())
	RenderingServer.canvas_item_set_z_index(_live, 1)
	var all := tips()
	_tip_i = randi() % maxi(1, all.size())
	_tip.text = all[_tip_i] if not all.is_empty() else ""
	_root.modulate.a = 0.0 if not headless() else 1.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _live.is_valid():
		RenderingServer.free_rid(_live)

func _ready() -> void:
	var tree := get_tree()
	_paused_before = tree.paused
	tree.paused = true  # nothing in the world runs (movement polls, AI, clocks) while it loads
	get_viewport().size_changed.connect(_layout)
	_layout()

func _exit_tree() -> void:
	if current == self:
		current = null
	var tree := get_tree()
	if tree:
		tree.paused = _paused_before

## Every input event stops here while the overlay is up: keys, pads and the touch layer's presses.
func _input(event: InputEvent) -> void:
	if event != null:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# The fades: in while it loads, out once finished (a revived overlay turns back up).
	_root.modulate.a = move_toward(_root.modulate.a, 0.0 if _closing else 1.0, delta / FADE_S)
	if _closing and _root.modulate.a <= 0.0:
		_free_now()
		return
	_spin += delta
	_paint()
	var all := tips()
	_tip_t += delta
	if _tip_t >= _rotate_s and all.size() > 1:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % all.size()
		_tip.text = all[_tip_i]

func set_title(t: String) -> void:
	_title.text = t

func set_progress(frac: float, what: String = "") -> void:
	progress = maxf(progress, clampf(frac, 0.0, 1.0))  # a bar never runs backwards
	last_progress = progress
	if what != "":
		stage_text = what
	_spin += 0.35  # each stage turns the emblem a notch even while the build holds the frame
	_paint()

func tip_text() -> String:
	return _tip.text

## Waits for the fade-in plus one drawn frame (the overlay is on screen before the work starts).
func faded_in() -> void:
	if headless():
		return
	while is_inside_tree() and _root.modulate.a < 1.0:
		await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame

## Fills the bar, fades out and frees the overlay. Returns once it is gone, or revived by open().
func finish() -> void:
	set_progress(1.0, "Ready")
	if draws > 0:
		print("[loading] %s: %d forced frames, %.0f ms" % [_title.text, draws, float(draw_cost_us) / 1000.0])
	_closing = true
	if headless() or not is_inside_tree():
		_free_now()
		return
	while _closing and is_inside_tree():
		await get_tree().process_frame

func _free_now() -> void:
	if current == self:
		current = null
	# Out of the tree now (unpauses in _exit_tree), not at the frame's end: code after a headless
	# run() sees the world running again in the same frame, exactly as before the overlay existed.
	if get_parent():
		get_parent().remove_child(self)
	queue_free()

## Dev: `-- --loading-shot=<png>` saves the first forced frame past half way and quits once the
## overlay is gone (windowed screenshot runs; never in play).
func _dev_shot() -> void:
	if progress < 0.5 or _shot_taken:
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--loading-shot="):
			_shot_taken = true
			get_viewport().get_texture().get_image().save_png(a.substr(15))
			print("[loading] shot %s at %.2f" % [a.substr(15), progress])
			tree_exited.connect(func () -> void: (Engine.get_main_loop() as SceneTree).quit(0))

func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var safe := UiTokens.safe_insets(get_viewport())  # x right, y bottom, z top, w left
	var compact := UiTokens.is_compact(view)
	var side := SheetChrome.SIDE_PHONE if compact else 96.0
	var left := safe.w + side
	var w := view.x - left - safe.x - side
	_title.add_theme_font_size_override("font_size", 28 if compact else 44)
	_tip.add_theme_font_size_override("font_size", 15 if compact else 20)
	_text_px = UiTokens.body(view)
	var mid := safe.z + (view.y - safe.z - safe.y) * (0.40 if compact else 0.42)
	_title.position = Vector2(left, mid - (40.0 if compact else 64.0))
	_title.size = Vector2(w, 48.0 if compact else 60.0)
	var bar_w := minf(w, 760.0)
	var bx := safe.w + (view.x - safe.w - safe.x - bar_w) * 0.5
	var by := mid + (28.0 if compact else 40.0)
	_bar_rect = Rect2(bx, by, bar_w, 8.0)
	var er := 26.0 if compact else 38.0
	_emblem = Vector3(view.x * 0.5 + (safe.w - safe.x) * 0.5, _title.position.y - er - (8.0 if compact else 18.0), er)
	var tip_h := 64.0 if compact else 80.0
	_tip.position = Vector2(bx, view.y - safe.y - tip_h - (16.0 if compact else 56.0))
	_tip.size = Vector2(bar_w, tip_h)
	_hexes.queue_redraw()
	_paint()

## The live parts, immediately: bar track and GOLD fill, stage line and percent, and the flat-top hex
## emblem whose lit edge walks round as the build moves.
func _paint() -> void:
	if not _live.is_valid():
		return
	var rs := RenderingServer
	rs.canvas_item_clear(_live)
	var r := _bar_rect
	rs.canvas_item_add_rect(_live, r, Color(1, 1, 1, 0.14))
	rs.canvas_item_add_rect(_live, Rect2(r.position, Vector2(r.size.x * progress, r.size.y)), UiTokens.GOLD)
	var base := r.position.y - 10.0
	UiTokens.ui_face().draw_string(_live, Vector2(r.position.x, base), stage_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.8, _text_px, UiTokens.META)
	UiTokens.ui_face(UiTokens.WEIGHT_BOLD).draw_string(_live, Vector2(r.position.x, base), "%d%%" % int(round(progress * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, _text_px, UiTokens.GOLD)
	var c := Vector2(_emblem.x, _emblem.y)
	var er := _emblem.z
	var ring := UiTokens.hex_points(c, er, UiTokens.HEX_FLAT_TOP)
	rs.canvas_item_add_polygon(_live, ring, [Color(UiTokens.HUD_FILL, 1.0)])
	var closed := ring.duplicate()
	closed.append(ring[0])
	rs.canvas_item_add_polyline(_live, closed, [Color(UiTokens.HUD_RIM, 0.35)], 2.0, true)
	var lit := int(floor(_spin * 3.0)) % 6
	for k in 2:
		var i := (lit + k) % 6
		rs.canvas_item_add_line(_live, ring[i], ring[(i + 1) % 6], UiTokens.GOLD, 4.0, true)
	rs.canvas_item_add_polygon(_live, UiTokens.hex_points(c, er * 0.46, UiTokens.HEX_FLAT_TOP), [Color(UiTokens.GOLD, 0.25 + 0.75 * progress)])

## The faint flat-top hex lattice behind everything.
func _draw_lattice() -> void:
	var view := _hexes.size
	var r := 34.0 if UiTokens.is_compact(view) else 52.0
	var dx := r * 1.5
	var dy := r * sqrt(3.0)
	var faint := Color(UiTokens.HUD_RIM, 0.035)
	for col in int(view.x / dx) + 2:
		for row in int(view.y / dy) + 2:
			var cy := float(row) * dy + (dy * 0.5 if col % 2 == 1 else 0.0)
			var pts := UiTokens.hex_points(Vector2(float(col) * dx, cy), r * 0.96, UiTokens.HEX_FLAT_TOP)
			pts.append(pts[0])
			_hexes.draw_polyline(pts, faint, 1.5, true)
