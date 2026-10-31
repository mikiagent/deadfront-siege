# Report: COMPYFEEL (compy strafes, crouch-then-charge, combat idle; the shared no-glide fix), Claude

Branch `claude/mmo-compyfeel`, cut from `origin/claude/mmo-overhaul` (cf3128fc). Pushed, not merged.

Owner (Milan, verbatim): "compsagnathus needs a strafe left and strafe right animation. its opening attack looks like
its gliding towards the player when it should lower its center of gravity and charge. It should also have a head
twitching idle animation, it should look like its itching for a fight". Added mid-run: "deinonychus actually has the
same problem where when it charges it glides instead of running" (ankylosaurus attacks glided too).

## What the glide was (measured, not guessed)
A probe ran each species against a still survivor and compared, frame by frame, body speed with planted-toe speed
per clip. Three separate causes:
1. **Shared code: the body moved under one-shots.** `creature.gd` kept walking the body while `CreatureAnim` was
   busy with a one-shot, and the gait call was ignored, so the clip slid. The compy's opening move was its spotting
   `alert` playing while it charged in at 4.5 m/s (glide ratio 0.99). The bite also slid after a walking survivor
   (`bite_track`), and so did attacks generally.
2. **Deinonychus run and charge shuffled.** `make_gait` swung the foot with a 45 deg toe curl and rolled it about
   the foot bone's tail instead of the toe tip. The toe tips cleared the ground by only 3-4 cm on a 2.87 m animal,
   and dug 10-22 cm into it at push-off. Read as feet sliding along the ground: 33 cm planted slide per step.
3. **Compy clips were too short-stepped for its speeds.** The old strafe (0.15 stride) ran at cadence 6.3 while
   circling at 3.6 m/s, a buzz rather than steps. The charge reused the run at cadence 5 (11.75 m/s).

## What shipped
**Shared fix (every species; coelomoves and ankyloai inherit it).** In `creature.gd` `_physics_process`, the
body never moves under a one-shot:
- an attack (`CreatureAnim.ATTACKS`) or a timed windup plays in place;
- any other one-shot (alert, sniff, hit_react, feed, charge_crouch) gives way to the stride-matched gait;
- leaps (`CreatureAnim.LEAPS`: hop_back, leap_back, pounce, dodge_left/right) keep moving on their own arc.

Locomotion was already stride-matched (`set_gait_clip` / `set_move_velocity`: cadence = speed / natural speed).
`RiggedModel.LOOPING` now lists strafe_left, strafe_right, walk_back and charge, as the raptorfeel report flagged.

**`tactical_brain.gd`:**
- `_start_charge`: when the rig has `charge_crouch`, the body holds still facing the prey while the coil plays, then
  runs. A straight charge locks its line at launch, not before the coil.
- `aware_idle()` override: in the fight but not striking, a rig with an `investigate` loop stands in it. Only the
  compy and the velociraptor have one, and the velociraptor is RaptorPackBrain, so that override does not reach it.
- `bite_track` no longer slides the body during the bite. `_bite_reach()` leads it instead: on prey walking away,
  the charge or lunge closes by her outward speed x the time to the contact frame before biting (`_strike`,
  `_charge`, `_lunge`). Landed share on a walking survivor: 0.62 (t_swarm, limits 0.45-0.85).

**Compy clips** (headless Blender, no credits), in `game/assets/creatures/compsognathus/anim/`:
- `strafe_left` / `strafe_right`: rebuilt with `make_gait.py`. 0.5 s loop, stride 0.26 (was 0.15), feet planted
  wider (new `spread_hind`), 14 cm toe lift at game scale, head held steady. It reads as step-out / close-in
  side-steps with no crossing. Natural speed 1.243 m/s (was 0.574), so circling at 3.6 m/s is cadence 2.9.
- `charge`: a new low sprint loop. 0.333 s cycle, stride 0.62, body leaning 18 deg, arms tucked, tail up, 17 cm
  toe clearance. Natural speed 4.446 m/s.
- `charge_crouch`: a 0.42 s one-shot. The body drops 34 % of hip height, chest dips, head drops level, the feet
  roll heel-up on planted toes, arms tuck, tail lifts, jaws part. It ends in the charge's lean.
- `investigate`: the combat idle, 3.0 s loop. Low stance, weight bouncing on pumping knees (6 bounces), the head
  snapping between hard tilts (up to 36 deg) and jerking up and down, jaw chatter and a hiss, tail flicks,
  twitchy weight shifts. The snout stays on the prey, and its calm wild `idle` is untouched.

**Deinonychus:** `run.glb` and `charge.glb` were regenerated from `tools/gait/deinonychus.json` with curl 15, lift
0.11-0.12 and no toe roll on the charge. Toe clearance is now 33 cm and 52 cm, and ground penetration +0.0 and
-1.4 cm. Stride and cycle are unchanged, so the baked natural speeds still hold. Walk and strafes are untouched.

**Tools:**
- `make_gait.py`: `spread_<end>` and `reach_roll` parameters. Toe roll now pivots on the `*_end` toe tip, a fix for
  future runs of every species; existing clips are unchanged.
- `make_investigate_idle.py`: `--clip combat`, `--clip charge_crouch`, and `--heel-roll DEG` (digitigrade heel
  lift in a crouch).
- `tools/gait/compsognathus.json`: new strafe and charge plans. The old strafe plan is kept as `strafe_v1`.
- `anim_events.json` natural_speeds.compsognathus: strafe_left/right 1.243 (`_len` 0.5), charge 4.446 (`_len` 0.333).

## Gates
- `t_compyfeel` PASS:
  - The compy clips load. The loops loop, and charge_crouch is a one-shot. Both LOOPING lists hold the gait loops.
  - Planted-toe slide per step, with the body carried at fight speed (limit 10 % of a step median, 20 % worst):

    | clip | speed | slide (median / worst) |
    |---|---|---|
    | compy charge | 9.4 m/s | 4.4 / 4.6 cm of 74 cm |
    | compy strafes | 3.6 m/s | 0.9 / 3.2 cm of 31 cm |
    | compy run | 7.2 m/s | 4.7 / 7.5 cm of 84 cm |
    | deino charge | 12.6 m/s | 8.2 / 10.7 cm of 197 cm |
    | deino run | 8.4 m/s | 6.3 / 9.5 cm of 159 cm |

    The old deinonychus run read about 33 cm of 159. At half cadence the check fails (31 cm and 114 cm), so it
    can catch a glide.
  - Live fights, compy 25 s, deinonychus 20 s, ankylosaurus 15 s: no body movement under a non-locomotion clip.
    One handover frame per strike is allowed, because the brain switches the clip after that frame's move.
  - The compy coils in charge_crouch with its body still (127 frames).
  - The charge plays the charge clip at cadence = speed / natural speed (58 frames, 0 off by more than 5 %).
  - Circling plays the strafes (178 frames).
  - Aggro and standing still plays the combat idle (161 of 161 frames).
- `check_leap.py --grounded`:
  - investigate: slide 0.00 cm, penetration -0.81 cm, PASS.
  - charge_crouch: slide 0.00 cm, penetration -0.43 cm, PASS.
  - Loops, penetration only:

    | clip | penetration | toe peak |
    |---|---|---|
    | compy strafes | -2.06 cm | 6 cm |
    | compy charge | -0.42 cm | 17 cm |
    | deino run | 0.00 cm | 33 cm |
    | deino charge | -1.41 cm | 52 cm |

    The old shipped compy strafe was -1.72 cm. The old deino run and charge were -10.6 and -22.2 cm.
- `python3 tools/audit_gaits.py --gate`: GATE PASS (no moonwalk).
- `t_combat`, `t_canim`, `t_godlab`, `t_swarm`, `t_tactical`, `t_dodgetext`, `t_labspawn`, `t_raptorfeel`, `t_ai`:
  PASS. There is no `t_*compy*` test besides the new one; t_swarm, t_tactical and t_dodgetext are the compy ones.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/compyfeel/`)
In-engine contact sheets from `creature_lab --clipsheet` (windowed at `--position 6000,3000`, `--skip-charcreate`,
self-quitting). Each has a front three-quarter row over a side row, 8 frames:
- compy: `investigate` (combat idle), `charge_crouch`, `charge`, `strafe_left`, `strafe_right`, and `idle` (the
  calm idle, for comparison);
- deinonychus: `run`, `charge`.

## Notes / for the next agent
- ASSUMPTION: compy speeds are unchanged. A charge is about 9-12 m/s, roughly 2-2.5x the charge clip's cadence (a
  0.13-0.16 s stride cycle). If it still reads too frantic, lower `ai.json archetypes.swarm.tactics.charge_speed_mult`
  (1.3) rather than the clip.
- The strafe walk at 3.6 m/s is cadence 2.9 (about 6 side-steps a second). A wider stride sank the hock skin past
  2 cm, so a slower feel needs a lower `circle_speed_frac`.
- Deinonychus walk and strafes still use the old curl-45 plan, which also drags its toes (8 cm toe peak on the walk).
  They were not part of the complaint and are left alone. Rebuild them the same way if Milan sees it.
- Other species built with `make_gait` and a high curl (check `swing_curl_*` in `tools/gait/*.json`) may shuffle the
  same way. Regenerating them now also picks up the toe-tip pivot fix.
- The external verifiers (`~/Documents/DeepseekCLI/verifiers`) are not on this machine. I used the repo's checks.

Credits: none (Tripo 0, Meshy 0, Higgsfield 0).

## Merge with canon e002a994 (2026-10-31)
- Merged in origin/claude/mmo-overhaul (ANKYLOAI, PINFEEL, ZEBRAWALK, HEATEDGE, BIGREACH, RETIREPROTO). Both clip
  lists are kept: `RiggedModel.LOOPING` has pinned plus the strafes, walk_back and charge, and `CreatureClips.OPTIONAL`
  has pin_foot plus charge_crouch. The fight-lab ANKYLOAI note and the no-glide note are both kept.
- The no-glide rule against the new code:
  - ClubTailBrain stops the body for its tail moves (they play in place with their own foot steps), so the rule never
    has to step in.
  - The rex pin_foot hold is not a one-shot (`start_pin` clears `_busy`), and `creature.gd` returns before locomotion
    while `pin_victim` is set, so the rule cannot release the pin.
- Gates after the merge, all PASS: `t_compyfeel` (ankylosaurus fight under ClubTailBrain: 0 glide frames),
  `t_ankyloai`, `t_pinfeel`, `t_combat`, `t_canim`, `t_godlab`, `t_swarm`, `t_tactical`, `t_raptorfeel`, `run_all.gd`
  `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## Merge with canon 4d460989 (COELOMOVES, 2026-10-31)
- `tactical_brain.gd`: both sides are kept. Canon's tactics profiles (`resolve` / `tactics_for_def`), the territorial
  state and the RAPTORFEEL investigate hold (moved into TacticalBrain) sit beside the `charge_crouch` coil and the
  `aware_idle()` combat idle.
- One behaviour call: canon's spot hold triggered on any rig with an `investigate` clip, which after this branch
  includes the compy. That would have made a swarm stand and wait 3 s on first sight. The hold now also needs a
  `sniff` clip. That keeps the hold for the velociraptor (the only species with both), while the compy's
  investigate stays its combat idle and it commits at once as before.
- `fight-lab.md`: canon's Coelophysis, Gallimimus and Megaloceros rows and the profile and territorial notes are kept,
  beside the compy and deinonychus rows and the no-glide note.
- Gates after the merge, all PASS: `t_compyfeel`, `t_coelomoves`, `t_raptorfeel`, `t_ankyloai`, `t_pinfeel`,
  `t_combat`, `t_canim`, `t_godlab`, `t_swarm`, `t_tactical`, `run_all.gd` `[tests] PASS`,
  `tools/smoke.sh --no-import` SMOKE PASS.
