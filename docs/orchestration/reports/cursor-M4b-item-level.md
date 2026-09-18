# Cursor M4b — crafted item level is the mean of materials

## What shipped
- Confirmed M4b baseline is present in-tree:
  - `game/scripts/items/crafting.gd` computes crafted level as floor-mean of consumed units, then clamps with skill and `recipe.max_level`.
  - `game/data/recipes.json` carries `skill` and `max_level` on every recipe.
  - `game/scripts/ui/craft_ui.gd` shows level sample contributions in preview and pickers.
  - `game/scripts/items/item_def.gd` and `game/scripts/items/item_stack.gd` apply `stats_per_level` scaling and expose scaled values.
  - `game/scripts/combat/hunt.gd` uses scaled weapon damage from the equipped stack.
- Completed in this pass:
  - `game/data/items.json`: aligned durability scaling keys with runtime (`max_durability`), and added a `food_energy` + `stats_per_level.food_energy` example on `raptor_meat`.
  - `game/scripts/dev/craft_lab.gd`: added explicit level-check craft cases for the prompt targets.

## Acceptance checks run
- Craft lab (`-- --lab=craft_lab`) output includes:
  - `[craft] level=15 from [25, 5, 15]`
  - `[craft] level=32 from [25, 40, 31]`
- Smoke test:
  - `tools/smoke.sh` -> `SMOKE PASS`

## What failed
- Nothing failed in this milestone pass.

## Credits spent
- Meshy credits: 0 (no Meshy calls in M4b).

## Next agent notes
- M8 should replace the skill-level stub in `Crafting.skill_level_for` with real levels from skill tree runtime/state.
- If recipe-level caps diverge by content tier, update `max_level` values in `recipes.json`; clamp logic is already in place.
