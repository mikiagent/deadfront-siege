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
	"res://scripts/ui/character_creation.gd", "res://scripts/ui/level_display.gd",
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
		var got: String = CU.level_text(inv, rec)
		_expect(got == CU.NO_LEVEL, "empty bag shows %s for %s (got %s)" % [CU.NO_LEVEL, rec.get("id", "?"), got])
		tested += 1
		if tested >= 5:
			break
	_expect(tested > 0, "hand recipes with inputs exist")
	_expect(CU.NO_LEVEL == "Lv —", "missing-input level text is 'Lv —'")
	var data: Node = get_root().get_node("Data")
	_expect(not (CU.stat_lines(data.item(&"work_axe")) as PackedStringArray).is_empty(), "a tool has stat lines")
	print("[t_ui] craft: %d unmakeable hand recipes read '%s'" % [tested, CU.NO_LEVEL])

func _test_display_mode() -> void:
	_expect(DisplayMode.logical_size(Vector2i(390, 844), 1.0) == Vector2i(390, 844), "390x844 window -> 390x844 logical")
	_expect(DisplayMode.logical_size(Vector2i(1170, 2532), 3.0) == Vector2i(390, 844), "iPhone pixels at 3x -> 390x844 logical")
	_expect(DisplayMode.logical_size(Vector2i(1600, 900), 1.0) == DisplayMode.DESIGN, "1600x900 desktop unchanged")
	_expect(DisplayMode.logical_size(Vector2i(3200, 1800), 2.0) == DisplayMode.DESIGN, "retina browser at 1600x900 CSS unchanged")
	_expect(DisplayMode.logical_size(Vector2i(844, 390), 1.0) == DisplayMode.DESIGN, "landscape keeps the design canvas")
	_expect(DisplayMode.logical_size(Vector2i(0, 0), 1.0) == DisplayMode.DESIGN, "a zero window keeps the design canvas")
	_expect(UT.is_phone(Vector2(DisplayMode.logical_size(Vector2i(390, 844), 1.0))), "is_phone holds on the phone canvas")

func _test_theme() -> void:
	var t: Theme = UT.build_theme()
	_expect(t.has_stylebox("focus", "Button"), "theme has a Button focus ring")
	_expect(t.has_stylebox("normal", "Button") and t.has_stylebox("panel", "PanelContainer"), "theme styles buttons and panels")
	for kind in ["Button", "Label", "LineEdit", "ProgressBar"]:
		_expect(t.get_font_size("font_size", kind) >= TYPE_MIN, "theme font size >= %d for %s" % [TYPE_MIN, kind])
	UT.install_theme()
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
	b.free()
