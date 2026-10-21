class_name EquipmentSlot
extends Control
## One cell of the 3x3 gear grid on Character -> Gear and Equipment (spec 13 s14, references 2-3):
## a dark compartment with a faded silhouette of what goes there when empty, the real art with
## "Lv. N" and wear when something is worn, and the yellow brackets when selected. The cell layout
## (which slot sits where, the silhouettes) is data: data/inv_ui.json equipment_grid.

signal pressed(slot: StringName)

## Equipment slot id (&"head", ...), &"tool" for the held tool, &"" for a blank cell.
var slot: StringName = &""
var stack: ItemStack
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()
var lv_px := 20
var _ghost: Control
## 1 -> 0 after an equip lands here (InvMotion.FLASH_S): a short gold light-up.
var _flash := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ghost = Control.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.material = HexButton.white_material() # one flat tone: a silhouette, not faded colour art
	_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost.draw.connect(_draw_ghost)
	add_child(_ghost)

## Shows what `inv` has in this cell now.
func show_from(inv: Inventory) -> void:
	stack = null
	if inv and slot == &"tool":
		var i := inv.equipped_tool_index
		stack = inv.slots[i] if i >= 0 and i < inv.slot_count else null
	elif inv and slot != &"":
		stack = inv.equipped_in(slot)
	var d := stack.def() if stack else null
	tooltip_text = (d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(slot))) if slot != &"" else ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if slot != &"" else Control.CURSOR_ARROW
	queue_redraw()
	_ghost.queue_redraw()

## Small transfer feedback (spec 13 s20): the cell lights up briefly as gear goes on.
func flash() -> void:
	InvMotion.run(self, func(t: float) -> void:
		_flash = 1.0 - t
		queue_redraw(), InvMotion.FLASH_S)

func _gui_input(event: InputEvent) -> void:
	if slot == &"":
		return
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		pressed.emit(slot)
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(InvTheme.CELL_DARK, 0.72))
	InvPaint.dashed(self, Vector2(size.x, 0), Vector2(size.x, size.y))
	InvPaint.dashed(self, Vector2(0, size.y), Vector2(size.x, size.y))
	if stack:
		InvPaint.item_icon(self, stack.def_id, r, 0.62, 0.54)
		InvPaint.level(self, LevelDisplay.label(stack.level) if stack.level > 0 else "", r, lv_px, minf(size.x, size.y))
		InvPaint.durability(self, r, stack)
		if stack.is_locked():
			InvPaint.lock_pip(self, r, minf(size.x, size.y))
	if _flash > 0.0:
		draw_rect(r, Color(InvTheme.SELECT, 0.3 * _flash))
	if selected:
		InvPaint.brackets(self, r.grow(-2.0), minf(size.x, size.y))

func _draw_ghost() -> void:
	if stack or slot == &"":
		return
	var grid: Dictionary = InvView.data().get("equipment_grid", {})
	var tone := Color(0.62, 0.62, 0.58, float(grid.get("silhouette_alpha", 0.22)))
	var id := str((grid.get("silhouette_ids", {}) as Dictionary).get(str(slot), ""))
	var r := Rect2(Vector2.ZERO, size)
	if id != "":
		InvPaint.item_icon(_ghost, StringName(id), r, 0.56, 0.52, tone)
	else: # no item art for these slots: soft painted shapes, as the reference's faded silhouettes
		match str((grid.get("silhouette_glyphs", {}) as Dictionary).get(str(slot), "")):
			"amulet":
				InvGlyphs.amulet(_ghost, r.grow(-minf(size.x, size.y) * 0.24), tone)
			"bag":
				var tex := UiIcons.icon(&"bag")
				var s := minf(size.x, size.y) * 0.46
				if tex:
					_ghost.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false, tone)

## The nine cells of data/inv_ui.json equipment_grid, added to `parent`; each emits pressed(slot).
static func grid(parent: Control, on_press: Callable) -> Array[EquipmentSlot]:
	var out: Array[EquipmentSlot] = []
	for id in (InvView.data().get("equipment_grid", {}) as Dictionary).get("cells", []):
		var c := EquipmentSlot.new()
		c.slot = StringName(str(id))
		c.pressed.connect(on_press)
		parent.add_child(c)
		out.append(c)
	return out

## Three a row filling `area`, like the references (Equipment's are taller than wide).
static func layout(cells: Array[EquipmentSlot], area: Rect2, lv: int) -> void:
	var cell := (area.size / 3.0).floor()
	for i in cells.size():
		cells[i].position = area.position + Vector2(i % 3, floori(i / 3.0)) * cell
		cells[i].size = cell
		cells[i].lv_px = lv
