class_name TouchGestures
extends Node
## Pinch (two fingers) or trackpad magnify to zoom the orthographic camera.

@export var min_size: float = 10.0
@export var max_size: float = 28.0

var joystick: TouchJoystick
var _touches: Dictionary = {}
var _last_dist: float = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
			_last_dist = 0.0
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() == 2 and not (joystick and joystick.active):
			var pts := _touches.values()
			var dist: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
			if _last_dist > 0.0 and dist > 0.0:
				_zoom(_last_dist / dist)
			_last_dist = dist

func _zoom(factor: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
		cam.size = clampf(cam.size * factor, min_size, max_size)
