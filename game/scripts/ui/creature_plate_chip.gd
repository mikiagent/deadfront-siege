class_name CreaturePlateChip
extends Control
## CREATURECHIPS: one of the creature plate's status chips, drawn with the player's chip renderer
## (HudBuffRow.draw_chip) so a creature's bleed looks like the player's, stack count included.
## The plate's line3 HBox lays these out where the old StatusGlyph ring sat.

var icon: StringName = &""
var kind: StringName = &""
var stacks: int = 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # 128 px UiIcons drawn at 38 px
	custom_minimum_size = Vector2(HudBuffRow.CHIP, HudBuffRow.CHIP)
	size = custom_minimum_size

func configure(icon_id: StringName, status_kind: StringName, count: int) -> void:
	icon = icon_id
	kind = status_kind
	stacks = count
	queue_redraw()

func _draw() -> void:
	HudBuffRow.draw_chip(self, ThemeDB.fallback_font, Rect2(Vector2.ZERO, Vector2(HudBuffRow.CHIP, HudBuffRow.CHIP)), icon, kind, false, stacks)
