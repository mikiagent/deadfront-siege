class_name LocalMarketClient
extends MarketClient
## Dev/test transport: the real economy (VaultBridge over EconStore + CharacterStore) running in
## this process, one account per client. Built only by labs and tests (MarketHarness), never by
## the player path, and labelled so it is never shown as the live market (spec 06: an honest
## harness, not a falsely represented live market).

var bridge: VaultBridge
var clock: Callable ## -> int unix seconds; a harness injects its own so shots are deterministic

func _init(p_bridge: VaultBridge, p_account: int, p_clock: Callable) -> void:
	bridge = p_bridge
	account = p_account
	clock = p_clock

func is_online() -> bool:
	return bridge != null

func kind() -> StringName:
	return &"local_test"

func label() -> String:
	return "Local test server: not the live market"

func now() -> int:
	return int(clock.call())

func _send(op: String, a: Dictionary) -> Dictionary:
	return bridge.client(op, account, a, int(clock.call()))
