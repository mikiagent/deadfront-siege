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
	"res://scripts/ui/food_inspector.gd", "res://scripts/ui/respawn_ring.gd",
	"res://scripts/ui/character_creation.gd", "res://scripts/ui/level_display.gd",
	"res://scripts/ui/hud_layout.gd", "res://scripts/ui/hud_pills.gd", "res://scripts/ui/yield_card.gd",
	"res://scripts/ui/pet_radial.gd", "res://scripts/ui/pet_rename_dialog.gd",
]
const TYPE_MIN := 12
## The HUD and bag joined W1-UI late (orchestrator option a). The bag is emoji-free; the HUD's rail
## and hunt glyphs have no white symbol yet and go to W2-HUD. Capped so the count cannot grow.
const LATE_EMOJI_LINES := {"res://scripts/ui/hunt_hud.gd": 10, "res://scripts/ui/inventory_ui.gd": 0}

var failures: Array[String] = []
var _done := false
# Scripts that reach autoloads (Data, World, Game) cannot compile while `--script` compiles this
# file, so they are loaded on the first frame, after the autoloads exist (as run_all.gd does).
var UT: GDScript
var CU: GDScript
var MS: GDScript
var LD: GDScript
var CR: GDScript  ## context_radial.gd and display_mode.gd, loaded like the rest (no class_name at parse time)
var DM: GDScript
var LAB: GDScript
var CC: GDScript
var _tally := Tally.new()

## Counts engine errors and warnings while the checks run: one a check trips (grab_focus on a
## FOCUS_NONE hex printed a warning and a backtrace) fails the run instead of littering the log.
class Tally extends Logger:
	var lines: PackedStringArray = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s %s (%s:%d %s)" % ["WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR", rationale if rationale != "" else code, file, line, function])

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	OS.add_logger(_tally)
	UT = load("res://scripts/ui/ui_tokens.gd")
	CU = load("res://scripts/ui/craft_ui.gd")
	MS = load("res://scripts/ui/map_screen.gd")
	LD = load("res://scripts/ui/level_display.gd")
	CR = load("res://scripts/ui/context_radial.gd")
	DM = load("res://scripts/core/display_mode.gd")
	LAB = load("res://scripts/dev/ui_real_capture_lab.gd")
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
	_test_level_up_banner()
	_test_hex_focus()
	_test_gate_verdict()
	_test_review_fixes()
	_test_free_spot()
	_test_layout_avoid()
	_test_current_title()
	_test_desktop_short_window()
	OS.remove_logger(_tally)
	for l in _tally.lines:
		failures.append("engine %s" % l)
	print("[t_ui] engine errors/warnings during the checks: %d" % _tally.lines.size())
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
		var first_func := -1
		for n in lines.size():
			var line := lines[n]
			# House style: constants sit at the top, before the first function.
			if first_func < 0 and (line.begins_with("func ") or line.begins_with("static func ")):
				first_func = n
			elif first_func >= 0 and line.begins_with("const "):
				failures.append("const after the first func (line %d) at %s:%d" % [first_func + 1, path, n + 1])
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
	for path in LATE_EMOJI_LINES:
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			for i in line.length():
				if line.unicode_at(i) >= 0x1F300 and line.unicode_at(i) <= 0x1FAFF:
					n += 1
					break
		_expect(n <= int(LATE_EMOJI_LINES[path]), "%s: %d lines with emoji, at most %d" % [path, n, LATE_EMOJI_LINES[path]])
		print("[t_ui] %s: %d lines with emoji (cap %d, W2-HUD)" % [path.get_file(), n, LATE_EMOJI_LINES[path]])

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
	var hex: float = CR.HEX
	# The verifier's case: two options, anchor above the view. Per-hex clamping stacked them.
	var spots: Array[Vector2] = CR.hex_positions(Vector2(800, -200), 2, view, Vector4.ZERO, hex)
	_expect(spots.size() == 2, "two hexes returned")
	if spots.size() == 2:
		var d := spots[0].distance_to(spots[1])
		_expect(d >= hex, "hex centres at least one hex apart above the view (got %.1f)" % d)
		print("[t_ui] radial above view: centres %.1f px apart (hex %.0f)" % [d, hex])
	for anchor in [Vector2(800, -200), Vector2(1590, 450), Vector2(10, 890), Vector2(800, 450)]:
		var ring: Array[Vector2] = CR.hex_positions(anchor, 5, view, Vector4.ZERO, hex)
		for p in ring:
			_expect(p.x >= -0.5 and p.y >= -0.5 and p.x + hex <= view.x + 0.5 and p.y + hex <= view.y + 0.5, "hex inside the view for anchor %s (%s)" % [anchor, p])
		for i in ring.size():
			for j in range(i + 1, ring.size()):
				_expect(ring[i].distance_to(ring[j]) >= hex - 0.5, "five-hex ring keeps hexes apart at %s" % anchor)
	# A ring next to a HUD block turns away from it when it can.
	var avoid: Array[Rect2] = [Rect2(1150, 0, 450, 240)]
	var near_hud: Array[Vector2] = CR.hex_positions(Vector2(1000, 150), 2, view, Vector4.ZERO, hex, 0.0, avoid)
	for p in near_hud:
		_expect(not Rect2(p, Vector2(hex, hex)).intersects(avoid[0]), "radial hex stays off the HUD block (%s)" % p)
	# The ring turns as a whole: inside the view, with a block on both preferred (right-hand) slots,
	# it must come out clear of the block with every hex still one radius from the anchor. Sliding
	# alone keeps the hexes apart but cannot clear it (review: TURN_STEPS := 1 still passed).
	var centre := Vector2(800, 450)
	var block: Array[Rect2] = [Rect2(820, 300, 300, 300)]
	var unturned: Array[Vector2] = CR._ring(centre, [-0.9, 0.9] as Array[float], 0.0, 96.0, hex)
	_expect(Rect2(unturned[0], Vector2(hex, hex)).intersects(block[0]) and Rect2(unturned[1], Vector2(hex, hex)).intersects(block[0]), "the unturned ring sits on the block (test set-up)")
	var turned: Array[Vector2] = CR.hex_positions(centre, 2, view, Vector4.ZERO, hex, 0.0, block)
	var radii: PackedStringArray = []
	for p in turned:
		var d := (p + Vector2(hex, hex) * 0.5).distance_to(centre)
		radii.append("%.1f" % d)
		_expect(not Rect2(p, Vector2(hex, hex)).intersects(block[0]), "turned ring clears the block (hex at %s)" % p)
		_expect(absf(d - 96.0) < 0.5, "turned ring keeps its radius: hex centre %.1f px from the anchor, not 96 (a slide, not a turn)" % d)
	print("[t_ui] radial turn: 2 hexes off the block at %s, radii %s" % [turned, ", ".join(radii)])

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
	_expect(not (LD.stat_lines(data.item(&"work_axe")) as PackedStringArray).is_empty(), "a tool has stat lines")
	_expect(LD.nice_name("no_such_thing") == "No Such Thing", "nice_name falls back to the capitalised id")
	print("[t_ui] craft: %d unmakeable hand recipes read '%s'" % [tested, CU.NO_LEVEL])

func _test_display_mode() -> void:
	_expect(DM.logical_size(Vector2i(390, 844), 1.0) == Vector2i(390, 844), "390x844 window -> 390x844 logical")
	_expect(DM.logical_size(Vector2i(1170, 2532), 3.0) == Vector2i(390, 844), "iPhone pixels at 3x -> 390x844 logical")
	_expect(DM.logical_size(Vector2i(1600, 900), 1.0) == DM.DESIGN, "1600x900 desktop unchanged")
	_expect(DM.logical_size(Vector2i(3200, 1800), 2.0) == DM.DESIGN, "retina browser at 1600x900 CSS unchanged")
	# The owner plays phones landscape: 844x390 pt gets a 1:1 canvas. It is compact (phone type and
	# the owned landscape layouts) but not is_phone, so the protected HUD and bag keep their desktop
	# rows (their portrait rows overlapped at 844x390).
	var land := Vector2(DM.logical_size(Vector2i(844, 390), 1.0))
	_expect(land == Vector2(844, 390), "844x390 landscape window -> 844x390 logical (got %s)" % land)
	_expect(DM.logical_size(Vector2i(2532, 1170), 3.0) == Vector2i(844, 390), "iPhone landscape pixels at 3x -> 844x390 logical")
	_expect(UT.is_compact(land) and not UT.is_narrow(land) and not UT.is_phone(land), "the landscape canvas is compact, not narrow, not is_phone")
	_expect(not UT.is_compact(Vector2(DM.DESIGN)) and not UT.is_phone(Vector2(DM.DESIGN)), "the 1600x900 desktop canvas is not a phone")
	# Narrow landscape phones (iPhone SE 667x375, 640x360 Androids) get LANDSCAPE_MIN_W, never a
	# canvas under 720 where is_phone would flip the protected HUD and bag to portrait rows, nor
	# one too narrow for the bag's three columns (at 760 its close button ran off the edge).
	var se := Vector2(DM.logical_size(Vector2i(667, 375), 1.0))
	_expect(se == Vector2(804, 452), "667x375 landscape window -> 804x452 logical (got %s)" % se)
	_expect(DM.logical_size(Vector2i(640, 360), 1.0) == Vector2i(804, 452), "640x360 landscape window -> 804x452 logical")
	# A notched iPhone (852x393 pt, 59 pt insets each side at 3x) keeps 804 px inside its safe area.
	_expect(DM.logical_size(Vector2i(2556, 1179), 3.0, 354.0) == Vector2i(933, 430), "notched 852x393 landscape -> 933x430 logical (%s)" % DM.logical_size(Vector2i(2556, 1179), 3.0, 354.0))
	# A bogus inset (a portrait safe area reported in landscape, 1362 px at 3x) is clamped to a quarter of the width.
	var bogus: Vector2i = DM.logical_size(Vector2i(2532, 1170), 3.0, 1362.0)
	_expect(bogus == Vector2i(1072, 495), "a portrait safe area in landscape clamps to 1072x495 logical (got %s)" % bogus)
	_expect(UT.is_compact(se) and not UT.is_narrow(se) and not UT.is_phone(se), "the SE canvas is compact, not narrow, not is_phone")
	_expect(not UT.is_narrow(Vector2(668, 376)), "a landscape canvas is never narrow, whatever its width")
	_expect(DM.logical_size(Vector2i(820, 1180), 1.0) == Vector2i(DM.TABLET_W, 1439), "portrait tablet -> TABLET_W wide canvas")
	_expect(DM.is_phone_landscape(Vector2(844, 390)) and DM.is_phone_landscape(Vector2(667, 375)), "844x390 and 667x375 pt are landscape phones")
	_expect(not DM.is_phone_landscape(Vector2(1947, 900)), "the unfitted 1947x900 canvas is not")
	_expect(not DM.is_phone_landscape(Vector2(390, 844)) and not DM.is_phone_landscape(Vector2(1600, 900)), "portrait phone and desktop are not landscape phones")
	_expect(DM.logical_size(Vector2i(0, 0), 1.0) == DM.DESIGN, "a zero window keeps the design canvas")
	var port := Vector2(DM.logical_size(Vector2i(390, 844), 1.0))
	_expect(UT.is_phone(port) and UT.is_narrow(port) and UT.is_compact(port), "the portrait canvas is phone, narrow and compact")
	print("[t_ui] canvas: 844x390 -> %s compact=%s narrow=%s is_phone=%s; 667x375 -> %s; 1600x900 -> %s compact=%s" % [land, UT.is_compact(land), UT.is_narrow(land), UT.is_phone(land), se, Vector2(DM.logical_size(Vector2i(1600, 900), 1.0)), UT.is_compact(Vector2(DM.DESIGN))])
	# Character creation lays out for the fitted canvas with or without the fit: an unfitted 844x390
	# phone (1947x900 canvas) gets the landscape layout at 2.3x, not the desktop one at 0.43.
	var raw: Dictionary = CC.layout_for(Vector2(1947, 900), land)
	_expect(bool(raw["short"]) and absf(float(raw["k"]) - 1947.0 / 844.0) < 0.01, "unfitted landscape charcreate: short layout scaled %.2f" % float(raw["k"]))
	var fitted: Dictionary = CC.layout_for(land, land)
	_expect(bool(fitted["short"]) and is_equal_approx(float(fitted["k"]), 1.0), "fitted landscape charcreate: short layout at 1x")
	var desk: Dictionary = CC.layout_for(Vector2(1600, 900), Vector2(DM.DESIGN))
	_expect(not bool(desk["phone"]) and is_equal_approx(float(desk["k"]), 1.0), "desktop charcreate: desktop layout at 1x")
	var se_raw: Dictionary = CC.layout_for(Vector2(1601, 900), se)
	_expect(bool(se_raw["short"]) and not bool(se_raw["narrow"]), "unfitted SE charcreate: landscape layout, not portrait")
	print("[t_ui] charcreate: unfitted 844x390 k=%.2f short=%s; fitted k=%.2f" % [float(raw["k"]), raw["short"], float(fitted["k"])])
	# Landscape screens keep off the HUD: skills sits under the vitals band, radials avoid the right column.
	var SS: GDScript = load("res://scripts/ui/skills_sheet.gd")
	var zones: Array[Rect2] = UT.hud_reserved(land)
	var sheet: Rect2 = SS.panel_rect(land)
	# A landscape phone gets an opaque full-screen sheet (under the vitals only 3 of 12 rows fitted).
	_expect(SS.is_sheet(land) and sheet.encloses(zones[0]), "landscape skills sheet %s covers the vitals band %s" % [sheet, zones[0]])
	# C3 rebuild (UICHAR): Skills is a full-screen sheet on every canvas (spec §8 shared chrome).
	_expect(SS.is_sheet(Vector2(1600, 900)) and SS.panel_rect(Vector2(1600, 900)) == Rect2(0, 0, 1600, 900), "desktop skills is a full-screen sheet")
	_expect(sheet.end.y <= land.y and sheet.size.y >= 4.0 * SS.ROW_H, "landscape skills panel fits the view with room for rows (%s)" % sheet)
	_expect(zones.size() == 6 and zones[1].position.x > land.x * 0.7, "landscape HUD zones include the right map/rail column (%s)" % [zones])
	# HANDS takes the quick row's fourth slot above the MENU / BUILD / BAG rail (owner layout 2026-10-28;
	# it stood over the old four-hex rail's last hex): 64 px rail and quick hexes on a landscape phone.
	var HS: GDScript = load("res://scripts/ui/held_item_slot.gd")
	var hands := Rect2(16.0 + 3.0 * (HS.SLOT + 10.0), land.y - 14.0 - 18.0 - 64.0 - 12.0 - 18.0 - 64.0, HS.SLOT, HS.SLOT + 18.0)
	_expect(zones.size() == 6 and zones[3].encloses(hands), "landscape HUD zones cover the HANDS slot %s" % hands)
	# ...the quick-food row beside it, and the pet whistle row under the vitals (hunt_hud.gd).
	_expect(zones[3].encloses(Rect2(16.0, land.y - 96.0 - 64.0 - 30.0, 64.0, 82.0)), "landscape HUD zones cover the first quick-food hex")
	_expect(zones[5].encloses(Rect2(16.0, 104.0, 3.0 * 74.0 - 10.0, 82.0)), "landscape HUD zones cover the whistle row under the vitals (%s)" % zones[5])
	# The XP line at the bottom centre (a gather label landed on it at 844x390).
	var xp_w := ThemeDB.fallback_font.get_string_size("Lv. 100  100.0%", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var xp := Rect2(land.x * 0.5 - xp_w * 0.5, land.y - 19.0, xp_w, 15.0)
	_expect(zones[4].encloses(xp), "landscape HUD zones cover the XP line %s (%s)" % [xp, zones[4]])

func _test_theme() -> void:
	var t: Theme = DM.build_theme()
	_expect(t.has_stylebox("focus", "Button"), "theme has a Button focus ring")
	_expect(t.has_stylebox("normal", "Button") and t.has_stylebox("panel", "PanelContainer"), "theme styles buttons and panels")
	for kind in ["Button", "Label", "LineEdit", "ProgressBar"]:
		_expect(t.get_font_size("font_size", kind) >= TYPE_MIN, "theme font size >= %d for %s" % [TYPE_MIN, kind])
	DM.install_theme()
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

## Screens that show the player level; each must read it through LevelDisplay (the HUD drew the stored
## 0 while the bag drew 0 + 1, so a new survivor was "Lv. 0" on one screen and "Lv. 1" on the next).
const LEVEL_SITES := ["res://scripts/ui/hunt_hud.gd", "res://scripts/ui/inventory_ui.gd", "res://scripts/dev/ui_real_capture_lab.gd"]

func _test_level_display() -> void:
	var world: Node = get_root().get_node("World")
	var was: int = world.pioneer_level
	world.pioneer_level = 0
	var fresh: String = LD.player_label()
	_expect(LD.player_level() == 1 and fresh == "Lv. 1", "a new survivor (stored level 0) reads Lv. 1 (got %s)" % fresh)
	world.pioneer_level = 7
	_expect(LD.player_level() == 8 and LD.player_label() == "Lv. 8", "stored level 7 reads Lv. 8 (got %s)" % LD.player_label())
	world.pioneer_level = was
	# Writes (the levelup shot) and the signal argument are fine; any other read formats its own number.
	var write_re := RegEx.new()
	write_re.compile("World\\.pioneer_level\\s*\\+?=[^=]|emit\\(World\\.pioneer_level\\)")
	var reads := 0
	for path in OWNED + LEVEL_SITES:
		if path.ends_with("level_display.gd"):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n in lines.size():
			var line := write_re.sub(lines[n], "", true)
			if not line.strip_edges().begins_with("#") and line.contains("World.pioneer_level"):
				reads += 1
				failures.append("player level read outside LevelDisplay at %s:%d" % [path, n + 1])
	print("[t_ui] player level: new survivor reads %s; direct reads outside LevelDisplay=%d" % [fresh, reads])

## After a level-up the banner and its title agree: the banner showed the shown level while the
## title lookup used the stored one, so every title came one level late.
func _test_level_up_banner() -> void:
	var world: Node = get_root().get_node("World")
	var was: int = world.pioneer_level
	var hud: Control = load("res://scripts/ui/hunt_hud.gd").new()
	hud.call("_load_level_data")
	var titles: Dictionary = hud.get("_titles")
	var checked := 0
	for key in titles.keys():
		if not str(key).is_valid_int() or int(key) < 2:  # level 1 is the start, never a level-up
			continue
		world.pioneer_level = 0  # the handler formats the signal's stored level, not World's
		hud.call("_on_level_up", int(key) - 1)
		var lines: Array = hud.get("_levelup_lines")
		var title := ""
		for l in lines:
			if str(l[0]).begins_with("Title "):
				title = str(l[0])
		var want := "Title %s acquired." % titles[key]
		_expect(str(lines[0][0]) == "Lv. %s" % key and title == want, "level-up to Lv. %s: banner \"%s\" with \"%s\" (got \"%s\")" % [key, lines[0][0], want, title])
		_expect(str(hud.get("_levelup_title")) == want and str(hud.get("_levelup_summary")).contains("other stats") and str(hud.get("_levelup_sp")).is_valid_int(), "level-up to Lv. %s: the phone banner has the title, one stat line and the skill points behind the brain (\"%s\" %s)" % [key, hud.get("_levelup_summary"), hud.get("_levelup_sp")])
		checked += 1
	world.pioneer_level = was
	hud.free()
	_expect(checked > 0, "titles.json has titles past level 1")
	print("[t_ui] level-up banner: %d titled levels, banner level and title key agree" % checked)

func _test_hex_focus() -> void:
	var HB: GDScript = load("res://scripts/ui/hex_button.gd")
	_test_controller_focus(HB)
	var b: Control = HB.new()
	b.focus_mode = Control.FOCUS_ALL  # as a menu hex
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
	_push_click(b)
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

## The controller path end to end (wants_focus forced on, no joypad needed). A HUD hex never takes
## focus (hunt_hud builds its rail with HexButton's defaults; a focused one took Space, roll, and the
## arrows, move). A station menu opens on its first hex, ui_right walks along its hexes, and
## closing it leaves nothing focused.
func _test_controller_focus(HB: GDScript) -> void:
	var hud_hex: Control = HB.new()
	get_root().add_child(hud_hex)
	hud_hex.position = Vector2(600, 100)
	# No grab_focus here: on a FOCUS_NONE control it prints an engine warning (the Tally fails on it).
	_push_click(hud_hex)
	_expect(hud_hex.focus_mode == Control.FOCUS_NONE and not hud_hex.has_focus(), "a HUD hex (HexButton defaults) is FOCUS_NONE and a click gives it no focus")
	UT.force_focus = true
	var st := Node3D.new()
	get_root().add_child(st)
	var menu: Control = (load("res://scripts/ui/station_menu.gd") as GDScript).new()
	get_root().add_child(menu)
	menu.call("show_for", st, [{"id": &"craft", "label": "CRAFT", "glyph": "C"}, {"id": &"cook", "label": "COOK", "glyph": "K"}])
	var hexes: Array = menu.get("_buttons")
	for i in hexes.size():
		(hexes[i] as Control).position = Vector2(300.0 + 90.0 * i, 300.0)
	_expect(hexes.size() == 2 and (hexes[0] as Control).has_focus(), "a controller opens the station menu with its first hex focused")
	var path: PackedStringArray = []
	for i in 2:
		var right := InputEventAction.new()
		right.action = &"ui_right"
		right.pressed = true
		get_root().push_input(right)
		path.append(str(hexes.find(get_root().gui_get_focus_owner())))
	_expect(",".join(path) == "1,1", "ui_right moves to the second menu hex and stays in the menu (focus at hex %s)" % ",".join(path))
	menu.call("hide_menu")
	_expect(get_root().gui_get_focus_owner() == null, "closing the menu leaves nothing focused (%s)" % get_root().gui_get_focus_owner())
	print("[t_ui] controller focus: menu opens on hex 0, ui_right x2 -> hex %s, after close: %s; HUD hex focus=%s" % [",".join(path), get_root().gui_get_focus_owner(), hud_hex.has_focus()])
	UT.force_focus = false
	for n in [menu, st, hud_hex]:
		n.free()

## Left press and release at a control's centre, in window pixels (the root stretches its canvas).
func _push_click(c: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = get_root().get_final_transform() * c.get_global_rect().get_center()
	click.global_position = click.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)

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
	var nan_ring: Array[Vector2] = CR.hex_positions(Vector2(NAN, NAN), 2, Vector2(1600, 900), Vector4.ZERO)
	var finite := nan_ring.size() == 2
	for p in nan_ring:
		finite = finite and p.is_finite()
	_expect(finite, "NaN anchor returns two finite hex positions (got %s)" % [nan_ring])
	print("[t_ui] NaN anchor -> %s" % [nan_ring])
	# A huge finite anchor (review probe: (-1e9, 1e9), 6 hexes gave min_dist=0.0) keeps its hexes apart.
	var far: Array[Vector2] = CR.hex_positions(Vector2(-1e9, 1e9), 6, Vector2(1600, 900), Vector4.ZERO)
	var far_min := INF
	for i in far.size():
		for j in range(i + 1, far.size()):
			far_min = minf(far_min, far[i].distance_to(far[j]))
	_expect(far.size() == 6 and far_min >= CR.HEX - 0.5, "anchor (-1e9, 1e9) keeps six hexes apart (min %.1f)" % far_min)
	print("[t_ui] huge anchor (-1e9, 1e9): six hexes, min_dist=%.1f" % far_min)
	# The atlas is north-up: its layout carries no rotation (a "yaw" key stayed behind at 0.0).
	var map: Control = MS.new()
	get_root().add_child(map)
	var keys: Array = (map.call("_layout") as Dictionary).keys()
	keys.sort()
	_expect(keys == ["centre", "fit", "scale", "size_m"], "atlas layout keys are centre/fit/scale/size_m (got %s)" % [keys])
	map.free()
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
	# skill symbols are white silhouettes: one that fills little of its icon reads as a thin line
	# (the crossbow covered 6 %). Blob-shaped ones still need an eye on the skills shot.
	var thinnest := 1.0
	for id in SS.SYMBOLS:
		var tex: Texture2D = icons.texture(StringName(str(SS.SYMBOLS[id])))
		var share := _opaque_share(tex)
		thinnest = minf(thinnest, share)
		_expect(share >= 0.12, "skill %s symbol %s fills %.0f%% of its icon (>= 12%%)" % [id, SS.SYMBOLS[id], share * 100.0])
	print("[t_ui] skill symbols: %d, thinnest silhouette %.2f" % [SS.SYMBOLS.size(), thinnest])
	# White symbols are one shared material, not a CPU copy per icon (the per-pixel copy hitched the
	# first skills and craft open). The lab checks they render white.
	var HB: GDScript = load("res://scripts/ui/hex_button.gd")
	var club: Texture2D = icons.texture(&"club")
	_expect(club != null and HB.symbol(["club"]) == club, "HexButton.symbol hands back the icon itself, not a copy")
	var rect: TextureRect = SS.symbol_rect("melee", 28.0)
	_expect(rect.texture == club and rect.material == HB.white_material(), "skill symbols draw through the shared white material")
	rect.free()

## Guards: a pickup toast on the quest card takes the nearest free spot above or below it, never a
## spot on the card and never one off the screen (review: toasts drew across the quest card).
func _test_free_spot() -> void:
	var before := failures.size()
	var taken_card: Array[Rect2] = [Rect2(422, 34, 240, 72)]
	var taken_stack: Array[Rect2] = [Rect2(0, 100, 200, 30), Rect2(0, 134, 200, 30)]
	var rows: Array = [
		{"name": "quest card", "box": Rect2(380, 100, 100, 28), "taken": taken_card, "view": Vector2(844, 390), "want": Rect2(380, 110, 100, 28)},
		{"name": "already free", "box": Rect2(10, 200, 50, 20), "taken": taken_card, "view": Vector2(844, 390), "want": Rect2(10, 200, 50, 20)},
		{"name": "nearer upward", "box": Rect2(10, 105, 50, 20), "taken": [Rect2(0, 100, 844, 40)] as Array[Rect2], "view": Vector2(844, 390), "want": Rect2(10, 76, 50, 20)},
		{"name": "no room", "box": Rect2(10, 40, 50, 20), "taken": [Rect2(0, 0, 200, 100)] as Array[Rect2], "view": Vector2(200, 100), "want": Rect2()},
		{"name": "chain down", "box": Rect2(10, 125, 50, 20), "taken": taken_stack, "view": Vector2(200, 400), "want": Rect2(10, 168, 50, 20)},
		# A creature plate prefers the spot above (its creature is below it): down is nearer here.
		{"name": "nearer down", "box": Rect2(10, 125, 50, 20), "taken": [Rect2(0, 120, 200, 10)] as Array[Rect2], "view": Vector2(200, 400), "want": Rect2(10, 134, 50, 20)},
		{"name": "prefer up", "box": Rect2(10, 125, 50, 20), "taken": [Rect2(0, 120, 200, 10)] as Array[Rect2], "view": Vector2(200, 400), "want": Rect2(10, 96, 50, 20), "prefer_up": true},
		{"name": "prefer up, no room above", "box": Rect2(10, 15, 50, 20), "taken": [Rect2(0, 10, 200, 10)] as Array[Rect2], "view": Vector2(200, 400), "want": Rect2(10, 24, 50, 20), "prefer_up": true},
	]
	var placed := 0
	for row in rows:
		var label := str(row["name"])
		var box: Rect2 = row["box"]
		var taken: Array[Rect2] = row["taken"]
		var view: Vector2 = row["view"]
		var want: Rect2 = row["want"]
		var got: Rect2 = UT.free_spot(box, taken, view, bool(row.get("prefer_up", false)))
		_expect(got == want, "free_spot %s: %s -> %s, want %s" % [label, box, got, want])
		if want.has_area():
			placed += 1
			_expect(Rect2(0.0, 8.0, view.x, view.y - 16.0).encloses(got), "free_spot %s: %s stays inside the view %s" % [label, got, view])
			for t in taken:
				_expect(not got.intersects(t.grow(2.0)), "free_spot %s: %s clears the taken block %s" % [label, got, t])
	if failures.size() == before:
		print("[t_ui] ok free_spot %d rows, %d placed clear of the taken blocks" % [rows.size(), placed])

## Guards: screen-space labels keep off the HUD blocks and each other, and a label whose object the
## HUD hides is dropped rather than drawn on top (review: camp labels over the quest text).
func _test_layout_avoid() -> void:
	var before := failures.size()
	var view := Vector2(844, 390)
	var quest := Rect2(422, 34, 240, 72)
	var avoid_quest: Array[Rect2] = [quest]
	var one: Array = [{"anchor": Vector2(540, 120), "w": 80.0, "h": 22.0, "priority": 1}]
	var a: Array = UT.layout_labels(one, view, avoid_quest)
	_expect(a.size() == 1, "layout_avoid a: one label off the card -> %d rows" % a.size())
	if a.size() == 1:
		var r: Rect2 = (a[0] as Dictionary)["rect"]
		var far := absf(r.end.y - 120.0)
		_expect(not r.intersects(quest.grow(2.0)), "layout_avoid a: label %s stays off the quest card %s" % [r, quest])
		_expect(Rect2(Vector2.ZERO, view).encloses(r), "layout_avoid a: label %s inside the view %s" % [r, view])
		_expect(far <= (22.0 + UT.SPACE * 0.5) * 4.0, "layout_avoid a: label ends %.1f px under its anchor (at most %.1f)" % [far, (22.0 + UT.SPACE * 0.5) * 4.0])
	var inside: Array = [{"anchor": Vector2(540, 70), "w": 80.0, "h": 22.0, "priority": 1}]
	var b: Array = UT.layout_labels(inside, view, avoid_quest)
	_expect(b.is_empty(), "layout_avoid b: a label anchored inside the card is dropped (%d rows)" % b.size())
	var c: Array = UT.layout_labels(inside, view, [] as Array[Rect2])
	_expect(c.size() == 1, "layout_avoid c: the same label with no avoid is placed (%d rows)" % c.size())
	var crowd: Array = [
		{"anchor": Vector2(300, 200), "w": 80.0, "h": 22.0, "priority": 3},
		{"anchor": Vector2(300, 200), "w": 80.0, "h": 22.0, "priority": 2},
		{"anchor": Vector2(300, 200), "w": 80.0, "h": 22.0, "priority": 1},
	]
	var block: Array[Rect2] = [Rect2(250, 150, 100, 30)]
	var d: Array = UT.layout_labels(crowd, view, block)
	_expect(d.size() == 3, "layout_avoid d: three labels on one anchor all placed (%d rows)" % d.size())
	var rects: Array[Rect2] = []
	for row in d:
		rects.append((row as Dictionary)["rect"] as Rect2)
	for i in rects.size():
		_expect(not rects[i].intersects(block[0]), "layout_avoid d: label %s clears the HUD block %s" % [rects[i], block[0]])
		for j in range(i + 1, rects.size()):
			_expect(not rects[i].intersects(rects[j]), "layout_avoid d: labels %s and %s do not overlap" % [rects[i], rects[j]])
	if failures.size() == before:
		print("[t_ui] ok layout_avoid single=%s inside_dropped=%s three=%d" % [a.size(), b.is_empty(), d.size()])

## Guards: a survivor holds the highest title at or under their level, and a new survivor holds the
## level-1 title from character creation (review: a new survivor showed no title).
func _test_current_title() -> void:
	var before := failures.size()
	var rows: Array = [
		[0, ""], [1, "Venture into the World"], [2, "Venture into the World"], [3, "Castaway No More"],
		[4, "Castaway No More"], [5, "Camp Builder"], [19, "Wild Lands Veteran"], [20, "Frontier Legend"],
		[99, "Frontier Legend"],
	]
	for row in rows:
		var level: int = row[0]
		var want: String = row[1]
		var got: String = LD.current_title(level)
		_expect(got == want, "current_title(%d) = \"%s\", want \"%s\"" % [level, got, want])
	var world: Node = get_root().get_node("World")
	var was: int = world.pioneer_level
	world.pioneer_level = 0
	var fresh: String = LD.current_title(LD.player_level())
	_expect(fresh == "Venture into the World", "a new survivor (stored level 0) holds \"Venture into the World\" (got \"%s\")" % fresh)
	world.pioneer_level = was
	if failures.size() == before:
		print("[t_ui] ok current_title %d levels, new survivor holds \"%s\"" % [rows.size(), fresh])

## Guards: a short desktop browser window keeps the desktop canvas, while the same shape on a
## touchscreen is a landscape phone (review: a 1200x480 browser got the phone layout).
func _test_desktop_short_window() -> void:
	var before := failures.size()
	var desktop: Vector2i = DM.logical_size(Vector2i(1200, 480), 1.0, 0.0, false)
	_expect(desktop == DM.DESIGN, "1200x480 without a touchscreen -> %s, want %s" % [desktop, DM.DESIGN])
	_expect(not UT.is_compact(Vector2(desktop)), "the desktop 1200x480 canvas %s is not compact" % desktop)
	var touch: Vector2i = DM.logical_size(Vector2i(1200, 480), 1.0, 0.0, true)
	_expect(UT.is_compact(Vector2(touch)), "1200x480 on a touchscreen -> %s is compact" % touch)
	var land: Vector2i = DM.logical_size(Vector2i(844, 390), 1.0, 0.0, true)
	_expect(land == Vector2i(844, 390), "844x390 on a touchscreen -> %s, want 844x390" % land)
	_expect(DM.handheld(), "a native (non-web) run is handheld, so --resolution 844x390 stands in for a phone")
	if failures.size() == before:
		print("[t_ui] ok desktop_short_window desktop=%s compact=false touch=%s compact=true 844x390=%s handheld=%s" % [desktop, touch, land, DM.handheld()])

## Share of an icon's pixels that are opaque (alpha > 0.5); 0 when the icon is missing.
func _opaque_share(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	var img := tex.get_image()
	if img == null or img.is_empty():
		return 0.0
	if img.is_compressed():
		img.decompress()
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())
