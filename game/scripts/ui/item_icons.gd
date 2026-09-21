class_name ItemIcons
extends RefCounted
## One lookup for item icons: data/icons_manifest.json (icons, aliases, category_fallback).
## Symbols come from game-icons.net (assets/icons/sym, CC BY 3.0, credits there).

static var _manifest: Dictionary = {}
static var _cache: Dictionary = {}

static func _load() -> void:
	if not _manifest.is_empty():
		return
	var path := "res://data/icons_manifest.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			_manifest = parsed
	if _manifest.is_empty():
		_manifest = {"icons": {}}

static func path_for(id: StringName) -> String:
	_load()
	var key := str(id)
	var icons: Dictionary = _manifest.get("icons", {})
	var aliases: Dictionary = _manifest.get("aliases", {})
	var p := str(icons.get(key, ""))
	if p == "" and aliases.has(key):
		p = str(icons.get(str(aliases[key]), ""))
	if p == "":
		var def := Data.item(id)
		if def:
			var fb: Dictionary = _manifest.get("category_fallback", {})
			for cat in def.categories:
				if fb.has(str(cat)):
					p = str(icons.get(str(fb[str(cat)]), ""))
					if p != "":
						break
	return p

static func texture(id: StringName) -> Texture2D:
	var key := str(id)
	if _cache.has(key):
		return _cache[key]
	var p := path_for(id)
	var tex: Texture2D = null
	if p != "" and ResourceLoader.exists(p):
		tex = load(p) as Texture2D
		# Menus and field actions share the same Durango-style visual language:
		# recognizable silhouettes, never multicolour inventory art.
		tex = HexButton._white_symbol(tex)
	_cache[key] = tex
	return tex

## Apply icon-on-top + caption styling to a slot button.
static func style_slot(b: Button, id: StringName, caption: String) -> void:
	var tex := texture(id)
	b.icon = tex
	if tex:
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 36)
		b.text = caption
	else:
		b.text = "%s\n%s" % [id, caption]
