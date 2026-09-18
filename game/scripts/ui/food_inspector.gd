class_name FoodInspector
extends PanelContainer
## Tap-food panel: energy, level, process, buffs, raw/poisoned before eat (PRD §21.3).

signal eat_pressed(slot_index: int)
signal feed_pressed(slot_index: int)
signal closed

var slot_index: int = -1
var _title: Label
var _body: Label
var _eat_btn: Button
var _feed_btn: Button
var _close_btn: Button

func _ready() -> void:
	visible = false
	z_index = 55
	custom_minimum_size = Vector2(320, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(280, 100)
	box.add_child(_body)
	_eat_btn = Button.new()
	_eat_btn.text = "Eat"
	_eat_btn.custom_minimum_size = Vector2(280, 64)
	_eat_btn.pressed.connect(func () -> void: eat_pressed.emit(slot_index); hide_panel())
	box.add_child(_eat_btn)
	_feed_btn = Button.new()
	_feed_btn.text = "Feed pet"
	_feed_btn.custom_minimum_size = Vector2(280, 64)
	_feed_btn.pressed.connect(func () -> void: feed_pressed.emit(slot_index); hide_panel())
	box.add_child(_feed_btn)
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.custom_minimum_size = Vector2(280, 64)
	_close_btn.pressed.connect(hide_panel)
	box.add_child(_close_btn)

func show_stack(stack: ItemStack, index: int, can_feed: bool = false) -> void:
	slot_index = index
	_title.text = "Food"
	_body.text = Food.inspector_text(stack)
	_eat_btn.disabled = Food.can_eat(_player_from_tree(), stack) != ""
	_feed_btn.visible = can_feed
	visible = true
	# Centre-ish for phone one-hand reach.
	var vp := get_viewport_rect().size
	position = Vector2(maxi(16, int(vp.x * 0.5 - 160)), maxi(80, int(vp.y * 0.25)))

func hide_panel() -> void:
	visible = false
	slot_index = -1
	closed.emit()

func _player_from_tree() -> Player:
	return get_tree().get_first_node_in_group("player") as Player
