# dsc — BIOMEDRESS

Owner: "start focusing on asset generation and building biomes using our 2D concept art as references
for what to generate and how to make them."

## Shipped
- `game/data/world/biome_dress.json` — a dressing set for all 8 BIOMEZONES zones (36 kinds). Each kind
  names sprite ids from `data/world/sprites2d.json` (sheet cuts from specs 27/28), lists the zones it
  may grow in, a density per m² of its zone, a clump count/spread, a `where` gate
  (`ground`/`edge`/`water`/`coast`/`any`) and a tint that pushes the shared sheet art toward the
  concept's palette.
- `game/scripts/world/biome_dress.gd` — `plan()` (pure and deterministic per seed) plus `install()`.
  Cards are drawn as camera-facing quads in one atlas material and one MultiMesh per 32 m cell, through
  `shaders/ground_cover.gdshader` (the GROUND2D sway shader): no colliders, no shadows, distance cull.
  Placement refuses claimed tiles, wrong-zone points (the zone is re-read at each card's exact
  position), water for land kinds, land for water kinds, steep faces and the sea.
- `game/scripts/world/island_scatter.gd` — one line installs `BiomeDress` right after `GroundCover`.
- `game/tests/t_biomedress.gd` — data completeness, determinism, claim/zone refusals, built-node
  checks, and climate signature checks (savanna → termite mounds, volcanic → obsidian, swamp → reeds).
- `game/scripts/dev/biomedress_lab.gd` + `game/scenes/dev/biomedress_lab.tscn` — top and game-camera
  shots per zone on home grassland, a savanna island and a volcanic island (30 PNGs).

## Concept mapping (what each zone is trying to look like)
| zone | concept signature |
|---|---|
| meadow | mixed grass clumps/tufts, white and red flowers, ferns, pebbles |
| forest | fern clusters, broadleaf shrubs, cycads, ivy, mossy rock/log, bromeliads |
| savanna | straw/plume clumps, aloes, red termite mounds, boulders, rock chips |
| canyon | red-tinted rock chunks, pale blue crystal clusters, aloes, termites |
| basalt | black basalt chunks and rubble, obsidian crystals, sulphur mounds, muted tree ferns/berry palms/red bromeliads |
| wetland | dense reed beds, reed clumps, cattails along the water; white lilies on the water |
| beach | shell scatters and piles, coral rock, driftwood, young palms |
| rocky | cliff chunks, boulders, mossy rock, crystals, fern tufts |

## Before / after
Before: `t_biomedress.gd` did not exist and no zone had any dedicated dressing; only the generic
GROUND2D cover and 3D props dressed the ground.
After (lab, 1600x900, gl_compatibility):

```
[biomedress] RESULT zones_total=8 zones_dressed=8 sprite_kinds_min=12 grass_in_claim=0 prims_camp=81468 ms_frame=4.50 ms_base=4.42 wrong_biome=0
```

- zones_dressed / zones_total = 8/8; at least 12 distinct sprite ids in every dressed zone.
- grass_in_claim = 0 and wrong_biome = 0.
- prims_camp = 81,468 (well inside the 900k gate); ms_frame 4.50 vs ms_base 4.42 → ~2 % frame cost.

## Shots looked at (full list and verdicts in `.dsc/NOTES.md`)
The first pass showed two real misses, both fixed and re-shot:
- **Wetland** was sparse green tufts instead of the concept's dense reed banks. Reed densities raised
  (reed_bed 0.05→0.13, reed_clump 0.03→0.08, cattail 0.02→0.06) and savanna/beach now grow reeds at
  the water too. After: a continuous reed wall with lilies on the turquoise channel.
- **Volcanic basalt** read as a green garden on brown dirt. Basalt chunks 0.024→0.06, obsidian
  0.004→0.008, a new dark basalt pebble kind at 0.03, and the tree fern/berry palm/bromeliad tints
  muted. After: a black-rock field with obsidian, crystals, sulphur and dark rubble.
Meadow, savanna, canyon, forest, beach and rocky passed unchanged; canyon (red earth + crystal
clusters) is the closest match to the concept art.

## Assumptions
- All densities, clump sizes, spreads, the 30° slope limit and the 3-tile water/coast margins are ours
  (`# ASSUMPTION` in the script); the docs give no numbers.
- Lily pads float at y = 0.06 on the water plane.
- Concept colour matching is done with per-kind tint multipliers, not new art.
- The flat brown terrain between basalt cards is the terrain palette (BiomeMaterial/terrain job), not
  this job's; the terrain palettes should be nudged darker/greyer on volcanic for a full match.

## What the integrator needs
- Nothing to merge by hand: `island_scatter.gd` gains one `BiomeDress.install(...)` line.
- If more sheets are cut later, add sprite ids to `biome_dress.json`; no code change is needed.
- Re-run the lab with
  `Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=biomedress_lab --shot-dir=DIR`
  to regenerate the 30 comparison shots.

## Gate status
Stage 1 and stage 2 of `verify_job.sh biomedress` pass (test + lab at 1600x900 and 844x390; 30 shots).
The full gate's related-test loop stops at `t_props2d`: `game/tests/t_props2d.gd` does not exist on this
branch (it lives only on `claude/mmo-props2d`), so the gate reports "printed no PASS line" for a file that
is not in the tree. `t_biome`, `t_ground2d`, `tools/smoke.sh` (SMOKE PASS) and the scope check all pass
when run by hand. Integrator: either merge/point at a tree with `t_props2d.gd`, or remove `t_props2d`
from `job_biomedress.conf` RELATED.
