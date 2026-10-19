class_name Settings
extends RefCounted
## Tiny persistent key/value store in user://settings.cfg (player preferences, not save data).

const PATH := "user://settings.cfg"

static var _cfg: ConfigFile

static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)  # a missing file just means defaults
	return _cfg

static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _file().get_value(section, key, default)

static func set_value(section: String, key: String, value: Variant) -> void:
	_file().set_value(section, key, value)
	var err := _file().save(PATH)
	if err != OK:
		push_warning("[settings] save failed (%d)" % err)
