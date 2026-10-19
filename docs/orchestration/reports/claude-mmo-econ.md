# claude-mmo-econ: economy engine (contracts 4, 5.1-5.3, 6)

Branch `claude/mmo-econ`. Pure domain code: no nodes, no networking, time passed in.
Accounts are integer ids only; auth and transport belong to the net package.
Second pass (2026-10-18): every blocker, major and minor from the independent review is
fixed, each with a test; see "Review fixes" below.

## What shipped

`game/scripts/economy/` (about 2,300 lines across 13 files, one class each):

| File | Role |
|---|---|
| `market_engine.gd` `MarketEngine` | The one entry point `apply(op, account_id, args, ts) -> {ok, r} / {ok:false, err, msg}`, the rid cache, the fault guard, accounts, wallet, objectives, vault deposit and withdraw, inbox, `sys.tick` |
| `ledger.gd` `Ledger` | State dict, wallets, vaults by uid, fee sink, faucet, initial grants, uid/id issuance from one counter, inboxes, `norm`/`canon` JSON shape |
| `market_book.gd` `MarketBook` | Fixed listings (partial buys), auctions (bids, anti-snipe, buyout), cancel, settlement and expiry |
| `order_book.gd` `OrderBook` | Buy orders, partial fills, cancel, expiry |
| `market_query.gd` `MarketQuery` | Read-only `search`, `orders`, `item_detail`, `trades`, `mine`, wallet holds |
| `price_history.gd` `PriceHistory` | Trade log, hourly OHLC + volume for 7 days, reference price |
| `settlers.gd` `Settlers` | NPC account 0, demand table from `data/world/market.json`, hourly refresh, daily budget |
| `asset_validator.gd` `AssetValidator` | Deposit trust boundary for items and pets |
| `econ_store.gd` `EconStore` | Journal + two-generation snapshots, flush before respond, torn-tail repair, replay, reload after a fault |
| `econ_invariants.gd` `EconInvariants` | Contract 6.7 items 1-4 over a state dict |
| `econ_rules.gd`, `econ_args.gd`, `econ_catalog.gd` | Rule numbers, argument validation, catalog snapshot from `Data` |

Data: `game/data/economy/market_rules.json` (fees, tax, increments, durations, caps, rid cache,
Settlers) and `limits.json` (open listing/order caps, vault caps, deposit caps, flag and
attribute whitelists, pet tolerance).

Tests: `game/tests/economy_tests.gd`, wired into `run_all.gd` with one hook, which now also
fails the run when the file does not compile (before, a parse error there still exited 0).

## How to use it (for the net/server agent)

```gdscript
var engine := MarketEngine.new(EconRules.load_default(), EconCatalog.from_data())
var store := EconStore.new(engine, data_dir)   # EconStore.DEFAULT_DIR = "user://server"
var why := store.open()                         # newest readable snapshot, then both journals
if why != "": refuse to start                   # corrupt journal, seq gap, no readable snapshot
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
  into `a.rid` before calling `apply`. The same rid on a different op returns `conflict`.
  A repeated rid changes nothing and returns the original response while it is in memory
  (the last 16,384 server-wide writes, including everything replayed since the last
  snapshot). An older repeat, or one from before a restart, returns
  `{ok:true, r:{duplicate:true, op, seq}}`: the client should re-read its state. The cache
  is the last 64 rids per account, forgotten after a day with no writes.
- Always go through `store.apply`, never `engine.apply` directly, or the op is not journaled
  and a fault is not repaired.
- `server_error` means one of two things. Either the disk could not be written (`store.broken`
  is set; the store refuses everything until restart, and a restart boots from what the disk
  holds, which matches what clients were told), or the op hit an internal error part-way
  (`engine.fault`); the store then reloads memory from disk, which never saw the op, and keeps
  serving.
- Change `market_rules.json`, `limits.json` or `items.json` only after `store.snapshot()` on a
  clean shutdown: the journal is replayed under the current rules and catalog.

Response shapes changed in this pass (no consumer used them yet; checked `mmo-net`):
- Listing views no longer carry `bidder`. They carry `has_bid` and `my_bid` (true when the
  caller is the high bidder). `market.trades` (the public tape) drops `buyer` and `seller`;
  `market.mine` trades keep them.
- `market.mine {page?, page_size?}` returns open `listings`, `bids`, `orders` and `trades` in
  full, plus `closed_listings` and `closed_orders` (last 7 days, newest first, paged) and
  `closed_total`.
- `inbox.take` returns `dropped`: how many older events were pushed out past `inbox_max`.

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
ranged attack, 1.04 both defences, 1.0 accuracy and speed. Only IVs enter the formula (later
level gains and EVs never change stats). Every stat must match within 0.5 %; the stored value
is the recomputed one. IVs 0..31 (all seven required), EVs 0..100 each and <= 300 total, level
gains <= 3 per level, xp below the next level, empty bag, not summoned. Every field must have
its `PetRecord.to_dict()` type; unknown fields are refused; `variant` must be "" or one the
creature def lists (spawners never set any other); grade, hunger_max and roles are rebuilt.

## Tests (run on this branch, 2026-10-18, after the fixes)

Unit tests, then smoke, each through `gslot.sh` with a timeout (no new `class_name` files, so
no import was needed):

```
[econ] fuzz 3000 ops over 6 accounts, invariants after every op: order_cancel 18/56, deposit_item 405/467, get 46/46, buy 44/294, take 72/72, list_auction 149/175, tick 191/191, sell_to_order 7/232, spend 32/32, orders 40/40, bid 73/221, list_fixed 117/303, item_detail 45/45, get 51/51, order_create 114/160, cancel 45/117, search 54/54, deposit_pet 85/100, buyout 10/67, withdraw_item 24/99, mine 59/59, withdraw_pet 32/41, trades 46/46, claim 27/32
[econ] search over 10000 active listings: page 1 in 15.8 ms first call, 9.9 ms best of 3; q+newest in 13.0 ms
[econ] state with 10000 listings: 4283 KB, stringified in 67 ms; largest rid cache 2218 bytes
[tests] PASS
SMOKE PASS
```

(`n/m` = successful / attempted.) The fuzz now also sends wrong-typed values in random item and
pet fields, and fails on any `server_error`. The log shows one deliberate `SCRIPT ERROR` and
one `ERROR` from the fault test, labelled as such, and a warning from the bad-snapshot test.
Covered from before: every op's happy path and every engine error code, invariants and "a
failed or read-only op changes nothing" after every test op, double-submit, buying a listing
twice, partial buys and fills, bid after end, anti-snipe cap, buyout over a standing bid,
cancel after a partial sale, no cancel after a bid, expiry, self-trade on buy, bid, buyout and
sell_to_order, pets with full stats in search, every filter and sort, Settlers budget, replay
from empty byte-identical (scenario and the whole fuzz run), torn final line, corrupt middle
line, snapshot + tail.

## Review fixes (one test each)

| Finding | Fix | Test |
|---|---|---|
| Blocker: a crash that cut only the last newline fused the next op onto it; the second reboot refused | Replay reads bytes; a final line with no newline is either cut (bad JSON) or kept with its newline restored, before any append | `_test_torn_newline`: drop the newline, reboot, two acknowledged ops, reboot again |
| Blocker: snapshot writes unchecked, journal truncated in place, a bad snapshot lost everything | `store_string`, flush and `get_error` checked, tmp read back and compared before anything moves. The journal rotates to `journal.prev.jsonl` and the old snapshot to `snapshot.prev.json`; boot falls back to them; a failed rotation stops the store | `_test_snapshot_failures`: unwritable tmp keeps serving and loses nothing; half-written `snapshot.json` boots from the previous generation; two unreadable snapshots and an old state version stop boot |
| Blocker: `summoned = "yes"` raised a script error and `apply` returned `{}` | `summoned` must be bool or 0/1. `apply` counts engine and script errors with a `Logger` (Godot 4.5+) and treats an error, or a result without `ok`, as `server_error` + `engine.fault`; the store reloads memory from disk | Hostile string/object/array/null in every item and pet field; `_test_fault_reload` (an op that writes, then hits a real script error or a bad debit, leaves memory and journal clean); fuzz with hostile fields |
| Major: `frill` refused the rare raptor bone and tools crafted from it | Added `frill` 0..1 | `_test_attribute_sources` walks butchering drops, catalog defaults, recipe buffs, island climates, tool tiers and the combat counters through the whitelist, and deposits the bone and a knife made from it |
| Major: reference price could be poisoned forever | Band judged afresh each recompute; when more eligible trades sit outside it than inside, re-anchor on all of them; no trades in the window means no reference; Settler trades excluded | `_test_reference_poisoning`: 2 trades at 100, then 3 honest pairs at 10 bring it to 10 |
| Major: torn-line repair rewrote the journal in place | Repair truncates to the last good byte (`FileAccess.resize`) or appends one newline; a failed repair stops boot | Torn-line tests above |
| Major: rid cache stored full responses (about 56 KB per account) | Persisted cache is `rid -> [op, seq]`; full bodies live in memory for the last 16,384 writes; idle caches pruned daily | Eviction re-applies, recent rid hits, repeat after restart says `duplicate`, idle prune; perf probe asserts a full cache < 2.5 KB (measured 2,218 bytes) |
| Minor: report understated abuse and durability | Rewritten below | |
| Minor: wash pairs judged against stale timestamps; NPC trades in the reference | Pair timestamps filtered by the 24 h window at read time; npc trades not eligible; `volume()` granularity documented (one hourly bucket) | Poisoning test (a pair trade 24 h later counts) and Settlers test |
| Minor: a bid at exactly 60 s left spent an extension without moving the end | Extend only when `now + snipe_extend_s > ends` | `_test_market_views` |
| Minor: state field names drifted from contract 4 | `claimed` is now `claimed_objectives`; `rid_order` is gone. `rid_cache` keeps the contract name but holds `[op, seq]`, not the response (orchestrator: please note this in contracts.md). State version is now 2 | Version test |
| Minor: `assert` guards vanish in release | `debit`/`credit` refuse and `push_error`, which faults the op | `_test_fault_reload` debit case |
| Minor: `market.mine` unpaged, bidder ids public, silent inbox overflow | Paged closed history, `has_bid`/`my_bid`, anonymous public tape, `dropped` count | `_test_market_views` |
| Minor: eviction and first-call timing untested | Asserted | `_test_idempotency`, `_test_search_perf` |

Not disputed: every finding reproduced by reading the code. One gap in the tests: no test makes
a write fail after the file opened (a real full disk), so the read-back check before the
rename runs only on the happy path. The unwritable-tmp test covers the open failure and the
half-written-snapshot test covers what a bad write would leave behind.

## Limits and honest caveats

- **Durability.** Godot exposes no fsync; `flush()` hands bytes to the OS.
  - A process crash (kill, OOM, segfault) loses nothing that was acknowledged: every op is
    flushed before its response, a torn tail is repaired at boot, and every step of a snapshot
    rotation leaves a bootable chain.
  - A power cut or kernel panic can lose acknowledged ops the OS had not yet written back
    (typically the last 30 s or so), without any sign. If a fresh `snapshot.json` never reached
    the disk, boot falls back to `snapshot.prev.json` + both journals. If that generation was
    also lost (two snapshots inside one writeback window, which takes 500 ops in under about
    30 s), boot refuses on the seq gap rather than starting empty. For real-money durability,
    put the data dir on a filesystem with ordered data journaling, or add an fsync through a
    GDExtension.
- **Deposits are validated client claims (contract 4, v1).** Gathering, crafting, taming and
  combat run on the client. Per account per day, a cheating client can deposit up to the caps
  of any item. It can also mint pets: up to 3 per species and 10 in total, each a level-60
  pet with IV 31 in every stat and the S-grade hunger/xp rate. The integrity checks only
  ensure the numbers are self-consistent. Accounts are free (contract 3), so sybil accounts
  multiply all of this, and the market lets them move it to one account.
- **Coin faucet.** `objective.claim` pays all 28 objectives (72 T-stones) on request, with no
  proof the objective was done. With the 20 starting T-stones, that is 92 T-stones per
  account, unbounded across sybil accounts and movable through the market (fees and tax
  take 8 %). Settlers add at most 2,000 a day server-wide. Server-simulated islands (v2) and
  some account cost (auth's call) are the real fixes.
- `wallet.spend travel` accepts any sail cost that exists, not the voyage actually taken.
- `process_count` is capped at 99 (steaming adds one each time; no smaller legitimate bound).
- `volume_24h` / `volume_7d` sum whole hourly buckets, so they can include up to an hour of
  older trades.
- A script error during an op triggers a reload from disk (about a snapshot parse plus up to
  500 replayed ops). Errors logged by another thread during an op cause a needless reload.
  A client that finds a reproducible internal error can make the server do this repeatedly;
  it cannot corrupt the books.
- Search is a linear scan (10-16 ms at 10,000 listings). Indexes are not needed until roughly
  50,000 active listings. A 10,000-listing state is 4.3 MB and stringifies in about 70 ms per
  snapshot.
- Names are not checked for uniqueness here (`auth.hello` owns that); rate limits (5.4)
  belong to the transport.

## Assumptions (marked `# ASSUMPTION:` in code)

- The only T-stone priced `claim` is opening a crater (`rules.json` `open_cost_tstones`).
- Any listed sail cost is a legal `travel` spend.
- A bid at or above the buyout is refused; the buyer uses `market.buyout`.
- Closed Settler orders are not kept, so they read as `not_found`, not `closed`.
- Settler trades count toward volume and OHLC but not the reference price.
- Retries and replayed frames arrive within a day; a rid idle longer applies again.
- Settlers only buy (contract 6.6): every refresh they cancel their orders and post up to 12 new
  ones with at most 500 escrowed, priced base x mean regional demand x scarce/abundant
  multiplier x 0.8; each server day their holdings are topped up to 2,000, so no more than
  2,000 T-stones a day reach players through them.
