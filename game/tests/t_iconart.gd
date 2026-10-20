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
		# Review 2026-10-19: model (glb) art must never be restamped as the procedural placeholder tier.
		var q := str(entry.get("quality", ""))
		_check(q in ["procedural_v1", "model_v2"], "%s has a known quality tier (%s)" % [id, q])
		_check(not (script.begins_with("glb:") and q == "procedural_v1"), "%s glb art not labelled procedural_v1" % id)
		_check(not (script.begins_with("glb:/") or script.contains("/Users/") or script.contains("..")), "%s glb path is repo-relative" % id)
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
	# Review 2026-10-19: the art judge's illegible renders must be in the replacement register.
	for id in ["iron_ingot", "steel_ingot", "ingot", "black_iron", "obsidian", "berry", "burnt_food", "mango", "fish"]:
		_check(str(items.get(id, {}).get("replace", "")) != "", "%s carries a replace mark" % id)
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
	# Review 2026-10-19: lookup must be exact-case on every platform, and junk ids must not be cached.
	_check(IA.is_rendered(&"steel_ingot") and not IA.is_rendered(&"STEEL_INGOT"), "is_rendered is case-sensitive")
	var before: int = (IA._cache as Dictionary).size()
	for i in 50:
		IA.texture_for(StringName("junk_%d" % i))
		IA.content_rect(StringName("junk_%d" % i))
	_check((IA._cache as Dictionary).size() == before, "unknown ids are not cached")

func _test_slot_overflow() -> void:
	var s: Button = (load("res://scripts/ui/art_slot.gd") as GDScript).new()
	s.size = Vector2(80, 80)
	s.set_item(&"steel_ingot", 2)
	var r: Rect2 = s.art_rect()
	_check(Rect2(Vector2.ZERO, s.size).has_point(r.get_center()), "wide steel_ingot art centre lies inside the slot (%s)" % r)
	_check(r.end.y <= 80.0 * 0.80 + 0.5 and r.end.y >= 80.0 * 0.60 - 0.5, "steel_ingot bottom within the floor band")
	_check(s.rim == IA.color_for_rarity(&"rare"), "steel ingot (a bulk material) rims rare, not legendary")
	# Review 2026-10-19: wide flat items never rose above the slot top and spilled past the side
	# rims. Every rendered item must rise 12-20 % and stay between the side rims.
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IA.RENDER_DIR + "manifest.json"))
	var low: Array[String] = []
	for id: String in man.get("items", {}):
		s.set_item(StringName(id), 1)
		var ar: Rect2 = s.art_rect()
		var wl: float = -ar.position.y / s.size.y
		if wl < 0.12 - 0.005 or wl > 0.20 + 0.005 or ar.position.x < -0.5 or ar.end.x > s.size.x + 0.5:
			low.append("%s(lift %.2f, x %.1f..%.1f)" % [id, wl, ar.position.x, ar.end.x])
	_check(low.is_empty(), "every item rises 12-20 %% above the slot inside the side rims: %s" % ", ".join(low))
	s.set_item(&"raid_maul", 1)
	var lift: float = -s.art_rect().position.y / s.size.y
	_check(lift >= 0.12 and lift <= 0.20, "tall raid_maul rises 12-20 %% above the slot (got %.2f)" % lift)
	_check(s.count_font_size() >= 14, "count font floor holds outside the tree")
	s.free()
