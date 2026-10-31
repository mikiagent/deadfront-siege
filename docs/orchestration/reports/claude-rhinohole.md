# RHINOHOLE: the woolly rhino's back holes

Owner: "woolly rhino has a hole on the back of its model, is that fixable?" Yes; fixed.
Branch `claude/mmo-rhinohole` (from `origin/claude/mmo-overhaul`, merged again before the gates). Not merged to canon.
**Credits: 0** (no Tripo, no Meshy).

## What the hole was
The Tripo hide (one mesh; the alpha is the same mesh with `woolly_rhino_alpha_albedo.jpg`, so one fix covers both)
had a slit along the spine just behind the hump (about 0.33 x 0.17 m, open to the sky) plus holes on the rump, the
upper flanks and behind the shoulders: 497 open edges once the glTF seam duplicates are welded. `build_rig.py`
already ran `holes_fill`, but it skips every rim that runs into a fur fin (an edge with 3+ faces where Tripo glued a
fin card across the rim), and those were the big ones. In game the double-sided shader showed the inside of the far
flank through them: dark gaps on the back.

## Fix: `tools/gait/woolly_rhino/patch_holes.py`, hooked into `build.sh` after `build_rig.py`
- Edits the .glb bytes directly. A glTF round trip through Blender re-orients the bones (checked: 6-24 joint node
  transforms change with every bone heuristic), and the 16 clips key bones in local space, so the script never
  imports/exports: only the hide primitive's vertex and index arrays grow. Joint nodes, skin, inverse binds, clips,
  textures and the saddle are byte-identical (`cmp` of the JSON joint nodes: 0 diffs).
- Rims it closes: closed loops of open edges; open chains whose ends meet through up to 6 closed (fin) edges;
  tangles (rims meeting at a vertex) are fanned to a new centre vertex. Then triangulated (beauty).
- Skin: patch corners copy their rim vertex's position and weights, so a patch deforms exactly with its rim (no
  crack at mid-run). A fan centre's weights are the rim weights summed, top 4, normalised.
- Texture: each patch corner takes the UV of the nearest hide vertex in the patch's dominant UV island (by area), so
  the patch samples the fur around it. (A plane fit was tried first and pulled a tan horn-coloured streak in on the
  rump.) Normals = the welded rim normals; faces wound to match the hide.
- Left open on purpose: the leg webbing `build_rig` cuts (rims mixing left and right leg bones below 45 % height;
  it tore when legs swung), and slivers under 5 edges that are not simple rims.
- Result: 31 patches, 337 triangles, 447 vertices; 497 -> 165 open edges (the rest: webbing and tiny fin slivers).
  Idempotent: a second run fills nothing and leaves the file byte-identical.

## Shots (`docs/orchestration/reports/rhinohole/`, Blender workbench, six views: top, rear-high, both rear
three-quarters, both high sides)
- `before_/after_rest_holes_red.jpg`, `before_/after_midrun_holes_red.jpg`: back faces hidden on a red sky, so every
  hole shows red. Before: the spine slit and ~a dozen flank/rump holes; after: none at rest, two pin-pricks mid-run.
- `before_/after_rest_ingame.jpg`, `before_/after_midrun_ingame.jpg`: double-sided like the game.
- `back_closeup_before_after.jpg`: top-down on the back.
- Re-render: `Blender -b -P tools/gait/woolly_rhino/back_views.py -- <glb> <abs prefix> [anim/run.glb 0.5] [--cull]`,
  then `tools/gait/woolly_rhino/back_sheet.sh <prefix> <out.jpg>` (ffmpeg).

## Gates (after merging canon 0348fea1)
- `check_woolly_rhino.py`: RHINO_CHECK PASS (16 clips, max stretch 11.62 as before).
- `all_tests.sh t_sp_woolly_rhino t_canim t_combat`: PASS. `t_boneparts`: FAIL "megarex has a carcass but no bone
  part list here": canon's (MEGAREX species with no bone parts); this branch touches no data or code.
- `run_all.gd`: [tests] PASS. `tools/smoke.sh`: SMOKE PASS.

## For the next agent
- `build.sh` needs the gitignored Tripo source (`work/woolly_rhino_tripo_v1.glb`); the shipped glb was patched in
  place with the same script that the build now runs.
- The brain/data joust work (claude/mmo-megajoust) is not touched here; no conflict expected.
