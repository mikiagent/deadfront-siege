class_name BuildUI
extends Control
## The Craft/Build construction menu (owner's spec 30 §2, phases 2-3) and the construction-site
## sheet (§7). One screen: the blueprint list grouped by the spec's categories on the left, the
## selected blueprint's details on the right. The details say every unmet prerequisite exactly
## (Construction level, the learned skill node, land/overlap) and whether it can be placed here
## now, so the panel and the actual placement never disagree (both ask BuildFlow).
## A placed site opens the sheet: its slots with the deposited instances, and Deposit / Withdraw /
## Work / Cancel. Completion is BuildFlow.complete (atomic, pays XP once).
## Desktop: list | detail side by side. Phone (compact canvas): one pane at a time, the detail as a
## sheet over the list, every button at the 64 px tap floor.

const FOOTER_H := 64.0
const SITE_GROUP := "construction_site"

var player: Player
var site: ConstructionSite
var _root: VBoxContainer
var _body: GridContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _hint: Label
var _footer: HBoxContainer
var _selected: String = ""
var _phone_detail := false
var _site_mode := false
var _slot_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 41  # above the craft menu, whose Build tab opens this
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_root.add_child(header)
	_title = Label.new()
	_title.text = "Build"
	_title.add_theme_font_size_override("font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_hint = Label.new()
	_hint.name = "BuildHint"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_stretch_ratio = 2.0
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	header.add_child(_hint)
	header.add_child(_mk_btn("Close", hide_ui, Vector2(120, 56)))
	_body = GridContainer.new()
	_body.columns = 2
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 12)
	_body.add_theme_constant_override("v_separation", 12)
	_root.add_child(_body)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(260, 220)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(280, 220)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_footer = HBoxContainer.new()
	_footer.name = "BuildFooter"
	_footer.add_theme_constant_override("separation", UiTokens.SPACE)
	_footer.custom_minimum_size = Vector2(0, FOOTER_H)
	_footer.visible = false
	_root.add_child(_footer)
	if get_viewport():
		get_viewport().size_changed.connect(_fit)
	resized.connect(_apply_phone_pane)
	_apply_phone_pane()

## One BuildUI per survivor, created on first use (main.gd is outside this task's files). It goes
## on the HUD's canvas layer, above the craft menu, and is bound to `p`.
static func ensure(p: Player) -> BuildUI:
	if p == null:
		return null
	if p.build_ui != null and is_instance_valid(p.build_ui):
		return p.build_ui as BuildUI
	var ui: BuildUI = (load("res://scenes/ui/build.tscn") as PackedScene).instantiate() as BuildUI
	ui.name = "BuildUI"
	var hud := p.get_tree().get_first_node_in_group("hud") if p.is_inside_tree() else null
	var layer: Node = hud.get_parent() if hud else null
	if layer == null:
		layer = p.get_tree().current_scene
	if layer:
		layer.add_child(ui)
	ui.bind(p)
	p.build_ui = ui
	return ui

## A runtime-created screen gets its size one frame late; fill the canvas explicitly.
func _fit() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	elif get_viewport():
		size = get_viewport().get_visible_rect().size
	_apply_phone_pane()

func bind(p: Player) -> void:
	player = p
	if player and player.inventory and not player.inventory.changed.is_connected(_on_inventory_changed):
		player.inventory.changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		rebuild()

# ---------------------------------------------------------------- opening

func toggle() -> void:
	if visible:
		hide_ui()
	else:
		open()

func open() -> void:
	site = null
	_site_mode = false
	visible = true
	_phone_detail = false
	_apply_phone_pane()
	rebuild()
	UiTokens.focus_first(_list.get_children())

func hide_ui() -> void:
	visible = false
	site = null
	_site_mode = false

## A tap on a placed site (ConstructionSite.interact lands here).
func show_site(s: ConstructionSite) -> void:
	site = s
	_site_mode = true
	_selected = str(s.blueprint_id)
	visible = true
	_phone_detail = false
	_apply_phone_pane()
	rebuild()

# ---------------------------------------------------------------- list

func rebuild() -> void:
	if player == null:
		return
	_refresh_list()
	_show_detail()

func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if _site_mode:
		_refresh_site_list()
		# One station's site: the blueprint list is not what the sheet is about.
		var l := Label.new()
		l.text = "Construction site"
		l.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
		l.add_theme_color_override("font_color", UiTokens.META)
		_list.add_child(l)
		var hint := Label.new()
		hint.text = "Deposit a part by tapping its slot, then work the site down to 0 s and press Finish."
		UiTokens.style_label(hint, get_viewport_rect().size, "body")
		hint.clip_text = false
		hint.custom_minimum_size = Vector2(240, 0)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(hint)
		return
	_title.text = "Build · Construction Parts / Workbench"
	_hint.text = "Gather logs and reeds, shape the parts by hand, then build here on your claim."
	var last_cat := ""
	for row in BuildFlow.menu_rows(player):
		var cat := str(row.get("category", ""))
		if cat != last_cat:
			last_cat = cat
			var head := Label.new()
			head.text = str(row.get("where", cat)).replace("_", " ").capitalize()
			head.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
			head.add_theme_color_override("font_color", UiTokens.META)
			_list.add_child(head)
		_list.add_child(_blueprint_row(row))
	if _list.get_child_count() == 0:
		var l := Label.new()
		l.text = "No blueprints yet."
		_list.add_child(l)

func _blueprint_row(row: Dictionary) -> Control:
	var id := str(row.get("id", ""))
	var blocked := str(row.get("blocked", ""))
	var chosen := id == _selected
	var view := get_viewport_rect().size
	var b := Button.new()
	b.name = "BP_" + id
	b.custom_minimum_size = Vector2(0, UiTokens.HEX if UiTokens.is_compact(view) else 60)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(chosen))
	b.pressed.connect(select.bind(id))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", UiTokens.SPACE)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var icon := TextureRect.new()
	icon.texture = ItemIcons.texture(&"workbench_kit")
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = Color.WHITE if blocked == "" else Color(0.6, 0.6, 0.6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(text)
	var name := Label.new()
	name.text = str(row.get("name", id))
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", UiTokens.body(view))
	name.add_theme_color_override("font_color", Color.WHITE if blocked == "" else Color(0.75, 0.75, 0.75))
	text.add_child(name)
	var meta := Label.new()
	meta.text = "Buildable" if blocked == "" else blocked
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", UiTokens.meta(view))
	meta.add_theme_color_override("font_color", UiTokens.META if blocked == "" else Color(1.0, 0.62, 0.5))
	text.add_child(meta)
	return b

func select(id: String) -> void:
	_selected = id
	if UiTokens.is_compact(get_viewport_rect().size):
		_phone_detail = true
		_apply_phone_pane()
	rebuild()

# ---------------------------------------------------------------- details

func _show_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_slot_buttons.clear()
	var view := get_viewport_rect().size
	if _site_mode:
		_show_site_detail(view)
		return
	var bp := Blueprints.of(StringName(_selected))
	if bp.is_empty():
		return
	var head := Label.new()
	head.text = str(bp.get("display_name", _selected))
	UiTokens.style_label(head, view, "heading")
	_detail.add_child(head)
	var unmet := Blueprints.unmet(player, bp)
	var placeable_here := _placeable_now()
	var status := Label.new()
	status.text = "Placeable here now" if placeable_here and unmet.is_empty() else "Cannot build yet"
	status.add_theme_font_size_override("font_size", UiTokens.body(view))
	status.add_theme_color_override("font_color", UiTokens.TEAL if placeable_here and unmet.is_empty() else Color(1.0, 0.62, 0.5))
	_detail.add_child(status)
	# The exact prerequisites, unmet ones first (spec 30 §3: the details never hide a gate).
	var prereq := Label.new()
	prereq.name = "BuildPrereq"
	var lines: Array[String] = []
	lines.append("Construction Lv. %d" % int(bp.get("construction_level", 1)))
	lines.append("Learned: %s" % str(bp.get("skill_node", "?")).replace("_", " ").capitalize())
	for u in unmet:
		lines.append("Missing: %s" % str(u))
	if unmet.is_empty():
		var here := BuildFlow.place_reason(player, StringName(_selected), _here_cell(), 0)
		lines.append("Here: " + (here if here != "" else "placeable"))
	prereq.text = "\n".join(lines)
	prereq.add_theme_font_size_override("font_size", UiTokens.body(view))
	prereq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(prereq)
	# Components: the exact slots and what satisfies them.
	var slots: Array = bp.get("slots", [])
	var slot_head := Label.new()
	slot_head.text = "Components"
	UiTokens.style_label(slot_head, view, "meta")
	_detail.add_child(slot_head)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var l := Label.new()
		l.name = "Slot_%d" % i
		l.text = "%s × %d  ·  %s%s" % [Blueprints.slot_label(s), int(s.get("quantity", 1)), ", ".join(PackedStringArray((s.get("accepted_tags", []) as Array).map(func (t: Variant) -> String: return str(t).replace("_", " ")))), "  ·  Lv. %d+" % int(s.get("min_level", 1)) if int(s.get("min_level", 1)) > 1 else ""]
		UiTokens.style_label(l, view, "body")
		_detail.add_child(l)
	var work := Label.new()
	work.text = "Work: %s s  ·  Level %d..%d%s" % [str(bp.get("work_seconds", 0)), int(bp.get("level_min", 1)), int(bp.get("level_max", 60)), "  ·  Station: Workbench"]
	UiTokens.style_label(work, view, "meta")
	_detail.add_child(work)
	# Actions: Place (the real BuildFlow call) and, on a phone, back to the list.
	_mk_footer("Back", _back_to_list, Vector2(96, 56))
	var place := _mk_footer("Place", _place_selected, Vector2(140, 64 if UiTokens.is_compact(view) else 56))
	place.disabled = not (unmet.is_empty() and placeable_here)

func _placeable_now() -> bool:
	if player == null or _selected == "":
		return false
	return BuildFlow.place_reason(player, StringName(_selected), _here_cell(), 0) == ""

## The cell in front of the survivor, the one the ghost would land on.
func _here_cell() -> Vector2i:
	if player == null:
		return Vector2i.ZERO
	return BuildGrid.tile_of(player.global_position)

func _place_selected() -> void:
	if player == null:
		return
	var s := BuildFlow.place_site(player, StringName(_selected), _here_cell(), 0)
	if s == null:
		return
	show_site(s)
	print("[ui] build placed %s site %s" % [_selected, s.site_id])

func _back_to_list() -> void:
	_phone_detail = false
	_apply_phone_pane()

func _apply_phone_pane() -> void:
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	if _site_mode and compact:
		_phone_detail = true  # the site sheet has no list to go back to
	_body.columns = 1 if compact else 2
	# A compact canvas shows one pane: the list, or the detail as a sheet over it.
	var list_node := _body.get_child(0) as Control
	var detail_node := _body.get_child(1) as Control
	if list_node:
		list_node.visible = not (compact and _phone_detail)
	if detail_node:
		detail_node.visible = not compact or _phone_detail
	_footer.visible = visible and (not compact or _phone_detail) and _footer.get_child_count() > 0

# ---------------------------------------------------------------- the site sheet (§7)

func _refresh_site_list() -> void:
	if site == null or not is_instance_valid(site):
		site = null
		_site_mode = false
		_refresh_list()
		return
	_title.text = "Build · %s" % str(site.bp().get("display_name", "site"))
	_hint.text = "Site %s · %d%% built · %d instance(s) logged" % [site.site_id.substr(0, 11), int(site.overall_progress() * 100.0), site.deposited_by.size()]

func _show_site_detail(view: Vector2) -> void:
	if site == null:
		return
	var head := Label.new()
	head.text = str(site.bp().get("display_name", "Construction site")) + " site"
	UiTokens.style_label(head, view, "heading")
	_detail.add_child(head)
	var progress := Label.new()
	progress.name = "SiteProgress"
	progress.text = "Materials %d%%  ·  Work %d%%  ·  %d/%d s" % [int(site.materials_ratio() * 100.0), int(site.work_ratio() * 100.0), int(site.work_progress), int(site.bp().get("work_seconds", 0))]
	UiTokens.style_label(progress, view, "body")
	_detail.add_child(progress)
	var slots: Array = site.bp().get("slots", [])
	for i in slots.size():
		var s: Dictionary = slots[i]
		var row := Button.new()
		row.name = "SiteSlot_%d" % i
		row.custom_minimum_size = Vector2(0, UiTokens.HEX if UiTokens.is_compact(view) else 60)
		row.add_theme_stylebox_override("normal", UiTokens.slot_style(false))
		row.pressed.connect(_deposit_slot.bind(i))
		var label := "%s  %d/%d  ·  %s" % [Blueprints.slot_label(s), site.deposited(i), site.needed(i), _instance_levels(i)]
		row.text = label
		row.add_theme_font_size_override("font_size", UiTokens.body(view))
		_detail.add_child(row)
		_slot_buttons.append(row)
	var by := Label.new()
	var who := ""
	for k in site.deposited_by:
		who += "%s: %s  " % [str(k).substr(0, 6), str(site.deposited_by[k])]
	by.text = "Contributors  " + (who if who != "" else "none yet")
	UiTokens.style_label(by, view, "meta")
	_detail.add_child(by)
	# Footer: Work, Withdraw the last deposit, Cancel the site, Done.
	_mk_footer("Work", _work, Vector2(110, 64 if UiTokens.is_compact(view) else 56)).disabled = not site.materials_ready() or site.work_done()
	_mk_footer("Withdraw", _withdraw, Vector2(130, 64 if UiTokens.is_compact(view) else 56)).disabled = site.escrow().is_empty()
	var cancel := _mk_footer("Cancel site", _cancel_site, Vector2(140, 64 if UiTokens.is_compact(view) else 56))
	cancel.add_theme_stylebox_override("normal", UiTokens.danger_style())
	var finish := _mk_footer("Finish", _finish, Vector2(120, 64 if UiTokens.is_compact(view) else 56))
	finish.disabled = not site.ready_to_finish()
	_mk_footer("Back", hide_ui, Vector2(96, 56))
	_footer.visible = true

func _instance_levels(slot: int) -> String:
	var lv: Array[int] = []
	for s in site.slot_items[slot] if slot < site.slot_items.size() else []:
		for _n in s.count:
			lv.append(s.level)
	return "-" if lv.is_empty() else ", ".join(PackedStringArray(lv.map(func (n: int) -> String: return "Lv %d" % n)))

## Tap on a slot: deposit the lowest-level instance the bag has that fits it (the site itself
## refuses a wrong tag; the button just offers the default).
func _deposit_slot(slot: int) -> void:
	if site == null or player == null:
		return
	var idx: int = site.first_fitting(player.inventory, slot)
	if idx < 0:
		player.notice("No %s in the bag." % Blueprints.slot_label((site.bp().get("slots", []) as Array)[slot]))
		return
	site.deposit(slot, idx)
	rebuild()

func _withdraw() -> void:
	if site == null:
		return
	for i in site.slot_items.size():
		if not (site.slot_items[i] as Array).is_empty() and site.withdraw(i):
			break
	rebuild()

func _work() -> void:
	if site == null:
		return
	site.work(1.0)
	rebuild()

func _cancel_site() -> void:
	if site == null or player == null:
		return
	if site.cancel(player):
		hide_ui()

func _finish() -> void:
	if site == null or player == null:
		return
	BuildFlow.complete(player, site)
	site = null
	_site_mode = false
	hide_ui()

# ---------------------------------------------------------------- widgets

func _mk_btn(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	# The tap floor: 64 px on a phone canvas, the desktop action size above it. Wide buttons keep
	# their width; only the shorter side is lifted.
	if UiTokens.is_compact(get_viewport_rect().size):
		minsz = Vector2(maxf(minsz.x, UiTokens.HEX), maxf(minsz.y, UiTokens.HEX))
	b.custom_minimum_size = minsz
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	b.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
	b.pressed.connect(cb)
	return b

## A footer button: the phone gets the 64 px tap floor, the desktop its 56 px action size.
func _mk_footer(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := _mk_btn(text, cb, minsz)
	_footer.add_child(b)
	_footer.visible = true
	return b
