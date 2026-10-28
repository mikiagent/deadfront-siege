class_name ClaimPanel
extends PanelContainer
## The CLAIM confirm (playtest 2026-10-21: a second CLAIM press staked a 14x14 anywhere, 3 m from the
## first, with no word about it). PRD 13.1 makes a second claim an expansion - one same-size plot,
## orthogonal only - so the CLAIM press with land already held asks first, in this panel: what you hold
## stays, and either the plot at your feet expands it or it is refused with the reason (not adjacent,
## overlaps your own, not dry land, another survivor's). Only the panel's EXPAND stakes; Close, a
## second press or walking off cancels. Plots only ever add, so a press can orphan no building.
## UNCLAIM (owner: "Also need a way to unclaim land too"): the same panel in release mode asks before
## a plot is GIVEN UP - pressing CLAIM while standing on your own plot, or a plot picked in the
## Domain screen's grid, opens open_release(); only its RELEASE PLOT gives the plot up, and its text
## states the consequence (what stops being yours, what happens to anything built there).
## The panel lives in the HUD (hunt_hud.gd), over the empty centre, clear of the rail, map and XP line.

signal answered(confirmed: bool)
## UNCLAIM: the survivor pressed RELEASE PLOT on their own plot (the plot is already released).
signal released(cell: Vector2i)
const SIZE := Vector2(500.0, 270.0)
const PHONE_SIZE := Vector2(272.0, 166.0)  ## a 390 px canvas: narrow enough to stand left of the map column
const TITLE := "Claim this land?"
const RELEASE_TITLE := "Release this plot?"

var _body: Label
var _confirm: Button
var _cancel: Button
var _row: HBoxContainer
var _title: Label
var _release_rt: IslandRuntime
var _release_cell := IslandClaims.NO_CELL  ## UNCLAIM: the cell the panel would give up, NO_CELL in claim mode
var _release_reason := ""
var _release_building := ""
var _release_used := 0

## UNCLAIM: the consequence of giving up `cell`, in the panel's words. `why` is the refusal ("" when
## the plot can be released), `building` names what stands on it. Two lines: what the release does to
## the land and its buildings, and that pressing RELEASE PLOT is what does it.
static func describe_release(used: int, cell: Vector2i, why: String, building: String) -> String:
	var n := IslandClaims.cell_tiles()
	if why != "":
		return "You hold %d plot%s.\nNo release here: %s. Nothing changes." % [used, "" if used == 1 else "s", IslandClaims.reason_text(why)]
	var left := maxi(0, used - 1)
	var on_it := "Nothing is built on it." if building == "" else "A %s stands on it, so it cannot be released until it is packed up." % building
	return "You hold %d plot%s; %d stay%s yours. Giving up the %dx%d plot at (%d, %d) is permanent: it stops being yours, you cannot build or manage anything there, and anyone (you included) can claim it again later. Grass and props cleared by the claim do not grow back on their own, and no claim stake is refunded. %s\nOnly RELEASE PLOT gives it up; KEEP closes this." % [
		used, "" if used == 1 else "s", left, "" if left == 1 else "s", n, n, cell.x, cell.y, on_it]

## `plots` held on this island now, `tile` where the survivor stands, `rect` the plot the press would
## stake, `why` "" when that plot expands the land held (IslandRuntime.claim_expand_reason), `stake`
## whether the press spends a claim stake. Two lines: what stays, what the press is (a no-op when the
## plot would not expand).
static func describe(plots: Array, tile: Vector2i, rect: Rect2i, why: String, stake: bool) -> String:
	# CLAIMS2 / spec 29: one cell is cell_tiles() x cell_tiles() world tiles (4x4 by default) on the
	# island's grid, not a 14x14 plot centred on the survivor.
	var n := plots.size()
	var n_tiles := rect.size.x if rect.has_area() else DomainRules.cell_tiles()
	var kept := "You hold %d cell%s; pressing CLAIM moves or loses none of %s." % [n, "" if n == 1 else "s", "it" if n == 1 else "them"]
	var pay := " Spends a claim stake." if stake else ""
	if why != "":
		return "%s\nNo expansion here: %s. Nothing moves, nothing is spent." % [kept, why]
	var centre := rect.get_center() if rect.has_area() else tile
	return "%s\nEXPAND adds a %dx%d cell at (%d, %d), sharing an edge with your land.%s" % [kept, n_tiles, n_tiles, centre.x, centre.y, pay]

## Tiles of `rect` already inside one of `plots`.
static func _inner_tiles(plots: Array, rect: Rect2i) -> int:
	var n := 0
	for t in rect.size.x * rect.size.y:
		var tile := rect.position + Vector2i(t % rect.size.x, t / rect.size.x)
		for p in plots:
			if (p as Rect2i).has_point(tile):
				n += 1
				break
	return n

func open(plots: Array, tile: Vector2i, rect: Rect2i, why: String, stake: bool) -> void:
	_release_cell = IslandClaims.NO_CELL
	_release_reason = ""
	_release_building = ""
	_release_used = plots.size()
	_shell(TITLE, describe(plots, tile, rect, why, stake))
	_cancel = _button("Cancel", false)
	_cancel.name = "ClaimCancel"
	_cancel.pressed.connect(func () -> void: answered.emit(false))
	(_row as HBoxContainer).add_child(_cancel)
	var ok_btn := _button("Expand", true)  # greyed when the plot would not expand (the body says why)
	ok_btn.name = "ClaimConfirm"
	ok_btn.disabled = why != ""
	ok_btn.size_flags_stretch_ratio = 1.6
	ok_btn.pressed.connect(func () -> void: answered.emit(true))
	(_row as HBoxContainer).add_child(ok_btn)
	_confirm = ok_btn
	visible = true
	UiTokens.focus_first([_cancel, _confirm])

## UNCLAIM: the release confirm. `rt` is the island whose plot `cell` would be given up; `why` is
## IslandClaims.release_reason ("" when it can go) and `building` names what stands on it. Nothing
## changes until RELEASE PLOT is pressed; KEEP (or walking away) cancels. The panel is the confirm
## step for BOTH entry points (the HUD's CLAIM press on your own plot and the Domain screen's grid),
## so no path can drop a plot without it.
func open_release(rt: IslandRuntime, used: int, cell: Vector2i, why: String, building: String) -> void:
	_release_rt = rt
	_release_cell = cell
	_release_reason = why
	_release_building = building
	_release_used = used
	_shell(RELEASE_TITLE, describe_release(used, cell, why, building))
	_cancel = _button("Keep", false)
	_cancel.name = "ClaimCancel"
	_cancel.pressed.connect(func () -> void: answered.emit(false))
	(_row as HBoxContainer).add_child(_cancel)
	var ok_btn := _button("Release plot", true)
	ok_btn.name = "ClaimConfirm"
	ok_btn.disabled = why != ""
	ok_btn.size_flags_stretch_ratio = 1.6
	ok_btn.pressed.connect(_on_release_pressed)
	(_row as HBoxContainer).add_child(ok_btn)
	_confirm = ok_btn
	visible = true
	UiTokens.focus_first([_cancel, _confirm])

## The confirm: one cell leaves the domain, through the one write path (IslandClaims.release_cell).
## A plot that became illegal while the panel was open (a build finished on it, the domain changed)
## is refused here and the panel says why; nothing is dropped.
func _on_release_pressed() -> void:
	if _release_cell == IslandClaims.NO_CELL or _release_rt == null or not is_instance_valid(_release_rt):
		return
	var out: Dictionary = IslandClaims.release_cell(_release_rt, _release_cell)
	if not bool(out["ok"]):
		_release_reason = str(out["reason"])
		if _body != null:
			_body.text = describe_release(_release_used, _release_cell, _release_reason, _release_building)
		if _confirm != null:
			_confirm.disabled = true
		return
	var cell := _release_cell
	_release_cell = IslandClaims.NO_CELL
	released.emit(cell)
	answered.emit(false)  # closes the panel (no claim was staked)

func release_cell() -> Vector2i:
	return _release_cell

## The shared chrome: parchment header with `title`, the body label `text`, and an empty button row.
func _shell(title_text: String, text: String) -> void:
	# B4 look (ui-redesign-spec §7 B4, §8): parchment header, body on the HUD fill, Cancel outlined and
	# the action a GOLD button with CTA ink.
	name = "ClaimPanel"
	custom_minimum_size = SIZE
	size = SIZE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.HUD_FILL, 0.96)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = UiTokens.PARCHMENT_TOP
	hs.border_color = UiTokens.PARCHMENT_BOTTOM
	hs.border_width_bottom = 4
	hs.content_margin_left = 20
	hs.content_margin_right = 20
	hs.content_margin_top = 8 if compact else 14
	hs.content_margin_bottom = 8 if compact else 14
	head.add_theme_stylebox_override("panel", hs)
	box.add_child(head)
	var title := Label.new()
	title.name = "ClaimTitle"
	title.text = title_text
	title.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	title.add_theme_font_size_override("font_size", 18 if compact else UiTokens.HEADER_PX)
	title.add_theme_color_override("font_color", UiTokens.PARCHMENT_INK)
	head.add_child(title)
	_title = title
	var inner := MarginContainer.new()
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 20)
	inner.add_theme_constant_override("margin_top", 10 if compact else 16)
	inner.add_theme_constant_override("margin_bottom", 10 if compact else 16)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10 if compact else 14)
	inner.add_child(col)
	_body = Label.new()
	_body.name = "ClaimBody"
	_body.text = text
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 13 if compact else 16)
	_body.add_theme_color_override("font_color", UiTokens.TEXT)
	_body.add_theme_constant_override("line_spacing", 2)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_row = HBoxContainer.new()
	(_row as HBoxContainer).add_theme_constant_override("separation", 12)
	col.add_child(_row)

func body_text() -> String:
	return _body.text if _body else ""

func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 64.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD if primary else UiTokens.WEIGHT_REGULAR))
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.GOLD if primary else Color(0, 0, 0, 0.35)
	sb.border_color = UiTokens.GOLD if primary else Color(1, 1, 1, 0.55)
	sb.set_border_width_all(0 if primary else 1)
	var down := sb.duplicate() as StyleBoxFlat
	down.bg_color = sb.bg_color.darkened(0.15) if primary else Color(UiTokens.GOLD_DIM, 0.3)
	var off := sb.duplicate() as StyleBoxFlat
	off.bg_color = Color(1, 1, 1, 0.06) if primary else sb.bg_color
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("disabled", off)
	var ink := UiTokens.CTA_INK if primary else UiTokens.TEXT
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, ink)
	b.add_theme_color_override("font_disabled_color", Color(UiTokens.MUTED, 0.6))
	return b

## Room for the panel on this canvas: the strip under the vitals / quest band (top 120 px) and over the
## bottom rail and XP line (bottom 104 px). A 390 px canvas has 166 px between them, so there the panel
## is short and its text wraps to more lines; at 900 px it takes its full height over the empty centre.
func fit(view: Vector2, inset: Vector4) -> void:
	var w := minf(PHONE_SIZE.x if view.y < 500.0 else SIZE.x, view.x - 32.0 - inset.w - inset.x)
	var top := 120.0 + inset.z
	var bottom := view.y - 104.0 - inset.y
	var h := clampf(bottom - top, 120.0, PHONE_SIZE.y if view.y < 500.0 else SIZE.y)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	# Left of the map column (154 px map + 16 px margin + the safe inset) on a phone, where the
	# centred panel covered the minimap; the centre of a desktop canvas is empty.
	var right := view.x - (240.0 if view.y < 500.0 else 16.0) - inset.x
	var x := clampf(view.x * 0.5 - w * 0.5, 16.0 + inset.w, maxf(16.0 + inset.w, right - w))
	# The content can be taller than the strip (a wrapped line on a phone): then the panel ends on the
	# rail's top edge and grows up into the play area, never over the rail's hexes.
	var real := maxf(size.y, get_combined_minimum_size().y)
	var y := minf((top + bottom) * 0.5 - real * 0.5, bottom - real)
	position = Vector2(x, maxf(8.0 + inset.z, y))
