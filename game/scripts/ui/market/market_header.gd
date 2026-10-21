class_name MarketHeader
extends Control
## `[<] Island name   [coin 1,234] [coin+lock 20] | [X]` on the black band (the torn paper under it is
## MarketScreen's sheet). Tradable T-stones are the big number (only they buy); bound ones show with a
## lock, and only when there are some, so a 20-coin wallet that cannot buy explains itself (bound
## ones pay listing fees, which Sell counts). The test server says so in the rail, not the title bar.
## No premium currency and no "+" (no monetization).

signal back_pressed
signal close_pressed

var title := ""
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
	draw_rect(Rect2(0, 0, size.x, h + _m.edge_h), MarketTheme.HEADER) # black behind the paper's rips
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
	MarketTheme.text(self, title, x, h * 0.5, minf(MarketTheme.width(title, tsize), free), tsize, MarketTheme.ACTION)

## A dark rounded counter ending at `right`: the grey T-stone coin (about half the pill's height, as
## in the references) and the number; bound T-stones add a white padlock on a dark disc beside the
## coin, at least 18 px across so it reads on a 390 px phone. Returns its left edge.
func _pill(right: float, bound: bool, value: String, h: float, wide: bool) -> float:
	var fs: int = _m.name
	var ph := maxf(28.0, h * 0.66)
	var cr := ph * 0.27
	var lr := maxf(9.0, ph * 0.22) if bound else 0.0
	var lead := ph * 0.42 + cr * 1.4 + lr * 1.7 + ph * 0.3 ## pill edge to the number: coin, lock, gap
	var w := maxf(lead + MarketTheme.width(value, fs) + ph * 0.35 + 4.0, size.x * (0.12 if wide else 0.07)) # 4 px: rounding never cuts the number
	var r := Rect2(right - w, (h - ph) * 0.5, w, ph)
	draw_style_box(MarketTheme.flat(Color(0.1, 0.1, 0.09, 0.95), Color(0, 0, 0, 0), 0, int(ph * 0.3)), r)
	var c := Vector2(r.position.x + ph * 0.42 + cr * 0.4, h * 0.5)
	MarketGlyphs.coin(self, c, cr)
	if bound:
		MarketGlyphs.lock(self, c + Vector2(cr + lr * 0.55, cr * 0.3), lr)
	var tx := r.position.x + lead
	MarketTheme.text(self, value, tx, h * 0.5, r.end.x - ph * 0.35 - tx, fs, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	return r.position.x
