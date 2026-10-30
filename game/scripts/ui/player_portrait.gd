class_name PlayerPortrait
extends RefCounted
## Portraits for HUD labels (spec 18's domain banner). This survivor's is PortraitService.of_player(),
## the one portrait every screen shows (CHARCREATE's headshot of the look, drawn again when the look
## changes); an owner this client has no look for (other players, until the server sends appearances)
## gets a neutral silhouette.

const SIZE := 128
const BACKDROP := Color("#3B3A2C")

static var _silhouette: ImageTexture

## The owner's portrait: yours (the silhouette until PortraitService's first render lands), anyone
## else's the silhouette. HuntHud redraws every frame, so a finished render shows on the next one.
static func texture_for(owner: Dictionary, _host: Node) -> Texture2D:
	var emblem := str(owner.get("emblem", ""))
	if emblem != "" and ResourceLoader.exists(emblem):
		return load(emblem) as Texture2D  # a town's picture (TOWNPOLISH2)
	var mine: Texture2D = PortraitService.of_player() if bool(owner.get("own", false)) else null
	return mine if mine else silhouette()

## Head and shoulders in grey on the portrait backdrop.
static func silhouette() -> Texture2D:
	if _silhouette == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		img.fill(BACKDROP)
		var ink := Color(0.60, 0.58, 0.52)
		for y in SIZE:
			for x in SIZE:
				var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(SIZE)
				var head := p.distance_to(Vector2(0.5, 0.40)) < 0.18
				var shoulders := p.y > 0.64 and Vector2((p.x - 0.5) / 0.36, (p.y - 0.98) / 0.32).length() < 1.0
				if head or shoulders:
					img.set_pixel(x, y, ink)
		img.generate_mipmaps()
		_silhouette = ImageTexture.create_from_image(img)
	return _silhouette
