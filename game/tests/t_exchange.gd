extends SceneTree
## W3-EXCHANGE: the Island Market screens, their transport and the honest local economy they are
## shot and tested on (docs/orchestration/mmo/exchange-spec.md §8). Every check goes through
## MarketClient -> VaultBridge.client(), so it fails if the screens ever bypass the relay.
## Run: godot --headless --path game --script res://tests/t_exchange.gd [-- --require-hooks]
##   -> "[t_exchange] PASS", exit 0/1.
## Hook-dependent checks (H0 menu row, H1 sorts, H2 filters; exchange-spec §6) print "HOOK ... absent"
## and are skipped on the branch; with --require-hooks (the hooks patch applied) they must pass.
## "[t_exchange] PENDING <gate>" lines name gates of later build steps; the B4 gate is 0 of them.

const DIR := "user://runs/t_exchange"
const MS_PATH := "res://scripts/ui/market/market_screen.gd"
## Gates a later build step turns into checks (spec §8). Each builder deletes its own lines here.
const PENDING := [
	"B4 pixels: targets >= 44 px at 844x390, no clipped labels, 500 listings page without hitches",
]

var failures: Array[String] = []
var require_hooks := false
var MF: GDScript ## MarketFormat, loaded (the test fails, not breaks, without it)
var _done := false
var _started := false

## NetClient's shape (claude/mmo-net net_client.gd / net_request.gd), so NetMarketClient is tested
## without a socket: the first answer times out, the retry must reuse the request's rid.
class FakeReq extends RefCounted:
	signal done(req: FakeReq)
	var op := ""
	var a := {}
	var rid := ""
	var ok := false
	var r := {}
	var err := ""
	var msg := ""

class FakeNet extends RefCounted:
	var account_id := 7
	var sent: Array = []
	var timeouts := 1
	func is_online() -> bool:
		return true
	func request(op: String, a: Dictionary) -> FakeReq:
		return _send(op, a, "r%d" % sent.size())
	func retry(req: FakeReq) -> FakeReq:
		return _send(req.op, req.a, req.rid)
	func _send(op: String, a: Dictionary, rid: String) -> FakeReq:
		var q := FakeReq.new()
		q.op = op
		q.a = a
		q.rid = rid
		sent.append(q)
		_finish.call_deferred(q)
		return q
	func _finish(q: FakeReq) -> void:
		if timeouts > 0:
			timeouts -= 1
			q.err = "timeout"
		else:
			q.ok = true
			q.r = {"echo": q.op}
		q.done.emit(q)

func _process(_delta: float) -> bool:
	if _done:
		return true
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	require_hooks = "--require-hooks" in OS.get_cmdline_user_args()
	var hs := load("res://scripts/dev/market_harness.gd") as GDScript
	var ms_script := load(MS_PATH) as GDScript
	MF = load("res://scripts/ui/market/market_format.gd") as GDScript
	if hs == null or not hs.can_instantiate():
		failures.append("scripts/dev/market_harness.gd does not compile")
	elif ms_script == null or not ms_script.can_instantiate():
		failures.append("scripts/ui/market/market_screen.gd does not compile (no Island Market screen)")
	else:
		await _test_offline()
		await _test_relay(hs)
		_test_scene(hs)
		await _test_offline_screen(ms_script)
		await _test_net_client()
		await _test_rows_and_sorts(hs, ms_script)
		await _test_buy(hs, ms_script)
		await _test_buy_errors(hs, ms_script)
		await _test_categories(hs, ms_script)
		await _test_sell(hs, ms_script)
		await _test_sell_errors(hs, ms_script)
		await _test_my_market(hs, ms_script)
		await _test_cancel(hs, ms_script)
		await _test_receive_all(hs, ms_script)
		await _test_receive_bag_full(hs, ms_script)
		await _test_menu(hs, ms_script)
		ms_script.set("test_client", null)
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

## A hook-dependent check that cannot run: a failure only when the hooks patch is applied.
func _hook_absent(id: String, what: String) -> void:
	print("[t_exchange] HOOK %s absent: %s skipped" % [id, what])
	_expect(not require_hooks, "hook %s is required (--require-hooks) but absent: %s" % [id, what])

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
	var rows: Array = h.call("op", 1, "market.search", {"page_size": 50}).get("r", {}).get("results", [])
	var by_def := {}
	var uids := {}
	for v: Dictionary in rows:
		by_def[str(v.key)] = int(by_def.get(str(v.key), 0)) + 1
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
	var h2: RefCounted = hs.new(DIR + "/scene2")
	h2.call("seed_scene")
	var again: Array = h2.call("op", 1, "market.search", {"page_size": 50}).get("r", {}).get("results", [])
	_expect(_sig(rows) == _sig(again), "the seeded scene is deterministic")
	print("[t_exchange] scene listings=%d defs=%s wallet=%s vault_items=%d" % [rows.size(), by_def, w, (vault.get("items", []) as Array).size()])

## Gate 10: no transport -> the offline panel, no rows, no rail, no Buy, and not one op sent.
func _test_offline_screen(ms_script: GDScript) -> void:
	ms_script.set("test_client", null)
	var ms: Control = await _open(ms_script)
	var buy: Control = ms.get("buy")
	var shown := 0
	for b in ms.find_children("*", "BaseButton", true, false):
		if (b as Control).is_visible_in_tree() and str(b.name) not in ["MarketBack", "MarketClose"]:
			shown += 1
	var title := ms.find_child("OfflineTitle", true, false) as Label
	_expect((ms.get("offline_panel") as Control).visible and title != null and title.text.contains("offline"), "offline: the Island Market offline panel shows")
	_expect(int(buy.get("requests")) == 0 and (buy.get("table").get("rows") as Array).is_empty(), "offline: no search sent, no rows (%d requests)" % int(buy.get("requests")))
	_expect(shown == 0 and not (ms.get("rail") as Control).visible, "offline: only back and close are shown (%d other buttons)" % shown)
	_expect((ms.get("header") as Control).get("wallet").is_empty(), "offline: no currency counters")
	ms.queue_free()
	print("[t_exchange] offline screen: panel shown, %d searches, %d buttons besides back/close" % [int(buy.get("requests")), shown])

## The socket transport: NetClient's rid on the envelope (none in the body), and a timed-out
## request is resent with retry() under the same rid, never as a new request.
func _test_net_client() -> void:
	var net := FakeNet.new()
	var mc: RefCounted = (load("res://scripts/ui/market/net_market_client.gd") as GDScript).new(net)
	var res: Dictionary = await mc.call("request", "market.buy", {"listing_id": "L1"})
	_expect(res.get("ok", false) and net.sent.size() == 2, "net: a timeout is retried once and then answered: %s (%d sent)" % [res, net.sent.size()])
	_expect(net.sent.size() == 2 and net.sent[0].rid == net.sent[1].rid and not (net.sent[0].a as Dictionary).has("rid"), "net: the retry reuses the request's rid and the body carries none")
	_expect(int(mc.get("account")) == 7 and mc.call("is_online") and mc.call("kind") == &"net", "net: account and online state come from Game.net")

## Gates 5-6: one row per listing, uids == market.search uids; every sort the server offers keeps
## the uid set and the server's order across pages (page_size 4, so page 2 and 3 exist).
func _test_rows_and_sorts(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/rows")
	h.call("seed_scene")
	ms_script.set("test_client", h.call("client", 1))
	var ms: Control = await _open(ms_script)
	var buy: Control = ms.get("buy")
	var table: Control = buy.get("table")
	var want: Array = h.call("op", 1, "market.search", buy.call("args")).r.results
	_expect(_row_uids(table) == want.map(func (v: Dictionary) -> String: return str(v.asset.uid)), "rows are market.search's listings in its order")
	var branches := _row_uids(table).filter(func (u: String) -> bool: return _row_of(table, u).get("view").key == "item:branch")
	var distinct := {}
	for u: String in branches:
		distinct[u] = true
	_expect(branches.size() == 3 and distinct.size() == 3, "three listed single branches are three rows with three uids: %s" % [branches])
	var sorts: Array = MF.call("sorts")
	if "durability_asc" not in sorts:
		_hook_absent("H1", "level_asc/durability sorts")
		_expect(not (table.get("head_btns")[&"durability"] as Control).visible, "without H1 the Durability header offers no sort")
	buy.set("page_size", 4)
	var checked: PackedStringArray = []
	for s: String in ["price_asc", "price_desc", "level_desc", "level_asc", "durability_asc", "durability_desc"]:
		if s not in sorts:
			continue
		buy.set("sort", s)
		buy.set("page", 1)
		await buy.call("reload")
		var seen: Array = []
		var pages_seen := 1
		for guard in 20:
			seen.append_array(_row_uids(table))
			if int(table.get("page")) >= int(table.get("pages")):
				break
			table.emit_signal("page_requested", int(table.get("page")) + 1)
			pages_seen += 1
		var all: Array = h.call("op", 1, "market.search", {"sort": s, "page_size": 50}).r.results
		_expect(pages_seen >= 3 and seen == all.map(func (v: Dictionary) -> String: return str(v.asset.uid)), "sort %s: %d pages give the server's order and uid set" % [s, pages_seen])
		checked.append(s)
	buy.set("page_size", 20)
	buy.set("sort", "price_asc")
	await buy.call("reload")
	table.emit_signal("sort_pressed", &"price")
	_expect(buy.get("sort") == "price_desc", "pressing the active Price header asks the server for the other direction")
	ms.queue_free()
	print("[t_exchange] rows: %d listings, sorts checked across pages: %s" % [want.size(), ", ".join(checked)])

## Gate 7: Buy moves the exact instance to the buyer's market storage and debits exactly the
## price; the seller gets price - tax once; a second tap sends nothing.
func _test_buy(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/buy")
	h.call("seed_scene")
	ms_script.set("test_client", h.call("client", 1))
	var ms: Control = await _open(ms_script)
	var table: Control = ms.get("buy").get("table")
	var confirm: Control = ms.get("confirm")
	var row := _first(table, "item:branch")
	var v: Dictionary = row.get("view")
	var price := int(v.unit_price)
	var w1 := _wallet(h, 1)
	var w2 := _wallet(h, 2)
	_click(row)
	await process_frame
	_expect(confirm.visible and confirm.get("view").id == v.id, "a tap on a row opens its confirm")
	_click(confirm.get("buy_btn"))
	_click(confirm.get("buy_btn")) # double tap
	var tax := EconRules.ceil_bp(price, EconRules.load_default().bp("sales_tax"))
	_expect(str((confirm.get("status") as Label).text).begins_with("Bought."), "the confirm says where the purchase went: %s" % (confirm.get("status") as Label).text)
	_expect(_wallet(h, 1) == w1 - price and _wallet(h, 2) == w2 + price - tax, "buyer paid %d once (%d -> %d), seller got %d once (%d -> %d)" % [price, w1, _wallet(h, 1), price - tax, w2, _wallet(h, 2)])
	var got: Dictionary = {}
	for it: Dictionary in h.call("op", 1, "vault.get", {}).r.get("items", []):
		if str(it.get("uid", "")) == str(v.asset.uid):
			got = it
	_expect(not got.is_empty() and int(got.level) == int(v.asset.level) and got.attributes == v.asset.attributes and str(got.id) == "branch", "the exact instance (uid %s, level, attributes) is in the buyer's vault: %s" % [v.asset.uid, got])
	_expect(str(v.asset.uid) not in _row_uids(table), "the bought row leaves the table")
	_expect((ms.get("header") as Control).call("tradable") == _wallet(h, 1) - int(h.call("op", 1, "wallet.get", {}).r.bound), "the header shows the new tradable balance")
	ms.queue_free()
	print("[t_exchange] buy: %s for %d, tax %d, buyer %d -> %d" % [v.asset.uid, price, tax, w1, _wallet(h, 1)])

## Gate 9 (Buy's error paths): the text the player reads, and both stores unchanged.
func _test_buy_errors(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/errors")
	h.call("seed_scene")
	var bridge: Object = h.get("bridge")
	bridge.call("hello", 4, "BoundOnly", int(h.get("now")))
	h.set("now", int(h.get("now")) + EconRules.load_default().num("trade_lock_s") + 1)
	bridge.call("hello", 5, "Fresh", int(h.get("now")))
	ms_script.set("test_client", h.call("client", 1))
	var ms: Control = await _open(ms_script)
	var table: Control = ms.get("buy").get("table")
	var confirm: Control = ms.get("confirm")
	var m: Dictionary = (load("res://scripts/ui/market/market_theme.gd") as GDScript).call("metrics", ms.get_viewport_rect().size)
	var status := confirm.get("status") as Label
	var books := func () -> String: return JSON.stringify([h.call("op", 1, "market.search", {"page_size": 50}).r, h.call("op", 1, "wallet.get", {}).r, h.call("op", 4, "wallet.get", {}).r, h.call("op", 5, "wallet.get", {}).r])
	# self_trade: the viewer's own stone listing has no Buy; the server refuses it too.
	var own := _first(table, "item:stone")
	_click(own)
	await process_frame
	_expect(not (confirm.get("buy_btn") as Control).visible and status.text == "That is your own listing.", "own listing: no Buy, says so (%s)" % status.text)
	var before: String = books.call()
	(confirm.get("buy_btn") as Control).visible = true
	await confirm.call("buy")
	_expect(status.text == "That is your own listing." and books.call() == before, "self_trade from the server: %s, stores unchanged" % status.text)
	var branch: Dictionary = _first(table, "item:branch").get("view")
	# insufficient_funds with only bound coins: Buy disabled with the reason; a stale balance gets the server's refusal.
	var c4: RefCounted = h.call("client", 4)
	confirm.call("open", c4, branch, 0, false, m)
	_expect((confirm.get("buy_btn") as Button).disabled and status.text.begins_with("Not enough tradable T-stones."), "bound coins only: Buy disabled with the reason (%s)" % status.text)
	confirm.call("open", c4, branch, 999, false, m)
	await confirm.call("buy")
	_expect(status.text.begins_with("Not enough tradable T-stones.") and books.call() == before, "insufficient_funds from the server: %s, stores unchanged" % status.text)
	# Trade lock: a fresh account cannot buy yet.
	confirm.call("open", h.call("client", 5), branch, 999, false, m)
	await confirm.call("buy")
	_expect(status.text.begins_with("New accounts can trade in") and books.call() == before, "trade lock: %s, stores unchanged" % status.text)
	# Offline: the base client says so and nothing moves.
	confirm.call("open", (load("res://scripts/ui/market/market_client.gd") as GDScript).new(), branch, 999, false, m)
	await confirm.call("buy")
	_expect(status.text == "The Island Market needs a connection to the game server." and books.call() == before, "offline buy: %s" % status.text)
	# Sold under us: another player buys it first; the confirm says so and the row leaves.
	confirm.call("open", h.call("client", 1), branch, 999, false, m)
	h.call("op", 3, "market.buy", {"listing_id": branch.id, "count": 1})
	var w1 := _wallet(h, 1)
	await confirm.call("buy")
	_expect(status.text == "No longer available." and _wallet(h, 1) == w1 and not (confirm.get("buy_btn") as Control).visible, "sold listing: %s, buyer's wallet unchanged" % status.text)
	_expect(str(branch.asset.uid) not in _row_uids(table), "the sold row leaves the table after the refusal")
	ms.queue_free()
	print("[t_exchange] buy errors: self_trade, bound-only, trade lock, offline, sold - each shown, stores unchanged")

## H2: Animals = bonded pets + captured cages (one row each); a clade row narrows to its species;
## an item category lists its own defs. Without H2 the search sheet offers no categories.
func _test_categories(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/cats")
	h.call("seed_scene")
	ms_script.set("test_client", h.call("client", 1))
	var ms: Control = await _open(ms_script)
	var buy: Control = ms.get("buy")
	var table: Control = buy.get("table")
	var search: Control = ms.get("search")
	if not MF.call("has_filter", "market_category"):
		_hook_absent("H2", "market categories and clade rows")
		_expect((search.get("categories") as Array).is_empty(), "without H2 the search sheet offers no categories")
		ms.queue_free()
		return
	_expect((search.get("categories") as Array).size() == (MF.call("categories") as Array).size(), "the search sheet lists every market category")
	search.emit_signal("category_chosen", "animal")
	var keys := _row_keys(table)
	_expect((buy.get("column") as Control).visible and keys.size() == 4 and keys.count("pet:compsognathus") == 1 and keys.count("item:captured_animal") == 3, "Animals: the bonded pet and three cages, one row each: %s" % [keys])
	var pet_row := _first(table, "pet:compsognathus")
	var cage_row := _first(table, "item:captured_animal")
	var pm: Dictionary = pet_row.get("model")
	var cm: Dictionary = cage_row.get("model")
	_expect(pm.badge and pm.icon == &"tamed_animal" and cm.name == "Captured Compsognathus" and not cm.badge and cm.icon == &"captured_animal", "a bonded pet has the B badge, a cage reads Captured <species>: %s / %s" % [pm.name, cm.name])
	var col: Control = buy.get("column")
	var titles: Array = (col.get("entries") as Array).map(func (e: Dictionary) -> String: return str(e.title))
	_expect(titles[0] == "View All" and "Compy Type" in titles and "Raptor Type" in titles and "Avian Type" not in titles and "Wolf Type" not in titles, "Animals column: View All then real clades only: %s" % [titles])
	col.emit_signal("picked", "clade:Compsognathidae")
	_expect(_row_keys(table).size() == 4, "Compy Type: the compsognathus pet and cages")
	col.emit_signal("picked", "clade:Dromaeosauridae")
	_expect(_row_keys(table).is_empty() and str((table.get("_empty") as Label).text).contains("Animals"), "Raptor Type: no listings, said so")
	search.emit_signal("category_chosen", "wood")
	_expect((table.get("rows") as Array).all(func (r: Control) -> bool: return r.get("model").type == "Wood") and _row_keys(table).count("item:branch") == 3, "Wood: only wood items: %s" % [_row_keys(table)])
	col.emit_signal("picked", "def:branch")
	_expect(_row_keys(table) == ["item:branch", "item:branch", "item:branch"], "Wood > Branch: the three branches")
	col.emit_signal("closed")
	_expect(not col.visible and _row_keys(table).size() == (h.call("op", 1, "market.search", {"page_size": 20}).r.results as Array).size(), "closing the category shows everything again")
	search.emit_signal("searched", "branch")
	var chips: Array = table.get("chips")
	_expect(chips.size() == 1 and _row_keys(table).size() == 3, "a name search shows a chip and only matching rows")
	table.emit_signal("chip_removed", &"q")
	_expect((table.get("chips") as Array).is_empty() and _row_keys(table).size() > 3, "removing the chip clears the search")
	ms.queue_free()
	print("[t_exchange] categories: Animals %d rows, clades %s" % [keys.size(), titles.size() - 1])

## Gate 8: the picker is the server character's own instances (bag, bonded pets, market storage),
## refused ones visible with their reason; List moves that exact instance (a part of a stack under
## the uid the deposit answers) and the preview equals the ledger: fee now, price - tax on sale.
## A bonded pet and a captured animal are listed as what they are (pet carrier with B, crate).
func _test_sell(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/sell")
	h.call("seed_scene")
	var ms: Control = await _open_sell(h, 1, ms_script)
	var sell: Control = ms.get("sell")
	var picker: Control = sell.get("picker")
	var form: Control = sell.get("form")
	_expect(sell.visible and not (ms.get("buy") as Control).visible, "the rail's Sell tab shows Sell")
	# Picker == the server character's bag stacks in slot order, then its pets, then its market storage.
	var ch: Dictionary = h.call("op", 1, "char.get", {}).r
	var want: Array = []
	var lock := str((load("res://scripts/server/character_state.gd") as GDScript).get_script_constant_map().LOCK)
	for row: Variant in ch.bag:
		if row is Dictionary and str(row.id) != lock:
			want.append(str(row.uid))
	want.append_array((ch.pets as Dictionary).keys())
	var vault: Dictionary = h.call("op", 1, "vault.get", {}).r
	for it: Dictionary in vault.items:
		want.append(str(it.uid))
	var got: Array = (picker.get("entries") as Array).map(func (e: Dictionary) -> String: return str(e.uid))
	_expect(got == want and (picker.get("cells") as Array).size() == want.size(), "picker cells == server bag + pets + storage, one per instance: %s vs %s" % [got, want])
	var bone := _entry(sell, func (e: Dictionary) -> bool: return e.src == "bag" and str(e.asset.id) == "bone")
	var stone := _entry(sell, func (e: Dictionary) -> bool: return e.src == "bag" and str(e.asset.id) == "stone")
	var pet := _entry(sell, func (e: Dictionary) -> bool: return e.src == "pet")
	var cage := _entry(sell, func (e: Dictionary) -> bool: return e.src == "bag" and str(e.asset.id) == "captured_animal")
	var stored := _entry(sell, func (e: Dictionary) -> bool: return e.src == "vault")
	_expect(pet.get("badge", false) and pet.get("icon") == &"tamed_animal" and not cage.get("badge", true) and cage.get("icon") == &"captured_animal" and str(cage.get("name", "")) == "Captured Compsognathus", "a bonded pet is a B pet carrier, a captured one a crate: %s / %s" % [pet.get("name"), cage.get("name")])
	# Locked: dimmed with its reason, nothing to list; the server refuses it too and nothing moves.
	await _click_cell(sell, str(stone.uid))
	var status := form.get("status") as Label
	_expect(str(stone.why).begins_with("Locked") and status.text == stone.why and not (form.get("_form") as Control).visible and (form.get("list_btn") as Button).disabled, "a locked stack shows why and cannot be listed: %s" % status.text)
	var before := JSON.stringify([h.call("op", 1, "char.get", {}).r.bag, h.call("op", 1, "wallet.get", {}).r])
	var forced: Dictionary = h.call("op", 1, "vault.deposit", {"bag_slot": _slot_of(h, str(stone.uid)), "count": 1})
	_expect(forced.get("err", "") == "invalid_asset" and str(forced.get("msg", "")).contains("locked") and before == JSON.stringify([h.call("op", 1, "char.get", {}).r.bag, h.call("op", 1, "wallet.get", {}).r]), "the server refuses a locked stack too, nothing moved: %s" % forced)
	# Part of a stack: 1 of 2 bones at a price inside the band (ref = the viewer's own bone buy).
	await _click_cell(sell, str(bone.uid))
	var band: Array = MF.call("band", int(form.get("ref")))
	_expect(int(form.get("ref")) > 0 and band.size() == 2 and int(form.get("lo")) == int(band[0]) and int(form.get("hi")) == int(band[1]) and str((form.get("band_label") as Label).text).contains(MF.call("group", band[1])), "bone: the band around the reference price is shown: %s" % (form.get("band_label") as Label).text)
	_expect(int(form.get("count")) == int(bone.count) and int(bone.count) == 2, "a stack starts at its whole count (%d)" % int(form.get("count")))
	(form.get("steppers").count_down as Button).pressed.emit()
	var edit := form.get("price_edit") as LineEdit
	edit.text = str(int(band[1]) + 50)
	edit.text_changed.emit(edit.text)
	edit.text_submitted.emit(edit.text)
	_expect(int(form.get("unit")) == int(band[1]) + 50 and status.text.begins_with("Outside the usual range") and (form.get("list_btn") as Button).text.begins_with("List anyway for") and not (form.get("list_btn") as Button).disabled, "a typed price above the band is warned about, not refused (%s)" % status.text)
	(form.get("steppers").price_down as Button).pressed.emit()
	_expect(int(form.get("unit")) == int(band[1]) and status.text == "" and (form.get("steppers").price_up as Button).disabled, "the stepper brings it back to the band's top and the warning goes (%d)" % int(form.get("unit")))
	var unit := int(band[0]) + 7
	edit.text = str(unit)
	edit.text_changed.emit(edit.text)
	var p: Dictionary = MF.call("preview", unit, 1)
	_expect((form.get("preview_values").fee as Label).text == MF.call("group", p.fee) and (form.get("preview_values").receive as Label).text == MF.call("group", p.receive) and (form.get("list_btn") as Button).text == "List for %s" % MF.call("group", p.total), "the preview shows fee %d, receive %d" % [p.fee, p.receive])
	var w0 := _wallet(h, 1)
	var ids0: Array = (h.call("op", 1, "market.mine", {}).r.listings as Array).map(func (l: Dictionary) -> String: return str(l.id))
	_click(form.get("list_btn"))
	_click(form.get("list_btn")) # double tap
	await process_frame
	var mine: Array = h.call("op", 1, "market.mine", {}).r.listings
	var new_rows := mine.filter(func (l: Dictionary) -> bool: return str(l.id) not in ids0)
	var lst: Dictionary = new_rows[0] if new_rows.size() == 1 else {}
	var left := _bag_row(h, str(bone.uid))
	_expect(new_rows.size() == 1 and _wallet(h, 1) == w0 - int(p.fee), "List: one listing, fee %d paid once (%d -> %d)" % [p.fee, w0, _wallet(h, 1)])
	_expect(int(lst.get("qty", 0)) == 1 and int(lst.get("unit_price", 0)) == unit and str(lst.get("asset", {}).get("id", "")) == "bone" and int(lst.asset.level) == int(bone.asset.level) and lst.asset.get("attributes", {}) == bone.asset.get("attributes", {}), "the listing is 1 bone with the stack's level and attributes at %d" % unit)
	_expect(int(left.get("count", 0)) == 1 and str(lst.get("asset", {}).get("uid", "")) != str(bone.uid), "the rest of the stack stays in the bag under its uid; the part has its own")
	_expect(status.text.begins_with("Listed"), "the panel says it is listed: %s" % status.text)
	h.call("op", 2, "market.buy", {"listing_id": str(lst.get("id", "")), "count": 1})
	_expect(_wallet(h, 1) == w0 - int(p.fee) + int(p.receive) and _wallet(h, 1) - w0 == int(p.net), "after a sale the ledger moved exactly the preview: net %d (%d -> %d)" % [p.net, w0, _wallet(h, 1)])
	# A bonded pet is listed as the pet (one instance, its uid); a captured animal as its cage.
	await _list_entry(sell, str(pet.uid), 0)
	await _list_entry(sell, str(cage.uid), 0)
	var mine_keys := {}
	for l: Dictionary in h.call("op", 1, "market.mine", {}).r.listings:
		mine_keys[str(l.asset.uid)] = str(l.key)
	_expect(mine_keys.get(str(pet.uid), "") == "pet:compsognathus" and mine_keys.get(str(cage.uid), "") == "item:captured_animal", "the pet and the cage are listed under their own uids: %s" % mine_keys)
	_expect(not str(pet.uid) in (h.call("op", 1, "char.get", {}).r.pets as Dictionary), "the listed pet left the character")
	# What waits in market storage lists with no deposit.
	var w1 := _wallet(h, 1)
	var stored_uid := str(stored.uid)
	await _list_entry(sell, stored_uid, 0)
	var found := false
	for l: Dictionary in h.call("op", 1, "market.mine", {}).r.listings:
		found = found or str(l.asset.uid) == stored_uid
	_expect(found and _wallet(h, 1) < w1, "a stored item is listed straight from market storage")
	# The picked stack leaves the bag elsewhere (another device) before List: the slot is re-read by
	# uid, so nothing else in that slot is listed, and the player is told.
	await _click_cell(sell, str(bone.uid))
	var gone: Dictionary = h.call("op", 1, "vault.deposit", {"bag_slot": _slot_of(h, str(bone.uid)), "count": 1})
	var n_before: int = (h.call("op", 1, "market.mine", {}).r.listings as Array).size()
	_click(form.get("list_btn"))
	await process_frame
	_expect(gone.get("ok", false) and status.text == "That item is no longer in your bag." and (h.call("op", 1, "market.mine", {}).r.listings as Array).size() == n_before, "a stack that left the bag is not replaced by whatever sits in its slot: %s" % status.text)
	# INVUI's "Sell on Market": the screen opens on Sell with that instance picked.
	var knife := _entry(sell, func (e: Dictionary) -> bool: return str(e.asset.get("id", "")) == "stone_knife_work")
	ms.call("close_screen")
	ms.call("open", null, &"sell", str(knife.uid))
	await process_frame
	_expect(sell.visible and str(sell.get("selected")) == str(knife.uid) and str((form.get("_title") as Label).text) == str(knife.name), "open(sell, uid) picks that instance: %s" % sell.get("selected"))
	ms.queue_free()
	print("[t_exchange] sell: %d cells, bone 1/2 at %d fee %d tax %d net %d, pet %s and cage %s listed, stored %s listed" % [got.size(), unit, p.fee, p.tax, p.net, pet.uid, cage.uid, stored_uid])

## Gate 9 (Sell's error paths): bound coins cannot pay the fee, prices out of range, the band is
## advice (the server takes a price outside it), refusal reasons for what the client can see, and a
## list step refused after the deposit keeps the item safe in market storage.
func _test_sell_errors(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/sell_errors")
	h.call("seed_scene")
	var bridge: Object = h.get("bridge")
	bridge.call("hello", 4, "BoundOnly", int(h.get("now")))
	h.set("now", int(h.get("now")) + EconRules.load_default().num("trade_lock_s") + 1)
	bridge.call("client", "act.gather", 4, {"node_id": "rock", "option": 0}, int(h.get("now")))
	var ms: Control = await _open_sell(h, 4, ms_script)
	var sell: Control = ms.get("sell")
	var form: Control = sell.get("form")
	var status := form.get("status") as Label
	var rock := _entry(sell, func (e: Dictionary) -> bool: return str(e.asset.get("id", "")) == "stone")
	await _click_cell(sell, str(rock.uid))
	var edit := form.get("price_edit") as LineEdit
	edit.text = "0"
	edit.text_changed.emit("0")
	_expect((form.get("list_btn") as Button).disabled and (form.get("list_btn") as Button).text == "Set a price", "price 0: List is disabled until a price is set")
	edit.text = "5000000"
	edit.text_changed.emit(edit.text)
	edit.focus_exited.emit()
	var hi: int = int(form.get("hi"))
	_expect(int(form.get("unit")) == hi and hi <= EconRules.load_default().num("max_unit_price"), "a price over the maximum is pulled to %d" % hi)
	edit.text = "40"
	edit.text_changed.emit("40")
	_expect((form.get("list_btn") as Button).disabled and status.text.contains("Bound T-stones can't pay"), "bound coins only: List disabled, the fee reason shown (%s)" % status.text)
	var before := JSON.stringify([h.call("op", 4, "char.get", {}).r.bag, h.call("op", 4, "wallet.get", {}).r, h.call("op", 4, "vault.get", {}).r])
	# A stale balance (the panel thinks the fee is payable): the server refuses the listing after the
	# deposit, the stone waits in market storage, the wallet is untouched.
	form.set("tradable", 999)
	sell.call("list_selected")
	await process_frame
	var vault: Array = h.call("op", 4, "vault.get", {}).r.items
	_expect(status.text.begins_with("Not enough tradable T-stones.") and status.text.contains("safe in your market storage") and int(h.call("op", 4, "wallet.get", {}).r.wallet) == 20 and vault.size() == 1 and str(vault[0].id) == "stone", "insufficient_funds after the deposit: %s; stone stored, wallet 20" % status.text)
	_expect(str(sell.get("selected")) == str(vault[0].uid) if not vault.is_empty() else false, "the stored stone stays picked to list again")
	_expect(before != JSON.stringify([h.call("op", 4, "char.get", {}).r.bag, h.call("op", 4, "wallet.get", {}).r, h.call("op", 4, "vault.get", {}).r]), "the deposit really moved the stone (bag -> storage)")
	# The server refuses prices out of 1..max_unit_price, whatever a client sends.
	var mc: RefCounted = h.call("client", 1)
	var bone_uid := ""
	for it: Dictionary in h.call("op", 1, "vault.get", {}).r.items:
		if str(it.id) == "bone":
			bone_uid = str(it.uid)
	var w1 := JSON.stringify(h.call("op", 1, "wallet.get", {}).r)
	for bad: int in [0, EconRules.load_default().num("max_unit_price") + 1]:
		var r: Dictionary = await mc.call("request", "market.list_fixed", {"asset": {"uid": bone_uid}, "unit_price": bad, "duration_h": 24})
		_expect(r.get("err", "") == "bad_request" and JSON.stringify(h.call("op", 1, "wallet.get", {}).r) == w1, "unit_price %d refused by the server: %s" % [bad, r.get("msg", "")])
	# The band is the reference filter (contract 6.5), not a listing limit: the server lists above it
	# (a rare-trait instance can be worth more than 4x its def), so the panel warns instead of refusing.
	var ref := int(h.call("op", 1, "market.item_detail", {"def_id": "bone"}).r.ref_price)
	var band: Array = MF.call("band", ref)
	var out: Dictionary = await mc.call("request", "market.list_fixed", {"asset": {"uid": bone_uid}, "unit_price": int(band[1]) + 1, "duration_h": 24})
	_expect(band.size() == 2 and out.get("ok", false), "a price above the band %s is the seller's choice: %s" % [band, out.get("err", "ok")])
	# Refusal reasons for what the client can see (the server's own words for the rest).
	var why := func (kind: String, a: Dictionary) -> String: return str(MF.call("sell_refusal", kind, a))
	_expect(why.call("item", {"id": "tamed_animal", "count": 1}).contains("bond"), "denied def (tamed_animal): %s" % why.call("item", {"id": "tamed_animal", "count": 1}))
	_expect(why.call("item", {"id": "stone", "count": 1, "flags": ["unstable"]}).contains("Cargo-warp"), "unstable goods say cargo-warp first")
	_expect(why.call("item", {"id": "stone_knife_work", "count": 1, "durability": 0, "max_durability": 40}).begins_with("Broken"), "a broken tool says so")
	_expect(why.call("pet", {"species": "compsognathus", "summoned": true}).begins_with("Dismiss") and why.call("pet", {"species": "compsognathus", "bag": ["x"]}).begins_with("Empty"), "a summoned or loaded pet says what to do")
	_expect(why.call("item", {"id": "bone", "count": 2, "flags": ["raw"]}) == "", "an ordinary stack can be sold")
	ms.queue_free()
	print("[t_exchange] sell errors: price 0, over max, bound-only fee, stale balance (stored, wallet kept), server range, band %s, refusal reasons" % [band])

## Picks `uid` in the open Sell tab and lists it at `price` (0 = the panel's starting price).
func _list_entry(sell: Control, uid: String, price: int) -> void:
	var form: Control = sell.get("form")
	await _click_cell(sell, uid)
	if price > 0:
		(form.get("price_edit") as LineEdit).text_changed.emit(str(price))
	if int(form.get("unit")) == 0:
		(form.get("steppers").price_up as Button).pressed.emit() # no market price yet: start at the band's floor
	_expect(form.call("can_list"), "%s can be listed (%s)" % [uid, (form.get("list_btn") as Button).text])
	_click(form.get("list_btn"))
	await process_frame
	_expect(str((form.get("status") as Label).text).begins_with("Listed"), "%s listed: %s" % [uid, (form.get("status") as Label).text])

## A real click on a picker cell, scrolled into view first (the grid scrolls like the Bag's).
func _click_cell(sell: Control, uid: String) -> void:
	var picker: Control = sell.get("picker")
	var cell: Control = picker.call("cell_of", uid)
	if not _expect(cell != null, "a picker cell for %s" % uid):
		return
	(picker.get("_scroll") as ScrollContainer).ensure_control_visible(cell)
	await process_frame
	_click(cell)
	await process_frame

func _open_sell(h: RefCounted, acct: int, ms_script: GDScript) -> Control:
	ms_script.set("test_client", h.call("client", acct))
	var ms: Control = await _open(ms_script)
	_click((ms.get("rail") as Control).get("buttons")[&"sell"])
	await process_frame
	await process_frame
	return ms

func _entry(sell: Control, pred: Callable) -> Dictionary:
	for e: Dictionary in sell.get("entries"):
		if pred.call(e):
			return e
	failures.append("no such entry in the Sell picker")
	return {"uid": "", "why": "", "asset": {}, "count": 0, "name": ""}

func _slot_of(h: RefCounted, uid: String) -> int:
	var bag: Array = h.call("op", 1, "char.get", {}).r.bag
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].get("uid", "")) == uid:
			return i
	return -1

func _bag_row(h: RefCounted, uid: String) -> Dictionary:
	var i := _slot_of(h, uid)
	return h.call("op", 1, "char.get", {}).r.bag[i] if i >= 0 else {}

## Gate 11: the HUD's MENU sheet has an Island Market row that opens the screen (hook H0).
## B3 My Market: every sub-tab is market.mine's own rows (Active = open listings, Sold / Expired =
## closed ones by state, History = the account's trades), and Sold says what the sale credited.
func _test_my_market(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/mine")
	h.call("seed_scene")
	var sale: String = h.call("list_one", 1, "bone", 1, 20)
	var w1 := _wallet(h, 1)
	h.call("op", 2, "market.buy", {"listing_id": sale, "count": 1})
	var credited := _wallet(h, 1) - w1
	var ms: Control = await _open_mine(h, 1, ms_script)
	var mine: Control = ms.get("mine")
	_expect(mine.visible and not (ms.get("buy") as Control).visible and not (ms.get("sell") as Control).visible, "the rail's My Market tab shows My Market")
	var r: Dictionary = h.call("op", 1, "market.mine", {"page_size": 20}).r
	var ids := func (rows: Array) -> Array: return rows.map(func (v: Dictionary) -> String: return str(v.id))
	var closed: Array = r.closed_listings
	var want := {
		&"active": ids.call(r.listings),
		&"sold": ids.call(closed.filter(func (l: Dictionary) -> bool: return l.state == "sold")),
		&"expired": ids.call(closed.filter(func (l: Dictionary) -> bool: return l.state != "sold")),
		&"history": ids.call(r.trades),
	}
	for sub: StringName in want:
		_click((mine.get("tab_btns") as Dictionary)[sub])
		await process_frame
		var got := _mine_ids(mine)
		_expect(mine.get("tab") == sub and got == want[sub] and not got.is_empty(), "My Market %s rows == market.mine (%s vs %s)" % [sub, got, want[sub]])
	_expect((want[&"sold"] as Array).has(sale) and (want[&"expired"] as Array).size() >= 1, "the seeded viewer has sold and expired listings")
	_click((mine.get("tab_btns") as Dictionary)[&"sold"])
	await process_frame
	var row := _mine_row(mine, sale)
	_expect(row != null and str(row.get("model").dur) == "Sold · +%s credited" % MF.call("group", credited) and credited == 20 - EconRules.ceil_bp(20, EconRules.load_default().bp("sales_tax")), "a sold row says the net its sale credited (+%d): %s" % [credited, row.get("model").dur if row else "no row"])
	_click((mine.get("tab_btns") as Dictionary)[&"history"])
	await process_frame
	var kinds := {}
	for m: Dictionary in (mine.get("rows") as Array).map(func (x: Node) -> Dictionary: return x.get("model")):
		kinds[str(m.dur).get_slice(" · ", 0)] = true
	_expect(kinds.has("Bought") and kinds.has("Sold") and kinds.has("Sold to Settlers"), "history tells bought, sold and sold to Settlers apart: %s" % [kinds.keys()])
	_click((mine.get("tab_btns") as Dictionary)[&"active"])
	await process_frame
	var active: Dictionary = (r.listings as Array)[0]
	_expect(str(_mine_row(mine, str(active.id)).get("model").dur).begins_with("Ends in ") and _mine_row(mine, str(active.id)).find_child("Cancel_*", false, false) != null, "an active row says when it ends and has Cancel")
	ms.queue_free()
	print("[t_exchange] my market: active %d, sold %d, expired %d, history %d rows == market.mine; sold +%d" % [(want[&"active"] as Array).size(), (want[&"sold"] as Array).size(), (want[&"expired"] as Array).size(), (want[&"history"] as Array).size(), credited])

## B3 Cancel: the confirm says the fee stays paid; one market.cancel (double tap) puts the exact
## units back in market storage under their uid, the wallet unchanged; a listing that sold while
## the panel was open is refused with "No longer available." and nothing moves.
func _test_cancel(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/cancel")
	h.call("seed_scene")
	var late: String = h.call("list_one", 1, "bone", 1, 30)
	var ms: Control = await _open_mine(h, 1, ms_script)
	var mine: Control = ms.get("mine")
	var confirm: Control = ms.get("confirm")
	var status := confirm.get("status") as Label
	var lst: Dictionary = {}
	for l: Dictionary in h.call("op", 1, "market.mine", {}).r.listings:
		if str(l.key) == "item:stone":
			lst = l
	var books := func () -> String: return JSON.stringify([h.call("op", 1, "char.get", {}).r, h.call("op", 1, "vault.get", {}).r, h.call("op", 1, "wallet.get", {}).r])
	var w := _wallet(h, 1)
	var waiting := (mine.get("waiting") as Array).size()
	_click(_mine_row(mine, str(lst.id)).find_child("Cancel_*", false, false))
	await process_frame
	_expect(confirm.visible and confirm.get("mode") == &"cancel" and str((confirm.get("_balance") as Label).text).contains("fee of %s T-stone%s is not refunded" % [MF.call("group", int(lst.fee)), "" if int(lst.fee) == 1 else "s"]), "Cancel opens the listing with the kept fee (%d) said" % int(lst.fee))
	_click(confirm.get("buy_btn"))
	_click(confirm.get("buy_btn")) # double tap
	await process_frame
	var back: Dictionary = {}
	for it: Dictionary in h.call("op", 1, "vault.get", {}).r.items:
		if str(it.uid) == str(lst.asset.uid):
			back = it
	_expect(status.text.begins_with("Cancelled.") and _wallet(h, 1) == w, "cancelled once, fee kept: %s (wallet %d -> %d)" % [status.text, w, _wallet(h, 1)])
	_expect(int(back.get("count", 0)) == int(lst.left) and int(back.get("level", -1)) == int(lst.asset.level) and back.get("attributes") == lst.asset.get("attributes"), "the exact units (uid %s) are back in market storage: %s" % [lst.asset.uid, back])
	_expect(str(lst.id) not in _mine_ids(mine) and (mine.get("waiting") as Array).size() == waiting + 1, "the row leaves Active and storage holds one more (%d)" % (mine.get("waiting") as Array).size())
	_click(confirm.get("cancel_btn")) # "Done"
	await process_frame
	_click((mine.get("tab_btns") as Dictionary)[&"expired"])
	await process_frame
	var gone := _mine_row(mine, str(lst.id))
	_expect(not confirm.visible and gone != null and str(gone.get("model").dur) == "Cancelled · back in storage", "Expired lists it as cancelled")
	# A listing that sells while its cancel panel is open: refused, nothing moves.
	_click((mine.get("tab_btns") as Dictionary)[&"active"])
	await process_frame
	_click(_mine_row(mine, late).find_child("Cancel_*", false, false))
	await process_frame
	h.call("op", 2, "market.buy", {"listing_id": late, "count": 1})
	var before: String = books.call()
	_click(confirm.get("buy_btn"))
	await process_frame
	_expect(status.text == "No longer available." and books.call() == before, "cancel of a sold listing: %s, stores unchanged" % status.text)
	_expect(late not in _mine_ids(mine), "the sold listing leaves Active after the refusal")
	ms.queue_free()
	print("[t_exchange] cancel: %s back in storage, fee %d kept; sold-meanwhile refused" % [lst.asset.uid, int(lst.fee)])

## B3 Receive All (gate 7's last step): the inbox is taken and shown, every item and pet waiting in
## market storage reaches the bag (a bought knife under its own uid, durability and level), and a
## second press moves nothing.
func _test_receive_all(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/receive")
	h.call("seed_scene")
	var knife: Dictionary = {}
	for v: Dictionary in h.call("op", 1, "market.search", {"page_size": 50}).r.results:
		if str(v.key) == "item:stone_knife_work":
			knife = v
	h.call("op", 1, "market.buy", {"listing_id": knife.id, "count": 1})
	var vault: Dictionary = h.call("op", 1, "vault.get", {}).r
	var bag0 := _bag_counts(h)
	var ms: Control = await _open_mine(h, 1, ms_script)
	var mine: Control = ms.get("mine")
	var n: int = (vault.items as Array).size() + (vault.pets as Array).size()
	_expect((mine.get("waiting") as Array).size() == n and n >= 3 and str((mine.get("_waiting_label") as Label).text) == "%d waiting in market storage" % n, "My Market says what waits in storage (%d)" % n)
	_click(mine.get("receive_btn"))
	if mine.get("receiving"):
		await mine.received
	var after: Dictionary = h.call("op", 1, "vault.get", {}).r
	var bag1 := _bag_counts(h)
	var moved_ok := true
	for it: Dictionary in vault.items:
		moved_ok = moved_ok and int(bag1.get(str(it.id), 0)) - int(bag0.get(str(it.id), 0)) >= int(it.count)
	var home := _bag_row(h, str(knife.asset.uid))
	_expect((after.items as Array).is_empty() and (after.pets as Array).is_empty() and moved_ok, "Receive All empties market storage into the bag: %s -> %s" % [bag0, bag1])
	_expect(int(home.get("durability", -1)) == int(knife.asset.durability) and int(home.get("level", -1)) == int(knife.asset.level), "the bought knife is in the bag under its own uid %s with its durability and level: %s" % [knife.asset.uid, home])
	var text := (mine.get("status") as Label).text
	_expect(text.begins_with("Received %d into your bag." % n) and text.contains("Sold Fibre Stalk ×1 to Trader2"), "the status says what came home and the inbox news: %s" % text)
	_expect((h.call("op", 1, "inbox.take", {}).r.events as Array).is_empty(), "the inbox was taken")
	var before := JSON.stringify([h.call("op", 1, "char.get", {}).r, h.call("op", 1, "vault.get", {}).r, h.call("op", 1, "wallet.get", {}).r])
	_expect((mine.get("receive_btn") as Button).disabled, "Receive All is disabled with nothing waiting")
	await mine.call("receive_all")
	_expect(before == JSON.stringify([h.call("op", 1, "char.get", {}).r, h.call("op", 1, "vault.get", {}).r, h.call("op", 1, "wallet.get", {}).r]) and (mine.get("status") as Label).text == "Nothing was waiting.", "a second Receive All moves nothing: %s" % (mine.get("status") as Label).text)
	ms.queue_free()
	print("[t_exchange] receive all: %d from storage to the bag, knife %s home; second press moved nothing" % [n, knife.asset.uid])

## B3 Receive All into a full bag: what fits comes home, the rest waits with the reason, nothing is
## lost (every unit is in the bag or still in storage), and pressing again while full moves nothing.
func _test_receive_bag_full(hs: GDScript, ms_script: GDScript) -> void:
	var h: RefCounted = hs.new(DIR + "/full")
	h.call("seed_scene")
	for v: Dictionary in h.call("op", 1, "market.search", {"page_size": 50}).r.results:
		if str(v.key) == "item:stone_knife_work":
			h.call("op", 1, "market.buy", {"listing_id": v.id, "count": 1})
	h.call("fill_bag", 1)
	_expect((h.get("failures") as PackedStringArray).is_empty(), "the harness fills the bag: %s" % ", ".join(h.get("failures")))
	var vault: Dictionary = h.call("op", 1, "vault.get", {}).r
	var units := func () -> Dictionary:
		var c := _bag_counts(h)
		for it: Dictionary in h.call("op", 1, "vault.get", {}).r.items:
			c[str(it.id)] = int(c.get(str(it.id), 0)) + int(it.count)
		return c
	var total0: Dictionary = units.call()
	var ms: Control = await _open_mine(h, 1, ms_script)
	var mine: Control = ms.get("mine")
	_click(mine.get("receive_btn"))
	if mine.get("receiving"):
		await mine.received
	var left: Array = h.call("op", 1, "vault.get", {}).r.items
	var text := (mine.get("status") as Label).text
	_expect(not left.is_empty() and text.contains("%d still waiting: Your bag is full." % left.size()) and (mine.get("waiting") as Array).size() == left.size(), "a full bag: %d of %d still waiting, said: %s" % [left.size(), (vault.items as Array).size(), text])
	_expect(units.call() == total0, "nothing is lost: every unit is in the bag or in storage (%s)" % units.call())
	var before := JSON.stringify([h.call("op", 1, "char.get", {}).r, h.call("op", 1, "vault.get", {}).r])
	_click(mine.get("receive_btn"))
	if mine.get("receiving"):
		await mine.received
	_expect(before == JSON.stringify([h.call("op", 1, "char.get", {}).r, h.call("op", 1, "vault.get", {}).r]), "pressing again with the bag still full moves nothing")
	ms.queue_free()
	print("[t_exchange] receive all, full bag: %d waiting, nothing lost, second press moved nothing" % left.size())

func _test_menu(hs: GDScript, ms_script: GDScript) -> void:
	var hud_script := load("res://scripts/ui/hunt_hud.gd") as GDScript
	if hud_script == null or not hud_script.get_script_method_list().any(func (f: Dictionary) -> bool: return f.name == "open_market"):
		_hook_absent("H0", "HUD menu row Island Market")
		return
	var h: RefCounted = hs.new(DIR + "/menu")
	ms_script.set("test_client", h.call("client", 1))
	var hud: Control = hud_script.new()
	get_root().add_child(hud)
	hud.call("_toggle_sheet", &"menu")
	var entry: Button = null
	for b in hud.find_children("*", "Button", true, false):
		if (b as Button).text == "Island Market":
			entry = b
	_expect(entry != null, "the HUD menu has an Island Market row")
	if entry:
		entry.pressed.emit()
	var ms := hud.find_child("MarketScreen", true, false) as Control
	_expect(ms != null and ms.visible and (ms.get_parent() as CanvasLayer).layer == 96, "Island Market opens the market screen on layer 96")
	_expect(hud.get("_sheet") == null, "the menu sheet closes")
	await process_frame # let the sheet's own await finish before the HUD goes
	await process_frame
	hud.queue_free()
	print("[t_exchange] menu: HUD MENU -> Island Market -> MarketScreen visible=%s" % (ms != null and ms.visible))

func _open_mine(h: RefCounted, acct: int, ms_script: GDScript) -> Control:
	ms_script.set("test_client", h.call("client", acct))
	var ms: Control = await _open(ms_script)
	_click((ms.get("rail") as Control).get("buttons")[&"my_market"])
	await process_frame
	await process_frame
	return ms

## Listing / trade ids of the My Market rows, in order.
func _mine_ids(mine: Control) -> Array:
	return (mine.get("rows") as Array).filter(func (r: Node) -> bool: return not r.is_queued_for_deletion()).map(func (r: Node) -> String: return str(r.get("model").id))

func _mine_row(mine: Control, id: String) -> Control:
	for r: Control in mine.get("rows"):
		if not r.is_queued_for_deletion() and str(r.get("model").id) == id:
			return r
	return null

## def -> units in the viewer's server bag.
func _bag_counts(h: RefCounted) -> Dictionary:
	var c := {}
	for row: Variant in h.call("op", 1, "char.get", {}).r.bag:
		if row is Dictionary and row.has("count"):
			c[str(row.id)] = int(c.get(str(row.id), 0)) + int(row.count)
	return c

## Opens the screen and waits for its containers to lay out (clicks need real rects).
func _open(ms_script: GDScript) -> Control:
	var ms: Control = ms_script.new()
	get_root().add_child(ms)
	ms.call("open", null, &"buy")
	await process_frame
	await process_frame
	return ms

func _wallet(h: RefCounted, acct: int) -> int:
	return int(h.call("op", acct, "wallet.get", {}).r.wallet)

func _row_uids(table: Control) -> Array:
	return (table.get("rows") as Array).filter(func (r: Node) -> bool: return not r.is_queued_for_deletion()).map(func (r: Node) -> String: return str(r.get("model").uid))

func _row_keys(table: Control) -> Array:
	return (table.get("rows") as Array).map(func (r: Node) -> String: return str(r.get("view").key))

func _row_of(table: Control, uid: String) -> Control:
	for r: Control in table.get("rows"):
		if str(r.get("model").uid) == uid:
			return r
	return null

func _first(table: Control, key: String) -> Control:
	for r: Control in table.get("rows"):
		if str(r.get("view").key) == key:
			return r
	failures.append("no %s row on the page" % key)
	return null

## A real left click at the control's centre (it must be on screen and on top to receive it).
func _click(c: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = get_root().get_final_transform() * c.get_global_rect().get_center()
	click.global_position = click.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	get_root().push_input(up)

static func _sig(rows: Array) -> String:
	var out: PackedStringArray = []
	for v: Dictionary in rows:
		out.append("%s/%s/%d/%d" % [v.id, v.asset.uid, int(v.unit_price), int(v.asset.level)])
	return ",".join(out)
