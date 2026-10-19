class_name EconStore
extends RefCounted
## Durability for MarketEngine (contract 5.2): every mutating op is appended to journal.jsonl
## and flushed before apply() returns, so a response is never sent for an op that could be
## lost. A snapshot is written to .tmp and read back before it replaces anything; then the
## journal it covers rotates to journal.prev.jsonl and the snapshot it replaces to
## snapshot.prev.json. Boot = newest readable snapshot, then both journals (entries with
## seq > the snapshot's) through the same apply(), repairing a torn tail.
## Limit: Godot has no fsync. flush() hands bytes to the OS, so a process crash loses nothing
## that was acknowledged. A power cut can lose ops the OS had not yet written back; a snapshot
## that never reached the disk boots from the previous generation, and a gap in seq stops boot.

const DEFAULT_DIR := "user://server" ## contract 5.2; the server may pass --data=<dir> instead

var engine: MarketEngine
var dir: String
var snapshot_every_ops := 500 ## 0 disables automatic snapshots
var snapshot_every_s := 60
var broken := "" ## set when the disk cannot be trusted any more; the store then refuses every op
var _journal: FileAccess
var _ops_since := 0
var _snap_ts := 0

func _init(p_engine: MarketEngine, p_dir: String) -> void:
	engine = p_engine
	dir = p_dir

func snapshot_path(prev: bool = false) -> String:
	return dir.path_join("snapshot.prev.json" if prev else "snapshot.json")

func journal_path(prev: bool = false) -> String:
	return dir.path_join("journal.prev.jsonl" if prev else "journal.jsonl")

## Loads the newest readable snapshot and replays both journals. Returns "" or why boot must stop.
func open() -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var why := _load_snapshot()
	for path in [journal_path(true), journal_path()]:
		if why == "":
			why = replay_file(path)
	if why != "":
		return why
	_journal = FileAccess.open(journal_path(), FileAccess.READ_WRITE if FileAccess.file_exists(journal_path()) else FileAccess.WRITE)
	if _journal == null:
		return "cannot open journal (%d)" % FileAccess.get_open_error()
	_journal.seek_end()
	_ops_since = 0
	_snap_ts = int(engine.state().last_ts)
	engine.drain_events() # replayed ops pushed their events when they first ran
	return ""

## Rebuilds memory from disk (snapshot + journals), which never saw an op that faulted.
func reload() -> String:
	close()
	engine.reset()
	return open()

func _load_snapshot() -> String:
	var bad: PackedStringArray = []
	for prev in [false, true]:
		var path := snapshot_path(prev)
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = _parse(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or not (parsed as Dictionary).has("seq"):
			bad.append("%s is unreadable" % path.get_file())
			continue
		if int(parsed.get("v", 0)) != Ledger.VERSION:
			return "%s is state version %d; this build reads %d" % [path.get_file(), int(parsed.get("v", 0)), Ledger.VERSION]
		engine.load_state(parsed)
		if prev and FileAccess.file_exists(snapshot_path()):
			# Keep the bad file out of the next rotation, so snapshot.prev.json stays a good one.
			push_warning("[econ] %s; booted from snapshot.prev.json" % ", ".join(bad))
			DirAccess.rename_absolute(snapshot_path(), dir.path_join("snapshot.bad.json"))
		return ""
	return "" if bad.is_empty() else "no readable snapshot (%s)" % ", ".join(bad)

## Replays journal lines newer than the engine's seq. A final line with no newline is a torn
## write: cut it off the file, or, when it parses, keep it and restore its newline so the next
## append starts a new line. A bad line before the end, or a seq that does not follow, is corruption.
func replay_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	var start := 0
	var line := 0
	while start < bytes.size():
		line += 1
		var nl := bytes.find(10, start)
		var row: Variant = _parse(bytes.slice(start, nl if nl >= 0 else bytes.size()).get_string_from_utf8())
		var valid: bool = row is Dictionary and (row as Dictionary).has_all(["seq", "ts", "account", "op", "a"]) and row.a is Dictionary
		if not valid:
			if nl >= 0:
				return "%s line %d is corrupt" % [path.get_file(), line]
			print("[econ] cutting torn line %d off %s" % [line, path.get_file()])
			return _repair(path, start, false)
		var seq := int(row.seq)
		if seq > engine.seq():
			if seq != engine.seq() + 1:
				return "%s jumps from seq %d to %d" % [path.get_file(), engine.seq(), seq]
			var res := engine.apply(str(row.op), int(row.account), row.a, int(row.ts))
			if engine.seq() != seq:
				return "%s seq %d did not replay (%s)" % [path.get_file(), seq, str(res.get("msg", ""))]
		if nl < 0:
			return _repair(path, bytes.size(), true)
		start = nl + 1
	return ""

## JSON.parse_string logs an error on bad text; torn lines are expected here, so parse quietly.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null

## Truncates the file to `keep` bytes in place (no rewrite, so a crash here cannot cut good
## lines), then optionally appends the missing newline. A failed repair stops boot.
static func _repair(path: String, keep: int, newline: bool) -> String:
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return "cannot repair %s (%d)" % [path.get_file(), FileAccess.get_open_error()]
	var ok := f.resize(keep) == OK
	if ok and newline:
		f.seek_end()
		ok = f.store_8(10)
		f.flush()
		ok = ok and f.get_error() == OK
	f.close()
	return "" if ok else "cannot repair %s" % path.get_file()

## Applies one op; journals and flushes it before returning when it changed state.
## The engine sees the args parsed back from the exact text the journal stores, so a replay
## reads the same numbers the live op did (JSON floats do not always survive a round trip).
func apply(op: String, account_id: int, args: Dictionary, ts: int) -> Dictionary:
	if _journal == null or broken != "":
		return EconArgs.no("server_error", "economy store is not writable (%s)" % (broken if broken != "" else "not open"))
	var text := JSON.stringify(args, "", true, true)
	var wire: Variant = JSON.parse_string(text)
	var before := engine.seq()
	var res := engine.apply(op, account_id, wire if wire is Dictionary else {}, ts)
	if engine.fault != "":
		push_warning("[econ] %s; reloading the books from disk" % engine.fault)
		var why := reload()
		if why != "":
			broken = "reload after a fault failed: %s" % why
			push_error("[econ] %s" % broken)
		return res
	if engine.seq() == before:
		return res
	var at := _journal.get_position()
	var wrote := _journal.store_line('{"a":%s,"account":%d,"op":%s,"seq":%d,"ts":%d}' % [text, account_id, JSON.stringify(op), engine.seq(), int(engine.state().last_ts)])
	_journal.flush()
	if not wrote or _journal.get_error() != OK:
		# Memory is now ahead of disk. Take back any partial line, then refuse this and every
		# later op until a restart, so no client acts on a change the disk does not hold.
		broken = "journal write failed (%d)" % _journal.get_error()
		_journal.resize(at)
		push_error("[econ] %s" % broken)
		return EconArgs.no("server_error", broken)
	_ops_since += 1
	if snapshot_every_ops > 0 and (_ops_since >= snapshot_every_ops or int(engine.state().last_ts) - _snap_ts >= snapshot_every_s):
		var why := snapshot()
		if why != "":
			push_error("[econ] snapshot failed: %s" % why)
	return res

## Writes and verifies snapshot.json.tmp, then rotates: journal -> journal.prev, snapshot ->
## snapshot.prev, tmp -> snapshot, fresh journal. Every step leaves a bootable chain on disk.
func snapshot() -> String:
	var text := engine.state_json()
	var tmp := snapshot_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%d)" % [tmp.get_file(), FileAccess.get_open_error()]
	var wrote := f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	# Read it back before it replaces anything: a full disk must not cost the good snapshot.
	if not wrote or err != OK or FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return "snapshot did not verify (%d); kept the old one and the journal" % err
	close()
	var why := _rotate(journal_path(), journal_path(true))
	if why == "" and FileAccess.file_exists(snapshot_path()):
		why = _rotate(snapshot_path(), snapshot_path(true))
	if why == "" and DirAccess.rename_absolute(tmp, snapshot_path()) != OK:
		why = "cannot rename the snapshot into place"
	if why == "":
		_journal = FileAccess.open(journal_path(), FileAccess.WRITE)
		if _journal == null:
			why = "cannot open a new journal (%d)" % FileAccess.get_open_error()
	if why != "":
		# The disk still holds a bootable chain, but new ops could not be journaled: stop.
		broken = "snapshot rotation failed: %s" % why
		return broken
	_ops_since = 0
	_snap_ts = int(engine.state().last_ts)
	return ""

## Replaces `to` with `from`.
static func _rotate(from: String, to: String) -> String:
	if FileAccess.file_exists(to) and DirAccess.remove_absolute(to) != OK:
		return "cannot remove %s" % to.get_file()
	if FileAccess.file_exists(from) and DirAccess.rename_absolute(from, to) != OK:
		return "cannot rename %s" % from.get_file()
	return ""

func close() -> void:
	if _journal:
		_journal.flush()
		_journal.close()
		_journal = null
