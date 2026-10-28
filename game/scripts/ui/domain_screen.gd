class_name DomainScreen
extends UiWorldSheet
## F1 Domain (docs/design/ui-redesign-spec.md §7 F1; spec 18 and 29 section 2): a full-screen sheet
## with the four territory tabs as a left icon column (Tamed Island / Civilized Island / Clan /
## Outpost, the last three later phases and saying so), and a content card:
## - no domain yet: the declare panel (GOLD headline, body, quote, GOLD "Declare Domain", island art);
## - a domain held: the plot grid around it (Domain gold, "can expand" gold outline, water blue) with
##   Plots used / cap, Pioneer rank, upkeep, next rank and the Communications Center link
##   (CommCenterUI, the spec-29 contribution panel), and Expand / Build here / Release.
## A footer band carries the territory rule. Declare and Expand open the ground-grid preview
## (DomainPreview): the sheet steps aside to a narrow card (Confirm / Cancel) so the terrain stays
## readable. Open with HuntHud.open_domain() (nav menu) or open(player).

const TABS := [
	["tamed_island", "Tamed Island", "Tamed", &"claim"],
	["civilized_island", "Civilized Island", "Civilized", &"build"],
	["clan", "Clan", "Clan", &"pets"],
	["outpost", "Outpost", "Outpost", &"attack"],
]
## ASSUMPTION: spec 29 says the other three territory types are later phases. Their tabs exist (the
## screen has four, per the acceptance criteria) and say so instead of pretending to work.
const PHASE_NOTE := {
	"civilized_island": ["Civilized Island claims", "Shared-world claims with rent and renewal arrive in Phase E. Not in this build."],
	"clan": ["Clan Enclaves", "Clan Enclaves unlock at Clan Level 5 in Phase F. Not in this build."],
	"outpost": ["Savage Island Outposts", "Outposts at Courier Warp Holes arrive in Phase G. Locked in this build."],
}
## Outpost is drawn locked (mockup F1): muted icon and label.
const LOCKED_TABS := ["outpost"]
const GRID_RADIUS := 3  ## the plot grid shows 7 x 7 cells around the domain
## ASSUMPTION: the canvas footer ("only buildings inside your Domain can be used") is not a rule in
## code; the footer states the growth rule the claim code enforces (IslandClaims.adjacent_to).
const RULE_TEXT := "Your Domain grows one plot at a time, edge to edge: no diagonal, no hop across water."

var player: Player
var rt: IslandRuntime
var preview: DomainPreview
var tab: String = "tamed_island"
## DOMAIN-D / spec 29 section 4: the Personal Communications Center's contribution panel.
var center_ui: CommCenterUI

var _tabs_box: VBoxContainer
var _tab_buttons: Dictionary = {}
var _tab_marks: Dictionary = {}
var _card: PanelContainer
var _pad: MarginContainer
var _main: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _headline: Label
var _body: Label
var _quote: Label
var _grid_title: Label
var _grid: _PlotGrid
var _legend: HBoxContainer
var _msg: Label
var _art: _IslandArt
var _stats: RichTextLabel
var _rows: VBoxContainer
var _row_labels: Dictionary = {}
var _center: Button
var _actions: HBoxContainer
var _declare: Button
var _expand: Button
var _build_here: Button
var _release: Button
var _footer: Label
var _foot_band: PanelContainer
# preview mode: a narrow card, the world visible beside it
var _pv_card: PanelContainer
var _pv_title: Label
var _note: Label
var _confirm: Button
var _cancel: Button

var _release_mode := false  ## UNCLAIM: the preview card is asking about a release, not a claim
var _release_cell := IslandClaims.NO_CELL  ## UNCLAIM: the plot picked in the grid (NO_CELL: none)
var _release_building := ""
var _previewing := false
var _last_reason := ""
var _picked := 0

func _init() -> void:
	super("Domain")

func _build() -> void:
	name = "DomainScreen"
	back_pressed.connect(close)
	close_pressed.connect(close)
	_tabs_box = VBoxContainer.new()
	_tabs_box.name = "Tabs"
	_tabs_box.add_theme_constant_override("separation", 0)
	body.add_child(_tabs_box)
	for row in TABS:
		var id: String = row[0]
		var b := Button.new()
		b.name = "Tab_%s" % id
		b.toggle_mode = true
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("focus", SheetChrome.box(Color(0, 0, 0, 0), UiTokens.GOLD, 1))
		b.pressed.connect(func () -> void: select_tab(id))
		var col := VBoxContainer.new()
		col.name = "Col"
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := SheetChrome.icon_rect(row[3], 48.0)
		ic.name = "Icon"
		col.add_child(ic)
		var l := SheetChrome.label(str(row[1]), 22, UiTokens.TEXT)
		l.name = "Label"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		b.add_child(col)
		var mark := SheetChrome.Brackets.new()
		mark.name = "Brackets"
		b.add_child(mark)
		_tab_marks[id] = mark
		_tab_buttons[id] = b
		_tabs_box.add_child(b)

	_card = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_card.name = "Card"
	body.add_child(_card)
	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 0)
	_card.add_child(card_v)
	_pad = MarginContainer.new()
	_pad.name = "Pad"
	_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_v.add_child(_pad)
	_main = HBoxContainer.new()
	_main.name = "Main"
	_pad.add_child(_main)
	_left = VBoxContainer.new()
	_left.name = "Left"
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_child(_left)
	_right = VBoxContainer.new()
	_right.name = "Right"
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_child(_right)

	_headline = SheetChrome.label("", 40, UiTokens.GOLD)
	_headline.name = "Headline"
	_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left.add_child(_headline)
	_body = SheetChrome.label("", 20, UiTokens.TEXT)
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left.add_child(_body)
	# ASSUMPTION: the flavour line is the canvas's; no lore source names one.
	_quote = SheetChrome.label("\"Mark the ground you mean to keep.\"", 18, UiTokens.MUTED, false, true)
	_quote.name = "Quote"
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left.add_child(_quote)
	_grid_title = SheetChrome.label("", 28, UiTokens.GOLD)
	_grid_title.name = "GridTitle"
	_grid_title.clip_text = true
	_left.add_child(_grid_title)
	_grid = _PlotGrid.new()
	_grid.name = "PlotGrid"
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_grid.picked.connect(_on_grid_picked)
	_left.add_child(_grid)
	_legend = HBoxContainer.new()
	_legend.name = "Legend"
	_legend.add_theme_constant_override("separation", 10)
	_left.add_child(_legend)
	for pair in [["Domain", 0], ["Can expand", 1], ["Water", 2], ["Camp", 3]]:
		var sw := _Swatch.new()
		sw.kind = int(pair[1])
		_legend.add_child(sw)
		_legend.add_child(SheetChrome.label(str(pair[0]), 16, UiTokens.TEXT))
	_declare = SheetChrome.gold_button("Declare Domain")
	_declare.name = "Declare"
	_declare.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_declare.pressed.connect(_on_declare)
	_left.add_child(_declare)
	_msg = SheetChrome.label("", 16, UiTokens.GOLD)
	_msg.name = "Message"
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_left.add_child(_msg)

	_art = _IslandArt.new()
	_art.name = "IslandArt"
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_child(_art)
	_stats = RichTextLabel.new()
	_stats.name = "Stats"
	_stats.bbcode_enabled = true
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_theme_font_override("normal_font", UiTokens.ui_face())
	_right.add_child(_stats)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 0)
	_right.add_child(_rows)
	for key in ["Upkeep", "Grid", "Next rank", "Rank up via"]:
		var r := HBoxContainer.new()
		r.name = "Row_%s" % key.replace(" ", "")
		var k := SheetChrome.label(key, 20, UiTokens.MUTED.lightened(0.15))
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(k)
		if key == "Rank up via":
			_center = SheetChrome.flat_button("Communications Center →")
			_center.name = "Center"
			_center.add_theme_color_override("font_color", UiTokens.GOLD)
			_center.pressed.connect(_on_center)
			r.add_child(_center)
		else:
			var v := SheetChrome.label("", 20, UiTokens.TEXT)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.add_child(v)
			_row_labels[key] = v
		_rows.add_child(r)
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.08)
		line.custom_minimum_size.y = 1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(line)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 12)
	_right.add_child(_actions)
	_expand = SheetChrome.gold_button("Expand")
	_expand.name = "Expand"
	_expand.pressed.connect(_on_expand)
	_build_here = SheetChrome.ghost_button("Build here")
	_build_here.name = "BuildHere"
	_build_here.pressed.connect(_on_build_here)
	# UNCLAIM: "Release plot" gives up ONE picked plot (the grid tap picks it); the confirm states the
	# consequence and only its own RELEASE PLOT does it. The old whole-Domain wipe is gone.
	_release = SheetChrome.ghost_button("Release plot", true)
	_release.name = "Release"
	_release.pressed.connect(_on_release)
	for b in [_expand, _build_here, _release]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_actions.add_child(b)

	_foot_band = PanelContainer.new()
	_foot_band.name = "FooterBand"
	_foot_band.add_theme_stylebox_override("panel", SheetChrome.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.06), 0))
	card_v.add_child(_foot_band)
	var foot_row := HBoxContainer.new()
	foot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	foot_row.add_theme_constant_override("separation", 10)
	_foot_band.add_child(foot_row)
	var warn := SheetChrome.icon_rect(&"notice", 22.0, UiTokens.GOLD)
	warn.name = "WarnIcon"
	warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot_row.add_child(warn)
	_footer = SheetChrome.label("", 18, UiTokens.TEXT)
	_footer.name = "Footer"
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot_row.add_child(_footer)

	# The preview card: the sheet steps aside so the ground grid stays readable.
	_pv_card = SheetChrome.panel(Color(UiTokens.HEADER, 0.94))
	_pv_card.name = "PreviewCard"
	_pv_card.visible = false
	add_child(_pv_card)
	var pv_pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pv_pad.add_theme_constant_override("margin_" + s, 16)
	_pv_card.add_child(pv_pad)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pv_pad.add_child(pv)
	_pv_title = SheetChrome.label("Pick plots", 26, UiTokens.GOLD)
	pv.add_child(_pv_title)
	_note = SheetChrome.label("", 18, UiTokens.TEXT)
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(_note)
	var pv_row := HBoxContainer.new()
	pv_row.add_theme_constant_override("separation", 12)
	pv.add_child(pv_row)
	_confirm = SheetChrome.gold_button("Confirm")
	_confirm.name = "Confirm"
	_confirm.pressed.connect(_on_confirm)
	_cancel = SheetChrome.ghost_button("Cancel")
	_cancel.name = "Cancel"
	_cancel.pressed.connect(_on_cancel)
	for b in [_confirm, _cancel]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(b as Button).custom_minimum_size.y = 64
		(b as Button).add_theme_font_size_override("font_size", 20)
		pv_row.add_child(b)

# ---------------------------------------------------------------- open / close / tabs

func open(p: Player) -> void:
	player = p
	rt = World.runtime
	visible = true
	if rt != null:
		IslandClaims.sync_cap(rt)
	tab = "tamed_island"
	_previewing = false
	_release_mode = false
	_release_cell = IslandClaims.NO_CELL
	_release_building = ""
	_last_reason = ""
	_picked = 0
	_shown_rank = DomainRules.pioneer_rank()
	_shown_cap = int(rt.call("claim_cap")) if rt != null else DomainRules.cap()
	_refresh()
	relayout()
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
	if _release_mode:
		_end_release()
	_previewing = false
	if center_ui != null and is_instance_valid(center_ui):
		center_ui.close()
	visible = false

func is_open() -> bool:
	return visible

func select_tab(id: String) -> void:
	tab = id
	_last_reason = ""
	_refresh()
	relayout()

func is_previewing() -> bool:
	return _previewing

## True while the declared view (plot grid) shows.
func showing_plots() -> bool:
	return _grid.visible

# ---------------------------------------------------------------- content

func _refresh() -> void:
	for id in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		var on: bool = str(id) == tab
		b.set_pressed_no_signal(on)
		var locked: bool = LOCKED_TABS.has(str(id))
		var sb := SheetChrome.box(UiTokens.GOLD_DIM if on else Color(0.05, 0.055, 0.06, 0.85), Color(1, 1, 1, 0.06), 1)
		for s in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, sb)
		var ink := UiTokens.GOLD if on else (UiTokens.MUTED if locked else UiTokens.TEXT)
		(b.find_child("Label", true, false) as Label).add_theme_color_override("font_color", ink)
		(b.find_child("Icon", true, false) as TextureRect).modulate = ink
		(_tab_marks[id] as Control).visible = on
	rt = World.runtime
	var own: bool = rt != null and IslandClaims.has_domain(rt)
	var home: bool = World.is_home()
	var tamed := tab == "tamed_island"
	var plots := tamed and own
	_set_mode(plots)
	_footer.text = (RULE_TEXT if tamed else str(PHASE_NOTE.get(tab, ["", ""])[1]))
	if not tamed:
		var note: Array = PHASE_NOTE.get(tab, ["", ""])
		_headline.text = str(note[0])
		_body.text = "This territory type is a later phase of the Domain system (spec 29). The Tamed Island tab is the one that works today."
		_quote.visible = false
		_declare.visible = false
		_art.visible = false
		_msg.text = ""
		return
	if not plots:
		_headline.text = "You can declare a Domain on your Tamed Island." if home else "You can declare a Domain on this island."
		_body.text = "Declare a Domain to lay claim to part of your island. Pick plots next to your camp; your Domain then grows from them."
		if not home:
			_body.text += " Land you claim on a visited island is not your Tamed Island domain."
		_declare.disabled = rt == null or _previewing
		_msg.text = _last_reason
		return
	var used: int = rt.call("claim_used")
	var cap: int = rt.call("claim_cap")
	var rank: int = DomainRules.pioneer_rank()
	_grid_title.text = "%s · your Domain" % _island_name()
	_stats.text = "[font_size=%d]Plots [color=#%s]%d[/color] / %d[/font_size]      Pioneer rank %d" % [_stats_px(), UiTokens.GOLD.to_html(false), used, cap, rank]
	(_row_labels["Upkeep"] as Label).text = "None on a Tamed Island" if home else "Not your Tamed Island"
	(_row_labels["Grid"] as Label).text = "%d x %d tiles a plot" % [DomainRules.cell_tiles(), DomainRules.cell_tiles()]
	var next: Array = DomainRules.next_milestone(rank)
	var nl := _row_labels["Next rank"] as Label
	if next.size() >= 2 and int(next[0]) > 0:
		nl.text = "%d plots at rank %d" % [int(next[1]), int(next[0])]
		nl.add_theme_color_override("font_color", UiTokens.GOLD)
	else:
		nl.text = "Every documented step done"
		nl.add_theme_color_override("font_color", UiTokens.TEXT)
	_center.disabled = not home
	_expand.disabled = _previewing
	var picked_hint := "Pick a gold plot to release, then Release plot." if _release_cell == IslandClaims.NO_CELL else "Release plot: %s picked." % str(_release_cell)
	_msg.text = _last_reason if _last_reason != "" else ("Claim limit reached: raise your Pioneer rank to claim more." if used >= cap else picked_hint)
	_grid.rt = rt
	_grid.marked = _release_cell
	_grid.queue_redraw()

func _set_mode(plots: bool) -> void:
	_body.visible = not plots
	_headline.visible = not plots
	_quote.visible = not plots
	_grid_title.visible = plots
	_grid.visible = plots
	_legend.visible = plots
	_art.visible = not plots
	_stats.visible = plots
	_rows.visible = plots
	_actions.visible = plots
	_declare.visible = not plots

func _stats_px() -> int:
	return 22 if UiTokens.is_compact(get_viewport_rect().size) else 36

func _island_name() -> String:
	if rt == null:
		return "No island"
	var def: Dictionary = World.island_def
	var label_text := str(def.get("name", World.island_id)).replace("_", " ")
	return label_text.capitalize() if label_text != "" else "Uncharted island"

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
	_pv_title.text = "Declare: pick plots" if mode == "declare" else "Expand: pick plots"
	_last_reason = ""
	_picked = 0
	_refresh()
	_update_footer()
	relayout()

func _on_selection_changed(count: int) -> void:
	_picked = count
	_last_reason = ""
	_update_footer()

func _on_cell_refused(reason: String) -> void:
	_last_reason = preview.reason_text(reason) if preview != null else reason
	_update_footer()

func _on_confirm() -> void:
	if _release_mode:
		_on_release_confirm()
		return
	if preview == null or not _previewing:
		return
	var out: Dictionary = preview.commit()
	if not bool(out["ok"]):
		_last_reason = IslandClaims.reason_text(str(out["reason"]))
		_update_footer()
		return
	_last_reason = ""
	_previewing = false
	_end_preview()
	_refresh()
	relayout()

func _on_cancel() -> void:
	if _release_mode:
		_end_release()
		_refresh()
		relayout()
		return
	_previewing = false
	_end_preview()
	_last_reason = ""
	_refresh()
	relayout()

func _end_preview() -> void:
	if preview != null and is_instance_valid(preview):
		preview.finish()
	preview = null

# ---------------------------------------------------------------- UNCLAIM (release one plot)

## UNCLAIM: the Release action. With a plot picked in the grid it asks first (the preview card states
## the consequence and Confirm / Keep answer it); with nothing picked it names that a plot must be
## picked. A release gives up ONE plot; it never wipes the Domain (that is not a rule the game has).
func _on_release() -> void:
	if rt == null:
		return
	if _release_cell == IslandClaims.NO_CELL:
		_last_reason = "Pick one of your gold plots in the grid first, then Release."
		_refresh()
		relayout()
		return
	_start_release(_release_cell)

## Pick a plot of the Domain in the grid: the release action now means that plot. A tap outside your
## plots (or on the camp's own landing plot) says why it cannot be released.
func _on_grid_picked(cell: Vector2i) -> void:
	if rt == null:
		return
	var why := IslandClaims.release_reason(rt, cell)
	if why != "":
		_last_reason = "Can't release that plot: %s." % IslandClaims.reason_text(why)
		_release_cell = IslandClaims.NO_CELL
		_refresh()
		relayout()
		return
	_release_cell = cell
	_last_reason = ""
	_refresh()
	relayout()

func _start_release(cell: Vector2i) -> void:
	_previewing = true
	_release_mode = true
	_release_cell = cell
	_last_reason = ""
	_release_building = IslandClaims.building_on(rt, cell) if rt != null else ""
	_pv_title.text = "Release plot"
	_confirm.text = "Release plot"
	_cancel.text = "Keep"
	_refresh()
	_update_footer()
	relayout()
	UiTokens.focus_first([_cancel, _confirm])

func _end_release() -> void:
	_previewing = false
	_release_mode = false
	_release_cell = IslandClaims.NO_CELL
	_release_building = ""
	_last_reason = ""
	_pv_title.text = "Pick plots"
	_confirm.text = "Confirm"
	_cancel.text = "Cancel"

func _on_release_confirm() -> void:
	if rt == null or _release_cell == IslandClaims.NO_CELL:
		return
	var out: Dictionary = IslandClaims.release_cell(rt, _release_cell)
	if not bool(out["ok"]):
		_last_reason = "Can't release that plot: %s." % IslandClaims.reason_text(str(out["reason"]))
		_update_footer()
		return
	_end_release()
	_refresh()
	relayout()

## "Build here": the Build sheet over the world, this screen closed.
func _on_build_here() -> void:
	close()
	if player != null:
		var b := BuildUI.ensure(player)
		if b != null:
			b.open()

func _on_center() -> void:
	if center_ui == null or not is_instance_valid(center_ui):
		center_ui = CommCenterUI.new()
		add_child(center_ui)
		center_ui.closed.connect(_on_center_closed)
	# The contribution panel is a modal over this sheet: the sheet's parts hide while it is up, and
	# one Close brings the Domain screen back with its capacity already updated. The screen node
	# itself stays visible: hiding it would zero the panel's layout.
	_show_chrome(false)
	center_ui.open(player)

func _on_center_closed() -> void:
	if not visible:
		return
	_show_chrome(true)
	_refresh()
	relayout()

func _show_chrome(on: bool) -> void:
	backdrop.visible = on
	header.visible = on
	body.visible = on

func _update_footer() -> void:
	if not _previewing:
		_msg.text = _last_reason
		return
	var cap: int = rt.call("claim_cap") if rt != null else DomainRules.cap()
	var used: int = rt.call("claim_used") if rt != null else 0
	if _release_mode:
		# UNCLAIM: the same card states the consequence of giving ONE plot up (ClaimPanel's words, so
		# both entry points say the same thing), and Confirm is RELEASE PLOT, not a stake.
		_note.text = ClaimPanel.describe_release(used, _release_cell, str(IslandClaims.release_reason(rt, _release_cell)) if rt != null else "not_owned", _release_building)
		_confirm.disabled = rt == null or _release_cell == IslandClaims.NO_CELL or IslandClaims.release_reason(rt, _release_cell) != ""
		return
	# The count comes from the preview itself: a signalled count went stale once (a shot said
	# "Selected 0" with three cells picked, i.e. the label lagged the grid).
	if preview != null and is_instance_valid(preview):
		_picked = preview.selected_cells().size()
	var head := "Selected %d · holds %d / %d" % [_picked, used, cap]
	_note.text = "%s\n%s" % [head, "Tap the glowing cells next to your land." if _last_reason == "" else _last_reason]
	_confirm.disabled = _picked == 0

# ---------------------------------------------------------------- layout

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var center_up: bool = center_ui != null and is_instance_valid(center_ui) and center_ui.is_open()
	_show_chrome(not _previewing and not center_up)
	_pv_card.visible = _previewing
	if _previewing:
		# Preview: the sheet steps aside to a narrow card at the bottom left, the ground grid visible.
		var w := minf(420.0, maxf(300.0, view.x * 0.36))
		var h := 230.0 if compact else 280.0
		_pv_card.position = Vector2(12.0, view.y - h - 12.0)
		_pv_card.size = Vector2(w, h)
		_pv_title.add_theme_font_size_override("font_size", 20 if compact else 26)
		_note.add_theme_font_size_override("font_size", 14 if compact else 18)
		return
	var tab_w := 116.0 if compact else 230.0
	var gap := 8.0 if compact else 20.0
	_tabs_box.position = rect.position
	_tabs_box.size = Vector2(tab_w, rect.size.y)
	for row in TABS:
		var b: Button = _tab_buttons[str(row[0])]
		b.custom_minimum_size = Vector2(tab_w, 64.0)
		var l := b.find_child("Label", true, false) as Label
		l.add_theme_font_size_override("font_size", 15 if compact else 22)
		l.text = str(row[2] if compact else row[1])
		(b.find_child("Icon", true, false) as Control).custom_minimum_size = Vector2.ONE * (28.0 if compact else 48.0)
		(_tab_marks[str(row[0])] as Control).queue_redraw()
	_card.position = Vector2(rect.position.x + tab_w + gap, rect.position.y)
	_card.size = Vector2(rect.size.x - tab_w - gap, rect.size.y)
	var px := 14 if compact else 60
	_pad.add_theme_constant_override("margin_left", px)
	_pad.add_theme_constant_override("margin_right", 14 if compact else 40)
	_pad.add_theme_constant_override("margin_top", 8 if compact else 30)
	_pad.add_theme_constant_override("margin_bottom", 8 if compact else 20)
	_main.add_theme_constant_override("separation", 16 if compact else 40)
	_headline.add_theme_font_size_override("font_size", 22 if compact else 40)
	_body.add_theme_font_size_override("font_size", 14 if compact else 21)
	_quote.add_theme_font_size_override("font_size", 13 if compact else 19)
	_grid_title.add_theme_font_size_override("font_size", 18 if compact else 30)
	_msg.add_theme_font_size_override("font_size", 13 if compact else 16)
	_footer.add_theme_font_size_override("font_size", 13 if compact else 19)
	_foot_band.custom_minimum_size.y = 34.0 if compact else 64.0
	_left.add_theme_constant_override("separation", 6 if compact else 18)
	_right.add_theme_constant_override("separation", 4 if compact else 18)
	_declare.custom_minimum_size = Vector2(240.0 if compact else 420.0, 64.0 if compact else 80.0)
	_declare.add_theme_font_size_override("font_size", 20 if compact else 30)
	for b in [_expand, _build_here, _release]:
		(b as Button).custom_minimum_size = Vector2(0.0, 64.0 if compact else 72.0)
		(b as Button).add_theme_font_size_override("font_size", 16 if compact else 24)
	_center.add_theme_font_size_override("font_size", 14 if compact else 20)
	_center.custom_minimum_size = Vector2(0.0, 64.0)
	for r in _rows.get_children():
		for k in r.get_children():
			if k is Label:
				(k as Label).add_theme_font_size_override("font_size", 14 if compact else 20)
				(k as Label).custom_minimum_size.y = 0.0 if compact else 56.0
	for k in _legend.get_children():
		if k is Label:
			(k as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
	_stats.add_theme_font_size_override("normal_font_size", 15 if compact else 26)
	# The plot grid's cell: what the card height allows after the title, legend and footer band.
	# A landscape phone drops the rule band under the grid: the grid needs the height more.
	_foot_band.visible = not (compact and _grid.visible)
	var foot_h := _foot_band.custom_minimum_size.y if _foot_band.visible else 0.0
	var avail_h := _card.size.y - foot_h - (84.0 if compact else 170.0)
	var avail_w := (_card.size.x - float(px) * 2.0) * 0.45
	var n := GRID_RADIUS * 2 + 1
	_grid.cell = clampf(floorf(minf(avail_h / float(n), avail_w / float(n))), 20.0, 68.0)
	_grid.custom_minimum_size = Vector2.ONE * _grid.cell * float(n)
	_right.size_flags_stretch_ratio = 1.0 if _grid.visible else 0.8
	_art.custom_minimum_size = Vector2(0.0, 120.0 if compact else 260.0)

# ---------------------------------------------------------------- drawn parts

## The 7 x 7 plot grid around the domain (§7 F1 "plot grid after declaring"): Domain cells GOLD,
## cells the domain can grow into outlined GOLD, water/cliff blue, the camp's own land GOLD at half
## alpha, other land green. Classified by IslandClaims, the same model the ground preview draws.
class _PlotGrid extends Control:
	## UNCLAIM: a tap on one of your gold plots picks it for release (the screen asks with the
	## consequence before anything is given up). A tap elsewhere is not a pick and says nothing.
	signal picked(cell: Vector2i)
	var rt: IslandRuntime
	var cell := 60.0
	var marked := IslandClaims.NO_CELL  ## the plot the screen's Release would give up (drawn white)
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func cell_at(local: Vector2) -> Vector2i:
		var c0 := centre_cell()
		var r := DomainScreen.GRID_RADIUS
		var gx := int(floor(local.x / cell))
		var gy := int(floor(local.y / cell))
		if gx < 0 or gy < 0 or gx > r * 2 or gy > r * 2:
			return IslandClaims.NO_CELL
		return c0 + Vector2i(gx - r, gy - r)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				tap_at(mb.position)
				accept_event()
		elif event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				tap_at(t.position)
				accept_event()
	## A tap at `local`: one of your own Domain plots is picked (the screen's Release gives it up);
	## anything else is ignored here (the grid still shows it as a state). Public for the test.
	func tap_at(local: Vector2) -> void:
		var c := cell_at(local)
		if c == IslandClaims.NO_CELL:
			return
		if states().get(c, -1) == 0:
			picked.emit(c)
	func centre_cell() -> Vector2i:
		var own: Dictionary = IslandClaims.owned_cells(rt)
		if own.is_empty():
			return Vector2i.ZERO
		var sum := Vector2.ZERO
		for c: Vector2i in own.keys():
			sum += Vector2(c)
		sum /= float(own.size())
		return Vector2i(roundi(sum.x), roundi(sum.y))
	## Vector2i -> 0 domain, 1 can expand, 2 water, 3 camp, 4 land (what the grid draws; tests read it).
	func states() -> Dictionary:
		var out := {}
		if rt == null or not is_instance_valid(rt):
			return out
		var c0 := centre_cell()
		var own: Dictionary = IslandClaims.owned_cells(rt)
		var r := DomainScreen.GRID_RADIUS
		for y in range(c0.y - r, c0.y + r + 1):
			for x in range(c0.x - r, c0.x + r + 1):
				var c := Vector2i(x, y)
				if own.has(c):
					out[c] = 0
					continue
				var info: Dictionary = IslandClaims.classify(rt, c)
				match str(info["state"]):
					"eligible":
						out[c] = 1
					"claimed":
						out[c] = 3
					_:
						var why := str(info["reason"])
						out[c] = 2 if why == "terrain" or why == "outside_the_island" else 4
		return out
	func _draw() -> void:
		var st := states()
		if st.is_empty():
			return
		var c0 := centre_cell()
		var r := DomainScreen.GRID_RADIUS
		for c: Vector2i in st.keys():
			var p := Vector2(float(c.x - c0.x + r), float(c.y - c0.y + r)) * cell
			var box := Rect2(p + Vector2.ONE, Vector2.ONE * (cell - 2.0))
			draw_rect(box, DomainScreen.swatch_color(int(st[c])))
			if int(st[c]) == 1:
				draw_rect(box.grow(-1.0), UiTokens.GOLD, false, 2.0)
			elif c == marked:
				draw_rect(box.grow(-2.0), UiTokens.TEXT, false, 3.0)
			else:
				draw_rect(box, Color(1, 1, 1, 0.06), false, 1.0)

static func swatch_color(kind: int) -> Color:
	match kind:
		0:
			return UiTokens.GOLD
		2:
			return Color(0.17, 0.29, 0.45)
		3:
			return Color(UiTokens.GOLD, 0.45)
		_:
			return Color(0.20, 0.28, 0.18)

class _Swatch extends Control:
	var kind := 0
	func _ready() -> void:
		custom_minimum_size = Vector2(16, 16)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		if kind == 1:
			UiTokens.draw_brackets(self, r, UiTokens.GOLD, 5.0, 2.0)
		else:
			draw_rect(r, DomainScreen.swatch_color(kind))

## The declare panel's island: a soft green landmass with a dashed GOLD plot and a flag.
class _IslandArt extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _blob(c: Vector2, r: Vector2, wob: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 64:
			var a := TAU * float(i) / 64.0
			var k := 1.0 + wob * sin(a * 3.0 + 0.6) + wob * 0.6 * sin(a * 5.0 + 1.9)
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
		return pts
	func _draw() -> void:
		var c := size * 0.5
		var r := Vector2(minf(size.x * 0.46, size.y * 0.58), minf(size.y * 0.44, size.x * 0.40))
		if r.x < 10.0 or r.y < 10.0:
			return
		draw_colored_polygon(_blob(c, r, 0.05), Color(0.20, 0.29, 0.17))
		draw_colored_polygon(_blob(c, r * 0.86, 0.06), Color(0.33, 0.45, 0.24))
		var s := minf(r.x, r.y) * 0.55
		var plot := Rect2(c + Vector2(r.x * 0.12 - s * 0.5, -s * 0.5), Vector2(s, s * 0.85))
		draw_rect(plot, Color(UiTokens.GOLD, 0.12))
		var corners := [plot.position, Vector2(plot.end.x, plot.position.y), plot.end, Vector2(plot.position.x, plot.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(UiTokens.GOLD, 0.75), 2.0, 8.0)
		var base := plot.get_center() + Vector2(0, s * 0.18)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.13, 0), base + Vector2(s * 0.13, 0), base + Vector2(0, -s * 0.26)]), Color(0.62, 0.60, 0.52))
		var pole := base + Vector2(0, -s * 0.26)
		draw_line(pole, pole + Vector2(0, -s * 0.22), UiTokens.GOLD, 2.0)
		draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -s * 0.22), pole + Vector2(s * 0.16, -s * 0.18), pole + Vector2(0, -s * 0.12)]), Color(UiTokens.GOLD, 0.8))
