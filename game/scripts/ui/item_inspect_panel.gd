class_name ItemInspectPanel
extends PanelContainer
## The item card (spec 13 s10-11; rewritten from INVUI's item_inspect_panel.gd onto canon's bag):
## a tan title band with the name, the art with its level and kind, compact rows (durability,
## processing left, locked), the instance's traits in their classes - gold positive, grey negative,
## green rare (InvAttributes) - and, at the bottom, the host's actions for this item. Which actions
## exist is the host's call (InventoryUI.valid_actions): the card only lays them out, two or three to
## a row, each a 64 px tap target. Presentation only: it never touches an Inventory.

const BG := Color("#33342A")
const BAND := Color("#CAAD69")
const BAND_TEXT := Color("#1B1A14")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const DIVIDER := Color(0.34, 0.33, 0.29, 0.9)

## What the card shows, for tests and labs: [{text, cls}] where cls is "", "positive", "negative",
## "rare" or "warn"; the title line is shown_title.
var shown_rows: Array[Dictionary] = []
var shown_title := ""
var shown_uid := ""
## The action buttons go here (the host adds them once and toggles visibility).
var actions: GridContainer

var _title: Label
var _art: TextureRect
var _level: Label
var _kind: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer
## Material appearance hook (spec 35, a separate worker): a row for the instance's `look` swatch.
## It stays hidden and empty here; show_look() is the one place that fills it.
var look_row: HBoxContainer
var _font_px := 14

func _init() -> void:
	name = "ItemCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = Color(0.06, 0.07, 0.06, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var band := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = BAND
	bsb.content_margin_left = 8
	bsb.content_margin_right = 8
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 2
	band.add_theme_stylebox_override("panel", bsb)
	box.add_child(band)
	_title = Label.new()
	_title.name = "CardTitle"
	_title.add_theme_color_override("font_color", BAND_TEXT)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	band.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	var facts := VBoxContainer.new()
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.add_theme_constant_override("separation", 2)
	_scroll.add_child(facts)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	facts.add_child(head)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.custom_minimum_size = Vector2(48, 48)
	head.add_child(_art)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_level = Label.new()
	_level.add_theme_color_override("font_color", TEXT)
	hv.add_child(_level)
	_kind = Label.new()
	_kind.add_theme_color_override("font_color", TEXT_2)
	_kind.clip_text = true
	_kind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hv.add_child(_kind)
	look_row = HBoxContainer.new()
	look_row.name = "LookRow"
	look_row.visible = false
	facts.add_child(look_row)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	facts.add_child(_rows)
	actions = GridContainer.new()
	actions.name = "CardActions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	box.add_child(actions)

## Type sizes per view: 12 px is the floor (UiTokens.TYPE_MIN).
func set_scale_for(view: Vector2) -> void:
	var compact := UiTokens.is_compact(view)
	_font_px = 13 if compact else 16
	_title.add_theme_font_size_override("font_size", 15 if compact else 20)
	_level.add_theme_font_size_override("font_size", _font_px)
	_kind.add_theme_font_size_override("font_size", maxi(12, _font_px - 1))
	_art.custom_minimum_size = Vector2(40, 40) if compact else Vector2(64, 64)
	for l in _rows.get_children():
		(l as Label).add_theme_font_size_override("font_size", _font_px)

## Fill the card for one instance. `where` is "" for the bag, else the container's title.
func show_stack(stack: ItemStack, where: String = "") -> void:
	if stack == null:
		hide_card()
		return
	var d := stack.def()
	shown_title = d.display_name if d and d.display_name != "" else str(stack.def_id).capitalize()
	shown_uid = stack.uid
	_title.text = shown_title
	_art.texture = ItemIcons.texture(stack.def_id)
	_level.text = "%s%s" % [LevelDisplay.label(stack.level), "  x%d" % stack.count if stack.count > 1 else ""]
	_kind.text = kind_text(stack) + ("  ·  in %s" % where if where != "" else "")
	shown_rows = rows_for(stack)
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for r in shown_rows:
		var l := Label.new()
		l.text = str(r.text)
		l.clip_text = true # one line per fact: the card's height never depends on a wrap pass
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_font_size_override("font_size", _font_px)
		l.add_theme_color_override("font_color", color_of(str(r.cls)))
		l.add_theme_constant_override("line_spacing", 0)
		_rows.add_child(l)
	show_look(stack)
	visible = true

## Sizes the card to its content but never past `max_h`: the facts scroll, the title band and the
## actions always stay inside. The host sets custom_minimum_size.x (the width) first.
func fit(max_h: float) -> void:
	_scroll.custom_minimum_size.y = 0.0
	var facts_h := (_scroll.get_child(0) as Control).get_combined_minimum_size().y
	var rest := get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(facts_h, 0.0, maxf(0.0, max_h - rest))
	size = Vector2(custom_minimum_size.x, minf(get_combined_minimum_size().y, max_h))

## Spec 35 hook for the material-appearance worker: fill look_row from stack.attributes.look (the
## species colour swatch) and show it. Deliberately empty here: the row stays hidden until then.
func show_look(_stack: ItemStack) -> void:
	look_row.visible = false

func hide_card() -> void:
	visible = false
	shown_uid = ""
	shown_title = ""
	shown_rows.clear()

## The card's facts as rows, from the instance's data only.
static func rows_for(stack: ItemStack) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if stack.max_durability > 0:
		out.append({"text": "Durability %d / %d%s" % [stack.durability, stack.max_durability, "  (broken)" if stack.is_broken() else ""],
			"cls": "warn" if stack.is_broken() else ""})
	var done: Variant = stack.attributes.get("processed", null)
	if done is Array or Food.is_food(stack):
		var total := int((ProcessStation.rules().get("in_place", {}) as Dictionary).get("opportunities", 2))
		out.append({"text": "Processing left %d" % maxi(0, total - ((done as Array).size() if done is Array else 0)), "cls": ""})
	var dmg := stack.scaled_damage()
	if dmg > 0.0:
		out.append({"text": "Damage %.0f" % dmg, "cls": ""})
	var armor := stack.scaled_armor()
	if armor > 0.0:
		out.append({"text": "Armour %.0f" % armor, "cls": ""})
	if BagCapacity.is_bag(stack.def_id):
		out.append({"text": "Storage +%d slots" % int(BagCapacity.of_stack(stack).get("total", 0)), "cls": ""})
	if Food.is_food(stack):
		out.append({"text": "Energy %.0f" % Food.energy_restore(stack), "cls": ""})
		if Food.is_raw(stack):
			out.append({"text": "Raw", "cls": "warn"})
		if Food.is_poisoned(stack):
			out.append({"text": "Poisoned", "cls": "warn"})
	var sec := InvAttributes.sections(stack)
	for cls: String in InvAttributes.CLASSES:
		for row: Dictionary in sec[cls]:
			out.append({"text": InvAttributes.line(row), "cls": cls})
	if stack.is_locked():
		out.append({"text": "Locked", "cls": ""})
	if stack.is_unstable():
		out.append({"text": "Unstable", "cls": "warn"})
	return out

## The first category as a word ("Bone", "Food"), the kind line under the level.
static func kind_text(stack: ItemStack) -> String:
	var d := stack.def()
	if d == null or d.categories.is_empty():
		return "Item"
	return str(d.categories[0]).capitalize()

static func color_of(cls: String) -> Color:
	if InvAttributes.COLORS.has(cls):
		return InvAttributes.COLORS[cls]
	return UiTokens.DANGER if cls == "warn" else TEXT
