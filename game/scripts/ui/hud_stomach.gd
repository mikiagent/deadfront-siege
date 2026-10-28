class_name HudStomach
extends RefCounted
## HUDRULES (owner 2026-10-28: "add a circular stomach indicator to the right of the health bar"): a ring
## that empties as hunger grows, a white stomach glyph inside. HuntHud draws it beside the two bars.
# ASSUMPTION: this build has no satiety meter (PRD :72/:1030, survival-needs.md "Food & relief"), so the ring
# reads what a meal leaves in her: the share of eaten Energy still digesting (Digestion rows, remaining /
# total). It is full right after a meal and empties over the food's digest time; empty = nothing in her
# stomach. No rule changes: it only reads Digestion.

const TRACK := Color(0.08, 0.08, 0.1, 0.9)
const LOW := 0.25  ## under this the ring turns LIFE red

## 0..1: how full she is.
static func fill_of(p: Player) -> float:
	var dig := Digestion.of(p)
	if dig == null:
		return 0.0
	var total := 0.0
	for row in dig.rows():
		total += float(row.get("total", 0.0))
	return clampf(dig.total_remaining() / total, 0.0, 1.0) if total > 0.0 else 0.0

static func color_for(fill: float) -> Color:
	return UiTokens.LIFE if fill < LOW else UiTokens.GOLD

## The ring centred on `c` (outer radius `rad`), filled clockwise from the top. Returns its box.
static func draw(ci: CanvasItem, c: Vector2, rad: float, fill: float) -> Rect2:
	var w := maxf(3.0, rad * 0.22)
	ci.draw_circle(c, rad, UiTokens.HUD_FILL)
	ci.draw_arc(c, rad - w * 0.5, 0.0, TAU, 40, TRACK, w, true)
	if fill > 0.0:
		ci.draw_arc(c, rad - w * 0.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), maxi(4, int(40.0 * fill)), color_for(fill), w, true)
	var g := (rad - w) * 1.25
	var tex := UiIcons.icon(&"stomach") if UiIcons.path_for(&"stomach") != "" else null
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, 0.95))
	return Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
