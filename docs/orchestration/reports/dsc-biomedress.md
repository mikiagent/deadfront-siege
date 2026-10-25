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

## Round 2 (orchestrator review)
Owner instruction for this round: headless/background only, no visible Godot window.

1. **Repaired PROPS2D / overhaul merged**: `game/tests/t_props2d.gd` and
   `game/scripts/world/prop_cards.gd` are in this tree, so the full gate's related-test loop can run.
   `game/scripts/camera/iso_camera.gd` is byte-identical to current `claude/mmo-overhaul`
   (blob `daf31d62`), so the owner's selected-resource/animal camera pan is intact; no protected-path
   change is committed. The earlier round-2 attempt did regress that file to a stale blob and hid it
   behind a hand-picked `BASE` in the job conf — both are gone: the conf has no `BASE` line and the
   scope check runs against the normal merge-base with `claude/mmo-overhaul`.
2. **Live claim reaction**: `BiomeDress.install()` connects `IslandRuntime.claims_changed` to
   `_on_claims_changed` → `clear_rect(rect)`, which collapses the cards on the new tiles (the MultiMesh
   is thinned, never rebuilt) and drops their records, so `claimed_instances() == 0` and the new
   `drawn_cards_in(rect)` (tile-record truth; headless cannot read multimesh transforms) drops them
   too. `rebuild()` re-plans and `plan()` already refuses claimed tiles, so a rebuild stays bare.
   New `_live_claim_check()` in `t_biomedress`: finds a cell that is edge-adjacent to held land and
   holds >= 2 cards, stakes it with `rt.claim_domain`, and asserts the plot's cards go, nothing else
   does, a rebuild keeps it bare, and removing the claim brings the cards back. Mutation-checked:
   deleting the `connect` makes it fail ("the live claim clears the cards it landed on (5 of 5 left)").
3. **Data/tests**: the `shell_pile` row pointed at the non-existent `beach-shells_15_shell_pile_c`
   (the real id is `..._17_shell_pile_c`). Fixed, and `BiomeDress.all_sprite_ids()` now returns every
   sprite id the data file configures — the test walks it and asserts each resolves to an existing
   file, so a typo in a row no zone happens to resolve can no longer hide.
4. **Signatures assert, not note**: `plan_kind(rt, zone, id, want, seed)` exposes the placement loop.
   The test forces savanna `termite_mound`, basalt `obsidian_crystal` and wetland `reed_bed` at 12
   cards with seed 4242 on their own islands and asserts >= 4 land inside the zone, off claimed tiles,
   and identical on a repeat call with the same seed.
5. **Build hygiene**: `_clear_cells()` now **detaches** each MultiMesh before `queue_free()` (queue_free
   leaves the node a child for the rest of the frame, which made an immediate second build measure
   240 → 322 nodes) and resets every dictionary/array. `_rebuild_checks()` builds twice and asserts
   identical cell count, MultiMesh child count, key-list length and card count, plus zero
   claimed/wrong-zone cards.
6. **Bounded land-tile structure**: `plan()` buckets land tiles per zone as `{count, sample}`, where
   `sample` is a reservoir capped at `TILE_SAMPLE_MAX = 2048` and appends in place (amortised O(1)),
   replacing the old `PackedInt32Array` append-and-reassign that copied the whole buffer per tile.
   Home island: 65 104 land tiles → 8 zones × at most 2 048 slots.
7. **Per-island lab proof**: the RESULT line now carries `zones_<island>` and `cards_<island>` (measured
   after that island is built, never cumulative) and the lab prints one
   `[biomedress] island <id> zones= cards= kinds_min=` line per island. `job_biomedress.conf`
   LAB_ASSERT requires all three islands to be non-zero.
8. **`island_scatter.gd` hook justified**: it is exactly the seam `GroundCover` already uses — the
   island build order is `IslandScatter.scatter()` → `BiomeDress`/`GroundCover` → `IslandProps.build`,
   and there is no installer registry to hook instead. The edit is one guarded line
   (`BiomeDress.install(rt, seed)` right after `GroundCover.install`), so it stays a one-line merge.
9. **Renderer evidence**: the owner reserved the machine (headless only) and no window was opened by
   hand for this round. The full gate (`verify_job.sh biomedress`, no `HEADLESS_ONLY` marker present in
   `docs/orchestration/dsc/gates/`) still runs its own stage-2 lab at 1600x900 and 844x390; that run
   passed and re-measured the field (RESULT below, 30 shots regenerated). The visual judgement of those
   shots is left to the owner/orchestrator — this agent did not look at new renders this round.
   The lab also detects
   `DisplayServer.get_name() == "headless"`, skips the pixel grabs and the prim/frame sample (the dummy
   renderer reports 0 there), still exits 0 when >= 5 zones were dressed, and says so in its log. The
   Forward+ 1600x900 and gl_compatibility 844x390 shots plus `prims_camp`/`ms_frame`/`ms_base` still
   need a windowed run of `verify_job.sh biomedress 2` when the machine is free. Round 1's 30 shots
   and their concept-art verdicts (`.dsc/NOTES.md`) are the visual evidence that exists.

Full gate stage-2 (windowed, gl_compatibility, 1600x900):

```
[biomedress] RESULT zones_total=8 zones_dressed=8 sprite_kinds_min=12 grass_in_claim=0 prims_camp=78967 ms_frame=5.95 ms_base=5.96 wrong_biome=0 zones_home_grassland=6 cards_home_grassland=8617 zones_savannah_15=5 cards_savannah_15=7500 zones_volcanic_60=4 cards_volcanic_60=9131
[biomedress] shots=30 islands=3 zones_dressed=meadow,forest,savanna,wetland,beach,rocky,canyon,basalt
```

Stage 2 also passed at 844x390 (same RESULT keys, its own shot dir). The per-island keys prove each
island separately; `prims_camp` 78 967 is inside the 900k budget and `ms_frame` 5.95 vs `ms_base` 5.96
is no measurable frame cost.

Headless lab (`--headless res://scenes/dev/biomedress_lab.tscn`):

```
[biomedress] island home_grassland zones=6 cards=8617 kinds_min=12
[biomedress] island savannah_15  zones=5 cards=7500 kinds_min=12
[biomedress] island volcanic_60  zones=4 cards=9131 kinds_min=12
[biomedress] RESULT zones_total=8 zones_dressed=8 sprite_kinds_min=12 grass_in_claim=0 prims_camp=0 ms_frame=0.00 ms_base=0.00 wrong_biome=0 zones_home_grassland=6 cards_home_grassland=8617 zones_savannah_15=5 cards_savannah_15=7500 zones_volcanic_60=4 cards_volcanic_60=9131
```

`prims_camp`/`ms_frame`/`ms_base` read 0 in headless by construction (no renderer); they are the
deferred-windowed numbers, not a regression.

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
`bash docs/orchestration/dsc/gates/verify_job.sh biomedress` prints **VERIFY PASS**: t_biomedress PASS,
lab stage 2 at 1600x900 and 844x390 with 30 shots each, related tests `t_biome`, `t_ground2d`,
`t_props2d` all PASS, `tools/smoke.sh` SMOKE PASS, report present, scope clean.

Scope: `job_biomedress.conf` has no `BASE` override, so the gate diffs against the normal
`git merge-base HEAD claude/mmo-overhaul`. This job's whole diff is:

```
docs/orchestration/dsc/gates/job_biomedress.conf
docs/orchestration/reports/dsc-biomedress.md
game/data/world/biome_dress.json
game/scenes/dev/biomedress_lab.tscn
game/scripts/dev/biomedress_lab.gd
game/scripts/world/biome_dress.gd
game/scripts/world/island_scatter.gd
game/tests/t_biomedress.gd
```

(plus their `.uid` files) and nothing else; `game/scripts/camera/iso_camera.gd` is untouched.
