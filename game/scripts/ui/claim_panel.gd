class_name ClaimPanel
extends PanelContainer
## The CLAIM confirm (playtest 2026-10-21: a second CLAIM press staked a 14x14 anywhere, 3 m from the
## first, with no word about it). PRD 13.1 makes a second claim an expansion - one same-size plot,
## orthogonal only - so the CLAIM press with land already held asks first, in this panel: what you hold
## stays, and either the plot at your feet expands it or it is refused with the reason (not adjacent,
## overlaps your own, not dry land, another survivor's). Only the panel's EXPAND stakes; Close, a
## second press or walking off cancels. Plots only ever add, so a press can orphan no building.
## The panel lives in the HUD (hunt_hud.gd), over the empty centre, clear of the rail, map and XP line.

signal answered(confirmed: bool)
const SIZE := Vector2(340.0, 196.0)
const PHONE_SIZE := Vector2(272.0, 166.0)  ## a 390 px canvas: narrow enough to stand left of the map column
const TITLE := "Claim this land?"

var _body: Label
var _confirm: Button
var _cancel: Button

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
	name = "ClaimPanel"
	custom_minimum_size = SIZE
	size = SIZE
	add_theme_stylebox_override("panel", UiTokens.panel_style(0.97))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.name = "ClaimTitle"
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UiTokens.TEXT)
	box.add_child(title)
	_body = Label.new()
	_body.name = "ClaimBody"
	_body.text = describe(plots, tile, rect, why, stake)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 13)
	_body.add_theme_color_override("font_color", UiTokens.META)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_cancel = _button("Close", false)
	_cancel.name = "ClaimCancel"
	_cancel.pressed.connect(func () -> void: answered.emit(false))
	row.add_child(_cancel)
	var ok_btn := _button("EXPAND" if why == "" else "", true)
	ok_btn.name = "ClaimConfirm"
	ok_btn.disabled = why != ""
	ok_btn.pressed.connect(func () -> void: answered.emit(true))
	row.add_child(ok_btn)
	_confirm = ok_btn
	visible = true
	UiTokens.focus_first([_cancel, _confirm])

func body_text() -> String:
	return _body.text if _body else ""

func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, UiTokens.TARGET_PRIMARY)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	var sb := UiTokens.button_style(primary)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", UiTokens.button_style(not primary))
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
