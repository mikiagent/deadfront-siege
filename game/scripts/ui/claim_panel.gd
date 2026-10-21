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
const TITLE := "Claim this land?"

var _body: Label
var _confirm: Button
var _cancel: Button

## `plots` held on this island now, `tile` where the survivor stands, `rect` the plot the press would
## stake, `why` "" when that plot expands the land held (IslandRuntime.claim_expand_reason), `stake`
## whether the press spends a claim stake. Two lines: what stays, what the press is (a no-op when the
## plot would not expand).
static func describe(plots: Array, tile: Vector2i, rect: Rect2i, why: String, stake: bool) -> String:
	var kept := "You hold %d plot%s here; this press takes none of %s away." % [plots.size(), "" if plots.size() == 1 else "s", "it" if plots.size() == 1 else "them"]
	var pay := " It spends a claim stake." if stake else ""
	if why != "":
		return "%s\nNo plot here: %s. Nothing moved, nothing spent." % [kept, why]
	return "%s\nCLAIM expands your land by a 14x14 plot at (%d, %d), sharing an edge with what you hold.%s" % [kept, tile.x, tile.y, pay]

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

## Room for the panel on this canvas: over the survivor (centre is empty at every size), between the
## vitals/quest band and the bottom rail, and never on the minimap column or the XP line.
func fit(view: Vector2, inset: Vector4) -> void:
	var w := minf(SIZE.x, view.x - 32.0 - inset.w - inset.x)
	var h := minf(SIZE.y, view.y - 24.0 - inset.z)
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	var x := clampf(view.x * 0.5 - w * 0.5, 16.0 + inset.w, maxf(16.0 + inset.w, view.x - 16.0 - inset.x - w))
	var y := clampf(view.y * 0.5 - h * 0.5, 120.0 + inset.z, maxf(120.0 + inset.z, view.y - 96.0 - inset.y - h))
	position = Vector2(x, y)
