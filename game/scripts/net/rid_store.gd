class_name RidStore
extends RefCounted
## The last PER_ACCOUNT mutating responses per account (contracts.md §4, §5.3), kept across
## restarts: each one is appended to rids.jsonl and flushed before the response is sent, and
## open() reloads the file. The file is rewritten (tmp + rename) on open and whenever it holds
## several times more lines than the cache, so its size follows the cache, not the uptime.
## ASSUMPTION: §5.2 names only snapshot.json and journal.jsonl. Rids get their own file so every
## mutating op is idempotent across a restart whether or not its owner journals.

const FILE := "rids.jsonl"
const PER_ACCOUNT := 64
const MIN_COMPACT := 4096  # lines

var path := ""
var _caches: Dictionary = {}  # account_id -> {rid -> {op, res}}, oldest first
var _entries := 0
var _lines := 0
var _file: FileAccess
var _rid_re := RegEx.create_from_string("^[A-Za-z0-9-]{8,64}$")

## Loads dir/rids.jsonl. A torn last line (the server died mid-write, before that response was
## sent) is dropped; any other bad line is corruption and refuses to open.
func open(dir: String) -> Error:
	close()
	_caches.clear()
	_entries = 0
	path = dir.path_join(FILE)
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		if text == "" and FileAccess.get_open_error() != OK:
			return FileAccess.get_open_error()
		var lines := text.split("\n", false)
		for i in lines.size():
			if not _admit(lines[i]) and i < lines.size() - 1:
				return ERR_FILE_CORRUPT
	return _compact()

func close() -> void:
	if _file != null:
		_file.close()
		_file = null

func is_open() -> bool:
	return _file != null

func lookup(aid: int, rid: String) -> Dictionary:
	return (_caches.get(aid, {}) as Dictionary).get(rid, {})

func count(aid: int) -> int:
	return (_caches.get(aid, {}) as Dictionary).size()

## Records op's response under rid; OK once it is flushed to disk. A rid already held is kept as is.
func remember(aid: int, rid: String, op: String, res: Dictionary) -> Error:
	if not lookup(aid, rid).is_empty():
		return OK
	_put(aid, rid, op, res.duplicate(true))
	if _file == null:
		return ERR_FILE_CANT_WRITE
	_file.store_line(JSON.stringify({"acc": aid, "rid": rid, "op": op, "res": res}))
	_file.flush()  # survives a process crash; power loss needs fsync, which GDScript does not expose
	_lines += 1
	var err := _file.get_error()
	if err == OK and _lines > maxi(MIN_COMPACT, 2 * _entries):
		err = _compact()
	return err

func _admit(line: String) -> bool:
	var json := JSON.new()
	if json.parse(line) != OK or not json.data is Dictionary:
		return false
	var row: Dictionary = json.data
	var aid: Variant = NetProtocol.as_int(row.get("acc"), 0, NetProtocol.MAX_ID)
	var rid: Variant = row.get("rid")
	var op: Variant = row.get("op")
	if aid == null or not rid is String or _rid_re.search(rid) == null or not op is String \
			or not NetProtocol.is_result(row.get("res")):
		return false
	_put(aid, rid, op, row["res"])
	return true

func _put(aid: int, rid: String, op: String, res: Dictionary) -> void:
	var cache: Dictionary = _caches.get(aid, {})
	if cache.is_empty():
		_caches[aid] = cache
	if not cache.has(rid):
		_entries += 1
	cache[rid] = {"op": op, "res": res}
	while cache.size() > PER_ACCOUNT:
		cache.erase(cache.keys()[0])  # dictionaries keep insertion order: oldest first
		_entries -= 1

func _compact() -> Error:
	close()
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	for aid: int in _caches:
		var cache: Dictionary = _caches[aid]
		for rid: String in cache:
			f.store_line(JSON.stringify({"acc": aid, "rid": rid, "op": cache[rid]["op"], "res": cache[rid]["res"]}))
	f.flush()
	var err := f.get_error()
	f.close()
	if err == OK:
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	_lines = _entries
	_file = FileAccess.open(path, FileAccess.READ_WRITE)
	if _file == null:
		return FileAccess.get_open_error()
	_file.seek_end()
	return OK
