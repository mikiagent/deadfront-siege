# Report: COMPYREVERT (the old compsognathus mesh back, every newer clip kept), Claude

Branch `claude/mmo-compyrevert`, cut from `origin/claude/mmo-overhaul` (f54eb43f), merged again with canon after
HOPSTRAFE landed (a3fa0f45), then with canon 2eecfc3e (bigstomp). Pushed, not merged.

Owner, verbatim: "I think i want the old model for the compsagnathus back. the new one is worse somehow. I might get
another reference for it".

## What shipped
- **Mesh:** `compsognathus.glb`, `compsognathus_Image_0/1/3.jpg`, `compsognathus_normal.png` and their `.import`
  files are back from `8ea31a78^`. That mesh already carries the dsc jaw from 6dc14241 (the glb grew 13488332 ->
  13525980 bytes there and has a `Jaw` bone under `Head`), so the old jaw is back with it. The green remodel's three
  texture files are removed.
- **The green remodel is kept** as `work/compsognathus_green_v2.glb` (force-added: `work/` is gitignored). Its
  gait plans are kept as `strafe_green_v2`, `strafe_v1_green_v2` and `charge_green_v2` in
  `tools/gait/compsognathus.json`. Its clips are in git at 42e4a5e7.
- **Same skeleton, different proportions.** Both meshes use the Velociraptor donor's bone names (the green one
  adds an unused `neutral_bone`), but v1 is 0.763 m tall and 1.90 m long against v2's 0.502 x 0.998. Its hind
  legs are 1.62x longer, and its feet are about 3x longer. The v2 clips cannot play as they are, so:
  - **v1 originals** (the remodel's copies were `transfer_clips.py` transfers of these, and nothing changed them
    after): walk, run, alert, attack_primary, attack_heavy, feed, hit_react, knockdown, death, sleep.
  - **Rebuilt on the v1 rig** with the same tools and settings that made the v2 clips. The settings were checked
    first: re-running each command on the v2 mesh reproduced the shipped v2 glb byte for byte, except walk_back,
    whose make_gait has changed since.

    | clip | tool and settings |
    |---|---|
    | idle (nervous) | `make_nervous_idle.py` |
    | investigate (combat idle) | `make_investigate_idle.py --clip combat --heel-roll 90` |
    | charge_crouch | `make_investigate_idle.py --clip charge_crouch --heel-roll 90` |
    | strafe_left / strafe_right | `make_gait.py compsognathus.json strafe --as strafe_left/right --travel ±1,0,0` |
    | charge | `make_gait.py compsognathus.json charge` |
    | walk_back (backpedal) | `make_gait.py compsognathus.json strafe_v1 --as walk_back --travel 0,1,0` |
    | hop_back, leap_back, pounce, dodge_left/right | `make_leap.py` |

    The idle, leap and crouch tools scale by the rig (length, hip height). make_gait plans are in metres, so
    `compsognathus.json` has every length (stride, lift, spread, offset, crouch, bob, sway) x1.62, the v1/v2 leg
    ratio. On v1's long feet the v2 toe curl dragged the toes (2 cm and 1 cm toe peak at game scale). So the strafe
    curls 10 deg with lift_shape 0.4 (9 cm peak, the toe leaves the ground at once), and walk_back curls 5 deg with
    lift 0.065 (6 cm).
- **Data (`compsognathus.json`):**
  - `source_height_m` 0.7625 and `source_length_m` 1.9017: the v1 mesh, as before the remodel.
  - `height_meters` stays 1.2. RiggedModel measures the mesh (0.7625), so the old compy stands 1.2 m tall in game,
    as the green one does, and is 3.0 m long (= `real_length_m` 3.0; the green one was 2.39 m).
  - `pipeline.version` 1 and `mesh_source` i2m_v1, a `revert_2026_10_31` note, the remodel block kept as
    `remodel_2026_10_28_reverted`.
  - The v1 eye points (radius 0.03, measured from this mesh by EYETRAILS round 3) and the v1 `look` text.
- **Natural speeds (`anim_events.json`):**
  - walk 0.331 and run 2.508: `bake_clip_speeds.py --dry-run` gives exactly these, the pre-remodel numbers.
  - strafes 1.326, walk_back 0.612, charge 4.837: measured in Godot as the planted-toe speed at cadence 1 and size 1.
  - The walk_back note now names `strafe_v1`.
- **Kept unchanged:** hitboxes rows (calibrated Jaw radii), ai.json swarm tactics, ragdoll row, the compy code paths
  (crouch-charge, leaps, pounces, strafe jumps, investigate, HOPSTRAFE hopping).

## A shared fix (affects every species)
`CreatureAnim` matched cadence to a natural speed baked at body size 1.0, but the genome size (0.85-1.15) scales the
model. So a 0.91 or 1.14 animal's planted feet slid 9-14 % of every step. t_compyfeel's strafe check failed on that
(3.4 cm against a 3.3 cm limit), not on the clip: the strafe's own slip is about 1 cm.

`set_move_speed`, `set_move_velocity` and `set_gait_clip` now divide the speed by `size_scale()`. t_compyfeel's
"charge cadence = speed / natural speed" check now multiplies by the size. t_ai, t_canim, t_smilorun, t_raptorflank,
t_ankyloai, t_tactical and t_swarm were re-run after it.

## Gates (final head, after the canon 2eecfc3e merge)
- PASS: `t_compyfeel`, `t_hopstrafe`, `t_bigstomp`, `t_ai`, `t_smilorun`, `t_raptorflank`, `t_ankyloai`, `t_hitboxes`, `t_canim`, `t_noboxes`, `t_combat`, `t_tactical`,
  `t_dodgetext` (the compy leap / "Missed" test; there is no t_compyjumps).
- t_compyfeel planted-toe slide, as a share of a step:

  | clip | slide (median / worst) | limit (median / worst) |
  |---|---|---|
  | strafes | 1.3 / 2.0 cm | 3.8 / 7.6 cm |
  | charge | 0.6 / 0.8 cm | 9.2 / 18.4 cm |
  | run (the v1 original) | 4.4-9.5 / 12.6-15.1 cm | 10.1 / 20.2 cm |

  The run's number depends on the speed rolled for the run (stats are not seeded). It passed in 5 of 5 runs, but
  it is the thinnest margin.
- **`t_swarm` FAILS, on canon too.** A temp checkout of canon a3fa0f45 with the green mesh fails 4 checks; this branch
  fails 3 of the same 4:
  - bolder in numbers;
  - circling-strafe frames 46 < 60;
  - surround gap 237 deg;
  - plain bite share (canon only).

  HOPSTRAFE made the compy hop instead of strafe and left t_swarm out of its gate list, so t_swarm needs updating on
  canon.
- `python3 tools/audit_gaits.py --gate`: GATE PASS. The brief says `tools/gait/audit_gaits.py`; the tool is
  `tools/audit_gaits.py`. Compy walk drift L -0.302 / R -0.055, run -0.425 / -0.399, no moonwalk.
- `check_leap.py` on the v1 rig (game scale 1.574):
  - leaps: penetration 0.00 cm, planted slide 0.00 cm, feet peak 12-19 cm;
  - pounce jaw 28 deg;
  - investigate and charge_crouch (`--grounded`): 0.00 cm slide, no penetration.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS. The full `all_tests.sh` sweep is at the end
  of this file.

## Lab shots (`docs/orchestration/reports/compyrevert/`)
- `contact_sheet_1.png`: idle, investigate, alert, walk, walk_back, run, charge_crouch, charge, strafe_left,
  strafe_right, feed.
- `contact_sheet_2.png`: attack_primary, attack_heavy, pounce, hop_back, leap_back, dodge_left, dodge_right,
  hit_react, knockdown, sleep, death.
- Each is 6 frames per clip, side-on beside the survivor, from `creature_lab --clipshots` windowed at
  `--position 6000,3000` with `--skip-charcreate`, self-quitting.
- `attack_primary_hit.png` and `attack_heavy_hit.png`: the hit frames.
- The raw 1280x720 frames (38 MB) are not committed.

## Known issues / next agent
- The v1 jaw is the dsc jaw on a mouth-shut Meshy mesh, so the lips stretch when it opens (the known limit, see
  creature jaws notes). It is what shipped before the remodel.
- The v1 run is the old clip; its slide margin is thin (above). Rebuild it with make_gait if Milan sees a skate.
- In-place strafe and walk_back strips were not rendered outside the game; the in-engine contact sheet covers them.
- No clip-viewer mp4. The contact sheets stand in.
- Coming back to the green model: copy `work/compsognathus_green_v2.glb` over the base, rename the `*_green_v2`
  plans in `compsognathus.json`, restore the anim/ glbs and data from 42e4a5e7, and rebake.

Credits: none (Tripo 0, Meshy 0, Codex 0).

## Full sweep (`tools/all_tests.sh`, 210 tests, before the 2eecfc3e merge)
- pass=195 fail=15 at JOBS=6, on a machine running about 20 other Godot processes.
- Re-run at JOBS=3:
  - **t_playerturn, t_tribe, t_noteleport pass.** They failed only under load.
  - **t_ragdoll's compsognathus slope death passes** (peak stretch 20 %); it failed only under load.
  - **These fail identically on an unmodified canon checkout (2eecfc3e), so none of them is from this branch:**
    - t_ragdoll (velociraptor slope, 75 %);
    - t_turnrate (the bite to the side);
    - t_kicktackle (the tackle lunge, 0.13 m);
    - t_colors (stegosaurus placeholder boxes);
    - t_stationstate (taming_pen_medium);
    - t_uinav (the right-column labels);
    - t_levelfx (the phone banner);
    - t_savefix (compile error: `Game`);
    - t_buildspeed (the home_grassland digest).
  - **t_perfgates and t_landmarks were not re-run.** They are a build-time budget and a seed check, and this
    branch does not touch either.
  - **t_swarm also fails on canon** (see above).
