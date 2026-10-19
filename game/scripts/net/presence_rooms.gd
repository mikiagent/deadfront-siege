class_name PresenceRooms
extends RefCounted
## Island rooms (contracts.md §7): who is on which island, the teleport check, and the 10 Hz
## relay of accepted states as `evt presence {players:[{id,name,p,yaw,anim}]}`.

const RELAY_INTERVAL := 0.1
const SPEED_FACTOR := 1.6
## ASSUMPTION: absorbs frame jitter and the 0.45 s roll burst (~12 m/s, player.gd _roll_left).
const SPEED_SLACK_M := 0.5
const MAX_ROOM := 100  # ASSUMPTION
## ASSUMPTION: the default playfield (smoke runs, --net-probe) has no island id.
const LOBBY := "lobby"
const PLAYER_SCRIPT := "res://scripts/player/player.gd"
## Player.run_speed (game/scripts/player/player.gd:19, no override in player.tscn). Used only
## when the script's default cannot be read (export templates strip script defaults).
const RUN_SPEED_FALLBACK := 7.0

var run_speed := RUN_SPEED_FALLBACK
var _server: NetServer
var _rooms: Dictionary = {}  # room key -> {account_id: true}
var _who: Dictionary = {}  # account_id -> {room, island, name, p: Vector3, yaw, anim, at, has_pos, dirty}
var _acc := 0.0
var _anim_re := RegEx.create_from_string("^[a-z0-9_]{1,32}$")

func _init(server: NetServer) -> void:
	_server = server
	server.account_offline.connect(leave)
	var script := load(PLAYER_SCRIPT) as Script
	var v: Variant = script.get_property_default_value(&"run_speed") if script else null
	if NetProtocol.is_num(v) and float(v) > 0.0:
		run_speed = float(v)

## presence.join {island}
func op_join(aid: int, a: Dictionary) -> Dictionary:
	var island := _island(a.get("island"))
	if island == "":
		return NetProtocol.fail("bad_request", "island must be a known island id")
	return _join(aid, island)

## presence.update {p:[x,y,z], yaw, anim, island}. A different island is travel: join it first.
func op_update(aid: int, a: Dictionary) -> Dictionary:
	var island := _island(a.get("island"))
	var p: Variant = a.get("p")
	var yaw: Variant = a.get("yaw")
	var anim: Variant = a.get("anim")
	if island == "" or not NetProtocol.is_vec3(p) or not NetProtocol.is_num(yaw) \
			or not anim is String or _anim_re.search(anim) == null:
		return NetProtocol.fail("bad_request", "presence.update needs p:[x,y,z], yaw, anim and a known island")
	var st: Dictionary = _who.get(aid, {})
	if st.is_empty() or st["island"] != island:
		var joined := _join(aid, island)
		if not joined["ok"]:
			return joined
		st = _who[aid]
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	var now := _server.mono()
	if st["has_pos"]:
		# Ground speed only: a fall off a cliff is fast and vertical, a speed hack is horizontal.
		var dt := now - float(st["at"])
		var flat := Vector2(pos.x - st["p"].x, pos.z - st["p"].z).length()
		if flat > SPEED_FACTOR * run_speed * dt + SPEED_SLACK_M:
			return NetProtocol.fail("bad_request", "moved too fast: %.1f m in %.2f s" % [flat, dt])
	st["p"] = pos
	st["yaw"] = wrapf(float(yaw), -PI, PI)
	st["anim"] = anim
	st["at"] = now
	st["has_pos"] = true
	st["dirty"] = true
	return NetProtocol.ok({})

func leave(aid: int) -> void:
	var st: Dictionary = _who.get(aid, {})
	if st.is_empty():
		return
	_who.erase(aid)
	var members: Dictionary = _rooms.get(st["room"], {})
	members.erase(aid)
	if members.is_empty():
		_rooms.erase(st["room"])
	elif st["has_pos"]:
		_server.broadcast_event(members.keys(), "presence_leave", {"id": aid})

## Everyone in aid's room (aid included), or [] when aid is in no room.
func room_members(aid: int) -> Array:
	var st: Dictionary = _who.get(aid, {})
	return [] if st.is_empty() else (_rooms.get(st["room"], {}) as Dictionary).keys()

func tick(delta: float) -> void:
	_acc += delta
	if _acc < RELAY_INTERVAL:
		return
	_acc = 0.0
	for key in _rooms.keys():
		var members: Dictionary = _rooms[key]
		var batch: Array = []
		for aid in members.keys():
			var st: Dictionary = _who[aid]
			if st["dirty"]:
				st["dirty"] = false
				batch.append(_entry(aid, st))
		if not batch.is_empty():
			_server.broadcast_event(members.keys(), "presence", {"players": batch})

func _join(aid: int, island: String) -> Dictionary:
	var key := _room_key(aid, island)
	var st: Dictionary = _who.get(aid, {})
	if st.is_empty() or st["room"] != key:
		if (_rooms.get(key, {}) as Dictionary).size() >= MAX_ROOM:
			return NetProtocol.fail("limit_reached", "this island is full")
		leave(aid)
		if not _rooms.has(key):
			_rooms[key] = {}
		_rooms[key][aid] = true
		_who[aid] = {"room": key, "island": island, "name": _server.account_name(aid), "p": Vector3.ZERO,
			"yaw": 0.0, "anim": "idle", "at": 0.0, "has_pos": false, "dirty": false}
	# The relay only carries changes, so a newcomer gets everyone who is standing still now.
	var players: Array = []
	for other in _rooms[key].keys():
		if other != aid and _who[other]["has_pos"]:
			players.append(_entry(other, _who[other]))
	if not players.is_empty():
		_server.send_event(aid, "presence", {"players": players})
	return NetProtocol.ok({"island": island, "players": _rooms[key].size()})

## ASSUMPTION: a private island is each player's own home, so its room is per account.
func _room_key(aid: int, island: String) -> String:
	if island != LOBBY and str(World.def_of(StringName(island)).get("kind", "")) == "private":
		return "%s#%d" % [island, aid]
	return island

func _island(v: Variant) -> String:
	if not v is String or (v as String).length() > 64:
		return ""
	return v if v == LOBBY or World.islands.has(v) else ""

func _entry(aid: int, st: Dictionary) -> Dictionary:
	var p: Vector3 = st["p"]
	return {"id": aid, "name": st["name"], "p": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"yaw": snappedf(st["yaw"], 0.001), "anim": st["anim"]}
