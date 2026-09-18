# Cursor follow-up M4b — crafted item level is the average of the materials

Owner correction to M4, now in `docs/prd/durango-wild-lands-systems-prd.md` §8.4 and §9.1. Small change; do it before M6 touches recipes.

1. In `scripts/items/crafting.gd`, replace `out.level = primary.level` with: the mean of the levels of every consumed stack (each unit counted, so a slot taking 3 units contributes 3 samples), rounded down, then `min(level, skill_level_for(recipe), recipe.max_level)`. Add `max_level` to `recipes.json` entries (default 60) and a `skill` field naming the tree that governs each recipe (weapon_tools, tailoring, construction, cooking, processing). Skill levels come from the survival.json stub for now (`# ASSUMPTION:` every tree is level 60 until M8 gives real skills).
2. Level drives stats: `ItemDef` gets a `stats_per_level` factor per relevant stat (weapon damage, tool durability, armor value, food energy) applied as `base * (1 + factor * level)`. Show the level on the craft preview next to the attributes, and show each slot's contribution to the average when the player picks materials.
3. Attributes still inherit from the primary slot only. Nothing else in M4 changes.
4. Lab check: craft the stone knife with a level-25 stone blade and a level-5 branch, expect level 15; with a level-40 branch, expect 32. Print `[craft] level=<n> from [<levels>]`.
5. Commit as `M4b: item level = mean of materials`, report in `docs/orchestration/reports/cursor-M4b-item-level.md`.
