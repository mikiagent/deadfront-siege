class_name NavMenu
extends Control
## B3 nav menu (docs/design/ui-redesign-spec.md §7 B3, durango-prompts/33_ingame_hamburger_menu.md):
## the MENU hex opens two columns of entries over the live world, Character / Skills / Craft / Build /
## Bag / Animals on the left (icon then label) and World Atlas / Domain / Orders / Communication /
## Friends / Save on the right (label then icon), a header band with the Warp Gem and T-stone balances (CurrencyBar), and a close
## hex where MENU sat. The world keeps running underneath. Each entry carries the MENU badge's notices
## of its own kind (HudField.notices, spec §11). HuntHud keeps it as its open sheet (_sheet), so
## sheet_open() hides HANDS and the creature plates while it is up. The menu draws on its own canvas
## layer and fades the HUD under it out (the mockup shows only the world, the menu and the close hex).
## A compact canvas (844x390) cannot stack six 64 px rows a side, so each side folds into two columns
## of three.

const LEFT := [
	{"id": &"character", "label": "Character", "icon": &"equip"},
	{"id": &"skills", "label": "Skills", "icon": &"skills"},
	{"id": &"craft", "label": "Craft", "icon": &"craft"},
	{"id": &"build", "label": "Build", "icon": &"build"},
	{"id": &"bag", "label": "Bag", "icon": &"bag"},
	{"id": &"animals", "label": "Animals", "icon": &"animals"},
]
const RIGHT := [
	{"id": &"atlas", "label": "World Atlas", "icon": &"map"},
	{"id": &"domain", "label": "Domain", "icon": &"claim"},
	{"id": &"orders", "label": "Orders", "icon": &"notice"},
	{"id": &"communication", "label": "Communication", "icon": &"chat"},
	# ASSUMPTION: Island Market (spec 33/14: Main Menu -> Island Market) takes the Friends slot; Friends has no system
	# and the phone layout fits six rows a side. Friends comes back when a friend system exists.
	{"id": &"market", "label": "Island Market", "icon": &"market"},
	{"id": &"save", "label": "Save", "icon": &"save"},
]
## Entries with no screen yet show greyed and do nothing.
const DISABLED := []

var hud: HuntHud
var entries: Dictionary = {}  ## id -> Button
var close_hex: HexButton
var debug_btn: Button
## BAGUI: Warp Gems (+) and T-stones, the same widget as the bag header.
var currency: CurrencyBar
var _header_h := 0.0
var _font: Font
var _layer: CanvasLayer
var root: Control  ## the full-screen surface on _layer: wash, header, badges, every button

func _init(p_hud: HuntHud = null) -> void:
	hud = p_hud
	name = "NavMenu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer = CanvasLayer.new()
	_layer.name = "NavLayer"
	_layer.layer = 90  # over the HUD and plates, under the modal screens (96)
	add_child(_layer)
	root = Control.new()
	root.name = "NavRoot"
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # a tap on the open world closes the menu
	root.gui_input.connect(_on_root_input)
	root.draw.connect(_draw_root)
	_layer.add_child(root)
	_font = UiTokens.ui_face(UiTokens.WEIGHT_REGULAR)
	for list in [LEFT, RIGHT]:
		for e in list:
			_entry(e, list == RIGHT)
	close_hex = HexButton.new(64.0)
	close_hex.name = "NavClose"
	close_hex.glyph = "✕"
	close_hex.caption = "CLOSE"
	close_hex.key_hint = "Esc"
	close_hex.rim_color = UiTokens.HUD_RIM
	close_hex.pressed.connect(_close)
	root.add_child(close_hex)
	# ASSUMPTION: the header's settings gear holds the debug-info toggle (the old menu's last row) until a settings screen exists.
	debug_btn = _flat_button("NavDebug")
	debug_btn.icon = UiIcons.icon(&"settings")
	debug_btn.add_theme_constant_override("icon_max_width", 30)
	debug_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_btn.tooltip_text = "Debug info"
	debug_btn.pressed.connect(func () -> void:
		if hud:
			hud._toggle_debug()
		root.queue_redraw())
	root.add_child(debug_btn)
	currency = CurrencyBar.new()
	root.add_child(currency)

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()

func _enter_tree() -> void:
	if hud:
		hud.modulate.a = 0.0  # the HUD's bars, rail and thumb hexes fade out under the menu

func _exit_tree() -> void:
	if hud:
		hud.modulate.a = 1.0

func _entry(e: Dictionary, right: bool) -> void:
	var b := _flat_button("Nav_" + str(e["id"]))
	b.text = str(e["label"])
	b.icon = UiIcons.icon(e["icon"])
	b.expand_icon = false
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = e["id"] in DISABLED
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	b.add_theme_color_override("font_hover_color", UiTokens.GOLD)
	b.add_theme_color_override("font_pressed_color", UiTokens.GOLD)
	b.add_theme_color_override("font_focus_color", UiTokens.TEXT)
	b.add_theme_color_override("font_disabled_color", Color(UiTokens.MUTED, 0.55))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	b.add_theme_constant_override("outline_size", 4)
	var id: StringName = e["id"]
	b.pressed.connect(func () -> void: _open(id))
	root.add_child(b)
	entries[id] = b

func _flat_button(n: String) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	var wash := StyleBoxFlat.new()
	wash.bg_color = UiTokens.GOLD_DIM
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("disabled", empty)
	b.add_theme_stylebox_override("hover", wash)
	b.add_theme_stylebox_override("pressed", wash)
	b.add_theme_stylebox_override("focus", wash)
	b.add_theme_font_override("font", _font)
	return b

# ---------------------------------------------------------------- layout

func _layout() -> void:
	var r := get_viewport_rect().size
	root.position = Vector2.ZERO
	root.size = r
	var inset := UiTokens.safe_insets(get_viewport())
	var compact := UiTokens.is_compact(r)
	var row_h := 72.0 if compact else 84.0
	var w := 176.0 if compact else 330.0
	var font_px := 20 if compact else 30
	var icon_px := 30 if compact else 44
	_header_h = 68.0 if compact else 84.0
	var top := _header_h + inset.z + (6.0 if compact else 40.0)
	var per_col := 3 if compact else 6
	for side in 2:
		var list: Array = LEFT if side == 0 else RIGHT
		for i in list.size():
			var b := entries[list[i]["id"]] as Button
			var col := i / per_col
			var row := i % per_col
			var x := 16.0 + inset.w + float(col) * (w + 8.0)
			if side == 1:
				x = r.x - 16.0 - inset.x - w - float(col) * (w + 8.0)
			b.add_theme_font_size_override("font_size", font_px)
			b.add_theme_constant_override("icon_max_width", icon_px)
			b.add_theme_constant_override("h_separation", 12 if compact else 20)
			b.custom_minimum_size = Vector2(w, row_h - 8.0)
			b.size = b.custom_minimum_size
			b.position = Vector2(x, top + float(row) * row_h)
	# The close hex sits where MENU is, so the same thumb spot opens and closes the menu.
	var side_px := HudField.px(&"rail", r)
	HudField.fit(close_hex, side_px)
	close_hex.position = hud._menu_hex.position if hud and hud._menu_hex else Vector2(16.0 + inset.w, r.y - side_px - 32.0 - inset.y)
	var g := 64.0
	debug_btn.custom_minimum_size = Vector2(g, g)
	debug_btn.size = debug_btn.custom_minimum_size
	debug_btn.position = Vector2(16.0 + inset.w, inset.z + (_header_h - g) * 0.5)
	currency.set_px(18 if compact else 24)
	currency.refresh()
	currency.size = currency.get_combined_minimum_size()
	currency.position = Vector2(r.x - 16.0 - inset.x - currency.size.x, inset.z + (_header_h - currency.size.y) * 0.5)
	root.queue_redraw()

## Every tappable rect on the menu (tests and the capture lab check them for size and overlap).
func tap_rects() -> Dictionary:
	var out := {}
	for id in entries:
		out[str(id)] = (entries[id] as Control).get_global_rect()
	out["close"] = close_hex.get_global_rect()  # the control is the tap target, as for MENU
	out["debug"] = debug_btn.get_global_rect()
	out["gems_add"] = currency.add_btn.get_global_rect()
	return out

# ---------------------------------------------------------------- badges (spec §11)

## The badge an entry shows: its notice count ("" when none), as on the MENU hex.
func badge_text(id: StringName) -> String:
	if hud == null or hud.field == null:
		return ""
	var n := hud.field.count(id)
	return "" if n <= 0 else (str(n) if n < 10 else "9+")

func _badge_urgent(id: StringName) -> bool:
	return hud != null and hud.field != null and bool((hud.field.notices.get(id, {}) as Dictionary).get("urgent", false))

# ---------------------------------------------------------------- draw

func _draw_root() -> void:
	var r := root.size
	# A light wash over the world, darker behind each column so the white labels read on grass.
	root.draw_rect(Rect2(Vector2.ZERO, r), Color(0, 0, 0, 0.22))
	var band := minf(r.x * 0.32, 520.0)
	var dark := Color(0, 0, 0, 0.5)
	var clear := Color(0, 0, 0, 0)
	root.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(band, 0), Vector2(band, r.y), Vector2(0, r.y)]), PackedColorArray([dark, clear, clear, dark]))
	root.draw_polygon(PackedVector2Array([Vector2(r.x - band, 0), Vector2(r.x, 0), Vector2(r.x, r.y), Vector2(r.x - band, r.y)]), PackedColorArray([clear, dark, dark, clear]))
	# Header band: utilities left, the balances (CurrencyBar) right.
	root.draw_rect(Rect2(0, 0, r.x, _header_h), Color(UiTokens.HEADER, 0.78))
	root.draw_line(Vector2(0, _header_h), Vector2(r.x, _header_h), Color(1, 1, 1, 0.08), 1.0)
	if Game.debug_overlay:
		UiTokens.draw_brackets(root, debug_btn.get_rect().grow(-6.0), UiTokens.GOLD, 10.0, 2.0)
	for id in entries:
		var t := badge_text(id)
		if t == "":
			continue
		var b := entries[id] as Button
		var icon_px := float(b.get_theme_constant("icon_max_width"))
		var right := b.icon_alignment == HORIZONTAL_ALIGNMENT_RIGHT
		var ix := b.position.x + (b.size.x - icon_px if right else 0.0)
		var at := Vector2(ix + (icon_px + 2.0 if right else -2.0), b.position.y + b.size.y * 0.5 - icon_px * 0.5)
		var urgent := _badge_urgent(id)
		var px := maxi(UiTokens.TYPE_MIN, int(icon_px * 0.36))
		var rad := maxf(9.0, float(px) * 0.8)
		if id == &"skills" and hud:
			hud._levelups.draw_pulse_rings(root, at, rad)  # LEVELFX: a level-up just showed
		root.draw_circle(at, rad, UiTokens.LIFE if urgent else UiTokens.GOLD)
		UiTokens.draw_centered(root, _font, at, t, px, Color.WHITE if urgent else UiTokens.CTA_INK)

# ---------------------------------------------------------------- input

func _on_root_input(event: InputEvent) -> void:
	var up := (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed)
	if up:
		root.accept_event()
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if hud:
		hud._close_sheet()

## Open an entry's screen. Entries whose redesigned screen does not exist yet open today's.
func _open(id: StringName) -> void:
	if hud == null or hud.player == null or id in DISABLED:
		return
	var h := hud
	var p := h.player
	h.field.clear(id)
	h._close_sheet()
	match id:
		&"character":
			h.open_character()
		&"skills":
			h.open_skills()
		&"craft":
			if p.craft_ui:
				p.craft_ui.toggle()
		&"build":
			var b := BuildUI.ensure(p)
			if b:
				b.toggle()
		&"bag":
			p.controls.toggle_inventory()
		&"animals":
			h.open_animals()
		&"market":
			h.open_market()
		&"orders":
			h.open_orders()
		&"atlas":
			h.open_atlas()
		&"domain":
			h.open_domain()
		&"communication":
			h.open_comms()
		&"save":
			var ok: bool = (load("res://scripts/core/save_game.gd") as GDScript).save_now()
			if ok:
				h._events.add_notice("Game saved · %s" % Time.get_time_string_from_system().left(5), true)
			else:
				h.notice("Save failed")
