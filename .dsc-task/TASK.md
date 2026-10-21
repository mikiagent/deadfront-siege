# Task: STATIONART: 3D models for the crafting stations and construction sites (headless Blender)

Owner: "keep buildings 3D"; the owner's spec docs/design/durango-prompts/30_building_construction_and_crafting_stations.md
(read §10, §12, §6-8) needs station tiers and unfinished construction sites. Another job builds the code; you build ONLY the
models, in the existing structure pipeline.
## The pipeline (read it first)
- tools/blender/structures/structures.py: one builder function per structure (e.g. workbench() at line ~98, smoker(),
  drying_rack(stage), _crate(), _teepee(), _stone_ring()), registered in BUILDERS; lib.py has the shared helpers and ONE
  1024 atlas (structures_atlas.png, 8x8 painted tiles: bark, stone, char, clay, deck, ...). build.py builds GLBs:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/structures/build.py -- <names>`
  (headless ONLY: a live Blender session once crashed). check_manifest.py writes game/data/props_manifest.json rows.
  The set's report: docs/orchestration/reports/claude-mmo-w1-structart.md (style, sizes, the atlas, conventions).
- Existing models (do not rebuild): workbench, technical_workbench, drying_rack (+ _raw/_drying/_dried), smoker, steamer,
  crock_pot, basket, large_box, chest, campfire, bonfire, stone_fire_pit, mortar, well, tent, fence, gate, pier.
## Build these (15 models), same style and conventions (one material = the atlas, origin at the ground centre, front +Z,
36-2500 triangles, real-world metres next to a 1.8 m survivor):
- Workbench tiers that read as a progression (spec 30 §12): makeshift_workbench (lashed sticks and a flat stone, ~1.2 x
  0.6 m), basic_workbench (planks on pillars with strap lashings), journeyman_workbench (trimmed planks, nailed, a vice and
  tool rack), expert_workbench (processed planks, metal fittings, drawers, glue pots).
- kiln (clay dome with a firebox mouth and chimney, ~1.6 m), loom (upright frame loom with warp threads, ~1.6 m),
  large_loom (wider, with a bench), oven (stone bread oven / stove with a flue, ~1.4 m), large_drying_rack (two-bay rack
  on trimmed pillars, ~3 m wide).
- Construction sites for unfinished buildings, three progress stages each: site_small_0/1/2 (fits a 2 x 2 m footprint) and
  site_large_0/1/2 (3 x 3 m): stage 0 = staked-out ground with a string outline and a small pile of logs and straps; stage
  1 = a scaffold frame half up with the material piles smaller; stage 2 = scaffold full height with a partial plank
  cladding. They must read as "under construction" at the game camera (pitch ~38.7 deg from above, yaw 45).
## Milestones
- M1 Read the pipeline and the report; build the four workbench tiers; `bash <verify> 1` must list them (stage 1 fails
  only on the models not built yet - that is expected until M3).
- M2 kiln, loom, large_loom, oven, large_drying_rack.
- M3 The six site stages. Stage 1 passes for all 15.
- M4 props_manifest.json rows (check_manifest.py), a contact sheet docs/orchestration/reports/dsc-stationart-sheet.png
  rendered headless in Blender (all 15 plus the existing workbench and a 1.8 m figure for scale, lit like the game, seen
  from the game camera angle), LOOK at it, fix anything that reads wrong (floating parts, wrong scale, a site that looks
  finished), re-render; then the report docs/orchestration/reports/dsc-stationart.md and the full verify.
Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_stationart.sh [1]` (read it first; no argument = full gate with a Godot import).
## Constraints
- Your files only: tools/blender/structures/, game/assets/props/blender/, game/data/props_manifest.json,
  docs/orchestration/reports/dsc-stationart*. Do not change existing builders' output (other structures must rebuild
  identically). Blender headless only; no Godot except the final import in the verify. Scratch files in $TMPDIR/stationart.
- Never `rm -r` a path with tracked files. Write each model in its own builder function; key nothing by list order.
- Report: what you built, triangle counts, the contact sheet and what you saw in it, assumptions (sizes are # ASSUMPTION
  unless the specs give them).
