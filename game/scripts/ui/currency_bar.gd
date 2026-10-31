class_name CurrencyBar
extends HBoxContainer
## The two balances (spec 14 / spec 33 header): the premium Warp Gems with a "+" and Gold (the
## T-stones balance, renamed for players; World.t_stones and the save key are unchanged). One widget reused by the nav menu, the bag header and the market header (BAGUI). It reads
## World each frame and only touches its labels when a number changed.
## The "+" is a placeholder: there is no purchase flow (BAGUI brief), it shows a short note.

signal add_pressed

var gems_label: Label
var stones_label: Label
var add_btn: Button
var _note: Label
var _shown := Vector2i(-1, -1)
var _px := 20

## Warp Gems teal, Gold the gold coin (owner 2026-10-28: "Change T-stones currency to Gold").
const GEM_COL := Color("#5ED3E0")
const STONE_COL := Color("#E6BE54")

func _init() -> void:
	name = "CurrencyBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_END
	gems_label = _pill(&"warp_gem", GEM_COL, "Warp Gems (premium)")
	add_btn = Button.new()
	add_btn.name = "AddGems"
	add_btn.text = "+"
	add_btn.tooltip_text = "Get Warp Gems"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.custom_minimum_size = Vector2(64, 64)
	add_btn.add_theme_stylebox_override("normal", _round(Color(GEM_COL, 0.22), GEM_COL))
	add_btn.add_theme_stylebox_override("hover", _round(Color(GEM_COL, 0.4), GEM_COL))
	add_btn.add_theme_stylebox_override("pressed", _round(Color(GEM_COL, 0.55), GEM_COL))
	add_btn.add_theme_color_override("font_color", GEM_COL)
	add_btn.pressed.connect(_on_add)
	add_child(add_btn)
	stones_label = _pill(&"t_stone", STONE_COL, "Gold")
	_note = Label.new()
	_note.name = "StoreNote"
	_note.text = "Warp Gem store is not open yet."
	_note.visible = false
	_note.top_level = true
	_note.add_theme_color_override("font_color", UiTokens.TEXT)
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = Color(0, 0, 0, 0.85)
	nsb.set_corner_radius_all(6)
	nsb.set_content_margin_all(8)
	_note.add_theme_stylebox_override("normal", nsb)
	add_child(_note)
	set_process(true)

## Hide the T-stone pill where the host shows its own coin balance (the market's server wallet).
func show_stones(on: bool) -> void:
	stones_label.get_parent().get_parent().visible = on

## Type size for the view (the host calls it on layout).
func set_px(px: int) -> void:
	_px = maxi(UiTokens.TYPE_MIN, px)
	for l: Label in [gems_label, stones_label, _note]:
		l.add_theme_font_size_override("font_size", _px)
	for ic in find_children("Icon", "TextureRect", true, false):
		(ic as TextureRect).custom_minimum_size = Vector2(_px + 6, _px + 6)
	add_btn.add_theme_font_size_override("font_size", _px + 6)

func _process(_dt: float) -> void:
	refresh()

func refresh() -> void:
	var now := Vector2i(World.warp_gems, World.t_stones)
	if now == _shown:
		return
	_shown = now
	gems_label.text = thousands(now.x)
	stones_label.text = thousands(now.y)

func _on_add() -> void:
	add_pressed.emit()
	if add_pressed.get_connections().is_empty():
		_note.visible = true
		_note.position = add_btn.global_position + Vector2(-160.0, add_btn.size.y + 4.0)
		get_tree().create_timer(2.5).timeout.connect(func () -> void: _note.visible = false)

## Icon + number on a dark rounded pill; returns the number's label.
func _pill(icon: StringName, col: Color, tip: String) -> Label:
	var p := PanelContainer.new()
	p.name = str(icon).capitalize().replace(" ", "")
	p.tooltip_text = tip
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := _round(Color(0, 0, 0, 0.55), Color(col, 0.0))
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var ic := TextureRect.new()
	ic.name = "Icon"
	ic.texture = UiIcons.icon(icon)
	ic.modulate = col
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(26, 26)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := Label.new()
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", UiTokens.TEXT)
	row.add_child(l)
	add_child(p)
	return l

static func _round(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0.0 else 0)
	sb.set_corner_radius_all(22)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
