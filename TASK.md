# TASK: fill the building data rows in game/data/structures.json

## Why
DEADFRONT (Godot 4.7.1 game in `game/`) is getting ARK-style modular building: foundations, walls,
doorways, doors, windows, ceilings, roofs, roof ridges, pillars, stairs and ramps in four tiers
(thatch, wood, stone, metal). Every number the game uses comes from `game/data/structures.json`.
The designer (Claude) set the formulas and the table below; you type the rows. Only two pieces
(foundation, wall) have tier rows today. `./verify_structures.sh` is the spec and is read-only.

## The one file you edit: `game/data/structures.json`
Change ONLY two top-level keys: `piece_tiers` and `placed_kinds`. Every other key stays exactly as it is.
Write the file the way it is written now: `json.dumps(data, indent=2, ensure_ascii=False)` (Python),
key order kept. The easiest safe way is a short Python script that loads the file, fills the two
keys and dumps it back; do not hand-edit 600 lines.

### 1. `piece_tiers`
Keys: every key of `pieces`, in the same order as `pieces` (foundation, wall, doorway, door, window,
ceiling, roof, roof_peak, pillar, stairs, ramp). Each piece maps tier -> blueprint, tiers in the
order thatch, wood, stone, metal. Leave the existing foundation and wall rows exactly as they are
(they already follow the formulas). Each blueprint has these keys in this order, shaped exactly like
the existing wall rows:

    model, max_durability, material_slots, minimum_level, maximum_level, required_skill_node,
    required_building_ability, supported_building_effects

Values (round(x) below means floor(x + 0.5), so 1.5 -> 2 and 1.7 -> 2):
- `model`: "" (empty string; the game draws a procedural stand-in until an artist model exists)
- size factor per piece: foundation 1.5, wall 1.0, doorway 0.85, window 0.85, door 0.5, ceiling 1.0,
  roof 1.0, roof_peak 1.0, pillar 0.5, stairs 1.5, ramp 0.75
- `max_durability` = round(tier_hp * size), tier_hp: thatch 400, wood 1200, stone 3000, metal 7000
- `material_slots`: exactly two dicts, keys in this order: role, item, quantity, counts_for_level,
  counts_for_attributes
  - first: role "primary", item and base quantity per tier: thatch branch 4, wood plank 4,
    stone stone 8, metal iron_ingot 4; quantity = max(1, round(base * size));
    counts_for_level true, counts_for_attributes true
  - second: role "binding", item and base quantity per tier: thatch fibre_stalk 4, wood twine 2,
    stone plank 2, metal stone 4; quantity = max(1, round(base * size));
    counts_for_level true, counts_for_attributes false
- `minimum_level` 1, `maximum_level` 60, `required_skill_node` "", `required_building_ability` 0,
  `supported_building_effects` ["durability"]

### 2. `placed_kinds`
Today `{}`. Fill it with these keys in this order. Each value is
`{"max_durability": N, "repair": [{"item": id, "quantity": q}, ...]}` (repair = the materials a full
repair from 0 costs; the game charges a fraction):

| kind | max_durability | repair |
|---|---|---|
| default | 300 | branch 2, fibre_stalk 2 |
| catapult | 200 | plank 4, rope 2 |
| fence | 250 | branch 2, twine 1 |
| gate | 300 | branch 3, twine 1 |
| tent | 200 | fibre_stalk 4, branch 2 |
| canvas_tent | 300 | twine 3, branch 2 |
| log_shelter | 900 | plank 4, twine 2 |
| straw_roll | 100 | fibre_stalk 3 |
| cabin_bed | 400 | plank 3, twine 1 |
| basket | 150 | fibre_stalk 3 |
| sign | 150 | branch 2 |
| workbench | 500 | branch 4, twine 2 |
| drying_rack | 250 | branch 3, twine 1 |
| smoker | 500 | stone 4, clay 2 |
| crock_pot | 400 | clay 3 |
| mortar | 400 | stone 3 |
| stone_grill | 600 | stone 5 |
| steamer | 400 | clay 2, branch 2 |
| well | 1200 | stone 6, plank 2 |
| bonfire | 300 | branch 3 |
| campfire | 200 | branch 2 |
| stone_fire_pit | 700 | stone 4 |
| makeshift_taming_pen | 600 | branch 4, twine 2 |
| field_small | 300 | branch 2, fibre_stalk 2 |
| field_large | 500 | branch 4, fibre_stalk 4 |

## Rules
- Touch no other file (TASK.md and verify_structures.sh are the only extra files allowed, and you
  must not edit either). Do not invent items: every item above already exists in game/data/items.json.
- No Godot run is needed for this task. If you ever run Godot, run it only through
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`
  and never with --editor.
- Milestones: (1) piece_tiers filled, run `./verify_structures.sh` and read every FAIL line;
  (2) placed_kinds filled; (3) `./verify_structures.sh` prints `VERIFY PASS`, then commit.
- Commit only game/data/structures.json, with a clear message ending with the line
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never commit TASK.md, verify_structures.sh,
  .dsc/ or .dsc.json. Do not push.
- Done = `./verify_structures.sh` exits 0 and prints `VERIFY PASS`.
