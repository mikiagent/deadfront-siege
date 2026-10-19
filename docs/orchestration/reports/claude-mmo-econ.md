# claude-mmo-econ: economy engine (contracts 4, 5.1-5.3, 6)

Branch `claude/mmo-econ`. Pure domain code: no nodes, no networking, time passed in.
Accounts are integer ids only; auth and transport belong to the net package.

## What shipped

`game/scripts/economy/` (about 2,100 lines across 13 files, one class each):

| File | Role |
|---|---|
| `market_engine.gd` `MarketEngine` | The one entry point `apply(op, account_id, args, ts) -> {ok, r} / {ok:false, err, msg}`, the rid cache, accounts, wallet, objectives, vault deposit and withdraw, inbox, `sys.tick` |
| `ledger.gd` `Ledger` | State dict, wallets, vaults by uid, fee sink, faucet, initial grants, uid/id issuance from one counter, inboxes, `norm`/`canon` JSON shape |
| `market_book.gd` `MarketBook` | Fixed listings (partial buys), auctions (bids, anti-snipe, buyout), cancel, settlement and expiry |
| `order_book.gd` `OrderBook` | Buy orders, partial fills, cancel, expiry |
| `market_query.gd` `MarketQuery` | Read-only `search`, `orders`, `item_detail`, `trades`, `mine`, wallet holds |
| `price_history.gd` `PriceHistory` | Trade log, hourly OHLC + volume for 7 days, reference price |
| `settlers.gd` `Settlers` | NPC account 0, demand table from `data/world/market.json`, hourly refresh, daily budget |
| `asset_validator.gd` `AssetValidator` | Deposit trust boundary for items and pets |
| `econ_store.gd` `EconStore` | Journal + snapshot, flush before respond, torn-line repair, replay |
| `econ_invariants.gd` `EconInvariants` | Contract 6.7 items 1-4 over a state dict |
| `econ_rules.gd`, `econ_args.gd`, `econ_catalog.gd` | Rule numbers, argument validation, catalog snapshot from `Data` |

Data: `game/data/economy/market_rules.json` (fees, tax, increments, durations, caps, Settlers)
and `limits.json` (open listing/order caps, vault caps, deposit caps, flag and attribute
whitelists, pet tolerance).

Tests: `game/tests/economy_tests.gd`, wired into `run_all.gd` with one line.

## How to use it (for the net/server agent)

```gdscript
var engine := MarketEngine.new(EconRules.load_default(), EconCatalog.from_data())
var store := EconStore.new(engine, data_dir)   # EconStore.DEFAULT_DIR = "user://server"
var why := store.open()                         # loads snapshot.json, replays journal.jsonl
if why != "": refuse to start                   # corrupt journal or snapshot
# per request, on the main thread, one at a time:
var res := store.apply(op, account_id, args, Time.get_unix_time_from_system() as int)
for ev in engine.drain_events():                # [account_id, {id, ts, ev, d}] to push
	...
# once a second or so:
store.apply("sys.tick", 0, {}, now)
```

- Client ops are exactly `MarketEngine.READ + MarketEngine.WRITE`. Never relay
  `MarketEngine.SYSTEM` (`account.ensure`, `sys.tick`) from a client. Call
  `account.ensure {name}` from `auth.hello` with the new account id (>= 1) before any other op.
- Write ops need `args.rid` (1-64 chars). The envelope carries `rid` outside `a`, so copy it
  into `a.rid` before calling `apply`. A repeated rid returns the cached response and changes
  nothing; the same rid on a different op returns `conflict`. Cache: last 64 per account.
- Always go through `store.apply`, never `engine.apply` directly, or the op is not journaled.
- `server_error` from the store means the journal could not be written. The store then refuses
  everything until restart; restart rolls back to what the disk holds, which matches what
  clients were told.
- Change `market_rules.json`, `limits.json` or `items.json` only after `store.snapshot()` on a
  clean shutdown: the journal is replayed under the current rules and catalog.

### Deposit caps (how the per-def table was derived)

Each def's 24 h cap is the smallest `category_caps` value among its `items.json` categories:
raw gathered bulk 2000, splits/planks/handles/lashing/fuel 1000, ores and metal 600,
cloth/hide/bone/dye 400, ammunition 300, monster parts 200, food 500, buff food 200,
medicine 100, treasure 50, kits and buckets 20, tools and weapons 10, armour 5. The result is
pinned in `deposit_caps` (151 tradeable defs). A def added later falls back to the same rule
at runtime, and a test checks the pinned table still follows it. Pets: 3 per species and 10 in
total per rolling 24 h. `captured_animal` and `tamed_animal` are refused (bond or release first).

### Pet integrity

Stats are recomputed the way `PetRecord.from_def` plus `add_xp` build them:
`base x (0.85 + 0.30 x IV/31) x growth^(level-1)`, growth 1.08 hp, 1.05 attack and
ranged attack, 1.04 both defences, 1.0 accuracy and speed. Wild genetics are rolled with no
level gains or EVs, and later gains and EVs never change a pet's stats, so only IVs enter the
formula. Every stat must match within 0.5 %; the stored value is the recomputed one. IVs 0..31
(all seven required), EVs 0..100 each and <= 300 total, level gains <= 3 per level, xp below the
next level, grade label and hunger_max rebuilt from the catalog, empty bag, not summoned.

## Tests (run on this branch, 2026-10-18)

Import, then unit tests, then smoke, each through `gslot.sh` with a timeout:

```
[econ] fuzz 3000 ops over 6 accounts, invariants after every op: order_cancel 18/67, deposit_item 396/437, spend 23/24, list_fixed 114/289, orders 52/52, get 53/53, order_create 93/143, tick 221/221, buy 44/317, list_auction 158/186, withdraw_item 32/117, sell_to_order 12/258, cancel 55/127, get 36/36, bid 87/219, trades 57/57, search 51/51, mine 52/52, deposit_pet 80/80, claim 27/33, take 55/55, item_detail 53/53, buyout 9/49, withdraw_pet 21/24
[econ] search over 10000 active listings: page 1 in 9.5 ms (best of 3); q+newest in 11.4 ms
[tests] PASS
SMOKE PASS
```

(`n/m` = successful / attempted; the fuzz deliberately sends bad uids, wrong owners, bad
durations and repeated rids.) Covered: every op's happy path and every engine error code
(`bad_request`, `unauthorized`, `not_found`, `insufficient_funds`, `insufficient_items`,
`not_owner`, `self_trade`, `expired`, `closed`, `bid_too_low`, `limit_reached`,
`invalid_asset`, `conflict`, `server_error`); after every test op the 6.7 invariants hold and a
failed or read-only op leaves the state JSON unchanged. Double-submit with one rid, buying the
same listing twice, partial buys and fills, bid after end, anti-snipe cap of 10, buyout over a
standing bid, cancel after a partial sale, no cancel after a bid, expiry returning assets,
self-trade on buy, bid, buyout and sell_to_order, pets with full stats and genetics in search,
every search filter and sort, reference price with outlier and wash damping, Settlers budget,
journal replay from empty byte-identical (scenario and the whole fuzz run), torn final line
discarded and cut, corrupt middle line stops boot, snapshot + tail and snapshot alone reboot
byte-identical, every catalog def passes deposit checks when fresh.

## What went wrong and was fixed in this pass

- Replay was not byte-identical: Godot's JSON reader comes back an ulp off for about 1 in 8
  full-precision doubles. The store now applies the args parsed back from the exact text it
  journals, and stored pet floats sit on a 0.001 grid (a test round-trips 100,000 grid values).
- `limits.json` refused real items: `hardness` goes to 7 in `items.json` (rule said 3) and
  `feathered` ships as `1`, not a bool.
- A script error inside a test function used to abort it silently while the run still printed
  PASS; each economy test now has to report completion.

## Limits and honest caveats

- **Deposits are validated client claims (contract 4, v1).** Gathering, crafting and combat run
  on the client, so a cheating client can deposit up to the daily caps of anything and the same
  pet up to 3 times a day per species. The caps and integrity checks bound the damage; they do
  not prevent it. Server-simulated islands (v2) are the fix.
- `wallet.spend travel` accepts any sail cost that exists, not the cost of the voyage actually
  taken: the server does not know where the client is.
- `flush()` is fflush, not fsync: a process crash loses nothing that was acknowledged; a kernel
  panic or power cut can lose the last few ops.
- `process_count` is capped at 99. Steaming keeps the item and adds a process each time, so
  there is no smaller legitimate bound, and food energy grows 35 % per process.
- Search is a linear scan (8-11 ms at 10,000 listings across runs). Indexes are not needed until roughly
  50,000 active listings.
- Names are not checked for uniqueness here; `auth.hello` owns that (contract 3).
- Rate limits (5.4) belong to the transport.

## Assumptions (marked `# ASSUMPTION:` in code)

- The only T-stone priced `claim` is opening a crater (`rules.json` `open_cost_tstones`).
- Any listed sail cost is a legal `travel` spend.
- A bid at or above the buyout is refused; the buyer uses `market.buyout`.
- Closed Settler orders are not kept, so they read as `not_found`, not `closed`.
- Settlers only buy (contract 6.6): every refresh they cancel their orders and post up to 12 new
  ones with at most 500 escrowed, priced base x mean regional demand x scarce/abundant
  multiplier x 0.8; each server day their holdings are topped up to 2,000, so no more than
  2,000 T-stones a day reach players through them.
