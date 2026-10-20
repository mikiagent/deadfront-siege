extends SceneTree
## W1-UIICONS: every id in data/ui_icons.json resolves to an existing SVG; every SVG is white
## single-colour on the 64 grid with the house stroke weights, inside the canvas and optically
## centred; every inventoried action, status and skill tree has an icon; every emoji or symbol
## in a UI string literal is mapped to an icon or listed as typographic; UiIcons falls back safely.

const MANIFEST := "res://data/ui_icons.json"
const DIR := "res://assets/icons/ui/"
const WHITE := ["#FFFFFF", "#ffffff", "#FFF", "#fff", "white", "none"]
const STROKE_WIDTHS := ["5", "1.5"]  # line weight, solid-edge softening
const MAX_OPTICAL_OFFSET := 3.0      # optical centre vs grid centre, in 64-grid units (~1 px at 24 px)
## The action inventory (report: docs/orchestration/reports/claude-mmo-w1-uiicons.md).
const INVENTORY := [
	"menu", "animals", "build", "skills", "eat", "quick_food", "inspect", "debug",
	"hands", "fists", "swap", "tool_none", "tool_axe", "tool_pick", "tool_knife", "tool_hoe",
	"claim", "harbour", "dismount", "catapult_stone", "catapult_toxin", "fire_ranged", "coat_weapon",
	"rope_snare", "heavy_snare", "drink", "wash", "sleep", "cook", "cauterise", "loot", "warp", "pen",
	"attack", "auto", "chase", "hold", "tackle", "kick", "roll", "net", "capture", "end_combat", "feed", "tame",
	"sic", "heel", "guard", "stance", "toxin", "siege", "fire",
	"chop", "mine", "pick", "dig", "fish", "butcher",
	"craft", "craft_hand", "station_workbench", "station_bonfire", "station_campfire", "station_drying_rack",
	"station_crock_pot", "station_mortar", "station_stone_grill", "station_steamer", "station_well",
	"rotate", "place_rotate", "confirm", "place_confirm", "done", "cancel", "place_cancel", "place", "pack_up", "layout", "blocked",
	"bag", "map", "save", "settings", "close", "back", "zoom_in", "zoom_out", "market", "chat", "notice",
	"sound", "mute", "aid", "use", "action", "equip", "lock", "unlock", "store", "take_all",
	"summon", "dismiss", "feed_pet", "recall_camp", "warp_home", "harbour_routes",
	"pioneer_xp", "t_stones", "meadow", "forest", "rocky", "riverside", "coastal",
]
## Scripts whose string literals may carry HUD glyphs.
const SCAN_DIRS := ["res://scripts/ui", "res://scripts/world"]
const SCAN_FILES := ["res://scripts/player/player.gd", "res://scripts/skills/skill_state.gd"]

var failures: Array[String] = []
var _icons: Dictionary = {}
var _m: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_expect(parsed is Dictionary, "ui_icons.json parses")
	if parsed is Dictionary:
		_m = parsed
		_icons = _m.get("icons", {})
		_test_ids_resolve()
		_test_svgs()
		_test_inventory()
		_test_glyph_scan()
		_test_loader()
	if failures.is_empty():
		print("[t_uiicons] PASS ids=%d files=%d glyphs=%d" % [_icons.size(), _svg_files().size(), (_m.get("glyphs", {}) as Dictionary).size()])
		quit(0)
	else:
		for f in failures:
			print("[t_uiicons] FAIL %s" % f)
		quit(1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _svg_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".svg"):
			out.append(f)
	return out

func _test_ids_resolve() -> void:
	_expect(_icons.size() >= 48, "at least 48 icon ids (%d)" % _icons.size())
	_expect(_icons.has(str(_m.get("fallback", ""))), "fallback id has an icon")
	var used := {}
	for id in _icons:
		var p := str(_icons[id])
		_expect(p.begins_with(DIR) and p.ends_with(".svg"), "%s points into %s (%s)" % [id, DIR, p])
		_expect(FileAccess.file_exists(p), "%s -> %s exists" % [id, p])
		used[p.get_file()] = true
	for f in _svg_files():
		_expect(used.has(f), "%s is mapped by some id" % f)
	_expect(_svg_files().size() >= 48, "at least 48 SVG files (%d)" % _svg_files().size())

func _test_svgs() -> void:
	var paint := RegEx.create_from_string("(fill|stroke|color|stop-color)\\s*[=:]\\s*\"?([^\";\\s>]+)")
	var widths := RegEx.create_from_string("stroke-width\\s*=\\s*\"([^\"]+)\"")
	for f in _svg_files():
		var txt := FileAccess.get_file_as_string(DIR + f)
		_expect(txt.contains("viewBox=\"0 0 64 64\""), "%s is on the 64 grid" % f)
		for bad in ["<style", "style=", "opacity", "url(", "<image", "<text", "currentColor", "gradient"]:
			_expect(not txt.contains(bad), "%s has no '%s'" % [f, bad])
		for m in paint.search_all(txt):
			_expect(m.get_string(2) in WHITE, "%s paints only white (%s=%s)" % [f, m.get_string(1), m.get_string(2)])
		for m in widths.search_all(txt):
			_expect(m.get_string(1) in STROKE_WIDTHS, "%s stroke-width %s is a house weight" % [f, m.get_string(1)])
		_test_pixels(f, txt)

## Rasterise at 64 px with the engine's own SVG renderer: every visible pixel is white, the
## drawing stays inside the canvas, and its optical centre (mean of the bounding-box centre and
## the alpha centroid, so heavy bases and tall tips both count) sits on the grid centre.
func _test_pixels(f: String, txt: String) -> void:
	var img := Image.new()
	_expect(img.load_svg_from_string(txt, 1.0) == OK, "%s rasterises" % f)
	if img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	var sum := Vector2.ZERO
	var mass := 0.0
	var lo := Vector2(64, 64)
	var hi := Vector2(-1, -1)
	var off_white := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.02:
				continue
			if c.a > 0.5 and minf(c.r, minf(c.g, c.b)) < 0.97:
				off_white += 1
			sum += Vector2(x + 0.5, y + 0.5) * c.a
			mass += c.a
			if c.a > 0.5:
				lo = lo.min(Vector2(x, y))
				hi = hi.max(Vector2(x, y))
	_expect(off_white == 0, "%s renders white only (%d off-white pixels)" % [f, off_white])
	_expect(mass > 200.0, "%s has visible ink" % f)
	_expect(lo.x >= 2 and lo.y >= 2 and hi.x <= 61 and hi.y <= 61, "%s stays inside the canvas (%s..%s)" % [f, lo, hi])
	if mass > 0.0:
		var optical := (sum / mass + (lo + hi + Vector2.ONE) * 0.5) * 0.5 - Vector2(32, 32)
		_expect(optical.length() <= MAX_OPTICAL_OFFSET, "%s is optically centred (off by %.1f)" % [f, optical.length()])

func _test_inventory() -> void:
	for id in INVENTORY:
		_expect(_icons.has(id), "inventoried action %s has an icon" % id)
	var statuses: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/statuses.json"))
	for s in (statuses as Dictionary).get("statuses", []):
		_expect(_icons.has(str((s as Dictionary).get("id", ""))), "status %s has an icon" % (s as Dictionary).get("id", ""))
	var trees: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/trees.json"))
	for t in (trees as Dictionary).get("trees", {}):
		_expect(_icons.has(str(t)), "skill tree %s has an icon" % t)

## Every non-ASCII symbol inside a string literal of a HUD script is either an icon (via the
## glyphs table) or plain typography; comments are ignored.
func _test_glyph_scan() -> void:
	var glyphs: Dictionary = _m.get("glyphs", {})
	var typo: Array = _m.get("typographic", [])
	for g in glyphs:
		_expect(_icons.has(str(glyphs[g])), "glyph %s maps to a known id (%s)" % [g, glyphs[g]])
	var files := PackedStringArray(SCAN_FILES)
	for d in SCAN_DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				files.append(d.path_join(f))
	var strings := RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
	var found := 0
	for path in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			for m in strings.search_all(_strip_comment(lines[i])):
				for ch in m.get_string():
					if ch.unicode_at(0) < 0x2010 or (ch.unicode_at(0) >= 0xFE00 and ch.unicode_at(0) <= 0xFE0F):
						continue
					found += 1
					_expect(glyphs.has(ch) or typo.has(ch), "%s:%d symbol %s (U+%04X) has no icon mapping" % [path.get_file(), i + 1, ch, ch.unicode_at(0)])
	_expect(found > 20, "the scan sees the legacy glyphs (%d)" % found)

func _strip_comment(line: String) -> String:
	var in_str := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if ch == "\\" and in_str:
			i += 2
			continue
		if ch == "\"":
			in_str = not in_str
		elif ch == "#" and not in_str:
			return line.substr(0, i)
		i += 1
	return line

func _test_loader() -> void:
	for id in _icons:
		var tex := UiIcons.icon(StringName(id))
		_expect(tex != null, "UiIcons.icon(%s) loads" % id)
	var fb := UiIcons.icon(&"no_such_action_xyz")
	_expect(fb != null and fb == UiIcons.icon(StringName(str(_m.get("fallback", "")))), "unknown id falls back to the fallback icon")
	_expect(UiIcons.icon(&"") == null, "empty id gives null")
	_expect(UiIcons.for_glyph("≡") == UiIcons.icon(&"menu"), "for_glyph maps the legacy menu glyph")
	_expect(UiIcons.for_glyph("not a glyph") == null, "for_glyph returns null for unknown glyphs")
	var t := UiIcons.icon(&"menu")
	if t:
		_expect(t.get_width() == 128 and t.get_image().has_mipmaps(), "icons import at 2x with mipmaps (%dpx)" % t.get_width())
