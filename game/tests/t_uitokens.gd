extends SceneTree
## UITOKENS: the hex-HUD token palette, the one hex geometry source, the pie sector, trait chips,
## selection brackets, the torn header edge, and the new HexButton fields.
## Owner decision 2026-10-28: hexes are FLAT-TOP globally (UiTokens.HEX_FLAT_TOP), so a HexButton's
## defaults draw a flat-top hex; pointy-top stays reachable per hex and must still match the old maths.
## Run: Godot --headless --path game --script res://tests/t_uitokens.gd -> "[t_uitokens] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const WATCHDOG_S := 60.0

var _fails: PackedStringArray = []
var _started := false
var _elapsed := 0.0
var UT: GDScript
var HB: GDScript
var _host: Node

func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > WATCHDOG_S:
		print("[t_uitokens] FAIL watchdog: %.0f s without finishing" % _elapsed)
		quit(1)
		return true
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_uitokens] FAIL %s" % what)

func _run() -> void:
	UT = load("res://scripts/ui/ui_tokens.gd")
	HB = load("res://scripts/ui/hex_button.gd")
	_host = Node.new()
	root.add_child(_host)
	_test_palette()
	_test_hex_points()
	_test_hex_radius_at()
	_test_pie()
	_test_chips()
	_test_brackets()
	_test_fonts()
	_test_header_and_torn()
	_test_hex_rect_maths()
	await _test_hex_button_defaults()
	await _test_hex_button_fields()
	await _test_key_hint()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_uitokens] PASS")
		quit(0)
	else:
		print("[t_uitokens] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- tokens (§2)

func _test_palette() -> void:
	_expect(UT.HUD_FILL == Color(0.039, 0.047, 0.047, 0.92), "HUD_FILL is the spec's colour")
	_expect(UT.HUD_RIM == Color(0.933, 0.945, 0.949, 0.85), "HUD_RIM is the spec's colour")
	_expect(UT.HEADER == Color(0.027, 0.031, 0.035, 1.0), "HEADER is the spec's colour")
	_expect(UT.SCREEN_DIM == Color(0.063, 0.165, 0.243, 0.55), "SCREEN_DIM is the spec's colour")
	_expect(UT.PANEL == Color(0.055, 0.118, 0.173, 0.82), "PANEL is the spec's colour")
	_expect(UT.GOLD == Color(0.957, 0.769, 0.188, 1.0), "GOLD is the spec's colour")
	_expect(UT.GOLD_DIM == Color(0.957, 0.769, 0.188, 0.12), "GOLD_DIM is the spec's colour")
	_expect(UT.CTA_INK == Color(0.078, 0.071, 0.047, 1.0), "CTA_INK is the spec's colour")
	_expect(UT.PARCHMENT_TOP == Color(0.804, 0.722, 0.541, 1.0), "PARCHMENT_TOP is the spec's colour")
	_expect(UT.PARCHMENT_BOTTOM == Color(0.706, 0.620, 0.424, 1.0), "PARCHMENT_BOTTOM is the spec's colour")
	_expect(UT.PARCHMENT_INK == Color(0.102, 0.090, 0.063, 1.0), "PARCHMENT_INK is the spec's colour")
	_expect(UT.OK_GREEN == Color(0.373, 0.827, 0.416, 1.0), "OK_GREEN is the spec's colour")
	_expect(UT.LIFE == Color(0.847, 0.314, 0.227, 1.0), "LIFE is the spec's colour")
	_expect(UT.ENERGY == Color(0.373, 0.659, 0.816, 1.0), "ENERGY is the spec's colour")
	_expect(UT.XP == Color(0.561, 0.816, 0.910, 1.0), "XP is the spec's colour")
	_expect(UT.MUTED == Color(0.604, 0.651, 0.678, 1.0), "MUTED is the spec's colour")
	# Existing constants other screens use must survive the addition.
	_expect(UT.TEAL == Color(0.20, 0.78, 0.74, 1.0) and UT.INK.a > 0.9 and UT.SPACE == 8 and UT.RADIUS == 12, "existing tokens kept")
	_expect(UT.HEX_FLAT_TOP, "HEX_FLAT_TOP is flat-top (owner decision 2026-10-28)")
	_expect(UT.MOOD.size() == 4, "MOOD has the four exhaustion tiers (%d)" % UT.MOOD.size())
	for i in [0, 1, 2, 3]:
		_expect(UT.MOOD[i] is Color, "MOOD[%d] is a colour" % i)
	if UT.MOOD.size() == 4:
		_expect(UT.MOOD[0] == Color(0.561, 0.863, 0.518), "MOOD[0] (fresh) is the spec's green")
		_expect(UT.MOOD[3] == Color(0.878, 0.412, 0.310), "MOOD[3] (exhausted) is the spec's red")
		var distinct := {}
		for c in UT.MOOD:
			distinct[c] = true
		_expect(distinct.size() == 4, "the four mood tints differ")
	print("[t_uitokens] palette: MOOD=%d, flat_top=%s" % [UT.MOOD.size(), UT.HEX_FLAT_TOP])

# ---------------------------------------------------------------- hex geometry (§2)

func _test_hex_points() -> void:
	var c := Vector2(100.0, 50.0)
	var r := 36.0
	for flat in [true, false]:
		var pts: PackedVector2Array = UT.hex_points(c, r, flat)
		_expect(pts.size() == 6, "hex_points(%s) gives 6 points (%d)" % ["flat" if flat else "pointy", pts.size()])
		for p in pts:
			_expect(absf(p.distance_to(c) - r) < 0.001, "hex_points(%s) corner %.3f px from centre (r %.1f)" % ["flat" if flat else "pointy", p.distance_to(c), r])
		# Flat-top has corners left/right (y == centre); pointy-top has corners top/bottom (x == centre).
		var on_x := 0
		var on_y := 0
		for p in pts:
			on_x += 1 if absf(p.y - c.y) < 0.001 else 0
			on_y += 1 if absf(p.x - c.x) < 0.001 else 0
		if flat:
			_expect(on_x == 2, "flat-top has two corners level with its centre (%d)" % on_x)
		else:
			_expect(on_y == 2, "pointy-top has two corners above/below its centre (%d)" % on_y)
	# Pointy-top is the old formula: 60*i - 30 degrees.
	var old := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)
		old.append(c + Vector2(cos(a), sin(a)) * r)
	var pointy: PackedVector2Array = UT.hex_points(c, r, false)
	var same := pointy.size() == old.size()
	for i in mini(pointy.size(), old.size()):
		same = same and pointy[i].distance_to(old[i]) < 0.0001
	_expect(same, "hex_points(flat_top=false) reproduces the old pointy-top corners")
	var flat_pts: PackedVector2Array = UT.hex_points(c, r, true)
	_expect(absf(UT.polygon_area(flat_pts) - 3.0 * sqrt(3.0) * 0.5 * r * r) < 0.5, "the hex's area is 3*sqrt(3)/2 r^2")
	print("[t_uitokens] hex_points: flat width %.2f, pointy width %.2f" % [flat_pts[0].x - c.x, pointy[1].x - pointy[5].x if pointy.size() == 6 else 0.0])

func _test_hex_radius_at() -> void:
	var r := 40.0
	var apothem := r * cos(PI / 6.0)
	for flat in [true, false]:
		var angles: PackedFloat32Array = UT.hex_vertex_angles(flat)
		for va in angles:
			var d: float = UT.hex_radius_at(va, r, flat)
			_expect(absf(d - r) < 0.01, "%s vertex angle %.1f deg is at r (%.3f vs %.1f)" % ["flat" if flat else "pointy", rad_to_deg(va), d, r])
			var mid := va + PI / 6.0  # next corner's midpoint: the edge's middle
			var e: float = UT.hex_radius_at(mid, r, flat)
			_expect(absf(e - apothem) < 0.01, "%s edge midpoint (%.1f deg) is at the apothem (%.3f vs %.3f)" % ["flat" if flat else "pointy", rad_to_deg(mid), e, apothem])
		var lo := INF
		var hi := 0.0
		for k in 720:
			var d: float = UT.hex_radius_at(TAU * float(k) / 720.0, r, flat)
			lo = minf(lo, d)
			hi = maxf(hi, d)
		_expect(lo >= apothem - 0.01 and hi <= r + 0.01, "%s radius stays between the apothem and r (%.3f..%.3f)" % ["flat" if flat else "pointy", lo, hi])
	print("[t_uitokens] hex_radius_at: r=%.1f apothem=%.3f" % [r, apothem])

# ---------------------------------------------------------------- the pie sector (§4)

func _test_pie() -> void:
	var c := Vector2(64.0, 64.0)
	var r := 30.0
	var hex_area := 3.0 * sqrt(3.0) * 0.5 * r * r
	for flat in [true, false]:
		var tag: String = "flat" if flat else "pointy"
		# f = 1 is the whole hex, within 1 %.
		var full: PackedVector2Array = UT.pie_points(c, r, 1.0, flat)
		var full_area: float = UT.polygon_area(full)
		_expect(absf(full_area - hex_area) <= hex_area * 0.01, "%s pie at f=1 covers the hex (%.2f vs %.2f, %.2f%%)" % [tag, full_area, hex_area, absf(full_area - hex_area) / hex_area * 100.0])
		# Every boundary point lies on the hex edge, and the sweep is sampled every <= 6 degrees.
		var prev := -PI * 0.5
		var worst := 0.0
		for i in range(1, full.size()):
			var a: float = atan2(full[i].y - c.y, full[i].x - c.x)
			var sweep := a - prev
			while sweep < -0.0001:
				sweep += TAU
			worst = maxf(worst, sweep)
			prev = a
		_expect(worst <= deg_to_rad(6.0) + 0.02, "%s pie samples every <= 6 deg (worst gap %.2f deg)" % [tag, rad_to_deg(worst)])
		# Area grows with f, monotonically.
		var last := 0.0
		var mono := true
		for k in range(1, 41):
			var f := float(k) / 40.0
			var area: float = UT.polygon_area(UT.pie_points(c, r, f, flat))
			mono = mono and area > last
			last = area
		_expect(mono, "%s pie area grows with f at every step" % tag)
		# Vertices inside the sweep are used exactly (the polygon reaches r there).
		var half_r: float = 0.0
		var on_vertex := 0
		for p in UT.pie_points(c, r, 0.75, flat):
			half_r = maxf(half_r, p.distance_to(c))
			for va in UT.hex_vertex_angles(flat):
				var a: float = float(va) - PI * 0.5
				var swept := fposmod(a, TAU)
				if swept <= TAU * 0.75 and absf(p.distance_to(c) - r) < 0.05:
					on_vertex += 1
					break
		_expect(on_vertex >= 4, "%s pie at f=0.75 passes its hex vertices (reached r %d times)" % [tag, on_vertex])
		_expect(half_r <= r + 0.01, "%s pie never reaches past the hex edge (%.3f <= %.1f)" % [tag, half_r, r])
		_expect(UT.pie_points(c, r, 0.0, flat).size() < 3, "%s pie at f=0 draws no sector" % tag)
	print("[t_uitokens] pie: f=1 area %.2f vs hex %.2f" % [UT.polygon_area(UT.pie_points(c, r, 1.0, true)), hex_area])

# ---------------------------------------------------------------- trait chips (§5)

func _test_chips() -> void:
	var neg: StyleBoxFlat = UT.trait_chip_style(&"negative")
	var pos: StyleBoxFlat = UT.trait_chip_style(&"positive")
	var rare: StyleBoxFlat = UT.trait_chip_style(&"rare")
	_expect(neg.bg_color == UT.TRAIT_NEG_BG, "negative chip bg is the grey token")
	_expect(pos.bg_color == UT.TRAIT_POS_BG, "positive chip bg is the yellow token")
	_expect(rare.bg_color == UT.TRAIT_RARE_BG, "rare chip bg is the green token")
	_expect(neg.bg_color != pos.bg_color and pos.bg_color != rare.bg_color and neg.bg_color != rare.bg_color, "the three chip backgrounds are distinct")
	_expect(pos.border_color == UT.GOLD and rare.border_color == UT.TRAIT_RARE_FG and neg.border_color == UT.TRAIT_NEG_FG, "chip borders use their fg tokens")
	for sb: StyleBoxFlat in [neg, pos, rare]:
		_expect(sb.corner_radius_top_left == 0 and sb.corner_radius_bottom_right == 0, "chips are square (0 radius)")
		_expect(is_equal_approx(sb.content_margin_top, 3.0) and is_equal_approx(sb.content_margin_bottom, 3.0), "chip padding is 3 px top/bottom")
		_expect(is_equal_approx(sb.content_margin_left, 8.0) and is_equal_approx(sb.content_margin_right, 8.0), "chip padding is 8 px left/right")
	_expect(UT.trait_chip_prefix(&"negative") == "−" and UT.trait_chip_prefix(&"positive") == "+" and UT.trait_chip_prefix(&"rare") == String.chr(0x2726), "colour-blind prefixes are − + ✦")
	_expect(UT.trait_chip_fg(&"positive") == UT.GOLD and UT.trait_chip_fg(&"rare") == UT.TRAIT_RARE_FG, "chip text colours follow the polarity")
	_expect(neg.bg_color == UT.trait_chip_style(&"unknown").bg_color, "an unknown polarity reads as negative")
	print("[t_uitokens] chips: neg %s pos %s rare %s" % [neg.bg_color, pos.bg_color, rare.bg_color])

# ---------------------------------------------------------------- type (§2)

## The UI face (owner decision 2026-10-28): constants name the file; the helper builds a 400 and a 700
## FontVariation from it. The TTF is an asset change of its own and may not be in this tree yet, in
## which case the helper must answer null rather than fail.
func _test_fonts() -> void:
	_expect(UT.UI_FONT_PATH == "res://assets/fonts/RobotoCondensed-Variable.ttf", "UI_FONT_PATH names the Roboto Condensed variable TTF")
	_expect(UT.WEIGHT_REGULAR == 400 and UT.WEIGHT_BOLD == 700, "the two weights are 400 and 700")
	var regular: Variant = UT.ui_font_regular()
	var bold: Variant = UT.ui_font_bold()
	var present := ResourceLoader.exists(UT.UI_FONT_PATH)
	print("[t_uitokens] fonts: %s present=%s" % [UT.UI_FONT_PATH, present])
	if present:
		_expect(regular is FontVariation and bold is FontVariation, "both weights are FontVariations")
		if regular is FontVariation and bold is FontVariation:
			_expect(regular.base_font != null and regular.base_font == bold.base_font, "both share the one base font")
			_expect(int((regular.variation_opentype as Dictionary).get("wght", 0.0)) == 400, "regular is wght 400")
			_expect(int((bold.variation_opentype as Dictionary).get("wght", 0.0)) == 700, "bold is wght 700")
			_expect(UT.ui_font(UT.WEIGHT_BOLD) == bold, "the variations are cached per weight")
			_expect(UT.ui_face() is FontVariation, "ui_face() hands back the UI font when it is there")
			var w400: float = regular.get_string_size("Bleed", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			_expect(w400 > 0.0, "the regular face measures text (%.1f px)" % w400)
	else:
		_expect(regular == null and bold == null, "without the TTF the helpers answer null, they do not fail")
		_expect(UT.ui_face() == ThemeDB.fallback_font, "ui_face() falls back to the engine font when the TTF is absent")

# ---------------------------------------------------------------- chrome (§8)

func _test_brackets() -> void:
	var rect := Rect2(10.0, 20.0, 100.0, 60.0)
	var segs: Array[Vector2] = UT.bracket_segments(rect, 18.0)
	_expect(segs.size() == 16, "four brackets are eight segments (%d endpoints)" % segs.size())
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]
	for corner: Vector2 in corners:
		var hits := 0
		for i in range(0, segs.size(), 2):
			var a := segs[i]
			var b := segs[i + 1]
			var on_a := a.distance_to(corner) < 0.01
			var on_b := b.distance_to(corner) < 0.01
			hits += 1 if on_a != on_b else 0  # one end at the corner
			_expect(a == rect.position.clamp(a, rect.end) and b == rect.position.clamp(b, rect.end), "bracket segment stays inside the rect")
		_expect(hits == 2, "every corner joins its bracket's two arms (%d at %s)" % [hits, corner])
	for i in range(0, segs.size(), 2):
		_expect(absf(segs[i].distance_to(segs[i + 1]) - 18.0) < 0.01, "bracket arms are 18 px")
	var small: Array[Vector2] = UT.bracket_segments(Rect2(0, 0, 20, 10), 18.0)
	_expect(absf(small[0].distance_to(small[1]) - 5.0) < 0.01, "on a small rect the arm is capped at half the short side (%.1f)" % small[0].distance_to(small[1]))
	print("[t_uitokens] brackets: %d endpoints, arm 18" % segs.size())

func _test_header_and_torn() -> void:
	var hs: StyleBoxFlat = UT.header_style()
	_expect(hs.bg_color == UT.HEADER, "the header bar is the HEADER token")
	_expect(hs.corner_radius_top_left == 0, "the header bar is square")
	var rect := Rect2(0.0, 0.0, 1600.0, 88.0)
	var zig: PackedVector2Array = UT.torn_edge_points(rect, 12.0, 16.0)
	_expect(zig.size() > 2, "the torn edge has teeth (%d points)" % zig.size())
	var lo := INF
	var hi := -INF
	var first := INF
	var last := -INF
	for p in zig:
		lo = minf(lo, 88.0 - p.y)
		hi = maxf(hi, 88.0 - p.y)
		first = minf(first, p.x)
		last = maxf(last, p.x)
	_expect(lo >= -0.01 and hi <= 12.01, "teeth are 0-12 px deep (%.2f..%.2f)" % [lo, hi])
	_expect(first == 0.0 and absf(last - 1600.0) < 0.01, "the torn edge spans the header (%s..%s)" % [first, last])
	_expect(zig != UT.torn_edge_points(Rect2(0.0, 0.0, 800.0, 88.0), 12.0, 16.0), "a different width tears differently")
	var again: PackedVector2Array = UT.torn_edge_points(rect, 12.0, 16.0)
	_expect(zig == again, "the torn edge is stable across redraws")
	print("[t_uitokens] torn edge: %d points, depth %.1f..%.1f px" % [zig.size(), lo, hi])

## The flat-top box: 2r wide, sqrt(3)r tall (the old pointy box the other way round).
func _test_hex_rect_maths() -> void:
	var b: Control = HB.new(64.0)
	_host.add_child(b)
	b.position = Vector2(100.0, 100.0)
	var r: float = minf(b.size.x, b.size.y) * 0.5 - 2.0
	var box: Rect2 = b.call("hex_rect")
	_expect(absf(box.size.x - r * 2.0) < 0.01, "flat-top hex_rect is 2r wide (%.2f vs %.2f)" % [box.size.x, r * 2.0])
	_expect(absf(box.size.y - r * 1.732) < 0.01, "flat-top hex_rect is sqrt(3)r tall (%.2f)" % box.size.y)
	b.flat_top = false
	_expect(absf((b.call("hex_rect") as Rect2).size.x - r * 1.732) < 0.01, "pointy-top hex_rect is sqrt(3)r wide")
	b.queue_free()

# ---------------------------------------------------------------- HexButton (§3)

func _test_hex_button_defaults() -> void:
	var b: Control = HB.new(64.0)
	_host.add_child(b)
	await process_frame
	var r := 30.0
	var c := Vector2(32.0, 32.0)
	_expect(b.flat_top == UT.HEX_FLAT_TOP, "a HexButton's flat_top defaults to UiTokens.HEX_FLAT_TOP")
	_expect(b.rim_width == 2.0 and b.rim_color.a == 0.0, "default rim: 2 px, following `accent` (today's look)")
	_expect(b.fill_ratio == 0.0 and not b.icon_grey and b.key_hint == "", "fill_ratio, icon_grey and key_hint default to off")
	var got: PackedVector2Array = b.call("_hex", r, c)
	var want: PackedVector2Array = UT.hex_points(c, r, true)
	_expect(got.size() == want.size(), "default hex has 6 corners")
	var same := got.size() == want.size()
	for i in mini(got.size(), want.size()):
		same = same and got[i].distance_to(want[i]) < 0.0001
	_expect(same, "a default HexButton draws UiTokens.hex_points(flat_top=true)")
	# Pointy-top still reproduces the old _hex() maths exactly.
	b.flat_top = false
	var pointy: PackedVector2Array = b.call("_hex", r, c)
	var old := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)
		old.append(c + Vector2(cos(a), sin(a)) * r)
	var old_same := pointy.size() == old.size()
	for i in mini(pointy.size(), old.size()):
		old_same = old_same and pointy[i].distance_to(old[i]) < 0.0001
	_expect(old_same, "flat_top=false gives back the old pointy-top polygon")
	# Flat-top corners: two level with the centre, none above/below it.
	var level := 0
	var above := 0
	for p in got:
		level += 1 if absf(p.y - c.y) < 0.001 else 0
		above += 1 if absf(p.x - c.x) < 0.001 else 0
	_expect(level == 2 and above == 0, "the default hex is flat-top (2 level corners, %d vertical)" % above)
	print("[t_uitokens] HexButton default: flat-top %s, rim %.0f px" % [b.flat_top, b.rim_width])
	b.queue_free()

func _test_hex_button_fields() -> void:
	var b: Control = HB.new(64.0)
	_host.add_child(b)
	await process_frame
	# A two-colour icon: greyed only when icon_grey asks, and the copy is actually grey.
	var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.2, 0.1, 1.0))
	var tex := ImageTexture.create_from_image(img)
	b.icon = tex
	b.color_icon = true
	_expect(b.call("drawn_icon") == tex, "without icon_grey the icon draws unchanged")
	var fill_was: Color = b.fill
	var rim_was: Color = b.accent
	b.fill_ratio = 0.5
	_expect(b.fill == fill_was and b.accent == rim_was, "fill_ratio leaves the hex fill and rim alone")
	_expect(b.cooldown == 0.0, "fill_ratio is separate from the cooldown sweep")
	b.icon_grey = true
	var grey: Texture2D = b.call("drawn_icon")
	_expect(grey != tex and grey != null, "icon_grey swaps in a grey copy")
	if grey:
		var px := grey.get_image().get_pixel(4, 4)
		_expect(absf(px.r - px.g) < 0.01 and absf(px.g - px.b) < 0.01, "the grey copy is desaturated (%s)" % px)
		_expect(absf(px.a - 1.0) < 0.01, "the grey copy keeps its alpha")
		_expect(b.call("drawn_icon") == grey, "the grey copy is cached per texture")
	_expect(b.fill == fill_was and b.accent == rim_was, "icon_grey leaves the hex fill and rim alone")
	_expect(b.call("drawn_icon") != null, "the drawn icon is never dropped")
	# rim_color/rim_width are just values the draw reads; the default still follows `accent`.
	b.rim_color = UT.HUD_RIM
	b.rim_width = 4.0
	_expect(b.rim_color == UT.HUD_RIM and b.rim_width == 4.0, "rim_color and rim_width are settable")
	# The white-symbol path still gets the shader material and no grey copy.
	var white := Control.new()
	b.queue_free()
	white.free()
	print("[t_uitokens] fields: fill_ratio/icon_grey leave fill and rim untouched")

func _test_key_hint() -> void:
	var b: Control = HB.new(64.0)
	_host.add_child(b)
	b.key_hint = "Esc"
	var was_size := root.size
	var was_scale := root.content_scale_size
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	await process_frame
	_expect(b.call("key_visible"), "on desktop a key hint draws")
	var kr: Rect2 = b.call("key_rect")
	_expect(kr.position.x > b.size.x * 0.5 and kr.position.y < b.size.y * 0.5, "the key cap sits at the hex's top-right (%s)" % kr)
	_expect(kr.end.y <= b.size.y * 0.5, "the key cap stays in the hex's top half")
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	b.queue_free()
	var b2: Control = HB.new(64.0)
	_host.add_child(b2)
	b2.key_hint = "Esc"
	await process_frame
	_expect(UiTokens.is_compact(Vector2(844, 390)), "844x390 is a landscape phone to UiTokens")
	_expect(not b2.call("key_visible"), "on a phone (844x390) the key hint is hidden")
	var phone_hidden: bool = not b2.call("key_visible")
	root.size = was_size
	root.content_scale_size = was_scale
	b2.queue_free()
	print("[t_uitokens] key hint: hidden on a phone %s" % phone_hidden)
