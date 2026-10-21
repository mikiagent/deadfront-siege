# W2-INV report: inventory and equipment by instance

Branch `claude/mmo-w2-inv`, base claude/mmo-overhaul ac33159f, merged at 93ab120a this round (six base commits since
cecc936b, all docs: specs 13 addendum and 15-18, STATUS, workflow scripts, references; nothing under game/ and none of
the hook files, so the round 3 gates of 79a24337 below stand). Hooks patch
`docs/orchestration/reports/claude-mmo-w2-inv-hooks.patch`, regenerated this round from the work tree (byte-identical
to its hook-file diff): `git apply --check --cached` is clean on claude/mmo-overhaul ac33159f and on the branch 93ab120a
(temporary indexes of each). The spec 13 storage addendum (Bag | Small Box tabs, Transfer to Bag) is INVUI B3's.

Owner approval on record (STATUS, 2026-10-20): "the non-stacking inventory save change is approved: merge it once its
independent review passes and old saves migrate cleanly in tests." Review rounds 1, 2 and 3 are fixed below; the
package needs its re-review before the merge.

## Sync 1 before integration (2026-10-20)
Base claude/mmo-overhaul 29ffa292 (W2-DATA and W2-SKILLS merged, specs 19-22, STATUS) merged into the branch at
4810b5da with no conflicts. The hooks patch no longer applied there (`error: patch failed: game/tests/t_items.gd:184`,
`game/tests/t_save.gd:1`); it was 3-way applied in a scratch tree, resolved, and regenerated (2583c2d3, a7b49780).
`git apply --check` is clean on claude/mmo-overhaul 29ffa292 and on the branch a7b49780. Branch code is unchanged;
only hook files changed:
- t_items `_test_pick_gates`: W2-DATA made iron need a bronze pick, so the "best pick is the one in use" check uses
  bronze (base) with W2-INV's `equipped_gather_tool()` (the branch's auto pick).
- t_save: W2-SKILLS froze the stacked v3 goldens as rev-1 inputs and checks that their skills_v2 migrates to
  save_v3_skills_rev2.json. The stacked goldens keep that skills check (`_check_v3_skills`, the base's
  `_check_v3_golden` without the "everything else unchanged" compare, because their stacks split on load) next to
  W2-INV's `_check_split`. `_test_rev1_skills` runs as on base. The header names both migrations.
- The instance goldens (save_v3_inst_golden.json, save_v3_inst_away_golden.json) were written before W2-SKILLS
  and still had rev-1 skills. Their round trip failed only on skills_v2
  (`FAIL v3 golden survives load + save unchanged: ["/skills_v2/trees/butchering/unlocked: array size", ...]`).
  `--write-golden` on the merged tree re-rolls pet genetics and every uid, so only its rev-2 skills_v2 block was
  taken into each old golden. Everything else is byte for byte. save_v3_golden.json, save_v3_away_golden.json and
  save_truncated.json have the same md5 before and after.
- W2-DATA's 59 new items needed no change. Tin, moss and cactus flower are materials (one per slot). Tools, nets
  III-V and armour are one per slot. forge/anvil kits (building) and antivenom/antibiotic (medicine) fall in the
  existing stacking categories.

Gates: a fresh mkscratch tree of a7b49780 with the hooks patch (import: 0 "Failed to compile" / SCRIPT ERROR / Parse
Error lines). Every run went through gslot; the logs are in scratch `w2inv-sync/logs/gates`.
- All 22 `t_*.gd` exit 0 with their PASS line. 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save] PASS`).
  Lines: `[t_data] PASS items=223 recipes=155`, `[t_w2_skills] PASS`, `[t_inventory] PASS`, `[t_items] PASS`,
  `[t_player] PASS`, `[t_tame] PASS`, `[t_build] PASS`, `[t_srvdom] PASS`, `[t_server_domain] PASS`, `[t_ui] PASS`,
  `[t_uiicons] PASS ids=171 files=114 ...`, `[t_web] PASS`, `[t_ai] PASS`, `[t_canim] PASS`, `[t_combat] PASS`,
  `[t_harbour] PASS islands=15`, `[t_iconart] PASS`, `[t_light] PASS` (t_light, t_lighting), `[t_occlude] PASS`,
  `[t_structart] PASS`.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs exit 0 with 0 SCRIPT ERROR: `[invlab] PASS empty_cells=100/97 slots=100 groups=20 stone_open=17 equip_l30=true
  full_unequip_notice=true`, `[craft_lab] PASS`, `[equiplab] PASS`, `[kitchen_lab] PASS`. Windowed
  `ui_real_capture_lab` at 844x390 on gl_compatibility: `[uireal] PASS screens=hud,craft,...,bag,charcreate,...`,
  0 SCRIPT ERROR.
- 0 "couldn't resolve track" in every log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (34 before and
  after; the newest is still 2026-10-20-202004).
- Shots opened and looked at (gl_compatibility; in scratch `w2inv-sync/shots`, not in the repo):
  - inventory_lab full bag at 1600x900 and 844x390: as in round 3. Group pills 16..2 with "Lv 1-16" style ranges,
    "×45" and "×6" stacks with no pill, single tools "Lv 1", "Bag 100 / 100".
  - ui_real_capture_lab bag at 844x390: the empty bag grid, "Bag 0 / 100".

## Review round 3 fixes (2026-10-20)
Each finding, the fix, the check that would have caught it, and that check run against the reviewed code (064ae99b
with its hooks patch, a mkscratch tree with the new test files copied in: `old_*.log` in scratch `w2inv-r3/`) or
against a mutation of the new code (`w2inv-r3/mut/`, run in the work tree and reverted; `cmp` confirmed the restore).

| # | Severity | Finding | Fix | Check, and its FAIL |
|---|---|---|---|---|
| 1 | blocker | `_plan` ordered by recipe `prefer_id`, then category overlaps, then `spend_key`: a plain dual-category unit always lost to a rare dedicated one (straw roll spent 3 lv40 trait stalks with 4 plain reeds in the bag; slingshot spent the rare dense bone) | hooks `crafting.gd`: `_plan` plans value first. Sort key per candidate, computed once: `prefer_id`, then `Inventory.spend_key` (the one ordering function), then the overlap count as a tie-break, then larger stack, then bag order. A unit that a later recipe slot still needs is left for it (`_spare_for_later`: take only while every later slot keeps enough candidates, so a cheap reed spent as fibre does not leave the lashing short). When a slot still runs short, `_plan` falls back to the dedicated-first plan (the order before W2-INV). The plan's lead is the first unit it really takes | t_inventory `_test_default_pick_value_before_overlap`. On the reviewed code: `FAIL straw roll spends the 4 plain reeds, not the lv40 trait stalks (spent [0, 1, 2, 3])`, `FAIL slingshot spends a plain raptor bone and the branch, not the dense bone (spent [0, 3, 4, 5])`, `FAIL the slingshot default spends no trait`, `FAIL 3 reeds and a frond: the third reed stays for the lashing, no trait stalk goes (spent [0, 1, 2, 5])`, `FAIL when value first runs a slot short, the dedicated-first plan still crafts (spent [])`. Mutations of the new code: no reservation `FAIL 3 reeds and a frond: ... (spent [0, 1, 2, 5])`; no fallback `FAIL when value first runs a slot short, the dedicated-first plan still crafts (spent [])`; overlap first (the reviewed order) the same four FAIL lines as the reviewed code |
| 2 | major | The hooks flipped the only full-bag refusal assertion (t_items) and rewrote craft_lab's refusal and make-room wait to the success case; `output_fits -> true` passed both | hooks `t_items.gd` `_test_no_lost_items`: the knife still crafts in a full bag (its inputs free a slot), and a full bag with one raw meat refuses sashimi (3 instances from 1 meat) with the bag untouched, still refuses with one slot freed, crafts with two. hooks `craft_lab.gd`: `_full_bag_craft` adds a sashimi craft at the bonfire with a full bag (refused, inputs unchanged, "Bag is full" notice); `_finish_waits_for_room` keeps the skewer that lands in its freed slot and adds a finished sashimi that waits ("make room to finish the Sashimi"), still waits after one freed slot and finishes with 3 after two. The vacuous "finishes once a slot frees up" check is gone | Mutation `return scratch.can_accept(out)` -> `return true`: `outfits_true t_items exit=1 fails=2` (`FAIL a full bag refuses sashimi (3 out, 1 slot freed) before consuming`, `FAIL one free slot is still one short for sashimi`), `outfits_true lab:craft_lab exit=1` (`FAIL full bag: a 3-instance craft is refused, inputs unchanged`, `FAIL full bag: refusal notice shown`, `FAIL a finished sashimi with a full bag waits, the meat untouched`, `FAIL the wait tells the player to make room`, `FAIL one freed slot is not enough: it still waits`). The reviewed code's `output_fits` is right, so these checks pass there (exit 0): the finding was the missing test, and the mutation is its proof |
| 3 | minor | The "same def as the lead" tie-break was untested; candidates sorted twice | The order matters, so the tie-break stays and is tested. A first try dropped it, and the fresh-tree gates caught a regression: `[t_srvdom] FAIL craft capture_net_i failed: insufficient_items missing twine` (the second twine, crafted from a picked stalk, spent the first twine, which tied with the other stalk and sat earlier in the bag). Now one sort: each key is computed once, the unpicked lead is the least valuable unit left (one scan), and "same def as the lead" sits after value and overlaps, before stack size and bag order | t_inventory: `a twine from a picked stalk spends the other stalk, not the tied twine`. Mutation (tie-break removed): `[t_inventory] FAIL a twine from a picked stalk spends the other stalk, not the tied twine (spent [1, 0])` and `[t_srvdom] FAIL craft capture_net_i failed: insufficient_items missing twine`. The reviewed code had the tie-break, so this check passes there |
| 4 | minor | `load_worn` silently dropped a saved worn row whose def no longer maps to that slot (spec 05:11 never delete) | `InventoryEquipment.load_worn`: a worn row that names a real item (a known def) but cannot be worn in its saved slot, or names a slot that no longer exists, goes to the bag after the capacity resize, through `add_growing` (a full bag grows rather than drop it), and logs `[inv] load: worn <id> L<n> cannot be worn there any more; moved to the bag`. It still loads as one unit at a reachable level with a uid of its own. A row that is not an item row (a string) or names no item of this build (an unknown id, the slot lock marker) is skipped | t_inventory `_test_hostile_worn`. On the reviewed code: `FAIL the stone (body) and the helms (legs, tail) are in the bag (stone 0 helm 0 used 0)`, `FAIL a full bag grows for an unwearable worn helm rather than drop it, and says so (helm 0, 0 log lines)` |
| 5 | minor | Storage/cargo grid: one Button per instance; a migrated heavy legacy cargo is 15,303 buttons | Not changed here (the storage grid is INVUI B3's, container capacity W2-BUILDSYS's). The gate line stays in the plan-register section and below for STATUS: "W2-INV: before players with large old saves update, W2-BUILDSYS raises container capacities (spec 05:14) and INVUI virtualizes the storage/cargo grid (one button per instance today)." | - |
| 6 | minor | The group badge "16 …" read as truncated text; stone and stone_shot share one icon | hooks `inventory_ui.gd`: a group cell has a corner count badge (a pill in the top-right corner, as in ARK and Durango; plain digits, so no new glyph) and its caption is the level range of its instances ("Lv 1-16", or "Lv 5" when they share a level); a real stack reads "×45" with no badge; a single instance "Lv N". Pooled buttons hide the badge for every other cell. The shared icon is not changed: `icons_manifest.json` aliases stone_shot to the stone icon (W1-UIICONS/iconart data, not this package's); the ×45 caption and the missing badge now tell the stack from the group | inventory_lab: `the stone group has a 16 badge, its level range and no stack ×N`, `the stone_shot stack shows ×45 and no group badge`. On the reviewed code: `[invlab] FAIL the stone group has a 16 badge, its level range and no stack ×N (badge '', caption '16 …')`. Shots looked at (below) |
| 7 | major | Acceptance: spec 05:23 ruling, default pick and default station load take the least valuable instance first, one ordering function | Met by #1. The station load (`StationCraft._finish_one`) and the server's `act.craft` take `Crafting.default_picks`, the same plan. Evidence, the reviewer's two probes on the new code: `[probe] straw_roll: picks [3, 6] spent ["reed lv1", "reed lv1", "reed lv1", "reed lv1"] spends_traits=false`; `[probe] slingshot: picks [1, 3, 4] spent ["raptor_bone lv1", "branch lv1", "twine lv1", "twine lv1"] spends_traits=false` | as #1 |
| 8 | major | Acceptance: the neighbouring loss guard (sec-loss-08 full-bag refusal) still tested after the hooks | Met by #2: `outfits_true t_items exit=1 fails=2`, `outfits_true lab:craft_lab exit=1` | as #2 |

Notes on #1:
- `prefer_id` stays ahead of value (the finding asked for prefer as a tie-break too). It is set by two recipes and
  names the recipe's own input, not a cheaper choice: `cook_meatball` (`input_id` meatball_mix in the meat category)
  and the well fill (`input_id` empty_bucket in the bucket category). Below value, a plain raw meat would be cooked into
  a meatball, and a lv1 water bucket picked to be filled over a higher-level empty one.
- The fallback case also fails on the reviewed code for a second reason, fixed here: its lead was the first sorted
  candidate even when an earlier slot had spent it, so default picks named a spent unit and were invalid. Probe on
  the reviewed code: `[probe] tri default_picks=[2, 1, 1] valid=false`; new code: `[probe] tri default_picks=[2, 1, 0]
  valid=true`.
- Not done: refusing a default that `plan_spends_traits` flags. With value first a trait instance goes only when no
  plain plan exists (every candidate carries one); refusing would block those crafts until INVUI's picker lands.
  Still handed to INVUI (below).

## Review round 2 fixes (2026-10-20)
Each finding, the fix, the check that would have caught it, and that check failing on the reviewed code (c7e1b323 with
its hooks patch applied, the work tree before any fix: `old_*.log` in scratch). Mutations were run in the work tree and
reverted.

| # | Severity | Finding | Fix | Check, and its FAIL on the reviewed code |
|---|---|---|---|---|
| 1 | blocker | The grouped bag built no cells for free slots: an empty bag showed a blank area | hooks `inventory_ui.gd` `_bag_cells`: after the item cells, one empty cell per free slot (`slot_count - used_slots()`), only in the whole-bag view; empty cells are disabled (no taps) and keep the slot look (a `disabled` stylebox = the slot style) | inventory_lab `_check_empty_cells`: an empty bag and a 3-item bag in the real screen. Now `[invlab] PASS empty_cells=100/97 ...`. Old: `FAIL 0 items: 0 item cells and 100 empty slot cells (0 shown, 0 empty)`, `FAIL 3 items: 3 item cells and 97 empty slot cells (3 shown, 0 empty)`. Looked at: `ui_real_capture_lab` bag_844x390 (empty bag: the BAG column is a grid of empty slots, "Bag 0 / 100") and inventory_lab `--bag-fill=30` at 844x390 and 1600x900 (3 group cells, then empty slots) |
| 2 | major | `_plan` put every unit of the lead's def ahead of all other candidates, whatever their value (spec 05:23) | hooks `crafting.gd` `_plan`: one comparator for the lead and the rest: recipe `prefer_id`, category overlaps, then `Inventory.spend_key`; "same def as the lead" is only a tie-break inside equal keys. The lead is chosen first, then the rest re-sort with the tie-break. `spend_key` stays the one ordering function | t_inventory `_test_default_pick_across_defs`: stalk lv1, stalk lv40 (with `{hardness:9}`, then plain), plain palm frond lv1; the default twine spends slots [0, 2]. Old: `FAIL default twine spends stalk lv1 and the plain frond lv1, not the lv40 stalk { "hardness": 9 } (spent [0, 1])` |
| 3 | major | The forged `inventory_extras.worn` row had no test; the sanitizer branch is its only durability guard | No code change: the sanitizer branch stays. New test through the loader's own path | t_inventory `_test_forged_worn_row`: `save_forged.json` with a worn raid_helm x5000 L9999, durability and max_durability 1e9, uid "not a uid", through `SaveMigrations.read` and the loader: x1, L60, durability <= 2288. Mutation `var row: Variant = worn[slot]`: `FAIL a forged worn helm loads as x1 L60 with durability <= 2288 ({ ... "durability": 1000000000, "max_durability": 1000000000, ... })` |
| 4 | minor | A default that can only spend trait instances spends them without a word (spec 13:486) | `Crafting.plan_spends_traits(inv, rec, picks)` (hooks): true when the plan spends an instance with traits. Handed to INVUI: its picker should require an explicit pick when this is true (craft_ui is not this package's) | `_test_default_pick_across_defs`: false for the cases above, true for two trait stalks. Old: `SCRIPT ERROR: Invalid call. Nonexistent function 'plan_spends_traits'` -> `FAIL _test_default_pick_across_defs stopped on a SCRIPT ERROR` |
| 5 | minor | "Then oldest" works only for crafted items; def rarity ignored | Documented as `# ASSUMPTION` on `Inventory.spend_key` (below). A minted sequence was not added: a wall-clock stamp breaks the server replay, and a per-process counter would not survive save/load without a new save field. Rarity is not used: item_rarity.json is a placeholder for UI rims (its own `_assumption`) and is not in the server's `DATA_FILES` | - |
| 6 | minor | Duplicate uids across containers that load on their own (building contents, pet bags) survived a load | `InventoryMigration.unique_uids(invs)` (branch): one seen set across the given containers, worn gear included; the first holder keeps a uid, later ones are reminted; a container listed twice (the cargo basket's storage is `World.cargo_home`) is walked once. Hooks `save_game.gd` `_apply` calls it after the pets load over home cargo, the bag, the live island's building storages (not the old island's, still queued for deletion) and pet bags, and logs `[inv] load: N duplicate uids reminted` | t_save `_test_duplicate_uids_across_containers` (bag, basket and pet bag rows of the instance golden share one uid, through `SaveGame.load_now` and a re-save). Old: `FAIL a uid shared by bag, basket and pet bag rows loads as distinct instances, the bag keeps it (dup 2, bag keeps true)`. t_inventory `_test_unique_uids_across_containers` (unit). Old: SCRIPT ERROR (no `unique_uids`) |
| 7 | minor | Corpse take XP: +3 per take; with one instance per unit a 26-instance corpse paid up to 78 | Hooks `corpse.gd`: Butchering XP is 3 per drop kind, the first time any of it leaves the loot (`first_take_of(def_id)`; the chest screen compares units per kind before and after a take). `player_actions.gd` `loot` (radial) asks the same. Item takes and Take all now pay the same; per kind is what taking each stacked row paid before W2-INV | t_player `_test_corpse_take_xp`: 3 meat + 2 hide taken by radial per item, chest per item and Take all pay 6 each. Old: `FAIL radial takes, chest takes and Take all each pay 3 per drop kind (paid [15.0, -5.0, 3.0])` (the -5 was xp_of across a level-up; the test now sums XP across levels) |
| 8 | minor | One instance per slot: home cargo and baskets hold 60 items; a heavy legacy save grows home cargo to 22,125 slots | Not changed here (world.gd is integrator-only, `BASKET_SLOTS` is W2-BUILDSYS's, the storage grid is INVUI B3's). Recorded under "For other packages" and in the plan-register section. STATUS is not this package's file: the integrator should add the line given there | - |
| 9 | minor | inventory.gd grew 364 -> 599 lines | Equip, unequip, bag bonus, capacity, resize and the worn-gear load moved to `game/scripts/items/inventory_equipment.gd` (`InventoryEquipment`, 127 lines, static functions like InventoryMigration). Inventory keeps one-line `equip_at`, `unequip`, `capacity` so no caller changes. inventory.gd is 497 lines (the rest of the growth: uids, groups, traits, spend order) | t_inventory's equip, Pocket and worn tests, equip_mount_lab, inventory_lab |
| 10 | minor | `can_accept` had no game caller | Hooks `crafting.gd` `output_fits` now asks `scratch.can_accept(out)` on the scratch bag after the inputs left (it was `scratch.add(out) == 0`, the same answer). That is the one place an output is placed after a consume; station finish goes through `output_fits` too, and a corpse take consumes nothing | craft_lab (full-bag refusal), t_items |
| 11 | minor | A group and a real stack both read "×N"; a group hid L/U pips; nothing showed a group opens | Hooks `inventory_ui.gd`: a group reads "16 …" (… is listed as plain typography in ui_icons.json; "16 ›" failed t_uiicons, `inventory_ui.gd:473 symbol › (U+203A) has no icon mapping`), a stack keeps "×45", a single instance "Lv N"; `_pips()` adds "L " / "U " when any instance in the group is locked / unstable | inventory_lab: `the stone group shows 16 and no stack ×N`, `the stone_shot stack shows ×45`, `a group holding a locked stone carries the L pip`. Old: `FAIL the stone group shows 16 and no stack ×N (got '×16')`, `FAIL a group holding a locked stone carries the L pip (got '×16')` |
| 12 | minor | `split_stacks` gave uid-less rows ".1", ".2" each | Hooks `character_state.gd`: a row without a uid is not split (it stays as stored, nothing deleted); `invariants()` already flags it | t_inventory `_test_split_rows_without_uid`. Old: `FAIL rows without a uid split into no duplicate uids and keep every unit (dup 2, units 6, uids ["", ".1", ".2"])` |
| 13 | minor | A journal written under the stacking rules can fail to replay and stop boot with only "seq N did not replay" | Hooks `character_store.gd` `open()`: when replay fails and the data files changed since the snapshot (`data/inventory.json` is new in `DATA_FILES`, so every pre-W2-INV snapshot reads as changed), the error adds "the data files changed since the snapshot: boot the previous build once so it snapshots, then upgrade". Operators: snapshot (clean `close()`) on the old build before upgrading | t_inventory `_test_journal_rules_change` (an old-build snapshot whose slot 0 differs from what the journaled deposit saw). Old: `FAIL a journal that fails under changed rules says to snapshot on the previous build (seq 3 did not replay (bag slot 0 is empty))` |
| 14 | major | Acceptance: spec 05:23 default pick, one ordering function, a test that fails on the old order | Met by #2: `_plan` orders every unit by `Inventory.spend_key`; the cross-def test failed on the old order (line above) and passes now: `[t_inventory] PASS` in the fresh tree | as #2 |

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
  - Equipment container: `equipment` holds worn gear out of the bag; `equip_at`, `unequip`, `capacity` delegate to
    InventoryEquipment (below). `worn(slot)`, `equipped_in(slot)`. Worn gear saves whole under
    `inventory_extras.worn`.
  - `load_array(raw, overflow)` -> `InventoryMigration.load_into`.
  - `groups()`: visual grouping data (one entry per item id with its slots and units). Nothing merges.
  - `traits(stack)` and `spend_key(stack)`: the one order default picks spend instances in (spec 05:23).
  - Best automatic tool: work tool first, then highest `gather_power`.
- `game/scripts/items/inventory_equipment.gd` (new, review 2): `equip_at(inv, index, slot)` wears the exact instance
  and takes it out of the bag; the old worn item swaps into the freed slot; an item only goes into its own slot.
  `unequip` (refused when the bag could not hold it), `bag_bonus`, `capacity`, `resize` (spec 05:11), `load_worn`
  (the saved worn rows, or the legacy def-id `equipment` form, which moves the item out of the bag; review 3: a real
  item that can no longer be worn in its saved slot goes to the bag, logged, never dropped).
- `game/scripts/items/inventory_migration.gd` (new): the migration (spec 08). Every stacked row becomes one instance
  per unit with the row's level and attributes; what the bag cannot hold goes to `overflow` (home cargo), which grows
  rather than drop anything; uids are unique after the load. The `[inv] migration:` line names what went to home
  storage (e.g. `285 more instances from split stacks, 80 kept here, 205 to home storage (stone x205); bag 100/100`).
  `unique_uids(invs)` (review 2): one holder per uid across containers that load on their own.
- `game/tests/t_inventory.gd`: 30 tests (list under Gates).
- `game/scripts/dev/inventory_lab.gd` + scene: a full bag of 100 mixed instances in the real inventory screen. Headless
  it drives the grid (group, open, tap an instance, equip the L30 helm out of its group, unequip into a full bag, the
  stone tip, the group count badge and level range against the ×45 stack, the L pip on a group, empty slot cells for
  an empty and a 3-item bag). With
  `--shot` it takes the bag picture; `--bag-group=<id>` opens a group first; `--bag-fill=N` keeps the first N instances.

## Hooks patch (integrator applies; files owned by merged packages)
- `save_game.gd`: player bag `load_array(rows, World.cargo_home)`; after the pets load, `InventoryMigration.unique_uids`
  over home cargo, the bag (worn gear included), the live island's building storages and pet bags.
- `save_sanitizer.gd`: counts clamp to `legacy_stack_max` (the old rule's ceiling); `worn` rows are sanitized.
- `player.gd`: `Inventory.new()` (100 slots). `corpse.gd`: `add_growing` (n instances, none dropped); Butchering XP
  3 per drop kind on its first take (`first_take_of`), chest screen and radial (`player_actions.gd` `loot`) alike.
- `crafting.gd` `_plan` (review 3): value first, one sort per slot: recipe `prefer_id`, `Inventory.spend_key`, category
  overlaps, the lead's def, stack size, bag order; a unit a later slot needs is left for it (`_spare_for_later`); when
  a slot runs short, the dedicated-first plan (`_plan_ordered(..., false)`, the order before W2-INV) is the fallback;
  the lead is the first unit taken (spec 05:23). `plan_spends_traits()`. `output_fits` asks `can_accept`.
- `item_stack.gd` (W2-PROCESS) `tooltip()`: named traits instead of the attribute dict; no "x1" on one instance.
- `server/character_state.gd`: `split_stacks(d)` splits a stored character's stacked rows (first unit keeps the
  stack's uid, the k-th more gets `<uid>.<k>`), grows the bag to 100, puts what does not fit in `d.storage`. A row
  without a uid is left as stored.
- `server/character_store.gd`: `open()` runs `migrate_stacks()` after the journal replay and snapshots; logs
  `[srv] migration: char <id>: ...`; `invariants()` counts home storage; `data/inventory.json` is in `DATA_FILES`; a
  replay that fails after the data files changed says to snapshot on the previous build first.
- `ui/inventory_ui.gd` (W1-UI; INVUI replaces it): grouped bag grid (one cell per item id: a group has a corner count
  badge and its level range "Lv 1-16" (review 3), a stack "×45", one instance "Lv N", with L/U pips for any
  locked/unstable instance; a group opens into one cell per instance
  behind a back cell; Equip wears the exact instance selected); one empty cell per free slot (disabled, slot look); slot icon and caption scale
  with the slot; the tip is not clipped; a refused unequip says "Bag is full."; dead worn-gear check removed.
- Tests and fixtures that encoded stacking: t_save (helm worn, `_test_stacked_migration`, instance goldens
  `save_v3_inst_golden.json`, `save_v3_inst_away_golden.json`), t_tame, t_items, t_player, t_build, run_all,
  multistack_lab, srvdom_checks, craft_lab. Review 2: t_save `_test_duplicate_uids_across_containers`, t_player
  `_test_corpse_take_xp`. Review 3: t_items `_test_no_lost_items` and craft_lab `_full_bag_craft` /
  `_finish_waits_for_room` test the full-bag refusal and the make-room wait again (sashimi: 3 instances from 1 meat).

## Vision fix (earlier round): default picks spare valuable instances (spec 05:23)
Spec 05:23: "When crafting, let users explicitly choose exactly which bone is consumed and protect valuable items from
default auto-consumption." Ruling: crafting only. `Inventory.spend_key(s) = [has traits, level, created_at]`
ascending; `Crafting._plan` orders every unit it spends by it, ahead of the category-overlap key since review 3 (round
3 #1), with the lead's own def only a tie-break (round 2 #2, round 3 #3). `_test_default_pick_spares_valuable` (failed on the old order:
`FAIL default twine spends the plain oldest stalks 3 then 2, not the trait (0) or lv 5 (1) one (picks [0] spent [0, 1])`).

## Gates
Round 3: fresh mkscratch tree of 79a24337 with the committed hooks patch (`mk exit=0`, import: 0 "Failed to compile" /
SCRIPT ERROR / Parse Error lines), every run through gslot (`w2inv-r3/gates2/` in scratch):
- All 20 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save] PASS`):
  `[t_inventory] PASS`, `[t_save] PASS`, `[t_player] PASS`, `[t_items] PASS`, `[t_tame] PASS`, `[t_build] PASS`,
  `[t_ui] PASS`, `[t_uiicons] PASS ids=169 files=114 glyphs=47 ...`, `[t_srvdom] PASS`, `[t_server_domain] PASS`,
  `[t_web] PASS`, `[t_ai] PASS`, `[t_canim] PASS`, `[t_combat] PASS`, `[t_harbour] PASS islands=15`, `[t_iconart] PASS`,
  `[t_light] PASS` (t_light, t_lighting), `[t_occlude] PASS`, `[t_structart] PASS`.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, exit 0, 0 SCRIPT ERROR: `[invlab] PASS empty_cells=100/97 slots=100 groups=20 stone_open=17 equip_l30=true
  full_unequip_notice=true`, `[craft_lab] PASS`, `[equiplab] PASS`, `[kitchen_lab] PASS`; windowed
  `ui_real_capture_lab` 844x390 gl_compatibility in the same tree: `[uireal] PASS screens=hud,craft,...,bag,...`, 0
  SCRIPT ERROR (bag and craft shots opened: the empty bag grid and the craft screen as in round 2).
- 0 "couldn't resolve track" in every gate log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (listing before
  the gate runs and after the UI capture compared: identical, newest 2026-10-20-202004 from before this round).
- An earlier round 3 gate run (tree of a99225da) failed `[t_srvdom] FAIL craft capture_net_i failed: insufficient_items
  missing twine` and the same in t_server_domain: the dropped lead-def tie-break (round 3 #3). Fixed in 79a24337;
  everything above is the rerun.

Round 3 mutation and old-code runs: the FAIL lines quoted in the round 3 table (`w2inv-r3/old_t_inventory.log`,
`old_inventory_lab.log`, `mut/*.log`, `mut/summary.txt`).

Round 2: fresh mkscratch tree of a2e9756b with the committed hooks patch (import: 0 "Failed to compile" / SCRIPT ERROR
lines), every run through gslot (`gates2/` in scratch):
- All 20 `t_*.gd` exit 0 with their PASS line and 0 SCRIPT ERROR, except t_save's 5 deliberate ones (`[t_save] PASS`):
  `[t_inventory] PASS`, `[t_save] PASS`, `[t_player] PASS`, `[t_items] PASS`, `[t_tame] PASS`, `[t_build] PASS`,
  `[t_ui] PASS`, `[t_uiicons] PASS ids=169 files=114 glyphs=47 ...`, `[t_srvdom] PASS`, `[t_server_domain] PASS`,
  `[t_web] PASS`, `[t_ai] PASS`, `[t_canim] PASS`, `[t_combat] PASS`, `[t_harbour] PASS islands=15`, `[t_iconart] PASS`,
  `[t_light] PASS` (t_light, t_lighting), `[t_occlude] PASS`, `[t_structart] PASS`.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`.
- Labs, exit 0, 0 SCRIPT ERROR: `[invlab] PASS empty_cells=100/97 slots=100 groups=20 stone_open=17 equip_l30=true
  full_unequip_notice=true`, `[craft_lab] PASS`, `[equiplab] PASS`, `[kitchen_lab] PASS`; windowed
  `ui_real_capture_lab` 844x390 gl_compatibility: `[uireal] PASS screens=hud,craft,...,bag,charcreate,...`.
- 0 "couldn't resolve track" in every gate log. No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` during the gate
  runs or the UI capture run (listing before and after compared).
- An earlier gate run of 9fa3e63e failed one gate: `[t_uiicons] FAIL inventory_ui.gd:473 symbol › (U+203A) has no icon
  mapping` (the first group badge "16 ›"). Fixed in a2e9756b ("16 …"); everything above is the rerun.

Round 2 mutation and old-code runs: the FAIL lines quoted in the round 2 table (`old_t_inventory.log`, `old_t_save.log`,
`old_t_player.log`, `old_invlab.log`, `mut_worn.log`).

t_inventory's 30 tests: exact equip by instance, bad amounts, worn gear out of the bag, best tool, no stacking, split
migration, legacy equipment migration, hostile worn rows, identity through transfer, the base's real stacked saves,
overflow to home storage with the log line, a 150-unit row bigger than the bag, round trip keeps uids, worn gear kept,
currency and ammo still stack, visual groups merge nothing, server store migration, default pick spares valuable
instances, round 1's legacy ceiling, duplicate uids, Pocket capacity, grown container reload, journal before split,
named traits in the tip, and round 2's default pick across defs (with `plan_spends_traits`), forged worn row, server
split of uid-less rows, journal under changed rules, unique uids across containers, and round 3's value before
overlap (straw roll, slingshot, the reserved reed, the dedicated-first fallback, the lead-def tie-break; the hostile
worn test now checks unwearable rows land in the bag).

## Bag shots (looked at)
Round 3, gl_compatibility, inventory_lab, PNGs in scratch `w2inv-r3/shots` (not in the repo), each opened and looked at:
- Full bag 1600x900: 20 cells. Each group has a white-rimmed dark pill in its top-right corner with the count (16, 12,
  10 ... 2) and its level range as the caption ("Lv 1-16", "Lv 1-23", "Lv 1-30" for the helms); stone_shot and bandage
  read "×45" and "×6" with no pill; single tools "Lv 1". The count no longer reads as truncated text.
- Full bag 844x390: the same pills, readable at 64 px; on the phone the pill covers the right edge of the item icon
  (the berry bowl, the meat), as corner counts do in ARK.
- `--bag-fill=30` 844x390: three group cells with pills 16, 12, 2, then empty slots.
- `--bag-group=stone` 844x390: back cell "All", stones "Lv 1".."Lv 14" in view, no pills on single instances.
- Still seen, not this package's: stone and stone_shot share the stone icon (icons_manifest alias); the translucent
  modal lets the HUD quest text show through at the top.

Round 2, gl_compatibility (the judge), PNGs in scratch (`w2inv-r2/shots`, `w2inv-r2/uireal`), not in the repo, each
opened and looked at:
- `ui_real_capture_lab` 844x390 bag (the reviewer's after_uireal case, an empty bag): the BAG column is a grid of empty
  slot compartments with "Bag 0 / 100" beside it, as the base showed its 20 (`[uireal] PASS screens=...,bag,...`).
- inventory_lab `--bag-fill=30`, 844x390: three group cells "16 …", "12 …", "2 …", then empty slots; 1600x900: the same
  three and 12 more empty slots in view, the column scrolls.
- inventory_lab full bag (100/100), 1600x900: 20 cells; groups read "16 …".."2 …", the stone_shot and bandage stacks
  "×45" and "×6", single tools "Lv 1": a group and a stack no longer look alike. No empty cells (the bag is full).
- inventory_lab full bag 844x390, and the stone group open (back cell "All", stones "Lv 1".."Lv 14" in view, the first
  selected): readable at 64 px.
- Seen, not fixed (not this package; INVUI replaces the screen): stone and stone_shot share one icon; the translucent
  modal lets the HUD quest text show through at the top; at 1600x900 a mostly empty 100-slot bag is a long scroll.

## For other packages and the integrator
- **INVUI (B3)**: the storage/cargo grid in inventory_ui.gd still builds one 64 px button per instance and rebuilds it
  after every transfer (reviewer probe: a cargo migrated to 2000 instances, `buttons=2000 rebuild_ms=99` headless).
  The bag grid is grouped; the storage grid is not. INVUI's InventoryGrid (shared by bag, storage, cargo) should
  virtualize or group it. `Inventory.groups()` gives the grouping data.
- **INVUI / iconart (review 3)**: `icons_manifest.json` aliases stone_shot to the stone icon, so the ammo stack and the
  stone group share a picture (the badge and "×45" tell them apart now); a stone_shot icon of its own is an iconart job.
- **INVUI (craft picker, spec 13:486)**: `Crafting.plan_spends_traits(inv, rec, picks)` is true when the default (or
  given) picks spend an instance with traits; the picker should then ask for an explicit pick instead of crafting on
  the default. Not wired here (craft_ui.gd is not this package's).
- **INVUI (bag grid)**: the round 2 grid shows one empty cell per free slot; with 100 slots and 134 px desktop cells a
  mostly empty bag is a long scroll at 1600x900. INVUI's InventoryGrid can size cells or virtualize.
- **INVUI (capacity indicator)**: `slot_count` now changes with worn equipment (Pocket / `bag_slots`) and `changed`
  is emitted; `capacity()` is the derived value. Equip and unequip can now be refused for capacity (`equip_at` /
  `unequip` return false): show "Bag is full." as inventory_ui.gd does here.
- **W2-BUILDSYS and the integrator (container capacity)**: with one instance per slot, home cargo
  (`World.cargo_home`, 60 slots, world.gd), baskets (`BASKET_SLOTS` 60) and pet bags (10) hold 60 / 60 / 10 items where
  they held as many stacks. Spec 05:14's references: "basket about 100 slots; level-60 Large Leaf Box up to 160; some
  event personal boxes 300; clan storage up to 2,000". Not changed here (integrator-only and W2-BUILDSYS files). The
  migration never deletes: an overfull cargo grows, and a grown cargo now reloads at its saved size. Reviewer probe: a
  legal heavy legacy save migrates into a home cargo of 22,125 slots and a 4.5 MB save. **Line for STATUS (integrator,
  STATUS is not this package's file):** "W2-INV: before players with large old saves update, W2-BUILDSYS raises
  container capacities (spec 05:14) and INVUI virtualizes the storage/cargo grid (one button per instance today)."
- **Server operators (W3)**: snapshot on the old build (a clean `close()`) before upgrading to W2-INV. A journal
  written while items stacked can fail to replay under the new rules; boot then stops with "... the data files
  changed since the snapshot: boot the previous build once so it snapshots, then upgrade".
- **W3 / server**: online characters get no Pocket bonus yet. The server keeps worn gear in its bag by uid (int form),
  which adds nothing to `capacity()`, and `d.bag` stays at 100. When the server moves worn gear into a container, it
  needs `bag_bonus()` and the same refusal rules. Home storage (`d.storage`) has no op that takes from it yet.

## Assumptions
- Review 3: a group cell's caption is the level range of its instances; its count is the corner badge.
- Review 3: `prefer_id` (a recipe's own input) ranks ahead of value; a saved worn row naming no item of this build (an
  unknown id, the slot lock marker) is skipped on load, as before (it is not an item; known items are never dropped).
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
- Butchering XP: 3 per drop kind, the first time any of it leaves a corpse (round 2). Taking each item, or each
  stacked row before W2-INV, pays the same as before; Take all now pays 3 per kind where it paid 3 once.
- `plan_spends_traits` counts traits only; a higher level alone does not ask for a pick.
- Spend order age: only crafted items carry `created_at`, so gathered, looted and migrated units tie at 0 and fall
  back to bag order, and a crafted unit sorts after a gathered one of the same level (a wall-clock stamp would break
  the server replay). Item-def rarity is not a key (item_rarity.json is a UI placeholder, not in `DATA_FILES`).
- A server row without a uid is not split by the migration (it stays as stored; `invariants()` flags it).
- The post-load uid pass covers the live island's buildings; the other island's building rows load on travel and are
  not checked against the bag then (only edited saves can hold such duplicates).

## Not done / next
1. Re-review (branch + hooks), then merge in the handoff order (after W2-SKILLS).
2. Item-def rarity (item_rarity.json, per id) is not in the spend order; only per-instance traits, level and age are
   (assumption above).
3. Building costs (`Inventory.consume`, build_placer) still take the first instances in bag order (outside the
   crafting-only ruling).
4. `health_bonus_at` / `food_energy_at` should move to ItemStack (W2-PROCESS).
5. INVUI: wire `plan_spends_traits` into the craft picker; size or virtualize the bag and storage grids.
