# Cursor M4b — crafted item level is the mean of materials

Output level is the floor-mean of every consumed unit, then clamped to the recipe skill and `max_level`. Attributes still come only from the primary slot.

## What shipped
- `Crafting.consumed_levels` / `crafted_level_for`: each slot count is one sample per unit; `min` of skill (stub 60) and `recipe.max_level` (default 60).
- Every recipe in `game/data/recipes.json` has `skill` (`weapon_tools`, `tailoring`, `construction`, `processing`) and `max_level`.
- `# ASSUMPTION:` every crafting tree is skill 60 until M8.
- `ItemDef.stats_per_level` scales weapon damage and tool durability as `base * (1 + factor * level)`. Hunt auto-attack uses the equipped stack's scaled damage.
- Craft preview shows output level, the sample list, and each slot's contribution.
- Craft prints `[craft] level=<n> from [<levels>]`.

## Lab
`craft_lab` two-unit mean (prompt numbers: blade + handle):

```
[craft] level=15 from [25, 5]
[craft] level=32 from [25, 40]
```

The live `improvised_stone_knife` recipe also consumes lashing, so a craft of lv25 stone + lv5 branch + lv1 twine is level 10. That is the three-sample mean, not a conflict with the two-unit check.

`tools/smoke.sh`: SMOKE PASS.

## Next
M5 island terrain. Do not change this save schema.
