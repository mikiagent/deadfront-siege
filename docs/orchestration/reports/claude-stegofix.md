# STEGOFIX: the blocky stegosaurus is gone, two rigged variants ship

Branch `claude/mmo-stegofix` (from `origin/claude/mmo-overhaul`). Not merged to canon. No credits spent.

## What the blocky stegosaurus was
It was not a stand-in model. It was the procedural box placeholder in `game/scripts/creatures/creature_view.gd`.
- Since 2026-09-21 (commit ab489b0c), `setup()` had `force_safe_placeholder := def.id == &"stegosaurus" and not allow_stegosaurus_rig`.
  Every stegosaurus in the game (wild, pens, the pet stage, labs) skipped its GLB and was built from boxes.
- `_build_placeholder()` then added a stegosaurus-only "readable low-poly fallback" on top of the generic boxes:
  seven box plates and four box spikes. That is what the owner saw.
- The override was meant for the v1 transplanted Meshy rig ("catastrophic weights, worm-like stretching").
  The v2 Tripo mesh with the Opus rig replaced v1 on 2026-10-18, but nobody lifted the override.
  Only `ragdoll_lab` set `allow_stegosaurus_rig = true`, so the v2 model only ever showed up in that lab.

Removed: the override flag, the static `allow_stegosaurus_rig` and its use in `ragdoll_lab.gd`, and the plated-box
branch. If a model ever fails to load now, `push_error` names the GLB instead of the box falling back silently.
No other path draws a stegosaurus: the gobkit `tools/standins/gobkit/Stegosaurus.glb` and `v1/` are referenced by no code.
Species with no GLB at all (ankylosaurus, triceratops and others) still use the generic boxes. That is out of scope here.

## The two models
`bakeoff/stegosaurus-v2` has three Tripo exports: graded (the one canon ships), ochre and museum. All three are the same mesh
(17,899 vertices), the same 34-bone Opus rig and the same clips. They differ only in the albedo map. Per its REPORT.md,
the owner **rejected** the museum recolour and the gentle grade replaced it. That leaves two variants:
- `graded`: the shipped grey-brown (the GLB as authored).
- `ochre`: olive hide with amber-edged plates (`stegosaurus_tex_ochre_albedo.jpg`, extracted from `tripo_stegosaurus_ochre.glb`).

They are declared in `stegosaurus.json` under `pipeline.model_variants` (variant id -> albedo file).
`CreatureView._apply_model_variant()` swaps the base-colour map before coloration runs, so the natural colour
patterns still layer on top.
- # ASSUMPTION: the pick is `CreatureView.pick_variant(def, "<id>@<rounded spawn position>")`, a hash of the spawn
  identity. It is deterministic and 50/50 (208/192 over 400 keys).
- `Creature.spawn` picks only when no variant is passed in. `PetRecord` and capture already persist `variant`,
  so a tamed animal keeps its look.

Rigging and animation were already done on this mesh (Opus rig, 9 clips, plus the gait/kick/charge clips from 10-27 and 10-28).
I did not re-rig. I checked every clip on the skinned mesh and fixed what failed:
- **Sinking**: charge -4.1 cm, kick -4.4, death -3.7, knockdown -6.6, strafes -2.3.
  New `tools/gait/ground_clip.py` lifts the root by the deficit on those frames, sampled at 30 fps. It appends a track and leaves the rest of the GLB byte for byte.
- **Moonwalk**: none. Planted feet slide backwards in walk and run (-0.6 to -1.16 m) and forwards in walk_back.
- **Stretch**: worst edge ratios of 2.5-10x. They are in 2-5 cm edges in the chest folds and at the neck plate bases,
  and they cannot be seen at game range.
  - The shipped T. rex reads 8-24x on the same metric.
  - I tried Laplacian weight smoothing over 6k vertices; it made walk and idle worse (3.4 -> 4.6), so I dropped it.
  - Known look: in `charge` the small neck-base plates crowd together for a few frames, visible only in close-up.
- New `tools/gait/check_stego.py` is the gate. It checks stretch (FAIL above 12), sinking/floating and stance drift on the skin. Result: `STEGO_CHECK PASS`, 14 clips.

## Shots (`docs/orchestration/reports/stegofix/`)
Taken from off-screen windowed runs (`--position 6000,3000`) of the new self-quitting `stegofix_lab`.
- `contact_sheet.png`: 14 clips at 30% and 60%, graded on the left, ochre on the right, survivor between them.
  Full-size frames: `sheet/*.png`.
- `world_wide.png`, `world_close.png`: temperate_45 crater herd (2 ochre + 1 graded), all GLB with 0 boxes, in the game's iso camera.
  - The lab turns the herd broadside for the shot.
  - The lab also closes the world atlas, which had popped open in one run.

What reads wrong, and was left as is:
- death and knockdown end on the side with the plates lying flat along the ground. This is the reviewed bakeoff motion.
- One stegosaurus in the crater herd stands at the islet's sand edge.

## Gates
- `tools/audit_gaits.py --gate`: GATE PASS. The stegosaurus is listed as unchecked (not +z facing); `check_stego.py` covers it.
- `check_leap.py`: no stegosaurus leap clip, so not applicable.
- `game/tests/t_stegofix.gd`: PASS. It checks:
  - no override or plated-box code is left;
  - '' / graded / ochre all draw the GLB with zero Box or Cylinder meshes and the right albedo;
  - the 9 listed clips plus walk_back, strafes, kick and charge are authored and loaded;
  - the toes stay within 6 cm of rest in idle, walk, attacks, hit_react and alert;
  - the pick is 50/50 and deterministic;
  - a wild spawn gets a variant.
- t_combat PASS, t_canim PASS, run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## For the next agent
- Adding a third look is one albedo file plus one line in `model_variants`. A different mesh needs its own GLB path, and the code does not support that yet.
- Real stretch fixes would come from re-weighting the neck and chest in the bakeoff's `work_rigged_graded.blend` (outside the repo), not from smoothing the GLB.
