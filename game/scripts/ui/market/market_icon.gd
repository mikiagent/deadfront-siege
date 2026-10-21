class_name MarketIcon
extends Control
## An item's art in the market (confirm and Sell panels; rows and cells call paint()): ItemArt's
## render or symbol fitted to the box, except a pet carrier / crate with no render yet, which the
## market draws itself (MarketGlyphs.cage) instead of the shared wireframe symbol.
# swap: INVUI ItemIcon when it reaches this base.

var id: StringName
var tint := Color.WHITE

func show_item(p_id: StringName, p_tint: Color = Color.WHITE) -> void:
	id = p_id
	tint = p_tint
	queue_redraw()

func _draw() -> void:
	if id != &"":
		paint(self, id, Rect2(Vector2.ZERO, size), tint)

## True when the market draws this id itself (a cage with no rendered icon).
static func drawn_cage(p_id: StringName) -> bool:
	return p_id in [&"tamed_animal", &"captured_animal"] and not ItemArt.is_rendered(p_id)

static func paint(ci: CanvasItem, p_id: StringName, r: Rect2, p_tint: Color = Color.WHITE) -> void:
	if drawn_cage(p_id):
		MarketGlyphs.cage(ci, p_id, r, p_tint)
		return
	var tex := ItemArt.texture_for(p_id)
	if tex == null:
		return
	var src := ItemArt.content_rect(p_id)
	var d := src.size * minf(r.size.x / src.size.x, r.size.y / src.size.y)
	ci.draw_texture_rect_region(tex, Rect2(r.get_center() - d * 0.5, d), src, p_tint)
