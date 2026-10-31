# BIOMEWIKI: biome spawn page in the wiki

Branch `claude/mmo-biomewiki`, cut from `claude/mmo-overhaul` at `03610b2a`. Not merged.

Owner ask (Milan, 2026-10-30): "can you add to the wiki somewhere I can see each biome and what dinosaurs spawn in each?"

## What shipped

- **`docs/current/biome-spawns.md`** (generated): one section per biome (island climate). Each section has a
  summary table (species, islands, level range, groups, tameable, status) and one table per island
  (ring or fixed spot or tutorial zone, count x groups, chance, level, alpha, tameable, status). It ends with every
  species' home `climate`, model yes/no, and whether any spawn table names it.
- **Generator** `gen_spawns` in `tools/docs_wiki/gen_game_data.py`, run by the normal
  `python3 tools/docs_wiki/gen_game_data.py`. It mirrors the game's code:
  - island merge = `World._load_islands` (`world/islands.json` templates, then `data/islands/*.json` keys on top);
  - fallback = `CreatureDef.eligible` + `has_model` (`assets/creatures/<id>/<id>.glb` exists), with the same
    table and pool as `IslandSpawns.spawn_all` and `Tutorial._wild_zones`;
  - level = the spawning species' tier + ring `level_offset` + row `tier_offset`, clamped 1-60
    (`Creature._spawn_level`); `level_override` islands (home, tutorial) are L1;
  - alpha = `ai.json alpha.chance_per_group` (8%), "never" on `no_alphas` islands (tutorial).
- **Test** `tools/docs_wiki/test_biome_spawns.py`: the fallback rule on a fake asset dir, plus real-data checks.
- Links: a row in `docs/current/README.md` (the Current implementation index, next to the other generated data
  pages), a pointer line at the top of `world-biomes.md` (also emitted by its generator), and the generated-pages
  list in `docs/README.md`.
- Drive-by: `gen_biomes` treated `creatures/ragdoll.json` as a species and dumped its rig dict into the Fauna
  table and `game/data_sheets/creatures.csv`. Fixed the filter and removed that row from both.

## What the page shows today

14 of 20 species have a model. No model yet: allosaurus, brachiosaurus, dilophosaurus, smilodon, tarbosaurus,
triceratops. Their rows fall through, for example tropical_25's far-shore Dilophosaurus spawns a Compsognathus
(L20), and tundra Smilodon spawns Megaloceros or Velociraptor. Pachycephalosaurus has a model but no spawn table
names it. Brachiosaurus is on no table.

## How to view

`python3 tools/docs_wiki/docs_wiki.py serve --port 8899 --open` from the canon checkout, then
Current implementation, then "Biome spawns — what lives where" (`docs/current/biome-spawns.md`).

## Gates

- `cd tools/docs_wiki && python3 -m unittest discover -p 'test_*.py'`: 54 tests OK (pytest is not installed).
- `python3 tools/docs_wiki/phase_map.py check`: OK.
- `tools/smoke.sh`: SMOKE PASS.

## For the next agent

- **Do not run `gen_game_data.py` straight into canon yet.** The committed `recipes.md`, `items-traits.md` and
  `world-biomes.md` have sections the generator does not produce (ONEGATHER, TERRAINSMOOTH and others), so a full
  regenerate deletes about 350 lines. `items.csv` and `recipes.csv` also differ from what the data gives (knife names),
  so it refuses without `--force-sheets`, and with it would discard those rows. I regenerated only `biome-spawns.md`.
  Either fold those hand sections into the generator or split the generated tables from the prose.
- Not modelled: positions (the 24-creature cap can cut late rows on a crowded island; dry-land rejects). A fixed spot
  shows the full ring level span because its ring depends on runtime position.
- No sheet (CSV) for spawns: the sheets round-trip back into data and spawn rows are nested; add one if Milan wants
  to edit spawns in a spreadsheet.
