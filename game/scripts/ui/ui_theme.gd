class_name UiTheme
extends RefCounted
## The token Theme (split out of UiTokens, which keeps constants and sizes).

static var _installed := false

## One Theme from these tokens: ink panels, teal selection and a teal focus ring (keyboard and
## controller users can see where they are), 16 px body type.
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	var normal := UiTokens.button_style(false)
	var hover := UiTokens.button_style(false)
	hover.bg_color = hover.bg_color.lightened(0.08)
	hover.border_color = UiTokens.META
	var pressed := UiTokens.button_style(true)
	var disabled := UiTokens.button_style(false)
	disabled.bg_color = Color(0.07, 0.075, 0.085, 0.9)
	disabled.border_color = Color(UiTokens.DIVIDER, 0.3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UiTokens.TEAL
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(UiTokens.RADIUS)
	focus.set_expand_margin_all(2.0)
	for kind in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		t.set_stylebox("pressed", kind, pressed)
		t.set_stylebox("hover_pressed", kind, pressed)
		t.set_stylebox("disabled", kind, disabled)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, UiTokens.TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, Color(UiTokens.META, 0.55))
		t.set_font_size("font_size", kind, 16)
	t.set_color("font_color", "Label", UiTokens.TEXT)
	t.set_font_size("font_size", "Label", 16)
	t.set_stylebox("panel", "PanelContainer", UiTokens.panel_style())
	t.set_stylebox("panel", "Panel", UiTokens.panel_style())
	var field := UiTokens.slot_style(false)
	field.content_margin_left = UiTokens.SPACE
	field.content_margin_right = UiTokens.SPACE
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", UiTokens.TEXT)
	t.set_font_size("font_size", "LineEdit", 16)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)  # visible on ink panels even when the bar is empty
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.TEAL
	fill.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", UiTokens.TYPE_MIN)
	return t

## Merge the token theme into the engine default theme, so every Control picks it up, including
## those under CanvasLayers (a theme on the root Window does not reach them). Idempotent.
static func install() -> void:
	if _installed:
		return
	var base := ThemeDB.get_default_theme()
	if base == null:
		return
	base.merge_with(build())
	_installed = true
	print("[ui] theme installed")
