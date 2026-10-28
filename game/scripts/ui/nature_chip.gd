class_name NatureChip
extends Panel
## NATURES (owner 2026-10-28): the nature is a TAG under the creature's name, not part of the name.
## One chip shared by the world plate, the Animals screen row and the pet radial, so the nature reads
## the same everywhere: its short label ("Timid"), small type, directly under the name.
##
## Style: the trait chip (docs/design/ui-redesign-spec.md §5) in its gold/positive polarity.
## ASSUMPTION: a nature is neither good nor bad, and the gold chip is the neutral-looking of the three
## (grey reads as a flaw and carries the "−" prefix; green is "rare special"). No prefix glyph: there
## is no polarity to signal for a colour-blind player. The three existing styles are untouched.
## The chip hides itself and takes no space when the animal has no nature.
##
## Sized by hand (not a container): the fallback font's line box is 25 px at 12 px type, taller than a
## plate row, so the label is centred and clipped inside the chip's own height instead.

const PAD_X := 6.0
const FONT_PX := UiTokens.CHIP_PX
const CHIP_H := 14.0

var label: Label

func _init() -> void:
	name = "NatureChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTokens.trait_chip_style(&"positive")
	# A tag under a name, not a card: no content margins (they would make the font's line box the height).
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.name = "NatureLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UiTokens.trait_chip_fg(&"positive"))
	label.add_theme_font_size_override("font_size", FONT_PX)
	add_child(label)
	visible = false

## The chip's own text: the nature's short label, "" for no nature.
static func text_for(nature: StringName) -> String:
	return CreatureNatures.tag(nature)

static func make(nature: StringName) -> NatureChip:
	var chip := NatureChip.new()
	chip.configure(nature)
	return chip

func configure(nature: StringName) -> void:
	var text := text_for(nature)
	label.text = text
	visible = text != ""
	if visible:
		fit()

## The chip box at its content size (callers place it; a container may lay it out itself).
func fit() -> void:
	var w := ThemeDB.fallback_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x + PAD_X * 2.0
	custom_minimum_size = Vector2(w, CHIP_H)
	size = custom_minimum_size
	label.position = Vector2(PAD_X, 0.0)
	label.size = Vector2(w - PAD_X * 2.0, CHIP_H)

func chip_text() -> String:
	return label.text
