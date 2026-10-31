class_name TutorialPointer
extends Control
## TUTORIAL ISLAND onboarding pointer: the plan's GUIDED hand, simple version
## (docs/design/durango-informed-improvements.md section 10, `point_at`). While a tutorial order
## runs it rings the exact HUD element the order names (MENU, BUILD, BAG, a context hex such as
## Drink or Rest) or bobs an arrow over the world spot (camp, bench, fire pit, the nearest branch
## node, the animal, the dock). Tutorial.pointer_target decides; this only draws. Nothing here takes
## input (mouse_filter IGNORE). MENU GUIDANCE (2026-10-29): it sits on its own canvas layer over every
## menu (TutorialLayer, 97), so inside the menus it rings the tab / entry / button Tutorial.guide names
## with a "Tap <name>" caption, or a "Scroll down" cue on the list when the entry is out of view. A
## path's way in (MENU, the station, a world spot) and every plain pointer still hide while a sheet,
## the bag or the craft screen covers them.

const GOLD := Color(1.0, 0.82, 0.32)
## Smoothing (owner 2026-10-29: "moves by updating its position instead of moving smoothly"): the drawn
## pointer eases toward its goal every frame (exponential approach, SMOOTH_K per second) and never
## steps faster than MAX_PX_S, so a new target or a 5 Hz re-pick glides instead of jumping; a world
## target that is a node (a creature, a carcass) is read every frame, so the arrow follows it.
const SMOOTH_K := 12.0
const MAX_PX_S := 2600.0
var player: Player
var _t := 0.0
var _target: Dictionary = {}
var _acc := 0.0
## What is drawn: the eased anchor point, ring radius and arrow direction, and the goal they chase.
var pos := Vector2.INF
var rad := 0.0
var dir := Vector2.DOWN
var goal: Dictionary = {}
var last_step := 0.0  ## pixels moved last frame (t_tutorial checks it stays bounded)

func _ready() -> void:
	name = "TutorialPointer"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	if _acc >= 0.2:  # the target search walks groups; 5 Hz is plenty for picking
		_acc = 0.0
		_target = Tutorial.pointer_target(player) if player else {}
		if not _target.is_empty() and int(_target.get("index", 0)) == 0 and _covered():
			_target = {}
	step(delta)
	visible = not _target.is_empty() and not goal.is_empty()
	if visible:
		queue_redraw()

## One frame of easing toward the current goal (public: tests drive it with a fixed delta).
func step(delta: float) -> void:
	goal = goal_for(_target)
	if goal.is_empty():
		pos = Vector2.INF
		last_step = 0.0
		return
	var g: Vector2 = goal["p"]
	if pos == Vector2.INF:
		pos = g
		rad = float(goal.get("rad", 0.0))
		dir = goal.get("dir", Vector2.DOWN)
		last_step = 0.0
		return
	var a := 1.0 - exp(-SMOOTH_K * delta)
	var want := (g - pos) * a
	if want.length() > MAX_PX_S * delta:
		want = want.normalized() * MAX_PX_S * delta
	pos += want
	last_step = want.length()
	rad = lerpf(rad, float(goal.get("rad", 0.0)), a)
	var gd: Vector2 = goal.get("dir", Vector2.DOWN)
	dir = dir.lerp(gd, a).normalized() if dir.lerp(gd, a).length() > 0.01 else gd

func set_target(t: Dictionary) -> void:
	_target = t

## Where the pointer wants to be for `t`: {"p", "dir", "rad", "kind": ui|world|edge, "ground"} or {}.
func goal_for(t: Dictionary) -> Dictionary:
	if t.is_empty():
		return {}
	if t.has("ui"):
		var c := t["ui"] as Control
		if c == null or not is_instance_valid(c):
			return {}
		var r := c.get_global_rect()
		var cue := int(t.get("cue", 0))
		if cue != 0 and t.get("scroll") is ScrollContainer:
			var v := (t["scroll"] as ScrollContainer).get_global_rect()
			return {"kind": "cue", "p": Vector2(v.get_center().x, v.end.y - 10.0 if cue > 0 else v.position.y + 10.0), "dir": Vector2(0, float(cue)), "rad": 0.0}
		return {"kind": "ui", "p": r.get_center() - get_global_rect().position, "rad": maxf(r.size.x, r.size.y) * 0.5 + 6.0, "dir": Vector2.DOWN, "rect": r}
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam == null or not t.has("world"):
		return {}
	var at := world_anchor(t)
	if cam.is_position_behind(at + Vector3.UP * 1.6):
		return {}
	var view := get_viewport_rect()
	var margin := 48.0
	var sp := cam.unproject_position(at + Vector3.UP * 1.6)
	if view.grow(-margin).has_point(sp):
		return {"kind": "world", "p": sp, "dir": Vector2.DOWN, "rad": 16.0, "ground": cam.unproject_position(at) - sp}
	var d := (sp - view.get_center()).normalized()
	return {"kind": "edge", "p": Vector2(clampf(sp.x, margin, view.size.x - margin), clampf(sp.y, margin, view.size.y - margin)), "dir": d, "rad": 0.0}

## The world point a target stands for this frame: its node's position when it has one (it moves).
static func world_anchor(t: Dictionary) -> Vector3:
	var node: Variant = t.get("node")
	if node is Node3D and is_instance_valid(node):
		return (node as Node3D).global_position
	return t.get("world", Vector3.ZERO)

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
	if goal.is_empty() or pos == Vector2.INF:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	match str(goal["kind"]):
		"cue":
			_arrow(pos + dir * 6.0 * pulse, dir)
			_caption(Rect2(pos - Vector2(0.0, 40.0 if dir.y > 0.0 else -40.0), Vector2.ZERO), "Scroll down" if dir.y > 0.0 else "Scroll up")
		"ui":
			var r: Rect2 = goal["rect"]
			if _target.has("caption"):
				_caption(Rect2(pos - r.size * 0.5, r.size), str(_target["caption"]))
			var rr := rad + 6.0 * pulse
			draw_arc(pos, rr, 0.0, TAU, 48, Color(GOLD, 0.95), 4.0, true)
			draw_arc(pos, rr + 8.0, 0.0, TAU, 48, Color(GOLD, 0.35 * (1.0 - pulse)), 3.0, true)
			_arrow(pos - Vector2(0.0, rr + 10.0 + 8.0 * pulse), Vector2.DOWN)
		"world":
			draw_arc(pos + (goal["ground"] as Vector2), 16.0 + 6.0 * pulse, 0.0, TAU, 32, Color(GOLD, 0.8), 3.0, true)
			_arrow(pos - Vector2(0.0, 14.0 * pulse), dir)
		_:
			# Off screen: an edge arrow pointing the way.
			_arrow(pos - dir * 6.0 * pulse, dir)

func _arrow(tip: Vector2, dir: Vector2) -> void:
	var back := -dir
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([tip, tip + back * 26.0 + side * 15.0, tip + back * 16.0, tip + back * 26.0 - side * 15.0])
	draw_colored_polygon(pts, GOLD)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.1, 0.08, 0.02, 0.9), 2.0, true)
	draw_line(tip + back * 18.0, tip + back * 44.0, GOLD, 6.0, true)

## "Tap Materials" beside the ringed control: above it, or below when it sits at the top edge.
func _caption(r: Rect2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var px := 18
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 20.0
	var view := get_viewport_rect().size
	var y := r.position.y - 64.0 if r.position.y > 90.0 else r.end.y + 18.0
	var box := Rect2(Vector2(clampf(r.get_center().x - w * 0.5, 4.0, view.x - w - 4.0), y), Vector2(w, 28.0))
	draw_rect(box, Color(0.08, 0.07, 0.04, 0.92))
	draw_rect(box, GOLD, false, 2.0)
	draw_string(font, box.position + Vector2(10.0, 20.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, GOLD)
