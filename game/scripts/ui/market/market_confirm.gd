class_name MarketConfirm
extends Control
## Buy confirm: the listing's real asset (level, durability, what it is made of, pet stats), the
## seller, the price and "your tradable T-stones N -> N - price". Buy sends one market.buy; the
## button is disabled while it is pending, so a second tap sends nothing. The bought instance goes
## to the buyer's market storage (the vault, contracts:157-159), collected with My Market -> Receive All.
## My Market opens the same panel on an own active listing to cancel it (open_cancel).
# swap: INVUI ItemInspectPanel for the asset block when it lands.

signal bought(res: Dictionary)
signal cancelled(res: Dictionary) ## an own listing was cancelled: its units are back in market storage
signal gone ## the listing was sold, expired or cancelled under us: the table reloads
signal stale ## another player bought part of this lot: the screen re-reads it and opens it again
signal dismissed

var client: MarketClient
var view: Dictionary
var tradable := 0
var pending := false
var mode := &"buy" ## buy | cancel
var buy_btn: Button
var cancel_btn: Button
var status: Label
var _panel: PanelContainer
var _band: PanelContainer
var _body: MarginContainer
var _icon: TextureRect
var _name: Label
var _lines: Label
var _price_row: Label
var _balance: Label
var _safe := Rect2() ## the safe area the panel centres in (MarketScreen metrics)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78) # the list behind is context, not something to read
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	var sb := MarketTheme.flat(MarketTheme.DIALOG, MarketTheme.BORDER, 2, 6)
	sb.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	_panel.add_child(outer)
	_band = PanelContainer.new() # the tan name band of the Sell panel and the Bag's inspect panel
	var tb := MarketTheme.flat(MarketTheme.PARCHMENT, Color(0, 0, 0, 0), 0, 4)
	tb.set_content_margin_all(10)
	tb.content_margin_left = 18
	_band.add_theme_stylebox_override("panel", tb)
	outer.add_child(_band)
	_name = MarketTheme.label("", 22, MarketTheme.PRIMARY_TEXT)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_band.add_child(_name)
	_body = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, 18)
	outer.add_child(_body)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_body.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(_icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(info)
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
	buy_btn.pressed.connect(func () -> void:
		if mode == &"cancel":
			cancel_listing()
		else:
			buy())
	buttons.add_child(buy_btn)

## Shows one listing. `p_tradable` is the header's tradable balance (wallet.get); `lock_s` its
## trade_lock_s (hook H6): a new account sees the lock before pressing Buy.
func open(p_client: MarketClient, v: Dictionary, p_tradable: int, own: bool, m: Dictionary, lock_s: int = 0) -> void:
	client = p_client
	view = v
	tradable = p_tradable
	pending = false
	mode = &"buy"
	visible = true
	var row := MarketFormat.row(v)
	var total: int = row.price * row.count
	_icon.texture = ItemArt.texture_for(row.icon)
	_icon.modulate = row.tint
	_name.text = ("B  " if row.badge else "") + row.name + ("  ×%d" % row.count if row.count > 1 else "")
	_lines.text = "\n".join(asset_lines(v))
	var qty := int(v.get("qty", row.count))
	_price_row.text = ("Price  %s T-stones" % MarketFormat.group(total)) + ("  (%s each)" % MarketFormat.group(row.price) if row.count > 1 else "") \
		+ ("  ·  %d of %d left" % [row.count, qty] if qty > row.count else "")
	var tax := EconRules.ceil_bp(total, EconRules.load_default().bp("sales_tax")) # the engine's own rounding
	_balance.text = "Your tradable T-stones  %s  →  %s\nNo buyer fee; the seller pays %d T-stones market tax." % [MarketFormat.group(tradable), MarketFormat.group(tradable - total), tax]
	say("")
	buy_btn.text = "Buy for %s" % MarketFormat.group(total)
	buy_btn.visible = not own
	buy_btn.disabled = false
	cancel_btn.text = "Close"
	if own:
		say(MarketFormat.ERRORS.self_trade)
	elif lock_s > 0:
		buy_btn.disabled = true
		say(MarketFormat.lock_text(lock_s), MarketTheme.DANGER)
	elif tradable < total:
		buy_btn.disabled = true
		say("%s You have %s; this costs %s." % [MarketFormat.ERRORS.insufficient_funds, MarketFormat.group(tradable), MarketFormat.group(total)], MarketTheme.DANGER)
	fit(m)

## The status line; hidden while empty, so no blank band sits above the buttons.
func say(text: String, color: Color = MarketTheme.TEXT) -> void:
	status.text = text
	status.visible = text != ""
	status.add_theme_color_override("font_color", color)

## An own active listing, to cancel: what it is, its price, and that the fee stays paid.
func open_cancel(p_client: MarketClient, v: Dictionary, m: Dictionary) -> void:
	open(p_client, v, 0, false, m)
	mode = &"cancel"
	var row := MarketFormat.row(v)
	_lines.text = "\n".join(MarketFormat.asset_lines(str(v.get("type", "item")), v.get("asset", {})))
	_balance.text = "Cancelling takes it off the market and puts it in your market storage (My Market → Receive All).\nThe listing fee of %s %s is not refunded." % [MarketFormat.group(int(v.get("fee", 0))), "T-stone" if int(v.get("fee", 0)) == 1 else "T-stones"]
	say("")
	buy_btn.text = "Cancel listing"
	buy_btn.disabled = false
	cancel_btn.text = "Keep listing"
	_price_row.text = ("Listed at  %s T-stones" % MarketFormat.group(row.price * row.count)) + ("  (%s each)" % MarketFormat.group(row.price) if row.count > 1 else "")
	fit(m)

## market.cancel, once: a second tap while pending sends nothing.
func cancel_listing() -> void:
	if pending or client == null or not buy_btn.visible or buy_btn.disabled:
		return
	pending = true
	buy_btn.disabled = true
	say("Cancelling…", MarketTheme.TEXT_2)
	var res: Dictionary = await client.request("market.cancel", {"listing_id": str(view.get("id", ""))})
	pending = false
	buy_btn.visible = false
	cancel_btn.text = "Done" if res.get("ok", false) else "Close"
	if res.get("ok", false):
		say("Cancelled. It is in your market storage: Receive All brings it to your bag.", MarketTheme.GOLD)
		cancelled.emit(res)
		return
	say(MarketFormat.error_text(res), MarketTheme.DANGER)
	if MarketFormat.is_gone(res):
		gone.emit() # sold or expired meanwhile: My Market reloads and shows where it went
	else:
		buy_btn.visible = true
		buy_btn.disabled = false

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
	say("Buying…", MarketTheme.TEXT_2)
	var row := MarketFormat.row(view)
	# ASSUMPTION: a lot listed as one (×N) is bought whole; per-unit buys arrive with a count stepper.
	var res: Dictionary = await client.request("market.buy", {"listing_id": row.id, "count": row.count})
	pending = false
	if res.get("ok", false):
		say("Bought. It is in your market storage: My Market → Receive All.", MarketTheme.GOLD)
		buy_btn.visible = false
		cancel_btn.text = "Done"
		bought.emit(res)
		return
	say(MarketFormat.error_text(res), MarketTheme.DANGER)
	if MarketFormat.is_gone(res):
		buy_btn.visible = false
		gone.emit()
	elif str(res.get("err", "")) == "insufficient_items":
		buy_btn.visible = false # the count is stale: Buy waits for the re-read lot (MarketScreen)
		stale.emit()
	else:
		buy_btn.disabled = false

func fit(m: Dictionary) -> void:
	_safe = m.get("safe", get_viewport_rect())
	var compact: bool = m.compact
	var w := minf(_safe.size.x - 24.0, 720.0)
	var isz := 72.0 if compact else 128.0
	_icon.custom_minimum_size = Vector2(isz, isz)
	MarketTheme.size_label(_name, m.name + (2 if compact else 6))
	var tb := _band.get_theme_stylebox("panel") as StyleBoxFlat
	tb.content_margin_top = 4.0 if compact else 10.0
	tb.content_margin_bottom = tb.content_margin_top
	for side in ["left", "right", "top", "bottom"]:
		_body.add_theme_constant_override("margin_" + side, 10 if compact else 18)
	for l: Label in [_lines, _balance, status]:
		MarketTheme.size_label(l, m.type + (0 if compact else 2))
	MarketTheme.size_label(_price_row, m.name)
	for b: Button in [buy_btn, cancel_btn]:
		MarketTheme.action(b, b == buy_btn, m.name)
		b.custom_minimum_size = Vector2(150 if compact else 220, m.tmin if compact else 56)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	_center()
	_center.call_deferred() # again once the wrapped lines know their width

func _center() -> void:
	_panel.reset_size()
	_panel.position = _safe.position + Vector2((_safe.size.x - _panel.size.x) * 0.5, maxf(4.0, (_safe.size.y - _panel.size.y) * 0.5))
