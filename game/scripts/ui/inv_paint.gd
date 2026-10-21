class_name InvPaint
extends RefCounted
## Draw helpers every slot-like control in the bag family paints with, so the Bag, storage, cargo
## and picker cells match (spec 13 s5-8, s11): item art, "Lv. N", the blue NEW tag, the yellow
## corner brackets, the rare corner mark, the lock pip, durability and a fungible count.

## Item art centred a little low in `cell` (room for the labels above), fitted to its opaque part.
static func item_icon(ci: CanvasItem, id: StringName, cell: Rect2, share: float = 0.62, centre_y: float = 0.56, tint: Color = Color.WHITE) -> void:
	var tex := ItemArt.texture_for(id)
	if tex == null:
		return
	var src := ItemArt.content_rect(id)
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		src = Rect2(Vector2.ZERO, tex.get_size())
	var box := cell.size * share
	var k := minf(box.x / src.size.x, box.y / src.size.y)
	var dst := src.size * k
	var c := Vector2(cell.position.x + cell.size.x * 0.5, cell.position.y + cell.size.y * centre_y)
	ci.draw_texture_rect_region(tex, Rect2(c - dst * 0.5, dst), src, tint)

## How far labels and marks sit inside a compartment of side `unit`: just inside the brackets.
static func inset(unit: float) -> float:
	return bracket_stroke(unit) + 3.0

static func bracket_stroke(unit: float) -> float:
	return maxf(3.0, unit * 0.035)

## Grey "Lv. N" in the top-right corner (the reference puts it at the top, beside NEW).
static func level(ci: CanvasItem, text: String, cell: Rect2, px: int, unit: float) -> void:
	if text == "":
		return
	var f := InvTheme.font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad := inset(unit)
	ci.draw_string(f, Vector2(cell.end.x - pad - w, cell.position.y + pad + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT_2)

## Small blue rectangle with white NEW, top-left.
static func new_tag(ci: CanvasItem, cell: Rect2, px: int, unit: float) -> Rect2:
	var f := InvTheme.font()
	var text := str((InvView.data().get("new_tag", {}) as Dictionary).get("text", "NEW"))
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad := inset(unit) - 2.0
	var r := Rect2(cell.position + Vector2(pad, pad), Vector2(w + 8.0, px + 6.0))
	ci.draw_rect(r, InvTheme.NEW_BG)
	ci.draw_string(f, Vector2(r.position.x + 4.0, r.position.y + 3.0 + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
	return r

## Four yellow L-shaped corner brackets with a faint tint behind (spec 13 s8: never a full frame).
## Sized from one compartment's side `unit`, so a 2x2 cage gets the same weight as a single cell.
static func brackets(ci: CanvasItem, r: Rect2, unit: float, color: Color = InvTheme.SELECT) -> void:
	var arm := maxf(10.0, unit * 0.14)
	var w := bracket_stroke(unit)
	ci.draw_rect(r, Color(color, 0.12))
	var inner := r.grow(-w * 0.5)
	for corner in [[inner.position, Vector2(1, 1)], [Vector2(inner.end.x, inner.position.y), Vector2(-1, 1)],
			[Vector2(inner.position.x, inner.end.y), Vector2(1, -1)], [inner.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		ci.draw_rect(Rect2(p - Vector2(w * 0.5, w * 0.5) * d.sign(), Vector2(arm * d.x, w * d.y)).abs(), color)
		ci.draw_rect(Rect2(p - Vector2(w * 0.5, w * 0.5) * d.sign(), Vector2(w * d.x, arm * d.y)).abs(), color)

## Small green triangle in the bottom-right corner for a rare trait (spec 13 s11, optional and
## much quieter than the brackets).
static func rare_marker(ci: CanvasItem, cell: Rect2, unit: float) -> void:
	var s := maxf(8.0, unit * 0.12)
	var e := cell.end - Vector2.ONE * inset(unit)
	ci.draw_colored_polygon(PackedVector2Array([e, e - Vector2(s, 0), e - Vector2(0, s)]), Color(InvTheme.RARE, 0.85))

## White lock glyph, bottom-left (white: lock is an action the player took).
static func lock_pip(ci: CanvasItem, cell: Rect2, unit: float) -> void:
	var tex := UiIcons.icon(&"lock")
	if tex == null:
		return
	var s := maxf(14.0, unit * 0.18)
	var i := inset(unit)
	ci.draw_texture_rect(tex, Rect2(Vector2(cell.position.x + i, cell.end.y - s - i), Vector2(s, s)), false)

## Thin wear bar along the bottom, only when worn below max.
static func durability(ci: CanvasItem, cell: Rect2, stack: ItemStack) -> void:
	if stack == null or stack.max_durability <= 0 or stack.durability >= stack.max_durability:
		return
	var frac := clampf(float(stack.durability) / float(stack.max_durability), 0.0, 1.0)
	var bar := Rect2(Vector2(cell.position.x + cell.size.x * 0.2, cell.end.y - 7.0), Vector2(cell.size.x * 0.6, 3.0))
	ci.draw_rect(bar, Color(0, 0, 0, 0.55))
	ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), InvTheme.DANGER if stack.is_broken() or frac < 0.2 else InvTheme.TEXT_2)

## "×N" bottom-right for fungible stacks (ammunition); instances are always one.
static func count(ci: CanvasItem, cell: Rect2, n: int, px: int) -> void:
	if n <= 1:
		return
	var f := InvTheme.font()
	var text := "×%d" % n
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	ci.draw_string(f, Vector2(cell.end.x - w - 5.0, cell.end.y - 5.0 - f.get_descent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)

## Faint dashed separator (the reference's fine compartment lines).
static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color = InvTheme.SEPARATOR, width: float = 1.0) -> void:
	ci.draw_dashed_line(a, b, color, width, 4.0, false)
