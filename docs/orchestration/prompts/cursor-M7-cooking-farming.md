# Cursor milestone M7 — cooking, food, and farming

Food restores Energy, never Health (PRD §1.4, §6.1). Cooking is the deepest combo system in the game and the reason a cook can reach the level cap. Do this after M5 and M6.

## Read first
- `docs/prd/durango-wild-lands-systems-prd.md` §6.2 (energy, fullness, moving-while-eating gotcha), §9.3 (cooking path, sashimi-steam-steam, boiling upranks), §9.4 (farming), §9.5, §21 items 3 (food inspector)
- `docs/design/skills.md` (Cooking and Farming trees), `game/data/skills/trees.json`
- `docs/design/world-design.md` §3 (item level, mean-of-materials) and the M4b rule
- `game/data/world/climates.json` for which plants grow where

## Tasks

1. **Food model.** Food items get `energy`, `process_count`, `buffs[]`, `raw` and `poisoned` flags, `level`. Eating: over 3 s, restores `energy × level_factor`; **moving cancels the rest and still applies Full** (PRD §6.2 MUST show in UI: a progress ring and a "keep still" hint). `Full` blocks eating for 10 s. Raw meat, fish and mushrooms can apply `stomachache` (PRD §6.4 table) or a fatigue "tastes bad".

2. **Cooking as processing steps** (data in `game/data/recipes.json`, station-gated): skewer at the bonfire (Cooking 1, output level capped at 19), meatball via mortar then cook (10), stone-plate grill (20, burnt on fail = energy crash), steam (25, adds a process step; steaming a steamed dish stacks), sashimi (40: 1 meat → 3 sashimi, process count forced to 2), boil (40: output level moves toward the water item's level, the uprank trick), roast and seasoned roast (45). Every step increments `process_count`; energy = base × (1 + 0.35 × process_count) *(design)*. Poison persists through cooking (PRD MAY keep).

3. **Food inspector**: tapping any food shows energy, level, process count, buffs, raw/poisoned, before eating (PRD §21 item 3).

4. **Buff food**: recipes with a herb or spice secondary slot grant a timed stat buff (gathering speed, defense, cold or heat resistance) listed in `game/data/food_buffs.json` (create it).

5. **Farming**: hoe + mud → field (small at Farming 1, large at 25) on the home island only for now. Plant seeds (flax, corn, wheat from the nature manifest crops; berries). Water amount raises success chance, fertilizer raises yield with overflow carried to the next plant, output level capped by Farming skill (PRD §9.4). Simple well at Construction 25 fills buckets. Growth is real-time with offline catch-up like tent rest. Saved in the M6 schema (add a versioned field).

6. **Pet feed**: carnivore feed from meat (meatballs are efficient, PRD §11.3), herbivore feed from fruit and stalks; feeding a pet drains hunger by energy × 10.

7. **Lab** `--lab=kitchen_lab`: bonfire, mortar, grill, steamer, a field, seeds, raw meat and fish, high-level water bucket. Debug keys to fast-forward growth.

## Acceptance
- Sashimi-steam-steam produces the highest energy per raw meat in the lab, as in Durango; skewer never exceeds level 19.
- Boiling a level-20 meat in level-40 water yields about level 30.
- Moving while eating cancels the remaining restore and still applies Full, with the UI warning visible.
- A field planted with flax at Farming 5 grows, waters, fertilises, harvests with overflow, and survives save/load.
- Smoke passes; report `docs/orchestration/reports/cursor-M7-cooking-farming.md`; commit as `M7: cooking, food, farming`.
