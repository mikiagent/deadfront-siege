class_name UiSymbols
extends RefCounted
## White action symbols built from item icons (split out of UiTokens, which keeps constants and sizes).

static var _cache: Dictionary = {}

## White silhouette of a texture (alpha kept, RGB dropped). HUD commands, menu actions and
## controls are monochrome white; system emoji render in colour on macOS/iOS, so action
## glyphs use these instead. Cached per source texture.
static func white_symbol(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var key := source.resource_path if source.resource_path != "" else str(source.get_rid())
	if _cache.has(key):
		return _cache[key] as Texture2D
	var image := source.get_image()
	if image == null or image.is_empty():
		return source
	image = image.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, image.get_pixel(x, y).a))
	var white := ImageTexture.create_from_image(image)
	_cache[key] = white
	return white

## White symbol for the first id in `ids` that has an icon (item ids from icons_manifest.json).
static func symbol(ids: Array) -> Texture2D:
	for id in ids:
		var tex := ItemIcons.texture(StringName(str(id)))
		if tex:
			return white_symbol(tex)
	return null
