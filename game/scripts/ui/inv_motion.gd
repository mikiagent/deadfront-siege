class_name InvMotion
extends RefCounted
## Restrained motion for the bag family (spec 13 s20): quick fades, a short settle of the selection
## brackets and a brief light-up where a moved item lands. No bounce, no long transitions, no
## particles. Motion only touches modulate and draw-time values, never a control's rect, so layout
## and tap-target checks read the final layout at once.

## A screen, the Detailed Stats panel or a dropdown fading in (design: at most 120 ms).
const OPEN_S := 0.11
## A storage tab switch (design: at most 80 ms).
const TAB_S := 0.07
## The yellow brackets settling onto a newly selected cell, from SETTLE_PX outside it.
const SETTLE_S := 0.08
const SETTLE_PX := 4.0
## A tab or gear cell lighting up as a transferred or equipped item arrives.
const FLASH_S := 0.3

## Fades `c` in from transparent over `secs` (restarts a fade already running on it).
static func fade_in(c: CanvasItem, secs: float = OPEN_S) -> void:
	if c == null or not c.is_inside_tree():
		return
	var old: Variant = c.get_meta(&"inv_fade") if c.has_meta(&"inv_fade") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	c.set_meta(&"inv_fade", tw)

## Runs `step` from 0 to 1 over `secs` on `owner` (each frame redraws what reads the value).
static func run(owner: Node, step: Callable, secs: float) -> void:
	if owner == null or not owner.is_inside_tree():
		step.call(1.0)
		return
	owner.create_tween().tween_method(step, 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
