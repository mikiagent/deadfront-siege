class_name UiWorldSheet
extends Control
## A full-screen sheet with the shared §8 chrome (SheetChrome) and an open/relayout lifecycle:
## backdrop, header (a SheetChrome named "Header"), `body` for the panels. Subclasses build their
## panels under `body` in `_build()` and place them in `_layout_body(view, rect)`; `rect` is the free
## area under the header. The header counter is rich text (GOLD numbers) in the chrome's right slot.
## Every §8 part (GOLD button, panels, parchment, brackets) comes from SheetChrome's static helpers.
## Used by DomainScreen (F1), CommsUI / RadioUniversityUI (F3) and TamingPenUI (E2).

signal back_pressed
signal close_pressed

var backdrop: ColorRect
var header: SheetChrome
var back_btn: Button
var title_label: Label
var counter: RichTextLabel
var close_btn: Button
var body: Control

var _title_text := ""

func _init(p_title: String = "") -> void:
	_title_text = p_title

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 44
	theme = SheetChrome.ui_theme()
	backdrop = SheetChrome.backdrop()  # the sheet owns the screen; taps never reach the world
	add_child(backdrop)
	body = Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	header = SheetChrome.new(_title_text)
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(header)
	back_btn = header.back
	close_btn = header.close
	title_label = header.title
	header.back_pressed.connect(func () -> void: back_pressed.emit())
	header.close_pressed.connect(func () -> void: close_pressed.emit())
	counter = RichTextLabel.new()
	counter.name = "Counter"
	counter.bbcode_enabled = true
	counter.fit_content = true
	counter.scroll_active = false
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	counter.add_theme_font_override("normal_font", UiTokens.ui_face())
	_build()
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()

## Subclasses add their panels to `body` here.
func _build() -> void:
	pass

## Subclasses place their panels inside `rect` (screen space, under the header).
func _layout_body(_view: Vector2, _rect: Rect2) -> void:
	pass

static func header_h(view: Vector2) -> float:
	return SheetChrome.header_for(view)

static func side_pad(view: Vector2) -> float:
	return SheetChrome.side_for(view)

## GOLD-numbered counter text, e.g. "Active missions [color=#…]1[/color] / 4".
func set_counter(bb: String) -> void:
	counter.text = bb
	if bb != "" and counter.get_parent() == null:
		header.right.add_child(counter)
	relayout()

func relayout() -> void:
	if body == null:
		return
	var view := get_viewport_rect().size
	var compact := UiTokens.is_compact(view)
	var cpx := SheetChrome.counter_px(view)
	counter.add_theme_font_size_override("normal_font_size", cpx)
	counter.custom_minimum_size.x = UiTokens.ui_face().get_string_size(counter.get_parsed_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, cpx).x + 4.0
	header.layout(view)
	var hh := header_h(view)
	var side := side_pad(view)
	var top := hh + (8.0 if compact else 24.0)
	var rect := Rect2(side, top, view.x - side * 2.0, view.y - top - (8.0 if compact else 32.0))
	body.position = Vector2.ZERO
	body.size = view
	_layout_body(view, rect)
	if not _settling:
		_settle()

var _settling := false

## Containers grow to their children's minimum size, and an autowrapped label's first minimum is
## measured at its pre-layout width (one word a line: thousands of px). One more pass a frame later,
## once the labels know their real width, puts every panel back at the size this layout gives it.
func _settle() -> void:
	_settling = true
	await get_tree().process_frame
	if is_inside_tree():
		relayout()
	_settling = false

## Every visible Button under `root` (gates: tap size, in-view, overlap).
static func buttons_in(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree():
			out.append(b)
	return out

## Smallest side of any visible button (the tap-target gate).
func min_target_px() -> float:
	var lo := INF
	for b in buttons_in(self):
		var r := b.get_global_rect()
		lo = minf(lo, minf(r.size.x, r.size.y))
	return lo if lo < INF else 0.0
