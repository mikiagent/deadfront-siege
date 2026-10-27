# dsc — simulated island market (economy phase 1, no UI), 2026-10-27

## What shipped

- **`game/scripts/world/market_system.gd`** — `class_name MarketSystem extends RefCounted`, a pure
  simulation of the four regional markets of `docs/design/economy.md` v1. No `Node`, no scene, no
  autoload, no UI, no player or harbour wiring. Constructed by `MarketSystem.load_default()` (reads
  `Data.market`) or `MarketSystem.from_data(dict)` (tests). For now only tests construct it.
  - `price(market, item, level, attributes)` = per-item base × `(1 + level_slope·level)` × attribute
    bonus × regional demand × saturation, snapped to 0.01.
  - `apply_sale` / `saturation` / `tick(hours)` — saturation and recovery; `tick` also settles
    listings. Recovery is driven only by the explicit hours argument; there is no RNG on the price
    path and no use of wall-clock time.
  - `list_stack` — fee up front, unstable refusal, instant sale at/below the price, a settle-hours
    curve above it; `pending_listings`, `sold_value`.
  - `buy` / `buy_price` — the sell-to-player side.
  - `animal_price` / `list_animal` — animal listings priced by grade.
  - `credit` / `debit` / `balance` / `fees_paid` — the T-stone wallet and the listing-fee sink.
  - `state_dict()` / `restore_state()` — price memory for the M9 save wiring (not saved yet).
- **`game/scripts/core/data.gd`** — `Data.market` is parsed from `res://data/world/market.json`
  inside `_load_world()`; an absent file leaves it `{}` instead of erroring, so a stripped build is
  harmless. No existing load was changed.
- **`game/data/world/market.json`** — existing fields untouched; added the tunables the design left
  implicit (see below).
- **`game/tests/run_all.gd`** — ten `_test_market_*()` functions, called from `_process()` after
  autoloads exist. `.dsc/verify_market.sh` (the task's gate) was missing from the worktree and was
  recreated: import + full suite + `tools/smoke.sh`, with `HOME` redirected to a temp dir when the
  sandbox makes `user://` unwritable (Godot otherwise segfaults while copying its log).

## Formula constants: from the doc vs pinned here

From `docs/design/economy.md` (and already in `market.json`):

| Constant | Value | Source |
|---|---|---|
| `level_slope` | 0.06 (`1 + 0.06·level`) | doc, Prices |
| `attribute_bonus.latent` / `.rare` | +25% / +100% | doc |
| `scarce_item_multiplier` / `abundant_item_multiplier` | 3.0 / 0.5 | doc ("0.5 (abundant) to 3.0 (scarce)") |
| `saturation.per_unit_sold` | 0.02 | doc |
| `saturation.recovery_per_hour` | 0.1 (10% of the gap per hour) | doc |
| `listing_fee` | 0.05 | doc |
| `buy_multiplier` | abundant 1.3, scarce 2.5 | doc |
| `animal_grade_multiplier` | S 2.0, A 1.5, B 1.0, C 0.7 | doc |
| `sell_time_hours` | at_price 0, over_20pct 1, over_50pct null | doc ("20% over sells in about an hour; 50% over never") |

Pinned by me (added to `market.json` so nothing numeric is buried in code):

| Key | Value | Why |
|---|---|---|
| `saturation.floor` (pre-existing) | 0.2 | kept as the data's own floor |
| `saturation` composes multiplicatively | `0.98^units` | doc says "each unit lowers the price by 2%"; compounding is the simplest reading and is what makes "dumping 50 units halves the price" exact enough (0.98^40 ≈ 0.446) |
| `saturation` recovery | `1 - (1 - s)·0.9^hours` | "recover 10% of the gap per hour", read as a compounding recovery of the distance back to par. A 40-unit dump (0.98^40 = 0.446) is at 0.599 one hour later: it has come 28% of the way back, which matches the doc's "come back after an hour and it has recovered about a fifth" in spirit (the doc does not pin the exact figure) |
| `sell_slope_window` | 0.2 | anchors the linear settle curve at 1.0x → 0 h and 1.2x → 1 h |
| `never_above_ratio` | 1.5 | where `over_50pct: null` starts to apply; between 1.2x and 1.5x the ask just takes longer |
| `default_base_price` | 3 | fallback for an item with no priced category |
| `attribute_ignore` | `climate`, `level`, `material_tier`, `tint` | bookkeeping attributes stamped by `island_runtime.gd`, not latent pips; counting them would add +25% per unit of bookkeeping |
| `rare_attribute_key` | `rare` | attributes listed under `rare` (array or single key) get the +100% rare bonus |
| `buy_tier_demand` | scarce ≥ 1.75, abundant ≤ 0.75 | the buy side needs to know which tier an item is when it is neither on the `scarce_items` nor `abundant_items` list but has a strong category demand |
| `category_aliases` | e.g. `food → food_raw`, `ore`/`metal → metal_ore`, `cooked → food_cooked`, `lashing → cordage`, `earth → clay`, `building → building_kit`, armors → `clothing` | `data/items.json` categories do not match the priced categories; base price is the *highest* priced category the item has |
| `item_base_price` | salt 10, obsidian 26, flint 4, ice 3, pearl 60, coral 24, ingots 26–48, `metal_shard` 5, `black_iron` 12, `sandstone` 3, `cactus_spine` 2, `sulphur` 4, `captured_animal`/`tamed_animal` 400 | items whose categories carry no market price at all (salt is only a `seasoning`); animal items price at the generic animal base |

Assumptions in code (marked `# ASSUMPTION:` where they are decisions, not data):

- The settle curve is linear between the doc's two anchors and keeps climbing to 1.5x; the doc's
  three data points do not define 1.3x, and jumping to "never" at 1.2x would contradict "20% over
  sells in about an hour".
- An item category with no price row is worth `default_base_price`.
- Creature data carries no price, so `default_animal_base()` uses the `animal` base price (400).
- Animals do not saturate a market (they are not hauled materials); the doc does not say.
- Unknown grades are refused (0 price) rather than guessed.

Known doc inconsistency (not edited, per the task): economy.md acceptance #3 says a level-30 knife
lists for "about 2.8×" a level-1 knife, but the documented formula gives
`(1 + 0.06·30)/(1 + 0.06) = 2.64`. The formula was implemented; the test asserts the 2.64 ratio so
anyone changing the slope sees it.

## Tests added (`game/tests/run_all.gd`)

`_test_market_data_load`, `_test_market_price_formula`, `_test_market_determinism`,
`_test_market_saturation_and_recovery`, `_test_market_listing_fee_and_settlement`,
`_test_market_unstable_gate`, `_test_market_buy_side`, `_test_market_animal_grade`,
`_test_market_tstone_sink`, `_test_market_price_memory`. They cover: four markets load and map to
climates; the price formula (level factor 1.06/3.4, latent and rare pips, bookkeeping attributes not
counted, scarce 3.0 vs abundant 0.5 for the same salt); determinism across repeated calls and two
independently fed instances; 2%/unit saturation, the 0.2 floor, per-market/item isolation, 10%-of-gap
recovery; 5% fee, instant sale at price, 1.2x → 1 h, 1.3x → 1.5 h, 1.45x still hours, 1.5x never,
undercut at once, no fee without funds; the unstable gate refusing before any fee; buy multipliers
1.3/1.8/2.5 and wallet spend; S/A/B/C animal prices and refusal of an unknown grade; the fee sink and
a wallet that cannot go negative; and a price-memory round trip including malformed saved data.
All 38 pre-existing tests still run; `tools/test.sh` equivalent (`import + run_all.gd`) prints
`[tests] PASS`, `tools/smoke.sh` prints `SMOKE PASS`.

## Deliberately deferred

- No UI (`hunt_hud.gd`, market screen), no harbour integration (`world/harbour.gd` and its "one market
  building at the home harbour" note in economy.md), no player inventory wiring, no scene changes, no
  autoload. Nothing calls `MarketSystem` outside the tests.
- Price memory is not in `save_game.gd`; M9 wires `state_dict()` / `restore_state()`.
- Simulated buyers are abstract: a listing settles when `tick` passes its hours; there is no NPC
  agent or per-settler need model yet (the doc asks for one "later, when real players arrive").
- Cargo-warp itself (`World.CARGO_FEE`) is not charged by the market; the market only refuses the
  `unstable` flag, which is what cargo-warp clears.

## Notes for the next agent

- `godot --headless --script` needs a writable `HOME`; in this sandbox the engine segfaults copying
  its log otherwise. `.dsc/verify_market.sh` handles it.
- A follow-up that touches the market screen should construct `MarketSystem.load_default()` from the
  harbour and call `tick(hours)` from the day/night clock rather than from `_process` deltas, so the
  simulation stays deterministic.
