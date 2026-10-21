class_name GearScreen
extends Control
## What Character -> Gear and Equipment / My Info share (spec 13 s13-16, references 2 and 3): the
## black header, the 3x3 gear cells, and the right-hand column listing what can go in the selected
## cell (the worn piece first with its green mark, then the bag's exact instances) over one yellow
## action. Gear changes go through InvActions -> PlayerActions, the same commands as the Bag. The
## subclasses lay out their own left / centre panels in _layout_body.

signal back_pressed
signal close_pressed

var player: Player
var inventory: Inventory
var header: InvHeader
var cells: Array[EquipmentSlot] = []
## Candidates for the selected cell, on the shared bag grid.
var list: InventoryGrid
var primary: Button
## Grey lines over the action: the targeted piece's own numbers (spec 13 s14: its properties beside
## Unequip), or why there is no action (locked, nothing to equip) or the last refusal.
var note: Label
var slot: StringName = &""
var _action: StringName = &""
var _refusal := ""
var _m := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(InvTheme.backdrop()) # opaque: HUD controls must not show through a modal screen
	_build_body()
	cells = EquipmentSlot.grid(self, select_slot)
	list = InventoryGrid.new()
	list.columns = 3
	add_child(list)
	list.selection_changed.connect(_on_pick)
	note = Label.new()
	note.add_theme_color_override("font_color", InvTheme.TEXT_2)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)
	primary = Button.new()
	primary.focus_mode = Control.FOCUS_NONE
	primary.clip_text = true
	primary.add_to_group(&"inv_contextual")
	primary.pressed.connect(_run)
	add_child(primary)
	header = InvHeader.new()
	header.show_stones = false # the Character and Equipment references carry no currency
	add_child(header)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	resized.connect(_layout)

## Subclass panels (built before the shared parts, so the header draws on top).
func _build_body() -> void:
	pass

func bind(inv: Inventory, p: Player) -> void:
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = inv
	player = p
	list.bind(inv)
	if inventory:
		inventory.changed.connect(_on_inventory_changed)
	refresh()

## Re-read the bag and the worn gear (the host calls it on open).
func refresh() -> void:
	for c in cells:
		c.show_from(inventory)
	_fill_list()
	_update()

## Select gear cell `s`: its brackets, its candidates on the right.
func select_slot(s: StringName) -> void:
	if s == &"":
		return
	slot = s
	_refusal = ""
	for c in cells:
		c.selected = c.slot == slot
	list.select_uid("")
	_fill_list()
	_update()

## Keyboard (spec 13 s21): the gear cell beside the selected one (blank cells are skipped).
func move_slot(dir: Vector2i) -> bool:
	var at := 0
	for i in cells.size():
		if cells[i].slot == slot:
			at = i
	var x := at % 3
	var y := at / 3
	for _step in 2: # a 3x3: at most two cells away
		x += dir.x
		y += dir.y
		if x < 0 or x > 2 or y < 0 or y > 2:
			return false
		if cells[y * 3 + x].slot != &"":
			select_slot(cells[y * 3 + x].slot)
			return true
	return false

## Enter: the column's yellow action, when there is one.
func press_primary() -> bool:
	if not primary.visible or _action == &"":
		return false
	primary.pressed.emit()
	return true

## The instance in the selected cell now (worn gear, or the held tool).
func worn() -> ItemStack:
	for c in cells:
		if c.slot == slot:
			return c.stack
	return null

## The candidate picked in the list (the worn one counts), else null.
func picked() -> ItemStack:
	var uid := list.selected_uid()
	if uid == "":
		return null
	var w := worn()
	if w and w.uid == uid:
		return w
	var i := list.selected_index()
	return inventory.slots[i] if i >= 0 else null

func _fill_list() -> void:
	var w := worn()
	list.pinned = w if slot != &"tool" else null
	list.worn_uid = w.uid if w and slot == &"tool" else ""
	list.set_view(&"level", StringName("slot:%s" % slot) if slot != &"" else &"slot:none")

## The selected candidate, or the worn piece when nothing is picked: what the action applies to.
func target() -> ItemStack:
	var p := picked()
	return p if p else worn()

func ctx() -> Dictionary:
	var t := target()
	return {"where": &"equipment", "player": player, "slot": slot, "worn": t != null and t == worn()}

func _on_pick(uid: String) -> void:
	if uid != "":
		_refusal = "" # a new pick; clearing the pick keeps the last refusal on screen
	_update()

func _update() -> void:
	var t := target()
	var acts: Array[StringName] = []
	if t:
		acts = InvActions.valid(t, ctx())
	_action = acts[0] if not acts.is_empty() else &""
	primary.visible = _action != &""
	primary.text = InvActions.label(_action)
	var why := _refusal
	if why == "" and t and t.is_locked():
		why = "Locked: unlock it in the Bag to wear it."
	elif why == "" and slot != &"" and list.item_cells().is_empty():
		why = "There are no items available to equip."
	note.text = why if why != "" or t == null else describe(t)
	_layout()

## "Forager Vest Lv. 12" over "Armor 110 · Durability 80 / 100 · Firm Lv. 3".
static func describe(s: ItemStack) -> String:
	var d := s.def()
	var bits := PackedStringArray()
	if s.scaled_damage() > 0.0:
		bits.append("Damage %.0f" % s.scaled_damage())
	if s.scaled_armor() > 0.0:
		bits.append("Armor %.0f" % s.scaled_armor())
	if d and d.health_bonus > 0.0:
		bits.append("Max health +%.0f" % d.health_bonus_at(s.level))
	if d and d.tool_class not in [&"", &"none"]:
		bits.append("%s %.2fx" % [str(d.tool_class).capitalize(), s.gather_power()])
	if s.max_durability > 0:
		bits.append("Durability %d / %d" % [s.durability, s.max_durability])
	for cls: String in ["positive", "negative", "rare"]:
		for r: Dictionary in InvAttributes.sections(s)[cls]:
			bits.append(InvAttributes.line(r))
	var title := d.display_name if d and d.display_name != "" else str(s.def_id)
	return "%s %s\n%s" % [title, LevelDisplay.label(s.level), " · ".join(bits)]

func _run() -> void:
	var t := target()
	if t == null or _action == &"":
		return
	var c := ctx()
	var i := list.selected_index() if not c.worn else -1
	var ok := InvActions.run(_action, player, i, c)
	if ok:
		for cell in cells:
			if cell.slot == slot:
				cell.flash()
	list.select_uid("")
	_refusal = "" if ok else InvActions.last_refusal
	_update()

func _on_inventory_changed() -> void:
	if is_visible_in_tree():
		refresh.call_deferred()

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := InvTheme.safe(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var head_h: float = _m.header_h + safe.z
	header.position = Vector2.ZERO
	header.size = Vector2(size.x, head_h)
	header.insets = safe
	header.apply_metrics(_m)
	var top: float = head_h + _m.gap
	var body := Rect2(Vector2(_m.margin + safe.w, top), Vector2(size.x - _m.margin * 2.0 - safe.w - safe.x, size.y - top - _m.margin - safe.y))
	var right_w := floorf(body.size.x * _right_share())
	var col := Rect2(Vector2(body.end.x - right_w, body.position.y), Vector2(right_w, body.size.y))
	_layout_body(Rect2(body.position, Vector2(body.size.x - right_w - _m.gap, body.size.y)))
	# Right column: candidates over one yellow action, like the references' Unequip / Equip.
	var act_h: float = _m.primary_h
	var bar := act_h + float(_m.margin) * 2.0
	list.lv_px = maxi(UiTokens.TYPE_MIN, int(_m.lv_font) - 2)
	list.new_px = int(_m.new_font)
	var empty := list.item_cells().is_empty()
	note.visible = note.text != ""
	# The note is as tall as its wrapped lines (at most 45 % of the column); the list takes the rest.
	var inset: float = float(_m.margin) * 2.0
	note.add_theme_font_size_override("font_size", int(_m.row_font) - (2 if _m.compact else 0))
	note.size = Vector2(col.size.x - inset * 2.0, 0.0)
	var line_h := float(note.get_line_height())
	var cap := floorf(col.size.y * 0.45 / line_h)
	note.max_lines_visible = int(cap)
	var nh := (minf(float(note.get_line_count()), cap) * line_h + 8.0) if note.visible else 0.0
	note.size = Vector2(col.size.x - inset * 2.0, nh)
	list.position = col.position
	list.size = Vector2(col.size.x, col.size.y - bar - (nh if not empty else 0.0))
	list.min_rows = maxi(1, ceili(list.size.y / maxf(1.0, floorf((col.size.x - 2.0) / 3.0))))
	list.refresh()
	primary.size = Vector2(col.size.x - float(_m.margin) * 2.0, act_h)
	primary.position = Vector2(col.position.x + float(_m.margin), col.end.y - _m.margin - act_h)
	InvTheme.style_primary(primary, int(_m.button_font))
	note.position = Vector2(col.position.x + inset, (list.position.y + list.size.y * 0.5 - nh * 0.5) if empty else col.end.y - bar - nh)

## Share of the width the candidate column takes (reference 2: 26 %, reference 3: 25 %).
func _right_share() -> float:
	return 0.26

## Lay out the left and centre panels in `area` (everything left of the candidate column).
func _layout_body(_area: Rect2) -> void:
	pass
