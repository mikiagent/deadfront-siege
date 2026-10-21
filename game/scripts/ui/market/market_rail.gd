class_name MarketRail
extends Control
## The left rail: Buy (cart), My Market (ledger), Sell (price tag). The active tab is lighter, with
## four yellow L brackets and a yellow icon and label (spec 14 references).
# swap: INVUI SelectionBrackets for the brackets.

signal tab_selected(id: StringName)

const TABS := [[&"buy", "Buy", &"cart"], [&"my_market", "My Market", &"ledger"], [&"sell", "Sell", &"tag"]]

var active := &"buy"
var buttons: Dictionary = {} ## id -> Button
var _m := {}

func _ready() -> void:
	for t: Array in TABS:
		var b := Button.new()
		b.name = "Tab_%s" % t[0]
		b.tooltip_text = t[1]
		MarketTheme.bare(b)
		var id: StringName = t[0]
		b.pressed.connect(func () -> void: select(id))
		add_child(b)
		buttons[id] = b

func select(id: StringName) -> void:
	if id != active:
		active = id
		queue_redraw()
	tab_selected.emit(id)

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var tab_h := maxf(UiTokens.TARGET_MIN, roundf(rect.size.y * 0.23))
	for i in TABS.size():
		var b: Button = buttons[TABS[i][0]]
		b.position = Vector2(0, i * tab_h)
		b.size = Vector2(rect.size.x, tab_h)
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	draw_style_box(MarketTheme.flat(Color(0.05, 0.06, 0.05, 0.3), MarketTheme.BORDER, 2, 3), Rect2(Vector2.ZERO, size))
	for t: Array in TABS:
		var b: Button = buttons[t[0]]
		var r := Rect2(b.position, b.size)
		var on: bool = t[0] == active
		if on:
			draw_rect(r.grow(-3), Color(0.78, 0.72, 0.52, 0.2))
			MarketTheme.brackets(self, r.grow(-2), minf(r.size.x, r.size.y) * 0.12, maxf(3.0, r.size.y * 0.03))
		else:
			MarketTheme.dotted(self, Vector2(r.position.x + 6, r.end.y), Vector2(r.end.x - 6, r.end.y))
		var col := MarketTheme.GOLD if on else MarketTheme.ACTION
		var fs: int = _m.tab
		var isz := minf(r.size.x * 0.42, r.size.y - fs * 1.6 - 12.0)
		var label_y := r.position.y + r.size.y * 0.5 + isz * 0.5 + fs * 0.55
		if isz >= 18.0:
			MarketGlyphs.draw(self, t[2], Rect2(r.position.x + (r.size.x - isz) * 0.5, label_y - fs * 0.6 - isz - 4.0, isz, isz), col)
		else:
			label_y = r.get_center().y
		MarketTheme.text(self, t[1], r.position.x + 4, label_y, r.size.x - 8, fs, col, HORIZONTAL_ALIGNMENT_CENTER)
