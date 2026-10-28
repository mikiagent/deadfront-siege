# Economy & trading — T-stones, sinks, sources, market data

The only currency in the build is **T-stones**: a plain int `World.t_stones` in
`game/scripts/core/world.gd`, starting at 20. It is not an item — no `t_stone` id exists in
`game/data/items.json`, and no inventory slot holds it. It saves as the key `t_stones`
(`game/scripts/core/save_game.gd`) and the sanitizer clamps it to 0–`MAX_T_STONES` 100000
(`game/scripts/core/save_sanitizer.gd`). There is no second currency, no bank and no wallet on the
client. (Warp Gems mentioned as a skill-refund charge are not implemented.)

Client display: the level-up stack prints "T-stones n" (`game/scripts/ui/hunt_hud.gd`), the map
screen meta line (`game/scripts/ui/map_screen.gd`), the island-pick rows and the camp status line
(`game/scripts/ui/world_ui.gd`).

## Sinks that exist today
| sink | cost | where |
|---|---|---|
| Sail to another island | `sail_cost` of the destination: 5 for every island without an explicit value, 0 for `home_grassland`, 5 in `game/data/islands/temperate_25.json`; gated further by a Survival level | `World.travel`, `game/scripts/core/world.gd` |
| Cargo warp (camp chest on an unstable island) | `World.CARGO_FEE` = 2 per shipment, charged only when something is accepted | `World.cargo_warp`, `game/scripts/world/cargo_warp.gd` |

Not T-stone sinks: repairs cost materials (`StructurePlacer.repair_cost`, half of the blueprint),
skill nodes cost SP, travel to the harbour/warp home is free. `rules.json` `craters.open_cost_tstones`
= 50 is loaded but read by no code — *unverified* whether any UI will charge it.

## Sources that exist today
| source | amount | where |
|---|---|---|
| New game | 20 | `World.t_stones` initial value |
| Objective steps | `t_stones` per step: 2, 2, 3, then 5 per step, 20 on the last | `game/data/world/objectives.json`, paid by `Objectives.settle` (`game/scripts/core/objectives.gd`) |
| Crater discovered | `rules.json` `craters.discover_tstones` = 30 | `World.discover_crater` |

There is no selling, no vendor NPC and no trade with other survivors in client code. The unstable
flag on materials is removed by cargo warp, not by selling.

## Market data — `game/data/world/market.json`
Data only for the client. The Island Market screens (`game/scripts/ui/market/`, see
[ui-screens.md](ui-screens.md#island-market)) talk to the Island Market engine below and show an
honest offline card in single-player; the server-side market engine
(below, "Island Market engine") prices from its own `game/data/economy/` files, not this one. The
file is read by one test (`game/tests/t_data.gd`) that checks every item's `market_category`
against the base-price table; the game loader (`game/scripts/core/data.gd`) does not load it. All
"market" references in scripts are forward-looking comments (item origin `market`, `ItemDef.
market_category`, a pet-record note).

What the file would price (its own formula line: base × level slope × attribute bonus × market
demand × saturation):
- `level_slope` 0.06; `attribute_bonus` latent 0.25, rare 1.0; `listing_fee` 0.05.
- `saturation`: 0.02 per unit sold, recovery 0.1 per hour, floor 0.2.
- `buy_multiplier`: abundant 1.3, normal 1.8, scarce 2.5. `sell_time_hours`: at price 0,
  over 20 % 1, over 50 % none.
- `animal_grade_multiplier`: S 2.0, A 1.5, B 1.0, C 0.7.
- `base_price_tstones` (22 categories): fibre 2, wood 2, stone 2, clay 2, herb 3, food_raw 3,
  meat 4, cordage 4, bone 4, hide 5, food_cooked 8, metal_ore 8, cloth 10, medicine 15, ingot 20,
  tool 25, clothing 30, building_kit 30, weapon 40, gem 40, unstable_loot 60, animal 400.
- Four markets, each with per-category `demand`, `scarce_items` and `abundant_items`:
  Temperate Exchange (temperate, grassland, savannah; metal_ore ×2.0, gem ×2.5),
  Tropic Bazaar (tropical, blue_tropical, swamp; hide 1.6, metal_ore 1.8, cloth 1.4),
  Frontier Post (desert; wood 2.2, fibre 1.8, herb 2.0),
  Northern Depot (tundra, snowfield; cloth 2.0, herb 1.8, hide 0.6).
  Global `scarce_item_multiplier` 3.0, `abundant_item_multiplier` 0.5.

`game/data/world/missions.json` (`tstones_base` 40, `tstones_per_tier` 3) and
`game/data/world/factions.json` (`crate_tstones`) carry T-stone numbers that no code reads today;
the loader loads neither file.

## XP economy (rules.json `xp`)
| action | XP | where |
|---|---|---|
| Gather pass | `gather_base` 1 + `round(seconds that pass waited)` — a 2.8 s stone pass pays 3, a 3.0 s log pass 3-4, a 1.1 s berry pass 2, a Lv-60 rock bare-handed (10.1 s) 11 against 8 with a pick | `PlayerActions.gather_pass_xp` (`game/scripts/player/player_actions.gd`), seconds from `GatherService.unit_seconds` via `_gather_unit_time` |
| Rock/clay pass, extra | +1 Processing on top of the above | `PlayerActions.finish_gather` |
| Build, a kit kind's first placement ever | `build_first` 30 | `World.note_building` -> `World.build_placement_xp`, `game/scripts/core/world.gd` |
| Build, a repeat of a known kind | `build_repeat` 8 | same |
| Build, same kind within `build_spam_radius_m` 10 m of one placed under `build_spam_seconds` 60 s ago | 0 | same; the 60 s tank is transient (`World.build_recent`, cleared on island load) |
| Blueprint structure completion | the blueprint's own `xp` plus the build award above, in one grant | `BuildFlow.complete` -> `World.note_building` |

The first-of-kind memory is `World.pioneer_buildings` (kind -> placements, saved under
`pioneer_buildings`; a save without the field loads with none). Both bars follow: the Construction
tree grant is mirrored into `World.add_xp` by `SkillState.add_xp`. The level curve is untouched
(`World.xp_for_level` = 100 + 25 x level). A repacked kit (pack up, place again) pays nothing.
Test: `game/tests/t_xpecon.gd`.

## What does exist that moves value
- Objectives pay XP and T-stones automatically when their step completes (`Objectives.settle`).
- The camp cargo warp moves unstable goods into home cargo for the flat fee above; a full cargo
  basket accepts nothing and the fee is not charged.
- The Island Market engine (below) moves T-stones and items between server characters.
- Cargo and storage capacity, which bound what can be traded at all, are in
  [inventory-bags.md](inventory-bags.md).

## Island Market screens
The Market is reached from the nav menu's **Island Market** entry (the right column's
Friends slot, `game/scripts/ui/nav_menu.gd`) or `HuntHud.open_market(tab)`; the screens live in
`game/scripts/ui/market/` and their ‹ returns to the nav menu. In the single-player build every
tab shows the offline card — the numbers below move nothing client-side. The dev/test harness
(`game/scripts/dev/market_harness.gd` with `LocalMarketClient`) drives the real engine in process
so the screens can be seen with listings. See [ui-screens.md](ui-screens.md#island-market).

## Island Market engine (online only) — `game/scripts/economy/`
Server-side and in-process, like `game/scripts/server/` (no transport, no host). Nothing in the
live single-player game calls it: offline play has no market, and the market screens say so. The
screens' only door is `MarketClient` (`game/scripts/ui/market/market_client.gd`); the dev/test
transport `LocalMarketClient` runs the real `VaultBridge` in process (`scripts/dev/market_harness.gd`). Entry points:
- `EconStore` (journal + snapshots under a data dir) wraps `MarketEngine` (ledger, fixed listings,
  auctions, buy orders, Settlers NPC orders flagged `npc: true`, price history, search).
- `VaultBridge` is the only path between a server character (`CharacterStore`) and the books:
  `client(op, account, args, ts)` is the one relay for client frames; `vault.deposit` /
  `vault.withdraw` run `act.deposit` / `char.receive` / `char.grant` (all server-only ops) under a
  `bridge.begin` mark, and `recover()` finishes or undoes a cut move at boot or right after a fault.
- Money rules (`game/data/economy/market_rules.json`): starting wallet 20, all bound
  (`starting_wallet_bound`); objective rewards are bound and fire only from the server
  (`objective.claim` is a system op); bound T-stones pay sinks (listing fees, `wallet.spend`), never
  buys, bids or order escrow; `trade_lock_s` 1800 from account creation (wall clock, `# ASSUMPTION`).
- Deposit whitelist (`game/data/economy/limits.json`): attributes, flags (`raw`, `poisoned`,
  `repacked`, `flawless`; `locked` and `unstable` refused), instance fields, per-def caps.
- Tests: `game/tests/t_econ.gd` (both stores, fuzz, crash recovery) and `economy_tests.gd` (run by
  `run_all.gd`).
