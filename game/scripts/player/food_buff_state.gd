class_name FoodBuffState
extends RefCounted
## Timed food effects, kept outside Player so survival state has one owner.

var _active: Dictionary = {} ## buff_id -> {time_left, row}

func apply(buff_id: StringName, row: Dictionary) -> void:
	_active[str(buff_id)] = {
		"time_left": float(row.get("duration", 300.0)),
		"row": row.duplicate(true),
	}

func tick(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: Array[String] = []
	for id in _active:
		_active[id]["time_left"] = float(_active[id].get("time_left", 0.0)) - delta
		if float(_active[id]["time_left"]) <= 0.0:
			expired.append(str(id))
	for id in expired:
		_active.erase(id)

func multiplier(stat: String) -> float:
	var value := 1.0
	for id in _active:
		var row: Dictionary = _active[id].get("row", {})
		if str(row.get("stat", "")) == stat and row.has("mult"):
			value *= float(row.get("mult", 1.0))
	return value

func to_dict() -> Dictionary:
	return _active.duplicate(true)

func from_dict(raw: Dictionary) -> void:
	_active = raw.duplicate(true)
