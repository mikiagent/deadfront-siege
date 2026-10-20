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
## Two different drawings must not share a silhouette: soft IoU of their alpha masks at 24 px.
const MASK_PX := 24
const MAX_IOU := 0.85
## Opposite-action pairs that are one drawing plus or minus a conventional mark (open shackle,
## arrow in or out, plus or minus). They sit side by side or swap in one slot, so the mark is the
## message; they still must not be identical.
const PAIRS := {"lock/unlock": 0.95, "store/take_all": 0.95, "zoom_in/zoom_out": 0.95}
## The report whose "Integrator hooks" name icon ids; each must resolve without the fallback.
const REPORT := "../docs/orchestration/reports/claude-mmo-w1-uiicons.md"

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
		_test_code_inventory()
		_test_hook_ids()
		_test_distinct()
		_test_composition()
		_test_glyph_scan()
		_test_loader()
	if failures.is_empty():
		print("[t_uiicons] PASS ids=%d files=%d glyphs=%d code_ids=%d worst_iou=%s" % [_icons.size(), _svg_files().size(), (_m.get("glyphs", {}) as Dictionary).size(), _code_ids, _worst_iou])
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

## Ids the game itself emits, read from the code and data rather than typed here: creature-plate
## status rows, crafting stations (recipes, the craft tabs, station buildings) and the context
## actions the player offers. Each must have its own entry (no fallback sparkle).
func _test_code_inventory() -> void:
	var ids := {}
	var plates := FileAccess.get_file_as_string("res://scripts/ui/creature_plates.gd")
	for pat in ["\"icon_id\"\\s*:\\s*\"([a-z_]+)\"", "_add_status\\([^,]+,[^,]+,\\s*&\"([a-z_]+)\""]:
		for m in RegEx.create_from_string(pat).search_all(plates):
			ids[m.get_string(1)] = "creature_plates.gd"
	var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json"))
	for r in (recipes as Dictionary).get("recipes", []):
		var sid: Variant = (r as Dictionary).get("station")
		ids["station_" + str(sid) if sid != null else "craft_hand"] = "recipes.json"
	var craft := FileAccess.get_file_as_string("res://scripts/ui/craft_ui.gd")
	var tabs := craft.substr(craft.find("const STATIONS"), craft.find("\n]", craft.find("const STATIONS")) - craft.find("const STATIONS"))
	_expect(tabs.length() > 40, "craft_ui.gd STATIONS found")
	for m in RegEx.create_from_string("\\[\"([a-z_]*)\", \"[^\"]+\", \"").search_all(tabs):
		ids["station_" + m.get_string(1) if m.get_string(1) != "" else "craft_hand"] = "craft_ui.gd STATIONS"
	var props: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/props_manifest.json"))
	var buildings: Dictionary = (props as Dictionary).get("buildings", {})
	for b in buildings:
		if str((buildings[b] as Dictionary).get("note", "")).contains("station"):
			ids["station_" + str(b)] = "props_manifest.json"
	var player := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	var ctx := _func_body(player, "context_actions")
	for m in RegEx.create_from_string("\"id\"\\s*:\\s*\"([a-z_]+)\"").search_all(ctx):
		ids[m.get_string(1)] = "player.context_actions"
	for line in _func_body(player, "context_action").split("\n"):
		if line.begins_with("\t\t\""):
			for m in RegEx.create_from_string("\"([a-z_]+)\"").search_all(line.substr(0, line.find(":"))):
				ids[m.get_string(1)] = "player.context_action"
	_expect(ids.size() > 30, "code inventory found the emitted ids (%d)" % ids.size())
	for id in ids:
		_expect(_icons.has(id), "%s (from %s) has its own icon, not the fallback" % [id, ids[id]])
	_code_ids = ids.size()

var _code_ids := 0

func _func_body(src: String, fname: String) -> String:
	var at := src.find("\nfunc %s(" % fname)
	if at < 0:
		failures.append("func %s not found" % fname)
		return ""
	var end := src.find("\nfunc ", at + 1)
	return src.substr(at, (end if end > 0 else src.length()) - at)

## Every `&"id"` passed to UiIcons.icon() in the report's "Integrator hooks" section resolves directly.
func _test_hook_ids() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(REPORT)
	_expect(FileAccess.file_exists(path), "report %s exists" % REPORT)
	var n := 0
	var tok := RegEx.create_from_string("&\"([a-z_]+)\"")
	var text := FileAccess.get_file_as_string(path)
	var at := text.find("\n## Integrator hooks")
	_expect(at >= 0, "report has an Integrator hooks section")
	var end := text.find("\n## ", at + 1)
	for line in text.substr(at, (end if end > 0 else text.length()) - at).split("\n"):
		if not line.contains("UiIcons.icon("):
			continue
		for m in tok.search_all(line.substr(line.find("UiIcons.icon("))):
			n += 1
			_expect(_icons.has(m.get_string(1)), "hook id %s resolves without the fallback" % m.get_string(1))
	_expect(n >= 20, "the report's hooks name icon ids (%d)" % n)

## No two drawings may read as the same shape at HUD size: rasterise each at 24 px and compare
## alpha masks (sum of min / sum of max). wet and bleed_deep once shared one silhouette.
func _test_distinct() -> void:
	var files := _svg_files()
	var masks: Array[PackedFloat32Array] = []
	for f in files:
		var img := Image.new()
		img.load_svg_from_string(FileAccess.get_file_as_string(DIR + f), MASK_PX / 64.0)
		img.convert(Image.FORMAT_RGBA8)
		var a := PackedFloat32Array()
		a.resize(MASK_PX * MASK_PX)
		for y in mini(MASK_PX, img.get_height()):
			for x in mini(MASK_PX, img.get_width()):
				a[y * MASK_PX + x] = img.get_pixel(x, y).a
		masks.append(a)
	var worst := 0.0
	var worst_pair := ""
	for i in files.size():
		for j in range(i + 1, files.size()):
			var lo := 0.0
			var hi := 0.0
			var a := masks[i]
			var b := masks[j]
			for k in a.size():
				lo += minf(a[k], b[k])
				hi += maxf(a[k], b[k])
			var iou := lo / maxf(hi, 0.001)
			var pair := "%s/%s" % [files[i].get_basename(), files[j].get_basename()]
			_expect(iou <= float(PAIRS.get(pair, MAX_IOU)), "%s and %s share a silhouette at %d px (IoU %.2f)" % [files[i], files[j], MASK_PX, iou])
			if PAIRS.has(pair) or iou <= worst:
				continue
			worst = iou
			worst_pair = pair
	_worst_iou = "%.2f %s" % [worst, worst_pair]

var _worst_iou := ""

## Pixel overlap misses one failure: the same arrangement of parts drawn a few units apart (the
## old wet and bleed_deep, IoU 0.63, were one big drop plus two small drops on the right). So
## also compare compositions: the separate parts of each drawing (area share, centre within the
## ink box, aspect and fill of each part). Three or more parts that all pair up is a fail.
const PART_MIN := 0.03     # parts below 3% of the ink are detail, not composition
const PART_AREA := 0.08    # max difference in area share for two parts to match
const PART_DIST := 0.15    # max centre distance, in ink-box units
const PART_SHAPE := 0.25   # max difference in aspect (log ratio) and in fill of the part's own box

func _test_composition() -> void:
	var comps := {}
	for f in _svg_files():
		comps[f] = _parts(FileAccess.get_file_as_string(DIR + f))
	var files := comps.keys()
	var multi := 0
	for i in files.size():
		if (comps[files[i]] as Array).size() >= 3:
			multi += 1
		for j in range(i + 1, files.size()):
			var pair := "%s/%s" % [str(files[i]).get_basename(), str(files[j]).get_basename()]
			if PAIRS.has(pair):
				continue
			_expect(not _same_parts(comps[files[i]], comps[files[j]]), "%s and %s have the same composition of parts" % [files[i], files[j]])
	_expect(multi > 15, "composition check sees drawings of 3+ parts (%d)" % multi)

## [area share, centre in the ink box, log aspect, fill] of each 4-connected part of the 64 px
## alpha mask (alpha > 0.5).
func _parts(svg: String) -> Array:
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	img.convert(Image.FORMAT_RGBA8)
	var n := 64
	var seen := PackedByteArray()
	seen.resize(n * n)
	var raw: Array = []
	var total := 0.0
	var lo := Vector2(n, n)
	var hi := Vector2(-1, -1)
	for y in n:
		for x in n:
			if seen[y * n + x] == 1 or img.get_pixel(x, y).a <= 0.5:
				continue
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			seen[y * n + x] = 1
			var area := 0
			var sum := Vector2.ZERO
			var plo := Vector2(n, n)
			var phi := Vector2(-1, -1)
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				area += 1
				sum += Vector2(p)
				plo = plo.min(Vector2(p))
				phi = phi.max(Vector2(p))
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := p + d
					if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or seen[q.y * n + q.x] == 1 or img.get_pixel(q.x, q.y).a <= 0.5:
						continue
					seen[q.y * n + q.x] = 1
					stack.append(q)
			lo = lo.min(plo)
			hi = hi.max(phi)
			var pbox := phi - plo + Vector2.ONE
			raw.append([float(area), sum / area, log(pbox.x / pbox.y), area / (pbox.x * pbox.y)])
			total += area
	var box := (hi - lo).max(Vector2.ONE)
	var out: Array = []
	for r in raw:
		if r[0] / total >= PART_MIN:
			out.append([r[0] / total, ((r[1] as Vector2) - lo) / box, r[2], r[3]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return out

func _same_parts(a: Array, b: Array) -> bool:
	if a.size() < 3 or a.size() != b.size():
		return false
	var used := {}
	for pa in a:
		var hit := -1
		for k in b.size():
			if not used.has(k) and absf(pa[0] - b[k][0]) <= PART_AREA and (pa[1] as Vector2).distance_to(b[k][1]) <= PART_DIST \
					and absf(pa[2] - b[k][2]) <= PART_SHAPE and absf(pa[3] - b[k][3]) <= PART_SHAPE:
				hit = k
				break
		if hit < 0:
			return false
		used[hit] = true
	return true

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
