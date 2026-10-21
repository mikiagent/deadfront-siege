class_name MarketRow
extends Button
## One table row = one listing = one exact instance (three single branches are three rows).
## Icon, gold name over a grey type line, "Lv. n", "cur/max" or "—", coin + price. A bonded pet
## gets the reference's "B" badge before its name; a captured one reads "Captured <species>".
# swap: INVUI ItemIcon / LevelLabel when they land.

var view: Dictionary ## the market.search result, as the server sent it
var model: Dictionary ## MarketFormat.row(view)
var own := false
var cols: Dictionary ## MarketTable.columns(): x/w per column
var _m: Dictionary

## `p_model` replaces MarketFormat.row(v) (My Market: the status in the durability column).
func setup(v: Dictionary, p_own: bool, p_cols: Dictionary, m: Dictionary, p_model: Dictionary = {}) -> void:
	view = v
	model = p_model if not p_model.is_empty() else MarketFormat.row(v)
	own = p_own
	cols = p_cols
	_m = m
	name = "Row_%s" % model.id
	tooltip_text = model.name
	MarketTheme.bare(self)
	custom_minimum_size = Vector2(0, m.row_h)

func relayout(p_cols: Dictionary, m: Dictionary) -> void:
	cols = p_cols
	_m = m
	custom_minimum_size.y = m.row_h
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var mid := h * 0.5
	if is_hovered() or has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05))
	MarketTheme.dotted(self, Vector2(8, h - 1), Vector2(size.x - 8, h - 1))
	var isz: float = _m.icon
	var tex := ItemArt.texture_for(model.icon)
	if tex:
		var src := ItemArt.content_rect(model.icon)
		var k := isz / maxf(src.size.x, src.size.y)
		var d := src.size * k
		draw_texture_rect_region(tex, Rect2(cols.icon_x + (isz - d.x) * 0.5, mid - d.y * 0.5, d.x, d.y), src, model.tint)
	var nx: float = cols.name_x
	var nw: float = cols.name_w
	var ns: int = _m.name
	var ts: int = _m.type
	var gap := (ns + ts) * 0.5 + 2.0
	var name_y := mid - gap * 0.5 - 1.0
	if model.badge:
		var r := ns * 0.62
		MarketGlyphs.badge_b(self, Vector2(nx + r, name_y), r)
		nx += r * 2.0 + 8.0
		nw -= r * 2.0 + 8.0
	var title: String = model.name + ("  ×%d" % model.count if model.count > 1 else "")
	MarketTheme.text(self, title, nx, name_y, nw, ns, MarketTheme.GOLD)
	var sub: String = model.type + ("  ·  Your listing" if own else "")
	MarketTheme.text(self, sub, cols.name_x, mid + gap * 0.5 + 1.0, cols.name_w, ts, MarketTheme.TEXT_2)
	MarketTheme.text(self, LevelDisplay.label(model.level) if model.level > 0 else LevelDisplay.NONE, cols.level_x, mid, cols.level_w, ns, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	MarketTheme.text(self, model.dur, cols.dur_x, mid, cols.dur_w, ns, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	price(self, model.price, Rect2(cols.price_x, 0, cols.price_w, h), ns)

## Coin + grouped number, centred in `r` (rows, the confirm panel).
static func price(ci: CanvasItem, value: int, r: Rect2, fs: int) -> void:
	var f := MarketTheme.font()
	var txt := MarketFormat.group(value)
	var csz := fs * 0.95
	var tw := minf(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, r.size.x - csz - 6.0)
	var x := r.position.x + (r.size.x - tw - csz - 6.0) * 0.5
	var coin := UiIcons.icon(&"t_stone")
	if coin:
		ci.draw_texture_rect(coin, Rect2(x, r.get_center().y - csz * 0.5, csz, csz), false, Color(0.82, 0.82, 0.8))
	MarketTheme.text(ci, txt, x + csz + 6.0, r.get_center().y, tw, fs, MarketTheme.TEXT)
