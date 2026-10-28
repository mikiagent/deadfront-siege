class_name HudStatusChip
extends RefCounted
## The HUD's 26 px status chips (the player's row and the target frame): the white UiIcons drawing of
## the status on a dark square. Two orange letters only for a status the icon set does not cover.

const PX := 26.0
const INSET := 3.0

## Draws one chip at `at` on `ci`'s canvas; `a` fades the target frame with combat.
static func draw(ci: CanvasItem, font: Font, at: Vector2, id: StringName, letter_col: Color, a: float = 1.0) -> void:
	ci.draw_rect(Rect2(at, Vector2(PX, PX)), Color(0.1, 0.1, 0.12, 0.85 * a))
	var tex := icon_for(id)
	if tex:
		ci.draw_texture_rect(tex, Rect2(at + Vector2(INSET, INSET), Vector2(PX - 2.0 * INSET, PX - 2.0 * INSET)), false, Color(1, 1, 1, a))
	else:
		ci.draw_string(font, at + Vector2(4, 19), str(id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(letter_col, letter_col.a * a))

## The chip's drawing, null when the set has none (then the chip falls back to letters).
static func icon_for(id: StringName) -> Texture2D:
	return UiIcons.icon(id) if UiIcons.path_for(id) != "" else null

## B2 target-frame chip (UIGATHER, spec §7 B2): icon and name on the HUD fill with a 1.5 px rim in the
## status's own colour ("Bleed", "Slowed", "Groggy"). Returns the drawn box.
static func draw_named(ci: CanvasItem, font: Font, at: Vector2, id: StringName, a: float = 1.0, px: int = 15) -> Rect2:
	var def := Data.status(id)
	var label := def.display_name if def and def.display_name != "" else str(id).capitalize()
	var col := def.fx_color if def else UiTokens.MUTED
	var h := float(px) + 11.0
	var w := h + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0
	var box := Rect2(at, Vector2(w, h))
	ci.draw_rect(box, Color(UiTokens.HUD_FILL, UiTokens.HUD_FILL.a * a))
	ci.draw_rect(box.grow(-0.75), Color(col, a), false, 1.5)
	var tex := icon_for(id)
	if tex:
		ci.draw_texture_rect(tex, Rect2(at + Vector2(5.0, 4.0), Vector2(h - 8.0, h - 8.0)), false, Color(col, a))
	ci.draw_string(font, at + Vector2(h + 2.0, h * 0.5 + float(px) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(col.lightened(0.25), a))
	return box
