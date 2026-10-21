# Task: HOUSEKIT: modular house parts in three material tiers (headless Blender)

Owner: "keep buildings 3D". Spec docs/design/durango-prompts/30_building_construction_and_crafting_stations.md §13 (houses and
modular parts: floors, walls, roofs, doors, stairs; material choice affects appearance) and spec 10. Look at
docs/reference/durango-tamed-island-overview.webp: wooden houses with dark roofs, paths and farm plots on a tamed island.
Existing stand-ins to replace in style (keep them working): floor(), wall(), wall_doorway(), roof() in structures.py.
## Models (2 m modules: a wall is 2 m wide x 2.4 m high; ASSUMPTION unless structures.json gives module_m/storey_m - read it)
- First group (M1): house_foundation (stone plinth, may sink up to 0.5 m), house_floor (planks), house_wall (log/plank),
  house_wall_window, house_wall_doorway, house_door (hinged leaf with its origin on the hinge).
- Second group (M2): house_roof (thatch slope), house_roof_corner, house_roof_gable, house_stairs.
- The rest (M3): timber-frame tier (house_wall_timber, house_wall_window_timber, house_roof_timber with dark shingles) and
  stone tier (house_wall_stone, house_wall_window_stone, house_roof_stone with slate).
Parts must snap: the same module size and pivot rules across tiers so a house can mix them.

## How to work
- The pipeline: tools/blender/structures/structures.py (one builder function per model, registered in BUILDERS; helpers and
  ONE shared 1024 atlas in lib.py: tiles such as bark, stone, char, clay, deck, thatch), build.py builds GLBs headless:
  `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/blender/structures/build.py -- <names>`
  (headless ONLY; never open a live Blender). check_manifest.py writes game/data/props_manifest.json rows. Read
  docs/orchestration/reports/claude-mmo-w1-structart.md for the set's style, sizes and conventions (one material = the
  atlas, origin at the ground centre, front +Z, real metres next to a 1.8 m survivor).
- The camera: perspective, pitch about 38.7 degrees from above, yaw 45; models must read from that angle.
- Do not change existing builders' output (other structures must rebuild identically). Scratch files in $TMPDIR/housekit.
  Never `rm -r` a path with tracked files. No Godot except the final import inside the verify.
- Contact sheet docs/orchestration/reports/dsc-housekit-sheet.png: render all your models headless in Blender from the game camera
  angle with a 1.8 m figure for scale, LOOK at it, write what you saw in .dsc/NOTES.md, fix anything wrong, re-render.
- Report docs/orchestration/reports/dsc-housekit.md: models, triangle counts, sizes (# ASSUMPTION unless a spec gives them),
  what the contact sheet showed.
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_blender.sh housekit [m1|m2|1]` (read it first; no stage = full).
## Milestones (milestone_done after each; the gate checks the models due by then)
- M1 the first group (verify m1). M2 the second group (verify m2). M3 the rest (verify 1). M4 manifest rows, contact sheet,
  report, full verify.
