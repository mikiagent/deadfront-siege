class_name HudEventState
extends RefCounted
## Short-lived HUD messages and hit effects. HuntHud renders this state but no longer owns its lifecycle.

var toasts: Array = []
var notices: Array = []
var bites: Array = []
var player_floats: Array = []

func add_bite(amount: float, heavy: bool) -> void:
	bites.append({"t": 0.0, "heavy": heavy, "x": randf_range(-6.0, 6.0)})
	player_floats.append({"t": 0.0, "n": amount, "x": randf_range(-18.0, 18.0)})

func add_notice(text: String) -> void:
	for entry in notices:
		if entry["text"] == text and entry["t"] < 1.5:
			entry["t"] = 0.0
			return
	notices.append({"text": text, "t": 0.0})

func add_toast(id: StringName, count: int) -> void:
	for entry in toasts:
		if entry["id"] == id and entry["t"] < 0.6:
			entry["n"] += count
			entry["t"] = 0.0
			return
	toasts.append({"id": id, "n": count, "t": 0.0})

func tick(delta: float) -> void:
	for entry in toasts:
		entry["t"] += delta
	toasts = toasts.filter(func(entry: Dictionary) -> bool: return entry["t"] < 1.3)
	for entry in notices:
		entry["t"] += delta
	notices = notices.filter(func(entry: Dictionary) -> bool: return entry["t"] < 3.2)
	for entry in bites:
		entry["t"] += delta
	bites = bites.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.5)
	for entry in player_floats:
		entry["t"] += delta
	player_floats = player_floats.filter(func(entry: Dictionary) -> bool: return entry["t"] < 0.95)
