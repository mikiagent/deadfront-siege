class_name TribeScreen
extends Control
## TRIBE M1: the Animals screen's Tribe tab (SheetChrome). Left: recruits waiting at the dock, then the
## members (count / housing). Right: the selected person - potential, level, skills, needs and what
## they are doing; Accept / Deny for a recruit; for a member the orders (Follow, Guard, Heel, Attack,
## Stay), one job at a time (Mine / Chop / Gather here, into the nearest chest), Rename, and the seven
## gear slots (tap a worn slot to take it back, tap a bag item to equip it). Taking direct control is
## M2 (Tribe.take_control).

const REFRESH := 0.5

var player: Player
var selected: TribeRecord
var chrome: SheetChrome
var _backdrop: ColorRect
var _left: Panel
var _right: Panel
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _version := -1
var _refresh_left := 0.0
var _rename: PetRenameDialog
## The last refusal (Accept with no housing, an equip that does not fit), shown under the actions.
var last_refusal: String = ""

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = SheetChrome.ui_theme()
	_backdrop = SheetChrome.backdrop()
	add_child(_backdrop)
	chrome = SheetChrome.new("Animals")
	add_child(chrome)
	var pack := chrome.add_tab("Pack", false)
	pack.pressed.connect(_to_pack)
	chrome.add_tab("Tribe", true)
	chrome.back_pressed.connect(_back)
	chrome.close_pressed.connect(close_screen)
	_left = _panel("TribeList")
	_right = _panel("TribeDetail")
	_list_scroll = _scroll(_left)
	_list = _vbox(_list_scroll, 4)
	_detail_scroll = _scroll(_right)
	_detail = _vbox(_detail_scroll, 8)
	_rename = PetRenameDialog.new()
	add_child(_rename)
	get_viewport().size_changed.connect(_layout)

func _panel(n: String) -> Panel:
	var p := Panel.new()
	p.name = n
	p.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	p.clip_contents = true
	add_child(p)
	return p

func _scroll(parent: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(s)
	return s

func _vbox(parent: Control, sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

func _layout() -> void:
	if chrome == null:
		return
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	var safe := UiTokens.safe_insets(get_viewport())
	var side := SheetChrome.side_for(view)
	var top := SheetChrome.body_top(view)
	var bottom := view.y - (8.0 if compact else 32.0) - safe.y
	var gap := 8.0 if compact else 20.0
	chrome.layout(view, safe)
	var left_x := side + safe.w
	var right_x := view.x - side - safe.x
	var lw := minf(420.0, (right_x - left_x) * 0.34)
	_left.position = Vector2(left_x, top)
	_left.size = Vector2(lw, bottom - top)
	_right.position = Vector2(left_x + lw + gap, top)
	_right.size = Vector2(right_x - _right.position.x, bottom - top)
	var pad := 8.0 if compact else 16.0
	for pair in [[_list_scroll, _left], [_detail_scroll, _right]]:
		(pair[0] as Control).position = Vector2(pad, pad)
		(pair[0] as Control).size = (pair[1] as Control).size - Vector2(pad, pad) * 2.0

# ---------------------------------------------------------------- open / close

func open(p: Player, rec: TribeRecord = null) -> void:
	player = p
	if rec:
		selected = rec
	if selected == null or not (Tribe.members.has(selected) or Tribe.pending.has(selected)):
		selected = Tribe.pending[0] if not Tribe.pending.is_empty() else (Tribe.members[0] if not Tribe.members.is_empty() else null)
	visible = true
	last_refusal = ""
	_layout()
	rebuild()

func close_screen() -> void:
	visible = false
	_rename.close()

func _back() -> void:
	close_screen()
	SheetChrome.back_to_menu(get_tree())

func _to_pack() -> void:
	close_screen()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_animals"):
		hud.open_animals()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _rename.visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible or player == null:
		return
	_refresh_left -= delta
	if Tribe.version != _version or _refresh_left <= 0.0:
		_refresh_left = REFRESH
		if Tribe.version != _version:
			rebuild()
		else:
			_rebuild_detail()  # live needs and state

# ---------------------------------------------------------------- content

func rebuild() -> void:
	_version = Tribe.version
	if selected != null and not (Tribe.members.has(selected) or Tribe.pending.has(selected)):
		selected = null
	var view := get_viewport_rect().size
	chrome.counter.text = "Tribe %d / %d" % [Tribe.members.size(), Tribe.housing_cap()]
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_list.add_child(SheetChrome.section_label("At the dock (%d / %d)" % [Tribe.pending.size(), Tribe.pending_cap()], view))
	if Tribe.pending.is_empty():
		_list.add_child(_muted("Nobody waiting. A boat comes about once a day."))
	for r in Tribe.pending:
		_list.add_child(_row(r, "%s · %s · leaves in %s" % [r.name, r.potential_label(), _clock(r.wait_left)]))
	_list.add_child(SheetChrome.section_label("Members", view))
	if Tribe.members.is_empty():
		_list.add_child(_muted("No members yet. Accept a recruit at the dock."))
	for r in Tribe.members:
		_list.add_child(_row(r, "%s · Lv %d · %s" % [r.name, r.level, _doing(r)]))
	_rebuild_detail()

func _row(r: TribeRecord, text: String) -> Button:
	var b := SheetChrome.action_button(text, &"cta" if r == selected else &"ghost")
	b.name = "Row_%s" % r.uid
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func () -> void:
		selected = r
		last_refusal = ""
		rebuild())
	return b

func _muted(t: String) -> Label:
	var l := SheetChrome.text(t, 14, UiTokens.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = false
	return l

static func _clock(s: float) -> String:
	var m := int(maxf(0.0, s)) / 60
	return "%dm %02ds" % [m, int(maxf(0.0, s)) % 60]

func _doing(r: TribeRecord) -> String:
	var body := player.tribe.body_of(r) if player and player.tribe else null
	var st := str(body.state) if body else "away"
	if body and body.tool_worn and str(body.state) == "idle":
		st = "tool worn: 1 durability left, repair or swap it"  # P1 WEAR: why the job stopped
	if TribeWork.is_station_job(r):
		return "%s · %s" % [TribeWork.plate_text(r), st]  # TRIBE M2a: Stay cancels it and refunds
	if r.order == &"work":
		return "%s job · %s" % [str(r.job.get("kind", "")).capitalize(), st]
	return "%s · %s" % [str(r.order).capitalize(), st]

func _rebuild_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var r := selected
	if r == null:
		_detail.add_child(_muted("Tribe members follow you, fight beside you and work at your home. Recruits arrive by boat at the dock."))
		return
	var view := get_viewport_rect().size
	var head := SheetChrome.text(r.name, 26 if UiTokens.is_compact(view) else 34)
	head.name = "DetailName"
	_detail.add_child(head)
	var pending := Tribe.pending.has(r)
	_detail.add_child(SheetChrome.text("Potential: %s · Level %d · Gathering %d · Melee %d" % [r.potential_label(), r.level, r.skill("gathering"), r.skill("melee")], 16))
	_detail.add_child(SheetChrome.text("Health %d / %d · Energy %d · Fatigue %d · Fullness %d" % [roundi(r.hp()), roundi(r.max_hp()), roundi(r.energy), roundi(r.fatigue), roundi(r.fullness)], 16, UiTokens.MUTED))
	if pending:
		_detail.add_child(_muted("Waiting at the dock. Leaves in %s if nobody answers." % _clock(r.wait_left)))
		_grid([["Accept", &"cta", func () -> void: _refuse(Tribe.accept(r))], ["Deny", &"danger", func () -> void: Tribe.deny(r)]])
	else:
		_detail.add_child(SheetChrome.text("Now: %s" % _doing(r), 16))
		_detail.add_child(SheetChrome.section_label("Orders", view))
		var orders: Array = []
		for o: StringName in [&"follow", &"guard", &"heel", &"attack", &"stay"]:
			orders.append([str(o).capitalize(), &"cta" if r.order == o else &"ghost", func () -> void: Tribe.set_order(r, o)])
		_grid(orders)
		_detail.add_child(SheetChrome.section_label("Job (one at a time, here, into the nearest chest)", view))
		var jobs: Array = []
		for k: StringName in TribeRecord.JOB_KINDS:
			var on := r.order == &"work" and str(r.job.get("kind", "")) == str(k)
			jobs.append([{&"mine": "Mine here", &"chop": "Chop here", &"gather": "Gather here"}[k], &"cta" if on else &"ghost", func () -> void: assign_job(r, k)])
		jobs.append(["Rename", &"ghost", func () -> void: _rename.open(r.name, func (nm: String) -> String: return Tribe.rename(r, nm))])
		_grid(jobs)
		if r.order == &"work":
			var body := player.tribe.body_of(r) if player and player.tribe else null
			if body and body.storage() == null:
				_detail.add_child(_muted("No chest near the job: build a basket there, or they keep what they carry."))
		_gear(r, view)
	if last_refusal != "":
		var why := SheetChrome.text(last_refusal, 16, UiTokens.DANGER)
		why.name = "Refusal"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(why)

func _refuse(why: String) -> void:
	last_refusal = why
	rebuild()

## A job at the survivor's spot, into the storage building nearest her (if any).
func assign_job(r: TribeRecord, kind: StringName) -> void:
	var at := player.global_position
	var chest := Vector3.INF
	var best := 30.0
	for n in player.get_tree().get_nodes_in_group("placed_building"):
		if n.get("storage") != null and (n as Node3D).global_position.distance_to(at) < best:
			best = (n as Node3D).global_position.distance_to(at)
			chest = (n as Node3D).global_position
	_refuse(Tribe.set_job(r, kind, at, chest))

func _grid(rows: Array) -> void:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in rows:
		var b := SheetChrome.action_button(str(row[0]), row[1])
		b.name = "Act_%s" % str(row[0]).replace(" ", "")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(row[2])
		g.add_child(b)
	_detail.add_child(g)

## The seven slots (tap = back to the bag), then the bag items this member can wear (tap = equip).
func _gear(r: TribeRecord, view: Vector2) -> void:
	_detail.add_child(SheetChrome.section_label("Gear", view))
	var worn: Array = []
	for slot in EntityEquipment.HUMAN_SLOTS:
		var st := r.equipment.worn(slot)
		var label := "%s: %s" % [str(slot).capitalize(), st.def().display_name if st and st.def() else "-"]
		worn.append([label, &"ghost", func () -> void:
			if r.equipment.worn(slot):
				_refuse(r.equipment.unequip_to(player.inventory, slot))])
	_grid(worn)
	var wearable: Array = []
	for i in player.inventory.slot_count:
		if r.equipment.equip_refusal(player.inventory, i) == "":
			var st := player.inventory.slots[i]
			wearable.append(["Equip %s" % (st.def().display_name if st.def() else str(st.def_id)), &"ghost", func () -> void:
				_refuse(r.equipment.equip_from(player.inventory, i))])
	if wearable.is_empty():
		_detail.add_child(_muted("Nothing in your bag they can wear."))
	else:
		_grid(wearable)
