extends SceneTree
## ISLANDSHAPES contact sheet: builds every roster island's landmass (IslandShape only, no runtime, so
## it runs headless in seconds) and paints a top-down map of each into one PNG grid: deep sea, the
## turquoise shelf, beach, ground by height, the river, and the non-navigable topography (rock brown,
## volcano ash) with each island's id and family underneath.
## Run: Godot --headless --path game --script res://scripts/dev/islandshapes_sheet.gd -- --out=/abs/sheet.png
## Optional --ids=a,b  --px=<cell px, default 220>.

const COLS := 5

var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var world := root.get_node("World")
	var ids: Array = []
	if args.has("ids"):
		ids = Array(str(args["ids"]).split(",", false))
	else:
		for id in world.islands.keys():
			if str(id) != "tutorial_isle":
				ids.append(str(id))
		ids.sort()
		ids.erase("home_grassland")
		ids.push_front("home_grassland")
	var px := int(args.get("px", "220"))
	var rows := int(ceil(float(ids.size()) / float(COLS)))
	var lab_h := 14
	var sheet := Image.create(COLS * px, rows * (px + lab_h), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.1))
	var shape_script: GDScript = load("res://scripts/world/island_shape.gd")
	for i in ids.size():
		var id := str(ids[i])
		var def: Dictionary = world.islands.get(id, {})
		var t0 := Time.get_ticks_msec()
		var sh = _make(shape_script, def)
		sh.compute()
		var ms := Time.get_ticks_msec() - t0
		var img := _paint(sh, px)
		var cx := (i % COLS) * px
		var cy := (i / COLS) * (px + lab_h)
		sheet.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(cx, cy))
		_label(sheet, "%s %s" % [id.left(14), sh.family], cx + 3, cy + px + 3)
		var kinds := []
		for f in sh.topo:
			kinds.append(str(f["kind"]))
		print("[sheet] %s family=%s river_arc=%.0f want=%.0f river_n=%d topo=%s shape_ms=%d south=%s" % [id, sh.family, sh.river_arc, sh.river_want(), sh.river.size(), ",".join(kinds), ms, sh.south_est])
	var out := str(args.get("out", "user://islandshapes_sheet.png"))
	sheet.save_png(out)
	print("[sheet] wrote %s" % out)
	quit(0)

## The same IslandShape.make call IslandRuntime.build makes for this island row.
func _make(shape_script: GDScript, def: Dictionary):
	var kind := str(def.get("kind", "unstable"))
	var seed := int(def.get("seed", 17 if kind == "private" else hash(str(def.get("id", "island")))))
	var legacy := kind == "private"
	var camp_a: Array = def.get("camp", [0, 0, 6])
	var harbour_a: Array = def.get("harbour", [0, 0, 12])
	var hint := Vector2(float(harbour_a[0]), float(harbour_a[2])) if def.has("harbour") else Vector2(float(camp_a[0]), float(camp_a[2]))
	var land_v: Variant = def.get("land_m", [])
	var land := Vector2(float(land_v[0]), float(land_v[1])) if land_v is Array and (land_v as Array).size() >= 2 else Vector2.ZERO
	var res := clampi(int(def.get("terrain_res", 161)), 65, 321)
	var sh = shape_script.call("make", float(def.get("size_m", 416)), seed, kind, int(def.get("tier", 10)), hint, legacy, res, str(def.get("climate", "grassland")), land, str(def.get("shape_family", "")), _keep(def))
	sh.camp_hint = Vector2(float(camp_a[0]), float(camp_a[2]))
	return sh

## IslandRuntime.keep_points, inlined: `--script` compiles before the autoloads exist.
func _keep(def: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cr: Variant = def.get("crater", null)
	if cr is Array and (cr as Array).size() >= 3:
		out.append(Vector2(float(cr[0]), float(cr[2])))
	for row in def.get("creatures", []):
		var at: Array = row.get("at", [0, 0, 0])
		if at.size() >= 3:
			out.append(Vector2(float(at[0]), float(at[2])))
	return out

func _paint(sh, px: int) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var res: int = sh.res
	for y in px:
		for x in px:
			var gx := clampi(int(float(x) / float(px) * float(res - 1) + 0.5), 0, res - 1)
			var gz := clampi(int(float(y) / float(px) * float(res - 1) + 0.5), 0, res - 1)
			var i := gx + gz * res
			var h: float = sh.heights[i]
			var c: Color
			if h < -1.5:
				c = Color(0.07, 0.20, 0.38)
			elif h < -0.05:
				c = Color(0.16, 0.62, 0.66).lerp(Color(0.07, 0.20, 0.38), clampf((-h - 0.6) / 1.2, 0.0, 1.0))
			elif h < 0.6:
				c = Color(0.86, 0.80, 0.58)
			else:
				c = Color(0.33, 0.55, 0.25).lerp(Color(0.55, 0.52, 0.36), clampf(h / 8.0, 0.0, 1.0))
			if sh.river_d[i] < sh.river_w[i] and h < 0.2:
				c = Color(0.25, 0.55, 0.85)
			if not sh.topo_mask.is_empty() and sh.topo_mask[i] == 1:
				c = Color(0.45, 0.34, 0.26).lerp(Color(0.85, 0.82, 0.78), clampf((h - 4.0) / 14.0, 0.0, 1.0))
			if sh.vslope[i] > 1.15 and h > 0.5:
				c = c.darkened(0.45)
			img.set_pixel(x, y, c)
	# The camp (orange) and the southern-most port estimate (white).
	for p in [sh.camp_hint, sh.south_est]:
		var u := int((p.x + sh.size * 0.5) / sh.size * float(px))
		var v := int((p.y + sh.size * 0.5) / sh.size * float(px))
		var col := Color(1, 0.55, 0.2) if p == sh.camp_hint else Color(1, 1, 1)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				img.set_pixel(clampi(u + dx, 0, px - 1), clampi(v + dy, 0, px - 1), col)
	return img

## A tiny 3x5 block font: the labels stay readable without a font resource in a headless run.
const GLYPHS := {
	"a": "111101111101101", "b": "110101110101110", "c": "111100100100111", "d": "110101101101110",
	"e": "111100110100111", "f": "111100110100100", "g": "111100101101111", "h": "101101111101101",
	"i": "111010010010111", "j": "001001001101111", "k": "101101110101101", "l": "100100100100111",
	"m": "101111111101101", "n": "110101101101101", "o": "111101101101111", "p": "111101111100100",
	"q": "111101101111001", "r": "110101110101101", "s": "111100111001111", "t": "111010010010010",
	"u": "101101101101111", "v": "101101101101010", "w": "101101111111101", "x": "101101010101101",
	"y": "101101111010010", "z": "111001010100111", "0": "111101101101111", "1": "010110010010111",
	"2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111",
	"6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111",
	"_": "000000000000111", " ": "000000000000000",
}

func _label(img: Image, text: String, x: int, y: int) -> void:
	var cx := x
	for ch in text.to_lower():
		var g: String = GLYPHS.get(ch, "000000000000000")
		for k in 15:
			if g[k] == "1":
				var gx := cx + (k % 3) * 2
				var gy := y + (k / 3) * 2
				for d in 4:
					var px := gx + d % 2
					var py := gy + d / 2
					if px < img.get_width() and py < img.get_height():
						img.set_pixel(px, py, Color(0.92, 0.92, 0.92))
		cx += 8
