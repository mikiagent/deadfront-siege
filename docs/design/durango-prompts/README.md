# Durango: Wild Lands — Claude implementation prompt bundle

Eleven independent Markdown prompts covering the systems we discussed, arranged for sequential use:

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

## Added guides
- `08_cooking_food_traits_and_individual_ingredients.md`: Complete cooking system, exact berry identities, nonstacking, food processing, recipe inheritance, buffs and eating.
- `09_capture_threshold_and_bonded_pet_limits.md`: Capture at ~50% HP when stunned, 30%-or-stun rule clarification, original-style 3-to-7 bonded pet capacity and Animal Handling skill unlocks.

- `10_construction_building_quality.md`: Construction, housing, quality traits, station performance and durability.
- `11_processing_skill_material_transformations.md`: Processing progression, recipes, individual material enhancement, tanning, metalwork, alloys and delegated jobs.

- `12_remaining_skill_trees.md` — Remaining/undercovered skill trees: Gathering, Butchering, Farming, Tailoring, Weapon/Tool, Ranged, Defense, Survival, Toxic Oil Islands.
