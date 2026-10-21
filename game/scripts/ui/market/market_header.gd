class_name MarketHeader
extends Control
## `[<] Island name   [test badge]   [T 1,234] [lock 20] | [X]` on the black band with the torn
## edge. Tradable T-stones are the big number (only they buy); bound ones show with a lock, and
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

func _icon_button(id: StringName, nm: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.icon = UiIcons.icon(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 34)
	MarketTheme.bare(b)
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
	var pad: float = (h - UiTokens.TARGET_MIN) * 0.5 if h > UiTokens.TARGET_MIN else 0.0
	var side := maxf(UiTokens.TARGET_MIN, h * 0.8)
	back_btn.position = Vector2(left + m.margin, (h - side) * 0.5)
	back_btn.size = Vector2(side, side)
	close_btn.position = Vector2(width - right - m.margin - side, (h - side) * 0.5)
	close_btn.size = Vector2(side, side)
	back_btn.add_theme_constant_override("icon_max_width", int(side * 0.62 - pad * 0.2))
	close_btn.add_theme_constant_override("icon_max_width", int(side * 0.62 - pad * 0.2))
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	var h: float = _m.header_h
	draw_rect(Rect2(0, 0, size.x, h), MarketTheme.HEADER)
	MarketTheme.torn_edge(self, h, size.x, _m.edge_h)
	var f := MarketTheme.font()
	var side := close_btn.size.x
	var right: float = close_btn.position.x - _m.margin
	# Divider before X, then the pills right to left.
	draw_rect(Rect2(right, h * 0.3, 2, h * 0.4), Color(0.4, 0.4, 0.38, 0.8))
	right -= _m.margin
	if not wallet.is_empty():
		var bound := int(wallet.get("bound", 0))
		if bound > 0:
			right = _pill(right, &"lock", MarketFormat.group(bound), h, false) - _m.margin * 0.75
		right = _pill(right, &"t_stone", MarketFormat.group(tradable()), h, true) - _m.margin
	var x: float = back_btn.position.x + side + _m.margin * 0.5
	var free: float = right - x
	var tsize: int = _m.title
	var tw := minf(f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x, free * (0.55 if badge != "" else 1.0))
	MarketTheme.text(self, title, x, h * 0.5, tw, tsize, MarketTheme.ACTION)
	if badge != "":
		var bx: float = x + tw + _m.margin
		var bsize: int = _m.type
		var bw := minf(f.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsize).x + 16.0, right - bx)
		if bw > 40.0:
			var r := Rect2(bx, h * 0.5 - bsize * 0.95, bw, bsize * 1.9)
			draw_style_box(MarketTheme.flat(Color(0.2, 0.12, 0.03, 0.85), MarketTheme.TEST_BADGE, 1, 4), r)
			MarketTheme.text(self, badge, bx + 8, h * 0.5, bw - 16, bsize, MarketTheme.TEST_BADGE)

## A dark rounded counter ending at `right`; returns its left edge.
func _pill(right: float, icon: StringName, value: String, h: float, wide: bool) -> float:
	var f := MarketTheme.font()
	var fs: int = _m.name
	var ph := maxf(28.0, h * 0.62)
	var isz := ph * 0.62
	var tw := f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := maxf(tw + isz + 30.0, size.x * (0.12 if wide else 0.06))
	var r := Rect2(right - w, (h - ph) * 0.5, w, ph)
	draw_style_box(MarketTheme.flat(Color(0.14, 0.14, 0.13, 0.95), Color(0.24, 0.24, 0.22, 1), 1, int(ph * 0.3)), r)
	var tex := UiIcons.icon(icon)
	if tex:
		draw_texture_rect(tex, Rect2(r.position.x + 8, r.position.y + (ph - isz) * 0.5, isz, isz), false, Color(0.86, 0.86, 0.84))
	MarketTheme.text(self, value, r.position.x + isz + 14, h * 0.5, w - isz - 24, fs, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	return r.position.x
