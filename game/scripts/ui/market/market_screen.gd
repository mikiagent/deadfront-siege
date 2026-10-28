class_name MarketScreen
extends Control
## The Island Market (owner: Gameplay HUD -> Main Menu -> Island Market -> Buy / My Market / Sell;
## docs/design/durango-prompts/06 + 14). Full screen on its own canvas layer, §8 chrome: HEADER bar
## with "‹ <island> Island", the T-stones pill and ✕, torn edge, PANEL panes, GOLD selection
## brackets, GOLD primary actions. Talks to the economy only through a MarketClient. With no game
## server (offline single-player, the only player build today) every tab says so and sends nothing
## (owner 2026-10-20: an honest "market offline" state, never fake listings).
## Open it with MarketScreen.open_for(hud_parent, tab) (the nav menu's entry point) or open().

signal closed
## Back (‹) returns to the nav menu (§8); the host decides what that is.
signal back_pressed

## Labs and tests only (MarketHarness's LocalMarketClient); the player path never sets it.
static var test_client: MarketClient

const TABS := [&"buy", &"my_market", &"sell"]
const TAB_NAMES := {&"buy": "Buy", &"my_market": "My Market", &"sell": "Sell"}
const OFFLINE_BODY := {
	&"buy": "Other survivors' listings live on the game server. This game is playing offline, so there is nothing to browse or buy.",
	&"my_market": "Your listings, sales and Receive All live on the game server. Nothing is listed while this game plays offline.",
	&"sell": "Listing an item moves it into market storage on the game server. Your bag stays as it is while this game plays offline.",
}

var client: MarketClient
var tab := &"buy"
var m := {} ## metrics for this canvas (metrics())
var wallet := {} ## the last wallet.get answer
var header: Control
var back_btn: Button
var close_btn: Button
var title: Label
var pill: Control
var rail_btns := {}
var rail_note: Label
var panes := {}
var offline: PanelContainer
var offline_title: Label
var offline_body: Label
var confirm: MarketConfirm
var _sell_uid := ""

## The nav menu's door: one screen per host, on its own canvas layer above the HUD.
static func open_for(host: Node, p_tab: StringName = &"buy", uid: String = "") -> MarketScreen:
	var s := host.get_node_or_null("MarketLayer/MarketScreen") as MarketScreen
	if s == null:
		var layer := CanvasLayer.new()
		layer.name = "MarketLayer"
		layer.layer = 96
		host.add_child(layer)
		s = MarketScreen.new()
		layer.add_child(s)
	s.open(p_tab, uid)
	return s

## The transport this game has: a lab/test client, else none (offline). A network client plugs in here.
static func client_for_game() -> MarketClient:
	return test_client if test_client != null else MarketClient.new()

static func lbl(text: String, px: int, color: Color = UiTokens.TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD if bold else UiTokens.WEIGHT_REGULAR))
	l.add_theme_font_size_override("font_size", maxi(UiTokens.TYPE_MIN, px))
	l.add_theme_color_override("font_color", color)
	return l

## A flat dark button (secondary) or the GOLD primary, CTA_INK text (§8). Tap height >= 64.
static func btn(text: String, px: int, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 64
	b.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD if primary else UiTokens.WEIGHT_REGULAR))
	b.add_theme_font_size_override("font_size", px)
	var fill := UiTokens.GOLD if primary else UiTokens.HEADER
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.lightened(0.08) if s == "hover" else (Color(fill, 0.35) if s == "disabled" else fill)
		sb.border_color = UiTokens.GOLD if s == "focus" else Color(UiTokens.HUD_RIM, 0.35)
		sb.set_border_width_all(2 if s == "focus" else (0 if primary else 1))
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		b.add_theme_stylebox_override(s, sb)
	var ink := UiTokens.CTA_INK if primary else UiTokens.TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(ink, 0.5))
	return b

static func panel_box(alpha: float = 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.PANEL, alpha)
	sb.border_color = Color(UiTokens.HUD_RIM, 0.12)
	sb.set_border_width_all(1)
	return sb

## Sizes at this canvas: desktop at 1600x900, compact (phone landscape 844x390) scaled down, every tap >= 64.
static func metrics(view: Vector2) -> Dictionary:
	var c := UiTokens.is_compact(view)
	return {
		"compact": c, "header_h": 64.0 if c else UiTokens.HEADER_H, "margin": 10.0 if c else 32.0,
		"rail_w": 104.0 if c else 200.0, "cat_w": 150.0 if c else 300.0, "detail_w": 300.0 if c else 450.0,
		"row_h": 64.0 if c else 96.0, "title": 22 if c else UiTokens.TITLE_PX + 8, "px": 15 if c else 22,
		"small": 12 if c else 16, "gap": 6.0 if c else 16.0,
	}

func _ready() -> void:
	name = "MarketScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.06, 0.07, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var wash := ColorRect.new()
	wash.color = UiTokens.SCREEN_DIM
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	header = Control.new()
	header.name = "Header"
	header.draw.connect(func () -> void:
		var r := Rect2(Vector2.ZERO, header.size)
		header.draw_rect(r, UiTokens.HEADER)
		UiTokens.draw_torn_edge(header, Rect2(0, r.size.y, r.size.x, UiTokens.TORN_MAX)))
	add_child(header)
	back_btn = MarketGlyphButton.new(&"back")
	back_btn.name = "Back"
	back_btn.pressed.connect(func () -> void:
		close_screen()
		back_pressed.emit())
	header.add_child(back_btn)
	title = lbl("", 28, UiTokens.TEXT)
	title.name = "Title"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)
	pill = Control.new()
	pill.name = "Wallet"
	pill.draw.connect(_draw_pill)
	header.add_child(pill)
	close_btn = MarketGlyphButton.new(&"close")
	close_btn.name = "Close"
	close_btn.pressed.connect(close_screen)
	header.add_child(close_btn)
	for id: StringName in TABS:
		var t := MarketRailTab.new(id, TAB_NAMES[id])
		t.name = "Tab_" + str(id)
		t.pressed.connect(show_tab.bind(id))
		add_child(t)
		rail_btns[id] = t
	rail_note = lbl("", 12, UiTokens.MUTED)
	rail_note.name = "RailNote"
	rail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(rail_note)
	for id: StringName in TABS:
		var p: Control = {&"buy": MarketBuy, &"my_market": MarketMine, &"sell": MarketSell}[id].new()
		p.name = {&"buy": "Buy", &"my_market": "MyMarket", &"sell": "Sell"}[id]
		p.set("screen", self)
		p.visible = false
		add_child(p)
		panes[id] = p
	offline = PanelContainer.new()
	offline.name = "Offline"
	offline.add_theme_stylebox_override("panel", panel_box())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	offline.add_child(box)
	offline_title = lbl("Island Market offline", 28, UiTokens.GOLD, true)
	box.add_child(offline_title)
	offline_body = lbl("", 18)
	offline_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(offline_body)
	add_child(offline)
	confirm = MarketConfirm.new()
	confirm.name = "Confirm"
	confirm.screen = self
	add_child(confirm)
	get_viewport().size_changed.connect(_layout)

func is_open() -> bool:
	return visible

func online() -> bool:
	return client != null and client.is_online()

## Opens on `p_tab` (buy | my_market | sell). `uid` preselects that instance in Sell (Bag -> Sell on Market).
func open(p_tab: StringName = &"buy", uid: String = "") -> void:
	client = client_for_game()
	_sell_uid = uid
	visible = true
	var island := MapScreen.island_name(str(World.island_id)) if str(World.island_id) != "" else ""
	title.text = island if island != "" else "Island Market" # spec 14: the island's name is the title
	rail_note.text = client.label() if online() else ""
	confirm.visible = false
	refresh_wallet()
	show_tab(p_tab if p_tab in TABS else &"buy")

func close_screen() -> void:
	if not visible:
		return
	visible = false
	confirm.visible = false
	closed.emit()

func show_tab(id: StringName) -> void:
	tab = id
	for t: StringName in TABS:
		rail_btns[t].picked = t == id
		panes[t].visible = t == id and online()
	offline.visible = not online()
	offline_body.text = OFFLINE_BODY[id]
	_layout()
	if online():
		if id == &"sell":
			panes[id].call("refresh", _sell_uid)
			_sell_uid = ""
		else:
			panes[id].call("refresh")

func refresh_wallet() -> void:
	wallet = {}
	if online():
		var res := client.request("wallet.get")
		if res.get("ok", false):
			wallet = res.r
	pill.queue_redraw()

## Spendable on buys: the wallet minus its bound part (bound T-stones pay fees only, market_rules.json).
func tradable() -> int:
	return int(wallet.get("wallet", 0)) - int(wallet.get("bound", 0))

func _draw_pill() -> void:
	var r := Rect2(Vector2.ZERO, pill.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	pill.draw_style_box(sb, r)
	var rad := r.size.y * 0.22
	MarketRow.draw_coin(pill, Vector2(r.size.y * 0.55, r.size.y * 0.5), rad)
	var px := int(m.get("small", 16)) + 4
	var f := UiTokens.ui_face(UiTokens.WEIGHT_BOLD)
	var t := MarketRow._num(int(wallet.get("wallet", 0))) if not wallet.is_empty() else "—"
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	pill.draw_string(f, Vector2(r.size.x - w - r.size.y * 0.45, r.size.y * 0.5 + px * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, UiTokens.TEXT)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if confirm.visible:
			confirm.visible = false
		else:
			close_screen()

func _layout() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	m = metrics(view)
	var ins := UiTokens.safe_insets(get_viewport()) # right, bottom, top, left
	var hh: float = m.header_h + ins.z
	header.position = Vector2.ZERO
	header.size = Vector2(view.x, hh)
	var left: float = ins.w + m.margin * 0.5
	var right: float = view.x - ins.x - m.margin * 0.5
	back_btn.position = Vector2(left, ins.z + (m.header_h - 64.0) * 0.5)
	back_btn.size = Vector2(64, 64)
	close_btn.position = Vector2(right - 64.0, back_btn.position.y)
	close_btn.size = Vector2(64, 64)
	var pill_w := 150.0 if m.compact else 220.0
	var pill_h := 40.0 if m.compact else 48.0
	pill.position = Vector2(close_btn.position.x - m.gap - pill_w, ins.z + (m.header_h - pill_h) * 0.5)
	pill.size = Vector2(pill_w, pill_h)
	title.add_theme_font_size_override("font_size", m.title)
	title.position = Vector2(left + 64.0, ins.z)
	title.size = Vector2(pill.position.x - title.position.x - m.gap, m.header_h)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.queue_redraw()
	pill.queue_redraw()
	var top: float = hh + UiTokens.TORN_MAX + m.gap
	var body := Rect2(ins.w + m.margin, top, view.x - ins.w - ins.x - m.margin * 2.0, view.y - top - ins.y - m.gap)
	# rail: three tall tabs, the test-server note under them
	var note_h := 0.0 if rail_note.text == "" else (34.0 if m.compact else 48.0)
	var tab_h := minf(m.row_h * 1.9, (body.size.y - note_h) / 3.0)
	for i in TABS.size():
		var t: MarketRailTab = rail_btns[TABS[i]]
		t.position = body.position + Vector2(0, tab_h * i)
		t.size = Vector2(m.rail_w, tab_h)
		t.px = m.px
	rail_note.add_theme_font_size_override("font_size", 12)
	rail_note.position = body.position + Vector2(0, tab_h * 3.0)
	rail_note.size = Vector2(m.rail_w, note_h)
	var content := Rect2(body.position.x + m.rail_w + m.gap, body.position.y, body.size.x - m.rail_w - m.gap, body.size.y)
	for id: StringName in TABS:
		panes[id].call("layout", content)
	offline_title.add_theme_font_size_override("font_size", m.title)
	offline_body.add_theme_font_size_override("font_size", m.px)
	offline.custom_minimum_size = Vector2(minf(content.size.x - m.gap * 2.0, 760.0), 0)
	offline_body.custom_minimum_size.x = offline.custom_minimum_size.x - 2.0
	_place_offline(content)
	_place_offline.call_deferred(content) # again once the wrapped body knows its width (one frame later)
	confirm.layout(view)

func _place_offline(content: Rect2) -> void:
	offline.reset_size()
	offline.position = content.position + Vector2((content.size.x - offline.size.x) * 0.5, maxf(0.0, (content.size.y - offline.size.y) * 0.35))
