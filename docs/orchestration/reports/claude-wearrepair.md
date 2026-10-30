# Report: WEARREPAIR (P1 WEAR + P3 GEARREPAIR from the tools doc), Claude

Branch `claude/mmo-wearrepair`, cut from `origin/claude/mmo-overhaul` (fc08395e). Pushed, not merged.
No credits spent. Design source: `docs/design/tools-durability-crafting.md` sections 3.1, 3.5, 3.7 and 4.

## Try it
- Wear: gather on a high-level island with a level-1 tool and watch it lose about 2 per pass; a matching
  tool loses 1. Fight a raptor in armor: each hit that lands takes 1 from one worn piece.
- Repair: carry a worn stone-tier tool and a stone or two, tap your workbench, tap **REPAIR** (top-left
  hex), tap the row. The bag's item card shows "Repair at Workbench: 2 Stone material" and
  "max 50 -> 40 (repair 1 of 4)" under Maintenance.

## P1 WEAR (commit 1fb52c4b)
- `Inventory.wear_tool(s, resource_level, spare_last)`: base 1 (work tool) or 3 (weapon used as a tool)
  x `clamp(1 + 0.04 x (resource level - tool level), 0.5, 2.5)`, a fraction rounded stochastically with
  `GatherService.rng`. Numbers in `rules.json gathering.wear`. Callers: player gather (wear now runs after
  the lot roll so it can use the lot's downranked level), server gather intent, helper tools
  (`GatherService.wear_role_tool`), the three corpse butcher paths and `PlayerActions.loot` (carcass
  level), tribe harvests. A caller without a level wears flat (old behaviour).
- Armor: `Inventory.wear_armor_piece` after a damaging creature hit (`CreatureAttack._deal_damage` for the
  survivor, `TribeMember.take_creature_hit` for members): 1 (`combat_tuning.json armor_wear_per_hit`) on
  one worn, unbroken piece, weighted by armor value, `CombatTuning.rng`. Dodges and misses wear nothing.
- Tribe: a worker never takes its tool below 1. At 1 the tool leaves the work set (`_sync_tools`), the
  job finds no node and idles, and the Tribe screen's "Now:" line reads "Chop job · tool worn: 1
  durability left, repair or swap it". KNIFESPLIT unchanged (the Work Knife takes no combat wear).

## P3 GEARREPAIR (commit ef2b98de)
- `GearRepair` (new, `game/scripts/items/gear_repair.gd`) reuses the unread `recipes.json repairs` table
  unchanged: tier -> station + material category + `restore_fraction` 0.5. Cost
  `ceil(missing / (0.5 x max))` units (broken 2, half-worn 1). New `recipes.json repair_rules`
  `{max_factor 0.8, max_repairs 4}`. Refusals: full item, wrong station ("repair at the workbench"),
  missing material ("needs 2 Stone material"), fifth repair ("worn out: repaired 4 times").
- UI: REPAIR hex on the station menu (`StationCraft.repair_actions`, slot 5) when the survivor carries or
  wears worn gear of that station's tiers; it opens `RepairPicker` (subclass of `TribeAssignPicker`, so
  no edits to that file). Item card Maintenance rows (`GearRepair.lines`), market row type line
  "· repaired n/4". The doc put the button on the inspect panel; the task asked for the station radial,
  so the card shows the line and the station does the repair.
- Shots (off-screen, scratch script): picker and item card at 1600x900 and 844x390 checked by eye; the
  card's line was clipped at 1600 as one row, so it is now two rows.

## Save change (flag)
- New key `attributes.repairs` (int) on repaired items only, plus the item's already-saved
  `max_durability` now going down. No new top-level fields. Old saves load unchanged and read 0 repairs.
  The sanitizer already clamps max to a fresh stack's max, which a repaired item is always under.
- `game/data/economy/limits.json attributes.repairs` (int 0-4) so the vault and market accept repaired
  gear; a forged count is refused.

## Tests
- New: `t_toolwear.gd`, `t_gearrepair.gd`.
- Passed on ef2b98de: t_toolwear, t_gearrepair, t_knifesplit, t_gather, t_combat, t_tribe, t_tribework,
  t_items, t_save, t_tutorial (own HOME, TEST_TIMEOUT 1200), t_bagui, t_data, t_econ, t_uimarket,
  t_craftradial, t_stationstate; `run_all.gd` "[tests] PASS"; `tools/smoke.sh --no-import` SMOKE PASS.
- Full `tools/all_tests.sh` on ef2b98de: 149 of 161 pass. The 12 failures (t_claimfix, t_eatqueue, t_foodcat,
  t_hudredraw, t_invscreens, t_movepriority, t_player, t_skillbuy, t_tactical, t_uigather, t_uiicons,
  t_uichar) fail the same way on canon fc08395e (checked in a throwaway worktree), so none is from this branch.
- Example of those: `t_invscreens` expects "Stone Knife" in the worn-weapon label but
  KNIFESPLIT renamed it "Stone Dagger".

## Assumptions (all marked in code or data)
- 0.04 per level, clamp 0.5-2.5, stochastic rounding; armor 1 per damaging hit, one piece, weighted.
- 0.8 per repair, 4 repairs, restore_fraction 0.5 from the existing table.
- Doc slip: its test line "a level-30 knife on a level-26 lot averages 0.5" contradicts its own formula
  (1 - 0.04 x 4 = 0.84). `t_toolwear` tests 0.84 at level 30 and the 0.5 floor at level 40.
- Repair is applied locally like the other offline verbs; `PlayerActions.online` has no repair intent yet
  (shortcut: add an `act.repair` intent when W3-SRVACT wires the socket).

## For the next agent
- P2/P4 (claude/mmo-recipetools) touch `recipes.json` rows and `rules.json crafting`; this branch adds
  `recipes.json repair_rules` near the top and `rules.json gathering` near `gathering_downrank`, so a
  merge should be textual only. P4 should land before or with P3 so repair works from the
  trait-adjusted max (GearRepair reads whatever max the item holds, so no code change needed).
- `tools/docs_wiki/gen_game_data.py` refused to write on canon (items.csv / recipes.csv differ); the
  recipes.md repair paragraph was hand-edited to match the generator's new text.
