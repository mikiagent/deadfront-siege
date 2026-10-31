# MEGAJOUST: the joust brain, and the megaloceros antlers rebuilt

Branch `claude/mmo-megajoust` (from `origin/claude/mmo-overhaul` 1bb8adec; canon merged back in at 0a289d98). Not merged to canon.

Owner, verbatim:
- "megaloceros strafe looks really awkward. I think a deer would normally charge and do a circle and charge again. Like a joust. ... this would be a success if the strafe animation wasn't breaking ankles and if the antlers turned out okay"
- Doe: "Have the doe tackle mainly, like a give it your all tackle, low center of gravity, and have it joust like the male. It should be more desperate ... running away and then charging/tackling but more running than charging"
- "like honestly the jousting brain is good for many of the four legged animals"

## Credits
Tripo 0, Meshy 0. Antlers and clips are Blender scripts.

## The joust (`game/scripts/creatures/brains/joust_brain.gd`, `JoustBrain extends TacticalBrain`)
- Opt-in: any species whose tactics profile has a `joust` block gets it (`Creature._make_brain`, `JoustBrain.wants`).
- The loop:
  1. **Tell.** `charge_crouch` where the rig has it, body still, turning to the threat.
  2. **Pass.** TacticalBrain's straight charge, `overshoot_m` past the threat. Contact is the ram impact, which knocks her back. Since the canon merge, the KNOCKDOWN tiers apply: the test logs "knocked down" for every jouster.
  3. **Run off.** Only with `run_off_s` (the doe).
  4. **Wheel.** A wide turn at the run with radius `turn_radius_m`, on `run_turn_left`/`run_turn_right` where the rig has them, else on the run, until it faces the threat from `min_run_m`. Then the next tell.
- What it never does: strafe, side-jump (`_start_dodge`), back-leap (`_start_hop`), feint or circle-strafe.
- Point blank, the profile's `point_blank` moves still go (stag hook, stomp, kick).
- Tame and ride are unchanged: pets use PetBrain.
- Joust keys: `turn_radius_m`, `overshoot_m`, `min_run_m`, `align_deg`, `wheel_max_s`, `run_off_s`, `display`, `display_after_s`, `charge_max_s`, `hit_mult`, `shove_m`, `toss_deg`. A variant's `tactics.joust` merges over the species'.
- Fixes found by watching it:
  - The body yaw lagged the wheel by ~10 deg, a crab that slid the hooves. It now faces its heading (`strafe_face` on an aim point).
  - A survivor standing in the line held the runner for the whole charge. Each pass now tosses her 30 deg off the line (`charge_toss_deg`).
  - A survivor who follows it round stays inside the wheel and is never lined up. After half of `wheel_max_s` lined up, or `wheel_max_s` in all, it passes anyway.
  - The run-off and wheel outran the leash and the far give-up. A jousting animal's `aggro_radius` and perception stretch to the joust's reach, but only while it is in the fight; spotting prey is unchanged. A grazer's `guard_m` grows by two wheel radii plus the overshoot.
- Shared code touched, one line each:
  - TacticalBrain's straight charge steers to a carrot at most 8 m ahead on its locked line. Before, a pass longer than 12 m got no direct steer without a navmesh.
  - `CreatureClips` LOOPING/OPTIONAL and `RiggedModel.LOOPING` gained `run_turn_left`/`run_turn_right`.

## Who jousts
| Species | Numbers (ASSUMPTION, Open Questions MJ1-MJ3) | Turn clips |
|---|---|---|
| Megaloceros stag | wheel 9 m, overshoot 8 m, next pass from 9 m, opens with the rut roar | yes |
| Megaloceros doe | stag's, plus: low tackle as her charge (x1.6, 3.5 m shove), runs straight off 3.5 s after every pass, overshoot 6 m, no display, first flight 5 s | yes |
| Woolly rhino (and its alpha) | wheel 8 m, overshoot 6 m, paw display; the horn toss on impact stays | no (the run) |
| Triceratops (and its alpha) | wheel 10 m, overshoot 7 m, charge_max_s 4 | no (the run; no charge clip either) |
| Zebraceratops | wheel 6 m, overshoot 5 m, no display | no (the run) |

Not opted in, as briefed:
- pachycephalosaurus (claude/mmo-pachybull),
- styracosaurus (its impale charge on canon is its own charge state; the joust would replace it),
- stegosaurus and ankylosaurus (claude/mmo-stegospin).

## Megaloceros clips (`tools/gait/megaloceros/clips.py`, both sexes)
- `charge_crouch` (the tell):
  - stag: antlers lowered level, two forehoof scrapes;
  - doe: chest and head dropped, hind legs gathered.
- `run_turn_left`/`run_turn_right`: the gallop on a 9 m arc (`TURN_R`, equal to `turn_radius_m`).
  - Stance hooves follow the arc: `ground()` rotates them about the arc centre. Swing hooves are carried along it.
  - The stag banks 9 deg into the turn. The doe does not bank: her run already sits at the stretch limit, 11.8 of 12.
- Doe `charge`: the low all-out tackle run, with the chest dropped and the head and neck thrust out.
- Every existing clip and the doe GLB rebuilt byte-identical. `check_megaloceros.py` now also checks moonwalk on charge and the turn clips: PASS for both sexes.

## Antlers (`tools/gait/megaloceros/build_rig.py` `build_antler`, `stag.json` span_m)
- Compared with the owner's stag sheet (`.claude/worktrees/species-ref/megaloceros_owner_sheet_stag.png`).
- The old antlers:
  - from the front: thin flat paddles on long bare beams, with short spikes;
  - from the side: a narrow vertical comb.
- The new antlers:
  - a short thick beam out and up;
  - a brow tine curling forward over the face;
  - a fan palm that widens outward, twists from upright at the root to laid back at the end, and cups up and forward, with grooves fanning to the tines;
  - six long tines along the upper/back rim that curl up and fan from forward-leaning over the face to back;
  - four tines splayed off the end, the lowest drooping;
  - two tines hooking forward off the front rim;
  - tine roots capped where they sink through the palm.
- Span 7.6 m tip to tip (was 6.5 m), top 5.7 m. Skinned 100 % to `Head`, a separate `Antlers` mesh as before.
- Shots, `docs/orchestration/reports/megajoust/`:
  - before: `antlers_before_{front,side,tq,head}.png`, rendered from the canon GLB;
  - after: `antlers_after_{front,side,tq,head}.png`.

## Joust shots (`--lab=megajoust_lab`, windowed at `--position 6000,3000`, self-quitting, GOD on, a real lab survivor)
- From above, with the trail coloured yellow tell, red pass, cyan run off, blue wheel: `joust_<species>_top.png` for:
  - megaloceros stag and doe,
  - woolly rhino,
  - triceratops,
  - zebraceratops.
- Close shots:
  - `joust_megaloceros_stag_tell.png` (antlers down, mid-scrape),
  - `joust_megaloceros_{stag,doe}_wheel.png`,
  - `joust_<species>_wheel.png` for the others.

## Tests
- `t_megajoust` (new): **PASS**. It checks:
  - clips load and loop;
  - the turn clips carried round the brain's arc add no slide over the straight run carried straight (stag 5.9 / 19.7 cm mean against 17.5; doe 3.9 / 2.9 against 3.9), while the straight run carried round the arc slips more;
  - live fights for stag, doe, woolly rhino, triceratops and zebraceratops:
    - passes and wheels alternate, 3 to 6 passes each;
    - passes hit and knock her down;
    - no strafe, walk_back, dodge or hop clip plays;
    - nothing glides;
    - the live wheel's hooves stay within limits;
  - the doe runs twice as long as she charges (32.9 s against 15.7 s).
- Also **PASS** after the canon merge: `t_sp_megaloceros` (updated: the doe has a charge and a straight tackle), `t_combat`, `t_tactical`, `t_canim`, `t_noboxes`, `t_knockdown`, `t_cornered`, `t_coelomoves`, `t_bigreach`, `t_godlab`, `t_ai`.
- Gates:
  - `run_all.gd`: [tests] PASS.
  - `tools/smoke.sh --no-import`: SMOKE PASS.
  - `tools/audit_gaits.py --gate`: GATE PASS.
- No duplicate func names in the merged .gd files.

## Left as is / for the next agent
- **The stag's approved run has a hind-hoof slip.** It reads ~40 cm per stance on BackFoot.R in a straight line; the doe reads 4-8 cm. The turn clips add nothing to it, but the run clip itself deserves a look.
- **Stride matching ignores genetic size.** Game-wide: `CreatureAnim` matches cadence to the def height, not to `size_scale()`, so a 0.9x animal slides ~10 % on every gait. `t_megajoust` spawns at size 1.
- **The other jousters have no turn clips.** Rhino, triceratops and zebraceratops wheel on the plain run: the rhino's live wheel reads 26 cm mean against the megaloceros' 6 cm. Turn clips for those rigs (the same `ground()` trick) would fix it.
- **The death pose clips an antler.** In the death pose one antler goes under the floor (the bigger span; the head roll from SP-MEGALOCEROS no longer clears it).
- **The doe gets no separate cornered thresholds.** The shared CORNERED rule reads species tactics, not a variant's.
- **The stag's footprint is wider.** The antlers count toward `Creature.footprint()` (BIGREACH melee reach), so the stag's footprint is ~7.6 m wide.
- **The joust shots predate the canon merge.** Knockdown landed after them, so the shots show the shove, not the fall.
