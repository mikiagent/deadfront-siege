class_name InvTab
extends Button
## One tab of the bag family (the storage-transfer and in-game Bag references): grey with grey text;
## the active one near-black with gold text and a gold underline, its count at the right ("61 / 200").
## It lights up briefly where items land (`flash`). A tab that switches nothing (the in-game Bag's one
## tab) is given MOUSE_FILTER_IGNORE by its screen: it reads as a heading, not a control.

var label := ""
var count := ""
## The count's colour (the full bag's warning colour); transparent = the label's.
var count_color := Color(0, 0, 0, 0)
var active := false
## 1 -> 0 after items arrive on this tab (InvMotion.FLASH_S).
var flash := 0.0
var px := 20
var pad := 20.0

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true

## The name, a gap and the count at `px`, never narrower than `least`.
func wanted_width(least: float) -> float:
	var w := InvTheme.font().get_string_size(label + count, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return maxf(w + pad * 2.0 + 28.0, least)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(InvTheme.button_box(Color(0.03, 0.032, 0.03, 0.95) if active else Color(0.26, 0.26, 0.245, 0.92), Color(0, 0, 0, 0.5), 4), r)
	if flash > 0.0:
		draw_rect(r.grow(-2.0), Color(InvTheme.SELECT, 0.32 * flash))
	if active:
		draw_rect(Rect2(Vector2(6, r.size.y - 5), Vector2(r.size.x - 12, 4)), InvTheme.SELECT)
	var f := InvTheme.font()
	var y := (r.size.y + f.get_ascent(px) - f.get_descent(px)) * 0.5 - 1.0
	var ink := InvTheme.SELECT if active else InvTheme.TEXT_2
	var count_w := f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(f, Vector2(pad, y), UiTokens.ellipsis(f, label, r.size.x - pad * 2.0 - count_w - 12.0, px), HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
	draw_string(f, Vector2(r.size.x - pad - count_w, y), count, HORIZONTAL_ALIGNMENT_LEFT, -1, px, count_color if count_color.a > 0.0 else ink)
