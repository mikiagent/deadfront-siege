class_name InventorySlot
extends Control
## One compartment of the bag grid (spec 13 s5-8): flat, transparent over the textured panel,
## a faint dashed edge, the item centred, "Lv. N" top-right, NEW top-left, brackets when selected.
## Empty cells stay visible. `uid` is the instance's identity (or "#<slot>" for a fungible stack).

signal pressed(slot: InventorySlot)

var uid := ""
var index := -1
var stack: ItemStack
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()
var lv_px := 20
var new_px := 15
## One compartment's side: labels and brackets keep this weight on a 2x2 cage.
var unit := 96.0
## Worn now (Character / Equipment candidate lists): a small green mark top-left, like Durango's.
var worn := false
var _rare := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS # the grid's scroll still drags through a cell
	focus_mode = Control.FOCUS_NONE

## Shows `s` (null = empty compartment) at bag slot `i`.
func set_stack(s: ItemStack, i: int, key: String) -> void:
	stack = s
	index = i
	uid = key
	_rare = s != null and InvAttributes.has_rare(s)
	var d := s.def() if s else null
	tooltip_text = (d.display_name if d and d.display_name != "" else str(s.def_id)) if s else ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if s else Control.CURSOR_ARROW
	queue_redraw()

func level_text() -> String:
	return LevelDisplay.label(stack.level) if stack and stack.level > 0 else ""

func shows_new() -> bool:
	return stack != null and &"new" in stack.flags

func shows_rare() -> bool:
	return _rare

func shows_lock() -> bool:
	return stack != null and stack.is_locked()

func _gui_input(event: InputEvent) -> void:
	if stack == null:
		return
	var tap := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tap:
		pressed.emit(self)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	InvPaint.dashed(self, Vector2(size.x, 0), Vector2(size.x, size.y))
	InvPaint.dashed(self, Vector2(0, size.y), Vector2(size.x, size.y))
	if stack == null:
		return
	# Span items (a cage) fill their block; single cells keep the art clear of the label row.
	var span := stack.slot_span() > 1
	InvPaint.item_icon(self, stack.def_id, r, 0.78 if span else 0.6, 0.55 if span else 0.58)
	if worn:
		InvPaint.worn_marker(self, r, unit)
	elif shows_new():
		InvPaint.new_tag(self, r, new_px, unit)
	InvPaint.level(self, level_text(), r, lv_px, unit)
	if _rare:
		InvPaint.rare_marker(self, r, unit)
	if shows_lock():
		InvPaint.lock_pip(self, r, unit)
	InvPaint.durability(self, r, stack)
	if stack.is_fungible():
		InvPaint.count(self, r, stack.count, lv_px)
	if selected: # last, so the corners sit on top of the marks inside them
		InvPaint.brackets(self, r.grow(-1.0), unit)
