extends SceneTree
## W3-EXCHANGE: the Island Market screens' transport and the honest local economy they are shot
## and tested on (docs/orchestration/mmo/exchange-spec.md §8). Every check goes through
## MarketClient -> VaultBridge.client(), so it fails if the screens ever bypass the relay.
## Run: godot --headless --path game --script res://tests/t_exchange.gd -> "[t_exchange] PASS", exit 0/1.
## "[t_exchange] PENDING <gate>" lines name gates of later build steps (B1-B4); the B4 gate is 0 of them.

const DIR := "user://runs/t_exchange"
## Gates a later build step turns into checks (spec §8). Each builder deletes its own lines here.
const PENDING := [
	"B1 menu: HUD MENU sheet has an Island Market row that opens MarketScreen (hunt_hud hook)",
	"B1 offline: no transport -> 'Island Market offline' panel, 0 rows, 0 Buy/Sell/Receive controls",
	"B1 buy rows: one row per listing, uids == market.search uids, sorting never changes the uid set",
	"B1 buy: market.buy moves the exact asset to the buyer's vault and debits exactly price",
	"B1 buy errors: self_trade, insufficient_funds (bound only), trade lock, sold listing, double tap",
	"B2 sell: picker rows == server bag instances, refusals shown with reason, preview == ledger deltas",
	"B2 sell errors: fee not payable from bound coins, price 0 / > max_unit_price refused",
	"B3 my market: active/sold/expired/history from market.mine, cancel returns to vault, fee kept",
	"B3 receive all: inbox.take + vault.withdraw per uid, bag_full keeps the rest, twice moves nothing",
	"B4 pixels: targets >= 44 px at 844x390, no clipped labels, 500 listings page without hitches",
]

var failures: Array[String] = []
var _done := false
var _started := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	var harness_script := load("res://scripts/dev/market_harness.gd") as GDScript
	if harness_script == null or not harness_script.can_instantiate():
		failures.append("scripts/dev/market_harness.gd does not compile")
	else:
		await _test_offline()
		await _test_relay(harness_script)
		_test_scene(harness_script)
	for f in failures:
		print("[t_exchange] FAIL %s" % f)
	for p in PENDING:
		print("[t_exchange] PENDING %s" % p)
	print("[t_exchange] PASS" if failures.is_empty() else "[t_exchange] FAIL count=%d" % failures.size())
	_done = true
	quit(0 if failures.is_empty() else 1)

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond

## Offline single-player: the base client answers every op with `offline` and claims no server.
func _test_offline() -> void:
	var mc: RefCounted = (load("res://scripts/ui/market/market_client.gd") as GDScript).new()
	var res: Dictionary = await mc.call("request", "market.search", {})
	_expect(not mc.call("is_online") and res.get("err", "") == "offline", "offline client answers offline: %s" % res)
	_expect(str(mc.call("label")).contains("offline"), "offline client says so")

## The local test transport is VaultBridge.client(): server-only ops are refused, writes get a rid,
## a retry under the same rid applies nothing twice, and it is labelled as a test server.
func _test_relay(hs: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/relay")
	var mc: RefCounted = h.call("client", 1)
	_expect(mc.call("kind") == &"local_test" and str(mc.call("label")).contains("not the live market"), "the local transport is labelled a test server")
	var refused: Dictionary = await mc.call("request", "act.deposit", {"bag_slot": 0})
	_expect(refused.get("err", "") == "unauthorized", "a server-only op is refused by the relay: %s" % refused)
	var missing: Dictionary = await mc.call("request", "market.cancel", {"listing_id": "L999999"})
	_expect(missing.get("err", "") == "not_found", "a write gets a rid from the client (else bad_request): %s" % missing)
	var rid: String = mc.call("new_rid")
	_expect(rid != str(mc.call("new_rid")), "rids are unique per write")

## The seeded scene the lab shoots: real listings from other accounts, one row per instance.
func _test_scene(hs: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/scene")
	h.call("seed_scene")
	_expect((h.get("failures") as PackedStringArray).is_empty(), "the harness seeds through real ops: %s" % ", ".join(h.get("failures")))
	var search: Dictionary = h.call("op", 1, "market.search", {"page_size": 50})
	var rows: Array = search.get("r", {}).get("results", [])
	var by_def := {}
	var uids := {}
	for v: Dictionary in rows:
		var key := str(v.key)
		by_def[key] = int(by_def.get(key, 0)) + 1
		uids[str(v.asset.uid)] = true
	_expect(int(by_def.get("item:branch", 0)) == 3 and int(by_def.get("pet:compsognathus", 0)) == 1, "three single branches and one bonded pet are listed: %s" % by_def)
	_expect(int(by_def.get("item:captured_animal", 0)) == 3, "three captured cages are listed: %s" % by_def)
	_expect(uids.size() == rows.size(), "every listing is a distinct instance (%d uids, %d rows)" % [uids.size(), rows.size()])
	var w: Dictionary = h.call("op", 1, "wallet.get", {}).get("r", {})
	_expect(int(w.get("bound", 0)) > 0 and int(w.get("wallet", 0)) > int(w.get("bound", 0)), "the viewer holds bound and tradable coins: %s" % w)
	var mine: Dictionary = h.call("op", 1, "market.mine", {}).get("r", {})
	var states := {}
	for l: Dictionary in mine.get("closed_listings", []):
		states[str(l.state)] = true
	_expect((mine.get("listings", []) as Array).size() == 1 and states.has("sold") and states.has("expired"), "the viewer has 1 active, a sold and an expired listing: %d %s" % [(mine.get("listings", []) as Array).size(), states.keys()])
	var vault: Dictionary = h.call("op", 1, "vault.get", {}).get("r", {})
	_expect((vault.get("items", []) as Array).size() >= 2, "a purchase and the expired berry wait in the vault for Receive All: %d" % (vault.get("items", []) as Array).size())
	# Deterministic: a second harness from scratch lists the same things at the same prices.
	var h2: RefCounted = hs.new(DIR + "/scene2")
	h2.call("seed_scene")
	var again: Array = h2.call("op", 1, "market.search", {"page_size": 50}).get("r", {}).get("results", [])
	_expect(_sig(rows) == _sig(again), "the seeded scene is deterministic")
	print("[t_exchange] scene listings=%d defs=%s wallet=%s vault_items=%d" % [rows.size(), by_def, w, (vault.get("items", []) as Array).size()])

static func _sig(rows: Array) -> String:
	var out: PackedStringArray = []
	for v: Dictionary in rows:
		out.append("%s/%s/%d/%d" % [v.id, v.asset.uid, int(v.unit_price), int(v.asset.level)])
	return ",".join(out)
