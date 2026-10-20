extends SceneTree
## W1-UI checks: glyphs and type floor in the UI files W1-UI owns, centred text, radial spacing,
## "Lv —" for unmakeable recipes, the logical canvas, the theme, atlas legend colours, focus.
## Run: godot --headless --path game --script res://tests/t_ui.gd   -> "[t_ui] PASS", exit 0/1.

const OWNED := [
	"res://scripts/core/display_mode.gd", "res://scripts/ui/ui_tokens.gd", "res://scripts/ui/hex_button.gd",
	"res://scripts/ui/status_glyph.gd", "res://scripts/ui/gather_ring.gd", "res://scripts/ui/eat_progress.gd",
	"res://scripts/ui/held_item_slot.gd", "res://scripts/ui/craft_ui.gd", "res://scripts/ui/craft_card.gd",
	"res://scripts/ui/station_menu.gd", "res://scripts/ui/station_radial.gd", "res://scripts/ui/skills_sheet.gd",
	"res://scripts/ui/map_screen.gd", "res://scripts/ui/fatigue_panel.gd", "res://scripts/ui/world_ui.gd",
	"res://scripts/ui/creature_plates.gd", "res://scripts/ui/context_radial.gd", "res://scripts/ui/gather_radial.gd",
	"res://scripts/ui/food_inspector.gd", "res://scripts/ui/pickup_toast.gd", "res://scripts/ui/respawn_ring.gd",
	"res://scripts/ui/character_creation.gd", "res://scripts/ui/level_display.gd", "res://scripts/ui/item_text.gd",
]
const TYPE_MIN := 12

var failures: Array[String] = []
var _done := false
# Scripts that reach autoloads (Data, World, Game) cannot compile while `--script` compiles this
# file, so they are loaded on the first frame, after the autoloads exist (as run_all.gd does).
var UT: GDScript
var CU: GDScript
var MS: GDScript
var LD: GDScript
var LAB: GDScript
var IT: GDScript
var CC: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	UT = load("res://scripts/ui/ui_tokens.gd")
	CU = load("res://scripts/ui/craft_ui.gd")
	MS = load("res://scripts/ui/map_screen.gd")
	LD = load("res://scripts/ui/level_display.gd")
	LAB = load("res://scripts/dev/ui_real_capture_lab.gd")
	IT = load("res://scripts/ui/item_text.gd")
	CC = load("res://scripts/ui/character_creation.gd")
	_expect(UT.TYPE_MIN == TYPE_MIN, "type floor is %d" % TYPE_MIN)
	_test_owned_sources()
	_test_draw_centered()
	_test_context_radial()
	_test_craft_level_text()
	_test_display_mode()
	_test_theme()
	_test_legend_colours()
	_test_level_display()
	_test_hex_focus()
	_test_gate_verdict()
	_test_review_fixes()
	if failures.is_empty():
		print("[t_ui] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_ui] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

## Top-level arguments of the first `fname(` call on a line ("" when the call spans lines).
static func call_args(line: String, fname: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var at := line.find(fname + "(")
	if at < 0:
		return out
	var depth := 0
	var cur := ""
	for i in range(at + fname.length(), line.length()):
		var ch := line[i]
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
			if depth == 1:
				continue
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
			if depth == 0:
				out.append(cur.strip_edges())
				return out
		elif ch == "," and depth == 1:
			out.append(cur.strip_edges())
			cur = ""
			continue
		cur += ch
	return PackedStringArray()

## No system emoji (U+1F300-1FAFF) and no literal font size under 12 in the owned UI files.
func _test_owned_sources() -> void:
	var override_re := RegEx.new()
	override_re.compile("font_size\",\\s*(\\d+)\\)")
	var local_re := RegEx.new()
	local_re.compile("\\b(?:fs|cs|bs|ts|ls|gs|ns|bsz|size_px)\\s*:?=\\s*(\\d+)\\s*$")
	var emoji_hits := 0
	var small_hits := 0
	for path in OWNED:
		var text := FileAccess.get_file_as_string(path)
		_expect(text != "", "owned file readable: %s" % path)
		var lines := text.split("\n")
		for n in lines.size():
			var line := lines[n]
			for i in line.length():
				var cp := line.unicode_at(i)
				if cp >= 0x1F300 and cp <= 0x1FAFF:
					emoji_hits += 1
					failures.append("emoji U+%X at %s:%d" % [cp, path, n + 1])
					break
			var sizes: PackedStringArray = []
			for m in override_re.search_all(line):
				sizes.append(m.get_string(1))
			for m in local_re.search_all(line):
				sizes.append(m.get_string(1))
			var ds := call_args(line, "draw_string")
			if ds.size() >= 6:
				sizes.append(ds[5])
			var dc := call_args(line, "draw_centered")
			if dc.size() >= 5:
				sizes.append(dc[4])
			for s in sizes:
				if s.is_valid_int() and int(s) < TYPE_MIN:
					small_hits += 1
					failures.append("font size %s under %d at %s:%d" % [s, TYPE_MIN, path, n + 1])
	print("[t_ui] scanned %d owned files: emoji=%d small_font=%d" % [OWNED.size(), emoji_hits, small_hits])

func _test_draw_centered() -> void:
	_expect(is_equal_approx(UT.centered_x(100.0, 40.0), 80.0), "a 40 px string centred at x=100 starts at x=80")
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("Bleed", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var at: Vector2 = UT.centered_origin(font, "Bleed", 14, Vector2(100, 50))
	_expect(is_equal_approx(at.x, 100.0 - w * 0.5), "measured string is centred on x (start %.1f, width %.1f)" % [at.x, w])
	_expect(at.y > 50.0 and at.y < 50.0 + 14.0, "baseline sits just under the centre line (%.1f)" % at.y)
	print("[t_ui] draw_centered: 40 px at x=100 starts at %.1f" % UT.centered_x(100.0, 40.0))

func _test_context_radial() -> void:
	var view := Vector2(1600, 900)
	var hex := ContextRadial.HEX
	# The verifier's case: two options, anchor above the view. Per-hex clamping stacked them.
	var spots := ContextRadial.hex_positions(Vector2(800, -200), 2, view, Vector4.ZERO, hex)
	_expect(spots.size() == 2, "two hexes returned")
	if spots.size() == 2:
		var d := spots[0].distance_to(spots[1])
		_expect(d >= hex, "hex centres at least one hex apart above the view (got %.1f)" % d)
		print("[t_ui] radial above view: centres %.1f px apart (hex %.0f)" % [d, hex])
	for anchor in [Vector2(800, -200), Vector2(1590, 450), Vector2(10, 890), Vector2(800, 450)]:
		var ring := ContextRadial.hex_positions(anchor, 5, view, Vector4.ZERO, hex)
		for p in ring:
			_expect(p.x >= -0.5 and p.y >= -0.5 and p.x + hex <= view.x + 0.5 and p.y + hex <= view.y + 0.5, "hex inside the view for anchor %s (%s)" % [anchor, p])
		for i in ring.size():
			for j in range(i + 1, ring.size()):
				_expect(ring[i].distance_to(ring[j]) >= hex - 0.5, "five-hex ring keeps hexes apart at %s" % anchor)
	# A ring next to a HUD block turns away from it when it can.
	var avoid: Array[Rect2] = [Rect2(1150, 0, 450, 240)]
	var near_hud := ContextRadial.hex_positions(Vector2(1000, 150), 2, view, Vector4.ZERO, hex, 0.0, avoid)
	for p in near_hud:
		_expect(not Rect2(p, Vector2(hex, hex)).intersects(avoid[0]), "radial hex stays off the HUD block (%s)" % p)

func _test_craft_level_text() -> void:
	var crafting: GDScript = load("res://scripts/items/crafting.gd")
	var inv: Object = (load("res://scripts/items/inventory.gd") as GDScript).new()
	var tested := 0
	for rec in crafting.recipes_for_station(&""):
		if (rec.get("slots", []) as Array).is_empty():
			continue
		var got: String = LD.recipe_label(inv, rec)
		_expect(got == CU.NO_LEVEL, "empty bag shows %s for %s (got %s)" % [CU.NO_LEVEL, rec.get("id", "?"), got])
		tested += 1
		if tested >= 5:
			break
	_expect(tested > 0, "hand recipes with inputs exist")
	_expect(CU.NO_LEVEL == LD.NONE and LD.NONE == "Lv. —", "missing-input level text is 'Lv. —', in the LevelDisplay format")
	var data: Node = get_root().get_node("Data")
	_expect(not (IT.stat_lines(data.item(&"work_axe")) as PackedStringArray).is_empty(), "a tool has stat lines")
	_expect(IT.nice_name("no_such_thing") == "No Such Thing", "nice_name falls back to the capitalised id")
	print("[t_ui] craft: %d unmakeable hand recipes read '%s'" % [tested, CU.NO_LEVEL])

func _test_display_mode() -> void:
	_expect(DisplayMode.logical_size(Vector2i(390, 844), 1.0) == Vector2i(390, 844), "390x844 window -> 390x844 logical")
	_expect(DisplayMode.logical_size(Vector2i(1170, 2532), 3.0) == Vector2i(390, 844), "iPhone pixels at 3x -> 390x844 logical")
	_expect(DisplayMode.logical_size(Vector2i(1600, 900), 1.0) == DisplayMode.DESIGN, "1600x900 desktop unchanged")
	_expect(DisplayMode.logical_size(Vector2i(3200, 1800), 2.0) == DisplayMode.DESIGN, "retina browser at 1600x900 CSS unchanged")
	# The owner plays phones landscape: 844x390 pt gets a 1:1 canvas. It is compact (phone type and
	# the owned landscape layouts) but not is_phone, so the protected HUD and bag keep their desktop
	# rows (their portrait rows overlapped at 844x390).
	var land := Vector2(DisplayMode.logical_size(Vector2i(844, 390), 1.0))
	_expect(land == Vector2(844, 390), "844x390 landscape window -> 844x390 logical (got %s)" % land)
	_expect(DisplayMode.logical_size(Vector2i(2532, 1170), 3.0) == Vector2i(844, 390), "iPhone landscape pixels at 3x -> 844x390 logical")
	_expect(UT.is_compact(land) and not UT.is_narrow(land) and not UT.is_phone(land), "the landscape canvas is compact, not narrow, not is_phone")
	_expect(not UT.is_compact(Vector2(DisplayMode.DESIGN)) and not UT.is_phone(Vector2(DisplayMode.DESIGN)), "the 1600x900 desktop canvas is not a phone")
	# Narrow landscape phones (iPhone SE 667x375, 640x360 Androids) get LANDSCAPE_MIN_W, never a
	# canvas under 720 where is_phone would flip the protected HUD and bag to portrait rows, nor
	# one too narrow for the bag's three columns (at 760 its close button ran off the edge).
	var se := Vector2(DisplayMode.logical_size(Vector2i(667, 375), 1.0))
	_expect(se == Vector2(804, 452), "667x375 landscape window -> 804x452 logical (got %s)" % se)
	_expect(DisplayMode.logical_size(Vector2i(640, 360), 1.0) == Vector2i(804, 452), "640x360 landscape window -> 804x452 logical")
	# A notched iPhone (852x393 pt, 59 pt insets each side at 3x) keeps 804 px inside its safe area.
	_expect(DisplayMode.logical_size(Vector2i(2556, 1179), 3.0, 354.0) == Vector2i(933, 430), "notched 852x393 landscape -> 933x430 logical (%s)" % DisplayMode.logical_size(Vector2i(2556, 1179), 3.0, 354.0))
	# A bogus inset (a portrait safe area reported in landscape, 1362 px at 3x) is clamped to a quarter of the width.
	var bogus := DisplayMode.logical_size(Vector2i(2532, 1170), 3.0, 1362.0)
	_expect(bogus == Vector2i(1072, 495), "a portrait safe area in landscape clamps to 1072x495 logical (got %s)" % bogus)
	_expect(UT.is_compact(se) and not UT.is_narrow(se) and not UT.is_phone(se), "the SE canvas is compact, not narrow, not is_phone")
	_expect(not UT.is_narrow(Vector2(668, 376)), "a landscape canvas is never narrow, whatever its width")
	_expect(DisplayMode.logical_size(Vector2i(820, 1180), 1.0) == Vector2i(DisplayMode.TABLET_W, 1439), "portrait tablet -> TABLET_W wide canvas")
	_expect(DisplayMode.is_phone_landscape(Vector2(844, 390)) and DisplayMode.is_phone_landscape(Vector2(667, 375)), "844x390 and 667x375 pt are landscape phones")
	_expect(not DisplayMode.is_phone_landscape(Vector2(1947, 900)), "the unfitted 1947x900 canvas is not")
	_expect(not DisplayMode.is_phone_landscape(Vector2(390, 844)) and not DisplayMode.is_phone_landscape(Vector2(1600, 900)), "portrait phone and desktop are not landscape phones")
	_expect(DisplayMode.logical_size(Vector2i(0, 0), 1.0) == DisplayMode.DESIGN, "a zero window keeps the design canvas")
	var port := Vector2(DisplayMode.logical_size(Vector2i(390, 844), 1.0))
	_expect(UT.is_phone(port) and UT.is_narrow(port) and UT.is_compact(port), "the portrait canvas is phone, narrow and compact")
	print("[t_ui] canvas: 844x390 -> %s compact=%s narrow=%s is_phone=%s; 667x375 -> %s; 1600x900 -> %s compact=%s" % [land, UT.is_compact(land), UT.is_narrow(land), UT.is_phone(land), se, Vector2(DisplayMode.logical_size(Vector2i(1600, 900), 1.0)), UT.is_compact(Vector2(DisplayMode.DESIGN))])
	# Character creation lays out for the fitted canvas with or without the fit: an unfitted 844x390
	# phone (1947x900 canvas) gets the landscape layout at 2.3x, not the desktop one at 0.43.
	var raw: Dictionary = CC.layout_for(Vector2(1947, 900), land)
	_expect(bool(raw["short"]) and absf(float(raw["k"]) - 1947.0 / 844.0) < 0.01, "unfitted landscape charcreate: short layout scaled %.2f" % float(raw["k"]))
	var fitted: Dictionary = CC.layout_for(land, land)
	_expect(bool(fitted["short"]) and is_equal_approx(float(fitted["k"]), 1.0), "fitted landscape charcreate: short layout at 1x")
	var desk: Dictionary = CC.layout_for(Vector2(1600, 900), Vector2(DisplayMode.DESIGN))
	_expect(not bool(desk["phone"]) and is_equal_approx(float(desk["k"]), 1.0), "desktop charcreate: desktop layout at 1x")
	var se_raw: Dictionary = CC.layout_for(Vector2(1601, 900), se)
	_expect(bool(se_raw["short"]) and not bool(se_raw["narrow"]), "unfitted SE charcreate: landscape layout, not portrait")
	print("[t_ui] charcreate: unfitted 844x390 k=%.2f short=%s; fitted k=%.2f" % [float(raw["k"]), raw["short"], float(fitted["k"])])
	# Landscape screens keep off the HUD: skills sits under the vitals band, radials avoid the right column.
	var SS: GDScript = load("res://scripts/ui/skills_sheet.gd")
	var zones: Array[Rect2] = UT.hud_reserved(land)
	var sheet: Rect2 = SS.panel_rect(land)
	_expect(not sheet.intersects(zones[0]), "landscape skills panel %s clears the vitals band %s" % [sheet, zones[0]])
	_expect(sheet.end.y <= land.y and sheet.size.y >= 4.0 * SS.ROW_H, "landscape skills panel fits the view with room for rows (%s)" % sheet)
	_expect(zones.size() == 3 and zones[1].position.x > land.x * 0.7, "landscape HUD zones include the right map/rail column (%s)" % [zones])

func _test_theme() -> void:
	var t: Theme = DisplayMode.build_theme()
	_expect(t.has_stylebox("focus", "Button"), "theme has a Button focus ring")
	_expect(t.has_stylebox("normal", "Button") and t.has_stylebox("panel", "PanelContainer"), "theme styles buttons and panels")
	for kind in ["Button", "Label", "LineEdit", "ProgressBar"]:
		_expect(t.get_font_size("font_size", kind) >= TYPE_MIN, "theme font size >= %d for %s" % [TYPE_MIN, kind])
	DisplayMode.install_theme()
	var focus := ThemeDB.get_default_theme().get_stylebox("focus", "Button") as StyleBoxFlat
	_expect(focus != null and focus.border_color == UT.TEAL, "theme merged into the default theme")

func _test_legend_colours() -> void:
	var legend: Dictionary = MS.LEGEND
	var kinds: Array = legend.keys()
	var min_d := INF
	for i in kinds.size():
		for j in range(i + 1, kinds.size()):
			var a: Color = MS.legend_color(kinds[i])
			var b: Color = MS.legend_color(kinds[j])
			var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			min_d = minf(min_d, d)
			_expect(d >= 0.3, "legend colours %s and %s are distinct (%.2f)" % [kinds[i], kinds[j], d])
	print("[t_ui] atlas legend: %d kinds, min colour distance %.2f" % [kinds.size(), min_d])

func _test_level_display() -> void:
	var world: Node = get_root().get_node("World")
	var was: int = world.pioneer_level
	world.pioneer_level = 7
	_expect(LD.player_level() == 7 and LD.player_label() == "Lv. 7", "one player level label")
	world.pioneer_level = was

func _test_hex_focus() -> void:
	var b: Control = (load("res://scripts/ui/hex_button.gd") as GDScript).new()
	_expect(b.focus_mode == Control.FOCUS_ALL, "HexButton is focusable")
	get_root().add_child(b)
	b.position = Vector2(100, 100)
	var hits := [0]
	b.connect("pressed", func () -> void: hits[0] += 1)
	b.grab_focus()
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	get_root().push_input(accept)
	_expect(hits[0] == 1, "ui_accept presses a focused HexButton (pressed x%d)" % hits[0])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# push_input takes window pixels; the root stretches its canvas into the window
	click.position = get_root().get_final_transform() * b.get_global_rect().get_center()
	click.global_position = click.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)
	_expect(not b.has_focus(), "a tap drops the hex's focus")
	_expect(hits[0] == 2, "the tap itself still presses the hex (pressed x%d)" % hits[0])
	print("[t_ui] hex focus: accept pressed=%d, focus after tap=%s" % [hits[0], b.has_focus()])
	b.queue_free()
	var hidden := Button.new()
	hidden.visible = false
	var inert := Label.new()
	var first := Button.new()
	var second := Button.new()
	for c in [hidden, inert, first, second]:
		get_root().add_child(c)
	_expect(UT.first_focusable([hidden, inert, first, second]) == first, "focus_first picks the first visible focusable control")
	for c in [hidden, inert, first, second]:
		c.queue_free()

## The real-scene gate must fail when the phone canvas fit is missing (review: it printed PASS
## for "phone=false min_font_px=3 logical_width=1600" at 390x844).
func _test_gate_verdict() -> void:
	var land: Array = LAB.gate_failures(Vector2(844, 390), false, 5.0, 1947)
	_expect(land.size() == 2, "844x390 without the fit fails twice (got %s)" % [land])
	_expect((LAB.gate_failures(Vector2(844, 390), true, 12.0, 844) as Array).is_empty(), "844x390 with the fit passes")
	_expect((LAB.gate_failures(Vector2(844, 390), false, 13.0, 844) as Array).size() == 1, "844x390 with is_compact false fails")
	print("[t_ui] gate: 844x390 without fit -> %d failures" % land.size())
	var broken: Array = LAB.gate_failures(Vector2(390, 844), false, 3.0, 1600)
	_expect(broken.size() == 2, "390x844 without the fit fails twice (got %s)" % [broken])
	_expect((LAB.gate_failures(Vector2(390, 844), true, 12.0, 390) as Array).is_empty(), "390x844 with the fit passes")
	_expect(not (LAB.gate_failures(Vector2(600, 500), true, 9.0, 600) as Array).is_empty(), "any phone-width window under 12 px fails")
	# SE: the 804 px canvas at 0.83 puts 12 px at 10 pt, which passes; a 1:1 667 px canvas fails.
	var se_floor: float = LAB.type_floor_pt(Vector2(667, 375))
	_expect(absf(se_floor - 12.0 * 667.0 / 804.0) < 0.01, "SE type floor is 12 px on the 804 px canvas (%.2f pt)" % se_floor)
	_expect((LAB.gate_failures(Vector2(667, 375), true, se_floor, 804) as Array).is_empty(), "667x375 with the fit passes")
	_expect((LAB.gate_failures(Vector2(667, 375), true, 12.0, 667) as Array).size() == 1, "667x375 on a 1:1 canvas fails")
	_expect((LAB.gate_failures(Vector2(667, 375), true, 9.0, 804) as Array).size() == 1, "667x375 with 9 pt text fails")
	_expect((LAB.gate_failures(Vector2(667, 375), true, se_floor, 760) as Array).size() == 1, "667x375 on a 760 px canvas fails")
	_expect((LAB.gate_failures(Vector2(1600, 900), false, 13.0, 1600) as Array).is_empty(), "1600x900 desktop passes")
	_expect(not (LAB.gate_failures(Vector2(1600, 900), false, 13.0, 1947) as Array).is_empty(), "1600x900 with a wrong canvas fails")
	print("[t_ui] gate: 390x844 without fit -> %d failures; SE floor %.1f pt" % [broken.size(), se_floor])

func _test_review_fixes() -> void:
	# NaN anchor (source behind the camera) still yields a full, finite ring
	var nan_ring := ContextRadial.hex_positions(Vector2(NAN, NAN), 2, Vector2(1600, 900), Vector4.ZERO)
	var finite := nan_ring.size() == 2
	for p in nan_ring:
		finite = finite and p.is_finite()
	_expect(finite, "NaN anchor returns two finite hex positions (got %s)" % [nan_ring])
	print("[t_ui] NaN anchor -> %s" % [nan_ring])
	# station tab grammar
	_expect(CU.recipe_count(1) == "1 recipe" and CU.recipe_count(3) == "3 recipes", "recipe count is pluralised")
	# one level format: no hand-rolled "Lv %d" / "Lv —" outside LevelDisplay
	var lv_re := RegEx.new()
	lv_re.compile("\"[^\"]*Lv\\.? ?(%d|—)")
	for path in OWNED:
		if path.ends_with("level_display.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var line := lines[n].strip_edges()
			if not line.begins_with("#") and lv_re.search(line) != null:
				failures.append("level text not via LevelDisplay at %s:%d" % [path, n + 1])
	# atlas legend: a light ring on every swatch, and phone labels fit their column
	_expect(MS.SWATCH_RING.get_luminance() >= 0.6, "legend swatch ring is light on the dark panel")
	var phone := Vector2(390, 844)
	var font := ThemeDB.fallback_font
	var col_w: float = MS.legend_col_w(phone)
	for kind in MS.LEGEND:
		var w := font.get_string_size(str(MS.LEGEND[kind][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, UT.meta(phone)).x
		_expect(w + 22.0 <= col_w, "phone legend label '%s' (%.0f px) fits its %.0f px column" % [MS.LEGEND[kind][1], w, col_w])
	# plate pill hides world labels behind it
	var CP: GDScript = load("res://scripts/ui/creature_plates.gd")
	_expect(is_equal_approx(CP.PILL_ALPHA, 1.0), "plate pill is opaque (%.2f): at 0.96 a world label still ghosted through" % CP.PILL_ALPHA)
	# every craft station has its own symbol (crock pot borrowed the stone grill's through an alias)
	var icons: GDScript = load("res://scripts/ui/item_icons.gd")
	var seen := {}
	for row in CU.STATIONS:
		var tex: Texture2D = icons.texture(StringName(str(row[2])))
		var key := tex.resource_path if tex else ""
		_expect(key != "" and not seen.has(key), "station %s has its own symbol (%s, also %s)" % [row[0], key, seen.get(key, "-")])
		seen[key] = row[0]
	print("[t_ui] craft stations: %d with %d distinct symbols" % [CU.STATIONS.size(), seen.size()])
	# skills: the scroll content leaves room for the scrollbar
	var sc := ScrollContainer.new()
	var SS: GDScript = load("res://scripts/ui/skills_sheet.gd")
	_expect(SS.scrollbar_reserve(sc) >= 12 + UT.SPACE, "skills sheet reserves the scrollbar width (%d)" % SS.scrollbar_reserve(sc))
	sc.free()
