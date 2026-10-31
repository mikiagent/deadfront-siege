# STYRAFIX: styracosaurus 3x, its charge and impale rebuilt

Branch `claude/mmo-styrafix` (from `origin/claude/mmo-overhaul` cf3128fc). Not merged. No credits spent.

Owner verdict (fight lab, 2026-10-31): "make styracosaurus bigger by like 3x. the animations and brain needs some
work. Its like bugging out though, i see you attempted to make some cool charge attacks and impale? we have to fix it
but good attempt".

## What "bugging out" was

The cause was found with a 60 s scripted GOD fight (`game/tests/t_styrafix.gd -- --log=PATH`). It logs the brain state,
the clip asked for, the clip the tree plays, speed and cadence every physics frame. Before the fix it showed:

1. **The charge stuck and ran in place.** The straight charge steered through the nav path. Its goal was the survivor's
   spot plus 3 m, so a charge from more than 12 m had no path in a sparse area. It stood in `charge` on idle for its whole
   2.6 s. When it did reach her, her capsule stopped the body, and the charge clip kept running at 2.7x cadence on the spot
   for up to 0.6 s.
2. **It charged from point blank.** Nothing set a minimum distance, so it charged from 2.6-3.5 m at a survivor who was
   already against its side. The "ram" then hit at once and pinned it against her.
3. **Clips cut each other, and the idle pose blinked between them.**
   - A strike was allowed while the hold/display `alert` pose played, and the hit flinch replaced paws and charges.
   - The AnimationTree only linked non-hub clips through idle, so every strafe -> walk_back, charge -> attack or
     one-shot -> walk change passed through the idle pose for 2-3 frames.
4. **The body glided.**
   - The body moved while one-shot poses played: alert during circle/approach, alert while a spotting creature
     kept walking its roam path, hit_react at the start of a charge.
   - A hit during the run set a 0.3 s stagger. The body stopped while the charge loop kept playing.
   - A missed charge stood staggered on the running loop.
5. **It leapt.** The shared chase rule tried `pounce` on every tactical brain. The styracosaurus has no pounce clip,
   so it hopped at her on the attack_heavy clip.
6. **Frantic back-pedalling.** The back-off hop played walk_back at 3.7x cadence. This is fixed by the 3x size: the
   stride triples, so the cadence is now about 1.2x.
7. **There was no impale.** The old charge was a ram plus shove: the knockdown pose slid her 4 m along the ground. That
   was the "impale" the owner saw.

After the fix, the same fight: worst 3 brain-state changes in any second, no A->B->A ping-pong, 0 glide frames
(4+ frames on a non-locomotion clip), and the charge clip plays on every moving charge frame, stride-matched
(10.05 m/s per cadence unit, constant).

## Size (3x)

| | before | after |
|---|---|---|
| height_meters | 2.25 | **6.75** |
| on-screen length / width | 5.1 m / 1.6 m | **15.2 m / 4.7 m** (lineup: longer than the triceratops at 9.2 m, shorter than the T. rex at 19.4 m) |
| real_length_m | 11 | **19** (roster rule: on-screen 15.2 / 1.6 x 2) |
| capsule radius (0.12 x L) | 1.32 m | 2.28 m |
| turn_rate | 2.5 | **1.4** (the default for L > 14 m; the T. rex has 1.3) |
| pen tier | medium | **Apex** (over 18 m) |
| saddle class | medium | **large** (`PetRecord.saddle_size`, height >= 5 m) |
| saddle | built at 2.25 m | **rebuilt** with `tools/blender/saddles/build.sh styracosaurus` at 6.75 m (rider_in_mount re-derived) |
| player reach on it | 2.1 m | 2.93 m from its centre (`hunt.gd`, from real_length_m) |

`# ASSUMPTION`: 3x on height only. I did not use real_length_m 33 (3 x 11): that would give an 8 m wide hitbox and the
largest gameplay body in the roster. Logged as SF1 in `docs/vision/WildLandsMMO_Open_Questions.md`.

Its distance knobs now scale with it in its species `tactics` block. After the canon merge this uses COELOMOVES'
mechanism: `"base": "horned_charger"`, resolved by `TacticalBrain.resolve` / `tactics_for_def`, with explicit
overrides. STYRAFIX's own merge hook was dropped. The one addition kept: an `attack_range` in a species tactics
block sets that creature's reach (`profile.attack_range`). The triceratops keeps the old horned_charger
numbers. Values: ring 16 m, reach 6 m (the horns, not the barrel), display 9 m, charge through 6 m, strafe and hop
3 m, guard 45 m, retreat room 24 m. The horn swipe now needs her in front (not behind).

## The charge and impale

One brain state, `charge`, with phases (`TacticalBrain._charge_impale`, gated by `tactics.charge_impale`):

1. **paw**:
   - It stops, faces her at its turn rate and plays `charge_windup`: horns lowered, a fore-foot scrapes twice, a snort.
   - It paws again until it is aimed within 12 deg, at most one extra paw.
   - If she walks under its horns (closer than 5 m), it drops the charge and fights point blank.
2. **run**:
   - The line is the way it faces, locked at the end of the paw. The body is driven straight along it
     (`brain.line_dir`, no pathing).
   - Speed ramps up over 0.5 s to about 9 m/s, with the `charge` clip stride-matched (the feet speed up with it).
3. **impale**: when she is where the horn tip will be at the clip's hit frame (`impale_reach_m` 6.7 m ahead on the
   line, within 1.2 m of it), it plants and plays `impale`:
   - The running horns pass over her head and dip onto her.
   - Hit frame (`hit_frac` 0.26): the heavy hit (x charge_mult), knockdown status. She is caught at the live horn tip:
     the Head bone's pose times the mesh's frontmost rest vertex, measured once per species.
   - Until `release_frac` 0.46 she is carried on the tip as it scoops up. Then she is flung: 4 m/s up, 4 m ahead.
   - She lands about 5 m up from where she stood at the top of the arc.
4. **glance**: if she is against its flank rather than at the horns, she is shoved aside (one hit), so the run never
   stalls on her capsule.
5. **brake and recover**: on a miss it slows to a stop on the charge clip over 0.6 s. After a miss or an impale, it
   stands for 2 s (`charge_recover`: head low, three head shakes) with its stagger set. That is the punish window.

It charges only from 10 m (`charge_min_m`). It cannot be flinched while it paws, runs or impales
(`CreatureBrain.super_armor`); it can be flinched in brake and recover. Horned chargers never pounce
(`pounce_max_m` 0 in the horned_charger block).

Shots: `docs/orchestration/reports/styrafix/` were taken from an off-screen windowed run
(`--lab=creature_lab --god --impaleshots=DIR`, self-quitting). There is one frame per phase:
- the first charge: `01_paw`, `02_run`, `03_impale_hit`, `04_carried`, `05_flung`, `06_recover`;
- the second charge, which she rolls out of: `07_paw`, `08_run`, `09_recover_miss`.

`contact_sheet.png` puts 6 of them together, and `lineup.png` shows the styracosaurus, triceratops and T. rex beside
the survivor. In the lab the horn tip was 1.27 m from her centre at the hit frame; in the headless fight it was
0.08-1.03 m.

## Clips (headless Blender, `tools/gait/check_styra.py` on the skin at 6.75 m)

- New, from `tools/jaw/make_styra_impale.py`:
  - `charge_windup` (31 f), `impale` (30 f), `charge_recover` (39 f).
  - They are keyed as local rotations on idle's first pose, so the planted feet stay where idle has them. Only
    the pawing foot moves.
  - The first pass rotated the shoulders, and the front-left sole slid 6-13 cm. The shoulders came out.
  - The impale dip had put the horn 24 cm into the ground. It is reduced; it now stops at the floor.
- `charge` rebuilt with `make_charge_kick.py --crouch 0`. The old `--crouch 0.03` lowered the body on FK legs, and at
  the new size the feet sank 0.86 m.
- `charge`, `run` and `kick` were grounded with `ground_clip.py`. At 6.75 m, run sank 0.40 m, charge 0.86 m and kick
  0.26 m.
- Gate result: `STYRA_CHECK` passes on idle, alert, attack_primary, attack_heavy, hit_react, charge, charge_windup,
  impale, charge_recover, run, death, knockdown, sleep and feed:
  - stretch at most 6.9;
  - no sinking below 3 cm;
  - planted soles within 6 cm on the stand-in-place clips;
  - no moonwalk on charge or run.
- **Not touched, and still failing at the new scale:**
  - `walk` and `walk_back`: one hind foot reads +-0.64 m of "moonwalk" drift after grounding, and before grounding
    they sank 11 / 24 cm.
  - `strafe_left` / `strafe_right`: they sink 8 cm and float 6 cm.
  - `kick`: its lowest point is 9 cm up at the top of the kick, and it sinks 3.5 cm.

  These are the shared gait clips and the old kick. I reverted my grounding of walk, walk_back and the strafes because
  it made the check worse; their originals are kept.

## Shared code touched (small, opt-in)

- `creature_anim.gd`:
  - Every non-hub clip now has a direct transition to every other non-hub clip and to walk/run. Before, travel went
    through idle and the idle pose blinked in between. This is the "clips cutting each other" fix, and it applies to
    every species.
  - Three new one-shots in `ONESHOT`.
- `creature_clips.gd`: `charge_windup`, `impale` and `charge_recover` added to `OPTIONAL`.
- `creature.gd`:
  - `brain.line_dir` drives the body straight with no path. Only the horned charge sets it.
  - `brain.super_armor()` is checked beside the TyrantBrain exemption for flinch and hit_react.
- `creature_brain.gd`:
  - `line_dir` and `super_armor()` added.
  - A creature that spots a threat now stops before its sniff/alert pose, instead of gliding along its roam path.
- `tactical_brain.gd`: my styracosaurus-only release of the alert pose when the body moves was removed in the
  COMPYFEEL merge. Canon's shared no-glide rule in `Creature._physics_process` does the same for every creature.
- I did **not** add a "play a run clip whenever the body moves" rule. That is claude/mmo-compyfeel's. The styracosaurus
  charge plays its own stride-matched `charge` clip.

## Canon merge (2026-10-31)

I merged origin/claude/mmo-overhaul 4d460989 (COELOMOVES, ANKYLOAI, PINFEEL, BIGREACH, ZEBRAWALK). Conflicts:
- **tactics**: canon's resolve was kept and the styracosaurus block now names its base.
- **heavy reach**: canon's `heavy_reach_m` and my front-only rule are both in.
- **clip lists**: `pin_foot` and my three clips are both in.
- **anim_events**: both notes are kept.
- **animation tree**: my all-pairs clip links are kept with canon's pin_foot links. `_trans` now skips a link that
  already exists.

After the merge, all of these pass:
- t_styrafix, 3 runs;
- t_styraco, t_coelomoves, t_combat, t_canim, t_mounts, t_saddles, t_godlab, t_swarm;
- run_all `[tests] PASS` and SMOKE PASS.

### Second merge: COMPYFEEL (ee6bfcbb)

Conflicts:
- **charge_crouch**: canon's coil before a charge now sits beside the impale phases. The impale branch runs first,
  and the styracosaurus has no charge_crouch clip.
- **clip lists**: `charge_crouch` and my three clips are both in ONESHOT and OPTIONAL.

COMPYFEEL's no-glide rule does not touch the charge. The paw, impale and recover stop the body, so their clips keep
playing in place. The run drives the body along `line_dir` on the stride-matched `charge` clip.

After this merge, all of these pass:
- t_styrafix, 3 runs;
- t_styraco, t_coelomoves, t_compyfeel, t_combat, t_canim, t_mounts, t_saddles, t_godlab, t_swarm;
- run_all `[tests] PASS` and SMOKE PASS.

## Gates

- t_styrafix PASS (5 runs in a row on the final code). Earlier runs failed on 2 frames at the start of the run: a
  second paw was still playing, then the idle fallback showed for a frame. Fixed: the run plays the charge clip and is
  on its line from its first frame.
- t_styraco PASS. It was updated:
  - the sidestep comes after the paw;
  - the miss check waits for the recover;
  - the swipe test spawns the 3x body 5 m off, facing her.
- t_combat, t_canim, t_mounts, t_saddles, t_godlab: PASS.
- t_tactical, t_zebra, t_turnrate, t_natures, t_kicktackle, t_tame, t_noboxes, t_swarm, t_raptorfeel: PASS.
- run_all.gd `[tests] PASS`.
- `tools/smoke.sh --no-import` SMOKE PASS.

## Not done / for the next agent

- **Owner re-test is required** (fight-lab verdict says so). Numbers worth his eye:
  - the toss height: about 5 m at the top, mostly the carry on a 6 m-high horn;
  - the 2 s recover;
  - the 10 m minimum charge range.
- **The headless fight varies run to run.** Physics order is not seeded, so the number of charges in 60 s differs
  (1-5 in the session's runs). The test asks for at least 2. If it flakes, lengthen the stand phase (`ROUND_S`).
- **The hitbox is still one capsule at the centre.**
  - The head and horns reach 6.8 m ahead but have no collision, so the survivor can stand under the neck.
  - The brain uses the horn tip for the charge and `attack_range` 6 m for its strikes.
  - Her own swing reaches it at 2.93 m from its centre, the barrel's surface.
- The styracosaurus is now larger than the triceratops (true sizes are the other way round). This is the owner's call.
