# claude-recipetools: P2 RECIPETOOLS + P4 TRAITGEAR

Branch `claude/mmo-recipetools`, cut from `origin/claude/mmo-overhaul` (fc08395e), canon 6afe7d9e (P1 WEAR + P3
GEARREPAIR) merged in. Not merged to canon. Design: `docs/design/tools-durability-crafting.md` (packages P2, P4).
No Meshy or Tripo credits spent.

## P2 RECIPETOOLS (commit cb28c9d1)

- `recipes.json requires_tool` is `{"class", "min_tier"}` (optional `min_level` read, unused). The old string form
  (`"hoe"`) reads as that class at stone tier. `Crafting.tool_need / recipe_tool / tool_block / wear_recipe_tool`.
- Only a **work** tool (`is_work_tool`) in the bag slots counts: never a Stone Dagger or barbed knife, never the
  worn weapon slot. Best qualifying tool by gather power (same order as `_best_tool`).
- Every craft path enforces and wears it, 1 per run, success or failure:
  `Crafting.run_plan` (survivor craft, server `act.craft`, tribe order) returns status `tool` and spends nothing
  without it; `ProcessStation.refuse_reason` / `load_from` (the workbench runs Trimmed and Fine Plank itself) refuse
  and wear on load; `Crafting.progression_block` returns the reason.
- UI: craft list row and detail say "Needs work axe (flint)" / "Needs hoe (stone)" instead of "Locked"; CraftPlace's
  result card shows "Uses Work Axe (1 durability)" or the red reason, and the Craft button reads the reason, disabled.
- Tribe ASSIGN (`TribeWork.craft_offer`) checks the **member's** held tool (its weapon slot), not the survivor's bag;
  `_finish_craft` wears that tool.

**Recipes with tool gates (TD5):**

| recipe | tool |
|---|---|
| pillar, plank, plank_shape, pillar_shape, trimmed_plank | work axe, stone+ |
| fine_plank | work axe, flint+ |
| hide_strap | work knife, stone+ |
| field_small, field_large | hoe, stone+ (existing rows, now enforced) |

Everything else stays ungated (dried_hide, cooking, forge and anvil: TD7). No other cut-hide recipe exists, so the
knife gate is hide_strap only.

Ladder proof: `t_recipetools` walks recipes breadth-first from an empty bag (a made work tool counts at the tier its
id names, conservative) and reaches knife/axe/pick at steel and hoe at stone; no deadlock. `t_data`'s
start-island reachability walk now reads the object form and requires a work tool of the tier.

## P4 TRAITGEAR (commit b9042683)

- `rules.json crafting.gear_traits` (# ASSUMPTION): high_density +3 %/lv max durability, low_density -3 %, firm +2 %
  damage, soft -2 %, tough_fiber +2 % armour, soft_fiber -2 %, high_elasticity +2 % gather power; cap +-15 % per stat.
- New crafts only: `Crafting.build_output` stamps gear with `attributes.trait_stats = true`; unstamped (old) gear
  reads multiplier 1.0 and its stored max is never recalculated.
- `ItemStack.trait_effects()` / `trait_mult(stat)` feed `apply_level_stats`, `scaled_damage`, `scaled_armor`,
  `gather_power`; gather speed (`GatherService.unit_seconds_for`, `HarvestNode` pick timing) divides by it.
- Item card (`ItemInspectPanel.rows_for`): "+9 % durability (High Density 3)", ", capped" when the clamp bites.
- Vault: `economy/limits.json` whitelists `trait_stats` (bool); the validator's max-durability cap already
  recomputes through `ItemStack.make`, so a trait-raised max passes and nothing higher does.
- With P3: repair multiplies the stored (trait-adjusted) max by 0.8; `t_traitgear` checks a High Density axe repairs
  from its own max and keeps the stored value on load.

## Tests

Gates, after the canon merge: see the head commit message / the coordinator hand-off for the final run.
Before the merge: t_recipetools, t_traitgear, t_data, t_uicraft, t_craftradial, t_tribework, t_rareattr,
t_knifesplit, t_tutorial (bot finishes; own HOME, TEST_TIMEOUT 1200), t_tutguide, t_buildflow, t_craftfeel, t_bagui,
t_econ, t_uimarket PASS; `run_all.gd` [tests] PASS; `smoke.sh --no-import` SMOKE PASS.
Full `all_tests.sh` (161): 148 pass. The failures also fail on clean canon fc08395e (checked in a baseline worktree):
t_eatqueue, t_foodcat, t_hudredraw, t_invscreens, t_movepriority, t_player, t_skillbuy, t_uiicons, t_tactical,
t_uichar. t_uigather failed once under load and passes alone. t_econ/t_uimarket failed on `trait_stats` before the
limits.json fix and pass after.

Existing tests changed: t_buildflow and t_craftradial carry a work axe for plank/trim crafts; t_data's tool checks.

## Not done / for the next agent

- No craft-screen shot of a tool-blocked row at 844x390: `ui_screens_lab` only captures the closed list and
  crashed after it (rc 70) in this run. Needs a lab that opens the craft panel with planks and no axe.
- `docs/current/recipes.md` got its tool column by an in-place edit; `gen_game_data.py` has the column too, but a
  full regeneration rewrites hand-written sections and is blocked by unsynced sheets (items.csv, recipes.csv) on
  canon, so it was not run.
- Daily "trim 3 planks" stays reachable: the tutorial makes a work axe before it.
- Roadmap rows `recipe-tool-gates` and `trait-gear-stats` stay `next` with a "built on claude/mmo-recipetools" note.
