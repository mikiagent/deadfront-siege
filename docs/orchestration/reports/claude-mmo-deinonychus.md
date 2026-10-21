# DEINO: Deinonychus v2 (Tripo multiview mesh, Blender rig, 9 clips)

Date: 2026-10-21. Agent: Claude Code (builder). Branch `claude/mmo-art-deinonychus` (merged `claude/mmo-overhaul` at ddaab662 first). Not pushed, not merged, not deployed.

Owner request: "and a newer deinonychus". The game still used the oldest Meshy v1 mesh with twisting pipe legs (asset-replacement.md row 1). The owner approved concept sheet v01 for a Tripo rebuild on 2026-10-18 ("Yes, use this sheet").

## Result

The game now loads the v2 Deinonychus: Tripo P1 multiview mesh, a 34-bone raptor rig and 9 authored clips. Every clip resolves in Godot (0 missing tracks). It reads as the sheet in game light: rust-banded dark-brown feathers, cream throat and legs, blue eye skin, sickle claws.

The Meshy v1 package is kept under `game/assets/creatures/deinonychus/v1/` with a `.gdignore`, so it is neither imported nor exported.

## Credits and task ids

| item | value |
|---|---|
| Tripo task | `f346e472-5a16-4209-a213-f14e3795420f`, name `deino-v2-a`, `multiview_to_model`, model `P1-20260311`, PBR, texture, `face_limit` 20000, success |
| Tripo credits | 50, spent by the previous DEINO agent; balance 3205 before, 3155 after (`deinonychus-v2/tripo/balance_*.json`) |
| Spent in this session | 0. No regeneration: geometry QA passed, so the retry in the 100-credit cap was not used |
| Package total | 50 of the 100 cap |
| Views | `game/assets/creatures/deinonychus/ref/deinonychus_{front,left,right,back}_v2.png`, made from the approved sheet with the dsc image tool (`deinonychus-v2/run_views.mjs`, sheet attached to every job, left view attached to the other three); front and right backgrounds cleaned to white. No sheet panels were cropped |

The INDEX.md row (now `INTEGRATED`, awaiting review) and the asset-replacement.md row (now `REVIEW`) record the same task id and credits.

Work files are outside the repo in `/Users/milankinzy/Documents/deadfront-dsc-work/deinonychus-v2/`:
- `tripo/`: task result and balances.
- `work/r2/`: scripts and blends.
- `out/deinonychus/`: verifier package.
- `out/clip_sheets/`, `out/shots/`: renders.

The scripts are also in `tools/deinonychus_v2/`.

## Geometry QA (raw Tripo mesh)

- 27,673 verts split at UV seams. They weld to 9,532 verts in **one island** at 1e-7 m, with 18,512 triangles.
- The 2,104 non-manifold edges are the feather shards.
- Bounds after scaling to the game's 3.6 m: 8.10 m long, 1.70 m wide.
- Anatomy matches the sheet: separate feet with three forward toes and a raised sickle claw on each digit II, arms with three claws and hanging wing feathers, a mouth slit, and a straight barred tail.
- Metallic averages 0.02. Verdict: no regeneration needed.

One defect showed up only in Godot: 7.5 % of Tripo's faces are wound against its own normals. After the weld, Blender rebuilt the vertex normals from that winding and 13 % of them pointed inward. In game the coat read blue-grey next to the warm velociraptor. The fix is in `prep2.py`:
- the 1,557 faces that disagree with Tripo's normals are re-wound;
- Tripo's shading normals are kept as split normals.

After the fix, 0 faces disagree with their corner normals in the exported GLB (`windcheck.py`).

## Rig

There are 34 joints. Every bone's local X is the body's lateral axis, so pitch is +X on every bone.

| group | bones |
|---|---|
| root | `root` |
| spine | `Hips`, `Spine1`, `Spine2`, `Chest` |
| neck and head | `Neck1-3`, `Head`, `Jaw` |
| arms | `Arm`, `Forearm`, `Hand` per side |
| legs | `Thigh`, `Shin`, `Metatarsal`, `Toe`, `Sickle` per side |
| tail | `Tail1-8` |

- Bone names follow the T. rex (`Thigh`, `Shin`, `Metatarsal`, `Toe`, `Head`), so `tools/bake_clip_speeds.py` and the t_canim helpers find the feet. `Sickle.L/R` and `Neck3` are extra.
- The joints were measured on the mesh with 10 cm grid renders and an overlay of the joint chain (`joints.py`, `overlay.py`). The knee sits forward of the hip inside the drumstick, the ankle is the backward "knee", and the jaw hinges behind the mouth slit.
- Weights start from heat weighting; no vertex was left unweighted.
- They were then cleaned by region (`build_rig.py`):
  - Limb bones keep only vertices near their own segment, with soft edges. One belly vertex had carried both arms and both thighs.
  - Toes may only be owned by the toe region. The raised digit II rides `Sickle`.
  - What a vertex loses goes to the nearest eligible bone.
  - Six smoothing passes are confined to the body region.
- The jaw is split on the mouth line measured at 1 mm/px:
  - lower jaw 100 % `Jaw`, upper skull 0 %;
  - blend only at the hinge.

## Clips

The clips are analytic digitigrade IK baked to FK at 30 fps:
- the ball of the foot is the target;
- the metatarsal leans by an authored angle;
- hip-knee-ankle is a two-bone solve with the knee pole on the forward side.

So knees can only bend forward and ankles back. All measurements below are taken on the skinned mesh in Blender (`bake.py` stats).

| clip | length | notes | lowest skin point | knee ahead / ankle behind (min, m) |
|---|---|---|---|---|
| idle | 3.0 s loop | breathing, slow look, tail sway, feet planted | 0.000 | 0.44 / 0.27 |
| walk | 0.9 s loop | planted feet stride at **2.60 m/s** in mesh units, duty 0.6, toes pivot at push-off, ankle arc in swing | -0.003 | 0.37 / 0.09 |
| run | 0.6 s loop | **6.60 m/s**, duty 0.36 with a flight phase, body pitched -7 deg, arms tucked | -0.003 | 0.29 / 0.01 |
| attack_primary | 1.2 s | draw back, lunge 0.3 m, jaw open 15 deg, snaps shut at 42 % (the game's `hit_frac`), head twist on the pull-back | 0.000 | 0.44 / 0.27 |
| attack_heavy | 2.4 s | crouch, held telegraph (sickle claws up, tremor), spring 0.46 m, two sickle rakes (first at 72 %), kick off backward, land | -0.001 | 0.24 / 0.06 |
| hit_react | 0.6 s | flinch from neutral (the game plays it at x2.0), ends at rest | 0.000 | 0.44 / 0.27 |
| knockdown | 2.5 s | shoved on the right flank, skids, drops onto its left side, stunned hold with breathing and a head lift | -0.003 (rests at 0.000) | 0.37 / 0.11 |
| death | 2.8 s | legs buckle, falls onto its left side, one leg spasm, still | -0.003 (rests at 0.000) | 0.44 / 0.27 |
| alert | 2.0 s | head low and forward, tail raised stiff, scans left and right, hiss | 0.000 | 0.44 / 0.27 |

- Strides are in mesh units. The base GLB is 3.6 m tall, so the game scales it by 1.0.
  - `tools/bake_clip_speeds.py` measured walk 2.6 / run 6.606 m/s in Godot (L and R feet equal) and rewrote only the deinonychus row of `anim_events.json`.
  - The old row was walk 4.385 and run 13.879, which made the feet slide.
  - At the game's walk (2.64 m/s) and top speed (6.6 m/s) both cadences are about 1.0.
- Clip GLBs are skeleton-only WITH the skin: 35 nodes, 1 skin, 0 meshes, 0 images, exactly 1 animation each.
- Leg bones are not twisted: by construction, and measured at most 1.8 deg in the gaits.
- The two falls are partly FK. Their leg-bone frames differ from the body's lateral axis by up to 29-35 deg while the legs fold and drape. That is the folding, not a twisted shin; the renders show no wringing.

### Problems found in renders and fixed (none showed in the verifier)

1. The thigh skin bagged when a trailing foot pulled the femur 45 deg back. Fixed by moving the swing to an ankle arc.
2. Toe tips sank 3 cm at push-off. Fixed by letting the ball rise while the toes pivot on their tips.
3. A belly vertex weighted to both arms and both thighs stretched 20x when the legs moved. Fixed by the region cleanup.
4. The lying body hovered 0.7 m on its curled tail and neck. Fixed by reducing the droop and tucking the lower arm, so the torso now touches.
5. Spline overshoot gave negative blend weights. Fixed by clamping the tracks.
6. The heavy attack's airborne ankle hyperextended by up to 0.40 m. The flight fold now flexes the right way.

## Integration (files)

- `game/assets/creatures/deinonychus/`:
  - `deinonychus.glb` (4.6 MB);
  - `anim/*.glb` (9);
  - `sheet.png` (4 rest views + 6 frames per clip);
  - textures extracted by the import:
    - `deinonychus_Color_f346e472_graded.jpg`: value lift v^0.78 on every texel, hue kept, median 0.243 -> 0.333, the sheet's own median;
    - `deinonychus_ORM_f346e472_matte.jpg`: roughness 0.55 + 0.45 r;
    - Tripo's `NormalGL` unchanged;
  - `ref/` views;
  - `v1/` (old Meshy package, `.gdignore`).
- `game/data/creatures/deinonychus.json`: new `pipeline` block. Route `tripo_mesh_opus_rig` v2, `forward_axis` -Z, `source_height_m` 3.6, mesh, texture, rig and clip notes. `authored_clips` keeps `hit_react`, so the creature still plays it and t_canim checks it. The old block is under `pipeline.v1`.
- `game/data/creatures/anim_events.json`: deinonychus `natural_speeds` row re-baked.
- `tools/deinonychus_v2/`: prep2, build_rig, joints, alib (solver), clips, bake, grade, export, sheet scripts.
- `assets/concept-art/INDEX.md` and `docs/orchestration/mmo/asset-replacement.md`: rows updated.

No `game/scripts` or `game/scenes` file changed.

## Gates

All gates were run on head `2caf950f` (the final assets). Godot always ran through scratchpad `gslot.sh` with its own `perl` alarm (silent audio). Logs are in `/Users/milankinzy/Documents/deadfront-dsc-work/deinonychus-v2/out/gate_logs/`.

| gate | result |
|---|---|
| `creature-verify.mjs out/deinonychus deinonychus --height 3.6 --require-jaw` (as the Stegosaurus v2 used it) | **ALL HARD CHECKS PASSED**, 3 warnings for the optional feed, sleep and tail_swipe. Details: 34 joints, 8 tail bones, jaw, skinned, origin at feet, height 3.60, faces -Z, spine horizontal, 9 clips in range, loops close, sheet.png. Output in `out/deinonychus_verify.txt` |
| `--import` | rc 0, 0 errors |
| every `game/tests/t_*.gd` (22 files) | all PASS. `t_save` prints its 5 deliberate SCRIPT ERRORs; every other test prints 0 |
| `run_all.gd` | `[tests] PASS`, 0 SCRIPT ERROR |
| `tools/smoke.sh --no-import` | `SMOKE PASS` |
| `creature_anim_lab` (headless, 30 s alarm) | 0 SCRIPT ERROR, 0 "couldn't resolve track", 0 clips with missing tracks |
| `creature_lab` (spawns a deinonychus), `raptor_scale_lab` (deinonychus at 3.6 m) | 0 SCRIPT ERROR, 0 "couldn't resolve track", 0 missing tracks |
| `tools/verify_rig_imports.gd` | `RIG IMPORT PASS: 99 clips through production loader` |
| shot probe log, 4 runs | each Deinonychus clip `tracks=N remapped=N missing=0`, 0 SCRIPT ERROR |
| new `Godot-*.ips` crash reports | none (newest is 2026-10-20 23:26, before this session) |

The labs exit by their alarm (rc 142). That is how a headless lab ends; all three printed their `[boot]` line.

t_canim lines for this species:
- `deinonychus walk loop 0.900 s, longest frozen span 0 %`;
- `gait cadence walk x1.02 at 2.64 m/s` (limit 3.0; the old clips glided);
- `hit_react 0.600 s at x2.00 ... free to attack 0.68 s of each second`;
- `play_clip(sleep) ... stays on idle`.

## Shots (opened and checked)

Shots were taken with my probe `deino_shots.gd` (a SceneTree script outside the repo). It builds the standard `LabKit` floor, game lighting and survivor, then spawns the Deinonychus through `creature.tscn`. The tree is advanced manually to exact clip times.

Three cameras:
- **close** and **wide**: on the game camera's azimuth, so the sun is behind the viewer as players see creatures;
- **iso**: the game's own IsoCamera.

Copies are in `/Users/milankinzy/Documents/deadfront-dsc-work/deinonychus-v2/out/shots/`.

Shots per configuration: 6 states (idle, walk, run, attack = attack_primary at 0.42 s, attack_heavy at 1.72 s, dead = death at 3.2 s) x 3 cameras = 18 PNGs, named `<config>_<state>_<camera>.png`. A 6-tile overview per configuration is `<config>_grid.png`.

| config | renderer, resolution |
|---|---|
| `fwd_1600` | Forward+, 1600x900 |
| `compat_1600` | gl_compatibility (web), 1600x900 |
| `fwd_844` | Forward+, 844x390 landscape phone |
| `compat_844` | gl_compatibility, 844x390 |

What I checked in each:
- silhouette matches the sheet;
- knees forward and ankles back on both legs;
- feet on the floor in idle, walk and attack (the planted foot's toes touch their shadow);
- no stretching or floating;
- the dead pose lies on its left side with the torso, head and tail on the ground.

From a camera on the shaded side the coat still reads blue-black under the sky light, while the lighter, redder velociraptor stays visibly warm there (matched shot `out/shots/cmp/velociraptor_shaded_side_idle.png`). The coat is dark by design (the sheet's brown-black with rust bands). A further lift would drift from the approved sheet, so I left it at the sheet's brightness.

## Known limits (honest)

- **Jaw.** The mesh has no inner mouth: only a 21 cm slit is open and the lips are fused at the front. Opening the jaw stretches a skin curtain across the front of the snout. Bites open 15-16 deg, where it reads as a bite at game distance. Wider would look cursed.
- **Stretch.** It concentrates in single sliver edges where feather shards are fused to the body: belly-thigh crease, arm feathers, sickle base. The worst single edge is 4.3x in walk and 7.3x in run (102 and 237 edges over 1.5x of 18.5k). The renders show no tearing at game scale. Run and the heavy attack are the most stretched clips.
- **Falls.** Knockdown and death fall to the left side only. The lower wing is squashed under the chest when lying, so the body rests about 3 cm up on it.
- **Optional clips.** No feed, sleep or tail_swipe; the verifier lists these as optional. `t_canim`'s sleep fallback check still has a species without sleep. Deinonychus has none.
- **Labs.** `creature_anim_lab` does not spawn a Deinonychus (its lanes are velociraptor, protoceratops, megaloceros, T. rex). It was run as the gate asks. Track resolution for this species is shown by `creature_lab`, `raptor_scale_lab`, `verify_rig_imports.gd` and the shot probe.
- **Size.** The data says 3.6 m tall (the "3x raptor" scale lab). Next to the 1.78 m survivor it is a horse-sized-plus predator. That is the existing design value; I did not change it.
- **Godot import noise.** The first `--import` after replacing the textures printed "Unrecognized UID" errors for files deleted or renamed in this tree (stale entries in the cloned cache). The next import printed 0 errors.

## W2-RAGDOLL: what must be re-tuned (not edited)

`claude/mmo-w2-ragdoll` (56890436), `game/data/creatures/ragdoll.json` `species.deinonychus`, is fitted to the v1 donor skeleton. Its bone names no longer exist:

| profile key | v1 bones | v2 equivalent |
|---|---|---|
| `feet` | `FrontFoot.L/R` | `Toe.L/R`, plus `Metatarsal.L/R` as the T. rex profile has |
| `reparent` | `BackFoot.* -> BackLowLeg.*` | delete (no such bones) |
| torso bodies | `Body` (Tail2 -> Shoulders, r 0.75), `Shoulders` | `Hips` / `Spine1-2` / `Chest`. Hips head at z 2.36, back at z 2.75, belly at z 1.5, half-width about 0.55 at the thighs |
| `Neck` (length 1.748, dir (0, -0.3, 1)) | | `Neck1` 0.38 m, `Neck2` 0.28 m, `Neck3` 0.24 m, `Head` 0.96 m |
| tail | `Tail2-5`, `Tail5_end` | `Tail1-8`, 0.61 m each, centreline z 2.24-2.44 |
| hip cone | `BackLeg.L/R` | `Thigh.L/R` (0.64 m) |
| knee hinge | `BackUpLeg.L/R` | `Shin.L/R` (0.77 m); add an ankle hinge on `Metatarsal.L/R` (0.71 m) |
| `hit_react_s` | 0.259 | 0.3 (0.6 s clip at x2.0) |
| `rest_bones` | | add `Jaw` like the T. rex |
| `mass_kg` 398.57, all radii | fitted to the v1 volume | re-fit to the new skin |

The T. rex profile in the same file is the closest template.

## For the next agent / reviewer

- **Before/after.** The old model is `v1/deinonychus.glb` with its own `v1/anim`. To view it, copy it to a scratch tree; it is gdignored here.
- **Rebuild from the Tripo GLB.** Run `prep2.py`, `build_rig.py`, `bake.py`, `grade.py`, `export.py` and `make_sheet.py` from `tools/deinonychus_v2/`, in that order, with headless Blender. The arguments are in each file's header. Then run `creature-verify.mjs <out> deinonychus --height 3.6 --require-jaw`, copy into the game, `--import`, and rerun `tools/bake_clip_speeds.py` if walk or run changed.
- **Tuning.** Clip timing and poses are in `clips.py`, as keyframe tracks per bone. The solver is `alib.py`.
- **Not done:** owner approval of the motion (the GAUNTLET clip-viewer recording), feed/sleep clips, and the ragdoll re-fit above.
