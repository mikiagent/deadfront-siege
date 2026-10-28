# claude-econ2: ECON (market engine) landed on the integration line

Branch `claude/mmo-econ2`, cut from `claude/mmo-overhaul` 0a576e0b. It merges `claude/mmo-econ`
ec2fe9c2 with `git merge` (no rebase). Not pushed and not merged into `claude/mmo-overhaul`.
ECON's own history is in `docs/orchestration/reports/claude-mmo-econ.md`.

## What landed

| Commit | What |
|---|---|
| f67fa6e6 | Merge of `claude/mmo-econ` (no conflicts), plus the hooks patch `claude-mmo-econ-hooks.patch` applied (see Conflicts). |
| a15a63e9 | Canon fix: flawless crafts and crafted rare traits can be deposited (CRAFTFEEL landed after ECON's last base). |
| (docs) | `docs/current/economy-trading.md` and `server-contract.md` now say the server-side market engine exists (online only), and that `act.deposit` and `char.grant` are server-only. |
| (this) | This report. |

Scope: `game/scripts/economy/` (engine, ledger, books, VaultBridge, recovery), `game/data/economy/`,
the tests `t_econ.gd`, `econ_bridge_checks.gd` and `economy_tests.gd`, and the hooks in
`intent_handlers.gd` and `run_all.gd`. No UI. Nothing in single-player calls the engine, and no
single-player character moves into a server store. Settlers' NPC orders carry `npc: true`, so no
simulated activity is presented as a player's.

## Review r3: each finding, its fix and the test that fails without it

The state is not what the prompt described. Every r3 finding
(`docs/orchestration/mmo/handoff/findings/econ-review-r3.json`) was fixed on `claude/mmo-econ` in
its fifth to thirteenth passes, including the WIP commit e0d34c74 the prompt called untested.
Re-reviews r4, r5 and the resumed r3 followed. I did not take that on trust. On this merged tree
I re-applied each old behaviour as a mutant, ran the test, and reverted.
Script: `$TMPDIR/econ2/mutants.py`; logs: `$TMPDIR/econ2/mut/`. **All 12 mutants fail.**

| # | Finding | Fix (where) | Mutant (old behaviour) -> failing line on this tree |
|---|---|---|---|
| B | A client could send `act.deposit` | Hooks: `act.deposit` moved to `IntentHandlers.SYSTEM_OPS`. `VaultBridge.client()` is the only relay and answers `unauthorized` (logged) for anything server-only. `bridge.begin` records `{account, rid, uid, op}`, so `recover()` lands only the marked uid. | `act.deposit` back in `CLIENT_OPS`: `[t_econ] FAIL act.deposit is a server-only op of the character store`, `FAIL vault.deposit left the stores inconsistent: ... export i7.0 is in no vault` (6 FAIL lines) |
| M1 | Split stacks could never be withdrawn | `vault.withdraw {rid, uid, count?}`: a whole export goes through `char.receive`, anything else through `char.grant` (hooks; refuses more units than are out, so it cannot mint) under a `bridge.begin` mark | grant path -> `not_withdrawable`: `FAIL a partial buy reaches the buyer's character`, `FAIL the seller's remainder comes back to the bag: 0 of 8`, `FAIL units bought through a buy order reach the buyer's character` |
| M2 | Contract 0.6/0.7: `objective.claim` mints on request, tradable start, no trade lock | `objective.claim` in `MarketEngine.SYSTEM`; `starting_wallet_bound` 20 (bound pays sinks only); `trade_lock_s` 1800 on every TRADE op | (a) claim back in WRITE: `ERROR: [tests] econ: objective.claim is not a client op`; (b) bound 0: `econ: the starting wallet is bound: { "wallet": 20, "bound": 0 }` (`[tests] FAIL count=11`); (c) lock off: `econ: market.list_fixed (list inside the trade lock) should fail with limit_reached, got { "ok": true ...` (`FAIL count=5`) |
| M3 | Bridge recovered only at boot | `apply()`/`client()` call `recover()` right after a move that could not finish; everything is refused while a move is stuck; `bridge.begin` answers `conflict` while a move is marked | (a) no in-request recover: `FAIL a vault fault after char.receive is finished in the same request (server_error)` (3 FAIL lines); (b) begin overwrites: `FAIL bridge.begin refuses while another move is marked (ok)` |
| m1 | A bought pet kept the seller's `owner` | Hooks `_receive`: `owner = str(account)` | `FAIL a bought pet answers to its buyer (owner 1, was 1)` |
| m2 | Bonded cap / 6.1 shape | Cap checked in `VaultBridge._withdraw` with `Data.bonded_cap()`. The 6.1 wording is an orchestrator item (below). | cap check off: `FAIL a full roster (3 of 3) refuses a bought pet, which stays in the vault (ok)` |
| m3 | Malformed deposit args answered `not_found` | `EconArgs` validation -> `bad_request` | `FAIL malformed deposit args answer bad_request: not_found,not_found,...` |
| m4 | `vault.withdraw` ignored `count` | `count` honoured | `FAIL vault.withdraw {uid, count: 1} takes one unit, not the stack (left 0 of 9)` (4 FAIL lines) |
| m5 | 64 market writes evicted a deposit's rid | Separate `rid_cache_bridge` 256 | one shared cap: `ERROR: [tests] econ: market writes keep their last 64 rids and never evict a vault move's rid`, `vault moves have their own cap` |

The later r3-relay items (rare traits, search filters, oversized grants, grant fields, full bag,
repacked kits) pass on this tree: t_econ prints
`[econ-bridge] full bag empty=0 whole=bag_full part=bag_full in_vault=true unchanged=true stuck='' search=ok | freed retry whole=ok part=ok home=15 of 15 again=not_found`.

## Conflicts and resolutions

- **The merge** was clean (no textual conflicts).
- **Hooks patch, `intent_handlers.gd`**: all hunks apply at a 36-line offset. W2-GATHER and CRAFTFEEL
  changed `_gather` and `_craft`, which the hooks do not touch. The patched `_deposit`, `_receive`
  and `_grant` read the same as on ECON's base.
- **Hooks patch, `run_all.gd`**: the hunk no longer matched, because W2-PROCESS and COMMCENTER
  added tests at that spot. I kept all of them and call `economy_tests.gd` after
  `_test_comm_center_registration()`.
- **CRAFTFEEL vs ECON's whitelist (a semantic conflict; canon's behaviour kept)**:
  `Crafting.apply_outcome` sets `flags.flawless`, `attributes.quality = "flawless"` and
  `attributes.flawless_bonus`, and multiplies `max_durability` by 1.1. It also writes a rolled rare
  trait as `1`, a level, where gathering writes `true`. ECON refused all of these, so no flawless or
  trait-rolled crafted tool could be sold. The fix:
  - `limits.json` allows the `flawless` flag, `quality` (enum) and `flawless_bonus` (num 0..1).
  - The six traits accept `true` or a level 1..60.
  - `AssetValidator` raises the durability cap of a flawless item by `rules.json`
    `crafting.flawless_stat_bonus`. It never reads the item's own field.
  - The test builds the item with `Crafting.apply_outcome` itself, so it follows the game, and
    refuses forged variants: the flawless durability without the flag, one point over the bump,
    and a `flawless_bonus` of 5.
  - On the previous validator, the new checks give `[tests] FAIL count=7`
    (`attribute black_sheen = 1 from Crafting.apply_outcome's rolled trait is allowed (... must be true/false)`, `flag flawless not allowed`).
  - **One assert changed.** I did not weaken it; it contradicted canon. The old assert was "a
    trait is true/false, not a number" (`black_sheen: 1` refused). Canon now writes 1, so it
    became bounds checks: 0, 61, 2.5, `"yes"` and `[1]` are refused.
- W2-GATHER's six traits match `loot_tables.json` and `rules.json crafting.rare_attributes` (now
  asserted). W2-INV uids, BAGS (no material carries `pocket`/`capacity` today, so bags trade as
  plain gear), CAPTURE09 and `captured_animal` cages (genetics now carry `coloration`; the body is
  kept byte for byte, and the validator ignores that key) all pass through the existing tests
  unchanged.

## Save / format changes

**No single-player save change.** No file under `core/save*`, `SaveGame` or the sanitizer is
touched, and no SP data moves anywhere. Server-side stores, which have no real data because no
host exists:
- `EconStore` (new) is ledger state version 3.
- `CharacterStore` gains the op `char.grant`.
- `char.receive` now restores the exact exported row, keeping its uid. An old srvdom journal that
  holds a `char.receive` would replay to a different uid. None exists outside tests.

## Gate results (all through gslot, this tree at the final commit)

- Import: rc 0, 0 SCRIPT ERROR, 0 "failed".
- 63 `t_*.gd` and `run_all`: 62 exit 0 with their PASS line. `[t_econ] PASS`, `[t_srvdom] PASS`, `[t_server_domain] PASS`,
  `[t_inventory] PASS`, `[t_save] PASS` (its 5 deliberate SCRIPT ERRORs), `[t_gather] PASS`,
  `[t_tame] PASS`, `[t_capture09] PASS`, `[t_data] PASS items=240 recipes=165`.
- `run_all.gd`: `[tests] PASS`. Its SCRIPT ERRORs are the 3 known compile-order ones (TouchControls)
  plus the 2 deliberate ones after `[econ] fault test: the next SCRIPT ERROR and ERROR lines are deliberate`.
- t_econ fuzz: `[econ-bridge] fuzz 3600 ops, 15 restarts mid-move, invariants of both stores after every op (coins issued 3579, sink 398)`.
- `tools/smoke.sh --no-import`: `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS`.
- Two failures, both on the base and in files ECON does not touch:
  - `t_uiicons` (`status caffeinated has an icon` etc.; FOODFX, known).
  - `t_mounts` (`[tmount] FAIL coelophysis has no saddle and is not in mounts_skip.json`): canon
    47592db4 removed the coelophysis saddle but left `mounts_skip.json` `skip: {}`.

## Assumptions (new in this pass)

- `# ASSUMPTION`: a rare trait level is 1..60, the item level range. No doc bounds it; the code
  writes `true` or `1` (`limits.json` `black_sheen._assumption`).
- `# ASSUMPTION`: `flawless_bonus` is bounded to 0..1.
- Carried from ECON: the trade lock runs on wall clock from account creation (contract 0.6 says
  play time; switch to it when presence reports play time). Settlers top up a flat 2,000 a day,
  where contract 0.7 says per active account (W1-INT's).

## Open risks / decisions

- **Orchestrator (carried from r3 m2):** contract 6.1 says a traded pet becomes a `caged_animal`
  item. ECON trades kind `pet` with the full PetRecord (same uid and lineage, cap on bond). Either
  amend 6.1 or schedule the switch with W2-CAGE.
- `Data.bonded_cap()` reads the local player. A process that hosts the books and also has a local
  player would apply that player's Animal Handling nodes to every buyer (`# shortcut` in
  `vault_bridge.gd`; fixed by W3-SRVACT).
- Nothing calls `objective.claim` from the server yet (W3 must observe objectives), and no
  transport is wired. `VaultBridge.client()` is the relay to use.
- The `t_mounts` base failure needs its owner (the saddles/data line).
