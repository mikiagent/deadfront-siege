class_name InvPaint
extends RefCounted
## Draw helpers every slot-like control in the bag family paints with, so the Bag, storage, cargo
## and picker cells match (spec 13 s5-8, s11): item art, "Lv. N", the processed "+", the blue NEW tag, the yellow
## corner brackets (the gold check in multi-select), trait pips, the lock pip, durability and a count.

## Shape each trait class is drawn with (pips and the inspect panel's trait chips).
const PIP_SHAPES := {&"positive": &"square", &"negative": &"hollow", &"rare": &"diamond"}

## data/inv_ui.json "art": id -> [texture, opaque rect] (null texture: none, use ItemArt).
static var _own_art := {}

## Item art centred a little low in `cell` (room for the labels above), fitted to its opaque part.
static func item_icon(ci: CanvasItem, id: StringName, cell: Rect2, share: float = 0.62, centre_y: float = 0.56, tint: Color = Color.WHITE) -> void:
	var own := own_art(id)
	var tex: Texture2D = own[0] if own[0] else ItemArt.texture_for(id)
	if tex == null:
		return
	var src: Rect2 = own[1] if own[0] else ItemArt.content_rect(id)
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		src = Rect2(Vector2.ZERO, tex.get_size())
	var box := cell.size * share
	var k := minf(box.x / src.size.x, box.y / src.size.y)
	var dst := src.size * k
	var c := Vector2(cell.position.x + cell.size.x * 0.5, cell.position.y + cell.size.y * centre_y)
	ci.draw_texture_rect_region(tex, Rect2(c - dst * 0.5, dst), src, tint)

## The family's own painted art for an item that has no render yet (data/inv_ui.json "art"):
## [texture or null, its opaque rect]. A render wins as soon as one exists.
static func own_art(id: StringName) -> Array:
	var key := str(id)
	if not _own_art.has(key):
		var row: Variant = (InvView.data().get("art", {}) as Dictionary).get(key)
		var tex: Texture2D = null
		var rect := Rect2()
		if row is Dictionary and not ItemArt.is_rendered(id) and ResourceLoader.exists(str(row.get("path", ""))):
			tex = load(str(row.path)) as Texture2D
			var r: Array = row.get("rect", [])
			rect = Rect2(r[0], r[1], r[2], r[3]) if r.size() == 4 else Rect2(Vector2.ZERO, tex.get_size())
		_own_art[key] = [tex, rect]
	return _own_art[key]

## How far labels and marks sit inside a compartment of side `unit`: just inside the brackets.
static func inset(unit: float) -> float:
	return bracket_stroke(unit) + 3.0

static func bracket_stroke(unit: float) -> float:
	return maxf(3.0, unit * 0.035)

## Grey "Lv. N" in the top-right corner (the reference puts it at the top, beside NEW).
static func level(ci: CanvasItem, text: String, cell: Rect2, px: int, unit: float) -> void:
	if text == "":
		return
	var f := InvTheme.font_at(px)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pad := inset(unit)
	ci.draw_string(f, Vector2(cell.end.x - pad - w, cell.position.y + pad + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT_2)

## Small blue rectangle with white NEW, top-left.
static func new_tag(ci: CanvasItem, cell: Rect2, px: int, unit: float) -> Rect2:
	var f := InvTheme.font_at(px)
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

## Small pips under the art, one per trait (both Durango references mark traits this way; spec 13
## s11: quiet next to the brackets). At most six. The class reads by shape as well as colour:
## positive a filled gold square, negative a hollow grey square, rare a green diamond.
static func pips(ci: CanvasItem, cell: Rect2, stack: ItemStack, unit: float) -> void:
	var sec := InvAttributes.sections(stack)
	var classes: Array[StringName] = []
	for cls: StringName in [&"positive", &"negative", &"rare"]:
		for _r in (sec[str(cls)] as Array):
			classes.append(cls)
	if classes.is_empty():
		return
	classes.resize(mini(classes.size(), 6))
	var s := maxf(5.0, roundf(unit * 0.06))
	var gap := maxf(2.0, roundf(s * 0.5))
	var x := cell.position.x + (cell.size.x - classes.size() * s - (classes.size() - 1) * gap) * 0.5
	var y := cell.position.y + cell.size.y - unit * 0.18
	for cls in classes:
		pip(ci, Rect2(x, y, s, s), cls)
		x += s + gap

static func pip_color(cls: StringName) -> Color:
	match cls:
		&"positive":
			return InvTheme.POSITIVE
		&"rare":
			return InvTheme.RARE
	return InvTheme.TEXT_2

## One trait pip in `r`, by its class's shape (never colour alone).
static func pip(ci: CanvasItem, r: Rect2, cls: StringName) -> void:
	var c := pip_color(cls)
	match PIP_SHAPES.get(cls, &"square"):
		&"hollow":
			var w := maxf(1.5, roundf(r.size.x * 0.25))
			ci.draw_rect(r.grow(-w * 0.5), c, false, w)
		&"diamond":
			var m := r.get_center()
			var h := r.size.x * 0.68 # a diamond reads as big as the squares at this half-diagonal
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -h), m + Vector2(h, 0), m + Vector2(0, h), m + Vector2(-h, 0)]), c)
		_:
			ci.draw_rect(r, c)

## Multi-select mark (storage reference): a lighter compartment and a gold disc with a dark tick, top-left.
static func check(ci: CanvasItem, cell: Rect2, unit: float) -> void:
	ci.draw_rect(cell, Color(1, 1, 1, 0.07))
	var rad := maxf(9.0, unit * 0.11)
	var c := cell.position + Vector2.ONE * (inset(unit) + rad - 2.0)
	ci.draw_circle(c, rad, InvTheme.SELECT)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-rad * 0.48, 0.0), c + Vector2(-rad * 0.1, rad * 0.4), c + Vector2(rad * 0.5, -rad * 0.38)]), InvTheme.PRIMARY_INK, maxf(2.0, rad * 0.24), true)

## Small green triangle in the top-left corner: the instance worn now (Character -> Gear reference).
static func worn_marker(ci: CanvasItem, cell: Rect2, unit: float) -> void:
	var s := maxf(10.0, unit * 0.16)
	var o := cell.position + Vector2.ONE * inset(unit)
	ci.draw_colored_polygon(PackedVector2Array([o, o + Vector2(s, 0), o + Vector2(0, s)]), InvTheme.RARE)

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
	var f := InvTheme.font_at(px)
	var text := "×%d" % n
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	ci.draw_string(f, Vector2(cell.end.x - w - 5.0, cell.end.y - 5.0 - f.get_descent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)

## Faint dashed separator (the reference's fine compartment lines).
static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color = InvTheme.SEPARATOR, width: float = 1.0) -> void:
	ci.draw_dashed_line(a, b, color, width, 4.0, false)

## Dark, slightly irregular panel border (spec 13 s2: "dark, slightly irregular", no bright outlines):
## a rounded outline whose points wander about a pixel by a fixed hash, so it never flickers and no
## edge looks ruled. `key` varies the wander between panels.
static func frame(ci: CanvasItem, r: Rect2, width: float = 3.0, key: int = 0) -> void:
	width = minf(width, 2.0) # thin worn edges (review r1: 3 px read as a thick cartoon outline)
	var rad := 4.0
	var box := r.grow(-width * 0.5)
	if box.size.x <= rad * 2.0 or box.size.y <= rad * 2.0:
		return
	# Corner centres clockwise from top-left, each with the arc it turns and the side after it.
	var cs := [box.position + Vector2(rad, rad), Vector2(box.end.x - rad, box.position.y + rad), box.end - Vector2(rad, rad), Vector2(box.position.x + rad, box.end.y - rad)]
	var pts := PackedVector2Array()
	var k := key * 37
	for i in 4:
		var a0 := PI + i * PI * 0.5
		for j in 3: # the arc's last point is the side's first
			var a := a0 + j * PI / 6.0
			pts.append(cs[i] + Vector2(cos(a), sin(a)) * rad)
		var from: Vector2 = cs[i] + Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5)) * rad
		var to: Vector2 = cs[(i + 1) % 4] + Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5)) * rad
		var normal := Vector2(cos(a0 + PI * 0.5), sin(a0 + PI * 0.5))
		var steps := maxi(1, int(from.distance_to(to) / 14.0))
		for s in steps:
			k += 1
			pts.append(from.lerp(to, float(s) / steps) + normal * InvHeader._jit(k) * 0.4)
	pts.append(pts[0])
	ci.draw_polyline(pts, InvTheme.FRAME_INK, width, true)

## A small white "+" under the "Lv. N" label: a processed instance (the in-game Bag reference).
static func plus(ci: CanvasItem, cell: Rect2, px: int, unit: float) -> void:
	var h := maxf(4.0, roundf(px * 0.32))
	var c := Vector2(cell.end.x - inset(unit) - h, cell.position.y + inset(unit) + px * 1.75 + h) # clear of the label's descenders
	var w := maxf(1.5, roundf(h * 0.4))
	ci.draw_line(c - Vector2(h, 0), c + Vector2(h, 0), InvGlyphs.WHITE, w)
	ci.draw_line(c - Vector2(0, h), c + Vector2(0, h), InvGlyphs.WHITE, w)
