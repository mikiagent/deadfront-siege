extends SceneTree
## W1-ICONART checks: rendered PNG contract, manifest, rarity coverage, ItemArt fallback,
## ArtSlot overflow. Run: Godot --headless --path game --script res://tests/t_iconart.gd

var failures: Array[String] = []
var _done := false
# ItemArt/ArtSlot reference the Data autoload, so they load at runtime, after autoloads exist.
var IA: GDScript
var II: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IA = load("res://scripts/ui/item_art.gd") as GDScript
	II = load("res://scripts/ui/item_icons.gd") as GDScript
	_test_pngs_and_manifest()
	_test_rarity_covers_items()
	_test_fallback()
	_test_slot_overflow()
	_test_slot_states()
	_test_mipmaps()
	_test_stretch()
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
	# Review 2026-10-20 (4): stone_knife's dark blade has low contrast on the slot interior.
	for id in ["iron_ingot", "steel_ingot", "ingot", "black_iron", "obsidian", "berry", "burnt_food", "mango", "fish", "stone_knife"]:
		_check(str(items.get(id, {}).get("replace", "")) != "", "%s carries a replace mark" % id)
	for id in [&"copper_ingot", &"bronze_ingot", &"iron_ingot", &"steel_ingot", &"straw_roll_kit"]:
		_check(IA.is_rendered(id), "%s has rendered art" % id)
	# Review 2026-10-20 (4): an exact-equality check broke whenever another package added an item.
	# 'missing' is regenerated on every render run; between runs it may lag new items, which still
	# show their white symbol. It must hold no stale ids, and an unrendered item with no symbol
	# at all (it would show the _unknown silhouette) must be listed.
	var data_items: Dictionary = get_root().get_node("Data").items
	var missing: Array = man.get("missing", [])
	var unrendered := 0
	for id: String in missing:
		_check(data_items.has(StringName(id)) and not IA.is_rendered(StringName(id)), "manifest 'missing' id %s is a real unrendered item" % id)
	for id: StringName in data_items.keys():
		if IA.is_rendered(id):
			continue
		unrendered += 1
		_check(II.path_for(id) != "" or missing.has(str(id)), "%s has no render and no symbol but is not in manifest 'missing'" % id)
	print("[t_iconart] pngs=%d missing=%d unrendered=%d" % [n, missing.size(), unrendered])

func _test_rarity_covers_items() -> void:
	var order: Array = IA.rarity_order()
	_check(order.size() == 5, "five rarity tiers")
	# Read the JSON itself: rarity() defaults to common and would hide a missing entry.
	var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IA.RARITY_PATH)).get("items", {})
	for id in get_root().get_node("Data").items.keys():
		# Kept strict on purpose: an unlisted item would silently rim as common.
		_check(listed.has(str(id)), "%s listed in item_rarity.json (give it a tier there)" % id)
		_check(order.has(str(listed.get(str(id), ""))), "%s has a known rarity" % id)

func _test_fallback() -> void:
	var tex: Texture2D = IA.texture_for(&"no_such_id")
	_check(tex != null and tex.resource_path == IA.UNKNOWN, "no_such_id falls back to the _unknown silhouette (%s)" % (tex.resource_path if tex else "null"))
	# Review 2026-10-20 (4): a non-null check alone would pass a wrong texture.
	var sym_id := &""
	for id: StringName in get_root().get_node("Data").items.keys():
		if not IA.is_rendered(id) and II.path_for(id) != "":
			sym_id = id
			break
	_check(sym_id != &"", "some unrendered item has a symbol to test the fallback with")
	if sym_id != &"":
		var st: Texture2D = IA.texture_for(sym_id)
		_check(st != null and st.resource_path == II.path_for(sym_id), "unrendered %s resolves to its ItemIcons symbol" % sym_id)
	var rt: Texture2D = IA.texture_for(&"steel_ingot")
	_check(rt != null and rt.resource_path == IA.RENDER_DIR + "steel_ingot.png", "rendered steel_ingot resolves to its render")
	_check(not IA.is_rendered(&"no_such_id"), "no_such_id is not rendered")
	_check(IA.rim_color(&"no_such_id") == IA.color_for_rarity(&"common"), "unknown item rims as common")
	# Review 2026-10-19: lookup must be exact-case on every platform, and junk ids must not be cached.
	_check(IA.is_rendered(&"steel_ingot") and not IA.is_rendered(&"STEEL_INGOT"), "is_rendered is case-sensitive")
	var before: int = (IA._cache as Dictionary).size()
	for i in 50:
		IA.texture_for(StringName("junk_%d" % i))
		IA.content_rect(StringName("junk_%d" % i))
	_check((IA._cache as Dictionary).size() == before, "unknown ids are not cached")
	# Review 2026-10-20: a "" sentinel key made the empty slot id "rendered" and texture_for
	# tried to load render/.png. Empty slots pass &"", so it must take the quiet fallback.
	_check(not IA.is_rendered(&""), "empty id is not rendered")
	_check(IA.texture_for(&"") != null, "empty id falls back to a texture")
	IA.content_rect(&"")
	_check(not (IA._cache as Dictionary).has("") and not (IA._used as Dictionary).has(""), "empty id is not cached")
	_check(not (IA._rects as Dictionary).has(""), "manifest rects hold no empty key")

## Review 2026-10-20: focus and press were only a 1 px wider border on a flat button, and
## rarity was colour alone. Lit frames must be clearly brighter, and every tier has its own pip count.
func _test_slot_states() -> void:
	var s: Button = (load("res://scripts/ui/art_slot.gd") as GDScript).new()
	s.size = Vector2(64, 64)
	s.set_item(&"stone_knife", 1)
	var idle: StyleBoxFlat = (s._frame(false) as StyleBoxFlat).duplicate()
	var lit: StyleBoxFlat = s._frame(true)
	_check(lit.border_color.get_luminance() >= idle.border_color.get_luminance() + 0.12, "lit rim is clearly brighter")
	_check(lit.shadow_size >= idle.shadow_size + 6 and lit.shadow_color.a > idle.shadow_color.a, "lit glow is wider and stronger")
	_check(lit.border_width_top > idle.border_width_top, "lit rim is thicker")
	_check(s.PRESS_SCALE <= 0.95, "press sinks the art")
	var seen := {}
	for id: String in ["stone_knife", "copper_ingot", "steel_ingot", "raid_helm", "raid_maul"]:
		s.set_item(StringName(id), 1)
		_check(s.pips == IA.rarity_order().find(str(IA.rarity(StringName(id)))), "%s pips match its tier" % id)
		seen[s.pips] = true
	_check(seen.size() == 5, "five tiers give five pip counts (%s)" % [seen.keys()])
	_check(s.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "slot samples mipmaps")
	# Review 2026-10-20 (4): ~6 px pips at a 64 px slot sat at the legibility floor. Pips are floored
	# in physical px and climb the left rim, so they never run into a right-aligned "x999".
	var font: Font = s.get_theme_default_font()
	for id: StringName in [&"heavy_snare", &"raid_maul"]:
		s.set_item(id, 999)
		var h: float = s.pip_half()
		_check(h >= s.PIP_PX, "%s pip half-size %.1f >= %.0f px (outside the tree the scale is 1)" % [id, h, s.PIP_PX])
		var fs: int = s.count_font_size()
		var w: float = font.get_string_size("x999", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base: float = s.cell().end.y - 6.0
		var count_box := Rect2(s.size.x - w - 6.0, base - font.get_ascent(fs), w, font.get_ascent(fs) + font.get_descent(fs))
		for c: Vector2 in s.pip_centres():
			var pip_box := Rect2(c - Vector2(h + 1.5, h + 1.5), Vector2(h + 1.5, h + 1.5) * 2.0)
			_check(not pip_box.intersects(count_box), "%s pip %s clear of the x999 count %s" % [id, pip_box, count_box])
			_check(s.cell().encloses(pip_box), "%s pip %s inside the frame" % [id, pip_box])
	# Review 2026-10-20 (4): dark items vanished on the near-black interior.
	_check(s.INTERIOR.get_luminance() >= UiTokens.INK_SOLID.get_luminance() + 0.05, "slot interior sits a step above INK_SOLID")
	s.free()

## Review 2026-10-20: 256 px art at ~60 px with no mipmaps risks shimmer on noisy textures.
func _test_mipmaps() -> void:
	var off: Array[String] = []
	for f in DirAccess.get_files_at(IA.RENDER_DIR):
		if f.ends_with(".png") and not FileAccess.get_file_as_string(IA.RENDER_DIR + f + ".import").contains("mipmaps/generate=true"):
			off.append(f)
	_check(off.is_empty(), "every render imports with mipmaps: %s" % ", ".join(off))
	var img: Image = (load(IA.RENDER_DIR + "fish.png") as Texture2D).get_image()
	_check(img != null and img.has_mipmaps(), "imported fish texture carries mipmaps")

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
	# Review 2026-10-20 (4): a 64x120 slot lifted every item only 6-9 %; the rise is measured
	# against the framed square cell, so tall and wide slots must hold the band too.
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IA.RENDER_DIR + "manifest.json"))
	for sz: Vector2 in [Vector2(80, 80), Vector2(64, 120), Vector2(140, 64), Vector2(64, 64)]:
		s.size = sz
		var c: Rect2 = s.cell()
		_check(c.size.y <= c.size.x + 0.5 and c.size.y >= minf(sz.x, sz.y) - 0.5, "%s slot frames a cell no taller than wide (%s)" % [sz, c])
		var low: Array[String] = []
		for id: String in man.get("items", {}):
			s.set_item(StringName(id), 1)
			var ar: Rect2 = s.art_rect()
			var wl: float = (c.position.y - ar.position.y) / c.size.y
			if wl < 0.12 - 0.005 or wl > 0.20 + 0.005 or ar.position.x < -0.5 or ar.end.x > sz.x + 0.5:
				low.append("%s(lift %.2f, x %.1f..%.1f)" % [id, wl, ar.position.x, ar.end.x])
		_check(low.is_empty(), "%s: every item rises 12-20 %% above the frame inside the side rims: %s" % [sz, ", ".join(low)])
	s.size = Vector2(80, 80)
	s.set_item(&"raid_maul", 1)
	var lift: float = -s.art_rect().position.y / s.size.y
	_check(lift >= 0.12 and lift <= 0.20, "tall raid_maul rises 12-20 %% above the slot (got %.2f)" % lift)
	_check(s.count_font_size() >= 14, "count font floor holds outside the tree")
	s.free()

## Review 2026-10-20 (4): get_screen_transform() leaves out the canvas_items stretch (1.0 in an
## 844x390 window where the stretch is 0.433), so the count and pip floors never applied on a
## phone. Halve the root stretch and check what lands on screen.
func _test_stretch() -> void:
	var root := get_root()
	var old := root.content_scale_factor
	# The headless window is tiny, so its stretch is not 1: scale the factor to land on 0.5.
	root.content_scale_factor = old * 0.5 / maxf(root.get_final_transform().get_scale().y, 0.001)
	var s: Button = (load("res://scripts/ui/art_slot.gd") as GDScript).new()
	s.size = Vector2(130, 130)  # the lab's slot at 844x390
	root.add_child(s)
	s.set_item(&"raid_maul", 12)
	var want: float = root.get_final_transform().get_scale().y
	var k: float = s.screen_scale()
	print("[t_iconart] stretch final=%.3f slot=%.3f" % [want, k])
	_check(absf(k - 0.5) < 0.01 and absf(k - want) < 0.01, "slot scale follows the window stretch (%.3f vs %.3f)" % [k, want])
	_check(s.count_font_size() * k >= s.COUNT_PX - 0.5, "count %.1f px on screen >= 14 under the stretch" % (s.count_font_size() * k))
	_check(s.pip_half() * k >= s.PIP_PX - 0.05, "pip half-size %.1f px on screen >= 4 under the stretch" % (s.pip_half() * k))
	s.free()
	root.content_scale_factor = old
