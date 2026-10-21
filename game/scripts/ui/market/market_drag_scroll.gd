class_name MarketDragScroll
extends ScrollContainer
## A market list that scrolls by dragging (finger or mouse; the wheel works as in any
## ScrollContainer) and follows keyboard / gamepad focus. Its rows are MOUSE_FILTER_PASS buttons,
## so a press on a row reaches this container too: once the press moves past DEADZONE it is a
## scroll, and tap_ok() is false while it is let go (the row gets the release first, then this
## container), so the row under the finger does not fire. Godot's own drag-scroll needs a
## touchscreen and never sees a press that a STOP button took: a phone could not scroll a list of rows.

const DEADZONE := 10.0

var dragged := false ## the press being let go became a scroll
var _down := false
var _from_y := 0.0
var _from_scroll := 0

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	follow_focus = true

## False while a press that turned into a scroll is let go: the row it started on must not fire.
func tap_ok() -> bool:
	return not dragged

func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_down = mb.pressed
		dragged = false # on a release the row has already asked tap_ok(); keys and pads tap again
		if mb.pressed:
			_from_y = mb.position.y
			_from_scroll = scroll_vertical
		accept_event() # one scroller: the built-in touch drag would move the list a second time
		return
	var mm := e as InputEventMouseMotion
	if mm == null or not _down or not (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		return
	accept_event()
	var dy := mm.position.y - _from_y
	if not dragged and absf(dy) < DEADZONE:
		return
	dragged = true
	scroll_vertical = _from_scroll - roundi(dy)
