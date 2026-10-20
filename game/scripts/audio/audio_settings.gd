class_name AudioSettings
extends Control
## Sound settings: one slider per mix bus (Master, Music, Ambience, SFX, Creatures, UI) plus
## Mute all. A slider scales its bus around the designed level in default_bus_layout.tres and
## saves through Settings (user://settings.cfg), so the level is still there next boot.
##
## Built in code and opened as a full-screen sheet over whatever screen calls it. One menu hook
## is all a caller needs: `AudioSettings.open_in(get_tree().current_scene)` (or the HUD's modal
## CanvasLayer), then close with the ✕ button, Escape or a tap outside.
## The mute hotkey is the `mute_audio` input action (F10), handled by AudioDirector.

const MIX_BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"Creatures", &"UI"]
const NAMES := {&"Master": "Master", &"Music": "Music", &"Ambience": "Ambience", &"SFX": "Effects",
	&"Creatures": "Creatures", &"UI": "Interface"}
const TAP_PX := 64.0

var director: AudioDirector
var _panel: PanelContainer
var _box: VBoxContainer
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _mute: CheckButton

## Make the panel as a child of `host` and show it. Returns the panel so callers can keep it.
## A Node3D or Node host gets its own CanvasLayer: a Control parented straight to the 3D scene
## root renders but does not resolve its anchors, so the sheet would hang off the top-left.
static func open_in(host: Node) -> AudioSettings:
	var p := AudioSettings.new()
	p.name = "AudioSettings"
	if host is CanvasLayer or host is Control:
		host.add_child(p)
	else:
		var layer := CanvasLayer.new()
		layer.name = "AudioSettingsLayer"
		layer.layer = 99
		host.add_child(layer)
		layer.add_child(p)
	p.open()
	return p

func _ready() -> void:
	# A Control directly under a CanvasLayer anchors to the viewport; set both so the sheet fills it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if director == null:
		director = Game.audio
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.gui_input.connect(func (ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			close()
	)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 0)
	_panel.add_theme_stylebox_override("panel", UiTokens.panel_style(0.98))
	centre.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", UiTokens.SPACE / 2)
	_panel.add_child(_box)
	_build()
	_refresh()

func _build() -> void:
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Sound"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(TAP_PX, TAP_PX)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	_box.add_child(head)
	var hint := Label.new()
	hint.text = "Tap a bar to set a level. Mute all silences the game."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", UiTokens.META)
	_box.add_child(hint)
	for bus in MIX_BUSES:
		_add_row(bus)
	_mute = CheckButton.new()
	_mute.text = "Mute all"
	_mute.custom_minimum_size = Vector2(0, TAP_PX)
	_mute.add_theme_font_size_override("font_size", 20)
	_mute.toggled.connect(_on_mute_toggled)
	_box.add_child(_mute)

## One 64 px row per bus: name, drag strip, value. Laid out in one line so six buses plus Mute all
## still fit a 640 px-tall phone without scrolling.
func _add_row(bus: StringName) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, TAP_PX)
	var name_label := Label.new()
	name_label.text = str(NAMES.get(bus, bus))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = "100%"
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", UiTokens.META)
	value_label.custom_minimum_size = Vector2(96, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.name = "Slider_%s" % bus
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(TAP_PX * 2.0, TAP_PX)  # the drag strip itself is a full tap target
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(bus, value_label))
	row.add_child(slider)
	row.add_child(value_label)
	_box.add_child(row)
	_sliders[bus] = slider
	_values[bus] = value_label

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if director == null:
		return
	for bus in _sliders:
		var v := director.bus_volume(bus)
		(_sliders[bus] as HSlider).set_value_no_signal(v)
		_show_value(bus, v)
	_mute.set_pressed_no_signal(director.muted)

func _on_slider_changed(value: float, bus: StringName, label: Label) -> void:
	if director:
		director.set_bus_volume(bus, value)
	_show_value(bus, value)
	if label != null:
		label.text = _value_text(value)

func _show_value(bus: StringName, value: float) -> void:
	var l: Label = _values.get(bus)
	if l:
		l.text = _value_text(value)

func _value_text(value: float) -> String:
	if value <= 0.001:
		return "off"
	var db := linear_to_db(value)
	return "%d%%" % roundi(value * 100.0) if db > -0.05 else "%d%%   %.0f dB" % [roundi(value * 100.0), db]

func _on_mute_toggled(pressed: bool) -> void:
	if director:
		director.set_muted(pressed)
	for bus in _sliders:
		(_sliders[bus] as HSlider).editable = not pressed
