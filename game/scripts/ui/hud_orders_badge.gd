class_name HudOrdersBadge
extends RefCounted
## HUDRULES (owner 2026-10-28: "make orders expandable/collapsible into the mini map. They are annoying and
## cover too much of the screen"). Collapsed (the default), the orders card is this badge in the minimap's
## top-left corner, over the round map's bezel: the orders glyph and the shown order's number ("3/28").
## A tap or click on it expands the card beside the minimap; a tap on the card collapses it again.
## The state is session-only (OrdersSheet.hud_expanded): no UI-settings store exists and the save is off-limits.
## A finished order flashes the badge GOLD for FLASH_S.

const H := 30.0
const TOUCH := 64.0
const FLASH_S := 2.4

## The badge rect for `text` at the minimap's corner `mp`.
static func rect_for(font: Font, mp: Vector2, text: String, px: int) -> Rect2:
	return Rect2(mp + Vector2(2.0, 2.0), Vector2(H + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 10.0, H))

## Where a press counts: the badge, padded to 64x64 on a compact canvas (it grows over the map, not off screen).
static func touch_rect(box: Rect2, compact: bool) -> Rect2:
	return Rect2(box.position, Vector2(maxf(box.size.x, TOUCH), maxf(box.size.y, TOUCH))) if compact else box

## `flash` 0..FLASH_S: time left of the finished-order flash.
static func draw(ci: CanvasItem, font: Font, box: Rect2, text: String, px: int, flash: float) -> void:
	var lit := flash > 0.0 and fmod(flash, 0.6) > 0.3
	ci.draw_rect(box, UiTokens.GOLD if lit else UiTokens.HUD_FILL)
	ci.draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), UiTokens.TEAL)
	ci.draw_rect(box.grow(-0.5), Color(UiTokens.GOLD, 0.8 if flash > 0.0 else 0.35), false, 1.0)
	var ink := UiTokens.CTA_INK if lit else Color.WHITE
	var tex := UiIcons.icon(&"notice") if UiIcons.path_for(&"notice") != "" else null
	if tex:
		ci.draw_texture_rect(tex, Rect2(box.position + Vector2(6.0, 5.0), Vector2(H - 10.0, H - 10.0)), false, ink)
	ci.draw_string(font, box.position + Vector2(H, H * 0.5 + px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
