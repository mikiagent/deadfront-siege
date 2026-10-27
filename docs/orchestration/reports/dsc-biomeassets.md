# dsc-biomeassets: biome props built in headless Blender

Task: build concept-art props for the larger, zoned islands (spec 26: canyon oasis, volcanic wetland,
savanna delta) with the owner's rules: props are not resources, some collide and some do not, everything
small can be destroyed except the big cliffs. Package owner: this job only. No other package's files were
changed; nothing is committed (the sandbox blocks git, see "Not done").

## What shipped

25 GLBs in `game/assets/nature/biome/`, one mesh and one material each, no image textures, ~10-60 KB each.
All numbers below are measured from the built meshes (`tools/blender/biome_props/write_manifest.py` prints
them and writes the JSON), Godot axes: width x height x depth, metres, origin at the ground centre, Y up.

| id | kind | w x h x d | collide | destroyable | tris |
|---|---|---|---|---|---|
| reed_clump_a | reed_clump | 1.86 x 1.86 x 1.68 | none | yes | 680 |
| reed_clump_b | reed_clump | 1.33 x 1.34 x 1.40 | none | yes | 440 |
| plume_grass | plume_grass | 1.63 x 1.63 x 1.27 | none | yes | 744 |
| fern_clump_a | fern | 1.41 x 0.90 x 1.35 | none | yes | 768 |
| fern_clump_b | fern | 1.70 x 1.33 x 1.92 | none | yes | 768 |
| lily_pad_cluster | lily_pads | 1.65 x 0.19 x 1.54 | none | yes | 236 |
| aloe_flower | aloe | 0.79 x 1.18 x 0.79 | none | yes | 380 |
| termite_mound_a | termite_mound | 2.44 x 3.07 x 2.11 | cylinder | yes | 1638 |
| termite_mound_b | termite_mound | 2.78 x 3.44 x 2.78 | cylinder | yes | 2144 |
| fallen_log_moss | fallen_log | 4.75 x 0.73 x 0.96 | box | yes | 341 |
| fallen_log_dry | fallen_log | 6.08 x 0.86 x 1.15 | box | yes | 261 |
| rock_spire_a | rock_spire | 4.03 x 5.87 x 3.77 | box | **no** | 818 |
| rock_spire_b | rock_spire | 4.89 x 9.05 x 4.89 | box | **no** | 818 |
| mesa_sandstone | mesa (fluted red canyon wall) | 13.13 x 9.45 x 11.10 | box | **no** | 2057 |
| cliff_chunk_red | cliff (stepped sandstone terrace) | 13.44 x 6.56 x 8.55 | box | **no** | 3040 |
| mesa_basalt | mesa (columnar basalt face) | 11.97 x 9.14 x 4.30 | box | **no** | 2039 |
| basalt_columns | basalt_columns | 2.45 x 1.70 x 3.17 | box | yes | 224 |
| boulder_pile_a | boulder_pile | 1.87 x 0.74 x 1.46 | box | yes | 300 |
| boulder_pile_b | boulder_pile | 2.74 x 0.97 x 2.04 | box | yes | 340 |
| crystal_blue | crystal_cluster (ore visual) | 1.18 x 0.67 x 1.20 | cylinder | yes | 1426 |
| crystal_obsidian | crystal_cluster (ore visual) | 0.96 x 0.52 x 0.96 | cylinder | yes | 1426 |
| crystal_sulphur | crystal_cluster (ore visual) | 1.33 x 0.36 x 1.20 | cylinder | yes | 1206 |
| steam_vent | steam_vent | 1.86 x 0.37 x 1.73 | cylinder | yes | 240 |
| hot_spring_rim | hot_spring_rim | 4.16 x 0.59 x 3.45 | box | yes | 782 |
| pebble_patch | pebbles | 1.93 x 0.10 x 2.08 | none | yes | 1280 |

Total 23.4k tris for all 25 props (previous nature props are 1-2k each; a full island can place hundreds of
these and stay inside the plan's < 900k visible primitives at camp).

Data: `game/data/world/biome_assets.json`, 25 rows, `{"_about", "assets": [...]}`, each row
`id, path (res://assets/nature/biome/<id>.glb), kind, size_m [w,h,d], collide ("none"|"box"|"cylinder"),
destroyable, biomes [zone ids], tris, budget_tris, origin "ground_center", notes`. Biomes use the plan's
zone names (`docs/design/islands-and-loop-plan.md` 1.4: riverbank, forest, dry_upland, savanna, rocky_hills,
volcanic, beach, canyon, delta, oasis, hot_spring) plus spec-26 landmarks. The file does NOT touch
`props_manifest.json`: it is consent for the island scatter to place visual props, not a resource sheet; only
the three crystal clusters are intended as ore-node visuals.

Reproducibility: `tools/blender/biome_props/` holds every script.
- `bp_lib.py`: hash noise, fibrous noise, sRGB->linear vertex colour, one Principled material, loft / ico /
  cylinder / parametric sheet / leaf helpers, join+export to GLB (Y up, origin at ground), tris+size report.
- `vegetation.py`, `rocks.py`, `minerals.py`: one builder per asset, grouped in a BUILDERS dict.
- `build_all.py`: builds every asset (or a group: `-- vegetation|rocks|minerals`), prints one JSON line per
  asset and **exits 1 if any asset is over its triangle budget** — the build is its own gate.
- `write_manifest.py`: runs the same build and writes `biome_assets.json` from the measured meshes.
- `sheet.py`: the contact sheet (below).
Run: `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/biome_props/build_all.py`
(Blender 5.2.0 LTS on this machine; the scripts use only stable bmesh/glTF APIs).

Budgets (task): vegetation <= 800 tris; mounds/logs/boulders <= 2500; spires/mesas/cliffs <= 6000.
Measured: vegetation 236-768 (max 768), mounds/logs/boulders 261-2144, spires/landforms 818-3040 —
every asset inside its budget, checked by build_all's exit code on every run below.
`# ASSUMPTION:` the task gives no budget for the minerals group; they use 1500 (2x the vegetation budget,
they are small ground props): crystals 1206-1426, vent 240, terrace rim 782, pebbles 1280.

## Look: what I compared against, and what changed

I opened all three concept images (`docs/reference/biome-concept-canyon-oasis-savanna.webp`,
`biome-concept-volcanic-wetland.webp`, `biome-concept-savanna-river-delta.webp`) and an in-game render of the
existing nature GLBs (Rock_1, WoodLog_Moss, Grass, Plant_1, TreeStump, Lilypad, rendered in Godot at 1280x720
with the game's GL-compatibility path). The existing Quaternius set is flat-coloured and smooth; ours is
faceted with baked per-vertex variation, so they sit together as "stylised low-poly" without matching exactly.

Things that were wrong when I looked at the renders, and what fixed them:
- Reeds/plume read as sparse sticks → 2x-3x denser clumps (16→34, 10→22, 7→12 stems), budget-capped.
- Ferns read as bare stems → arching rachis with 11 shrinking pinna pairs, tilted up 30 deg.
- Lily pads too pale, flower invisible → darker pads, 9-petal white flower with a yellow centre.
- Logs floated and had claw-like roots; moss covered the whole trunk → capped ends, sag lowered to sit on
  the ground, moss only as small flat patches on the upper bark.
- Mesas read as brown bread loaves (round ring lofts seen from a 50 deg camera) → rebuilt by the orchestrator's
  audit as three distinct silhouettes: a fluted red canyon wall (buttress ridge, 2.1k tris), a stepped
  sandstone terrace (offset tiers with risers and pale lips, 3.0k tris), a columnar basalt face (5/6/7-gon
  columns, 3 rows, broken heights, ash + lichen, 2.0k tris). Each has a 0.6-0.7 m skirt below z = 0 so it can
  sit into a slope.
- Spires had a smooth cone crown and a green wash → blunt broken shaft, three tilted cap slabs, bare
  sandstone colour with strata; 5.9 m and 9.1 m tall.
- Termite mounds 1.9 m and tent-like → pinnacle profile (broad base, steep wall, blunt crown), 7 vertical
  fins with shadowed grooves, clay blobs at the foot, 3.07 m / 3.44 m tall (both inside the 2-3.5 m range).
- Steam vent was a flat ring → raised sinter mound sloping into a dark shallow pit, sulphur crust on one side.
- Hot spring was three cups → a staircase of three low, wide cream travertine pools, each lower and further
  out than the last, with warm basin floors.

Materials: one Principled material per asset, base colour from COLOR_0 (`biome_vcol`), roughness 0.72,
metallic 0, **doubleSided off for every solid** (glTF `doubleSided` absent; back faces are culled), and
**doubleSided on only for the foliage cards** (reeds, plume, ferns, lily, aloe). Crystals: roughness 0.30 /
metallic 0.10 (blue), 0.25 / 0.25 (obsidian), 0.45 / 0.0 (sulphur) so the facets catch the sun. Verified by
reading the GLB JSON for all 25 files.

Shots looked at: the contact sheet below (every asset next to a 1.8 m figure, neutral sun + sky, Standard view
transform, front-left 3/4 view), plus Godot in-engine renders of the whole set and of the rocks close-up
during iteration (`.dsc/shots/godot_look2.png` in the worktree, throwaway scripts were deleted).

## Verify / checks run

- `build_all.py` for vegetation, rocks, minerals: exit 0, every asset inside budget (the run exits 1 on any
  over-budget asset; it did during iteration and was fixed).
- Godot import: `... --headless --path game --import` at alarm 900 → exit 0, **0 lines matching /error/i**
  in the log, and 25 `.import` files created.
- A throwaway Godot probe loaded all 25 GLBs as PackedScene: mesh present, `ARRAY_COLOR` present,
  `vertex_color_use_as_albedo` already true on the imported StandardMaterial3D (the game needs no material
  override or remap), tri counts identical to Blender, AABBs identical to `size_m`.
- `biome_assets.json`: 25 rows, every row has id/path/kind/size_m/collide/destroyable/biomes; destroyable is
  false only for mesa/cliff/spire kinds (asserted in a one-off check).
- The package verify script (`verify_biomeassets.sh`) passes.

## Colour space: unverified in Godot

COLOR_0 handling is **not** confirmed. Evidence both ways:
- A calibration GLB (two quads, COLOR_0 = 0.214 vs 0.5) rendered in Godot's gl_compatibility path showed
  127 and 53 grey, i.e. Godot displayed the raw stored value without an sRGB conversion.
- Writing raw sRGB into COLOR_0 then made every asset wash out pale in-engine (sandstone peach, granite
  near-white), which is what a double sRGB->linear decode would look like.
So the scripts store **linear** (authored sRGB passed through `bp_lib.srgb()`), which looked right in-engine.
This is a single calibration box, not a validated pipeline, and my render used LINEAR tonemapping and a
constant ambient instead of the game's AGX + sky ambient (`world_lighting.gd:145-156,205-217`). **The
integrator should eyeball the props in the real lighting before shipping; if they look washed out, the fix
is one line in `bp_lib.paint` (`v[layer] = srgb(...)` → store the raw triple) and a rebuild.**

## Assumptions
- `# ASSUMPTION:` minerals budget 1500 tris (task gives none).
- `# ASSUMPTION:` "collide": none for vegetation, lily pads and pebbles (walk through); box for logs,
  boulders, basalt outcrop, terraces, mesas, spires; cylinder for termite mounds, crystal clusters and the
  vent rim (round footprints). The integrator can override any row.
- `# ASSUMPTION:` "destroyable": every prop except the three mesa/cliff kinds and the two spires. If a prop
  is destroyed, nothing here says what it drops: these are props, not resources (owner's rule); only the
  crystals mirror ore nodes.
- `# ASSUMPTION:` zone ids in `biomes` follow the plan's 1.4 naming; unmerged W1-BIOME may rename them.
- `# ASSUMPTION:` asset ids are the file names; there is no manifest registry otherwise (this file is it).

## Not done / for the integrator
- **Nothing is committed.** The sandbox in this worktree cannot write `.git/index.lock`, so no git operation
  that touches the index (merge, checkout, commit) works here. The plan file from `claude/mmo-overhaul`
  (`docs/design/islands-and-loop-plan.md`) was brought in with `git show ... > file`, uncommitted. The runner
  checkpoints git when enabled; the orchestrator must commit these files.
- Wiring is out of scope (my files are the GLBs, the Blender scripts and `biome_assets.json`):
  - the island scatter (`island_scatter.gd` / the plan's per-zone sets) must read `biome_assets.json` and place
    by `biomes` / `kind`; props must NOT get harvest nodes, only the crystal clusters should back ore nodes;
  - colliders: build from `collide` + `size_m` (box → BoxShape3D of size_m, cylinder → CylinderShape3D with
    radius = max(w, d) / 2, height = h, standing on y = 0);
  - destruction: `destroyable` false → skip the breakable component; true → whatever destruction system the
    island uses, with no drops;
  - mesas/cliffs/spires are landmarks: place them on the zone's landmark slot, slope-gated so their 0.6-0.7 m
    skirt sits into the terrain, and keep the 6k/2.5k budgets in mind when counting a whole island.
- No hooks patch was needed: no file outside my three areas was modified.
- The sheet's captions are small and lie on the ground in front of each asset (readable at 100 %); the
  package verify only checks the file exists.

## Files
- `game/assets/nature/biome/*.glb` (25) + Godot `.import` files.
- `game/data/world/biome_assets.json`.
- `tools/blender/biome_props/{bp_lib,build_all,vegetation,rocks,minerals,write_manifest,sheet}.py`.
- `docs/orchestration/reports/dsc-biomeassets.md`, `docs/orchestration/reports/dsc-biomeassets-sheet.png`.
