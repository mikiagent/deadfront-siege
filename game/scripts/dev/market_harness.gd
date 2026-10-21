class_name MarketHarness
extends RefCounted
## A deterministic local economy for the market lab and t_exchange: the real VaultBridge over
## EconStore (on disk, in the run's own user dir) and an in-memory CharacterStore on a small
## server world. Every item, coin and listing gets into it through ops a real client or the
## server's own tick sends: gather / loot / craft / tame / capture, selling to Settlers' buy
## orders for tradable coins, vault.deposit and market.list_fixed. Nothing is written into the
## books directly, and ECON's default rules are used unchanged (the trade lock is waited out on
## the harness clock). Dev/test only: its clients are LocalMarketClient, labelled as a test server.

const T0 := 1760000000
const HOUR := 3600
const VIEWER := 1 ## the player looking at the screens
const SELLER_A := 2
const SELLER_B := 3
const NAMES := {VIEWER: "You", SELLER_A: "Trader2", SELLER_B: "Trader3"}
## Server-world sources of what Settlers buy: def -> [node, option].
const GATHER := {"stone": ["rock", 0], "berry": ["bush", 0], "fibre_stalk": ["bush", 1], "branch": ["bush", 2], "dry_grass": ["grass", 0], "herb_leaf": ["grass", 1]}

var bridge: VaultBridge
var world: WorldFacade
var now := T0
var failures: PackedStringArray = []
var _rid := 0

func _init(dir: String) -> void:
	_wipe(dir)
	var econ := EconStore.new(MarketEngine.new(EconRules.load_default(), EconCatalog.from_data()), dir)
	var err := econ.open()
	if err != "":
		failures.append("economy store did not open: %s" % err)
	world = _make_world()
	bridge = VaultBridge.new(econ, CharacterStore.new(world, "", 7))
	for acct: int in NAMES:
		_check(bridge.hello(acct, NAMES[acct], now), "hello %d" % acct)

## MarketEngine and CharacterStore each register a static error-counting Logger and never remove
## it; a windowed run that quits with them registered aborts in NSApplication terminate (a Godot
## .ips per lab shot). The lab calls this on exit. Headless tests never take that path.
# shortcut: unregisters ECON/SRVDOM's statics from outside; ECON should own a release() (report note).
static func release_loggers() -> void:
	for owner: Script in [MarketEngine, CharacterStore]:
		var lg: Variant = owner.get("_errors")
		if lg is Logger:
			OS.remove_logger(lg)
			owner.set("_errors", null)

## The screens' transport for one account, on the harness clock.
func client(acct: int = VIEWER) -> LocalMarketClient:
	return LocalMarketClient.new(bridge, acct, func () -> int: return now)

## The lab/test scene: other players' listings (single branches, bones, a crafted knife, a bonded
## pet, captured cages), and the viewer with tradable + bound coins, one active, one sold and one
## expired listing, a purchase waiting in the vault for Receive All, and a bag to sell from:
## two bones, a crafted knife, a captured cage, a bonded pet and a locked stone stack.
func seed_scene() -> void:
	now += int(bridge.econ.engine.L.rules.num("trade_lock_s")) + 1 # new accounts wait out the lock
	for acct: int in [SELLER_A, SELLER_B, VIEWER]:
		earn(acct, 140)
	# Seller A: three single branches, two bones, a knife with durability.
	_gather(SELLER_A, "branch", 5)
	for i in 3:
		list_one(SELLER_A, "branch", 1, 25)
	_loot(SELLER_A, "bone", 3)
	for i in 2:
		list_one(SELLER_A, "bone", 1, 50)
	if _craft_knife(SELLER_A):
		list_one(SELLER_A, "stone_knife_work", 1, 40)
	# Seller B: a bonded pet and three captured cages.
	var pid := tame(SELLER_B, "compy_tame")
	if pid != "":
		var dep := op(SELLER_B, "vault.deposit", {"pet_uid": pid})
		if dep.ok:
			op(SELLER_B, "market.list_fixed", {"asset": {"uid": pid}, "unit_price": 500, "duration_h": 72})
	for i in 3:
		var slot := capture(SELLER_B, "compy_cage%d" % i)
		if slot >= 0:
			_list_slot(SELLER_B, slot, 1, 600, 72)
	# The viewer: sold (Trader2 buys it), active, expired (12 h, then 13 h pass), a bought bone.
	_gather(VIEWER, "fibre_stalk", 3)
	var sold := list_one(VIEWER, "fibre_stalk", 1, 6)
	if sold != "":
		op(SELLER_A, "market.buy", {"listing_id": sold, "count": 1})
	_gather(VIEWER, "stone", 4)
	list_one(VIEWER, "stone", 1, 9)
	_gather(VIEWER, "berry", 2)
	list_one(VIEWER, "berry", 1, 8, 12)
	var bone := _search_first(VIEWER, "bone")
	if bone != "":
		op(VIEWER, "market.buy", {"listing_id": bone, "count": 1})
	# The viewer's Sell picker: every kind of cell (stack, durability, cage, bonded pet, locked).
	_loot(VIEWER, "bone", 2)
	_craft_knife(VIEWER)
	capture(VIEWER, "compy_mine_cage")
	tame(VIEWER, "compy_mine")
	lock_first(VIEWER, "stone")
	now += 13 * HOUR
	tick()

## Stands in for the Bag's Lock (InventoryUI sets the "locked" flag on a stack): the server has no
## lock intent yet, so the same flag goes on the server character's stack.
# shortcut: edits the character dict directly; use the server's lock intent once W3-SRVACT adds one.
func lock_first(acct: int, def: String) -> void:
	var slot := _slot(acct, def)
	if slot < 0:
		failures.append("account %d has no %s to lock" % [acct, def])
		return
	var row: Dictionary = _bag(acct)[slot]
	row.flags = (row.get("flags", []) as Array) + ["locked"]

## Tradable coins the honest way: sell gathered goods into Settlers' buy orders, window by window.
func earn(acct: int, target: int) -> void:
	for w in 48:
		if tradable(acct) >= target:
			return
		now = (now / HOUR + 1) * HOUR
		tick()
		var orders: Array = op(acct, "market.orders", {"limit": 100}).get("r", {}).get("orders", [])
		for o: Dictionary in orders:
			if not o.npc or not GATHER.has(str(o.def_id)) or tradable(acct) >= target:
				continue
			var n := mini(int(o.qty) - int(o.filled), 20)
			_gather(acct, str(o.def_id), n)
			var slot := _slot(acct, str(o.def_id))
			if slot < 0:
				continue
			n = mini(n, int(_bag(acct)[slot].count))
			var dep := op(acct, "vault.deposit", {"bag_slot": slot, "count": n})
			if dep.ok:
				op(acct, "market.sell_to_order", {"order_id": str(o.id), "uid": str(dep.r.uid), "count": n})
	failures.append("account %d earned only %d of %d tradable T-stones" % [acct, tradable(acct), target])

func tick() -> void:
	bridge.apply("sys.tick", 0, {}, now)

func tradable(acct: int) -> int:
	var w: Dictionary = op(acct, "wallet.get", {}).get("r", {})
	return int(w.get("wallet", 0)) - int(w.get("bound", 0))

## One client op, synchronously, with a deterministic rid on writes.
func op(acct: int, name: String, a: Dictionary) -> Dictionary:
	if name in MarketClient.WRITE_OPS and not a.has("rid"):
		_rid += 1
		a = a.duplicate()
		a.rid = "h%d" % _rid
	return _check(bridge.client(name, acct, a, now), "%s by %d" % [name, acct])

## Deposits `count` of the first `def` stack and lists it; returns the listing id or "".
func list_one(acct: int, def: String, count: int, price: int, hours: int = 72) -> String:
	var slot := _slot(acct, def)
	if slot < 0:
		failures.append("account %d has no %s to list" % [acct, def])
		return ""
	return _list_slot(acct, slot, count, price, hours)

func _list_slot(acct: int, slot: int, count: int, price: int, hours: int) -> String:
	var dep := op(acct, "vault.deposit", {"bag_slot": slot, "count": count})
	if not dep.ok:
		return ""
	var lst := op(acct, "market.list_fixed", {"asset": {"uid": str(dep.r.uid)}, "unit_price": price, "duration_h": hours})
	return str(lst.r.listing.id) if lst.ok else ""

func tame(acct: int, net_id: String) -> String:
	_gather(acct, "berry", 3)
	world.add_creature(net_id, "compsognathus", Vector3(1, 0, 1), 90.0, {"hp": 20.0, "knocked": true})
	var r := {}
	for i in 3:
		r = bridge.client("act.tame", acct, {"net_id": net_id, "food": "berry"}, now + i)
	if not r.get("ok", false) or not r.r.has("pet_uid"):
		failures.append("tame %s: %s" % [net_id, r])
		return ""
	return str(r.r.pet_uid)

## A captured_animal cage in the bag through the real capture steps; returns its slot or -1.
func capture(acct: int, net_id: String) -> int:
	var before := _count(acct, "captured_animal")
	_gather(acct, "fibre_stalk", 4)
	_gather(acct, "branch", 1)
	for i in 2:
		bridge.client("act.craft", acct, {"recipe_id": "twine", "picks": [_slot(acct, "fibre_stalk")]}, now)
	bridge.client("act.craft", acct, {"recipe_id": "capture_net_i"}, now)
	world.add_creature(net_id, "compsognathus", Vector3(1, 0, 1), 90.0, {"hp": 10.0})
	for i in 40:
		world.creatures[net_id].knocked = true
		var got := bridge.client("act.capture", acct, {"net_id": net_id}, now + i)
		if got.get("ok", false) and got.r.get("captured", false):
			break
		if _count(acct, "capture_net_i") == 0:
			bridge.client("act.craft", acct, {"recipe_id": "capture_net_i"}, now)
	if _count(acct, "captured_animal") <= before:
		failures.append("capture %s put no cage in the bag" % net_id)
		return -1
	return _slot(acct, "captured_animal")

func _craft_knife(acct: int) -> bool:
	_gather(acct, "fibre_stalk", 2)
	bridge.client("act.craft", acct, {"recipe_id": "twine", "picks": [_slot(acct, "fibre_stalk")]}, now)
	var r := bridge.client("act.craft", acct, {"recipe_id": "improvised_stone_knife"}, now)
	if not r.get("ok", false):
		failures.append("craft improvised_stone_knife: %s" % r)
	return r.get("ok", false)

func _search_first(acct: int, q: String) -> String:
	var res: Array = op(acct, "market.search", {"q": q}).get("r", {}).get("results", [])
	return str(res[0].id) if not res.is_empty() else ""

func _gather(acct: int, def: String, n: int) -> void:
	var src: Array = GATHER[def]
	for _i in 200:
		if _count(acct, def) >= n:
			return
		bridge.client("act.gather", acct, {"node_id": src[0], "option": src[1]}, now)

func _loot(acct: int, def: String, n: int) -> void:
	var slots: Array = world.corpses["carcass"].slots
	for i in slots.size():
		if slots[i] is Dictionary and str(slots[i].id) == def:
			_check(bridge.client("act.loot", acct, {"corpse_id": "carcass", "slot": i, "count": n}, now), "loot %s" % def)
			return

func _bag(acct: int) -> Array:
	return bridge.chars.character(acct).d.bag

func _slot(acct: int, def: String) -> int:
	var bag := _bag(acct)
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].id) == def:
			return i
	return -1

func _count(acct: int, def: String) -> int:
	var n := 0
	for row: Variant in _bag(acct):
		if row is Dictionary and str(row.id) == def:
			n += int(row.count)
	return n

func _check(res: Dictionary, what: String) -> Dictionary:
	if not res.get("ok", false):
		failures.append("%s: %s %s" % [what, res.get("err", "?"), res.get("msg", "")])
	return res

## Rock, bush and grass that never run out, and a carcass with bones (the srvdom test world's shape).
static func _make_world() -> WorldFacade:
	var w := WorldFacade.new()
	w.add_node("rock", Vector3(1.5, 0, 0), [{"item": "stone", "tool": "none", "min": 2, "max": 4, "left": 1000000}], 1, "Rock")
	w.add_node("bush", Vector3(-1.5, 0, 0), [
		{"item": "berry", "tool": "none", "min": 1, "max": 2, "left": 1000000},
		{"item": "fibre_stalk", "tool": "none", "min": 1, "max": 3, "left": 1000000},
		{"item": "branch", "tool": "none", "min": 1, "max": 2, "left": 1000000},
	], 1, "bush")
	w.add_node("grass", Vector3(0, 0, 1.5), [
		{"item": "dry_grass", "tool": "none", "min": 1, "max": 2, "left": 1000000},
		{"item": "herb_leaf", "tool": "none", "min": 1, "max": 1, "left": 1000000},
	], 1, "grass")
	w.corpses["carcass"] = {"pos": [1, 0, -1], "slots": [ItemStack.make(&"bone", 6).to_dict(), ItemStack.make(&"raw_meat", 3).to_dict()]}
	return w

static func _wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			da.remove(f)
