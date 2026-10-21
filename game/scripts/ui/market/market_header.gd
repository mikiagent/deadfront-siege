class_name MarketHeader
extends Control
## `[<] Island name   test-server words   [coin 1,234] [coin+lock 20] | [X]` on the black band with
## the torn edge. Tradable T-stones are the big number (only they buy); bound ones show with a lock, and
## only when there are some, so a 20-coin wallet that cannot buy explains itself (bound ones pay
## listing fees, which Sell counts).
## No premium currency and no "+" (no monetization).

signal back_pressed
signal close_pressed

var title := ""
var badge := "" ## "" on the live server; the test server's label otherwise
var wallet := {} ## wallet.get: {wallet, bound, held}; empty = not loaded (offline shows no counters)

var back_btn: Button
var close_btn: Button
var _m := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	back_btn = _icon_button(&"back", "MarketBack")
	back_btn.pressed.connect(func () -> void: back_pressed.emit())
	close_btn = _icon_button(&"close", "MarketClose")
	close_btn.pressed.connect(func () -> void: close_pressed.emit())

## Back and close draw the references' thin "<" and X (MarketGlyphs), white.
func _icon_button(id: StringName, nm: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.tooltip_text = "Back" if id == &"back" else "Close"
	MarketTheme.bare(b)
	b.draw.connect(func () -> void:
		var g := b.size.y * 0.5
		MarketGlyphs.draw(b, id, Rect2((b.size - Vector2(g, g)) * 0.5, Vector2(g, g)), MarketTheme.ACTION))
	add_child(b)
	return b

func set_wallet(w: Dictionary) -> void:
	wallet = w
	queue_redraw()

func tradable() -> int:
	return int(wallet.get("wallet", 0)) - int(wallet.get("bound", 0)) # Ledger.tradable; held bids are outside the wallet

## The band spans the screen; back, title, pills and X keep inside `left` / `right` (the safe area).
func layout(m: Dictionary, width: float, left: float = 0.0, right: float = 0.0) -> void:
	_m = m
	var h: float = m.header_h
	size = Vector2(width, h + m.edge_h)
	var side := maxf(m.tmin, h * 0.8)
	back_btn.position = Vector2(left + m.margin, (h - side) * 0.5)
	back_btn.size = Vector2(side, side)
	close_btn.position = Vector2(width - right - m.margin - side, (h - side) * 0.5)
	close_btn.size = Vector2(side, side)
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	var h: float = _m.header_h
	draw_rect(Rect2(0, 0, size.x, h + _m.edge_h * 0.7), MarketTheme.HEADER) # black behind the band's rips
	MarketTheme.torn_edge(self, h, size.x, _m.edge_h)
	var side := close_btn.size.x
	var right: float = close_btn.position.x - _m.margin
	# Divider before X, then the pills right to left.
	MarketTheme.dotted(self, Vector2(right, h * 0.3), Vector2(right, h * 0.7), Color(0.45, 0.45, 0.42, 0.8), 4.0)
	right -= _m.margin
	if not wallet.is_empty():
		var bound := int(wallet.get("bound", 0))
		if bound > 0:
			right = _pill(right, true, MarketFormat.group(bound), h, false) - _m.margin * 0.75
		right = _pill(right, false, MarketFormat.group(tradable()), h, true) - _m.margin
	var x: float = back_btn.position.x + side + _m.margin * 0.25
	var free: float = right - x
	var tsize: int = _m.title
	var tw := minf(MarketTheme.width(title, tsize), free * (0.62 if badge != "" else 1.0))
	MarketTheme.text(self, title, x, h * 0.5, tw, tsize, MarketTheme.ACTION)
	if badge != "":
		# Honest but quiet (spec 06: never a falsely represented live market): grey words after the
		# title, not a coloured pill competing with it.
		var bx: float = x + tw + _m.margin
		MarketTheme.text(self, badge, bx, h * 0.5 + tsize * 0.12, right - bx, _m.type, MarketTheme.TEXT_2)

## A dark rounded counter ending at `right` (the grey T-stone coin, with a lock tag for bound
## ones); returns its left edge.
func _pill(right: float, bound: bool, value: String, h: float, wide: bool) -> float:
	var fs: int = _m.name
	var ph := maxf(28.0, h * 0.66)
	var isz := ph * 0.66
	var tw := MarketTheme.width(value, fs)
	var w := maxf(tw + isz + 34.0, size.x * (0.12 if wide else 0.07))
	var r := Rect2(right - w, (h - ph) * 0.5, w, ph)
	draw_style_box(MarketTheme.flat(Color(0.1, 0.1, 0.09, 0.95), Color(0.2, 0.2, 0.18, 1), 1, int(ph * 0.3)), r)
	MarketGlyphs.coin(self, Vector2(r.position.x + 8 + isz * 0.5, h * 0.5), isz * 0.5, bound)
	MarketTheme.text(self, value, r.position.x + isz + 16, h * 0.5, w - isz - 28, fs, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	return r.position.x
