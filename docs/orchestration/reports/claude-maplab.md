# MAPLAB: map lab, map format, validator, first importer

Branch `claude/mmo-maplab`, cut from `origin/claude/mmo-overhaul` d8e013fa. Not merged or pushed.
Owner's ask: "since we have a creature lab, it would be cool to also have a map lab so i can mark land
with what I want and pass the finalized map to Opus to create it".

## What shipped

- **`--lab=map_lab`** (`game/scripts/dev/map_lab.gd`, `game/scenes/dev/map_lab.tscn`): a top-down
  island painter in SheetChrome style at 1600x900. Mouse and touch both work, and every control is
  64 px. It has:
  - **Paint**: land, sea, erase, height (low, hill, mountain), river, lake and road, with a brush
    radius and a fill mode.
  - **Zones**: every zone in `biomes.json` (meadow, forest, savanna, canyon, basalt, wetland, beach,
    rocky), plus unset.
  - **Markers**: town, dock, camp, Adventurer's Guild, landmark, resource cluster, creature spawn and
    claim-free. Each has its own fields (name, species, level, count, radius, resource), and the
    Select tool edits or drags them.
  - **History and files**: undo/redo (64 steps, ctrl+Z/Y), layer toggles, a legend, save/load of
    drafts (`user://maplab/`), Validate, and Export to `game/data/maps/<name>.map.json` plus a
    `<name>.png` preview.
  - **Map settings**: size presets (Home 416 m, Tutorial 880 m, Custom), cell size (default 4 m),
    climate.
- **`MapDoc`** (`game/scripts/world/map_doc.gd`): the model, versioned JSON reader and writer,
  validator, preview image and importer.
- **`docs/current/map-format.md`**: the format an agent builds from, with every layer, marker kind,
  validator code and what the importer does or doesn't do. It is listed in `docs/current/README.md`.
- **Sample**: `game/data/maps/sample.map.json` + `sample.png` (home size, grassland). It uses every
  layer and marker kind and validates with 0 issues. `--make-sample` regenerates it from
  `map_lab.gd build_sample()`, and t_maplab checks that the file matches.
- **Importer**: an island def with `"map": "res://data/maps/<name>.map.json"` (or
  `MapDoc.island_def(base)`) builds a real island.
  - Hooks: `IslandRuntime.build` calls `MapDoc.apply_to_shape` instead of `IslandShape.compute()`,
    and `IslandTerrain._build_tile_types` calls `MapDoc.paint_zones` after the zone smoothing. Both
    are gated on `map_doc != null`, so every existing island builds exactly as before.
  - What it builds: land and sea, heights, rivers and lakes as MUD fresh water, painted zones, the
    harbour at the dock, the camp at the camp or town, and creatures from the spawn markers.
  - `islandgen_lab --map=<name>` builds and shoots one.

## Shots

- `docs/orchestration/reports/maplab/maplab_spawn_selected.png`: the sample, a spawn marker selected
  (species, level, count and radius fields), Validate showing "No issues".
- `docs/orchestration/reports/maplab/maplab_zones_off_dock.png`: the Zones layer off (land, height,
  water and roads only), the dock selected.
- `docs/orchestration/reports/maplab/sample_imported_top.png`: the sample built by the importer,
  shot top-down by islandgen_lab.

## Gates

- `t_maplab` **PASS**. It covers painting (brush, sea clears layers, fill), undo/redo (paint, marker
  add, prop edit, resize), an identical round trip and the committed sample file, refusal of bad files,
  the validator catching each listed problem, markers keeping their props, lab UI clicks (stroke,
  marker drop, undo, every button 64 px), and the importer build (98 %+ land/sea and zone agreement,
  the mountain above the meadow, the harbour at the dock, 7 creatures).
- `run_all` **`[tests] PASS`**.
- `bash tools/smoke.sh --no-import` **SMOKE PASS**.
- `t_islandgen` **PASS**: the 15 real islands are unchanged by the hooks.

Credits spent: none (no Meshy or Tripo).

## Not done / for the next agent

The importer leaves these as data only (listed in map-format.md, "Not imported yet"):
- town, guild and landmark buildings;
- resource clusters (the zone scatter still places nodes);
- claim-free circles (not wired into `IslandClaims`);
- roads (no path tiles);
- spawn level and radius.

Other gaps:
- Rivers are 4 m cells, so their edges show small steps, and `IslandShape.river`, the ford and the
  waterfall are empty on a map-built island.
- No map-built island is in the roster yet. To add one, give an `islands/*.json` a `"map"` key, then
  re-check t_harbour and the island pick.
- No pinch zoom or pan (the canvas always shows the whole map). Phone landscape (844x390) was not
  laid out or shot: 1600x900 first, as asked.

## Assumptions (marked in code)

- 4 m cells.
- Height classes of 1.2, 4.5 and 10 m.
- A tutorial preset of 880 m (the tutorial worktree's `size_m`; that island is not in canon).
- The coarse resource groups: trees, rock, fibre, berries, herbs, clay, reeds, ore, flint, salt.
- The sea floor drops 0.6 m per metre.
- A 6 m shore ramp.
