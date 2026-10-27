# Task: FARMKIT: farm plots, crop stages, paths and farm props (headless Blender)

Owner: build biomes and tamed islands like the references. Look at docs/reference/durango-tamed-island-overview.webp (dark
tilled farm plots with crop rows, dirt paths between buildings, palm rows) and spec 30 §13 (farming/animal facilities).
The game has field plots already (game/scripts/world/field_plot.gd); you make ONLY the models.
## Models (sizes ASSUMPTION; a field plot module is 2 x 2 m unless field_plot.gd says otherwise - read it)
- First group (M1): field_tilled (dark furrowed soil, raised edge), field_crop_0 (seedlings), field_crop_1 (young),
  field_crop_2 (grown), field_crop_3 (ripe, harvestable look) - crops as low-poly rows on the tilled plot.
- Second group (M2): path_dirt, path_dirt_corner, path_stone, path_stone_corner (2 m flat path tiles, at most 0.05 m high,
  edges that blend into grass).
- The rest (M3): fence_post_rail, fence_post_rail_gate (gate leaf origin on its hinge), trellis, scarecrow, compost_heap,
  water_trough.

## How to work
- The pipeline: tools/blender/structures/structures.py (one builder function per model, registered in BUILDERS; helpers and
  ONE shared 1024 atlas in lib.py: tiles such as bark, stone, char, clay, deck, thatch), build.py builds GLBs headless:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/structures/build.py -- <names>`
  (headless ONLY; never open a live Blender). check_manifest.py writes game/data/props_manifest.json rows. Read
  docs/orchestration/reports/claude-mmo-w1-structart.md for the set's style, sizes and conventions (one material = the
  atlas, origin at the ground centre, front +Z, real metres next to a 1.8 m survivor).
- The camera: perspective, pitch about 38.7 degrees from above, yaw 45; models must read from that angle.
- Do not change existing builders' output (other structures must rebuild identically). Scratch files in $TMPDIR/farmkit.
  Never `rm -r` a path with tracked files. No Godot except the final import inside the verify.
- Contact sheet docs/orchestration/reports/dsc-farmkit-sheet.png: render all your models headless in Blender from the game camera
  angle with a 1.8 m figure for scale, LOOK at it, write what you saw in .dsc/NOTES.md, fix anything wrong, re-render.
- Report docs/orchestration/reports/dsc-farmkit.md: models, triangle counts, sizes (# ASSUMPTION unless a spec gives them),
  what the contact sheet showed.
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_blender.sh farmkit [m1|m2|1]` (read it first; no stage = full).
## Milestones (milestone_done after each; the gate checks the models due by then)
- M1 the first group (verify m1). M2 the second group (verify m2). M3 the rest (verify 1). M4 manifest rows, contact sheet,
  report, full verify.
