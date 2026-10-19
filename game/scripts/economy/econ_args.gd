class_name EconArgs
extends RefCounted
## Reads one request's arguments with type, range, length and enum checks. The first bad
## field is remembered, so a handler reads everything, checks `err`, and only then mutates.
## Integers may arrive as integral floats (JSON parses every number as float).

const SAFE_INT := 9007199254740991 ## 2^53 - 1: beyond this a JSON double is not exact

var a: Dictionary
var err := ""

func _init(args: Dictionary) -> void:
	a = args

func has(key: String) -> bool:
	return a.has(key) and a[key] != null

func integer(key: String, lo: int, hi: int, default: Variant = null) -> int:
	if not has(key):
		if default == null:
			return _bad("%s is required" % key)
		return int(default)
	var v: Variant = as_int(a[key])
	if v == null:
		return _bad("%s must be an integer" % key)
	if int(v) < lo or int(v) > hi:
		return _bad("%s must be %d..%d" % [key, lo, hi])
	return int(v)

func one_of(key: String, options: Array, default: Variant = null) -> int:
	var v := integer(key, -SAFE_INT, SAFE_INT, default)
	if err == "" and v not in options:
		_bad("%s must be one of %s" % [key, str(options)])
	return v

func text(key: String, min_len: int, max_len: int, default: Variant = null) -> String:
	if not has(key):
		if default == null:
			_bad("%s is required" % key)
			return ""
		return str(default)
	if not (a[key] is String or a[key] is StringName):
		_bad("%s must be a string" % key)
		return ""
	var s := str(a[key])
	if s.length() < min_len or s.length() > max_len:
		_bad("%s must be %d..%d characters" % [key, min_len, max_len])
		return ""
	return s

func choice(key: String, options: Array, default: Variant = null) -> String:
	var s := text(key, 1, 32, default)
	if err == "" and s not in options:
		_bad("%s must be one of %s" % [key, ", ".join(options)])
	return s

func dict(key: String, required: bool = true) -> Dictionary:
	if not has(key):
		if required:
			_bad("%s is required" % key)
		return {}
	if not a[key] is Dictionary:
		_bad("%s must be an object" % key)
		return {}
	return a[key]

func fail() -> Dictionary:
	return {"ok": false, "err": "bad_request", "msg": err}

## `changed = false` marks a successful op that touched nothing (no seq, journal or rid entry).
static func ok(r: Dictionary, changed: bool = true) -> Dictionary:
	return {"ok": true, "r": r} if changed else {"ok": true, "r": r, "noop": true}

static func no(code: String, msg: String) -> Dictionary:
	return {"ok": false, "err": code, "msg": msg}

## Integral int or float within the exact-double range, else null.
static func as_int(v: Variant) -> Variant:
	if v is int:
		return v if absi(v) <= SAFE_INT else null
	if v is float and is_finite(v) and v == floorf(v) and absf(v) <= float(SAFE_INT):
		return int(v)
	return null

static func is_id(s: String) -> bool:
	if s.is_empty() or s.length() > 48:
		return false
	for ch in s:
		if not (ch >= "a" and ch <= "z") and not (ch >= "0" and ch <= "9") and ch != "_":
			return false
	return true

func _bad(msg: String) -> int:
	if err == "":
		err = msg
	return 0
