class_name RespawnRing
extends Control
## Circular cooldown ring: a dead pet's countdown until it can be summoned again (PETS sheet).
## Sweeps down from a full circle, seconds in the middle; calls on_done once when it finishes.

var rec: PetRecord
var on_done: Callable

func _init(p_rec: PetRecord = null, p_on_done: Callable = Callable()) -> void:
	rec = p_rec
	on_done = p_on_done
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if rec == null:
		return
	if not rec.respawning():
		if on_done.is_valid():
			var cb := on_done
			on_done = Callable()
			cb.call()
		return
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.45))
	draw_arc(c, r, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.25), 2.5, true)
	if rec == null or PetRecord.RESPAWN_TIME <= 0.0:
		return
	var frac := clampf(rec.respawn_left / PetRecord.RESPAWN_TIME, 0.0, 1.0)
	if frac > 0.0:
		# remaining time sweeps down clockwise from 12 o'clock
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, Color(0.55, 0.9, 1.0), 4.0, true)
	var secs := "%ds" % int(ceil(rec.respawn_left))
	var f := ThemeDB.fallback_font
	var fs := 16
	var w := f.get_string_size(secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.38), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
