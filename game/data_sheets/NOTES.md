# Editable game-data sheets — how to change the build

These CSVs are **generated from** `game/data/*.json` (generator: `tools/docs_wiki/gen_game_data.py`).
They are yours to edit — Numbers, Excel or Google Sheets all open them plain. So a sync can apply
them safely:

- **First column is the key** (`id`/`species`/`station`/...) — never rename a key of an existing
  row; deleting a KEY row means "remove this record", and the sync will ask before doing it.
- Numbers, booleans (`true`/`false`) are edited in place. List cells are `;`-joined values.
- Keep the header row untouched. A **new row at the bottom** means "new record", validated
  against real game ids before anything applies.
- After a tuning pass, tell the agent to **sync sheets back**: it rewrites only changed values,
  prints a diff of every applied cell, and the game's data tests run before it is called done.

| Sheet | Syncs into | What it tunes |
|---|---|---|
| recipes.csv | `data/recipes.json` | craft inputs/outputs, times, gates |
| repairs.csv | `data/recipes.json ·repairs` | per-tier repair cost/restore |
| processing.csv | `data/processing.json` | station labels, slots, real convergence times |
| items.csv | `data/items.json` | stack sizes, levels, rarity, default attributes |
| foods.csv | `data/foods.json` | FOODFX channels/effects per consumable |
| islands.csv | `data/islands/*.json` | island roster, tiers, lifetimes |
| climates.csv | `data/world/climates.json` | tiers, resists, flora families, materials |
| creatures.csv | `data/creatures/*.json` | species tier/climate rows |
| butchering.csv | `data/butchering.json` | kill drops per species |
