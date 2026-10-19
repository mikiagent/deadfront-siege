class_name AccountStore
extends RefCounted
## Online identity (contracts.md §3): id, name, sha256(token) and created. Wallets and vaults
## belong to the economy. The whole file is rewritten (tmp + rename) on every new account, so a
## crash leaves either the old or the new file, never half of one; the previous version is kept
## as accounts.json.bak for an operator to restore by hand.
## shortcut: O(accounts) per new account and no fsync (GDScript has none); move the rows into the
## economy snapshot and journal (contracts §5.2) once that lands.

const FILE := "accounts.json"
## ASSUMPTION: Settlers is the NPC account (§6.6); the others would read as staff.
const RESERVED: Array[String] = ["settlers", "server", "system", "admin"]

var path := ""
var _by_id: Dictionary = {}  # int -> {id, name, token_hash, created}
var _by_hash: Dictionary = {}  # token_hash -> id
var _by_name: Dictionary = {}  # lower-case name -> id
var _next_id := 1  # id 0 is Settlers (§6.6)

## Opens (or creates) the store in dir. A file that does not parse is an error, not an empty
## store: starting blank would hand existing names to whoever asks first.
func open(dir: String) -> Error:
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	path = dir.path_join(FILE)
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(path + ".tmp")  # crashed mid-write; the real file is intact
	if not FileAccess.file_exists(path):
		return OK
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return _corrupt()
	var data: Dictionary = json.data
	var rows: Variant = data.get("accounts")
	var next: Variant = NetProtocol.as_int(data.get("next_id"), 1, NetProtocol.MAX_ID)
	if not rows is Array or next == null:
		return _corrupt()
	for row in rows:
		if not _admit(row):
			return _corrupt()
	_next_id = maxi(_next_id, next)
	return OK

func count() -> int:
	return _by_id.size()

func name_taken(n: String) -> bool:
	return _by_name.has(n.to_lower()) or n.to_lower() in RESERVED

func name_of(id: int) -> String:
	return str(_by_id.get(id, {}).get("name", ""))

func find_by_token(token: String) -> Dictionary:
	if not NetProtocol.is_token(token):
		return {}
	return _by_id.get(_by_hash.get(token.sha256_text(), -1), {})

## Returns {account, token} or {} when the name is not free or the file could not be written.
## The token exists only in this return value; the store keeps its hash.
func create(n: String, created: int) -> Dictionary:
	if not NetProtocol.valid_name(n) or name_taken(n):
		return {}
	var token := Crypto.new().generate_random_bytes(32).hex_encode()
	var rec := {"id": _next_id, "name": n, "token_hash": token.sha256_text(), "created": created}
	_index(rec)
	_next_id += 1
	if _save() != OK:
		_by_id.erase(rec["id"])
		_by_hash.erase(rec["token_hash"])
		_by_name.erase(n.to_lower())
		_next_id -= 1
		return {}
	return {"account": rec, "token": token}

func _corrupt() -> Error:
	print("[net] %s is corrupt; the server will not start. %s.bak holds the version before the last write." % [path, path])
	return ERR_FILE_CORRUPT

func _admit(row: Variant) -> bool:
	if not row is Dictionary:
		return false
	var id: Variant = NetProtocol.as_int(row.get("id"), 1, NetProtocol.MAX_ID)
	var created: Variant = NetProtocol.as_int(row.get("created"), 0, 1 << 40)
	var n: Variant = row.get("name")
	var h: Variant = row.get("token_hash")
	if id == null or created == null or not n is String or not h is String:
		return false
	if not NetProtocol.valid_name(n) or not NetProtocol.is_token(h) or _by_id.has(id) or _by_hash.has(h) or name_taken(n):
		return false
	_index({"id": id, "name": n, "token_hash": h, "created": created})
	_next_id = maxi(_next_id, id + 1)
	return true

func _index(rec: Dictionary) -> void:
	_by_id[rec["id"]] = rec
	_by_hash[rec["token_hash"]] = rec["id"]
	_by_name[str(rec["name"]).to_lower()] = rec["id"]

func _save() -> Error:
	var ids := _by_id.keys()
	ids.sort()
	var rows: Array = []
	for id in ids:
		rows.append(_by_id[id])
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"next_id": _next_id, "accounts": rows}, "\t"))
	var err := OK if NetProtocol.flushed(f) else ERR_FILE_CANT_WRITE  # a full disk must not truncate accounts.json
	f.close()
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")  # a copy, so accounts.json exists at every instant
	return DirAccess.rename_absolute(tmp, path)
