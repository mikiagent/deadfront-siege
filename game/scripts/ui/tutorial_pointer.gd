class_name TutorialPointer
extends Control
## TUTORIAL ISLAND onboarding pointer: the plan's GUIDED hand, simple version
## (docs/design/durango-informed-improvements.md section 10, `point_at`). While a tutorial order
## runs it rings the exact HUD element the order names (MENU, BUILD, BAG, a context hex such as
## Drink or Rest) or bobs an arrow over the world spot (camp, bench, fire pit, the nearest branch
## node, the animal, the dock). Tutorial.pointer_target decides; this only draws. Nothing here takes
## input (mouse_filter IGNORE) and it hides while a full-screen sheet or modal is up.

const GOLD := Color(1.0, 0.82, 0.32)
var player: Player
var _t := 0.0
var _target: Dictionary = {}
var _acc := 0.0

func _ready() -> void:
	name = "TutorialPointer"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 0.2:  # the target search walks groups; 5 Hz is plenty for a pointer
		_acc = 0.0
		_target = Tutorial.pointer_target(player) if player and not _covered() else {}
	visible = not _target.is_empty()
	if visible:
		queue_redraw()

## A sheet, the bag, the craft screen or a modal is up: the pointer would sit on top of it.
func _covered() -> bool:
	if player.ui and player.ui.visible:
		return true
	if player.craft_ui and player.craft_ui.visible:
		return true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.get("_sheet") != null:
		return true
	return not get_tree().get_nodes_in_group(&"character_creation").is_empty()

func _draw() -> void:
	if _target.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	if _target.has("ui"):
		var c := _target["ui"] as Control
		if c == null or not is_instance_valid(c):
			return
		var r := c.get_global_rect()
		var centre := r.get_center() - get_global_rect().position
		var rad := maxf(r.size.x, r.size.y) * 0.5 + 6.0 + 6.0 * pulse
		draw_arc(centre, rad, 0.0, TAU, 48, Color(GOLD, 0.95), 4.0, true)
		draw_arc(centre, rad + 8.0, 0.0, TAU, 48, Color(GOLD, 0.35 * (1.0 - pulse)), 3.0, true)
		_arrow(centre - Vector2(0.0, rad + 10.0 + 8.0 * pulse), Vector2.DOWN)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at: Vector3 = _target["world"]
	var view := get_viewport_rect()
	var margin := 48.0
	if cam.is_position_behind(at + Vector3.UP * 1.6):
		return
	var sp := cam.unproject_position(at + Vector3.UP * 1.6)
	var inside := view.grow(-margin).has_point(sp)
	if inside:
		var ground := cam.unproject_position(at)
		draw_arc(ground, 16.0 + 6.0 * pulse, 0.0, TAU, 32, Color(GOLD, 0.8), 3.0, true)
		_arrow(sp - Vector2(0.0, 14.0 * pulse), Vector2.DOWN)
	else:
		# Off screen: an edge arrow pointing the way.
		var c2 := view.get_center()
		var dir := (sp - c2).normalized()
		var edge := Vector2(clampf(sp.x, margin, view.size.x - margin), clampf(sp.y, margin, view.size.y - margin))
		_arrow(edge - dir * 6.0 * pulse, dir)

func _arrow(tip: Vector2, dir: Vector2) -> void:
	var back := -dir
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, tip + back * 26.0 + side * 15.0, tip + back * 16.0, tip + back * 26.0 - side * 15.0])
	draw_colored_polygon(pts, GOLD)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.1, 0.08, 0.02, 0.9), 2.0, true)
	draw_line(tip + back * 18.0, tip + back * 44.0, GOLD, 6.0, true)
