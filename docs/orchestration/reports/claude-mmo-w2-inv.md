# W2-INV report: inventory and equipment by instance

Branch `claude/mmo-w2-inv`, base claude/mmo-overhaul 34b6d459 (unchanged since 80348edd merged it; checked at the end
of this round). Hooks patch `docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch`: `git apply --check` is clean
on claude/mmo-overhaul 34b6d459 (temporary index of the base) and on the branch.

Owner approval on record (STATUS, 2026-10-20): "the non-stacking inventory save change is approved: merge it once its
independent review passes and old saves migrate cleanly in tests." The first independent review found a blocker
(old saves lost units); it is fixed below, so the package needs its re-review before the merge.

## Review round 1 fixes (2026-10-20)
Every finding, the fix, the check that would have caught it, and that check failing on the reviewed code: the new
t_inventory.gd run in a mkscratch tree of 80b335c1 with that commit's hooks patch (`old_t_inventory.log`).

| # | Severity | Finding | Fix | Check, and its FAIL on 80b335c1 |
|---|---|---|---|---|
| 1 | blocker | `legacy_stack_max` was the items.json stack_max, so the sanitizer cut legal old rows (stone x150 -> 20, fibre_stalk x400 -> 30) | `item_def.gd`: `legacy_stack_max` = the data value only for durability tools and multi-slot items, else 999: the exact pre-W2-INV rule (base item_def.gd:46, owner 2026-09-20) | `_test_legacy_ceiling`: the golden with stone x150 and bandage x40 in the bag and fibre_stalk x400 in home cargo, through `SaveMigrations.read` and the loader. Now `[t_inventory] legacy ceiling stone=169 bandage=40 fibre_stalk=400`. Old: `FAIL old stone rows keep every unit (want 169 got 39)`, `(want 40 got 10)`, `(want 400 got 30)` |
| 2 | major | Duplicate uids survived a load | `InventoryMigration.load_into` keeps a seen-uid set seeded from the overflow container (home cargo loads first); `extras_from_dict` continues it (`Inventory.load_uids` + the bag's uids). The first holder keeps a uid, later ones `remint_uid()` | `_test_duplicate_uids`: `dup uids: instances=5 distinct=5 worn_same=false`. Old: `FAIL dup-uid rows: 5 instances with 5 uids, the first row keeps l00aa11 ({ "l00aa11": 3, ... })`, `FAIL a worn helm with the bag helm's uid gets its own (bag lbb22 worn lbb22)`, `FAIL a bag row repeating a home cargo uid gets its own` |
| 3 | major | Equipment and Pocket capacity bonuses missing (spec 05:11) | `Inventory.capacity()` = `base_slots` + each worn item's `bag_bonus()`: its def's `bag_slots` (new items.json field, default 0) + `attributes.pocket` level x `pocket_slots_per_level` (6, data). Derived from what is worn, so nothing adds twice. `equip_at` grows or shrinks by the swap's difference and undoes a swap that cannot shrink; `unequip` is refused when what the bag holds plus the item would not fit; a shrink moves single items out of the cut tail and never drops one. `extras_from_dict` sizes the bag to its capacity on load | `_test_pocket_capacity` (test defs, as `_test_currency_stacks`): `pocket: 100 -> 112 -> 116, refused full, shrink kept all, reload 116`; a forged Pocket level is capped. Old: `FAIL a Pocket 2 pouch adds 12 slots (100)`, `FAIL a satchel's bag_slots add once, beside the pouch (100)`, `FAIL a full bag refuses the pouch's unequip ...` |
| 4 | minor | The tip dumped the attribute dict (`attr { "tint": ... }`) | hooks `item_stack.gd` `tooltip()`: one line of named traits (`Inventory.traits()`: attributes that are neither bookkeeping nor the def's defaults, the same rule as the spend order); a single instance's title has no "x1" | `_test_tip_names_traits`; inventory_lab checks the stone tip. Old: `FAIL the tip names traits, not the raw dict (Stone x1 \| lv 3  process 0 \| attr { "tint": "#8a8a8a", "material_tier": "stone", "hardness": 2 })` |
| 5 | minor | Stacking categories were a code constant | `game/data/inventory.json` (new, owned here): `stacking_categories`, `pocket_slots_per_level`, `max_pocket_level`; read once by `ItemDef.rules()`. Added to `CharacterStore.DATA_FILES` (hooks), so the server snapshots after the rules change | t_inventory's stacking tests (`no stacking`, `currency stacks`) read it |
| 6 | minor | Storage grid: one 64 px cell per instance, rebuilt per transfer (2000 buttons for a migrated cargo); containers keep their old sizes | Handed to INVUI B3 (its storage/cargo split view replaces this grid: invui-spec.md, InventoryGrid shared by bag, storage and cargo). Container capacity flagged below for W2-BUILDSYS and the integrator. Not changed here: world.gd is integrator-only and BASKET_SLOTS belongs to W2-BUILDSYS | - |
| 7 | minor | A grown home cargo logged a migration on every load | `load_into` first sizes the container to its last saved row, so `_place_extra` and its log run only when a stack really splits | `_test_grown_container_reloads`. Old: `FAIL a 70-row cargo reloads as 70 rows with no migration log (slots 70, new lines 1)` |
| 8 | minor | inventory.gd grew 364 -> 629 lines; `sort()` had no caller | The load and migration (`load_into`, `_place_extra`, `_append`, `_clear_orphan_locks`, `MAX_LOAD_UNITS`) moved to `game/scripts/items/inventory_migration.gd` (`InventoryMigration`, 109 lines). `sort()` is dropped: INVUI's Auto Sort is view-only (invui-spec.md assumption 5, spec 13 "reorganize the presentation"), so nothing would call it. inventory.gd is 599 lines; the rest of the growth is the equipment container and capacity | t_inventory no longer sorts |
| 9 | minor | Dead `equipment.values()` check; a refused unequip was silent | hooks `inventory_ui.gd`: the dead check is gone (quick-food check kept); a refused unequip shows "Bag is full." and the gear stays worn | inventory_lab: `unequip into a full bag: the helm stays worn and 'Bag is full' shows` |
| 10 | minor | The server split stacks before replaying the journal | hooks `character_store.gd`: `migrate_stacks()` runs after the journal replay, then the store snapshots at once | `_test_journal_before_split`: a deposit of 5 from a 20-stack journaled, no clean close, reboot: 15 stone left, one row each, 5 exported, invariants hold. Old: `FAIL the replayed deposit still moved 5; 15 stone are left, one row each (boot '', stone 19, multi 0, exported 1)` |

On the old code `_test_equip_exact_instance` and `_test_legacy_equipment_migration` also stop on a SCRIPT ERROR there
(the test helper now builds the reload at `base_slots`, which 80b335c1 does not have).

Acceptance line "equipping L60 keeps it equipped after a sort and a save/load" (plan-register): worn gear lives in the
equipment container, outside the bag rows, so no bag order can move it; with `sort()` dropped the test checks the
save/load half (`exact equip: worn lv=60 uid_kept=true bag_helm_lv=1`).

## What shipped on the branch (owned files)
- `game/scripts/items/item_def.gd`: materials and food do not stack (owner 2026-10-20, prompts 05/08). Only the
  `stacking_categories` of `data/inventory.json` (currency, ammunition, siege_ammunition, counter_supply, medicine,
  building) keep the data's `stack_max`; every other item is 1 per slot. `legacy_stack_max` is the pre-W2-INV per-row
  ceiling for the save sanitizer (999, or the data value for durability tools and multi-slot items). `bag_slots`.
- `game/data/inventory.json` (new): stacking categories, Pocket slots per level, the Pocket level cap.
- `game/scripts/items/inventory.gd`:
  - Bag of instances, `BASE_SLOTS = 100` (spec 05:11). Every non-stacking unit gets a local uid on add (uid only, so
    the server's journal replay stays deterministic).
  - Equipment container: `equip_at(index, slot)` wears the exact instance and takes it out of the bag; the old worn
    item swaps into the freed slot. An item only goes into its own slot. Worn gear saves whole under
    `inventory_extras.worn`; legacy def-id `equipment` migrates by moving the item out.
  - Capacity (spec 05:11): `capacity()`, `bag_bonus()`, `_resize()` (above).
  - `load_array(raw, overflow)` -> `InventoryMigration.load_into`.
  - `groups()`: visual grouping data (one entry per item id with its slots and units). Nothing merges.
  - `traits(stack)` and `spend_key(stack)`: the one order default picks spend instances in (spec 05:23).
  - Best automatic tool: work tool first, then highest `gather_power`.
- `game/scripts/items/inventory_migration.gd` (new): the migration (spec 08). Every stacked row becomes one instance
  per unit with the row's level and attributes; what the bag cannot hold goes to `overflow` (home cargo), which grows
  rather than drop anything; uids are unique after the load. The `[inv] migration:` line names what went to home
  storage (e.g. `285 more instances from split stacks, 80 kept here, 205 to home storage (stone x205); bag 100/100`).
- `game/tests/t_inventory.gd`: 24 tests (list under Gates).
- `game/scripts/dev/inventory_lab.gd` + scene: a full bag of 100 mixed instances in the real inventory screen. Headless
  it drives the grid (group, open, tap an instance, equip the L30 helm out of its group, unequip into a full bag, the
  stone tip). With `--shot` it takes the bag picture; `--bag-group=<id>` opens a group first.

## Hooks patch (integrator applies; files owned by merged packages)
- `save_game.gd`: player bag `load_array(rows, World.cargo_home)`.
- `save_sanitizer.gd`: counts clamp to `legacy_stack_max` (the old rule's ceiling); `worn` rows are sanitized.
- `player.gd`: `Inventory.new()` (100 slots). `corpse.gd`: `add_growing` (n instances, none dropped).
- `crafting.gd` `_plan`: the lead's own def first, then candidates by `Inventory.spend_key` (spec 05:23).
- `item_stack.gd` (W2-PROCESS) `tooltip()`: named traits instead of the attribute dict; no "x1" on one instance.
- `server/character_state.gd`: `split_stacks(d)` splits a stored character's stacked rows (first unit keeps the
  stack's uid, the k-th more gets `<uid>.<k>`), grows the bag to 100, puts what does not fit in `d.storage`.
- `server/character_store.gd`: `open()` runs `migrate_stacks()` after the journal replay and snapshots; logs
  `[srv] migration: char <id>: ...`; `invariants()` counts home storage; `data/inventory.json` is in `DATA_FILES`.
- `ui/inventory_ui.gd` (W1-UI; INVUI replaces it): grouped bag grid (one cell per item id with a ×N badge; a group opens
  into one cell per instance behind a back cell; Equip wears the exact instance selected); slot icon and caption scale
  with the slot; the tip is not clipped; a refused unequip says "Bag is full."; dead worn-gear check removed.
- Tests and fixtures that encoded stacking: t_save (helm worn, `_test_stacked_migration`, instance goldens
  `save_v3_inst_golden.json`, `save_v3_inst_away_golden.json`), t_tame, t_items, t_player, t_build, run_all,
  multistack_lab, srvdom_checks, craft_lab.

## Vision fix (earlier round): default picks spare valuable instances (spec 05:23)
Spec 05:23: "When crafting, let users explicitly choose exactly which bone is consumed and protect valuable items from
default auto-consumption." Ruling: crafting only. `Inventory.spend_key(s) = [has traits, level, created_at]`
ascending; `Crafting._plan` sorts candidates by it. `_test_default_pick_spares_valuable` (failed on the old order:
`FAIL default twine spends the plain oldest stalks 3 then 2, not the trait (0) or lv 5 (1) one (picks [0] spent [0, 1])`).

## Gates
Fresh mkscratch tree of edc8ba74 with the committed hooks patch (import: 0 "Failed to compile" / SCRIPT ERROR lines),
every run through gslot:
- All 20 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save] PASS`):
  `[t_inventory] PASS`, `[t_save] PASS`, `[t_items] PASS`, `[t_tame] PASS`, `[t_build] PASS`, `[t_player] PASS`,
  `[t_ui] PASS`, `[t_srvdom] PASS`, `[t_server_domain] PASS`, `[t_uiicons] PASS ids=169 ...`, `[t_web] PASS`, and the rest.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, 0 SCRIPT ERROR, 0 FAIL lines: `[invlab] PASS slots=100 groups=20 stone_open=17 equip_l30=true full_unequip_notice=true`,
  `[craft_lab] PASS`, `[equiplab] PASS`, `[kitchen_lab] PASS`.
- 0 "couldn't resolve track" in every gate log.
- Crash reports: `Godot-2026-10-20-201353.ips`, `-201403.ips`, `-201415.ips` appeared during this round (SIGABRT from
  an Objective-C exception, `procRole` Foreground, relaunched every 12 s). Not from this package's runs: every run
  here exited 0 with its PASS line, the last two launched after the first gate run had ended, and the gate runs are
  headless. None appeared during the fresh-tree gates or the shots.
- The same set also passed in the package work tree with the hooks applied (first run).
- New t_inventory lines: `legacy ceiling stone=169 bandage=40 fibre_stalk=400`,
  `dup uids: instances=5 distinct=5 worn_same=false`, `pocket: 100 -> 112 -> 116, refused full, shrink kept all, reload 116`.

t_inventory's 24 tests: exact equip by instance, bad amounts, worn gear out of the bag, best tool, no stacking, split
migration, legacy equipment migration, hostile worn rows, identity through transfer, the base's real stacked saves,
overflow to home storage with the log line, a 150-unit row bigger than the bag, round trip keeps uids, worn gear kept,
currency and ammo still stack, visual groups merge nothing, server store migration, default pick spares valuable
instances, and this round's legacy ceiling, duplicate uids, Pocket capacity, grown container reload, journal before
split, named traits in the tip.

## Bag shots (looked at)
`inventory_lab` on gl_compatibility (the judge), a full bag of 100 mixed instances, 1600x900 and 844x390, grouped and
with the stone group open (4 PNGs in scratch, not in the repo), opened and looked at:
- 1600x900 stone group open: back cell "All" and 16 stones "Lv 1".."Lv 16"; the selected stone's tip reads "Stone" /
  "lv 1  process 0", with no attribute dict (round 0 showed `attr { "tint": "#8a8a8a", "material_tier": "stone" }`).
- 1600x900 grouped: 20 cells, ×N badges and single "Lv 1" cells readable, "Bag 100 / 100" in the profile.
- 844x390: 64 px cells, 5 wide; 3 rows show and the panel scrolls (as on base). Badges and "Lv N" readable.
- Seen, not fixed (not this package; INVUI replaces the screen): stone and stone_shot share one icon; a group and a
  real stack both read "×N"; the translucent modal lets the HUD quest text show through at the top.

## For other packages and the integrator
- **INVUI (B3)**: the storage/cargo grid in inventory_ui.gd still builds one 64 px button per instance and rebuilds it
  after every transfer (reviewer probe: a cargo migrated to 2000 instances, `buttons=2000 rebuild_ms=99` headless).
  The bag grid is grouped; the storage grid is not. INVUI's InventoryGrid (shared by bag, storage, cargo) should
  virtualize or group it. `Inventory.groups()` gives the grouping data.
- **INVUI (capacity indicator)**: `slot_count` now changes with worn equipment (Pocket / `bag_slots`) and `changed`
  is emitted; `capacity()` is the derived value. Equip and unequip can now be refused for capacity (`equip_at` /
  `unequip` return false): show "Bag is full." as inventory_ui.gd does here.
- **W2-BUILDSYS and the integrator (container capacity)**: with one instance per slot, home cargo
  (`World.cargo_home`, 60 slots, world.gd), baskets (`BASKET_SLOTS` 60) and pet bags (10) hold 60 / 60 / 10 items where
  they held as many stacks. Spec 05:14's references: "basket about 100 slots; level-60 Large Leaf Box up to 160; some
  event personal boxes 300; clan storage up to 2,000". Not changed here (integrator-only and W2-BUILDSYS files). The
  migration never deletes: an overfull cargo grows, and a grown cargo now reloads at its saved size.
- **W3 / server**: online characters get no Pocket bonus yet. The server keeps worn gear in its bag by uid (int form),
  which adds nothing to `capacity()`, and `d.bag` stays at 100. When the server moves worn gear into a container, it
  needs `bag_bonus()` and the same refusal rules. Home storage (`d.storage`) has no op that takes from it yet.

## Assumptions
- `stacking_categories` (data): spec 05 only names "currency in a wallet, certain consumables".
- An instance's Pocket is `attributes.pocket` = its level; `max_pocket_level` 60 (the item level cap) bounds a saved
  value. `bag_slots` (items.json, default 0) is the "equipment adds storage slots" part of spec 05:11; no item in
  data sets either yet.
- A shrink that cannot fit the cut tail's items (or has a multi-slot item there) refuses the unequip or swap rather
  than overflow anywhere (spec 05:11 allows either; refusing never moves an item out of the bag).
- `MAX_LOAD_UNITS = 100000` (a forged save must not allocate without bound).
- `PLAIN_ATTRS` (level, climate, processed, material_tier) are bookkeeping, not traits.
- Server home storage is `d.storage` on the character; W3 adds the ops that take items out of it.
- Gathered items have origin "" locally.

## Not done / next
1. Re-review (branch + hooks), then merge in the handoff order (after W2-SKILLS).
2. Item-def rarity (item_rarity.json, per id) is not in the spend order; only per-instance traits, level and age are.
3. Building costs (`Inventory.consume`, build_placer) still take the first instances in bag order (outside the
   crafting-only ruling).
4. Corpse take XP is a flat +3 per take (player_actions.loot); with instances 3 meat pay 9 XP. Its owner should look.
5. `health_bonus_at` / `food_energy_at` should move to ItemStack (W2-PROCESS).
