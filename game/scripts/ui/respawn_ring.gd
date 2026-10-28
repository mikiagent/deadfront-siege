class_name RespawnRing
extends Control
## Circular cooldown ring: a dead pet's countdown until it can be summoned again (PETS sheet).
## Sweeps down from a full circle, seconds in the middle; calls on_done once when it finishes.

var rec: PetRecord
var on_done: Callable

func _init(p_rec: PetRecord = null, p_on_done: Callable = Callable()) -> void:
	rec = p_rec
	on_done = p_on_done
	custom_minimum_size = Vector2(64, 64)
	size = custom_minimum_size
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

## B4 look (ui-redesign-spec §7 B4): a dark red disc, the time left as a LIFE arc sweeping down
## clockwise from 12 o'clock, the whole seconds in the middle ("seconds" under them on a big ring).
func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	var w := maxf(3.0, r * 0.09)
	draw_circle(c, r, Color(0.22, 0.05, 0.04, 0.9))
	draw_arc(c, r - w * 0.5, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.12), w, true)
	if rec == null or PetRecord.RESPAWN_TIME <= 0.0:
		return
	var frac := clampf(rec.respawn_left / PetRecord.RESPAWN_TIME, 0.0, 1.0)
	if frac > 0.0:
		draw_arc(c, r - w * 0.5, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, UiTokens.LIFE, w, true)
	var font := UiTokens.ui_face()
	var big := r >= 44.0
	var n := str(int(ceil(rec.respawn_left)))
	UiTokens.draw_centered(self, font, c - Vector2(0, r * 0.12 if big else 0.0), n if big else n + "s", maxi(UiTokens.TYPE_MIN, int(r * (0.62 if big else 0.5))), Color.WHITE)
	if big:
		UiTokens.draw_centered(self, font, c + Vector2(0, r * 0.42), "seconds", maxi(UiTokens.TYPE_MIN, int(r * 0.2)), UiTokens.TEXT)
