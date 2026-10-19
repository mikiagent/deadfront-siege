class_name EconStore
extends RefCounted
## Durability for MarketEngine (contract 5.2): every mutating op is appended to journal.jsonl
## and flushed before apply() returns, so a response is never sent for an op that could be
## lost. snapshot.json is written to .tmp, flushed and renamed over the old one, then the
## journal is truncated. Boot = load snapshot, replay journal entries with seq > snapshot seq
## through the same apply(), discarding a torn last line.
## Limit: FileAccess.flush hands bytes to the OS (fflush), not fsync; a process crash is safe,
## a kernel or power loss can drop the last few ops.

var engine: MarketEngine
var dir: String
var snapshot_every_ops := 500 ## 0 disables automatic snapshots
var snapshot_every_s := 60
var _journal: FileAccess
var _ops_since := 0
var _snap_ts := 0

func _init(p_engine: MarketEngine, p_dir: String) -> void:
	engine = p_engine
	dir = p_dir

func snapshot_path() -> String:
	return dir.path_join("snapshot.json")

func journal_path() -> String:
	return dir.path_join("journal.jsonl")

## Loads the snapshot and replays the journal. Returns "" or why boot must stop.
func open() -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(snapshot_path()):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path()))
		if not parsed is Dictionary:
			return "snapshot.json is unreadable"
		engine.load_state(parsed)
	var why := replay_file(journal_path())
	if why != "":
		return why
	_journal = FileAccess.open(journal_path(), FileAccess.READ_WRITE if FileAccess.file_exists(journal_path()) else FileAccess.WRITE)
	if _journal == null:
		return "cannot open journal (%d)" % FileAccess.get_open_error()
	_journal.seek_end()
	_snap_ts = int(engine.state().last_ts)
	return ""

## Replays journal lines newer than the engine's seq. A bad final line is a torn write and is
## cut from the file; a bad line before the end, or a seq that does not follow, is corruption.
func replay_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	if lines.size() > 0 and lines[lines.size() - 1] == "":
		lines.remove_at(lines.size() - 1)
	var good: PackedStringArray = []
	for i in lines.size():
		var row: Variant = JSON.parse_string(lines[i])
		var valid: bool = row is Dictionary and (row as Dictionary).has_all(["seq", "ts", "account", "op", "a"]) and row.a is Dictionary
		if not valid:
			if i == lines.size() - 1:
				print("[econ] discarding torn journal line %d" % (i + 1))
				_rewrite(path, good)
				break
			return "journal line %d is corrupt" % (i + 1)
		good.append(lines[i])
		var seq := int(row.seq)
		if seq <= engine.seq():
			continue
		if seq != engine.seq() + 1:
			return "journal jumps from seq %d to %d" % [engine.seq(), seq]
		var res := engine.apply(str(row.op), int(row.account), row.a, int(row.ts))
		if engine.seq() != seq:
			return "journal seq %d did not replay (%s)" % [seq, str(res.get("msg", ""))]
	return ""

## Applies one op; journals and flushes it before returning when it changed state.
func apply(op: String, account_id: int, args: Dictionary, ts: int) -> Dictionary:
	var before := engine.seq()
	var res := engine.apply(op, account_id, args, ts)
	if engine.seq() == before:
		return res
	var entry := {"seq": engine.seq(), "ts": int(engine.state().last_ts), "account": account_id, "op": op, "a": args}
	_journal.store_line(JSON.stringify(entry, "", true, true))
	_journal.flush()
	_ops_since += 1
	if snapshot_every_ops > 0 and (_ops_since >= snapshot_every_ops or int(engine.state().last_ts) - _snap_ts >= snapshot_every_s):
		var why := snapshot()
		if why != "":
			push_error("[econ] snapshot failed: %s" % why)
	return res

## Atomic snapshot (tmp + flush + rename), then the journal restarts empty.
func snapshot() -> String:
	var tmp := snapshot_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%d)" % [tmp, FileAccess.get_open_error()]
	f.store_string(engine.state_json())
	f.flush()
	f.close()
	var err := DirAccess.rename_absolute(tmp, snapshot_path())
	if err != OK:
		return "rename failed (%d)" % err
	# Every journaled op is now inside the snapshot (seq <= snapshot seq), so the journal can go.
	if _journal:
		_journal.close()
	_journal = FileAccess.open(journal_path(), FileAccess.WRITE)
	_ops_since = 0
	_snap_ts = int(engine.state().last_ts)
	return "" if _journal != null else "cannot reopen journal"

func close() -> void:
	if _journal:
		_journal.flush()
		_journal.close()
		_journal = null

static func _rewrite(path: String, lines: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for line in lines:
		f.store_line(line)
	f.close()
