class_name PetGearSheet
extends UiWorldSheet
## SADDLES: one tame's equipment (PetRecord.gear), opened from the pet radial's Gear and the Animals
## screen's Gear. Left: the tame on its stage, wearing what it wears, and the saddle size it takes.
## Right: the SADDLE slot and every saddle in the bag (fitting ones first). Tap a bag saddle to put it
## on, or drag it onto the slot; tap the slot's Unequip, or drag the slot back onto the bag list, to take
## it off. Taking the saddle off the tame she rides dismounts her first (PetGear.unequip).
## ‹ goes back to whatever was under it (the Animals screen stays open beneath), ✕ closes to the HUD.

const CELL_DESK := 96.0
const CELL_PHONE := 64.0

var player: Player
var rec: PetRecord

var _left: PanelContainer
var _stage: AnimalStage
var _who: Label
var _fits: Label
var _right: PanelContainer
var _slot: GearCell
var _slot_name: Label
var _slot_note: Label
var _unequip: Button
var _bag_title: Label
var _bag_scroll: ScrollContainer
var _bag: GridContainer
var _empty: Label
var _msg: Label

func _init() -> void:
	super("Gear")

func _build() -> void:
	name = "PetGearSheet"
	close_pressed.connect(_close_all)
	back_pressed.connect(close)
	_left = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_left.name = "Tame"
	body.add_child(_left)
	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 6)
	_left.add_child(lv)
	_stage = AnimalStage.new()
	lv.add_child(_stage)
	_who = SheetChrome.label("", 24, UiTokens.TEXT, true)
	_who.name = "Who"
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_who)
	_fits = SheetChrome.label("", 16, UiTokens.MUTED)
	_fits.name = "Fits"
	_fits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_fits)
	_right = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_right.name = "Slots"
	body.add_child(_right)
	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 12)
	_right.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_slot = GearCell.new()
	_slot.name = "SaddleSlot"
	_slot.sheet = self
	_slot.is_slot = true
	_slot.pressed.connect(_unequip_now)
	row.add_child(_slot)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	_slot_name = SheetChrome.label("", 20, UiTokens.TEXT, true)
	_slot_name.name = "SlotName"
	info.add_child(_slot_name)
	_slot_note = SheetChrome.label("", 15, UiTokens.MUTED)
	_slot_note.name = "SlotNote"
	_slot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_slot_note)
	_unequip = SheetChrome.action_button("Unequip", &"ghost", false)
	_unequip.name = "Unequip"
	_unequip.pressed.connect(_unequip_now)
	row.add_child(_unequip)
	_msg = SheetChrome.label("", 15, UiTokens.LIFE)
	_msg.name = "Message"
	col.add_child(_msg)
	_bag_title = SheetChrome.label("Saddles in your bag", 17, UiTokens.GOLD, true)
	col.add_child(_bag_title)
	_bag_scroll = BagDrop.new()
	_bag_scroll.name = "BagSaddles"
	(_bag_scroll as BagDrop).sheet = self
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_bag_scroll)
	_bag = GridContainer.new()
	_bag.columns = 2
	_bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag.add_theme_constant_override("h_separation", 8)
	_bag.add_theme_constant_override("v_separation", 8)
	_bag_scroll.add_child(_bag)
	_empty = SheetChrome.label("No saddle in your bag. Sew one at a workbench (Tailoring).", 15, UiTokens.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_empty)

func open(p: Player, r: PetRecord) -> void:
	player = p
	rec = r
	visible = true
	_msg.text = ""
	if not p.inventory.changed.is_connected(refresh):
		p.inventory.changed.connect(refresh)
	if not r.gear.changed.is_connected(refresh):
		r.gear.changed.connect(refresh)
	refresh()

func close() -> void:
	visible = false
	if rec and rec.gear.changed.is_connected(refresh):
		rec.gear.changed.disconnect(refresh)

func _close_all() -> void:
	close()
	var hud := get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	var animals: Variant = hud.get("_animal_screen") if hud else null
	if animals is AnimalScreen and is_instance_valid(animals):
		(animals as AnimalScreen).close_screen()

func is_open() -> bool:
	return visible

func refresh() -> void:
	if not visible or rec == null or player == null:
		return
	var def := Data.creature(rec.species)
	_who.text = rec.name if rec.name != "" else str(rec.species).capitalize()
	var size := PetRecord.saddle_size(def)
	_fits.text = ("Takes a %s saddle" % size) if &"mount" in rec.tamed_role else "Cannot be ridden"
	_stage.show_pet(rec)
	var s := rec.saddle()
	_slot.stack = s
	_slot.bag_index = -1
	_slot.queue_redraw()
	_slot_name.text = _name_of(s) if s else "No saddle"
	_slot_note.text = ("Lv. %d · rides" % s.level) if s else "Riding needs a fitting saddle."
	_unequip.visible = s != null
	for c in _bag.get_children():
		c.queue_free()
	var idx := PetGear.bag_saddles(player.inventory, rec)
	for i in idx:
		var st := player.inventory.slots[i]
		var cell := GearCell.new()
		cell.name = "Cell%d" % i
		cell.sheet = self
		cell.stack = st
		cell.bag_index = i
		cell.wrong = rec.saddle_fit(st) != ""
		cell.text = _name_of(st) + ("\nwrong size" if cell.wrong else "")
		cell.pressed.connect(equip_index.bind(i))
		_bag.add_child(cell)
	_empty.visible = idx.is_empty()
	set_counter("Saddle [color=#%s]%d[/color] / 1" % [UiTokens.GOLD.to_html(false), 1 if s else 0])
	relayout()

func _name_of(s: ItemStack) -> String:
	return s.def().display_name if s and s.def() and s.def().display_name != "" else str(s.def_id if s else "")

## Tap or drop a bag saddle: put it on.
func equip_index(i: int) -> void:
	_msg.text = PetGear.equip(player, rec, i)
	refresh()

func _unequip_now() -> void:
	if rec.saddle() == null:
		return
	_msg.text = PetGear.unequip(player, rec)
	refresh()

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var gap := 8.0 if compact else 20.0
	var lw := floorf((rect.size.x - gap) * 0.42)
	_left.position = rect.position
	_left.size = Vector2(lw, rect.size.y)
	_right.position = Vector2(rect.position.x + lw + gap, rect.position.y)
	_right.size = Vector2(rect.size.x - lw - gap, rect.size.y)
	# The stage keeps a landscape frame (AnimalStage frames for one): a tall panel cut the tail off.
	_stage.custom_minimum_size = Vector2(0, minf(rect.size.y - (44.0 if compact else 80.0), lw * 0.7))
	var cell := CELL_PHONE if compact else CELL_DESK
	_slot.custom_minimum_size = Vector2(cell, cell)
	_unequip.custom_minimum_size = Vector2(cell * 1.4, SheetChrome.TAP)
	_who.add_theme_font_size_override("font_size", 16 if compact else 24)
	_fits.add_theme_font_size_override("font_size", 12 if compact else 16)
	_slot_name.add_theme_font_size_override("font_size", 15 if compact else 20)
	_slot_note.add_theme_font_size_override("font_size", 12 if compact else 15)
	_msg.add_theme_font_size_override("font_size", 12 if compact else 15)
	_bag_title.add_theme_font_size_override("font_size", 13 if compact else 17)
	_empty.add_theme_font_size_override("font_size", 12 if compact else 15)
	for c in _bag.get_children():
		(c as Control).custom_minimum_size = Vector2(0, cell)
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(c as Button).add_theme_font_size_override("font_size", 13 if compact else 16)

## A saddle cell: the item's icon in its natural colour (spec 35) on a dark tile; GOLD edge on the slot,
## dim red edge on a saddle of the wrong size. Drag from a bag cell to the slot to equip.
class GearCell extends Button:
	var sheet: PetGearSheet
	var stack: ItemStack
	var bag_index := -1
	var is_slot := false
	var wrong := false

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		autowrap_mode = TextServer.AUTOWRAP_OFF
		custom_minimum_size = Vector2(SheetChrome.TAP, SheetChrome.TAP)
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		add_theme_color_override("font_color", UiTokens.TEXT)
		add_theme_color_override("font_hover_color", UiTokens.GOLD)

	func _ready() -> void:
		# The label sits right of the icon square.
		add_theme_constant_override("h_separation", 0)
		resized.connect(func () -> void: _pad())
		_pad()

	func _pad() -> void:
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = size.y + 8.0 if not is_slot else 0.0
		add_theme_stylebox_override("normal", sb)
		add_theme_stylebox_override("hover", sb)
		add_theme_stylebox_override("pressed", sb)
		add_theme_stylebox_override("focus", sb)

	func _draw() -> void:
		var sq := Rect2(Vector2.ZERO, Vector2(size.y, size.y)) if not is_slot else Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		draw_rect(sq, Color(0.16, 0.17, 0.18))
		var edge := UiTokens.GOLD if is_slot else (Color(UiTokens.LIFE, 0.7) if wrong else Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), edge, false, 2.0)
		if stack:
			var tex := ItemIcons.texture(stack.def_id)
			if tex:
				draw_texture_rect(tex, sq.grow(-sq.size.y * 0.12), false, stack.tint_color())
		elif is_slot:
			var ghost := UiIcons.icon(&"ride")
			if ghost:
				draw_texture_rect(ghost, sq.grow(-sq.size.y * 0.25), false, Color(1, 1, 1, 0.18))
		if has_focus() or is_hovered():
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.05))

	func _get_drag_data(_at: Vector2) -> Variant:
		if stack == null:
			return null
		var prev := TextureRect.new()
		prev.texture = ItemIcons.texture(stack.def_id)
		prev.modulate = stack.tint_color()
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.size = Vector2(64, 64)
		set_drag_preview(prev)
		return {"saddle_from": "slot" if is_slot else "bag", "index": bag_index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return is_slot and data is Dictionary and str(data.get("saddle_from", "")) == "bag"

	func _drop_data(_at: Vector2, data: Variant) -> void:
		sheet.equip_index(int(data["index"]))

## The bag list accepts the slot's saddle: drop there to unequip.
class BagDrop extends ScrollContainer:
	var sheet: PetGearSheet

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and str(data.get("saddle_from", "")) == "slot"

	func _drop_data(_at: Vector2, _data: Variant) -> void:
		sheet._unequip_now()
