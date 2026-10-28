class_name HudRestBox
extends RefCounted
## REST: the Resting chip's live recovery rates (spec 01:22), a rounded pill under the HUD's status row,
## and the recovery floats over the survivor. Lines are RestState.hud_lines(): what she is doing (white),
## Health, fatigue (green; Health red while a status takes more than the rest gives). Kept out of
## hunt_hud.gd, which makes the calls.

const GOOD := Color(0.55, 0.9, 0.6)
## Pre-merge fix: the box was meta-size text in a square box; the pill reads at the body size and
## fits its text, up to this width.
const MAX_W := 280.0
const PAD := 8.0
## A recovery float shows what one interval of rest gave, so the gain is seen on her, not only in the pill.
const FLOAT_EVERY_S := 1.0

var _hp0 := -1.0
var _fat0 := -1.0
var _left := FLOAT_EVERY_S

## The Resting chip, first in the status row: the rest icon on a status chip.
static func chip(ci: CanvasItem, font: Font, at: Vector2) -> void:
	HudStatusChip.draw(ci, font, at, &"resting", Color(1, 0.75, 0.45))

## Draws the pill with its top-left at `at` (at most MAX_W wide); returns the drawn rect (HUD drawn_blocks).
static func draw(ci: CanvasItem, font: Font, at: Vector2, px: int, lines: PackedStringArray) -> Rect2:
	var text_w := 0.0
	for line in lines:
		text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	text_w = minf(text_w, MAX_W - PAD * 2.0)
	var row := px + 6.0
	var box := Rect2(at, Vector2(text_w + PAD * 2.0, PAD * 2.0 + row * lines.size() - 6.0))
	var sb := UiTokens.panel_style()
	sb.set_corner_radius_all(int(minf(UiTokens.RADIUS, box.size.y * 0.5)))
	ci.draw_style_box(sb, box)
	for i in lines.size():
		var col := Color.WHITE if i == 0 else (UiTokens.DANGER if i == 1 and lines[i].begins_with("-") else GOOD)
		var base := Vector2(at.x + PAD, at.y + PAD + row * i + px * 0.85)
		ci.draw_string(font, base, UiTokens.ellipsis(font, lines[i], text_w, px), HORIZONTAL_ALIGNMENT_LEFT, text_w, px, col)
	return box

## Every FLOAT_EVERY_S while she rests or sleeps: what that interval gave, as rising text over her
## ("+3 HP" green, "-1 fatigue" teal); nothing when a stat did not move by a whole point.
func tick(p: Player, events: HudEventState, delta: float) -> void:
	if p == null or p.sim == null or p.sim.rest.hud_lines().is_empty():
		_hp0 = -1.0
		return
	if _hp0 < 0.0:
		_hp0 = p.vitals.health
		_fat0 = p.vitals.fatigue
		_left = FLOAT_EVERY_S
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = FLOAT_EVERY_S
	var hp := p.vitals.health - _hp0
	var fat := _fat0 - p.vitals.fatigue
	if hp >= 1.0:
		events.add_float("+%d HP" % int(hp), GOOD, 0.0)
		_hp0 += floorf(hp)
	elif hp < 0.0:
		_hp0 = p.vitals.health  # a status took it: the red damage floats already say so
	if fat >= 1.0:
		events.add_float("-%d fatigue" % int(fat), UiTokens.TEAL, 22.0)  # one row under the HP float
		_fat0 -= floorf(fat)
	elif fat < 0.0:
		_fat0 = p.vitals.fatigue
