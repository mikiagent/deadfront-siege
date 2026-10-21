# PROPS: non-resource scenery and biome-weighted scatter — report

**Branch:** `claude/mmo-props` (worktree `.claude/worktrees/mmo-props`), based on `88ba6ef3` + the PROPS task commit.
**Merged the plan?** No: `git merge claude/mmo-overhaul` cannot run in this sandbox (`unable to lock
.git/worktrees/mmo-props/ORIG_HEAD: Operation not permitted`; the main repo's `.git` is read-only here). I read
`docs/design/islands-and-loop-plan.md` out of that branch with `git show` and followed its numbers (P1/P4 look items,
budgets, biome zone names, 400-600 HarvestNodes). The integrator should merge `claude/mmo-overhaul` first; nothing in
this branch touches its files.

## What shipped

| File | What it does |
|---|---|
| `game/data/world/props.json` (new) | 16 prop kinds + the scatter block. Per kind: `models` (existing `assets/nature/*.glb` now, `assets/nature/biome/*.glb` listed first for BIOMEASSETS), `biomes` weights, `size_m`, `radius_m`, `collide`, `destroyable`, `density_per_ha`, optional `water`/`cliff`/`card`. Scatter: `nodes_target`, `role_share`, per-biome `weights`, `ground_cover` densities. |
| `game/scripts/world/island_props.gd` (new) | `IslandProps`: biome area sampling, placement, `VegBatch` batching, colliders, `TilePath` blockers, clearing, save/load, scattering tint, Meshy-free cliff refusal. |
| `game/scripts/world/island_scatter.gd` | Area-based HarvestNode targets with biome weighting and a per-family preferred-biome gate; ground cover chunked into VegBatch cells; a top-up so the island reaches its target. |
| `game/scripts/world/veg_batch.gd` | `get_for_mesh` (card billboards), `material_override`, `overlay_color`, `cast_shadow_override`, `mesh_longest`, `set_xform`. |
| `game/scripts/dev/props_lab.gd` + `game/scenes/dev/props_lab.tscn` (new) | Windowed lab: prints the `[props]` line, a per-batch cost table, clears a prop, refuses a cliff it places by hand, saves 4 shots. 120 s watchdog. |
| `game/tests/t_props.gd` (new) | The acceptance test (see below). |
| `docs/orchestration/reports/dsc-props-hooks.patch` (new) | Every edit outside this job's file list. |

### Owner rules, as implemented

1. **Props are not resources.** `IslandProps` never adds to the `harvest` group, creates no `TapZone` and no
   labels, so no radial, no gather and no name pill can ever come from one. `t_props` asserts the group holds only
   `HarvestNode`s, that no prop body has a `TapZone`, and that each prop body is in `props`, not `harvest`.
2. **Some collide, some don't.** `collide: true` (boulders, cliff rocks, rock spires, mesas, basalt columns, termite
   mounds, fallen logs, tree stumps) = `StaticBody3D` + cylinder `Shape` on layer 1 + the tiles in
   `TilePath._props`, so both physics and A* treat them as solid. `collide: false` (reeds, plume grass, ferns,
   flowers, lily pads, pebbles, driftwood, mossy stones, aloe) = a batched instance and nothing else.
   `t_props` checks a boulder's tiles are not walkable and reeds' tiles are not in the blocker list.
3. **Most props clear, big cliffs do not.** Three kinds are `destroyable: false`: `cliff_rock`, `mesa_cliff`,
   `basalt_column` (the owner's "really big cliffs"). Everything else clears by an attack
   (`PlayerActions.attack` → `clear_in_front` when nothing alive is in reach), or by a build that needs the tile
   (`BuildPlacer.confirm` → `clear_cells`); a cliff refuses the build with reason `cliff` before the kit is paid.
   Cleared props are saved **by tile** inside the existing harvest snapshot
   (`unstable.harvested.__tiles.props.cleared`), so **no schema bump and no new top-level save key**.
   Clearing gives nothing (`# ASSUMPTION`).
4. **Biomes.** `IslandProps.biome_of(rt, x, z)` returns one of props.json's eight ids. It calls
   `BiomeZones.biome_at` through `load()` + `has_method` when BIOMEZONES lands (int ids go through
   `zone_name(id)`), and otherwise derives the zone from tile type, height, slope, climate and a moisture noise
   (meadow, forest, savanna, canyon, basalt, wetland, beach, rocky). Cadence: 2 m grid for area, per-candidate for
   placement.
5. **Resources by biome.** `island_scatter._plant_family` rejects a clump by the role's biome weight (trees thin on
   savanna, rocks on rocky ground) and by a per-family preferred-biome gate (reeds/flax/clay/mud by water, ore and
   crystal families on rocky/canyon/basalt, trees in forest/meadow, cactus/aloe/dry grass in savanna/canyon).
6. **Ground cover far from the origin.** Grass and flowers are now VegBatch cells (32 m, 120 m range, no shadows,
   foliage sway material) instead of one island-wide MultiMesh culled at 48 m. `rt.cover_points` records the
   placement for tests and labs.

## Numbers, before -> after (home_grassland, native, gl_compatibility 1600x900)

| Measure | Before | After |
|---|---|---|
| HarvestNodes on home | 216 | **478** (plan band 420-620, asserted) |
| Props on home | 0 | **248** (16 colliding, 232 walk-through) |
| Prop kinds placed on home | 0 | 10 of 16 (6 need BIOMEASSETS models or a volcanic/desert island) |
| Ground cover instances | 96 (one MultiMesh, 48 m cull) | **2140** in 16 VegBatch cells, 407 within 25 m of camp, 922 in the outer third of the island |
| Camp draws (1600x900) | 315-360 | **408** |
| Camp visible primitives | ~0.2-0.9M by climate | **548,494** (plan gate < 900k) |
| Camp shadow primitives | 0.2-2.1M | **2,398,253** (plan gate < 3.0M) |
| Camp total primitives | 2.83M home | **2,946,747** |
| `t_props` reachability | — | 45/45 checks (camp → harbour arrival + 44 sampled resources) |

Prop draw cost is shared with the resource batches: props ride the same `VegBatch` cells as harvest nodes of the
same model, so the scenery layer adds instances, not scene nodes or extra draws per prop.

**Batch cost table (props_lab `[props] batch` lines).** The expensive families are the Meshy tree (19-31k tris) and
berry-bush (36-41k tris) models, not the props: the whole prop layer is ~5.8M tris of the island-wide total but only
a fraction of what is on screen. Ground cover is 2,300 instances at 192-408 tris. The `role_share` in props.json is
weighted towards rock/plant/wild-grass for that reason; the plan's 180-250 home trees need CARD2D cards.

**Shadow rule.** Scenery batches never cast shadows (`cast_shadow_override = OFF`): decoration, not a gameplay read,
and the plan's shadow gate is the tight one on home. Trees and bushes (resources) keep their shadows.

**Tint rule.** Every prop batch gets a translucent dark overlay (`SCENERY_TINT`, alpha 0.30) so a prop sharing a
model with a resource node (`Rock_1`, `WoodLog`, `Plant_*`) does not read as something to tap. ASSUMPTION: the exact
colour is mine.

## Shots looked at (in the verify output dir `.../dsc/props-out/shots/`)

- `props_camp.png` — camp view: cover, reeds by the river, logs and boulders, the survivor clear against them, HUD
  unchanged.
- `props_prop_close.png` — the nearest big prop with the survivor beside it: prop scale next to a 1.8 m survivor
  reads right (boulder knee-to-chest, log waist-high).
- `props_top.png` — atlas view: green land, river, cover spread over the whole island, no bare ring around the
  origin any more.
- `props_cleared.png` — the same spot after a log was cleared: the log is gone, neighbours stay.

## Assumptions (marked `# ASSUMPTION:` in code)

- Clearing a prop gives no loot (owner's rule says nothing about drops; the simplest reading).
- Prop `size_m` = the model's longest side in metres; collider radius = `radius_m x max(0.35, height/2)`, capped at
  3.2 m, so a mesa is a landmark, not a wall.
- Scenery tint (alpha 0.30) and "props never cast shadows".
- The three indestructible kinds are exactly cliff_rock, mesa_cliff, basalt_column.
- Prop density per kind is mine (the docs give none): pebbles 130/ha, ferns 60/ha, reeds 80/ha, boulders 16/ha,
  mesas 0.5/ha, etc.
- `MAX_PROPS = 1400` per island: a proportional cut across kinds, never spent in dict order.
- Zone thresholds in the fallback (river < 0.35 m height and MUD tile -> wetland, slope > 32 deg or ROCK -> rocky,
  etc.) are mine; BIOMEZONES replaces them when it lands.
- Ground cover densities 1600/ha grass and 140/ha flowers.

## Owner update 2026-10-21: props switch to painted 2D cards

`props.json` kinds may declare `"card": "prop:<id>"` instead of GLB models; the id names a row of the owner's
`data/sprites2d.json` (CardProp, CARD2D job). Five kinds exist only as cards so far — `stone_arch`, `pillar`,
`waterfall`, `vines`, `shells` — and are skipped (one log line, no error) until those rows and images land.
**Every prop visual goes through one function, `IslandProps._draw_prop(row)`** (called from `_spawn`), so the card
job replaces that body with `CardProp` sprites and changes nothing else: placement, biome weights, colliders,
TilePath blockers, clearing, the save format and `t_props` all stay as they are. A res:// PNG/WebP path also works
today as a card, drawn as a camera-facing billboard through `VegBatch.get_for_mesh`.

## What the integrator needs

1. **Merge order.** `claude/mmo-overhaul` first (it brings the plan and today's fixes), then this branch. Nothing
   here edits the plan's files.
2. **Hooks patch.** `docs/orchestration/reports/dsc-props-hooks.patch` applies to
   `data.gd`, `island_runtime.gd`, `tile_path.gd`, `build_grid.gd`, `build_placer.gd`, `player_actions.gd`,
   `veg_batch.gd`, and `tools/smoke.sh` (a sandbox fallback for `$HOME`; the smoke assertions are unchanged).
   If CARD2D, W2-BUILDSYS or ISLANDGEN merge first, re-apply by hand:
   - `island_runtime.build()` must call `IslandProps.build(self)` after `IslandScatter.scatter` and before
     `_setup_pathing`;
   - `harvest_tile_snapshot()` carries `props`, `apply_harvest_tile_snapshot()` reads it;
   - `TilePath` needs `_props` + `_prop_blockers()` and `_blocked()`;
   - `Data.world_props` from `data/world/props.json`;
   - `VegBatch` needs `get_for_mesh`, `overlay_color`, `cast_shadow_override`, `material_override`,
     `mesh_longest`, `set_xform`.
3. **BIOMEASSETS:** each kind lists `res://assets/nature/biome/*.glb` first. They are skipped while missing, so the
   layer gets its cliffs, mesas, termite mounds, reeds and plumes the moment those files import — no code change.
   The prop kinds that place nothing on the starter today (`cliff_rock`, `rock_spire`, `mesa_cliff`,
   `basalt_column`, `termite_mound`) are exactly the ones waiting on that art or on a desert/volcanic island.
4. **CARD2D:** set `"card": "res://…png"` on a kind and `IslandProps` draws a camera-facing quad through
   `VegBatch.get_for_mesh` with the same placement, collider and clearing rules. Nothing else changes.
5. **BIOMEZONES:** `biome_at` is called untyped; int ids go through `zone_name(id)`; names are mapped onto the eight
   props.json ids. If it exposes a different API, only `IslandProps.biome_of` needs editing.
6. **Budget:** the camp is at 530k visible / 2.29M shadow with 478 resources. Raising `role_share.tree` or `bush`
   (or CARD2D not landing) will move the visible count fast: berry bushes are 36-41k tris each and the biggest
   single batch. The plan's 180-250 trees is not affordable on these GLBs.

## Verification

```
bash scratchpad/dsc/verify_props.sh   -> VERIFY PASS
```
which runs `--import`, `t_props` (PASS, 0 SCRIPT ERROR), `t_stepover` (PASS), the windowed `props_lab` (prints
`[props]`, no SCRIPT ERROR, 4 shots) and `tools/smoke.sh` (SMOKE PASS). Also run by hand on this branch:
`t_data` PASS, `t_build` PASS, `t_save` PASS (its 5 deliberate SCRIPT ERRORs only), `island_lab` headless.
The smoke step needed a sandbox fix: `$HOME/Library/Application Support` is not writable for this run, so Godot
segfaulted at startup; `tools/smoke.sh` now falls back to a scratch HOME like `gslot.sh` does (recorded in the hooks
patch).
