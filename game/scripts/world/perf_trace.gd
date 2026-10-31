class_name PerfTrace
extends RefCounted
## BUILDSPEED: a lightweight phase timer for the island build. Off unless the environment asks for
## it (BUILD_PROFILE=1, or ISL_TIME=1 which already prints the coarse islandgen line), so normal
## play and the other labs pay one bool check per mark.
## Usage: PerfTrace.start("home_grassland"); PerfTrace.mark("shape"); ... PerfTrace.finish().
## `mark` closes the phase opened by the previous mark (or by start) and opens the next one; the
## table prints "[buildprofile] island=<id> <phase>=<ms> ... total=<ms>".

## A test can turn the table on itself (the gate runs without the env var).
static var force: bool = false
static var _on := false
static var _label := ""
static var _last_usec := 0
static var _rows: Array[String] = []
static var _ms: Dictionary = {}

static func _env_on() -> bool:
	if force:
		return true
	return OS.get_environment("BUILD_PROFILE") == "1" or OS.get_environment("ISL_TIME") == "1"

static func start(label: String) -> void:
	_on = _env_on()
	if not _on:
		return
	_label = label
	_rows.clear()
	_ms.clear()
	_last_usec = Time.get_ticks_usec()

static func is_on() -> bool:
	return _on

## Close the phase since the last mark and open a new one named `phase`.
static func mark(phase: String) -> void:
	LoadingScreen.stage(phase)  # LOADING: the overlay's bar follows the build's stages (no-op when none is up)
	if not _on:
		return
	var now := Time.get_ticks_usec()
	var d := float(now - _last_usec) / 1000.0
	_last_usec = now
	var prev := float(_ms.get(phase, 0.0)) + d
	_ms[phase] = prev
	if not _rows.has(phase):
		_rows.append(phase)

## Close the last phase and print the table.
static func finish() -> void:
	if not _on:
		LoadingScreen.stage("__end")
		return
	mark("__end")
	_on = false
	var parts := PackedStringArray()
	var total := 0.0
	for phase in _rows:
		if phase == "__end":
			continue
		var v := float(_ms.get(phase, 0.0))
		total += v
		parts.append("%s=%.0f" % [phase, v])
	print("[buildprofile] island=%s %s total=%.0f" % [_label, " ".join(parts), total])
