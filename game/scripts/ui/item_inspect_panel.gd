class_name ItemInspectPanel
extends PanelContainer
## The item card (spec 13 s10-11; rewritten from INVUI's item_inspect_panel.gd onto canon's bag):
## a tan title band with the name, the art with its level and kind, compact rows (durability,
## processing left, locked), the instance's traits in their classes - gold positive, grey negative,
## green rare (InvAttributes) - and, at the bottom, the host's actions for this item. Which actions
## exist is the host's call (InventoryUI.valid_actions): the card only lays them out, two or three to
## a row, each a 64 px tap target. Presentation only: it never touches an Inventory.
## BAGUI (owner 2026-10-28, Durango reference): under the art, a quality line (rarity + dots), the
## item's tag chips, then sections - Traits (gold/grey), Perks (green, with their tier I-V), Info
## (flat-top hex colour swatches), Maintenance, Craft into (recipes that take this item) - and the
## host's big Use button (use_row) under the smaller actions.

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
## The host's big Use button goes here.
var use_row: VBoxContainer
## What the BAGUI sections show, for tests and labs.
var shown_tags: Array[String] = []
var shown_craft_into: Array[String] = []
var shown_swatches: Array[Color] = []

var _title: Label
var _art: TextureRect
var _level: Label
var _kind: Label
var _rows: VBoxContainer
var _quality: Label
var _tags: HFlowContainer
var _sections: VBoxContainer
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
	_quality = Label.new()
	_quality.name = "Quality"
	hv.add_child(_quality)
	_tags = HFlowContainer.new()
	_tags.name = "Tags"
	_tags.add_theme_constant_override("h_separation", 4)
	_tags.add_theme_constant_override("v_separation", 4)
	facts.add_child(_tags)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 1)
	facts.add_child(_rows)
	_sections = VBoxContainer.new()
	_sections.name = "Sections"
	_sections.add_theme_constant_override("separation", 1)
	facts.add_child(_sections)
	look_row = HBoxContainer.new()
	look_row.name = "LookRow"
	look_row.visible = false
	look_row.add_theme_constant_override("separation", 6)
	actions = GridContainer.new()
	actions.name = "CardActions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	box.add_child(actions)
	use_row = VBoxContainer.new()
	use_row.name = "UseRow"
	box.add_child(use_row)

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
	var rq := ItemArt.rarity(stack.def_id)
	var dots := ItemArt.rarity_order().find(rq) + 1
	_quality.text = "%s  %s%s" % [str(rq).capitalize(), "•".repeat(maxi(1, dots)), "   Flawless" if &"flawless" in stack.flags else ""]
	_quality.add_theme_color_override("font_color", ItemArt.color_for_rarity(rq))
	_quality.add_theme_font_size_override("font_size", maxi(12, _font_px - 1))
	for c in _rows.get_children() + _sections.get_children() + _tags.get_children():
		c.get_parent().remove_child(c)
		if c != look_row: # kept and re-added under Info
			c.queue_free()
	shown_tags = tags_for(stack)
	for t in shown_tags:
		_tags.add_child(SheetChrome.chip(t, &"neutral", maxi(12, _font_px - 2)))
	# Plain facts first, then the reference's sections.
	var traits: Array[Dictionary] = []
	var perks: Array[Dictionary] = []
	for r in shown_rows:
		match str(r.cls):
			"positive", "negative":
				traits.append(r)
			"rare":
				perks.append(r)
			_:
				_rows.add_child(_row_label(str(r.text), str(r.cls)))
	if not traits.is_empty():
		_section("Traits")
		for r in traits:
			_sections.add_child(_row_label(str(r.text), str(r.cls)))
	if not perks.is_empty():
		_section("Perks")
		for r in perks:
			_sections.add_child(_row_label(str(r.text), "rare"))
	_section("Info")
	show_look(stack)
	_section("Maintenance")
	for line in GearRepair.lines(stack):  # one fact per row (P3 GEARREPAIR)
		_sections.add_child(_row_label(line, ""))
	shown_craft_into = craft_into(stack)
	if not shown_craft_into.is_empty():
		_section("Craft into")
		for n in shown_craft_into:
			_sections.add_child(_row_label("›  " + n, ""))
	visible = true

func _row_label(t: String, cls: String) -> Label:
	var l := Label.new()
	l.text = t
	l.clip_text = true # one line per fact: the card's height never depends on a wrap pass
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", _font_px)
	l.add_theme_color_override("font_color", color_of(cls))
	l.add_theme_constant_override("line_spacing", 0)
	return l

## A small GOLD section heading with a hairline above it.
func _section(t: String) -> void:
	var l := Label.new()
	l.text = t.to_upper()
	l.add_theme_font_size_override("font_size", maxi(12, _font_px - 3))
	l.add_theme_color_override("font_color", BAND)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = DIVIDER
	sb.border_width_top = 1
	sb.content_margin_top = 6
	l.add_theme_stylebox_override("normal", sb)
	_sections.add_child(l)

## Sizes the card to its content but never past `max_h`: the facts scroll, the title band and the
## actions always stay inside. The host sets custom_minimum_size.x (the width) first.
func fit(max_h: float) -> void:
	_scroll.custom_minimum_size.y = 0.0
	var facts_h := (_scroll.get_child(0) as Control).get_combined_minimum_size().y
	var rest := get_combined_minimum_size().y
	_scroll.custom_minimum_size.y = clampf(facts_h, 0.0, maxf(0.0, max_h - rest))
	size = Vector2(custom_minimum_size.x, minf(get_combined_minimum_size().y, max_h))

## Spec 35's look row, filled (BAGUI "Info"): flat-top hex swatches of the instance's natural colour
## and its light and dark tones, with the hex code.
func show_look(stack: ItemStack) -> void:
	shown_swatches = swatches(stack)
	for c in look_row.get_children():
		look_row.remove_child(c)
		c.queue_free()
	for col in shown_swatches:
		var h := HexSwatch.new()
		h.color = col
		h.custom_minimum_size = Vector2(28, 26) if _font_px < 16 else Vector2(36, 32)
		look_row.add_child(h)
	var code := Label.new()
	code.text = "#" + shown_swatches[0].to_html(false).to_upper() if not shown_swatches.is_empty() else "No colour"
	code.add_theme_font_size_override("font_size", maxi(12, _font_px - 1))
	code.add_theme_color_override("font_color", TEXT_2)
	code.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look_row.add_child(code)
	look_row.visible = true
	_sections.add_child(look_row)

func hide_card() -> void:
	if look_row.get_parent():
		look_row.get_parent().remove_child(look_row) # it is re-added under Info by the next show
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
	if stack.def() and stack.def().is_work_tool and Inventory.slot_for(stack.def()) != &"weapon":
		out.append({"text": "Work tool: butchers and harvests, never used in combat", "cls": ""}) # KNIFESPLIT
	elif dmg > 0.0:
		out.append({"text": "Damage %.0f" % dmg, "cls": ""})
	var armor := stack.scaled_armor()
	if armor > 0.0:
		out.append({"text": "Armour %.0f" % armor, "cls": ""})
	for line in trait_effect_lines(stack):
		out.append({"text": line, "cls": ""})
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

## TRAITGEAR: "+9 % durability (High Density 3)", one line per stat its traits move.
static func trait_effect_lines(stack: ItemStack) -> Array[String]:
	var out: Array[String] = []
	var eff := stack.trait_effects()
	for stat: String in ["durability", "damage", "armor", "gather_power"]:
		if not eff.has(stat):
			continue
		var e: Dictionary = eff[stat]
		var names: PackedStringArray = []
		for f: Array in e["from"]:
			var row: Variant = (InvAttributes.data().get("attribute_classes", {}) as Dictionary).get(str(f[0]))
			names.append("%s %d" % [str((row as Dictionary).get("label", str(f[0]).capitalize())) if row is Dictionary else str(f[0]).capitalize(), int(f[1])])
		var pct := roundi(float(e["pct"]) * 100.0)
		out.append("%s%d %% %s (%s%s)" % ["+" if pct >= 0 else "", pct, stat.replace("_", " ").replace("armor", "armour"), ", ".join(names), ", capped" if bool(e["capped"]) else ""])
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

## The item's classification tags as chips ("Tendon", "Strap", "Meat", "Edible"; ItemTags), without
## bookkeeping tier_* rows.
static func tags_for(stack: ItemStack) -> Array[String]:
	var out: Array[String] = []
	for t in ItemTags.tags(stack.def_id):
		var l := ItemTags.label(t)
		if l != "":
			out.append(l)
	return out

## P3 GEARREPAIR: where, for what and to which max (GearRepair.text); "Repair: Not Possible" for items
## without durability. Durability itself is a fact row above.
static func repair_text(stack: ItemStack) -> String:
	return GearRepair.text(stack)

## Display names of the recipes this item can fill a slot of (by category, allowed id or preferred
## id), sorted, at most CRAFT_INTO_MAX.
const CRAFT_INTO_MAX := 8
static func craft_into(stack: ItemStack) -> Array[String]:
	var out: Array[String] = []
	var d := stack.def()
	if d == null:
		return out
	var seen := {}
	for rec: Variant in Crafting.all_recipes():
		if not rec is Dictionary:
			continue
		for slot: Variant in (rec as Dictionary).get("slots", []):
			if not slot is Dictionary:
				continue
			var sd := slot as Dictionary
			var ids: Variant = sd.get("allowed_ids", [])
			var fits := d.has_category(StringName(str(sd.get("category", "")))) or str(sd.get("prefer_id", "")) == str(stack.def_id) \
				or (ids is Array and str(stack.def_id) in (ids as Array))
			if fits:
				var n := str((rec as Dictionary).get("display_name", (rec as Dictionary).get("id", "")))
				if not seen.has(n):
					seen[n] = true
					out.append(n)
				break
	out.sort()
	return out.slice(0, CRAFT_INTO_MAX)

## The instance's natural colour (its tint) and a light and a dark tone of it; [] without a tint.
# ASSUMPTION: the reference shows three swatches; items carry one colour, so the other two are its tones.
static func swatches(stack: ItemStack) -> Array[Color]:
	var out: Array[Color] = []
	if not str(stack.attributes.get("tint", "")).begins_with("#"):
		return out
	var c := stack.tint_color()
	out.append(c)
	out.append(c.lightened(0.3))
	out.append(c.darkened(0.35))
	return out

## A flat-top hexagon filled with one colour (the Info swatch).
class HexSwatch extends Control:
	var color := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x * 0.5, size.y / sqrt(3.0))
		var pts := PackedVector2Array()
		for i in 6:
			var a := deg_to_rad(60.0 * i)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, color)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.6), 1.5, true)
