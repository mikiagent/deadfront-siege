# W2-GATHER landed on the integration line (claude/mmo-w2gather2)

Base: `claude/mmo-overhaul` b08ed1f8. Source: `claude/mmo-w2-gather` (review round 4 head).

## What landed
- `git merge claude/mmo-w2-gather` (71c9c6dc): no conflicts. The branch only adds files: `game/scripts/gather/`
  (GatherService, LootRoller, LootTables, ButcherLoot, GatherFeedback), `game/data/loot_tables.json`,
  `game/data/gather_rules.json`, `game/tests/t_gather.gd`, `--lab=gather_lab`, and its report and hooks patch.
- The hooks patch (`docs/orchestration/reports/claude-mmo-w2-gather-hooks.patch`, now historical), applied by hand in 300cb3bf:
  - `player_actions.gd`: gather seconds and yield come from `GatherService.unit_seconds` / `yield_multiplier`;
    `GatherService.after_unit` runs after each unit (helper-tool wear, 5% green trait per item on the instance
    that landed, climate finds, "+n Item" stack). Applied clean.
  - `intent_handlers.gd` (server `act.gather`): same yield rule, wear, traits, finds; the result carries `rares` and `traits`. Applied clean.
  - `inventory.gd`: `wear_tool(s)` split out of `wear_gather_tool`. Applied clean.
  - `hunt_hud.gd`: tinted rare notices (`notice(text, tint)`, `tick_notices` in `_process`, `notice_box` /
    `notice_punch` / `notice_colors` in `_draw`). The `_process` hunk did not apply on its own (canon added the pulse
    clock there); `git apply --3way` merged it with no conflict.
  - `corpse.gd`: `_roll_loot` calls `ButcherLoot.roll_into` (rewritten, see below).
- 1257bf9c: a base carcass part never scales to 0, plus docs (`docs/current/world-biomes.md` and its generator).

## Conflicts and how they were resolved
No textual conflicts. These were semantic:
1. **corpse.gd `_roll_loot`.** Canon (SKILLBUY) added `Data.butcher_row_open`: a Butchering skill node opens each part.
   The patch would have dropped that gate. `LootRoller.roll_carcass` now checks `Data.butcher_row_open` per row, so
   canon's node gates still apply, with W2-GATHER's knife/skill count scaling and rare-row chance on top.
2. **Knife part gates dropped (W2-GATHER piece obsolete).** `loot_tables.json` `part_min_tier` (dense_bone needs bone;
   armor_scute and venom_gland need flint) was, in W2-GATHER's own words, a stand-in "until W2-BUTCHER lands those
   nodes". Canon's trees.json now gates all three by Butchering nodes. Keeping both would be two gates for one
   rule, so the knife gates are gone.
3. **Two gather-time rules.** Canon had `HarvestNode.seconds_for` / `work_tool` (best pick on rock, else the class
   tool; only t_items calls it). It now delegates to `GatherService.unit_seconds_for`, and `work_tool` is deleted.
   `GatherService.tool_for` now takes the best pick on every rock first, including rocks that need a pick, as
   canon's `work_tool` did. The patch had used `find_gather_tool(&"pick")` there.
4. **Canon's every-kill guarantee.** run_all's "poison corpse keeps counter materials" failed: W2-GATHER's no-knife
   0.75x can floor a 1-2 count base part to 0. Base parts now keep at least 1 (ASSUMPTION below). The root cause is
   fixed; the assert is unchanged.
5. **W2-INV / GATHERGLIDE / multi-resource trees / BIOMEDRESS / CRAFTFEEL / FOODFX.** No conflicts.
   - W2-INV: W2-GATHER round 4 had already moved to instances (`inv.uids()`, a trait goes on the landed instance).
   - Multi-resource trees and GATHERGLIDE: `finish_gather` still uses the selected option's `stack.def_id`.
   - CRAFTFEEL and FOODFX: these use their own toasts, separate from the gather yield stack.

## Tests changed (with reasons)
In `t_gather.gd`, the asserts on the dropped knife gates were replaced with asserts on the canon node gate:
- Data: "no knife part gates left beside the Butchering node gates" replaces the check that `part_min_tier` names valid tiers.
- Carcass math: "a stone knife cannot cut scutes/dense bone", "a flint knife cuts them" and the misspelt-gate check
  are replaced by "a stone knife takes hide and bone". Without a local survivor, every part is open.
- Live hook: a flint knife without the nodes cuts 0 scutes and 0 dense bone. With the nodes learned it cuts them:
  `nodes learned: { raw_meat: 2201, armor_scute: 192, dense_bone: 303 }`. Without them: `armor_scute: 0, dense_bone: 0`.
- The talon setup (`_unlock_butchering`) also learns the talon's Butchering node. Before this, canon's node gate
  kept the talon off, and 5 live talon checks failed.

## Dropped, and why
- `part_min_tier` knife gates: canon's Butchering nodes do this now (item 2 above).
- The **GatherXp hook**: W2-GATHER removed it in its own review round 4. No doc pays XP for a rare result, and
  W2-SKILLS paces XP. The base +2 Gathering / +3 Butchering is the whole award, and t_gather asserts that.
- `tools/labs.txt` registration: the file still does not exist. `--lab=gather_lab` runs through main.gd's scene lookup.

## Gate results (this tree, head after 1257bf9c)
- Import: `--import` rc=0, 0 SCRIPT ERROR / Failed to compile.
- All 61 `game/tests/t_*.gd` files ran through gslot. Every one exited rc=0 with 0 SCRIPT ERROR, except:
  - t_save: its 5 deliberate SCRIPT ERRORs, `[t_save] PASS`.
  - **t_uiicons: rc=1 on base too.** `[t_uiicons] FAIL status caffeinated has an icon` and more: FOODFX statuses
    with no icon. I ran it on a temporary b08ed1f8 worktree (since removed), and the FAIL lines were identical.
    This is not caused by this package.
- Quoted PASS lines:
  - `[t_gather] PASS`, `[t_inventory] PASS`, `[t_items] PASS`, `[t_data] PASS items=240 recipes=165`
  - `[t_craftfeel] PASS`, `[t_bags] PASS`, `[t_save] PASS`, `[t_player] PASS`, `[t_water] PASS`
  - `[t_w2_skills] PASS`, `[t_skillfeel] PASS ...`, `[t_gatherglide] PASS`
  - t_mounts prints `PASS t_mounts`, rc=0.
  - After the last code change I re-ran t_gather, run_all and every test that mentions corpse or butcher.
- `game/tests/run_all.gd`: `[tests] PASS` (rc=0). It prints 3 compile-time SCRIPT ERRORs, starting with
  `Identifier not found: TouchControls` (hunt_hud.gd:90 compiled before the autoloads exist). The b08ed1f8 base
  prints the same 3.
- `bash tools/smoke.sh --no-import` through gslot (alarm 900): `SMOKE PASS`.
- `--lab=gather_lab` headless: `[gather_lab] PASS`. I did not run it windowed: the owner reserved the machine,
  so no windowed labs.

## Assumptions (new in this landing)
- `# ASSUMPTION` in `loot_roller.gd`: a base carcass part keeps at least 1 unit after knife/skill scaling.
- W2-GATHER's own numbers are unchanged; they are listed in `claude-mmo-w2-gather.md`:
  - 1.35x bare hands
  - 0.75x no knife
  - +15% per knife tier and +1% per Butchering level
  - 0.12 rare part chance
  - find odds
  - 5% trait (from the docs)

## Risks for review
- **Balance shift on carcasses:** rare rows (e.g. raptor_talon) no longer always drop. They roll 0.12 + 15% per
  knife tier (about 17% in tests). Base counts now depend on the knife. Both are W2-GATHER's own numbers, but players
  will notice them.
- **Gather time:** every node with no required tool is now 1.35x slower bare-handed, and the role's tool helps (axe
  on trees, knife on bushes). The radial's time hex (GATHERGLIDE) should read `GatherService.unit_seconds`, if
  it shows times.
- **Untracked import artefacts:** `--import` turns `game/data_sheets/*.csv` into `*.translation` / `.csv.import`
  files. They are left untracked. Canon should add `game/data_sheets/.gdignore`, or mark the CSVs keep-only.
  Neither is done here.
- Still open from W2-GATHER's next-agent list:
  - ECON: `limits.json` `attributes` must whitelist the six trait keys.
  - W3: server nodes need `climate` in their attributes before finds roll online.
  - The rare-trait chance on butcher parts.
