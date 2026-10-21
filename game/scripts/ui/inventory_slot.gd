class_name InventorySlot
extends Control
## One compartment of the bag grid (spec 13 s5-8): flat, transparent over the textured panel,
## a faint dashed edge, the item centred, "Lv. N" top-right, NEW top-left, trait pips under the art,
## brackets when selected (the gold check in multi-select).
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
## Multi-select: a selected cell shows the gold check (storage reference) instead of the brackets.
var checks := false:
	set(v):
		if checks != v:
			checks = v
			queue_redraw()
var _rare := false
## 0 -> 1 as the brackets settle onto a new selection (InvMotion.SETTLE_S); 1 at rest.
var _settle := 1.0

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

## Desktop hover (spec 13 s21): the same facts the inspect panel gives on a tap, in words, so a
## trait's class never rests on its colour alone.
func _get_tooltip(_at: Vector2) -> String:
	return describe(stack) if stack else ""

## "Raptor Bone Lv. 60" then one line per trait ("Rare trait: Black Sheen"), NEW and Locked.
static func describe(s: ItemStack) -> String:
	var d := s.def()
	var title := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))
	var lines := PackedStringArray(["%s %s" % [title, LevelDisplay.label(s.level)] if s.level > 0 else title])
	var sec := InvAttributes.sections(s)
	for cls: StringName in [&"positive", &"negative", &"rare"]:
		for r: Dictionary in sec[str(cls)]:
			lines.append("%s: %s" % [ItemInspectPanel.TraitChip.CLASS_WORDS[cls], InvAttributes.line(r)])
	if &"new" in s.flags:
		lines.append("New")
	if s.is_locked():
		lines.append("Locked")
	return "\n".join(lines)

## Subtle selection feedback (spec 13 s20): the brackets close in from just outside the cell.
func settle_in() -> void:
	_settle = 0.0
	InvMotion.run(self, func(t: float) -> void:
		_settle = t
		queue_redraw(), InvMotion.SETTLE_S)

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
	# Span items (a cage) fill their block; single cells keep the art clear of the labels and pips.
	var span := stack.slot_span() > 1
	InvPaint.item_icon(self, stack.def_id, r, 0.78 if span else 0.56, 0.55)
	if worn:
		InvPaint.worn_marker(self, r, unit)
	elif shows_new():
		InvPaint.new_tag(self, r, new_px, unit)
	InvPaint.level(self, level_text(), r, lv_px, unit)
	InvPaint.pips(self, r, stack, unit)
	if shows_lock():
		InvPaint.lock_pip(self, r, unit)
	InvPaint.durability(self, r, stack)
	if stack.is_fungible():
		InvPaint.count(self, r, stack.count, lv_px)
	if selected and checks:
		InvPaint.check(self, r, unit)
	elif selected: # last, so the corners sit on top of the marks inside them
		InvPaint.brackets(self, r.grow(-1.0 + InvMotion.SETTLE_PX * (1.0 - _settle)), unit)
