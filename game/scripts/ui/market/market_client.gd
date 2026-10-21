class_name MarketClient
extends RefCounted
## The market screens' one door to the economy. Every request is a VaultBridge.client() op on
## some server; subclasses are the transports (docs/orchestration/mmo/exchange-spec.md §2).
## This base class is "no server": offline single-player, where the market is honestly offline
## (STATUS 2026-10-20 owner: the market is an online feature; no fake listings).

## Ops that change state carry a request id; a retry sends the SAME rid so the server answers
## from its cache and nothing happens twice (contract 5.3).
const WRITE_OPS := MarketEngine.WRITE + ["vault.deposit", "vault.withdraw"]

var account := -1 ## this player's economy account; -1 when unknown (own rows then rely on the server's self_trade)
var _seq := 0
var _session := "%x" % (Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system())) ## rids stay unique across restarts

func is_online() -> bool:
	return false

## offline | net | local_test: the screen shows a badge for anything that is not the live server.
func kind() -> StringName:
	return &"offline"

## Said under the header, so a test server is never mistaken for the live market.
func label() -> String:
	return "Island Market offline"

## One op. A write gets a new rid unless `a.rid` is set (a retry passes the old one back).
## Always returns {ok, r} or {ok:false, err, msg}; await it (the network transport is async).
func request(op: String, a: Dictionary = {}) -> Dictionary:
	if op in WRITE_OPS and not a.has("rid"):
		a = a.duplicate()
		a.rid = new_rid()
	return await _send(op, a)

func new_rid() -> String:
	_seq += 1
	return "x%s.%d" % [_session, _seq]

func _send(_op: String, _a: Dictionary) -> Dictionary:
	return EconArgs.no("offline", "the Island Market needs a connection to the game server")
