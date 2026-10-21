# W2-INV report: inventory and equipment by instance

Branch `claude/mmo-w2-inv`, base claude/mmo-overhaul 34b6d459 merged in (80348edd). Hooks patch
`docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch`: `git apply --check` is clean on the branch and on
claude/mmo-overhaul 34b6d459 alone (checked against a temporary index of the base).

Owner approval on record (STATUS, 2026-10-20): "the non-stacking inventory save change is approved: merge it once its
independent review passes and old saves migrate cleanly in tests." The package is still **unreviewed**.

## What shipped on the branch (owned files)
- `game/scripts/items/item_def.gd`: materials and food do not stack (owner 2026-10-20, prompts 05/08). Only
  `STACKING_CATEGORIES` (currency, ammunition, siege_ammunition, counter_supply, medicine, building) keep the data's
  `stack_max`; every other item is 1 per slot. `legacy_stack_max` keeps the old per-row ceiling for the save sanitizer.
- `game/scripts/items/inventory.gd`:
  - Bag of instances, `BASE_SLOTS = 100` (pack 05). Every non-stacking unit gets a local uid on add (uid only, so the
    server's journal replay stays deterministic).
  - Equipment container: `equip_at(index, slot)` wears the exact instance and takes it out of the bag; the old worn
    item swaps into the freed slot. An item only goes into its own slot. `unequip` is refused when the bag is full.
    Worn gear saves whole under `inventory_extras.worn`; legacy def-id `equipment` migrates by moving the item out.
  - `load_array(raw, overflow)`: the migration (spec 08). Every stacked row becomes one instance per unit with the row's
    level and attributes. What the bag cannot hold goes to `overflow` (home cargo), which grows rather than drop
    anything. Nothing is deleted. The `[inv] migration:` log line names what went to home storage
    (e.g. `285 more instances from split stacks, 80 kept here, 205 to home storage (stone x205); bag 100/100`).
  - `groups()`: visual grouping data (one entry per item id with its slots and units). Nothing merges.
  - `spend_key(stack)`: the one order default picks spend instances in (spec 05:23, below).
  - Best automatic tool: work tool first, then highest `gather_power`.
- `game/tests/t_inventory.gd`: 18 tests (list under Gates).
- `game/scripts/dev/inventory_lab.gd` + scene: a full bag of 100 mixed instances in the real inventory screen. Headless
  it drives the grid (group, open, tap an instance, equip the L30 helm out of its group). With `--shot` it takes the
  bag picture; `--bag-group=<id>` opens a group first.

## Hooks patch (integrator applies; files owned by merged packages)
- `save_game.gd`: player bag `load_array(rows, World.cargo_home)`.
- `save_sanitizer.gd`: counts clamp to `legacy_stack_max` (without this every legacy stack loads as 1, which is data
  loss); `worn` rows are sanitized.
- `player.gd`: `Inventory.new()` (100 slots). `corpse.gd`: `add_growing` (n instances, none dropped).
- `crafting.gd` `_plan`: the lead's own def first (a fibre twine is not eaten as fibre), then the candidates sort by
  `Inventory.spend_key` before the old largest-stack rule (spec 05:23).
- `server/character_state.gd`: `split_stacks(d)` splits a stored character's stacked rows (first unit keeps the
  stack's uid, the k-th more gets `<uid>.<k>`, deterministic on every boot), grows the bag to 100, and puts what does
  not fit in `d.storage` (home storage); `BAG_SLOTS = Inventory.BASE_SLOTS`; worn gear resolves by bag index.
- `server/character_store.gd`: `open()` runs `migrate_stacks()` after reading the snapshot, logs
  `[srv] migration: char <id>: bag .., .. rows split from stacks, .. units to home storage (..)` and snapshots;
  `invariants()` counts home storage.
- `ui/inventory_ui.gd` (W1-UI): grouped bag grid (one cell per item id with a ×N badge; a group opens into one cell
  per instance behind a back cell; Equip wears the exact instance selected); slot icon and caption scale with the slot;
  the back cell uses the white `back` icon (t_uiicons rejects a bare ‹ glyph); the item tip is no longer clipped
  to one line (it showed only "Stone x1...").
- Tests and fixtures that encoded stacking: t_save (helm worn, new `_test_stacked_migration`, new instance goldens
  `save_v3_inst_golden.json`, `save_v3_inst_away_golden.json`; the base's goldens stay as the stacked saves the
  migration loads), t_tame, t_items, t_player, t_build, run_all, multistack_lab, srvdom_checks, craft_lab.

## Vision fix: default picks spare valuable instances (spec 05:23)
Spec 05:23, verbatim: "When crafting, let users explicitly choose exactly which bone is consumed and protect valuable
items from default auto-consumption." Orchestrator ruling: crafting only (option a); autofeed, quick-eat and pet
feeding are out of scope.
- `Inventory.spend_key(s) = [has traits, level, created_at]`, ascending. A trait is an attribute that is neither
  bookkeeping (`PLAIN_ATTRS`: level, climate, processed, material_tier) nor equal to the def's own
  `default_attributes` (stone's default tint is not a trait).
- `Crafting._plan` sorts candidates by it after the existing preferred-id and dual-category rules, so
  `Crafting.default_picks` (the craft card) and the station default load W2-PROCESS reuses through `default_picks`
  take plain, low-level, oldest instances first. Explicit picks are untouched.
- Test `_test_default_pick_spares_valuable`: four fibre stalks (trait L1 at slot 0, plain L5, plain L1 newer, plain L1
  older). On the old order it fails:
  `[t_inventory] FAIL default twine spends the plain oldest stalks 3 then 2, not the trait (0) or lv 5 (1) one (picks [0] spent [0, 1])`.
  The default-attribute check failed on the first version of spend_key:
  `[t_inventory] FAIL a def's own default attributes (stone tint) are not traits ({ "tint": "#8a8a8a", "material_tier": "stone" })`.

## Gates
Fresh scratch tree from 98fea3c0 with the committed hooks patch (mkscratch, imported):
- `--import` (mkscratch) done; all 20 `t_*.gd` exit 0 with their PASS line, 0 SCRIPT ERROR except t_save's 5
  deliberate ones (`[t_save] PASS`), including `[t_inventory] PASS`, `[t_uiicons] PASS ids=169 ...`, `[t_srvdom] PASS`,
  `[t_server_domain] PASS`, `[t_items] PASS`, `[t_tame] PASS`, `[t_build] PASS`, `[t_player] PASS`, `[t_ui] PASS`.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR, 0 FAIL lines: `[invlab] PASS slots=100 groups=20 stone_open=17 equip_l30=true`,
  craft_lab `[craft_lab] PASS` (every check), `[equiplab] PASS`, kitchen_lab `[kitchen_lab] PASS` (every check).
- 0 "couldn't resolve track" in any gate log; no new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (newest is still
  Godot-2026-10-20-131531.ips, from before this run).
- The first gate run (before the UI fix) had `[t_uiicons] FAIL inventory_ui.gd:444 symbol ‹ (U+2039) has no icon
  mapping` from the hooks' back cell; fixed and rerun above.

Every t_inventory test fails on the old code: t_inventory.gd run on base 8718f94f printed 40 FAIL lines, at least one
per test, e.g. `FAIL save_v1.json: every unit survives (want { "stone": 3, "branch": 2, "flint": 2 } total 7, got {  } total 0)`,
`FAIL coins stack in one slot (slots 2)`, `FAIL the bag grows to 100 and fills; the rest is in home storage (bag 18/20, storage 0)`,
`FAIL _test_round_trip_keeps_uids stopped on a SCRIPT ERROR` (old code has no such method), `FAIL default twine spends ...`.

Tests in t_inventory: exact equip by instance, bad amounts, worn gear out of the bag, best tool, no stacking, split
migration, legacy equipment migration, hostile worn rows, identity through transfer, the base's real stacked saves
(save_v1, save_v3_golden, save_v3_away_golden: units per id and in total, one uid per instance), overflow to home
storage with the log line, a 150-unit row bigger than the bag, save/load round trip keeps every uid (and does not
migrate again), worn gear kept, currency and ammo still stack, visual groups merge nothing, server store migration
(every unit, distinct uids, bag 100, rest in storage, invariants hold, logged, next boot unchanged, a migrated unit
leaves by its own uid), default pick spares valuable instances.

## Bag shots (looked at)
`inventory_lab`, a full bag of 100 mixed instances, 1600x900 and 844x390, Forward+ and gl_compatibility, grouped and
with the stone group open (8 PNGs, scratch only, not in the repo):
- 1600x900: 20 cells (18 groups, the ammo stack, the bandage stack) in a 5-wide grid, icons and ×N badges readable;
  open group: back cell and 16 stones with "Lv 1".."Lv 16"; the selected stone's lines read in full under Equipment.
- 844x390: 64 px cells, 5 wide; 3 rows show and the 4th row is under the fold (the panel scrolls, as on base). Badges
  and "Lv N" captions are readable. Both renderers look the same.
- Fixed after looking: the tip was clipped to "Stone x1..." (now full lines); the back cell's ‹ glyph failed t_uiicons
  (now the white back icon).
- Seen, not fixed (not this package): stone and stone_shot share one icon, so the stone group (×16) and the ammo stack
  (×45) look alike (icon set, W1-UIICONS/ICONS2); a group and a real stack both read "×N"; the modal is translucent
  and the HUD's quest text shows through at the top (W1-UI). INVUI (spec 13) replaces this bag screen.

## Assumptions
- `STACKING_CATEGORIES` list (spec 05 only names "currency in a wallet, certain consumables").
- `MAX_LOAD_UNITS = 100000` (a forged save must not allocate without bound).
- `PLAIN_ATTRS` (level, climate, processed, material_tier) are bookkeeping, not traits; there is no per-instance trait
  list in data yet.
- Server home storage is `d.storage` on the character; W3 adds the ops that take items out of it.
- Gathered items have origin "" locally.

## Not done / next
1. Independent review (branch + hooks), then merge in the handoff order (after W2-SKILLS).
2. Pocket and equipment capacity bonuses (spec 05: "Pocket attribute +6 spaces per level"): no item in data grants
   slots yet, so there is nothing to wire; W2-DATA/INVUI.
3. Item-def rarity (item_rarity.json, per id) is not in the spend order; only per-instance traits, level and age are.
4. Building costs (`Inventory.consume`, build_placer) still take the first instances in bag order: not crafting, so out
   of the ruling's scope.
5. Corpse take XP is a flat +3 per take (player_actions.loot); with instances 3 meat pay 9 XP. Its owner should look.
6. `health_bonus_at` / `food_energy_at` should move to ItemStack (W2-PROCESS).
