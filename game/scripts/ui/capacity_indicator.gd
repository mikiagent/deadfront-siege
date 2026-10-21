class_name CapacityIndicator
extends Control
## "[bag] 91 / 100" from the real bag (spec 13 s4): used slots (a caged animal counts its 4) over
## slot_count, which capacity bonuses change. The count turns to the warning colour when full.

var inventory: Inventory
var font_px := 34

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind(inv: Inventory) -> void:
	if inventory and inventory.changed.is_connected(refresh):
		inventory.changed.disconnect(refresh)
	inventory = inv
	if inventory:
		inventory.changed.connect(refresh)
	refresh()

func label_text() -> String:
	return "%d / %d" % [inventory.used_slots(), inventory.slot_count] if inventory else ""

func is_full() -> bool:
	return inventory != null and inventory.used_slots() >= inventory.slot_count

func count_color() -> Color:
	return InvTheme.DANGER if is_full() else InvTheme.TEXT

## Width this indicator needs at its font size: icon + gap + text.
func wanted_width() -> float:
	var f := InvTheme.font_at(font_px)
	return font_px * 1.1 + 8.0 + f.get_string_size(label_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x

## Re-measure and repaint (the count, or the font size, changed).
func refresh() -> void:
	custom_minimum_size = Vector2(wanted_width(), font_px * 1.2)
	queue_redraw()

func _draw() -> void:
	if inventory == null:
		return
	var f := InvTheme.font_at(font_px)
	var icon := UiIcons.icon(&"bag")
	var s := font_px * 1.1
	var y := (size.y - s) * 0.5
	if icon:
		draw_texture_rect(icon, Rect2(0, y, s, s), false, InvTheme.SELECT) # the bag is a thing: yellow, as in the reference
	var base := (size.y + f.get_ascent(font_px) - f.get_descent(font_px)) * 0.5
	var x := s + 8.0
	# "91" and "100" in the count colour, the slash grey (reference).
	for part in [["%d" % inventory.used_slots(), count_color()], [" / ", InvTheme.TEXT_2], ["%d" % inventory.slot_count, count_color()]]:
		draw_string(f, Vector2(x, base), part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, part[1])
		x += f.get_string_size(part[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
