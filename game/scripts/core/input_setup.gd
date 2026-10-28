extends Node
## Registers the project's input actions at boot so they live in one readable
## place instead of the serialized [input] block of project.godot.
## Cursor: migrate these to Project Settings > Input Map if you prefer, but keep
## the action NAMES stable; gameplay scripts reference them by string.

const ACTIONS: Dictionary = {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	# ASSUMPTION: Q takes the keyboard roll after the owner assigned Space to quick gather.
	"roll": [KEY_Q],
	"interact": [KEY_E],
	"gather_nearest": [KEY_SPACE],
	"rest": [KEY_X],
	"attack": [KEY_F],
	"tactic_1": [KEY_1],
	"tactic_2": [KEY_2],
	"tactic_3": [KEY_3],
	"tactic_4": [KEY_4],
	"inventory": [KEY_I],
	"craft": [KEY_C],
	"debug_toggle": [KEY_F3],
	"touch_toggle": [KEY_F4],
	"show_grid": [KEY_F6],
	"bandage": [KEY_B],
	"hunt_chase": [KEY_H],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"place_rotate": [KEY_R],
	"place_confirm": [KEY_ENTER, KEY_KP_ENTER],
	"place_cancel": [KEY_ESCAPE],
	"fullscreen": [KEY_F11],
}

## Gamepad layout (Xbox naming; Godot maps PlayStation and Switch pads to the same indices).
## Left stick moves, A interacts and gathers, X attacks, B rolls, Y opens crafting, LB and RB are
## tackle and kick, the triggers are the two other tactics, Back opens the bag, Start pauses, the
## right stick click opens the map. While placing a building A confirms, B cancels and RB rotates.
const JOY_BUTTONS: Dictionary = {
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"roll": [JOY_BUTTON_B],
	"interact": [JOY_BUTTON_A],
	"attack": [JOY_BUTTON_X],
	"craft": [JOY_BUTTON_Y],
	"tactic_1": [JOY_BUTTON_LEFT_SHOULDER],
	"tactic_2": [JOY_BUTTON_RIGHT_SHOULDER],
	"inventory": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
	"map": [JOY_BUTTON_RIGHT_STICK],
	"bandage": [JOY_BUTTON_DPAD_DOWN],
	"hunt_chase": [JOY_BUTTON_DPAD_UP],
	"place_confirm": [JOY_BUTTON_A],
	"place_cancel": [JOY_BUTTON_B],
	"place_rotate": [JOY_BUTTON_RIGHT_SHOULDER],
}
## [axis, sign] pairs. Stick directions drive movement; triggers are tactics 3 and 4.
const JOY_AXES: Dictionary = {
	"move_left": [[JOY_AXIS_LEFT_X, -1.0]],
	"move_right": [[JOY_AXIS_LEFT_X, 1.0]],
	"move_up": [[JOY_AXIS_LEFT_Y, -1.0]],
	"move_down": [[JOY_AXIS_LEFT_Y, 1.0]],
	"tactic_3": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"tactic_4": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
}
const STICK_DEADZONE := 0.25

func _init() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in JOY_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: JoyButton in JOY_BUTTONS[action]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
	for action: String in JOY_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for pair: Array in JOY_AXES[action]:
			var jm := InputEventJoypadMotion.new()
			jm.axis = pair[0]
			jm.axis_value = pair[1]
			InputMap.action_add_event(action, jm)
		InputMap.action_set_deadzone(action, STICK_DEADZONE)
	# Primary mouse button doubles as tap-to-gather / tap-to-attack.
	if not InputMap.has_action("tap"):
		InputMap.add_action("tap")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("tap", mb)
