class_name UiIcons
extends RefCounted
## White action and HUD icons: hand-drawn SVGs in assets/icons/ui, one per action id in
## data/ui_icons.json. Colour = things (ItemIcons), white = actions (this).
## `icon()` never returns null for a non-empty id: unknown ids get the fallback sparkle.
## (Named icon(), not get(): a static get() would shadow Object.get and does not compile.)

const MANIFEST := "res://data/ui_icons.json"
const DIR := "res://assets/icons/ui/"

static var _manifest: Dictionary = {}
static var _cache: Dictionary = {}

static func _load() -> void:
	if not _manifest.is_empty():
		return
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			_manifest = parsed
	if _manifest.is_empty():
		push_warning("[ui_icons] %s missing or invalid" % MANIFEST)
		_manifest = {"icons": {}, "glyphs": {}}

## SVG path for an action id, "" when the id is unknown.
static func path_for(id: StringName) -> String:
	_load()
	return str((_manifest.get("icons", {}) as Dictionary).get(str(id), ""))

## Texture for an action id; unknown ids get the fallback icon, "" gets null.
static func icon(id: StringName) -> Texture2D:
	if id == &"":
		return null
	if _cache.has(id):
		return _cache[id]
	var p := path_for(id)
	if p == "":
		push_warning("[ui_icons] no icon for '%s', using fallback" % id)
		p = path_for(StringName(str(_manifest.get("fallback", "action"))))
	var tex: Texture2D = load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null
	_cache[id] = tex
	return tex

## Icon for a legacy emoji/symbol glyph still set on a HexButton (migration aid), null if none.
static func for_glyph(glyph: String) -> Texture2D:
	_load()
	var id := str((_manifest.get("glyphs", {}) as Dictionary).get(glyph, ""))
	return icon(StringName(id)) if id != "" else null

## White part icon for a carcass part's item id (data/ui_icons.json "parts"), null when it has none.
static func for_part(item_id: StringName) -> Texture2D:
	_load()
	var id := str((_manifest.get("parts", {}) as Dictionary).get(str(item_id), ""))
	return icon(StringName(id)) if id != "" else null
