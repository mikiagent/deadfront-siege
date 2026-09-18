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
	"roll": [KEY_SPACE],
	"interact": [KEY_E],
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
}

func _init() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	# Primary mouse button doubles as tap-to-gather / tap-to-attack.
	if not InputMap.has_action("tap"):
		InputMap.add_action("tap")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("tap", mb)
