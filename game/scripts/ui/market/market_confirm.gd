class_name MarketConfirm
extends Control
## Buy confirm: the listing's real asset (level, durability, what it is made of, pet stats), the
## seller, the price and "your tradable T-stones N -> N - price". Buy sends one market.buy; the
## button is disabled while it is pending, so a second tap sends nothing. The bought instance goes
## to the buyer's market storage (the vault, contracts:157-159), collected with My Market -> Receive All.
# swap: INVUI ItemInspectPanel for the asset block when it lands.

signal bought(res: Dictionary)
signal gone ## the listing was sold, expired or cancelled under us: the table reloads
signal dismissed

var client: MarketClient
var view: Dictionary
var tradable := 0
var pending := false
var buy_btn: Button
var cancel_btn: Button
var status: Label
var _panel: PanelContainer
var _icon: TextureRect
var _name: Label
var _lines: Label
var _price_row: Label
var _balance: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var sb := MarketTheme.flat(Color(0.14, 0.17, 0.15, 0.98), MarketTheme.BORDER, 2, 6)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	_name = MarketTheme.label("", 22, MarketTheme.GOLD)
	info.add_child(_name)
	_lines = MarketTheme.label("", 16, MarketTheme.TEXT) # one fact per line, short: no wrap (wrapped labels measured the panel full-height)
	info.add_child(_lines)
	_price_row = MarketTheme.label("", 18, MarketTheme.TEXT)
	box.add_child(_price_row)
	_balance = MarketTheme.label("", 15, MarketTheme.TEXT_2)
	_balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_balance)
	status = MarketTheme.label("", 16, MarketTheme.TEXT)
	status.name = "BuyStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	cancel_btn = Button.new()
	cancel_btn.name = "BuyCancel"
	cancel_btn.text = "Close"
	cancel_btn.pressed.connect(func () -> void: dismissed.emit())
	buttons.add_child(cancel_btn)
	buy_btn = Button.new()
	buy_btn.name = "BuyConfirm"
	buy_btn.pressed.connect(buy)
	buttons.add_child(buy_btn)

## Shows one listing. `p_tradable` is the header's tradable balance (wallet.get).
func open(p_client: MarketClient, v: Dictionary, p_tradable: int, own: bool, m: Dictionary) -> void:
	client = p_client
	view = v
	tradable = p_tradable
	pending = false
	visible = true
	var row := MarketFormat.row(v)
	var total: int = row.price * row.count
	_icon.texture = ItemArt.texture_for(row.icon)
	_icon.modulate = row.tint
	_name.text = ("B  " if row.badge else "") + row.name + ("  ×%d" % row.count if row.count > 1 else "")
	_lines.text = "\n".join(asset_lines(v))
	_price_row.text = ("Price  %s T-stones" % MarketFormat.group(total)) + ("  (%s each)" % MarketFormat.group(row.price) if row.count > 1 else "")
	var tax := EconRules.ceil_bp(total, EconRules.load_default().bp("sales_tax")) # the engine's own rounding
	_balance.text = "Your tradable T-stones  %s  →  %s\nNo buyer fee; the seller pays %d T-stones market tax." % [MarketFormat.group(tradable), MarketFormat.group(tradable - total), tax]
	status.text = ""
	status.add_theme_color_override("font_color", MarketTheme.TEXT)
	buy_btn.text = "Buy for %s" % MarketFormat.group(total)
	buy_btn.visible = not own
	buy_btn.disabled = false
	cancel_btn.text = "Close"
	if own:
		status.text = MarketFormat.ERRORS.self_trade
	elif tradable < total:
		buy_btn.disabled = true
		status.text = "%s You have %s; this costs %s." % [MarketFormat.ERRORS.insufficient_funds, MarketFormat.group(tradable), MarketFormat.group(total)]
		status.add_theme_color_override("font_color", MarketTheme.DANGER)
	fit(m)

## Every fact the asset carries, read from its dict, and who sells it.
static func asset_lines(v: Dictionary) -> PackedStringArray:
	var out := MarketFormat.asset_lines(str(v.get("type", "item")), v.get("asset", {}))
	out.append("Sold by %s" % str(v.get("seller_name", "?")))
	return out

func buy() -> void:
	if pending or client == null or not buy_btn.visible or buy_btn.disabled:
		return # a second tap while pending, or after the sale, sends nothing
	pending = true
	buy_btn.disabled = true
	status.text = "Buying…"
	status.add_theme_color_override("font_color", MarketTheme.TEXT_2)
	var row := MarketFormat.row(view)
	# ASSUMPTION: a lot listed as one (×N) is bought whole; per-unit buys arrive with a count stepper.
	var res: Dictionary = await client.request("market.buy", {"listing_id": row.id, "count": row.count})
	pending = false
	if res.get("ok", false):
		status.text = "Bought. It is in your market storage: My Market → Receive All."
		status.add_theme_color_override("font_color", MarketTheme.GOLD)
		buy_btn.visible = false
		cancel_btn.text = "Done"
		bought.emit(res)
		return
	status.text = MarketFormat.error_text(res)
	status.add_theme_color_override("font_color", MarketTheme.DANGER)
	if MarketFormat.is_gone(res):
		buy_btn.visible = false
		gone.emit()
	else:
		buy_btn.disabled = false

func fit(m: Dictionary) -> void:
	var view_size := get_viewport_rect().size
	var compact: bool = m.compact
	var w := minf(view_size.x - 24.0, 720.0)
	var isz := 72.0 if compact else 128.0
	_icon.custom_minimum_size = Vector2(isz, isz)
	MarketTheme.size_label(_name, m.name + 4)
	for l: Label in [_lines, _balance, status]:
		MarketTheme.size_label(l, m.type + (0 if compact else 2))
	MarketTheme.size_label(_price_row, m.name)
	for b: Button in [buy_btn, cancel_btn]:
		MarketTheme.action(b, b == buy_btn, m.name)
		b.custom_minimum_size = Vector2(150 if compact else 220, UiTokens.TARGET_MIN if compact else 56)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	_center()
	_center.call_deferred() # again once the wrapped lines know their width

func _center() -> void:
	var view_size := get_viewport_rect().size
	_panel.reset_size()
	_panel.position = Vector2((view_size.x - _panel.size.x) * 0.5, maxf(4.0, (view_size.y - _panel.size.y) * 0.5))
