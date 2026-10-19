class_name PresenceRooms
extends RefCounted
## Island rooms (contracts.md §7): who is on which island, the teleport check, and the 10 Hz
## relay of accepted states as `evt presence {players:[{id,name,p,yaw,anim}]}`.

const RELAY_INTERVAL := 0.1
const SPEED_FACTOR := 1.6
## ASSUMPTION: allowance an update did not use carries over, up to this many seconds of it. Frames
## that a stalled mobile link delivers together (arriving ~0 s apart) still pass, and so does the
## 0.45 s roll at 13 m/s (player.gd _try_roll). Standing still banks no more than this.
const CARRY_S := 3.0
## ASSUMPTION: islands are flat (island_runtime.gd _terrain keeps heights within about -2.6..4.5 m),
## nothing flies, and player.gd _fall_guard re-seats anyone below -15 m. Outside this band is a hack.
const Y_MIN := -20.0
const Y_MAX := 30.0
const MAX_ROOM := 100  # ASSUMPTION
## ASSUMPTION: real travel takes longer than this, so hopping islands to dodge the speed check
## (each change resets it, contract §7) is held to one hop per window.
const ISLAND_HOP_COOLDOWN := 2.0
## Last accepted position outlives the socket so a reconnect cannot reset the speed check. After
## this long the allowance (1.6 × run speed × dt) covers any island anyway.
const LAST_TTL := 600.0
## ASSUMPTION: the default playfield (smoke runs, --net-probe) has no island id.
const LOBBY := "lobby"
const ANIM_PATTERN := "^[a-z0-9_]{1,32}$"  # every survivor clip name (assets/characters/survivor/anim)
const PLAYER_SCRIPT := "res://scripts/player/player.gd"
## Player.run_speed (game/scripts/player/player.gd:19, no override in player.tscn). Used only
## when the script's default cannot be read (export templates strip script defaults).
const RUN_SPEED_FALLBACK := 7.0

var run_speed := RUN_SPEED_FALLBACK
var _server: NetServer
var _rooms: Dictionary = {}  # room key -> {account_id: true}
var _who: Dictionary = {}  # account_id -> {room, island, name, p: Vector3, yaw, anim, has_pos, dirty}
var _last: Dictionary = {}  # account_id -> {island, p: Vector3, at, budget, hopped_at}; swept after LAST_TTL
var _acc := 0.0
var _sweep_acc := 0.0
var _anim_re := RegEx.create_from_string(ANIM_PATTERN)

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
	var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
	if pos.y < Y_MIN or pos.y > Y_MAX:
		return NetProtocol.fail("bad_request", "height must be %d to %d m" % [int(Y_MIN), int(Y_MAX)])
	var now := _server.mono()
	var rate := SPEED_FACTOR * run_speed
	var budget := rate * CARRY_S  # a first update, or one after travel, starts with a full carry
	var last: Dictionary = _last.get(aid, {})
	var hopped_at := -LAST_TTL
	if not last.is_empty() and last["island"] == island:
		# Distance budget: carry from earlier updates plus run allowance for the time since the
		# last accepted one (unbounded, so running on through a long disconnect still passes).
		# Climbing costs like running; falling is free (gravity is the only vertical force).
		var d: Vector3 = pos - last["p"]
		var cost := Vector3(d.x, maxf(d.y, 0.0), d.z).length()
		var allow := float(last["budget"]) + rate * maxf(0.0, now - float(last["at"]))
		if cost > allow:
			return NetProtocol.fail("bad_request", "moved too fast: %.1f m with %.1f m allowed" % [cost, allow])
		budget = minf(budget, allow - cost)
		hopped_at = last["hopped_at"]
	elif not last.is_empty():
		if now - float(last["hopped_at"]) < ISLAND_HOP_COOLDOWN:
			return NetProtocol.fail("rate_limited", "changing islands too fast")
		hopped_at = now
	var st: Dictionary = _who.get(aid, {})
	if st.is_empty() or st["island"] != island:
		var joined := _join(aid, island)
		if not joined["ok"]:
			return joined
		st = _who[aid]
	_last[aid] = {"island": island, "p": pos, "at": now, "budget": budget, "hopped_at": hopped_at}
	st["p"] = pos
	st["yaw"] = wrapf(float(yaw), -PI, PI)
	st["anim"] = anim
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
	_sweep_acc += delta
	if _sweep_acc >= 30.0:
		_sweep_acc = 0.0
		var now := _server.mono()
		for aid in _last.keys():
			if not _who.has(aid) and now - float(_last[aid]["at"]) > LAST_TTL:
				_last.erase(aid)
	_acc += delta
	if _acc < RELAY_INTERVAL:
		return
	_acc = minf(_acc - RELAY_INTERVAL, RELAY_INTERVAL)  # keep the remainder so the relay stays at 10 Hz
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
			"yaw": 0.0, "anim": "idle", "has_pos": false, "dirty": false}
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
