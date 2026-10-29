class_name AlphaChip
extends Panel
## ALPHATAG (owner 2026-10-29: "Alpha should be a tag in front of the name (prefix tag)"): the
## "ALPHA" chip that sits BEFORE the animal's name, on the world plate, the target plate and wherever
## the name is drawn. A genetic alpha (CreatureGenetics.alpha) wears it; a normal animal, and the pack
## leader whose "Alpha" word stays inside its name, do not.
##
## Style: the trait chip's gold, but SOLID (gold fill, ink text) so it reads as a rank tag in front of
## the name, not as another tinted nature chip under it. Sized by hand like NatureChip: the fallback
## font's line box at 12 px is taller than a plate row, so the label is centred and clipped inside.
## ASSUMPTION: the tag text is "ALPHA" upper case; the owner's example was "[ALPHA] Deinonychus".

const PAD_X := 4.0
const FONT_PX := UiTokens.CHIP_PX
const CHIP_H := 14.0
## Gap between the tag and the name it prefixes.
const NAME_GAP := 4.0

var label: Label

func _init() -> void:
	name = "AlphaChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTokens.trait_chip_style(&"positive")
	# Solid gold: the plate's names read white on ink, so the tag is the one filled chip on the row.
	style.bg_color = UiTokens.GOLD
	style.border_color = UiTokens.GOLD
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.name = "AlphaLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTokens.CTA_INK)
	label.add_theme_font_size_override("font_size", FONT_PX)
	add_child(label)
	visible = false

## "ALPHA" for an alpha, "" for every other animal.
static func text_for(is_alpha: bool) -> String:
	return CreatureNatures.ALPHA_TAG if is_alpha else ""

static func make(is_alpha: bool) -> AlphaChip:
	var chip := AlphaChip.new()
	chip.configure(is_alpha)
	return chip

func configure(is_alpha: bool) -> void:
	label.text = text_for(is_alpha)
	visible = label.text != ""
	if visible:
		fit()

func fit() -> void:
	var w := ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x + PAD_X * 2.0
	custom_minimum_size = Vector2(w, CHIP_H)
	size = custom_minimum_size
	label.size = Vector2(w - PAD_X * 2.0, CHIP_H)
	label.position = Vector2(PAD_X, (CHIP_H - label.size.y) * 0.5)

## Width the tag takes in front of a name (0 when the animal has none): callers shift the name right
## and shorten its ellipsis budget by this plus NAME_GAP.
static func prefix_width(is_alpha: bool) -> float:
	if not is_alpha:
		return 0.0
	var w := ThemeDB.fallback_font.get_string_size(ALPHA_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x + PAD_X * 2.0
	return w + NAME_GAP

const ALPHA_TEXT := "ALPHA"

## The tag drawn straight onto a CanvasItem (the HUD's target plate is drawn, not built of nodes).
## Returns the chip's rect; empty for a normal animal. `pos` is its top-left.
static func draw_at(ci: CanvasItem, font: Font, pos: Vector2, is_alpha: bool, a: float = 1.0) -> Rect2:
	var text := text_for(is_alpha)
	if text == "":
		return Rect2()
	var r := Rect2(pos, Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x + PAD_X * 2.0, CHIP_H))
	var style := UiTokens.trait_chip_style(&"positive")
	style.bg_color = UiTokens.GOLD
	style.border_color = UiTokens.GOLD
	style.set_corner_radius_all(2)
	style.bg_color.a *= a
	style.border_color.a *= a
	ci.draw_style_box(style, r)
	var base := r.position.y + (CHIP_H + font.get_ascent(FONT_PX) - font.get_descent(FONT_PX)) * 0.5
	ci.draw_string(font, Vector2(r.position.x + PAD_X, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX, Color(UiTokens.CTA_INK, a))
	return r

func chip_text() -> String:
	return label.text
