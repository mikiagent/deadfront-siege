class_name BagInspect
extends PanelContainer
## Bag inspect panel (owner spec 31 §9 "Bag Inspection UI", §9 "Equipment Comparison").
## Shows a bag's level next to its storage capacity, the breakdown from BagCapacity (base curve,
## inherited attributes, Pocket, the type's own modifier), crafting quality and durability, and the
## capacity change against the bag worn in the same slot: green for an improvement, the warning
## colour for a reduction. The same text is used by the dev lab so screenshots and asserts agree.
## Runs in the bag screen's CanvasLayer; the panel is a 64 px tap target on phones.

signal closed

const UP := Color(0.42, 0.88, 0.48)
const DOWN := Color(0.95, 0.45, 0.38)
const INK := Color(0.95, 0.95, 0.93)
const META := Color(0.72, 0.74, 0.72)

var slot_index: int = -1
var _inventory: Inventory
var _title: Label
var _body: Label
var _compare: Label
var _close_btn: Button
## Set by show_stack: what the panel printed (tests and the lab read these, not the widgets).
var shown_bag_id: StringName = &""
var shown_breakdown: Dictionary = {}
var shown_change: int = 0
var shown_worn_total: int = 0
var shown_new_total: int = 0
var shown_min_px: float = 0.0
## True when the whole panel, Close button included, sits inside the view (the lab checks it).
var shown_fits := false

func _ready() -> void:
	visible = false
	z_index = 56
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.95)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.name = "BagTitle"
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", INK)
	box.add_child(_title)
	_body = Label.new()
	_body.name = "BagBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_color_override("font_color", INK)
	box.add_child(_body)
	_compare = Label.new()
	_compare.name = "BagCompare"
	_compare.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compare.add_theme_font_size_override("font_size", 16)
	box.add_child(_compare)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(280, 64)
	_close_btn.pressed.connect(hide_panel)
	box.add_child(_close_btn)

## The lines the panel shows for a bag instance in `inv` (the worn bag in its slot is the "current").
## Also fills the shown_* fields so callers can assert without scraping labels.
func show_stack(stack: ItemStack, index: int, inv: Inventory = null) -> void:
	slot_index = index
	_inventory = inv
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	var compact := UiTokens.is_compact(view)
	var body_px := 13 if compact else 16
	shown_bag_id = BagCapacity.bag_id_of(stack.def_id) if stack else &""
	shown_breakdown = BagCapacity.of_stack(stack)
	var d := stack.def() if stack else null
	var b := shown_breakdown
	_title.text = str(d.display_name) if d else "Bag"
	_title.add_theme_font_size_override("font_size", 17 if compact else 20)
	var lines: PackedStringArray = []
	lines.append("Level %d" % stack.level)
	lines.append("Storage Capacity: +%d" % int(b.get("total", 0)))
	var storage: Dictionary = b.get("storage", {})
	var extra: PackedStringArray = []
	for key: Variant in storage:
		extra.append("%s +%d" % [String(key).capitalize(), int(storage[key])])
	if int(b.get("capacity", 0)) > 0:
		extra.append("Capacity +%d" % int(b.get("capacity", 0)))
	if int(b.get("other", 0)) > 0:
		extra.append("Bag modifier +%d" % int(b.get("other", 0)))
	if compact:
		# A landscape phone is 390 px tall: the itemised list became a scroll play. One line per
		# fact, the breakdown folded into the capacity line (the same numbers, just inline).
		lines.append("Base +%d · Pocket Lv. %d +%d%s" % [int(b.get("base", 0)), int(b.get("pocket_level", 0)), int(b.get("pocket", 0)), "" if extra.is_empty() else " · " + " · ".join(extra)])
		lines.append("Quality %s · Durability %d/%d" % [quality_text(stack), stack.durability, maxi(stack.max_durability, stack.durability)])
	else:
		lines.append("Base Capacity: +%d" % int(b.get("base", 0)))
		for key: Variant in storage:
			lines.append("%s: +%d" % [String(key).capitalize(), int(storage[key])])
		lines.append("Pocket Lv. %d: +%d" % [int(b.get("pocket_level", 0)), int(b.get("pocket", 0))])
		if int(b.get("capacity", 0)) > 0:
			lines.append("Capacity attribute: +%d" % int(b.get("capacity", 0)))
		if int(b.get("other", 0)) > 0:
			lines.append("Bag modifier: +%d" % int(b.get("other", 0)))
		lines.append("Crafting Quality: %s" % quality_text(stack))
		lines.append("Durability: %d/%d" % [stack.durability, maxi(stack.max_durability, stack.durability)])
	_body.text = "\n".join(lines)
	_body.add_theme_font_size_override("font_size", body_px)
	# Compare against the bag currently worn in the bag's own slot (spec 31 §9).
	shown_change = 0
	shown_worn_total = 0
	shown_new_total = 0
	var slot := BagDef.slot(shown_bag_id)
	if inv != null and slot != &"":
		var cur: Variant = inv.equipment.get(str(slot))
		if cur is ItemStack and BagCapacity.is_bag((cur as ItemStack).def_id) and (cur as ItemStack).uid != stack.uid:
			shown_worn_total = int(BagCapacity.of_stack(cur).get("total", 0))
			shown_new_total = int(b.get("total", 0))
			shown_change = shown_new_total - shown_worn_total
			var color := UP if shown_change > 0 else (DOWN if shown_change < 0 else META)
			_compare.text = "Current +%d → new +%d\nCapacity change: %+d slots" % [shown_worn_total, shown_new_total, shown_change] if compact else "Current bag: +%d slots\nNew bag: +%d slots\nCapacity change: %+d slots" % [shown_worn_total, shown_new_total, shown_change]
			_compare.add_theme_color_override("font_color", color)
			_compare.visible = true
		else:
			shown_new_total = int(b.get("total", 0))
			shown_change = shown_new_total
			_compare.text = "No bag worn\nCapacity change: +%d slots" % shown_new_total
			_compare.add_theme_color_override("font_color", UP)
			_compare.visible = true
	else:
		_compare.text = ""
		_compare.visible = false
	shown_min_px = _close_btn.custom_minimum_size.y
	_compare.add_theme_font_size_override("font_size", 14 if compact else 16)
	# A landscape phone is 390 px tall: a narrow column wrapped every line and the Close button fell
	# off the screen (lab shot). Wide and short: the panel takes most of the width and is clamped
	# into the view, so nothing is left below the fold.
	# On a phone the panel stops short of the screen's own close button in the corner, or the two
	# icons stack on top of each other (844x390 shot).
	var target_w := minf(view.x - 16.0, view.x - 120.0 if compact else 420.0)
	# The labels are given the width they will have before the panel is measured: an autowrapped
	# label in a zero-width column counts one word per line, and the panel came out 6500 px tall.
	var inner := target_w - 28.0
	_body.custom_minimum_size = Vector2(inner, 0)
	_compare.custom_minimum_size = Vector2(inner, 0)
	custom_minimum_size = Vector2(target_w, 0)
	visible = true
	# The height is only right once the labels rewrapped, which Godot does at the end of the frame.
	_fit_to_view.call_deferred()

## Sizes the panel to its content and keeps it inside the view, Close button included.
func _fit_to_view() -> void:
	if not is_inside_tree() or not visible:
		return
	var view := get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
	reset_size()
	size = get_combined_minimum_size()
	var start := Vector2(view.x * 0.5 - size.x * 0.5, view.y * 0.22 if not UiTokens.is_compact(view) else 8.0)
	position = Vector2(int(clampf(start.x, 8.0, maxf(8.0, view.x - size.x - 8.0))), int(clampf(start.y, 8.0, maxf(8.0, view.y - size.y - 8.0))))
	shown_fits = size.y <= view.y - 16.0 and size.x <= view.x - 16.0

## "Normal" unless the instance carries a crafting-quality attribute; a flawless marker reads so.
func quality_text(stack: ItemStack) -> String:
	if stack == null:
		return "Normal"
	var q: Variant = stack.attributes.get("quality", null)
	if q != null and str(q) != "":
		return str(q).capitalize()
	if bool(stack.flags.has(&"flawless")):
		return "Flawless"
	return "Normal"

func hide_panel() -> void:
	visible = false
	slot_index = -1
	closed.emit()

## The inspect text without a live panel (tooltips, the lab's printout).
static func text_for(stack: ItemStack, inv: Inventory = null) -> String:
	var b := BagCapacity.of_stack(stack)
	var d := stack.def() if stack else null
	var lines: PackedStringArray = [str(d.display_name) if d else "Bag", "Level %d" % stack.level,
		"Storage Capacity: +%d" % int(b.get("total", 0)), "Base Capacity: +%d" % int(b.get("base", 0)),
		"Pocket Lv. %d: +%d" % [int(b.get("pocket_level", 0)), int(b.get("pocket", 0))],
		"Crafting Quality: %s" % ("Flawless" if stack and stack.flags.has(&"flawless") else str(stack.attributes.get("quality", "Normal")).capitalize()),
		"Durability: %d/%d" % [stack.durability, stack.max_durability]]
	if inv != null:
		var slot := BagDef.slot(BagCapacity.bag_id_of(stack.def_id))
		var cur: Variant = inv.equipment.get(str(slot)) if slot != &"" else null
		if cur is ItemStack and (cur as ItemStack).uid != stack.uid:
			var change := int(b.get("total", 0)) - int(BagCapacity.of_stack(cur).get("total", 0))
			lines.append("Capacity change: %+d slots" % change)
	return "\n".join(lines)
