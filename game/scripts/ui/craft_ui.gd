class_name CraftUI
extends Control
## Touch-first recipe list. Primary slot is badged; output preview shows inherited attributes.

var player: Player
var _filter_can: bool = true
var _rec: Dictionary = {}
var _picks: Array[int] = []
var _pick_slot: int = -1
var _list: VBoxContainer
var _slots_box: VBoxContainer
var _preview: Label
var _picker: VBoxContainer
var _craft_btn: Button
var _status: Label
var _scroll: ScrollContainer
var _root: VBoxContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 12
	_root.offset_top = 12
	_root.offset_right = -12
	_root.offset_bottom = -12
	add_child(_root)
	var filters := HBoxContainer.new()
	_root.add_child(filters)
	filters.add_child(_mk_btn("Can craft", Callable(self, "_on_filter_can"), Vector2(160, 64)))
	filters.add_child(_mk_btn("All", Callable(self, "_on_filter_all"), Vector2(120, 64)))
	filters.add_child(_mk_btn("Close", Callable(self, "hide_ui"), Vector2(120, 64)))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_status)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(280, 400)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail)
	_slots_box = VBoxContainer.new()
	detail.add_child(_slots_box)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(0, 80)
	detail.add_child(_preview)
	_craft_btn = _mk_btn("Craft", Callable(self, "_on_craft"), Vector2(200, 72))
	detail.add_child(_craft_btn)
	var place_row := HBoxContainer.new()
	detail.add_child(place_row)
	place_row.add_child(_mk_btn("Place pen", Callable(self, "_place_kind").bind(&"makeshift_taming_pen"), Vector2(150, 64)))
	place_row.add_child(_mk_btn("Workbench", Callable(self, "_place_kind").bind(&"workbench"), Vector2(150, 64)))
	place_row.add_child(_mk_btn("Dry rack", Callable(self, "_place_kind").bind(&"drying_rack"), Vector2(150, 64)))
	place_row.add_child(_mk_btn("Bonfire", Callable(self, "_place_kind").bind(&"bonfire"), Vector2(150, 64)))
	place_row.add_child(_mk_btn("Tent", Callable(self, "_place_kind").bind(&"tent"), Vector2(120, 64)))
	place_row.add_child(_mk_btn("Basket", Callable(self, "_place_kind").bind(&"basket"), Vector2(140, 64)))
	_picker = VBoxContainer.new()
	_picker.visible = false
	detail.add_child(_picker)
	resized.connect(_layout_safe)
	_layout_safe()

func bind(p: Player) -> void:
	player = p
	if not player.inventory.changed.is_connected(rebuild):
		player.inventory.changed.connect(rebuild)

func toggle() -> void:
	if visible:
		hide_ui()
	else:
		show_ui()

func show_ui() -> void:
	visible = true
	_layout_safe()
	rebuild()

func hide_ui() -> void:
	visible = false
	_picker.visible = false

func rebuild() -> void:
	if player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	for rec in Crafting.all_recipes():
		if not rec is Dictionary:
			continue
		var picks := Crafting.default_picks(player.inventory, rec)
		var can := Crafting.picks_valid(player.inventory, rec, picks)
		var station_ok := Crafting.station_nearby(player, rec)
		if _filter_can and (not can or not station_ok):
			continue
		var label := str(rec.get("display_name", rec.get("id", "?")))
		if not station_ok:
			label += "  (need %s)" % Crafting.station_id(rec)
		elif not can:
			label += "  (missing)"
		var b := _mk_btn(label, Callable(self, "_select").bind(rec), Vector2(260, 64))
		b.modulate = Color.WHITE if can and station_ok else Color(0.7, 0.7, 0.7)
		_list.add_child(b)
	_refresh_detail()

func _select(rec: Dictionary) -> void:
	_rec = rec
	_picks = Crafting.default_picks(player.inventory, rec)
	_pick_slot = -1
	_picker.visible = false
	_refresh_detail()

func _refresh_detail() -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	if _rec.is_empty():
		_preview.text = "Pick a recipe."
		_craft_btn.disabled = true
		return
	var slots: Array = _rec.get("slots", [])
	var pidx := Crafting.primary_index(_rec)
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var cat := str(slot.get("category", ""))
		var count := int(slot.get("count", 1))
		var text := "%s ×%d" % [cat, count]
		if i == pidx:
			text = "PRIMARY  " + text
		var chosen := "—"
		if i < _picks.size() and _picks[i] >= 0:
			var s := player.inventory.slots[_picks[i]]
			if s:
				chosen = "%s lv%d ×%d  contrib %s" % [s.def_id, s.level, count, _contrib_list(s.level, count)]
		var b := _mk_btn("%s\n%s" % [text, chosen], Callable(self, "_open_picker").bind(i), Vector2(360, 72))
		if i == pidx:
			b.modulate = Color(1.0, 0.92, 0.55)
		_slots_box.add_child(b)
	var prev := Crafting.preview(player.inventory, _rec, _picks)
	if prev:
		var levels := Crafting.consumed_levels(player.inventory, _rec, _picks)
		_preview.text = "Output: %s  lv %d  (mean %s)  process %d\n%s" % [
			prev.def_id, prev.level, str(levels), prev.process_count, prev.attributes]
	else:
		_preview.text = "Need materials (and station if listed)."
	_craft_btn.disabled = not Crafting.can_make(player, _rec, _picks)
	_status.text = "Filter: %s   butcher skill %d" % [
		"can craft" if _filter_can else "all", Data.butchering_level()]

func _open_picker(slot_i: int) -> void:
	_pick_slot = slot_i
	for c in _picker.get_children():
		c.queue_free()
	if _rec.is_empty():
		return
	var slots: Array = _rec.get("slots", [])
	if slot_i < 0 or slot_i >= slots.size():
		return
	var title := Label.new()
	title.text = "Choose %s" % slots[slot_i].get("category", "")
	_picker.add_child(title)
	var need := int(slots[slot_i].get("count", 1))
	for idx in Crafting.stacks_for_slot(player.inventory, slots[slot_i]):
		var s := player.inventory.slots[idx]
		var lab := "%s x%d lv%d proc%d  %s  contrib %s" % [
			s.def_id, s.count, s.level, s.process_count, s.attributes, _contrib_list(s.level, need)]
		_picker.add_child(_mk_btn(lab, Callable(self, "_pick_stack").bind(idx), Vector2(400, 64)))
	_picker.visible = true

func _pick_stack(idx: int) -> void:
	if _pick_slot < 0:
		return
	if _picks.size() <= _pick_slot:
		_picks.resize(_pick_slot + 1)
	_picks[_pick_slot] = idx
	_picker.visible = false
	_refresh_detail()

func _contrib_list(level: int, count: int) -> String:
	var parts: PackedStringArray = []
	for _i in count:
		parts.append(str(level))
	return "[" + ", ".join(parts) + "]"

func _on_craft() -> void:
	if Crafting.craft(player, _rec, _picks) == null:
		_status.text = "Cannot craft."
		return
	_picks = Crafting.default_picks(player.inventory, _rec)
	rebuild()

func _place_kind(kind: StringName) -> void:
	hide_ui()
	player.placer.begin(kind)
	TouchControls.set_context(&"place")

func _on_filter_can() -> void:
	_filter_can = true
	rebuild()

func _on_filter_all() -> void:
	_filter_can = false
	rebuild()

func _layout_safe() -> void:
	if _root == null:
		return
	var pad_l := 12.0
	var pad_t := 12.0
	var pad_r := 12.0
	var pad_b := 12.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport_rect().size
		var win := Vector2(DisplayServer.window_get_size())
		if win.x > 0.0 and win.y > 0.0:
			pad_l = maxf(12.0, safe.position.x * view.x / win.x)
			pad_t = maxf(12.0, safe.position.y * view.y / win.y)
			pad_r = maxf(12.0, (win.x - (safe.position.x + safe.size.x)) * view.x / win.x)
			pad_b = maxf(12.0, (win.y - (safe.position.y + safe.size.y)) * view.y / win.y)
	_root.offset_left = pad_l
	_root.offset_top = pad_t
	_root.offset_right = -pad_r
	_root.offset_bottom = -pad_b

func _mk_btn(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b
