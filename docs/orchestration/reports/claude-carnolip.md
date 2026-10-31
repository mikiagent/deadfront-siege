# CARNOLIP: the Carnotaurus' protruding lip

Branch `claude/mmo-carnolip`, cut from `origin/claude/mmo-overhaul` (4e69a701), canon re-merged before the report (no new commits). Pushed, not merged to canon.

Owner: "can you fix the carnotaurus's protruding lip? I love the way it attacks." Attacks, brain, timings and every clip are untouched.

## Cause
The Tripo mesh (task 489df448) was modelled with the mouth open and a long lower jaw. `add_jaw.py --open` closes that gape in the bind pose by rotating the jaw skin up about the mouth corner. A jaw that hung down-forward then lies level, so its horizontal reach grows. The chin ended **1.0 cm (mesh units, about 13 cm in game) in front of the upper lip**: an underbite, with the lower teeth and a flat chin ledge showing in front of the snout. It was not a weighting error: the jaw skin moves rigidly with the Jaw bone as it should. Both skins share the mesh (the alpha is a texture swap via `pipeline.model_variants.alpha`), so both showed it, and one fix covers both.

## Fix
- New `tools/jaw/trim_jaw.py`: measures the chin tip (Jaw skin) and the upper lip front (Head skin at chin height) along the Jaw bone, then slides the front of the jaw skin back so the chin ends `--gap` 0.004 behind the lip.
  - The move ramps in smoothly from 55% of the chin's reach to the tip (`--from`) and is scaled by each vertex's Jaw weight.
  - A first try that scaled the whole jaw tore the cheek seal behind the teeth (the mouth lining showed through); the front-only ramp keeps the lips sealed.
  - Bones are not touched; the glTF node transforms match the old file to 1e-6, so all 16 clips play as before. Running it twice does nothing (the overbite is already gone).
- `tools/gait/build_carnotaurus.sh` runs it right after `add_jaw.py`, so a rebuild keeps the fix.
- `tools/jaw/render_head.py` gained `--albedo` to render a skin swap (alpha shots).

## Shots (`docs/orchestration/reports/carnolip/`)
Blender Workbench, camera on the Jaw bone, jaw forced to 0 deg (closed), 18 deg (mid-bite) and 38 deg (wide open, the bite and roar reach 34-40).
- `before_sheet.jpg`, `after_sheet.jpg`: rows closed / mid / wide; columns regular side, three-quarter, front, then alpha side and three-quarter.
- The single frames: `{before,after}_{reg,alpha}_jaw{0,18,38}_f000_{side,threeq,front}.png`.

## Tests (after the canon re-merge)
- t_sp_carnotaurus PASS, t_boneparts PASS, t_canim PASS (there is no t_hitboxes on canon).
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Credits
Tripo 0, Meshy 0.

## Not done / for the next agent
- No in-game (Godot) head shot; the shots are Blender renders of the shipped glb.
- The front view still shows a little of the chin's flat top under the upper teeth when closed; it no longer sticks out in front.
- The lower teeth in the front 45% of the jaw are slightly closer together (they slid back with the skin).
