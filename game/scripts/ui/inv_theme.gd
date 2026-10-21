class_name InvTheme
extends RefCounted
## One source of colour, type and size for the Durango bag family (spec 13 s2-3; design section 3).
## Durango's earthy palette wins over the teal UiTokens inside these screens; the theme is set on the
## family root only, never on the global theme.

const BG := Color("#101714")
## The weathered surface around and between the panels: the references show a lighter, blotchy
## khaki there, which is what makes each dark-bordered panel read as its own compartment.
# ASSUMPTION: spec 13's #101714 "main background" stays the dark of the panel borders and header;
# the backdrop between panels follows the references (newest truth) as a dark khaki.
const BACKDROP := Color("#3B382C")
const HEADER := Color("#080809")
## Spec 13's #39392F warmed toward the reference's brown grid panel (#3A2F2C).
const PANEL := Color("#3A3530")
const PANEL_2 := Color("#26322C")
const CELL_DARK := Color("#0E120F")
const SEPARATOR := Color(0.337, 0.325, 0.29, 0.5) # #56534A at 50 %
const SELECT := Color("#E6BE54")
const PRIMARY := Color("#F2C84C")
const PRIMARY_INK := Color("#1B1A14")
const TAN := Color("#CAAD69")
const TAN_DARK := Color("#8E7A4C")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const TEXT_OFF := Color("#77786F")
const NEW_BG := Color("#176897")
const POSITIVE := Color("#D9B65A")
const RARE := Color("#67B84E")
const DANGER := UiTokens.DANGER
const BUTTON_DARK := Color(0.07, 0.075, 0.065, 0.9)
const BUTTON_EDGE := Color(0.62, 0.61, 0.56, 0.75)
const GRAIN := preload("res://scripts/ui/inv_grain.gdshader")
## The dark, slightly irregular panel border (spec 13 s2).
const FRAME_INK := Color(0.035, 0.03, 0.024, 0.92)
## Safe-area insets every screen of the family lays out inside (x right, y bottom, z top, w left).
## Desktop and headless runs report none, so the labs and tests force a notch through this.
static var forced_insets := Vector4(-1, -1, -1, -1)

static var _theme: Theme
static var _font: FontVariation
static var _grain := {}

## Per-canvas sizes. Desktop (the 1600x900 judge and every taller canvas) and the compact landscape
## phone (shorter than UiTokens.SHORT_MAX) each fit seven square cells beside the inspect panel.
static func metrics(view: Vector2) -> Dictionary:
	var compact := UiTokens.is_compact(view)
	var m := {}
	m.margin = 8.0 if compact else 16.0
	m.gap = 6.0 if compact else 16.0
	m.header_h = 44.0 if compact else roundf(clampf(view.y * 0.089, 72.0, 96.0))
	m.toolbar_h = 48.0 if compact else roundf(clampf(view.y * 0.107, 90.0, 116.0))
	m.inspect_w = roundf(view.x * (0.275 if compact else 0.28))
	var grid_w: float = view.x - m.margin * 2.0 - m.inspect_w - m.gap
	m.columns = 7
	m.cell = floorf(grid_w / 7.0)
	if m.cell < 72.0:
		m.columns = 6
		m.cell = floorf(grid_w / 6.0)
	m.grid_w = m.cell * m.columns
	m.title_font = 22 if compact else 40
	m.cap_font = 20 if compact else 34
	m.lv_font = maxi(UiTokens.TYPE_MIN, roundi(m.cell * 0.125))
	m.new_font = maxi(UiTokens.TYPE_MIN, roundi(m.cell * 0.095))
	m.name_font = 18 if compact else 34
	m.row_font = 14 if compact else 20
	m.row_h = 26.0 if compact else 44.0
	m.section_font = UiTokens.TYPE_MIN if compact else 16
	m.primary_h = 56.0 if compact else 88.0
	m.secondary_h = 56.0 if compact else 64.0
	m.square = 44.0 if compact else 72.0
	m.button_font = 16 if compact else 26
	m.compact = compact
	return m

## The family's condensed face: the project default font, narrowed like Durango's condensed sans.
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_transform = Transform2D(Vector2(0.9, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	return _font

static func safe(vp: Viewport) -> Vector4:
	return forced_insets if forced_insets.x >= 0.0 else UiTokens.safe_insets(vp)

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	for kind in ["Button"]:
		t.set_stylebox("normal", kind, button_box(BUTTON_DARK, BUTTON_EDGE))
		t.set_stylebox("hover", kind, button_box(BUTTON_DARK.lightened(0.08), TEXT))
		t.set_stylebox("pressed", kind, button_box(Color(SELECT, 0.25), SELECT))
		t.set_stylebox("hover_pressed", kind, button_box(Color(SELECT, 0.25), SELECT))
		t.set_stylebox("disabled", kind, button_box(Color(BUTTON_DARK, 0.6), Color(BUTTON_EDGE, 0.3)))
		var focus := button_box(Color(0, 0, 0, 0), SELECT)
		focus.draw_center = false
		focus.set_border_width_all(2)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, TEXT)
		t.set_color("font_disabled_color", kind, TEXT_OFF)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.0)
	t.set_stylebox("panel", "PanelContainer", sb)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(SELECT, 0.55)
	bar.set_corner_radius_all(2)
	for part in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(part, "VScrollBar", bar)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.25)
	track.content_margin_left = 3
	track.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", track)
	# Hover tooltips (desktop) in the family's dark look; the same facts are one tap away in the panel.
	t.set_stylebox("panel", "TooltipPanel", button_box(Color(0.045, 0.045, 0.04, 0.96), BUTTON_EDGE))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font("font", "TooltipLabel", font())
	t.set_font_size("font_size", "TooltipLabel", 16)
	_theme = t
	return t

## Dark rectangular button with a thin light edge and minimal rounding (spec 13 s9).
static func button_box(bg: Color, edge: Color, radius: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	return sb

## Yellow primary action (Durango's Form Bond / Unequip), dark ink.
static func style_primary(b: Button, font_px: int) -> void:
	b.add_theme_stylebox_override("normal", button_box(PRIMARY, PRIMARY.darkened(0.3), 3))
	b.add_theme_stylebox_override("hover", button_box(PRIMARY.lightened(0.1), PRIMARY.darkened(0.3), 3))
	b.add_theme_stylebox_override("pressed", button_box(PRIMARY.darkened(0.12), PRIMARY.darkened(0.4), 3))
	b.add_theme_stylebox_override("hover_pressed", button_box(PRIMARY.darkened(0.12), PRIMARY.darkened(0.4), 3))
	b.add_theme_stylebox_override("disabled", button_box(PRIMARY.darkened(0.45), PRIMARY.darkened(0.6), 3))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, PRIMARY_INK)
	b.add_theme_color_override("font_disabled_color", Color(PRIMARY_INK, 0.6))
	b.add_theme_font_size_override("font_size", font_px)

## Weathered surface (canvas_item shader; no NoiseTexture2D, which loads asynchronously on web).
## One material per tint/strength so every screen shares it.
static func grain(tint: Color, strength: float = 1.0, seed_v: float = 0.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.1f" % [tint.to_html(), strength, seed_v]
	if not _grain.has(key):
		var m := ShaderMaterial.new()
		m.shader = GRAIN
		m.set_shader_parameter("tint", tint)
		m.set_shader_parameter("strength", strength)
		m.set_shader_parameter("seed", seed_v)
		_grain[key] = m
	return _grain[key]

## The family's opaque backdrop (HUD controls must not show through a modal screen).
static func backdrop() -> ColorRect:
	return surface(BACKDROP, 1.2, 9.0)

## A full-rect ColorRect painted with the grain, for panel backgrounds.
static func surface(tint: Color, strength: float = 1.0, seed_v: float = 0.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.WHITE
	r.material = grain(tint, strength, seed_v)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r
