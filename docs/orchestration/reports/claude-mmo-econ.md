# claude-mmo-econ: economy engine (contracts 4, 5.1-5.3, 6)

Branch `claude/mmo-econ`. Pure domain code: no nodes, no networking, time passed in.
Accounts are integer ids only; auth and transport belong to the net package.
Second pass (2026-10-18): every blocker, major and minor from the independent review is
fixed, each with a test; see "Review fixes" below. Third pass (same day): the second review's
blocker and six minors are fixed or answered, each with a test that fails on the code before
it; see "Second review fixes". Fourth pass (2026-10-20): contracts v2, bridged to the
server characters. Fifth pass (2026-10-20, evening): every review r3 item is fixed; read
"Review r3 fixes" first, then the fourth pass; both supersede the deposit parts below.
Sixth pass (2026-10-20, night): the one minor from the review of 5498f04b; see "Processed goods".

## Processed goods (sixth pass, 2026-10-20)

Finding (minor, review of 5498f04b; also the vision check's ECON row, PRD:131 "processed goods
sell on the island market"): W2-PROCESS (unmerged, claude/mmo-w2-process 0ec9253f) records its
in-place steps in `attributes.processed`, an Array such as `["dry"]`. The deposit whitelist
had no such key and no array type, so dried meat would have been refused.

**Fix.** `AssetValidator._attribute` gains one rule type, `steps`: an Array of known step ids,
at most `max` long. `limits.json` gains one `processed` row: values `dry`, `smoke`, `steam`
(W2-PROCESS `processing.json` `in_place.steps`) and `max: 2` (its `opportunities`). Nothing
else is whitelisted.

**Where I differ from the finding.** It asked for unique strings. W2-PROCESS does not forbid a
repeated step: `processing_left` only counts the history, and its processing.json says the
steam-steam question "stays open". A uniqueness rule would refuse a stack it can make, such
as `["steam", "steam"]`. The length cap bounds the field instead.

| Test (passes now) | FAIL with the old validator and limits.json (new tests kept, `git stash` of the two files) |
|---|---|
| `t_econ` `_test_processed`: berries with `processed: ["dry"]` deposit, list, sell and withdraw into the buyer's bag with the history and origin intact: `[econ-bridge] processed deposit=i7.0 count=4 history=["dry"] origin=gather` | `[t_econ] FAIL a dried stack deposits: { "ok": false, "err": "invalid_asset", "msg": "attribute processed not allowed" }` |
| `run_all` `_test_item_deposits`: `["steam", "steam"]` survives a deposit; `["fry"]`, three steps, `"dry"` (not a list) and `[["dry"]]` are refused | `ERROR: [tests] econ: vault.deposit_item should succeed: { "ok": false, "err": "invalid_asset", "msg": "attribute processed not allowed" }`, `[tests] FAIL count=2` |

**Sync step, now a check.** `_test_attribute_sources` reads `res://data/processing.json` when
it exists and runs a full-length history of every in-place step through the whitelist. The
file is not on the base yet, so today this adds nothing. At W2-PROCESS's merge it fails if
that package's steps or opportunities differ from the `processed` row; update the row then.

Assumption: `max: 2` inherits W2-PROCESS's `# ASSUMPTION` of 2 opportunities (spec 08's
estimate). Both live in data.

No pixels: this is server-side validation with no UI, so no lab or screenshot applies.

### Acceptance (sixth pass; package tree at 1dccc874 with the hooks patch applied, through gslot)

Code at 1dccc874 (base 6e26ef2a merged; that merge only touched docs, so no `--import` was
needed). The working tree carried exactly the hooks patch (`git diff` equals
`claude-mmo-econ-hooks.patch` byte for byte).

- Hooks patch: `git apply --cached --check` on a `claude/mmo-overhaul` 6e26ef2a index is
  clean. The base did not touch its two files, so the patch is unchanged.
- `t_econ.gd`: `[t_econ] PASS`, with `[econ-bridge] processed deposit=i7.0 count=4 history=["dry"] origin=gather`.
- `run_all.gd`: `[tests] PASS`. Its three SCRIPT ERROR lines are the deliberate fault tests,
  announced by `[econ] fault test: the next SCRIPT ERROR and ERROR lines are deliberate`.
- All 20 `game/tests/t_*.gd` exit 0 with their PASS line (`t_ai`, `t_build`, `t_canim`,
  `t_combat`, `t_econ`, `t_harbour`, `t_iconart`, `t_items`, `t_light`, `t_lighting`,
  `t_occlude`, `t_player`, `t_save`, `t_server_domain`, `t_srvdom`, `t_structart`, `t_tame`,
  `t_ui`, `t_uiicons`, `t_web`). `t_save` prints its 5 deliberate SCRIPT ERRORs; every other
  test prints 0. No test prints "couldn't resolve track".
- `tools/smoke.sh --no-import`: `SMOKE PASS`.
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (25 before, 25 after).
- Labs: none. ECON has no lab or UI.

## Review r3 fixes (fifth pass, 2026-10-20)

Findings: `docs/orchestration/mmo/handoff/findings/econ-review-r3.json` (1 blocker, 3 majors,
5 minors). I fixed every item or answered it below. Each fix has a test that fails on the
reviewed commit. The FAIL lines come from copying the new `game/tests/econ_bridge_checks.gd` and
`game/tests/economy_tests.gd` into a scratch tree at `d50324df` (the commit r3 reviewed) and
running `t_econ.gd` and `run_all.gd` there. On that code the bridge tests reach the relay the
way the old hook described it: `VaultBridge.apply` for economy ops, `chars.apply` for
`IntentHandlers.CLIENT_OPS`. Old run: `[t_econ] FAIL count=29`, `[tests] FAIL count=13`.

**Ownership.** The WIP commit had edited W1-SRVDOM's `game/scripts/server/intent_handlers.gd`
on the branch. An earlier pass had edited the integrator's `game/tests/run_all.gd`. Both edits
now ship only in the hooks patch `docs/orchestration/reports/claude-mmo-econ-hooks.patch`;
the branch's copies of both files match the base byte for byte. `git apply --check` is clean
on `claude/mmo-overhaul` 6e26ef2a (sixth pass). I ran the gates with the patch applied (below).

| # | Item | Fix | Test (passes now) | FAIL on d50324df |
|---|---|---|---|---|
| B | A client could send `act.deposit` | Hooks: `act.deposit` moves from `IntentHandlers.CLIENT_OPS` to `SYSTEM_OPS`. `VaultBridge.client(op, account, args, ts)` is the transport's one relay: economy `CLIENT_OPS` go to `apply()`, `IntentHandlers.CLIENT_OPS` go to `chars.apply()`, and anything else is answered `unauthorized` and logged (`push_warning "[econ] refused server-only op ..."`). `bridge.begin` now records `{account, rid, uid, op}`, and the bridge computes the uid `act.deposit` will export before it runs. `recover()` puts only that uid into that account's vault. Any other export in no vault is reported, inflight or not, and never moved. | `t_econ` `_test_client_gate`, `_test_strays` | `FAIL act.deposit is a server-only op of the character store`; `FAIL a client's act.deposit, char.*, bridge.*, vault dicts and objective.claim are refused: ok,...,ok,...`; `FAIL a refused client act.deposit is logged (0 warning lines)`; `FAIL vault.deposit left the stores inconsistent: stone: characters exported 13, the vaults took in 0 net, export i7.0 is in no vault`; `FAIL recover() reports an export in no vault even with no move marked: ''`; `FAIL a stray export never lands in the vault of a marked deposit (account 2 holds ["i16.0"])` |
| M1 | Split assets could never be withdrawn | `vault.withdraw {rid, uid, count?}`. The whole of an exported asset still goes through `char.receive` (exact body, own uid). Anything else goes through `char.grant`: a split part, a remainder, an order fill, or part of any stack. The grant path checks bag room, runs `bridge.begin {op: grant}`, then `vault.withdraw_item` (KEEP_BODY keeps the units under the rid), then `char.grant` with rid `g<econ seq>`, then `bridge.end`. `recover()` finishes a cut grant from the rid cache exactly once. Hooks: `char.grant` refuses more units than are out (`s.exported`), so it cannot mint, and it keeps the stack's origin. | `t_econ` `_test_sales` (partial buy, seller's remainder, part listing, order fill, `count: 1`, every stone in exactly one place), `_test_crash_recovery` 5 and 6 | `FAIL a partial buy reaches the buyer's character (not_withdrawable)`; `FAIL the seller's remainder comes back to the bag (not_withdrawable): 0 of 8`; `FAIL a part listing's remainder comes back to the bag (not_withdrawable)`; `FAIL units bought through a buy order reach the buyer's character (not_withdrawable)`; `FAIL a grant cut after the vault let go reaches the character at boot: 0 -> 0` |
| M2 | Contract 0.6/0.7: `objective.claim` minted on request, tradable start, no trade lock | `objective.claim` moved from `MarketEngine.WRITE` to `SYSTEM`, so it is no longer in `VaultBridge.CLIENT_OPS`. The server calls it on observed state, and the reward is bound. Accounts carry `bound`: the starting wallet (`starting_wallet_bound`, 20 = all of it) plus objective rewards. `wallet.spend` pays from bound coins first. Listing fees, buys, bids, buyouts and order escrow need `wallet - bound` (`Ledger.tradable`). `trade_lock_s: 1800` from account creation refuses list, auction, buy, bid, buyout, order_create and sell_to_order with `limit_reached`. `wallet.get` reports `bound`. Invariant: `0 <= bound <= wallet`. | `run_all` `_test_bound_wallet_and_trade_lock`; `t_econ` `_test_client_gate` (objective.claim refused) | `econ: objective.claim is not a client op: rewards fire on server-observed state`; `econ: the starting wallet is bound: { "wallet": 20, "held": 0 }`; `econ: market.list_fixed (list inside the trade lock) should fail with limit_reached, got { "ok": true ...`; `econ: market.buy (a buy that needs bound coins) should fail with insufficient_funds, got { "ok": true ...` |
| M3 | Bridge recovery only at boot | `recover()` is state-based and can run at any time. `apply()` and `client()` call it right after any move that could not finish (`broken` set). While it cannot finish, every op is refused with `server_error`, so a copy held in two places can never be listed. `bridge.begin` answers `conflict` while a move is marked. A double refusal (vault and `char.receive`) keeps the mark, so the next op lands the asset. A failed `vault.withdraw_*` after `char.receive` is retried at once. Orphans are scanned on every `recover()`. | `t_econ` `_test_recover_any_time` (a test-only `FlakyEngine` faults `vault.withdraw_item` / `vault.deposit_item` for one uid; EconStore reloads from disk, as in production), `_test_crash_recovery` 2 | `FAIL a vault fault after char.receive is finished in the same request (server_error): stone: characters exported 0, the vaults took in 5 net, i11.0 is held as exported but the character store has no export`; `FAIL while the character and the vault both hold i13.0 nothing can list it (ok)`; `FAIL an asset both stores refused is in the vault before the next deposit runs: stranded ["i16.0"]`; `FAIL bridge.begin refuses while another move is marked (ok)` |
| m1 | A bought pet kept the seller's `owner` | Hooks: `char.receive` sets `owner = str(account)` after the canonical match. `tamer` keeps the lineage. A re-deposit exports the new owner. | `t_econ` `_test_pets_and_cages` | `FAIL a bought pet answers to its buyer (owner 1, was 1)`; `FAIL a re-deposit exports the pet under its new owner` |
| m2 | 6.1 shape and the bonded cap | Hooks: `char.receive` of a pet refuses `limit_reached` at `Data.bonded_cap()` (pack 09: the cap is checked when a bond forms; cages never count). The orchestrator should either amend contract 6.1 to "pets trade as kind `pet` in the books and are shown as cages", or plan the switch to `caged_animal` items with W2-CAGE. Behaviour already matches the contract: the pet keeps its uid, lineage and genetics, and nobody re-tames it. | None yet: `Data.bonded_cap()` returns 2147483647 on the base, so nothing can trip it. Sync step when W2-SKILLS merges its single cap function: point the check at it and add a `t_econ` case where a full roster refuses the withdrawal and the pet stays in the vault. | n/a |
| m3 | Malformed `vault.deposit` args answered `not_found` | `bag_slot`, `count` and `pet_uid` are read with `EconArgs` and answer `bad_request` when they fail validation. `not_found` is kept for an empty slot or an unknown pet. | `t_econ` `_test_deposit` (2.5, -1, 0, "3", 1e300, INF, 0.5, -1, 999, ["x"], 7) | `FAIL malformed deposit args answer bad_request: not_found,not_found,...` |
| m4 | `vault.withdraw` ignored `count` | `count` is honoured (`insufficient_items` above the stack, as contract 4's `vault.withdraw_item`). A part leaves through `char.grant`. | `t_econ` `_test_sales` | `FAIL vault.withdraw {uid, count: 1} takes one unit, not the stack (left 7 of 7)` |
| m5 | 64 newer writes evicted a deposit's rid | Vault moves (`MarketEngine.BRIDGE`) have their own cap, `rid_cache_bridge: 256`, so market traffic never evicts them. They are still dropped by the daily idle prune. | `run_all` `_test_idempotency` | `econ: market writes keep their last 64 rids and never evict a vault move's rid (size 64, keep=false)`; `econ: a deposit replayed after 70 market writes moves nothing` |

**Fuzz.** The bridge fuzz runs 3600 ops through `client()` (the engine fuzz in `run_all`
runs 3000) with every cross-store invariant after every op: no currency or item is created or
destroyed outside faucets and sinks. It covers withdrawals with `count`, grants,
`objective.claim` from the server, hostile frames (`act.deposit`, `char.grant` and
`bridge.begin` from a client, client dicts), and cut deposits, receives and grants with a
restart. Both journals then replay from empty byte for byte.

### Acceptance (fifth pass)

The fifth pass was committed with its gates pending. The sixth-pass acceptance above covers
that code too.

### Integrator hooks (current; replaces the fourth pass's list)

1. **Apply `docs/orchestration/reports/claude-mmo-econ-hooks.patch`.** It changes:
   - `intent_handlers.gd`: `act.deposit` becomes a system op, and it adds `char.grant`, the
     pet owner rewrite and the bonded cap on receive.
   - `run_all.gd`: runs `economy_tests.gd`.

   `t_econ.gd` follows the t_*.gd convention, so no registration is needed.
2. **Boot and per request** (net server):
   ```gdscript
   var econ := EconStore.new(MarketEngine.new(EconRules.load_default(), EconCatalog.from_data()), data_dir.path_join("econ"))
   var chars := CharacterStore.new(world_facade, data_dir.path_join("chars"), world_seed)
   for why in [econ.open(), chars.open()]:
   	if why != "": push_error(why); return   # refuse to start
   var bridge := VaultBridge.new(econ, chars)
   var stuck := bridge.recover(int(Time.get_unix_time_from_system()))
   if stuck != "": push_error("[econ] %s" % stuck); return   # an asset is in no vault: a person looks
   # auth.hello:          bridge.hello(account_id, name, now)
   # EVERY client frame:  res = bridge.client(op, account_id, a, now)   (economy and act.* alike)
   # once a second:       bridge.apply("sys.tick", 0, {}, now)
   # objective observed:  bridge.apply("objective.claim", account_id, {"index": i}, now)
   ```
   Do not relay client frames to `chars.apply` or `econ.apply` directly. `client()` holds the
   list of what a client may send.
3. Still W1-INT's (contract 0.7, not in r3): Settlers issuance per active account per day.
   W3 must observe objectives and call `objective.claim`; nothing does yet.

### Assumptions added (fifth pass)

- `# ASSUMPTION` (market_engine.gd): the trade lock runs from account creation (wall
  clock). Contract 0.6 says "30 min of server-observed play"; W3 can switch it once
  presence reports play time. The refusal uses the existing `limit_reached` code, so no
  contract change is needed.
- Bound T-stones pay `wallet.spend` only. Listing fees count as trading (one rule: market
  ops spend tradable coins). Objective rewards are bound, as plan items W1-INT and W2-INT
  ask.
- `starting_wallet_bound` (20) lives in `market_rules.json` next to `starting_wallet`. Tests
  raise `starting_wallet` to get tradable coins, and `_rules()` sets `trade_lock_s = 0`.
- `rid_cache_bridge: 256` per account. A withdrawal body is about 0.4-1.2 KB, so this is at
  most about 300 KB per active account. It is pruned after a day without writes.
- While a move cannot finish, the bridge refuses every op for every account. This is a
  global stop: the simplest choice that can never trade a duplicate. With `act.deposit`
  server-only, only a store fault (a disk or engine error) can cause it.
- When the bridge finishes a withdrawal on its own after a fault, the client still gets
  `server_error`, but the asset is in its bag. A retry of that rid answers `not_found`.
- `bag_full` (srvdom's assumption code) answers a withdrawal the bag has no room for.

## Fourth pass (2026-10-20): contracts v2, bridged to the server characters

The base (`claude/mmo-overhaul`, merged twice: ~364 then 42 commits) now has W1-SRVDOM's
`CharacterStore` and `IntentHandlers`. Contract v2 section 0 says assets enter the economy
only from a server character, with provenance. This pass makes that the only way in.

### What changed

| Where | Change |
|---|---|
| `vault_bridge.gd` `VaultBridge` (new) | The one path between a character and the books. Client ops `vault.deposit {rid, bag_slot, count?}` / `{rid, pet_uid}` and `vault.withdraw {rid, uid}`; everything else passes to `EconStore`. Uses only srvdom's ops: `act.deposit` (asset out of the character), `char.receive` (exact body back), `char.settled` (a split or consumed export), `char.wallet` (mirror after every op that moved a wallet). `hello()` creates both accounts; `recover()` runs at boot. `CLIENT_OPS` is what the transport may relay. |
| `market_engine.gd` | `vault.deposit_*` / `vault.withdraw_*` moved from `WRITE` to `BRIDGE` (rid-carrying, server-only). New server ops `bridge.begin {rid}`, `bridge.end`, `bridge.settled {uids}`. A deposit takes the whole exported body, requires `Provenance.is_server`, and keeps it byte for byte under its own uid (`i<seq>.<k>` / `p<seq>.<k>`), origin and seq; the same uid twice is `conflict`. `deposit_refusal()` is the read-only precheck. |
| `ledger.gd` (state v3) | `src` (uids held exactly as exported), `retired` (exported bodies a split or a Settler consume changed, waiting for `char.settled`), `inflight` (the deposit between the two journals), `touched` (memory: wallets the op moved). `take_item` retires on a split. |
| `market_book.gd`, `order_book.gd` | A partial buy retires the exported body; a Settler consume retires it. |
| `asset_validator.gd` | Defence in depth only (the body is kept, not rebuilt). Durability cap = what `ItemStack.make` gives at that level and material tier (the base changed the rule; 24 catalog defs failed before). Pets checked against `PetStats.compute` (W2-INT's planned switch, needed now because the base changed the formula) and accept the identity fields (`uid`, `owner`, `origin`, `tamer`, `tamed_at`, `wild_level`, `name`, `parent_uids`, `hp_now`). `captured_animal` cages validate species, variant, grade_seed and genetics. |
| `econ_invariants.gd` | Character uids are exempt from the issued-id check; every `src` uid must be held and not retired. |
| `limits.json` | `captured_animal` is no longer denied. |

Caged pets (contract 6.1): a bonded pet enters through `act.deposit {pet_uid}` and is the
cage asset in the books (kind `pet`): uid, origin, lineage (`parent_uids`), genetics and stats
travel unchanged through escrow, and `vault.withdraw` hands the exact PetDict to
`char.receive`, so the buyer's character holds a bonded pet without re-taming. Captured
(untamed) animals trade as their `captured_animal` stack and still need a pen. Cages trade by
listing only: buy orders and Settlers refuse `captured_animal` (one cage is one animal).

### Crash safety between the two journals

| Cut | What boot (`recover()`) does | Test |
|---|---|---|
| after `bridge.begin`, before `act.deposit` | drops the mark | `crash ... deposit_before_export=dropped` |
| after `act.deposit`, before the vault | the one export that is in no vault and not retired goes into the marked account's vault under the client's rid (a retry of that rid then answers from the cache) | `deposit_after_export=landed` |
| after `char.receive`, before the vault let go (withdraw runs receive first) | a `src` uid the character store no longer lists was received: the vault lets go | `withdraw_after_receive=finished` |
| after a split, before `char.settled` / a wallet move before `char.wallet` | settles `retired`, mirrors every wallet | `split_before_settle=settled` |

### Acceptance (all run on this branch after the second base merge, through gslot)

- [x] `tools/smoke.sh --no-import` -> `SMOKE PASS`
- [x] `run_all.gd` -> `[tests] PASS`, with the engine fuzz line
  `[econ] fuzz 3000 ops over 6 accounts, invariants after every op: order_cancel 15/59, deposit_item 386/437, get 53/53, buy 54/295, bid 93/249, list_fixed 111/259, cancel 47/127, list_auction 171/202, item_detail 50/50, sell_to_order 17/240, get 48/48, deposit_pet 85/91, withdraw_pet 32/38, orders 44/44, tick 206/206, spend 39/39, take 82/82, mine 53/53, order_create 108/145, claim 25/31, withdraw_item 40/103, search 38/38, buyout 11/64, trades 47/47`
- [x] `t_econ.gd` (new, both stores) -> `[t_econ] PASS`:
  ```
  [econ-bridge] deposit whole=i7.0 part=i15.0 repeat_same_and_unchanged=true
  [econ-bridge] refusals codes=invalid_asset,invalid_asset,invalid_asset,not_found,not_found,not_found,unauthorized,unauthorized,unauthorized,unauthorized,unauthorized,unauthorized,unauthorized cap=limit_reached edited_body=invalid_asset twice=not_found
  [econ-bridge] sale whole=13 stone paid=91 wallets_mirrored=true split_settled=true parts=not_withdrawable,not_withdrawable
  [econ-bridge] pet uid=p11.0 origin=tame to_buyer=true cage=i26.0 species=compsognathus outbid_refunded=true
  [econ-bridge] crash deposit_after_export=landed deposit_before_export=dropped withdraw_after_receive=finished split_before_settle=settled consistent=true
  [econ-bridge] fuzz 3000 ops, 13 restarts mid-move, invariants of both stores after every op: market.buy 44/363, vault.withdraw 48/257, market.list_auction 130/149, act.gather 584/584, vault.deposit 101/476, market.cancel 22/101, sys.tick 145/145, market.list_fixed 119/330, market.bid 32/135, market.sell_to_order 22/231, market.buyout 6/58, market.order_create 103/107, market.order_cancel 6/51
  ```
  After every op the bridge fuzz checks: `EconInvariants` (6.7 items 1-4), `CharacterStore.invariants()`,
  per def "characters exported" == "vaults took in net", the same for pets, every character
  wallet == its ledger wallet, nothing in flight or retired, every export held byte for byte
  under its uid, and every held export still listed. Failed ops and repeated rids change
  neither store. Both journals then replay from empty byte for byte.
- [x] Every other `game/tests/t_*.gd` PASS: t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web.
- [x] The tests can fail. Mutants, each run through t_econ and reverted: no precheck before
  `act.deposit` (3 failures: "a deposit the vault would refuse never leaves the bag"), no
  retire on a partial buy (10: "held in another shape than it was exported"), no wallet mirror
  (24), no orphan recovery (8: "export ... is in no vault"), no withdraw recovery (7:
  "vaults took in 4 net" after the character got it back = a duplicate). The engine suite
  covers a uid deposited twice (`conflict`), an unstamped client dict and a forged origin.
- No screenshots: no visuals in this package.

### Integrator hooks (fourth pass)

Superseded by "Integrator hooks (current)" in the review r3 section: the hooks now ship as a
patch, and every client frame goes through `VaultBridge.client()`.

### Owner decisions (money rules; none changed silently)

- **Cages trade by listing only**: buy orders and Settlers refuse `captured_animal`.
- **Partial deposits** are allowed (the part leaves with a new character uid). Since the
  fifth pass, withdrawals take `count`, and split stacks leave through `char.grant`.
- Contract v2 0.6/0.7 since the fifth pass: bound starting wallet and objective rewards,
  `objective.claim` server-only, 30-minute trade lock. Still W1-INT's: Settlers issuance per
  active account per day.

### Assumptions added

- `# ASSUMPTION`-free in code; listed here: cage genetics are wild (no level gains), so they
  are checked as level 1; a cage of any species fills no order.
- State version 3: snapshots from v2 builds are refused (no server data exists yet).

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

Fourth pass: serve the books through `VaultBridge` (integrator hook 1 above). The
`vault.deposit_*` / `vault.withdraw_*` ops below are bridge-only now; clients send
`vault.deposit` / `vault.withdraw` to the bridge.

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
  A repeated rid changes nothing. The cache is the last 64 rids per account, forgotten after a
  day with no writes.
  - `vault.withdraw_item`, `vault.withdraw_pet` and `inbox.take` (`MarketEngine.KEEP_BODY`):
    the full response is persisted in the account's `rid_cache`, so a repeat returns the
    original item, pet or events after any restart and any amount of other traffic. These are
    the only responses that carry something the server no longer holds.
  - Every other write: the original response while it is in memory (the last 16,384
    server-wide writes, including everything replayed since the last snapshot). An older
    repeat, or one from before a restart, returns `{ok:true, r:{duplicate:true, op, seq}}`.
    The client should re-read its state, which holds everything such an op did.
- Always go through `store.apply`, never `engine.apply` directly, or the op is not journaled,
  a fault is not repaired, and the clock is not guarded. `store.apply` never lets time run
  backwards: every op, reads and refusals included, runs at the latest ts the store has seen,
  and the journal records that ts.
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
- Third pass: `market.buy`, `market.buyout`, `market.bid`, `market.order_create` and
  `market.sell_to_order` can now return `limit_reached` when a vault is full (see below).

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

## Tests (run on this branch, 2026-10-18, after the third-pass fixes)

Unit tests, then smoke, each through `gslot.sh` with a timeout (no new `class_name` files, so
no import was needed):

```
[econ] fuzz 3000 ops over 6 accounts, invariants after every op: order_cancel 18/56, deposit_item 405/467, get 46/46, buy 44/294, take 72/72, list_auction 149/175, tick 191/191, sell_to_order 7/232, spend 32/32, orders 40/40, bid 73/221, list_fixed 117/303, item_detail 45/45, get 51/51, order_create 114/160, cancel 45/117, search 54/54, deposit_pet 85/100, buyout 10/67, withdraw_item 24/99, mine 59/59, withdraw_pet 32/41, trades 46/46, claim 27/32
[econ] search over 10000 active listings: page 1 in 23.3 ms first call, 16.6 ms best of 3; q+newest in 28.1 ms
[econ] state with 10000 listings: 4283 KB, stringified in 108 ms; largest rid cache 2218 bytes
[econ] full snapshot of that state: 111 ms
[tests] PASS
SMOKE PASS
```

Timings vary run to run with machine load: stringify measured 67-108 ms across this pass's
runs. Mutation check: with the six changed engine files put back to the previous commit and
the new tests kept, the run fails 26 checks, covering every finding below. The log's
`Save schema 4 is newer` error comes from the save-migration tests, not from this package.

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
| Minor: state field names drifted from contract 4 | `claimed` is now `claimed_objectives`; `rid_order` is gone. State version is now 2. (Third pass: `rid_cache` holds the full response for withdrawals and inbox.take, `[op, seq]` otherwise; orchestrator: please note this in contracts.md 4) | Version test |
| Minor: `assert` guards vanish in release | `debit`/`credit` refuse and `push_error`, which faults the op | `_test_fault_reload` debit case |
| Minor: `market.mine` unpaged, bidder ids public, silent inbox overflow | Paged closed history, `has_bid`/`my_bid`, anonymous public tape, `dropped` count | `_test_market_views` |
| Minor: eviction and first-call timing untested | Asserted | `_test_idempotency`, `_test_search_perf` |

## Second review fixes (third pass)

Each test below fails on the code before this pass; I checked that by running it there.

| Finding | Fix | Test |
|---|---|---|
| Blocker: a repeated `withdraw_item` / `withdraw_pet` rid after a snapshot + restart, or after 16,384 other writes, got `{duplicate:true}` with no asset: the asset was gone from the vault and never handed over. `inbox.take` lost events the same way | Responses of the `KEEP_BODY` ops are persisted in the account's `rid_cache` as `[op, seq, response]`, as contract 4 says; the rest keep `[op, seq]` (their effects are all in state to re-read, and persisting listing bodies cost about 56 KB per account, which the first review flagged) | `_test_rid_bodies`: withdraw item, withdraw pet and take, snapshot, reopen, repeat each rid: same body and nothing applied. Then a partial withdraw, 16,385 writes by another account, repeat: same item and the stack still holds 6 |
| Minor: vault caps only checked on deposit | `Ledger.vault_full`. `buy`, `buyout` and `order_create` need a free slot; `bid` needs one counting the auctions the bidder already leads; `sell_to_order` refuses while the order owner's vault is full (each fill is a new stack, so the order pauses). Assets already in escrow still deliver (auction wins, returns from cancel and expiry): nothing is refused late or lost, and a vault can overshoot by at most its owner's own listings plus auctions it led | `_test_vault_caps`: ten 1-unit buys stop at 3, and buy, bid, buyout, order_create, a leading bid holding the last slot, fill into a full vault and a pet buy all return `limit_reached`; an auction won after the vault filled still delivers (4 of 3) |
| Minor: wall clock stepping back contradicted an earlier "expired" | `EconStore.apply` keeps the latest ts it has seen and passes that to every op; the journal records the clamped ts, so replay is unchanged. The engine alone still clamps only to the last write | `_test_clock`: buy refused at end+5, then at end-30: still `expired`; same after a read at the later time |
| Minor: re-anchor rule deviates from 6.5 and could be triggered by many small trades | Re-anchor now needs most eligible trades **and** most units outside the band, so neither many tiny trades nor one large one can do it. Marked `# ASSUMPTION:`. **Orchestrator: please amend contracts.md 6.5** to: "...excluding trades priced outside 0.25x-4x the previous reference, unless most of the window's eligible trades and units are outside it, in which case all eligible trades count" | `_test_reference_poisoning`: three 1-unit trades at 1 leave a reference of 20 (by count alone it drops to 10); the 100-unit outlier in `_test_history_and_reference` covers the other side |
| Minor: after a fallback boot, the next snapshot deleted the journal bridging snapshot.prev | `snapshot()` appends the journal to `journal.prev` instead of replacing it whenever there is no `snapshot.json` to rotate, so `journal.prev` always bridges `snapshot.prev` to the new snapshot. A crash mid-append leaves lines in both files, and boot replays each seq once | `_test_snapshot_failures`: fallback boot, snapshot, one more op, then a second bad `snapshot.json` still boots to the live state (before: "jumps from seq 16 to 21") |
| Minor: `#-12345` accepted as a tint | Each digit checked against `[0-9a-fA-F]` | `_test_item_deposits`: `#-12345` and `#+1234567` refused |
| Minor: snapshot cost grows with closed history | Not changed in code; measured and documented under Limits (scaling ceiling). Moving closed history and the trade log into an append-only side file is the fix once the ceiling is near | `_test_search_perf` now times a full `snapshot()` |

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
- **(Superseded by the fourth pass: deposits now come only from server characters with
  provenance; what follows describes the v1 trust model.) Deposits are validated client claims (contract 4, v1).** Gathering, crafting, taming and
  combat run on the client. Per account per day, a cheating client can deposit up to the caps
  of any item. It can also mint pets: up to 3 per species and 10 in total, each a level-60
  pet with IV 31 in every stat and the S-grade hunger/xp rate. The integrity checks only
  ensure the numbers are self-consistent. Accounts are free (contract 3), so sybil accounts
  multiply all of this, and the market lets them move it to one account.
- **Coin faucet (fifth pass).** `objective.claim` is server-only now and its 72 T-stones are
  bound, like the 20 starting T-stones: they pay travel and claims but never reach another
  account. Sybil accounts can no longer funnel coins through the market. What is left is W3's
  job: calling `objective.claim` only when the server saw the objective done. Settlers add at
  most 2,000 a day server-wide.
- `wallet.spend travel` accepts any sail cost that exists, not the voyage actually taken.
- `process_count` is capped at 99 (steaming adds one each time; no smaller legitimate bound).
- `volume_24h` / `volume_7d` sum whole hourly buckets, so they can include up to an hour of
  older trades.
- A script error during an op triggers a reload from disk (about a snapshot parse plus up to
  500 replayed ops). Errors logged by another thread during an op cause a needless reload.
  A client that finds a reproducible internal error can make the server do this repeatedly;
  it cannot corrupt the books.
- Search is a linear scan (10-28 ms at 10,000 listings, depending on load). Indexes are not
  needed until roughly 50,000 active listings.
- **Snapshot scaling ceiling.** A snapshot stringifies, writes, reads back and compares the
  whole state on the caller's thread, every 60 s or 500 ops. Measured: 10,000 active listings
  = 4.3 MB, and a full snapshot takes about 70-110 ms. A closed listing (kept 7 days with its
  asset copy) costs about the same as an active one, about 430 bytes. So 5,000 closed
  listings a day adds about 15 MB, and each snapshot then stalls the server for roughly
  300-500 ms. Keep active listings plus 7 days of closed listings and orders under about
  25,000 (about 10 MB, about 200 ms per snapshot). Past that, move `closed_listings`,
  `closed_orders` and `trades` into an append-only side file, or raise `snapshot_every_s`
  (boot then replays a longer journal).
- **Vault caps can overshoot a little.** Settlement never refuses: an auction won or a listing
  returned after its owner's vault filled still lands there. Overshoot is at most the owner's
  open listings (50) plus the auctions they led when the vault filled. A vault past the cap
  can still withdraw and sell, but cannot deposit or buy until it is back under. A full vault
  pauses its owner's buy orders (`sell_to_order` returns `limit_reached`), so instant sell
  should fall back to the next best order.
- **Persisted rid bodies.** A withdrawal body is one item or pet dict (about 0.4 or 1.2 KB),
  so at most about 80 KB per account for 64 withdrawals. Cached `inbox.take` bodies hold at
  most the events the account received across its last 64 writes. All of it is pruned after
  a day with no writes. A repeat of a withdrawal evicted by 64 newer writes, or idle for a
  day, applies again (by then the client has long had its answer).
- **Clock guard is per process.** The latest-seen ts lives in `EconStore` memory. After a
  restart it starts from the last write's ts, so a wall clock stepped back across a restart
  can still contradict a read answered just before it. Use a clock that never steps back
  (for example `CLOCK_MONOTONIC` plus a boot offset) if that matters.
- Names are not checked for uniqueness here (`auth.hello` owns that); rate limits (5.4)
  belong to the transport.

## Assumptions (marked `# ASSUMPTION:` in code)

- The only T-stone priced `claim` is opening a crater (`rules.json` `open_cost_tstones`).
- Any listed sail cost is a legal `travel` spend.
- A bid at or above the buyout is refused; the buyer uses `market.buyout`.
- Closed Settler orders are not kept, so they read as `not_found`, not `closed`.
- Settler trades count toward volume and OHLC but not the reference price.
- The reference re-anchors on all eligible trades when most trades and most units sit outside
  the 0.25x-4x band (an extension of contract 6.5; see "Second review fixes").
- Retries and replayed frames arrive within a day; a rid idle longer applies again.
- Settlers only buy (contract 6.6): every refresh they cancel their orders and post up to 12 new
  ones with at most 500 escrowed, priced base x mean regional demand x scarce/abundant
  multiplier x 0.8; each server day their holdings are topped up to 2,000, so no more than
  2,000 T-stones a day reach players through them.
