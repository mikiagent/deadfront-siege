# Task: Blender models for the 18 camp pieces that still show Kenney placeholders

## Why
The owner said the buildings hold the game back from looking AAA ("the harbor is just a gray block"). A
previous package built a coherent hand-made Blender set (tent, workbench, fire pits, drying rack, well, pier,
catapult, fences...) in tools/blender/structures/ and it is now in the game. But 18 placeable kinds still fall
back to toy-like salmon-pink Kenney models and look out of place next to the new set. Build a Blender model for
each, in the SAME style, with the SAME builder kit, so the camp reads as one world.

## The 18 kinds (footprint in 1.92 m grid cells; what the game uses it for)
| kind | footprint | purpose / what it should look like |
|---|---|---|
| campfire_stand | 1x1 | cooking upgrade: a stone ring fire with an iron/wood spit stand and a hanging pot |
| technical_workbench | 2x1 | heavy workbench with a stone or iron anvil block, vise, hammer and tongs on it |
| grindstone | 1x1 | round sharpening stone on a wooden frame with a crank and a water trough (tool repair) |
| tent_canvas | 3x2 | cheap shade tent: canvas fly stretched over poles and ropes, open sides |
| bedroll | 1x2 | rolled-out hide/fibre sleeping mat with a rolled pillow, on the ground |
| large_box | 2x1 | big plank storage crate with rope handles and a lid (storage ~120 slots) |
| chest | 1x1 | locked storage chest, plank body, iron straps and a lock plate |
| barrel | 1x1 | open water/brine barrel: staves and iron hoops, water surface inside |
| bucket | 1x1 | wooden bucket with a rope handle (keep it under the footprint; small object) |
| fence_fortified | 2x1 | fortified fence run: thick sharpened log palisade stakes lashed with rope |
| signpost | 1x1 | wooden post with a plank sign board |
| fishing_stand | 1x1 | rack with hanging fish over a small fire or drying line |
| field_small | 2x2 | tilled small farm field: dark dirt rows (furrows) in a low log/stone border, stakes |
| field_large | 3x3 | the same, larger, with more rows |
| stone_grill | 2x2 | flat stone grill slab over a stone-ringed fire |
| straw_roll | 1x2 | a rolled straw/thatch sleeping roll on the ground |
| log_shelter | 4x4 | small lean-to/hut of logs with a thatch or bark roof, open front (sleep later) |
| cabin_bed | 2x2 | wooden bed frame with a hide mattress and fur blanket |

Fields are flat (low height); everything else should read clearly at the game's high isometric camera.

## How the kit works (read the code first)
- tools/blender/structures/lib.py: bmesh primitives that UV themselves into atlas tiles (lib.TILES: wood, plank,
  bark, log_end, char, canvas, hide, rope, thatch, weave, fiber, stone, cobble, clay, iron, dirt, fish, water,
  sign_board, bone, ...), and the GLB exporter. structures.py: one builder function per model (study tent(),
  workbench(), stone_fire_pit(), well(), drying_rack(), pier(), catapult(), _crate()) and the BUILDERS dict.
- build.py builds GLBs headless: /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P
  tools/blender/structures/build.py -- <names...>   (never the Blender MCP server; never a live Blender).
- check_manifest.py: add each kind to KIND_GLB (kind -> glb name; give every kind its own model), then run
  `python3 -I tools/blender/structures/check_manifest.py --write` to write the manifest rows (glb, aabb_m,
  art_status REVIEW + upgrade note), then without --write to check: <= 4000 tris, one material named
  structures_atlas, no embedded image, origin at the ground centre, horizontal size inside the footprint
  (+5 %), measured AABB matching aabb_m. Update NOTES for kinds whose old note talks about placeholders.
- preview.py renders a contact sheet from the game's iso angle:
  Blender -b --factory-startup -P tools/blender/structures/preview.py -- work/sheets/<kind>.png <glb name>
  Render one per kind AND one sheet with all 18 next to tent/workbench/well for comparison
  (work/sheets/all.png). LOOK at them: same warm wood/stone/canvas palette and edge density as the existing
  set, readable silhouettes, nothing floating, nothing sunk below z = 0, no grey untextured faces.

## Rules
- Do NOT change structures_atlas.png or lib.TILES (all models share it) and do NOT change any existing GLB or
  builder output: the gate hashes them. Only add new builder functions/BUILDERS entries, KIND_GLB entries and
  notes, the new GLBs and their manifest rows. You may add helpers to structures.py.
- Budget: 300-2500 triangles per piece; bevelled/segmented shapes like the existing set, not raw boxes.
- Godot runs only through /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
  (the gate does them). Never touch game/scripts or game/scenes.
- Commit at each milestone on this branch (claude/mmo-camp) with a clear message ending
  "Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>". Do not commit .import/.uid churn or game/override.cfg.

## Milestones
1. Storage and small objects: large_box, chest, barrel, bucket, signpost, bedroll, straw_roll.
   `./tools/dsc/verify_camp.sh --fast` shows PASS lines for these kinds (others may still FAIL).
2. Stations: campfire_stand, technical_workbench, grindstone, fishing_stand, stone_grill.
3. Structures and fields: tent_canvas, fence_fortified, field_small, field_large, log_shelter, cabin_bed;
   `./tools/dsc/verify_camp.sh --fast` prints VERIFY FAST PASS.
4. docs/orchestration/reports/dsc-camp-pieces.md (per kind: tris, aabb, sheet path, materials used; what you
   would improve) and work/sheets/all.png; then `./tools/dsc/verify_camp.sh` (full, runs Godot) prints VERIFY PASS.
Never edit tools/dsc/verify_camp.sh or the hash file.
