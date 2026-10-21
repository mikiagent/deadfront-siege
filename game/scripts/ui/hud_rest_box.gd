class_name HudRestBox
extends RefCounted
## REST: the Resting chip's live recovery rates (spec 01:22), a dark box under the HUD's status row.
## Lines are RestState.hud_lines(): what she is doing (white), Health, fatigue (green; Health red while
## a status takes more than the rest gives). Kept out of hunt_hud.gd, which makes the one call.

const GOOD := Color(0.55, 0.9, 0.6)

## The Resting chip, first in the status row: the rest icon on a status chip.
static func chip(ci: CanvasItem, font: Font, at: Vector2) -> void:
	HudStatusChip.draw(ci, font, at, &"resting", Color(1, 0.75, 0.45))

## Draws the box `width` wide with its top-left at `at`; returns the drawn rect (HUD drawn_blocks).
static func draw(ci: CanvasItem, font: Font, at: Vector2, width: float, px: int, lines: PackedStringArray) -> Rect2:
	var box := Rect2(at, Vector2(width, 8.0 + (px + 4.0) * lines.size())).grow(4.0)
	ci.draw_rect(box, UiTokens.INK)
	for i in lines.size():
		var col := Color.WHITE if i == 0 else (UiTokens.DANGER if i == 1 and lines[i].begins_with("-") else GOOD)
		ci.draw_string(font, Vector2(at.x, at.y + (px + 4.0) * (i + 1)), UiTokens.ellipsis(font, lines[i], width, px),
			HORIZONTAL_ALIGNMENT_LEFT, width, px, col)
	return box
