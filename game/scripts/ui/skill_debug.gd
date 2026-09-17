class_name SkillDebug
extends Control
## F7 panel. ASSUMPTION: no SP economy; nodes are free toggles.

var _open: bool = false
var _box: VBoxContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(1100, 40)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.9)
	bg.size = Vector2(360, 420)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.position = Vector2(8, 8)
	add_child(_box)
	_rebuild()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		_open = not _open
		visible = _open
		if _open:
			_rebuild()

func _rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "Survival (debug, no SP)"
	_box.add_child(title)
	for id: StringName in Data.survival_nodes:
		var b := CheckBox.new()
		b.text = str(id)
		b.button_pressed = Data.is_survival_unlocked(id)
		var node_id: StringName = id
		b.toggled.connect(func (on: bool) -> void: Data.set_survival_unlocked(node_id, on))
		_box.add_child(b)
