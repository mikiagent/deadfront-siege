# Durango: Wild Lands — Claude implementation prompt bundle

Seven independent Markdown prompts covering the systems we discussed, arranged for sequential use:

1. **01_fatigue_and_exhaustion.md** — stamina vs energy vs fatigue, environment, rest.
2. **02_dinosaur_taming_and_companions.md** — capture-to-pen, feeding, bonding, companion roles.
3. **03_leveling_progression_skill_trees.md** — level 60, 12 categories, SP, research and skill resets.
4. **04_loot_material_processing_crafting.md** — unique ingredients, perks, processing, crafting ability and quality.
5. **05_inventory_stacking_storage.md** — nonstacking item instances, capacity, boxes, dinosaur cargo.
6. **06_island_market_player_economy.md** — selling exact inventory items, listings, escrow, fees and purchases.
7. **07_combat_and_animal_capture.md** — semi-auto combat, stances, telegraphs, timed defense and net captures.

## How to pass these to Claude
Upload the relevant individual file(s), plus your existing game project context. Ask Claude to inspect existing code first and implement each system incrementally. Files **02 and 07 overlap intentionally in capture**, and explicitly require **one shared capture implementation**. Start with core architecture and persist item identity consistently across 02, 04, 05, and 06.

These files are newly consolidated, implementation-ready versions of the prompts from this conversation, not byte-for-byte exports of the previously displayed writing blocks. Values marked illustrative or community-reconstructed are not guaranteed original game server parameters.
