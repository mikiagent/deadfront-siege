extends SceneTree
## W1-ICONART checks: rendered PNG contract, manifest, rarity coverage, ItemArt fallback,
## ArtSlot overflow. Run: Godot --headless --path game --script res://tests/t_iconart.gd

var failures: Array[String] = []
var _done := false
# ItemArt/ArtSlot reference the Data autoload, so they load at runtime, after autoloads exist.
var IA: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IA = load("res://scripts/ui/item_art.gd") as GDScript
	_test_pngs_and_manifest()
	_test_rarity_covers_items()
	_test_fallback()
	_test_slot_overflow()
	if failures.is_empty():
		print("[t_iconart] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_iconart] FAIL %s" % f)
		quit(1)
	return true

func _check(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _test_pngs_and_manifest() -> void:
	var dir: String = IA.RENDER_DIR
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
	_check(parsed is Dictionary, "manifest.json parses")
	if not parsed is Dictionary:
		return
	var man: Dictionary = parsed
	var items: Dictionary = man.get("items", {})
	_check(man.has("rig"), "manifest has render settings")
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".png"):
			continue
		n += 1
		var id := f.get_basename()
		var entry: Dictionary = items.get(id, {})
		var script := str(entry.get("script", ""))
		_check(script.begins_with("tools/blender/items/") or script.begins_with("glb:"), "%s in manifest with source script" % id)
		var path := ProjectSettings.globalize_path(dir + f)
		_check(FileAccess.get_file_as_bytes(path).size() <= 64 * 1024, "%s <= 64 KB" % id)
		var img := Image.load_from_file(path)
		if img == null:
			_check(false, "%s loads" % id)
			continue
		_check(img.get_width() == 256 and img.get_height() == 256 and img.detect_alpha() != Image.ALPHA_NONE, "%s 256x256 RGBA" % id)
		var edge_ok := true
		for i in 256:
			for p in [Vector2i(i, 0), Vector2i(i, 255), Vector2i(0, i), Vector2i(255, i)]:
				if img.get_pixelv(p).a > 0.0:
					edge_ok = false
		_check(edge_ok, "%s edge rows transparent" % id)
		# The slot fits the manifest rect instead of reading pixels back, so it must match them.
		var used := img.get_used_rect()
		var mr: Array = entry.get("rect", [0, 0, 0, 0])  # JSON numbers are floats
		_check(mr.size() == 4 and Rect2i(int(mr[0]), int(mr[1]), int(mr[2]), int(mr[3])) == used, "%s manifest rect %s matches pixels %s" % [id, mr, used])
	_check(n >= 60, "at least 60 PNGs (got %d)" % n)
	for id in [&"copper_ingot", &"bronze_ingot", &"iron_ingot", &"steel_ingot", &"straw_roll_kit"]:
		_check(IA.is_rendered(id), "%s has rendered art" % id)
	var unrendered: Array = []
	for id: StringName in get_root().get_node("Data").items.keys():
		if not IA.is_rendered(id):
			unrendered.append(str(id))
	unrendered.sort()
	_check(man.get("missing", []) == unrendered, "manifest 'missing' lists every unrendered item (%d)" % unrendered.size())
	print("[t_iconart] pngs=%d missing=%d" % [n, unrendered.size()])

func _test_rarity_covers_items() -> void:
	var order: Array = IA.rarity_order()
	_check(order.size() == 5, "five rarity tiers")
	# Read the JSON itself: rarity() defaults to common and would hide a missing entry.
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IA.RARITY_PATH)).get("items", {})
	for id in get_root().get_node("Data").items.keys():
		_check(listed.has(str(id)), "%s listed in item_rarity.json" % id)
		_check(order.has(str(listed.get(str(id), ""))), "%s has a known rarity" % id)

func _test_fallback() -> void:
	var tex: Texture2D = IA.texture_for(&"no_such_id")
	_check(tex != null, "no_such_id falls back to a symbol texture")
	_check(not IA.is_rendered(&"no_such_id"), "no_such_id is not rendered")
	_check(IA.rim_color(&"no_such_id") == IA.color_for_rarity(&"common"), "unknown item rims as common")

func _test_slot_overflow() -> void:
	var s: Button = (load("res://scripts/ui/art_slot.gd") as GDScript).new()
	s.size = Vector2(80, 80)
	s.set_item(&"steel_ingot", 2)
	var r: Rect2 = s.art_rect()
	_check(Rect2(Vector2.ZERO, s.size).has_point(r.get_center()), "wide steel_ingot art centre lies inside the slot (%s)" % r)
	_check(absf(r.end.y - 80.0 * 0.80) < 0.5, "steel_ingot stands on the slot floor")
	_check(s.rim == IA.color_for_rarity(&"rare"), "steel ingot (a bulk material) rims rare, not legendary")
	s.set_item(&"raid_maul", 1)
	var lift: float = -s.art_rect().position.y / s.size.y
	_check(lift >= 0.12 and lift <= 0.20, "tall raid_maul rises 12-20 %% above the slot (got %.2f)" % lift)
	_check(s.count_font_size() >= 14, "count font floor holds outside the tree")
	s.free()
