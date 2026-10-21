class_name NetCharacters
extends RefCounted
## Server-owned characters on the socket (contracts v2 §0.1, §0.3, §0.4). A hello makes the
## account's character in W1-SRVDOM's CharacterStore; clients send only IntentHandlers.CLIENT_OPS
## (the act.<verb> intents, char.get, char.import), which run on the server's copy. The
## server-only SYSTEM_OPS are never registered, so no client can call them.

const SEED_FILE := "world_seed"

var store: CharacterStore
## shortcut: an empty in-memory island, so intents that need the world answer not_found;
## W3-SRVWORLD replaces it with its IslandRuntime facade.
var world := WorldFacade.new()
var _server: NetServer
var _moved: Dictionary = {}  # account_id -> the presence spot last committed with char.move

func _init(server: NetServer) -> void:
	_server = server
	for op: String in IntentHandlers.CLIENT_OPS:
		var read := op in IntentHandlers.READ_OPS
		server.register_op(op, _relay.bind(op), not read, "read" if read else "write")
	server.account_online.connect(_on_online)
	server.account_offline.connect(func (aid: int) -> void: _moved.erase(aid))

## Opens <data_dir>/chars under the world seed kept in <data_dir>/world_seed. "" or why it failed.
func open(data_dir: String) -> String:
	var world_seed := _world_seed(data_dir)
	if world_seed <= 0:
		return "cannot read or write %s" % data_dir.path_join(SEED_FILE)
	store = CharacterStore.new(world, data_dir.path_join("chars"), world_seed)
	var why := store.open()
	if why != "":
		store = null
	_moved.clear()
	return why

## Clean shutdown snapshots the store (CharacterStore.close).
func close() -> void:
	if store:
		var why := store.close()
		if why != "":
			_server._log("store_error", {"store": "chars", "err": why})
		store = null

## Online characters are server-owned from creation (§0.1): the first hello makes it, later ones find it.
func _on_online(aid: int) -> void:
	if store == null:
		return
	var res := store.apply("char.create", aid, {"name": _server.account_name(aid)}, int(_server.wall_time()))
	if not res.get("ok", false):
		_server._log("store_error", {"store": "chars", "account": aid, "err": str(res.get("msg", ""))})

func _relay(aid: int, a: Dictionary, rid: String, op: String) -> Dictionary:
	if store == null:
		return NetProtocol.fail("server_error", "character store is not open")
	var now := int(_server.wall_time())
	_sync_position(aid, now)
	var args := a.duplicate()
	args.erase("rid")
	if rid != "":
		args["rid"] = rid  # the store keeps it too: a crash between its journal and rids.jsonl cannot apply twice
	return store.apply(op, aid, args, now)

## Reach checks use the server's position (§0.4): before an intent, commit the last spot the
## presence layer accepted. reset: presence already speed-checked every update on the way there,
## and committing each 10 Hz update would journal ten lines a second per player.
func _sync_position(aid: int, now: int) -> void:
	var p: Variant = _server.presence.position_of(aid)
	if p == null or p == _moved.get(aid):
		return
	var v: Vector3 = p
	if store.apply("char.move", aid, {"p": [v.x, v.y, v.z], "reset": true}, now).get("ok", false):
		_moved[aid] = v

## A secret per world (CharacterStore: anyone who knows it can predict rolls), made once and kept.
## 48 bits: the store's JSON snapshot holds integers exactly only below 2^53.
static func _world_seed(dir: String) -> int:
	var path := dir.path_join(SEED_FILE)
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path).strip_edges()
		return text.to_int() if text.is_valid_int() else -1
	var world_seed := maxi(1, Crypto.new().generate_random_bytes(6).hex_encode().hex_to_int())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return -1
	f.store_string(str(world_seed))
	return world_seed if NetProtocol.flushed(f) else -1
