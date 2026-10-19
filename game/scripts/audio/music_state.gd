class_name MusicState
extends RefCounted
## Music mood with hysteresis: combat needs a sustained threat to start and a long calm to end,
## so a creature stepping in and out of range never flickers the score.

const ENTER_COMBAT_S := 0.8
const EXIT_COMBAT_S := 10.0

var state: StringName = &"explore"
var _threat_s: float = 0.0
var _calm_s: float = 0.0

## force_combat: the survivor dealt or took damage this frame (skips the enter delay).
func update(delta: float, threat: bool, night: bool, force_combat: bool = false) -> StringName:
	if threat or force_combat:
		_threat_s += delta
		_calm_s = 0.0
	else:
		_calm_s += delta
		_threat_s = 0.0
	var calm_state: StringName = &"night" if night else &"explore"
	if state == &"combat":
		if _calm_s >= EXIT_COMBAT_S:
			state = calm_state
	elif force_combat or _threat_s >= ENTER_COMBAT_S:
		state = &"combat"
	else:
		state = calm_state
	return state
