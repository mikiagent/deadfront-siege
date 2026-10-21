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
	"B2 sell: picker rows == server bag instances, refusals shown with reason, preview == ledger deltas",
	"B2 sell errors: fee not payable from bound coins, price 0 / > max_unit_price refused",
	"B3 my market: active/sold/expired/history from market.mine, cancel returns to vault, fee kept",
	"B3 receive all: inbox.take + vault.withdraw per uid, bag_full keeps the rest, twice moves nothing",
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

## Gate 11: the HUD's MENU sheet has an Island Market row that opens the screen (hook H0).
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
