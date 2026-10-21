class_name SailChart
extends Control
## The sea under the Sail chart (SailScreen): Home Lv. 10 on the left, then one vertical band per
## island level, each headed "Lv. N" and darker than the one before, with dashed sea lanes between
## neighbouring levels, wave strokes, a compass rose, Home's island shape and slowly drifting clouds.
## It also places the SailNodes: x strictly grows with the level (two islands of one level share
## their band, one above the other), so the whole sea scrolls to the right.

const SHALLOW := Color("#6E9EA6")
const DEEP := Color("#0F1F2E")
## Shares of the view width. Home plus five level bands fit one view, so Home and 5 islands show
## at 1600 and at 844 px, and the ten bands make the sea a little over twice the view.
const HOME_FRAC := 0.22
const BAND_FRAC := 0.19
const TAIL_FRAC := 0.06
const BAND_MIN := 120.0 ## keeps nodes at least 64 px wide on very narrow canvases
const TAN := Color("#CAAD69")
const SEED := 15

var home_w := 0.0
var band_w := 0.0
var bands: Array[Dictionary] = [] ## {tier, x, w}
var _m: Dictionary = {}
var _label_h := 0.0
var _lanes: Array[PackedVector2Array] = []
var _waves: PackedVector2Array = PackedVector2Array()
var _clouds: Array[Vector3] = [] ## x, y, scale
var _home_shape := PackedVector2Array()
var _t := 0.0

## Lays the sea out for a `view`-sized window (SailScreen.metrics() `m`) and adds one SailNode per
## entry (SailScreen._entries()); returns them in entry order.
func build(entries: Array[Dictionary], view: Vector2, m: Dictionary) -> Array[SailNode]:
	_m = m
	mouse_filter = Control.MOUSE_FILTER_PASS
	home_w = roundf(maxf(view.x * HOME_FRAC, BAND_MIN))
	band_w = roundf(maxf(view.x * BAND_FRAC, BAND_MIN))
	var tiers: Array[int] = []
	var home_tier := 10
	for e in entries:
		if bool(e.home):
			home_tier = int(e.tier)
		elif not tiers.has(int(e.tier)):
			tiers.append(int(e.tier))
	tiers.sort()
	size = Vector2(home_w + band_w * float(tiers.size()) + roundf(view.x * TAIL_FRAC), view.y)
	bands = [{"tier": home_tier, "x": 0.0, "w": home_w}]
	for i in tiers.size():
		bands.append({"tier": tiers[i], "x": home_w + band_w * float(i), "w": band_w})
	_label_h = float(int(m.band_px)) * 1.9
	var free := view.y - _label_h
	var w := minf(band_w - 24.0, float(m.node_w))
	var h := SailNode.height_for(m)
	var made: Array[SailNode] = []
	var by_band: Array = []
	for b in bands:
		by_band.append([])
	for e in entries:
		var n := SailNode.new()
		n.setup(e, m)
		n.size = Vector2(w, h)
		add_child(n)
		made.append(n)
		var bi := 0 if bool(e.home) else tiers.find(int(e.tier)) + 1
		(by_band[bi] as Array).append(n)
	for bi in bands.size():
		var group: Array = by_band[bi]
		var cx: float = float(bands[bi].x) + float(bands[bi].w) * 0.5
		var k := group.size()
		if k == 1:
			# One island: a gentle up/down wave from band to band, like a route across the chart.
			var wave := 0.0 if bi == 0 else (free - h) * 0.16 * (1.0 if bi % 2 == 1 else -1.0)
			(group[0] as SailNode).position = Vector2(cx - w * 0.5, _label_h + (free - h) * 0.5 + wave)
		else:
			# shortcut: more than two islands of one level would need a wider band; the data has two at most.
			var gap := (free - h * float(k)) / float(k + 1)
			for j in k:
				var stagger := band_w * 0.08 * (float(j) - float(k - 1) * 0.5)
				(group[j] as SailNode).position = Vector2(cx - w * 0.5 + stagger, _label_h + gap + (gap + h) * float(j))
	_lanes.clear()
	for bi in range(1, bands.size()):
		for a in by_band[bi - 1]:
			for b in by_band[bi]:
				_lanes.append(PackedVector2Array([_centre(a), _centre(b)]))
	_scatter(view)
	return made

func _centre(n: SailNode) -> Vector2:
	return n.position + n.disc_center()

## Fixed (seeded) wave strokes, clouds and Home's coastline: the picture never jumps between opens.
func _scatter(view: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_waves.clear()
	for i in int(size.x * size.y / 9000.0):
		_waves.append(Vector2(rng.randf_range(8.0, size.x - 8.0), rng.randf_range(_label_h + 8.0, size.y - 8.0)))
	_clouds.clear()
	for i in int(size.x / 380.0) + 2:
		var top := rng.randf() < 0.5
		var y := rng.randf_range(0.02, 0.14) if top else rng.randf_range(0.86, 0.98)
		_clouds.append(Vector3(rng.randf_range(0.0, size.x), y * size.y, rng.randf_range(0.7, 1.3)))
	# The unknown beyond the last band: a bank of cloud at the far right.
	for i in 5:
		_clouds.append(Vector3(size.x - view.x * TAIL_FRAC * rng.randf_range(0.0, 1.2), size.y * rng.randf_range(0.15, 0.85), rng.randf_range(1.0, 1.6)))
	_home_shape.clear()
	var r := float(_m.d) * 0.98
	for i in 28:
		var a := TAU * float(i) / 28.0
		var wobble := 1.0 + 0.1 * sin(a * 3.0 + 0.6) + 0.06 * sin(a * 7.0) + rng.randf_range(-0.04, 0.04)
		_home_shape.append(Vector2(cos(a) * 1.15, sin(a) * 0.85) * r * wobble)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()  # the clouds drift

func _draw() -> void:
	var n := bands.size()
	var font := SailNode.font()
	var band_px := int(_m.get("band_px", 13))
	for i in n:
		var b: Dictionary = bands[i]
		var col := SHALLOW.lerp(DEEP, float(i) / float(maxi(1, n - 1)))
		draw_rect(Rect2(float(b.x), 0.0, float(b.w), size.y), col)
		if i > 0:
			draw_line(Vector2(float(b.x), 0.0), Vector2(float(b.x), size.y), Color(1, 1, 1, 0.1), 2.0)
	if n > 0:
		var last: Dictionary = bands[n - 1]
		var tail_x := float(last.x) + float(last.w)
		draw_rect(Rect2(tail_x, 0.0, size.x - tail_x, size.y), DEEP.darkened(0.2))
	for p in _waves:
		var s := 7.0 + fmod(p.x, 5.0)
		draw_arc(p, s, PI * 1.15, PI * 1.85, 6, Color(1, 1, 1, 0.12), 1.5, true)
	for lane in _lanes:
		draw_dashed_line(lane[0], lane[1], Color(1, 1, 1, 0.22), 2.0, 9.0, true)
	if not _home_shape.is_empty() and n > 0:
		var hc := Vector2(home_w * 0.5, 0.0)
		for c in get_children():
			if c is SailNode and (c as SailNode).home:
				hc = _centre(c)
		var sand := PackedVector2Array()
		var grass := PackedVector2Array()
		for p in _home_shape:
			sand.append(hc + p * 1.12)
			grass.append(hc + p)
		draw_colored_polygon(sand, Color("#D8C48E"))
		draw_colored_polygon(grass, Color("#6F9A4C"))
	_draw_compass(Vector2(home_w * 0.5, size.y - float(_m.get("compass", 28.0)) - float(_m.get("pad", 8.0))), float(_m.get("compass", 28.0)))
	for cl in _clouds:
		var x := fposmod(cl.x + _t * 6.0 * cl.z, size.x + 160.0) - 80.0
		_draw_cloud(Vector2(x, cl.y), 26.0 * cl.z)
	for b in bands:  # band headings over the clouds
		var label := LevelDisplay.label(int(b.tier))
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, band_px).x
		var at := Vector2(float(b.x) + (float(b.w) - lw) * 0.5, _label_h * 0.72)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, band_px, 4, Color(0, 0, 0, 0.6))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, band_px, TAN)

func _draw_cloud(c: Vector2, s: float) -> void:
	var col := Color(1, 1, 1, 0.22)
	draw_circle(c, s, col)
	draw_circle(c + Vector2(s * 0.9, s * 0.15), s * 0.75, col)
	draw_circle(c + Vector2(-s * 0.9, s * 0.2), s * 0.65, col)
	draw_circle(c + Vector2(s * 0.3, -s * 0.45), s * 0.7, col)

func _draw_compass(c: Vector2, r: float) -> void:
	var line := Color(TAN, 0.75)
	draw_arc(c, r, 0.0, TAU, 40, line, 2.0, true)
	draw_arc(c, r * 0.72, 0.0, TAU, 40, Color(TAN, 0.35), 1.5, true)
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI * 0.5
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var reach := r * (1.05 if i % 2 == 0 else 0.6)
		var wid := r * (0.16 if i % 2 == 0 else 0.1)
		draw_colored_polygon(PackedVector2Array([c, c + side * wid, c + dir * reach]), Color("#ECEBE4") if i == 0 else Color(TAN, 0.9))
		draw_colored_polygon(PackedVector2Array([c, c + dir * reach, c - side * wid]), Color("#8E7A4C"))
	var font := SailNode.font()
	var px := maxi(12, int(r * 0.45))
	var w := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string_outline(font, c + Vector2(-w * 0.5, -r * 1.12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, px, 3, Color(0, 0, 0, 0.6))
	draw_string(font, c + Vector2(-w * 0.5, -r * 1.12), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("#ECEBE4"))
