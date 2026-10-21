class_name GearPresetSelector
extends Control
## The numbered loadout row under the Gear tab (spec 13 s14, Character -> Gear reference): compact
## dark cells "1 2 [lock] [lock]", the active one in yellow brackets, the ones not yet earned with a
## lock. Presentation only: a tap emits chosen(k); GearPresets decides (and refuses a locked one).

signal chosen(k: int)

var active := 0
var unlocked := 1
var count := 4
var font_px := 26

## Reads the preset state for the survivor now.
func show_state(inv: Inventory) -> void:
	count = GearPresets.count()
	unlocked = GearPresets.unlocked_count(LevelDisplay.player_level())
	active = GearPresets.active(inv)
	queue_redraw()

func cell_rect(k: int) -> Rect2:
	var w := size.x / float(maxi(1, count))
	return Rect2(Vector2(w * k, 0), Vector2(w, size.y))

func _gui_input(event: InputEvent) -> void:
	var at := Vector2(-1, -1)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	if at.x >= 0.0:
		chosen.emit(clampi(int(at.x / (size.x / float(maxi(1, count)))), 0, count - 1))
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(InvTheme.CELL_DARK, 0.85))
	var f := InvTheme.font_at(font_px)
	var lock := UiIcons.icon(&"lock")
	for k in count:
		var r := cell_rect(k)
		if k > 0:
			InvPaint.dashed(self, r.position + Vector2(0, size.y * 0.15), r.position + Vector2(0, size.y * 0.85))
		if k >= unlocked:
			var s := size.y * 0.36
			if lock:
				draw_texture_rect(lock, Rect2(r.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false, InvTheme.TEXT_OFF)
		else:
			UiTokens.draw_centered(self, f, r.get_center(), str(k + 1), font_px, InvTheme.SELECT if k == active else InvTheme.TEXT)
		if k == active:
			InvPaint.brackets(self, r.grow(-2.0), r.size.y)
