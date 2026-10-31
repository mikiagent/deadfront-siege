class_name TribeAssignPicker
extends Control
## TRIBE M2a: "Assign…" from the craft panel or the Construction panel. A modal list of tribe members,
## one 64 px row each: name, their level in the job's skill, predicted success and time (TribeWork
## offer_text). A member who can't take it shows why in red and can't be tapped ("needs Processing 10",
## "Missing materials", "Joss is busy"). Tapping a row calls on_pick(record) and closes.

var on_pick: Callable
var rows_box: VBoxContainer
var title_label: Label

## rows: [{"record": TribeRecord, "text": String, "why": String}].
static func open_on(parent: Node, title: String, rows: Array, pick: Callable) -> TribeAssignPicker:
	var old := parent.get_node_or_null("TribeAssignPicker")
	if old:
		old.queue_free()
	var p := TribeAssignPicker.new()
	p.name = "TribeAssignPicker"
	parent.add_child(p)
	p.fill(title, rows, pick)
	return p

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", CraftUI.pad(Color(0.02, 0.025, 0.03, 0.96), 18, 18, 14, 14))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title_label = CraftUI._label("", 22, UiTokens.TEXT)
	box.add_child(title_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 64.0), minf(300.0, get_viewport_rect().size.y - 170.0))
	box.add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 6)
	scroll.add_child(rows_box)
	var close := CraftUI.mk_btn("Close", queue_free, Vector2(0, 64), "ghost")
	close.name = "PickerClose"
	box.add_child(close)

func fill(title: String, rows: Array, pick: Callable) -> void:
	on_pick = pick
	title_label.text = title
	if rows.is_empty():
		rows_box.add_child(CraftUI._label("No tribe members yet: accept a recruit at the dock.", 18, UiTokens.MUTED))
		return
	for row: Dictionary in rows:
		var r: TribeRecord = row["record"]
		var why := str(row.get("why", ""))
		var b := CraftUI.mk_btn(str(row.get("text", r.name)) if why == "" else "%s — %s" % [r.name, why], _pick.bind(r), Vector2(0, 64), "cta" if why == "" else "ghost")
		b.name = "Pick_" + r.uid
		b.disabled = why != ""
		b.add_theme_font_size_override("font_size", 20)
		if why != "":
			b.add_theme_color_override("font_disabled_color", UiTokens.LIFE)
		rows_box.add_child(b)

func _pick(r: TribeRecord) -> void:
	var cb := on_pick
	queue_free()
	if cb.is_valid():
		cb.call(r)
