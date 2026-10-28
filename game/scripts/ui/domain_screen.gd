class_name DomainScreen
extends Control
## Spec 29 section 2's Domain screen (Main Menu -> Domain): the four territory tabs, what the
## survivor holds on this island (cells used / cap), and the actions the record allows - Declare when
## there is no domain yet, Expand when there is, Renew / Release where they apply (declared here as
## later phases, disabled with the reason). Declare and Expand both open the ground-grid preview
## (DomainPreview): the screen stays up as a narrow panel so the terrain stays readable, and its
## footer is the candidate count with Confirm / Cancel.
##
## Layout: a left tab rail and a content card on a wide canvas; on a landscape phone the tabs turn
## into a row under the title and the card takes the full width. Every action is 64 px tall on a
## phone and 56 on desktop (tap targets; the gate measures the smallest).

const GOLD := Color(0.96, 0.82, 0.36)
const GOLD_DIM := Color(0.35, 0.30, 0.16)
const TABS := [
	["tamed_island", "Tamed Island"],
	["civilized_island", "Civilized Island"],
	["clan", "Clan"],
	["outpost", "Outpost"],
]
## ASSUMPTION: spec 29 says the other three territory types are later phases. Their tabs exist (the
## screen has four, per the acceptance criteria) and say so instead of pretending to work.
## Full label on a wide canvas, short one on a phone (a tab rail clips otherwise).
const TAB_LABEL := {
	"tamed_island": ["Tamed Island", "Tamed"],
	"civilized_island": ["Civilized Island", "Civilized"],
	"clan": ["Clan", "Clan"],
	"outpost": ["Outpost", "Outpost"],
}
const PHASE_NOTE := {
	"civilized_island": "Phase E: shared-world claims, rent and renewal. Not in this build.",
	"clan": "Phase F: clan Enclaves, unlocked at Clan Level 5. Not in this build.",
	"outpost": "Phase G: Savage Island Outposts at Courier Warp Holes. Not in this build.",
}

var player: Player
var rt: IslandRuntime
var preview: DomainPreview
var tab: String = "tamed_island"

var _title: Label
var _island: Label
var _stats: Label
var _body: Label
var _note: Label
var _tabs_box: Container
var _content: VBoxContainer
var _outer: BoxContainer
var _tab_buttons: Dictionary = {}
var _actions: HBoxContainer
var _declare: Button
var _expand: Button
## DOMAIN-D / spec 29 section 4: the Personal Communications Center's contribution panel.
var _center: Button
var center_ui: CommCenterUI
var _renew: Button
var _release: Button
var _confirm: Button
var _cancel: Button
var _close: Button
var _root_panel: Panel
var _backdrop: ColorRect

var _previewing := false
var _last_reason := ""
var _picked := 0

func _ready() -> void:
	visible = false
	name = "DomainScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the world stays live; only the card blocks
	z_index = 44
	_root_panel = Panel.new()
	_root_panel.name = "Card"
	_root_panel.add_theme_stylebox_override("panel", UiTokens.panel_style(0.95))
	# An opaque backdrop under the card: what is behind it must not read through the copy, and the
	# card covers the HUD's own panels (the quest card sits in the same corner on a phone).
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.02, 0.025, 0.03, 0.90)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_root_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_panel.clip_contents = true
	add_child(_root_panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTokens.SPACE * 2)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UiTokens.SPACE)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", UiTokens.SPACE)
	stack.add_child(head)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "DOMAIN"
	_title.add_theme_color_override("font_color", UiTokens.TEXT)
	head.add_child(_title)
	_island = Label.new()
	_island.name = "Island"
	_island.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_island.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_island.clip_text = true
	_island.add_theme_color_override("font_color", GOLD)
	head.add_child(_island)

	_tabs_box = VBoxContainer.new()
	_tabs_box.name = "Tabs"
	_tabs_box.add_theme_constant_override("separation", UiTokens.SPACE)
	_tabs_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for row in TABS:
		var id: String = row[0]
		var b := _button(str(row[1]), false)
		b.name = "Tab_%s" % id
		b.toggle_mode = true
		b.pressed.connect(func () -> void: select_tab(id))
		_tab_buttons[id] = b
		_tabs_box.add_child(b)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", UiTokens.SPACE)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats = Label.new()
	_stats.name = "Stats"
	_stats.add_theme_color_override("font_color", UiTokens.TEXT)
	_content.add_child(_stats)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_text = true
	_body.add_theme_color_override("font_color", UiTokens.META)
	_content.add_child(_body)
	_note = Label.new()
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", GOLD)
	_content.add_child(_note)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", UiTokens.SPACE)
	_content.add_child(_actions)

	_outer = HBoxContainer.new()
	_outer.name = "Outer"
	_outer.add_theme_constant_override("separation", UiTokens.SPACE)
	_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_outer)
	_outer.add_child(_tabs_box)
	_outer.add_child(_content)

	_declare = _action("DECLARE", true, _on_declare, "Declare")
	_expand = _action("EXPAND", true, _on_expand, "Expand")
	_renew = _action("RENEW", false, _on_later, "Renew")
	_release = _action("RELEASE", false, _on_release, "Release")
	_confirm = _action("CONFIRM", true, _on_confirm, "Confirm")
	_cancel = _action("CANCEL", false, _on_cancel, "Cancel")
	_close = _action("CLOSE", false, _on_close, "Close")
	# DOMAIN-D: behind the rank/cap line - the contribution track that raises both.
	_center = _action("CENTER", true, _on_center, "Center")

	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	size = get_viewport_rect().size
	_layout()

func _button(text: String, gold: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	b.add_theme_stylebox_override("hover", UiTokens.button_style(true))
	b.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	b.add_theme_color_override("font_color", GOLD if gold else UiTokens.TEXT)
	b.clip_text = true
	return b

func _action(text: String, gold: bool, cb: Callable, node_name: String) -> Button:
	var b := _button(text, gold)
	b.name = node_name
	b.pressed.connect(cb)
	_actions.add_child(b)
	return b

# ---------------------------------------------------------------- open / close / tabs

func open(p: Player) -> void:
	player = p
	rt = World.runtime
	visible = true
	size = get_viewport_rect().size
	if rt != null:
		IslandClaims.sync_cap(rt)
	tab = "tamed_island"
	_previewing = false
	_last_reason = ""
	_picked = 0
	_shown_rank = DomainRules.pioneer_rank()
	_shown_cap = int(rt.call("claim_cap")) if rt != null else DomainRules.cap()
	_refresh()
	_layout()
	UiTokens.focus_first([_tab_buttons["tamed_island"]])

## DOMAIN-D / spec 29 section 4: the contribution panel raises the rank, and the capacity shown here
## must follow it while the screen stays open. One record read and a compare per frame is cheap.
var _shown_rank := -1
var _shown_cap := -1

func _process(_delta: float) -> void:
	if not visible:
		return
	var rank: int = DomainRules.pioneer_rank()
	var cap: int = rt.call("claim_cap") if rt != null and is_instance_valid(rt) else DomainRules.cap()
	if rank == _shown_rank and cap == _shown_cap:
		return
	_shown_rank = rank
	_shown_cap = cap
	_refresh()

func close() -> void:
	_end_preview()
	if center_ui != null and is_instance_valid(center_ui):
		center_ui.close()
	visible = false

func is_open() -> bool:
	return visible

func select_tab(id: String) -> void:
	tab = id
	_refresh()

func is_previewing() -> bool:
	return _previewing

# ---------------------------------------------------------------- the card's text

func _refresh() -> void:
	for id in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		var on: bool = str(id) == tab
		b.set_pressed_no_signal(on)
		b.add_theme_stylebox_override("normal", UiTokens.button_style(on))
		b.add_theme_color_override("font_color", GOLD if on else UiTokens.TEXT)
	rt = World.runtime
	var here := _island_name()
	_island.text = here
	if tab != "tamed_island":
		_stats.text = ""
		_body.text = str(PHASE_NOTE.get(tab, ""))
		_note.text = ""
		# The center belongs to the Tamed Island: leave the tab and its button goes with it.
		_center.visible = false
		_set_actions(false, false, false, false, false, false, true)
		return
	var own: bool = rt != null and IslandClaims.has_domain(rt)
	var used: int = rt.call("claim_used") if rt != null else 0
	var cap: int = rt.call("claim_cap") if rt != null else DomainRules.cap()
	# DOMAIN-D / spec 29 section 4: the rank the Personal Communications Center has raised, and the
	# cap the next documented step would bring (the capacity the center raises; land still comes
	# only from Declare/Expand here).
	var rank: int = DomainRules.pioneer_rank()
	var next: Array = DomainRules.next_milestone(rank)
	_stats.text = "Plots  %d / %d   ·   Pioneer rank %d" % [used, cap, rank]
	var lines: Array[String] = []
	lines.append("Owner  %s   ·   %s" % [str(World.player_name), "personal Tamed Island" if World.is_home() else "visited island"])
	lines.append("Grid  %d x %d tiles a cell on the island's origin grid" % [DomainRules.cell_tiles(), DomainRules.cell_tiles()])
	lines.append("Upkeep  none on a Tamed Island" % [])
	if World.is_home():
		if next.size() >= 2 and int(next[0]) > 0:
			var next_rank := int(next[0])
			var step: Dictionary = CommCenter.step_for(next_rank)
			var how := "contribute at the Communications Center" if step.is_empty() or CommCenter.built(rt) else "build the Communications Center, then contribute"
			lines.append("Capacity  Pioneer rank %d -> %d plots at rank %d (%s)" % [rank, int(next[1]), next_rank, how])
		else:
			lines.append("Capacity  every documented Pioneer step is done" % [])
	if own:
		lines.append("Land  %d cell%s held, %d more until the cap" % [used, "" if used == 1 else "s", maxi(0, cap - used)])
		lines.append("Grow  edge-adjacent cells only: no diagonal, no hop across water")
	else:
		lines.append("Land  no domain declared here yet" % [])
		lines.append("Declare  pick any valid cell next to your camp land")
	if _previewing:
		lines.append("Preview  tap cells to select; Confirm stakes them as one batch")
	# A landscape phone has ~230 px of card left under the tabs: keep the lines that decide anything.
	if UiTokens.is_compact(get_viewport_rect().size):
		lines = lines.slice(2)
	_body.text = "\n".join(lines)
	if World.is_home():
		_note.text = "Claim limit reached: raise your Pioneer rank to claim more." if used >= cap and own else ""
	else:
		_note.text = "Visiting an island: land you claim here is not your Tamed Island domain."
	_set_actions(not _previewing and tab == "tamed_island", not _previewing and tab == "tamed_island", false, not _previewing and own, _previewing, _previewing, true)
	_center.disabled = _previewing or tab != "tamed_island" or not World.is_home()
	_declare.visible = not _previewing and not own
	_expand.visible = not _previewing and own
	_center.visible = not _previewing and tab == "tamed_island" and World.is_home()
	_renew.visible = false
	_release.visible = not _previewing and own
	_confirm.visible = _previewing
	_cancel.visible = _previewing
	_update_footer()

func _set_actions(declare: bool, expand: bool, renew: bool, release: bool, confirm: bool, cancel: bool, close_ok: bool) -> void:
	_declare.disabled = not declare
	_expand.disabled = not expand
	_renew.disabled = not renew
	_release.disabled = not release
	_confirm.disabled = not confirm
	_cancel.disabled = not cancel
	_close.disabled = not close_ok

func _island_name() -> String:
	if rt == null:
		return "No island"
	var def: Dictionary = World.island_def
	var label := str(def.get("name", World.island_id)).replace("_", " ")
	return label.capitalize() if label != "" else "Uncharted island"

# ---------------------------------------------------------------- Declare / Expand / Confirm

func _on_declare() -> void:
	_start_preview("declare")

func _on_expand() -> void:
	_start_preview("expand")

func _start_preview(mode: String) -> void:
	if rt == null:
		return
	if preview == null:
		preview = DomainPreview.new()
		preview.top_level = true
		rt.add_child(preview)
		preview.selection_changed.connect(_on_selection_changed)
		preview.cell_refused.connect(_on_cell_refused)
	_previewing = true
	var at: Vector2i = IslandClaims.cell_of(rt, BuildGrid.tile_of(player.global_position)) if player != null else IslandClaims.cell_of(rt, Vector2i.ZERO)
	if mode == "declare" and IslandClaims.has_domain(rt):
		at = IslandClaims.cell_of(rt, IslandClaims.cell_rect(rt, (rt.domain["cells"][0] as Vector2i)).get_center())
	preview.begin(rt, at)
	_last_reason = ""
	_picked = 0
	_refresh()
	_layout()  # the card widens back / narrows for the preview

func _on_selection_changed(count: int) -> void:
	_picked = count
	_last_reason = ""
	_update_footer()

func _on_cell_refused(reason: String) -> void:
	_last_reason = preview.reason_text(reason) if preview != null else reason
	_update_footer()

func _on_confirm() -> void:
	if preview == null or not _previewing:
		return
	var out: Dictionary = preview.commit()
	if not bool(out["ok"]):
		_last_reason = IslandClaims.reason_text(str(out["reason"]))
		_update_footer()
		_refresh_stats_only()
		return
	_last_reason = ""
	_previewing = false
	_end_preview()
	_refresh()
	_layout()

func _on_cancel() -> void:
	_previewing = false
	_end_preview()
	_refresh()
	_layout()

func _end_preview() -> void:
	if preview != null and is_instance_valid(preview):
		preview.finish()
	preview = null

func _on_release() -> void:
	if rt == null:
		return
	IslandClaims.clear_domain(rt)
	_refresh()

func _on_later() -> void:
	_last_reason = "Renewal belongs to Civilized Island claims (Phase E)."
	_update_footer()

func _on_center() -> void:
	if center_ui == null or not is_instance_valid(center_ui):
		center_ui = CommCenterUI.new()
		add_child(center_ui)
		center_ui.closed.connect(_on_center_closed)
	# The panel is a modal on top of this card (both are the same screen's text): the card and its
	# scrim hide while it is up, and one Close brings the Domain screen back with its capacity
	# already updated. The screen node itself stays visible: hiding it would zero the panel's layout.
	_root_panel.visible = false
	_backdrop.visible = false
	center_ui.open(player)

func _on_center_closed() -> void:
	if not visible:
		return
	_root_panel.visible = true
	_backdrop.visible = true
	_refresh()
	_layout()

func _on_close() -> void:
	close()

func _update_footer() -> void:
	if not _previewing:
		_note.text = _last_reason
		return
	var cap: int = rt.call("claim_cap") if rt != null else DomainRules.cap()
	var used: int = rt.call("claim_used") if rt != null else 0
	# The count comes from the preview itself: a signalled count went stale once (a shot said
	# "Selected 0" with three cells picked, i.e. the label lagged the grid).
	if preview != null and is_instance_valid(preview):
		_picked = preview.selected_cells().size()
	var head := "Selected %d · holds %d / %d" % [_picked, used, cap]
	_note.text = head if _last_reason == "" else "%s — %s" % [head, _last_reason]
	_confirm.disabled = _picked == 0

func _refresh_stats_only() -> void:
	if rt == null:
		return
	_stats.text = "Plots  %d / %d" % [int(rt.call("claim_used")), int(rt.call("claim_cap"))]

# ---------------------------------------------------------------- layout

## The card is one container stack: a header, then tabs + content (side by side on a wide canvas, a
## tab row above the content on a phone), so no text is ever hand-positioned over another control.
func _layout() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	var phone := UiTokens.is_phone(view)
	var pad := 12.0 if compact else 20.0
	var head := UiTokens.heading(view)
	_title.add_theme_font_size_override("font_size", head)
	_island.add_theme_font_size_override("font_size", head)
	_stats.add_theme_font_size_override("font_size", head)
	for l in [_body, _note]:
		(l as Label).add_theme_font_size_override("font_size", UiTokens.body(view))
	for b in [_declare, _expand, _renew, _release, _confirm, _cancel, _close, _center]:
		(b as Button).add_theme_font_size_override("font_size", UiTokens.body(view))
	for id in _tab_buttons.keys():
		(_tab_buttons[id] as Button).add_theme_font_size_override("font_size", UiTokens.body(view))
		# A landscape phone has ~200 px a tab: "Tamed", "Civilized", "Clan", "Outpost" fit.
		(_tab_buttons[id] as Button).text = str(TAB_LABEL[id][1] if compact else TAB_LABEL[id][0])
	var btn_h := 64.0 if compact else 56.0
	for b in [_declare, _expand, _renew, _release, _confirm, _cancel, _close, _center]:
		(b as Button).custom_minimum_size = Vector2(0.0, btn_h)
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		b.custom_minimum_size = Vector2(0.0, btn_h if compact else 48.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A landscape phone is compact but not "phone" (844 wide), and a 520 px card there squeezed the
	# tab row and clipped the copy: compact canvases get the full width and tighter margins.
	var margin_px := 8 if compact else UiTokens.SPACE * 2
	var margin := _root_panel.get_node_or_null("Margin") as MarginContainer
	if margin != null:
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, margin_px)
	# Compact: full width up to 600 px (a phone's body text over ~700 px is too long a measure, and
	# the ground has to stay visible for the preview); wide: a 520-620 px card on the left.
	var card_w := minf(600.0, view.x - pad * 2.0) if (phone or compact) else minf(620.0, maxf(520.0, view.x * 0.42))
	# While previewing, the ground grid is the point: the card gives up width (a phone) so the cells
	# the survivor is picking stay visible beside it.
	if _previewing and (phone or compact):
		card_w = minf(card_w, maxf(360.0, view.x * 0.45))
	var card_h := view.y - pad * 2.0
	_root_panel.position = Vector2(pad, pad)
	_root_panel.size = Vector2(card_w, card_h)
	_backdrop.position = _root_panel.position
	_backdrop.size = _root_panel.size
	_set_axis(compact)
	if not compact:
		(_tabs_box as Control).custom_minimum_size = Vector2(196.0, 0.0)
		(_tabs_box as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tabs_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		(_tabs_box as Control).custom_minimum_size = Vector2(0.0, btn_h)
		(_tabs_box as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_tabs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

## Tabs beside the content on a wide canvas, above it on a phone.
func _set_axis(horizontal_tabs: bool) -> void:
	var want_outer: bool = horizontal_tabs == false  # wide: tabs | content in a row
	var need_swap: bool = (_outer is HBoxContainer) != want_outer
	if need_swap:
		var kids: Array[Node] = _outer.get_children()
		# want_outer = a row of tabs | content (wide canvas); otherwise the tabs stack above it.
		var fresh: BoxContainer = HBoxContainer.new() if want_outer else VBoxContainer.new()
		fresh.name = "Outer"
		fresh.add_theme_constant_override("separation", UiTokens.SPACE)
		fresh.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for k in kids:
			_outer.remove_child(k)
			fresh.add_child(k)
		var stack := _outer.get_parent()
		stack.remove_child(_outer)
		_outer.queue_free()
		_outer = fresh
		stack.add_child(_outer)
	var want_row: bool = horizontal_tabs
	if (_tabs_box is HBoxContainer) != want_row:
		var kids2: Array[Node] = _tabs_box.get_children()
		var fresh2: Container = HBoxContainer.new() if want_row else VBoxContainer.new()
		fresh2.name = "Tabs"
		fresh2.add_theme_constant_override("separation", UiTokens.SPACE)
		for k in kids2:
			_tabs_box.remove_child(k)
			fresh2.add_child(k)
		_tabs_box.get_parent().remove_child(_tabs_box)
		_tabs_box.queue_free()
		_tabs_box = fresh2
		_outer.add_child(_tabs_box)
		_outer.move_child(_tabs_box, 0)

## Smallest interactive control height on screen (the gate's tap-target check).
func min_target_px() -> float:
	var low := INF
	for b in [_declare, _expand, _confirm, _cancel, _close, _center]:
		var btn := b as Button
		if btn.visible:
			low = minf(low, btn.size.y)
	for id in _tab_buttons.keys():
		var btn: Button = _tab_buttons[id]
		if btn.visible:
			low = minf(low, btn.size.y)
	return low if low < INF else 0.0
