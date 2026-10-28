class_name NatureChip
extends PanelContainer
## NATURES (owner 2026-10-28): the nature is a TAG under the creature's name, not part of the name.
## One chip shared by the world plate, the Animals screen row and the pet radial, so the nature reads
## the same everywhere: its short label ("Timid"), small type, directly under the name.
##
## Style: the trait chip (docs/design/ui-redesign-spec.md §5) in its gold/positive polarity.
## ASSUMPTION: a nature is neither good nor bad, and the positive chip is the neutral-looking of the
## three (the negative one is grey and its "−" prefix would read as a penalty). No prefix glyph: there
## is no polarity to signal for a colour-blind player. The three existing styles are left untouched.
## The chip is hidden (and adds no height) when the animal has no nature.

const DEFAULT_PX := UiTokens.CHIP_PX

var label: Label

func _init() -> void:
	name = "NatureChip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTokens.trait_chip_style(&"positive")
	# A tag under a name, not a card: half the trait chip's vertical padding.
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.name = "NatureLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", UiTokens.trait_chip_fg(&"positive"))
	add_child(label)
	visible = false

## The chip's own text: the nature's short label, "" for no nature.
static func text_for(nature: StringName) -> String:
	return CreatureNatures.label(nature)

static func make(nature: StringName, px: int = DEFAULT_PX) -> NatureChip:
	var chip := NatureChip.new()
	chip.configure(nature, px)
	return chip

func configure(nature: StringName, px: int = DEFAULT_PX) -> void:
	var text := text_for(nature)
	label.text = text
	label.add_theme_font_size_override("font_size", px)
	visible = text != ""
	fit()

## The chip box at its content size; callers place its top-left (the plate) or centre it (the radial).
func fit() -> void:
	size = get_combined_minimum_size()

func chip_text() -> String:
	return label.text
