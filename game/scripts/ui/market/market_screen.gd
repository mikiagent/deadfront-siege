class_name MarketScreen
extends Control
## The Island Market (owner: Gameplay HUD -> Main Menu -> Island Market -> Buy / My Market / Sell).
## Full screen and opaque on its own canvas layer; talks to the economy only through a
## MarketClient. With no game server (offline single-player, today's player build) it says so
## and sends nothing: the market is an online feature (STATUS 2026-10-20), never faked here.

signal closed

## Labs and tests only (MarketHarness's LocalMarketClient); the player path never sets it.
static var test_client: MarketClient

var player: Node
var client: MarketClient
var tab := &"buy"
var header: MarketHeader
var rail: MarketRail
var buy: MarketBuy
var search: MarketSearch
var confirm: MarketConfirm
var offline_panel: Control
var _later: Label ## My Market / Sell until their build steps land
var _backdrop: ColorRect
var _m := {}

## The transport this game has: the socket when Game.net is online, else none (offline).
static func client_for_game() -> MarketClient:
	if test_client != null:
		return test_client
	var net: Variant = Game.get("net")
	if net is Object and (net as Object).has_method("request") and bool((net as Object).call("is_online")):
		return NetMarketClient.new(net)
	return MarketClient.new()

func _ready() -> void:
	name = "MarketScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP # sized to the canvas in _layout (a CanvasLayer child has no parent rect)
	_backdrop = ColorRect.new()
	_backdrop.color = MarketTheme.BG
	_backdrop.material = MarketTheme.backdrop()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	header = MarketHeader.new()
	header.name = "Header"
	header.back_pressed.connect(close_screen)
	header.close_pressed.connect(close_screen)
	add_child(header)
	rail = MarketRail.new()
	rail.name = "Rail"
	rail.tab_selected.connect(show_tab)
	add_child(rail)
	buy = MarketBuy.new()
	buy.name = "Buy"
	add_child(buy)
	_later = MarketTheme.label("", 18, MarketTheme.TEXT_2)
	_later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_later.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_later)
	offline_panel = _offline_panel()
	add_child(offline_panel)
	search = MarketSearch.new()
	search.name = "Search"
	search.visible = false
	search.searched.connect(func (t: String) -> void:
		search.visible = false
		buy.set_query(t))
	search.category_chosen.connect(func (id: String) -> void:
		search.visible = false
		buy.set_category(id))
	search.cancelled.connect(func () -> void: search.visible = false)
	add_child(search)
	confirm = MarketConfirm.new()
	confirm.name = "Confirm"
	confirm.visible = false
	confirm.dismissed.connect(func () -> void: confirm.visible = false)
	confirm.bought.connect(func (res: Dictionary) -> void:
		refresh_wallet()
		buy.reload())
	confirm.gone.connect(buy.reload)
	add_child(confirm)
	buy.table.search_pressed.connect(func () -> void: search.open(buy.q, _m))
	buy.table.row_pressed.connect(func (v: Dictionary) -> void:
		confirm.open(client, v, header.tradable(), client.account >= 0 and int(v.get("seller", -2)) == client.account, _m))
	get_viewport().size_changed.connect(_layout)

func is_open() -> bool:
	return visible

## Opens on `p_tab` (buy | my_market | sell). `_uid` is the instance INVUI's "Sell on Market" picks (B2).
func open(p_player: Node, p_tab: StringName = &"buy", _uid: String = "") -> void:
	player = p_player
	client = client_for_game()
	visible = true
	header.title = MapScreen.island_name(str(World.island_id))
	header.badge = client.label() if client.kind() == &"local_test" else ""
	header.set_wallet({})
	var online := client.is_online()
	offline_panel.visible = not online
	rail.visible = online
	_layout() # rows are built at the size they will show
	if online:
		buy.start(client)
		refresh_wallet()
		rail.select(p_tab)
	else:
		buy.visible = false
		_later.visible = false
	_layout()

func close_screen() -> void:
	if not visible:
		return
	visible = false
	search.visible = false
	confirm.visible = false
	closed.emit()

func show_tab(id: StringName) -> void:
	tab = id
	buy.visible = id == &"buy"
	_later.visible = id != &"buy"
	_later.text = "Selling arrives with the next build step." if id == &"sell" else "Your listings, sales and Receive All arrive with the next build step."
	_layout()

func refresh_wallet() -> void:
	var res: Dictionary = await client.request("wallet.get")
	if res.get("ok", false):
		header.set_wallet(res.r)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if confirm.visible:
		confirm.visible = false
	elif search.visible:
		search.visible = false
	else:
		close_screen()

func _offline_panel() -> Control:
	var p := PanelContainer.new()
	p.name = "OfflinePanel"
	var sb := MarketTheme.flat(Color(0.05, 0.06, 0.05, 0.75), MarketTheme.BORDER, 2, 6)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	p.add_child(box)
	var t := MarketTheme.label("Island Market offline", 28, MarketTheme.GOLD)
	t.name = "OfflineTitle"
	box.add_child(t)
	var body := MarketTheme.label(MarketFormat.ERRORS.offline + " Players buy and sell on the server, so nothing is listed, bought or sold while this game plays offline.", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return p

func _place_offline(body: Rect2) -> void:
	offline_panel.reset_size()
	offline_panel.position = body.position + Vector2((body.size.x - offline_panel.size.x) * 0.5, maxf(0.0, (body.size.y - offline_panel.size.y) * 0.4))

func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	_m = MarketTheme.metrics(view)
	var ins := UiTokens.safe_insets(get_viewport())
	var left: float = _m.margin + ins.w
	var right: float = _m.margin + ins.x
	header.layout(_m, view.x)
	var top: float = _m.header_h + _m.edge_h + _m.margin * 0.5
	var body := Rect2(left, top, view.x - left - right, view.y - top - _m.margin * 0.5 - ins.y)
	rail.layout(_m, Rect2(body.position, Vector2(_m.rail_w, body.size.y)))
	var content := Rect2(body.position.x + _m.rail_w + _m.margin, body.position.y, body.size.x - _m.rail_w - _m.margin, body.size.y)
	buy.layout(_m, content)
	_later.position = content.position
	_later.size = content.size
	MarketTheme.size_label(_later, _m.name)
	offline_panel.custom_minimum_size = Vector2(minf(body.size.x, 760.0), 0)
	MarketTheme.size_label(offline_panel.get_child(0).get_child(0) as Label, _m.title)
	MarketTheme.size_label(offline_panel.get_child(0).get_child(1) as Label, _m.name)
	_place_offline(body)
	_place_offline.call_deferred(body) # again once the wrapped text knows its width
	if confirm.visible and not confirm.view.is_empty():
		confirm.fit(_m)
