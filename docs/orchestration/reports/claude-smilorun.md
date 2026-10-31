# SMILORUN + burst chaser: the smilodon bounds like a cat and is very hard to outrun

Branch `claude/mmo-smilorun`, cut from `origin/claude/mmo-overhaul`, with canon merged back in before the tests. Pushed, not merged to canon.

Owner, verbatim:
- "the smilodon run should be more cat-like, more of a leaping run"
- then: "honestly i feel like it should have jumping, leaping, bounding movement abilities that make it very hard to escape. Like it's the ultimate burst chaser. But it's agro ring could be lower since its so fast or something like that. idk"

Credits: no Tripo, Meshy or Higgsfield spend. Everything was built on the existing rig with Blender scripts.

## Shots (`docs/orchestration/reports/smilorun/`)
Each strip shows 14 frames of one cycle, side view, with the survivor for scale. They come from off-screen windowed runs of `smilodon_lab` (`--position 6000,3000`, quits by itself).
- `run_strip.jpg`: the new run.
- `sprint_strip.jpg`: the burst bound.
- `lope_strip.jpg`: the canter.
- `leap_strip.jpg`: the chase bound.

New lab options: `--pcts=0,7,...` and `--cams=side`.

## Clips (Blender, `tools/gait/`)
### `make_gait.py` (shared)
New options, all off by default, so other species are unchanged:
- `spine` block plus clip `flex_*`: the front chain (Hips, Torso, Shoulders) bends nose-down and the pelvis (Back) rump-down. Each section carries its leg roots, so the shoulder and haunch skin follow the back.
- `swing_ease_<end>`: a leg stays folded back longer, then reaches forward late.
- `head_level`: the neck takes back the shoulders' pitch.
- `true_pitch`: **found a bug.** The body pitch was applied with the wrong sign. A positive angle about SIDE lifts the nose, so `rock_front`/`rock_hind` and the per-end drop were swapped between the ends.
  - I fixed it as an opt-in so the old species keep their tuned look.
  - Any species json that uses `rock_*` or relies on the drop should switch on `true_pitch` and retune when it is next rebuilt.

### `run`: rotary bound
- Timing: 0.583 s cycle, rotary footfall LH, RH, RF, LF.
- Gathered: the back is arched and the rump low, the hinds land forward under the chest, and the fronts are folded back.
- The hinds drive off into a long stretched flight: forelegs reaching, hinds trailing.
- The fronts land reaching, then the hips vault up over them while the back flexes again.
- Measured on the skinned mesh:
  - all four paws are off the ground for 8 of 15 frames;
  - the back flexes 44 deg;
  - the hips rise and fall 0.83-1.25 m;
  - the head moves only 1.39-1.56 m;
  - the tail is lifted and swings against the body's pitch.
- Natural speed is 6.21 m/s, so cadence is 1.0 at the 6.3 m/s approach pace.
- Planted paws slip 0.000 m/frame.

### New gaits and the leap
- **`sprint`** (12.67 m/s natural): the burst bound, with a longer stride, longer flight and 51 deg of flex.
- **`lope`** (3.61 m/s): a canter. It covers the walk-to-run gap.
  - Without it, a 3.6 m/s winded or walk-pace cat played the leaping run at cadence 0.58, which looked like slow motion.
- **`leap`** (`make_cat_moves.py`, 0.75 s): coil, drive off at 0.12, stretched flight, fronts land on their prints at 0.78, hinds swing in under the chest at 0.88, then it is gathered to run on.
  - The airborne window 0.12-0.78 is in `anim_events.clips.leap`.

### Build and data
- `build_smilodon.sh` builds sprint and lope.
- `smilodon.json` lists the new clips, plus `hit_parts.leap` (either forepaw or the sabres).
- `natural_speeds`: run re-baked with `bake_clip_speeds.py --dry-run` (6.213 m/s, len 0.583); lope and sprint from stride/cycle.

## Blends (`creature_anim.gd`, `creature_clips.gd`)
- Gait ladder `GAITS` = walk, lope, run, sprint. `_pick_gait` switches at the geometric mean of neighbouring gaits with 10 % hysteresis, as before. A rig with only walk and run behaves exactly as before.
  - So walk hands over to lope at about 2.1 m/s, lope to run at about 4.7 m/s, and run to sprint at about 8.9 m/s, each near cadence 1.
- `lope` and `sprint` are hubs, so all gait changes use the 0.2 s gait blend.
- Pounce lead-in:
  - From lope, run or sprint into `attack_heavy`, `pounce` or `leap`, the blend is now 0.2 s instead of 0.08 s, so the gallop no longer pops into the crouch.
  - The leap lands back into the stride with the gait blend.
  - The run's frame 0 is the gathered stance, which blends cleanly out of the walk and into the crouch.
- **Not reviewed:** the blends were not recorded. The strips show single clips only.

## Burst chaser (`tactical_brain.gd`, smilodon only via the saber_cat `tactics`)
All of this runs only while the prey is running away (`_prey_leaving`). Keys:
- **`burst`:**
  - 15.5 m/s for 2.2 s, `burst_cd` 5 s, energy cost 12 out of a pool of about 106.
  - It plays the sprint clip through the gait ladder.
  - The speed override is divided by `run_speed_mult` because the sprint state multiplies it back.
- **`bound`:**
  - Aim: where she will be when it lands (her velocity over the flight), just short of her by the body radius.
  - When the jump is 4-12 m (cooldown 1.8 s, energy 8), it bounds.
  - **Cut-off:** if she runs more than 35 deg across its line, it lands 2 m past her on her own line, in her escape path.
  - **Strike on landing** (`bound.strike`): the landing is the pounce. It uses the pounce's cooldown, energy and `pounce_mult`, the leap hit parts, and it pins. There is no windup, but a roll still dodges it.
  - A bound that lands without hitting goes into the coiled pounce if the pounce is ready (`chase_pounce_telegraph_s` 0: no crouch, the pounce clip's own crouch is the lead-in). Otherwise it runs on.
- **Step hop:** if it is chasing but has moved under 1 m/s for 0.3 s, it hops 3 m toward her.
- **Physical arc:** during a bound the body itself flies the arc (`_arc_step` when `_b_phys`), from its height to the ground found by a ray under the landing point. It slides along whatever it meets, and gravity is held off while it flies. So it clears steps and lands on them, never inside them.
- It no longer stops to swipe at prey sprinting away faster than 4 m/s, because the paw only raked air. It bounds onto her instead.
- **Smaller ring** (`ai.json` saber_cat):
  - `perception_base` 4: it spots prey at 10.75 m by day, was 14.75.
  - `leash_mult` 1.25: the ring is 13.4 m, was 22.1.
  - `spot_alert_s` 0.15: no roar on spotting.
    - New profile key in `creature_brain._spot`, default 0.6, so other species are unchanged.
    - Without it, a sprinting survivor was out of the small ring during the old 0.6 s look.

## Tests
- **New `t_smilorun`: PASS.** It checks:
  - Run, sprint and lope (sampled 49 times):
    - flight: all four paws up in 28 of 49 (run) and 32 of 49 (sprint) samples;
    - back flex: 42.6 deg run, 50.2 sprint, 19.3 lope;
    - planted toe tips move back at the speed in `natural_speeds` (6.21, 12.66, 3.61 m/s) and stay within 0.44 m/s of it.
  - The gait ladder.
  - A survivor just outside the detection ring is ignored, and the ring is well under the old one.
  - **Catch:** a survivor sprinting straight away at 10.6 m/s from 8 m is caught in 1.67 s (burst, then a bound strike).
  - A survivor running across its line gets the cut-off leap, which lands ahead of her.
  - A bound onto a 1 m shelf never dips into it and lands standing on it.
  - Stuck at a 0.9 m step, it hops up.
- `check_smilodon.py` gained gallop gates for run, lope and sprint (flight, back flex of 12 deg or more, slip under 3 cm per frame). **SMILODON_CHECK PASS** on all 20 clips.
- `tools/audit_gaits.py --gate`: GATE PASS.
- **`t_sp_smilodon`: PASS**, with two edits:
  - the run left its "a toe stays on the floor" list (it has a flight by design; t_smilorun covers it);
  - the stalk test starts 12 m out, inside the smaller leash.
- After merging canon:
  - t_sp_smilodon, t_smilorun, t_canim, t_combat: PASS;
  - `run_all.gd`: `[tests] PASS`;
  - `tools/smoke.sh`: SMOKE PASS.

## Merge with canon
Four conflicts, all resolved as unions:
- STYRAFIX's charge_windup, impale and charge_recover clips, and its direct clip-to-hub transitions;
- canon's `stop_move()` in `_spot`.

The brain changes are additive, smilodon-keyed tactics, with new state `bound`. They do not touch the cornered or knockdown code paths. Neither branch was on canon at merge time, so compatibility with them is not tested.

## Assumptions and open questions (SM7-SM9 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **Every number is an `# ASSUMPTION`:** burst speed, length and cost, bound range, cut-off angle and distance, ring sizes, and the gait shapes (tuned by eye on strips).
- **SM4 still stands:** a 100 HP survivor dies to the pounce, so a caught survivor is a dead one. The bound strike uses `pounce_mult`.
- **Bound covers ground fast:** up to 12 m in about 0.5 s of air. That is what makes her hard to escape, but it is a long leap for a 3.5 m cat.

## Files
- **Code:**
  - `tactical_brain.gd`;
  - `creature_brain.gd` (`spot_alert_s`);
  - `creature_anim.gd` (`GAITS` ladder, hubs, blends, leap);
  - `creature_clips.gd`;
  - `smilodon_lab.gd`.
- **Data:** `ai.json` (saber_cat), `smilodon.json`, `anim_events.json`.
- **Tools:**
  - `make_gait.py`, `make_cat_moves.py`, `check_smilodon.py`, `smilodon.json`, `build_smilodon.sh`;
  - two env-gated traces: `GALLOP_TRACE` in `check_smilodon.py` and `SMILO_TRACE` in `t_smilorun`.
- **Assets:** `anim/run.glb` (rebuilt); new `anim/lope.glb`, `anim/sprint.glb`, `anim/leap.glb`.
- **Tests:** `t_smilorun.gd` (new), `t_sp_smilodon.gd`.
