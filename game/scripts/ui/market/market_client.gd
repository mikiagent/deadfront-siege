class_name MarketClient
extends RefCounted
## The market screens' one door to the economy (ported from claude/mmo-exchange). Every request is a
## VaultBridge.client() op on some server; subclasses are the transports. This base class is "no
## server": offline single-player, where the market is honestly offline (owner 2026-10-20: no fake
## listings, the market is an online feature).

## Ops that change state carry a request id; a retry sends the same rid so nothing happens twice.
const WRITE_OPS := MarketEngine.WRITE + ["vault.deposit", "vault.withdraw"]

var account := -1 ## this player's economy account; -1 offline
var _seq := 0
var _session := "%x" % (Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system()))

func is_online() -> bool:
	return false

## Said on the rail, so a test server is never mistaken for the live market.
func label() -> String:
	return "Island Market offline"

## One op; always {ok, r} or {ok:false, err, msg}. A write gets a new rid unless `a.rid` is set.
func request(op: String, a: Dictionary = {}) -> Dictionary:
	if op in WRITE_OPS and not a.has("rid"):
		a = a.duplicate()
		_seq += 1
		a.rid = "x%s.%d" % [_session, _seq]
	return _send(op, a)

## The server's unix time, for "ago" lines.
func now() -> int:
	return int(Time.get_unix_time_from_system())

func _send(_op: String, _a: Dictionary) -> Dictionary:
	return EconArgs.no("offline", "the Island Market needs a connection to the game server")
