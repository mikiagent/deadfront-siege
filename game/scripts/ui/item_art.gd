class_name ItemArt
extends RefCounted
## Rendered item art (assets/icons/render, built by tools/render_icons.py) plus rarity rims.
## Lookup order: rendered PNG, then the white ItemIcons symbol, then the _unknown silhouette.

const RENDER_DIR := "res://assets/icons/render/"
const RARITY_PATH := "res://data/item_rarity.json"
const UNKNOWN := RENDER_DIR + "_unknown.png"

static var _rarity: Dictionary = {}
static var _cache: Dictionary = {}
static var _used: Dictionary = {}
static var _rects: Dictionary = {}  # id -> [x, y, w, h] from manifest.json, written at render time
# A flag, not a sentinel key: a "" key made the empty slot id look rendered (review 2026-10-20).
static var _rects_loaded := false

static func _load_rects() -> void:
	if _rects_loaded:
		return
	_rects_loaded = true  # parse once even when the manifest is missing
	var path := RENDER_DIR + "manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var items: Dictionary = parsed.get("items", {})
		for k: String in items:
			_rects[k] = items[k].get("rect", [])

static func _load_rarity() -> void:
	if not _rarity.is_empty():
		return
	if FileAccess.file_exists(RARITY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RARITY_PATH))
		if parsed is Dictionary:
			_rarity = parsed
	if _rarity.is_empty():
		_rarity = {"items": {}, "colors": {}, "default": "common"}

## True when the item has its own rendered PNG (not a symbol fallback).
## Looked up in the manifest, not the filesystem: macOS paths are case-insensitive, so
## "STEEL_INGOT" would resolve on desktop and fail on case-sensitive export targets.
static func is_rendered(id: StringName) -> bool:
	_load_rects()
	return _rects.has(str(id)) and not str(id).begins_with("_")

static func texture_for(id: StringName) -> Texture2D:
	var key := str(id)
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if is_rendered(id):
		tex = load(RENDER_DIR + key + ".png") as Texture2D
	if tex == null and Data.item(id) != null:
		tex = ItemIcons.texture(id)
	if tex == null and ResourceLoader.exists(UNKNOWN):
		tex = load(UNKNOWN) as Texture2D
	if is_rendered(id) or Data.item(id) != null:  # only real ids, so arbitrary ids cannot grow the cache
		_cache[key] = tex
	return tex

## Opaque part of the texture in texture pixels, so slots can fit the object, not the padding.
## Rendered items read it from the manifest; only symbol fallbacks pay a GPU readback.
static func content_rect(id: StringName) -> Rect2:
	var key := str(id)
	if _used.has(key):
		return _used[key]
	_load_rects()
	var tex := texture_for(id)
	var r := Rect2()
	var mr: Array = _rects.get(key, []) if is_rendered(id) else []
	if mr.size() == 4 and mr[2] > 0 and mr[3] > 0:
		r = Rect2(mr[0], mr[1], mr[2], mr[3])
	elif tex:
		r = Rect2(Vector2.ZERO, tex.get_size())
		var img := tex.get_image()
		if img and not img.is_compressed():
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				r = Rect2(used)
	if is_rendered(id) or Data.item(id) != null:
		_used[key] = r
	return r

static func rarity(id: StringName) -> StringName:
	_load_rarity()
	var items: Dictionary = _rarity.get("items", {})
	return StringName(str(items.get(str(id), _rarity.get("default", "common"))))

static func rarity_order() -> Array:
	_load_rarity()
	return _rarity.get("order", ["common"])

static func rim_color(id: StringName) -> Color:
	return color_for_rarity(rarity(id))

static func color_for_rarity(r: StringName) -> Color:
	_load_rarity()
	var colors: Dictionary = _rarity.get("colors", {})
	return Color.html(str(colors.get(str(r), "#a8adb3")))
