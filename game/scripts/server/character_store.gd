class_name CharacterStore
extends RefCounted
## Server-owned characters (contract v2 §0.1) with the economy engine's durability (§5.2):
## apply(op, account, args, ts) runs one IntentHandlers op on the server copy; a change bumps
## seq and is appended to journal.jsonl and flushed before apply() returns. Each journal line
## also carries `w`, the world answers the op read, so a replay rebuilds the characters
## without the island. Snapshot = canonical state JSON, written to .tmp, read back, renamed.
## Boot = snapshot, then journal lines with seq > snapshot.seq; a torn last line is cut off.
## dir == "" keeps the journal in `lines` only (tests, the fuzz).
# shortcut: one snapshot generation (EconStore keeps two plus journal.prev); copy its rotation
# here if power-cut durability matters before W3 hosts this.

const VERSION := 1
const RIDS_KEPT := 64
## The data the handlers read. Replay re-runs them, so a snapshot records this hash and boot
## warns when it changed. shortcut: creature defs (tame, capture) are not hashed yet.
const DATA_FILES := ["res://data/items.json", "res://data/recipes.json", "res://data/combat_counters.json", "res://data/combat_tuning.json", "res://data/world/rules.json", "res://data/inventory.json"]

var s: Dictionary
var world: WorldFacade
var handlers: IntentHandlers
var dir: String
var lines: PackedStringArray = [] ## memory mode: every journal line since genesis
var snapshot_every_ops := 500 ## 0 disables automatic snapshots
var broken := "" ## set when the disk cannot be trusted; every later op is refused
var _journal: FileAccess
var _ops_since := 0
var data_changed := false ## set by open() when the snapshot was taken under other data files
var _seed := 0 ## the seed W3 passed; open() refuses a disk written under another one
static var _errors: ErrorCount

## Counts script and engine errors, so apply() can tell an op that hit one part-way.
class ErrorCount extends Logger:
	var n := 0
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			n += 1

## world_seed seeds every server roll (capture, crit, genetics) with the op's seq. It must be a
## server secret, random and persisted per world (W3 passes it): anyone who knows it can predict
## rolls. Tests pass fixed seeds.
func _init(p_world: WorldFacade, p_dir: String, world_seed: int) -> void:
	world = p_world
	dir = p_dir
	handlers = IntentHandlers.new(world)
	_seed = world_seed
	s = genesis(world_seed)
	if _errors == null:
		_errors = ErrorCount.new()
		OS.add_logger(_errors)

static func genesis(world_seed: int) -> Dictionary:
	return {
		"v": VERSION, "seq": 0, "last_ts": 0, "world_seed": world_seed, "chars": {},
		"minted": {}, "consumed": {}, "exported": {}, "pets_minted": 0, "pets_exported": 0,
		"exported_assets": {}, ## uid -> canonical body of every asset act.deposit handed out
	}

func character(account: int) -> CharacterState:
	var d: Variant = s.chars.get(str(account))
	return CharacterState.new(d) if d is Dictionary else null

# --- the one entry point -------------------------------------------------------------------

## -> {ok, r} | {ok: false, err, msg}. The handlers see the args parsed back from the exact
## text the journal stores, so a replay reads the same numbers the live op did. Keys the op
## does not read are dropped first (IntentHandlers.ARG_KEYS).
func apply(op: String, account: int, args: Dictionary, ts: int) -> Dictionary:
	if broken != "":
		return IntentHandlers.no("server_error", "character store is not writable (%s)" % broken)
	if dir != "" and _journal == null:
		return IntentHandlers.no("server_error", "character store is not open; call open() first")
	var parsed: Variant = wire(args) # null when args do not survive JSON (NaN, INF)
	var a := IntentHandlers.known_args(op, parsed if parsed is Dictionary else {})
	var tape: Array = []
	var res := _run(op, account, a, ts, tape, false)
	if not res.has("_seq"):
		return res
	res.erase("_seq")
	var line := canon({"a": a, "account": account, "op": op, "seq": int(s.seq), "ts": int(s.last_ts), "w": tape})
	if dir == "":
		lines.append(line)
		return res
	var at := _journal.get_position()
	var wrote := _journal.store_line(line)
	_journal.flush()
	if not wrote or _journal.get_error() != OK:
		# Memory is ahead of disk now: refuse this and every later op until a restart.
		broken = "journal write failed (%d)" % _journal.get_error()
		_journal.resize(at)
		push_error("[srv] %s" % broken)
		return IntentHandlers.no("server_error", broken)
	_ops_since += 1
	if snapshot_every_ops > 0 and _ops_since >= snapshot_every_ops:
		var why := snapshot()
		if why != "":
			push_error("[srv] snapshot failed: %s" % why)
	return res

## Shared by live ops and replay. A committed op's result carries "_seq".
func _run(op: String, account: int, a: Dictionary, ts: int, tape: Array, replaying: bool) -> Dictionary:
	if op not in IntentHandlers.CLIENT_OPS and op not in IntentHandlers.SYSTEM_OPS:
		return IntentHandlers.no("bad_request", "unknown op %s" % op)
	if account < 1:
		return IntentHandlers.no("unauthorized", "account must be positive")
	var now := maxi(ts, int(s.last_ts)) # server time never runs backwards inside the store
	if op == "char.create":
		return _create(account, a, now)
	var ch := character(account)
	if ch == null:
		return IntentHandlers.no("unauthorized", "account %d has no online character" % account)
	var rid: Variant = IntentHandlers.text(a, "rid")
	if a.has("rid") and rid == null: # an unusable rid would let the op apply twice (§5.3)
		return IntentHandlers.no("bad_request", "rid must be a 1..64 character string")
	if rid != null and ch.d.rids.has(rid):
		var hit: Array = ch.d.rids[rid]
		if str(hit[0]) != op:
			return IntentHandlers.no("conflict", "rid already used for %s" % hit[0])
		# shortcut: a repeat gets this marker, not the first body; the client re-reads with char.get.
		return {"ok": true, "r": {"duplicate": true, "op": op, "seq": int(hit[1])}}
	var backup: Dictionary = {"char": ch.d.duplicate(true), "minted": s.minted.duplicate(), "consumed": s.consumed.duplicate(), "exported": s.exported.duplicate(), "pets_minted": s.pets_minted, "pets_exported": s.pets_exported, "exported_assets": s.exported_assets.duplicate()}
	var errors := _errors.n
	handlers.begin(s, int(s.seq) + 1, now, account, op, tape, replaying)
	var got: Variant = handlers.run(op, ch, a)
	var res: Dictionary = got if got is Dictionary else {}
	if not res.has("ok") or _errors.n != errors:
		# An internal error part-way: put the character back so a half-applied op cannot persist.
		s.chars[str(account)] = backup.char
		for k in ["minted", "consumed", "exported", "pets_minted", "pets_exported", "exported_assets"]:
			s[k] = backup[k]
		return IntentHandlers.no("server_error", "internal error in %s; nothing was applied" % op)
	if not res.ok or res.has("noop") or op in IntentHandlers.READ_OPS:
		res.erase("noop")
		return res
	handlers.flush() # world writes land only now that the op commits
	s.seq = int(s.seq) + 1
	s.last_ts = now
	if rid != null:
		_remember(ch.d, rid, op)
	s.chars[str(account)] = norm(ch.d) # integral floats -> ints, the shape a reload has
	res["_seq"] = s.seq
	res.r["seq"] = s.seq
	return res

## char.create {name}: the first hello of an account makes its server-owned character.
func _create(account: int, a: Dictionary, now: int) -> Dictionary:
	var name: Variant = IntentHandlers.text(a, "name", 20)
	if name == null or (name as String).length() < 3:
		return IntentHandlers.no("bad_request", "name must be 3..20 characters")
	for c in (name as String):
		if not (c >= "a" and c <= "z") and not (c >= "A" and c <= "Z") and not (c >= "0" and c <= "9") and c not in [" ", "_", "-"]:
			return IntentHandlers.no("bad_request", "name may use letters, digits, space, _ and -")
	if s.chars.has(str(account)):
		return {"ok": true, "r": character(account).view()}
	s.chars[str(account)] = CharacterState.fresh(account, name, now)
	s.seq = int(s.seq) + 1
	s.last_ts = now
	return {"ok": true, "r": {"account": account, "seq": s.seq}, "_seq": s.seq}

func _remember(d: Dictionary, rid: String, op: String) -> void:
	var cache: Dictionary = d.rids
	cache[rid] = [op, int(s.seq)]
	if cache.size() > RIDS_KEPT:
		var oldest := ""
		for k: String in cache:
			if oldest == "" or int(cache[k][1]) < int(cache[oldest][1]):
				oldest = k
		cache.erase(oldest)

# --- replay and durability -----------------------------------------------------------------

## Replays one journal line (live ops wrote it). Returns "" or why boot must stop.
func replay_line(text: String) -> String:
	var row: Variant = _parse(text)
	if not (row is Dictionary and (row as Dictionary).has_all(["seq", "ts", "account", "op", "a", "w"]) and row.a is Dictionary and row.w is Array):
		return "corrupt journal line"
	row = norm(row)
	var seq := int(row.seq)
	if seq <= int(s.seq):
		return ""
	if seq != int(s.seq) + 1:
		return "journal jumps from seq %d to %d" % [int(s.seq), seq]
	var res := _run(str(row.op), int(row.account), row.a, int(row.ts), row.w, true)
	if int(s.seq) != seq:
		return "seq %d did not replay (%s)" % [seq, str(res.get("msg", res.get("err", "")))]
	if dir == "":
		lines.append(text)
	return ""

## Loads snapshot.json and replays journal.jsonl. Returns "" or why boot must stop.
func open() -> String:
	if dir == "":
		return ""
	DirAccess.make_dir_recursive_absolute(dir)
	var snap := dir.path_join("snapshot.json")
	if FileAccess.file_exists(snap):
		var parsed: Variant = _parse(FileAccess.get_file_as_string(snap))
		if not parsed is Dictionary or int(parsed.get("v", 0)) != VERSION:
			return "snapshot.json is unreadable or another version"
		s = norm(parsed)
		data_changed = str(s.get("data", "")) != data_hash()
		s.erase("data") # lives only in the file, so the state hash does not depend on it
		if int(s.world_seed) != _seed:
			return "world_seed differs from the one this store was written under"
	var path := dir.path_join("journal.jsonl")
	if not FileAccess.file_exists(snap):
		# Genesis goes to disk first, so world_seed is never only in memory (a journal replayed
		# under another seed would silently diverge). A journal with no snapshot cannot be checked.
		if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > 0:
			return "journal.jsonl has no snapshot.json; its world_seed cannot be checked"
		return snapshot()
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var start := 0
		while start < bytes.size():
			var nl := bytes.find(10, start)
			var text := bytes.slice(start, nl if nl >= 0 else bytes.size()).get_string_from_utf8()
			if nl < 0 and not _parse(text) is Dictionary:
				var f := FileAccess.open(path, FileAccess.READ_WRITE) # a torn final write: cut it off
				if f == null or f.resize(start) != OK:
					return "cannot cut the torn journal tail"
				f.close()
				break
			var why := replay_line(text)
			if why != "":
				# W2-INV: a journal written under other rules (items stacked) may not replay under these.
				return why + ("; the data files changed since the snapshot: boot the previous build once so it snapshots, then upgrade" if data_changed else "")
			if nl < 0: # a complete last line that lost only its newline: give it back
				var f := FileAccess.open(path, FileAccess.READ_WRITE)
				f.seek_end()
				f.store_8(10)
				f.close()
				break
			start = nl + 1
	_journal = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if _journal == null:
		return "cannot open journal (%d)" % FileAccess.get_open_error()
	_journal.seek_end()
	_ops_since = 0
	# W2-INV: split stacked characters only after the journal replayed against the rows it was
	# written for (a deposit of 5 from a 20-stack), then snapshot so the split is never replayed over.
	var migrated := migrate_stacks()
	if data_changed:
		# The journal just replayed under new rules; snapshot so later boots do not repeat that.
		push_warning("[srv] data files changed since the last snapshot; the journal replayed under the new rules")
		return snapshot()
	return snapshot() if migrated > 0 else ""

## W2-INV: characters stored while materials stacked get one row per unit (CharacterState.
## split_stacks); what the 100-slot bag cannot hold goes to their home storage. Logged per
## character. Returns how many characters changed.
func migrate_stacks() -> int:
	var changed := 0
	for key: String in s.chars:
		var got := CharacterState.split_stacks(s.chars[key])
		if got.is_empty():
			continue
		changed += 1
		s.chars[key] = norm(s.chars[key])
		var parts := PackedStringArray()
		var stored := 0
		for id: String in got.stored:
			parts.append("%s x%d" % [id, got.stored[id]])
			stored += int(got.stored[id])
		print("[srv] migration: char %s: bag %d slots, %d rows split from stacks, %d units to home storage%s" % [key, (s.chars[key].bag as Array).size(), got.split, stored, " (%s)" % ", ".join(parts) if not parts.is_empty() else ""])
	return changed

## Verified write of the snapshot, then a fresh journal (everything in it is now covered).
func snapshot() -> String:
	if dir == "":
		return ""
	var text := canon(s.merged({"data": data_hash()}))
	var snap := dir.path_join("snapshot.json")
	var tmp := snap + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s (%d)" % [tmp.get_file(), FileAccess.get_open_error()]
	var wrote := f.store_string(text)
	f.close()
	if not wrote or FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return "snapshot did not verify; kept the old one and the journal"
	if DirAccess.rename_absolute(tmp, snap) != OK: # atomic replace on POSIX
		return "cannot rename the snapshot into place"
	_close_journal()
	_journal = FileAccess.open(dir.path_join("journal.jsonl"), FileAccess.WRITE)
	if _journal == null:
		broken = "cannot open a new journal (%d)" % FileAccess.get_open_error()
		return broken
	_ops_since = 0
	return ""

## Clean shutdown: snapshot (so no journal replays under the next deploy's data), then close.
func close() -> String:
	var why := snapshot() if _journal and broken == "" else ""
	_close_journal()
	return why

func _close_journal() -> void:
	if _journal:
		_journal.flush()
		_journal.close()
		_journal = null

# --- canonical form and invariants ------------------------------------------------------------

static func data_hash() -> String:
	var all := ""
	for path: String in DATA_FILES:
		all += FileAccess.get_file_as_string(path).sha256_text()
	return all.sha256_text()

func state_json() -> String:
	return canon(s)

func state_hash() -> String:
	return canon(s).sha256_text()

## Contract §6.7 for characters. Returns the problems found (empty = all hold).
func invariants() -> Array[String]:
	var out: Array[String] = []
	var held := {}
	var seen := {}
	var pets := 0
	for key: String in s.chars:
		var ch: Dictionary = s.chars[key]
		for row: Variant in (ch.bag as Array) + (ch.get("storage", []) as Array): # storage: W2-INV home storage
			if not row is Dictionary or str(row.id) == str(CharacterState.LOCK):
				continue
			if int(row.count) < 1 or int(row.durability) < 0:
				out.append("char %s holds %s with count %d durability %d" % [key, row.id, int(row.count), int(row.durability)])
			if not Provenance.is_server(row):
				out.append("char %s holds %s without server provenance" % [key, row.id])
			_once(seen, str(row.get("uid", "")), out)
			held[str(row.id)] = int(held.get(str(row.id), 0)) + int(row.count)
		for uid: String in ch.pets:
			pets += 1
			_once(seen, uid, out)
			if str(ch.pets[uid].get("uid", "")) != uid or not Provenance.is_server(ch.pets[uid]):
				out.append("char %s pet %s has no matching server provenance" % [key, uid])
		for slot: String in ch.equipment:
			if CharacterState.new(ch).find_uid(str(ch.equipment[slot])) < 0:
				out.append("char %s equips %s, which is not in its bag" % [key, ch.equipment[slot]])
	var defs := {}
	for d: Dictionary in [held, s.minted, s.consumed, s.exported]:
		for k: String in d:
			defs[k] = true
			if int(d[k]) < 0:
				out.append("negative count for %s" % k)
	for k: String in defs:
		var expect := int(s.minted.get(k, 0)) - int(s.consumed.get(k, 0)) - int(s.exported.get(k, 0))
		if expect != int(held.get(k, 0)):
			out.append("%s: minted - consumed - exported = %d but %d are held" % [k, expect, int(held.get(k, 0))])
	if int(s.pets_minted) - int(s.pets_exported) != pets:
		out.append("pets: minted - exported = %d but %d are held" % [int(s.pets_minted) - int(s.pets_exported), pets])
	return out

static func _once(seen: Dictionary, uid: String, out: Array[String]) -> void:
	if seen.has(uid):
		out.append("uid %s is in two containers" % uid)
	seen[uid] = true

## Integral floats become ints, StringNames strings, keys strings: one canonical shape shared
## by live state and state reloaded from JSON (Ledger.norm's rules).
static func norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if is_finite(f) and f == floorf(f) and absf(f) <= 9007199254740991.0 else f
		TYPE_STRING_NAME:
			return str(v)
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[str(k)] = norm(v[k])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for x in v:
				out.append(norm(x))
			return out
	return v

static func canon(v: Variant) -> String:
	return JSON.stringify(v, "", true, true)

## A value as the journal will hand it back: through canonical JSON text and norm().
static func wire(v: Variant) -> Variant:
	return norm(_parse(canon(norm(v))))

## JSON.parse_string logs on bad text; torn lines are expected, so parse quietly.
static func _parse(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null
