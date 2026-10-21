# Task: 2D resource cards with sway (trial) - CARD2D

Context: DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (the project is `game/`), shipped as a web build
(renderer gl_compatibility) viewed through a fixed orthographic iso camera (IsoCamera: yaw 45, pitch -35.26, see
game/scripts/camera/iso_camera.gd). Resource nodes (trees, bushes, berry bushes, grass/fibre, plants, rocks) are 3D
GLBs today, placed by game/scripts/world/island_scatter.gd (`_attach_batched`, models from Data.nature_families /
game/data nature manifest, files under game/assets/nature/).

The owner wants to try what Durango: Wild Lands does: resources as flat 2D cards that sway, for performance and density,
"2D but realistic and kind of look 3D". BUILDINGS STAY 3D. Read docs/design/durango-prompts/25_world_art_map_combat_observations.md
(section 1) and look at docs/reference/durango-forest-flat-trees.webp.

## Requirements

1. Bake tool (milestone 1). A Godot script `game/scripts/dev/card_bake.gd` (run: Godot --path game -- --lab=card_bake)
   that renders each resource GLB listed in `game/data/card2d.json` (you create it: at least bush-berries-a,
   bush-berries-a-empty, bush-berries-b, grass-a, plant-a, tree-common-a, tree-birch-a, tree-acacia-a, rock-a, plus any
   GLB the home island's harvest families use most) in a SubViewport with a transparent background, through an
   orthographic camera at the IsoCamera angle, in soft neutral light, and saves:
   `game/assets/nature/cards/<name>_albedo.png` and `<name>_normal.png` (view-space normals baked from the model, so the
   game's moving sun still shades the card like a 3D object), trimmed to the content, power-of-two, 512 px for small
   props and 1024 px for trees, plus the pivot (ground point) and world size in card2d.json. Re-running it is
   deterministic.
2. CardProp (milestone 2). `game/scenes/world/card_prop.tscn` + `game/scripts/world/card_prop.gd` + `game/shaders/card_sway.gdshader`:
   a quad anchored at the bottom centre, facing the iso camera (fixed camera, so a Y-axis billboard that matches the
   camera yaw), alpha-scissor (opaque pass, no sorting problems), lit (albedo + normal map) and casting shadows through
   the alpha. Sway in the vertex shader: displacement grows with height (none at the base), driven by TIME and a
   per-instance phase from world position; per-kind amplitude/speed in card2d.json (trees slow and wide, grass fast and
   small, bushes in between, rocks 0). A short rustle when the node is gathered (call a method from HarvestNode).
   Empty/regrowing state swaps to the "-empty" card where the 3D path swapped models.
3. Lab (milestone 3). `game/scripts/dev/card2d_lab.gd` (+ scene, wired like other labs through LabKit): builds a patch
   of ground and plants the SAME layout twice - left half 3D models, right half cards (about 150 props each, mixed
   kinds, a few tall trees), with the survivor standing between them; options --shot=<png> --frames=<dir> (a 3 s
   sequence of PNGs so the sway can be seen) --mode=cards|models|split. Prints one line
   `[card2d] PASS kinds=<n> cards=<n> models=<n> ms_cards=<avg frame ms with only cards> ms_models=<... only models>`.
4. Game integration behind a flag (milestone 4). `rules.json` key `"resource_render": "model"` (default stays "model"
   until the owner approves); when "card", island_scatter uses CardProp for every family that has a card and the model
   otherwise. Tapping a card resource must still select/gather it exactly like before (keep the node's collision /
   pick shape), the see-through-trees occlusion (W2-OCCLUDE) must still fade a card that hides the survivor, and the
   lab flag `--cards` turns it on for home_lab. A test `game/tests/t_card2d.gd` checks: every card2d.json entry has
   both PNGs and a pivot; a CardProp faces the camera yaw; the shader has the sway uniform and rocks have amplitude 0;
   with resource_render=card a home island spawns cards for the carded families and the nodes stay gatherable
   (call the same gather path a test already uses); with "model" nothing changes.

## Constraints
- Godot only through `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`
  with its own timeout: `gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot ...`
  (max 5 Godot runs machine-wide; never --editor). Run `--headless --path game --import` once after adding PNGs or class_name files.
- Keep game/override.cfg (it isolates the test save). Never touch other folders under .claude/worktrees/, the owner's save,
  or ~/Documents/deadfront. Do not change buildings, creatures or characters. No paid image generation.
- Typed GDScript. Do not add dependencies. Do not push, merge or deploy.
- Write `docs/orchestration/reports/dsc-card2d.md`: what shipped, the lab numbers, the shot paths, what is left.
- The verify command is `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_card2d.sh`
  (read it; it must exit 0).

Out of scope: hand-painted art, terrain repainting, the map.
