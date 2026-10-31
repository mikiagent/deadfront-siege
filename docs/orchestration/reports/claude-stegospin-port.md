# STEGOSPIN port onto canon (knockdown, hitboxes, bigstomp, megajoust)

Branch `claude/mmo-stegospin`, merged with `origin/claude/mmo-overhaul` up to f1b73788e (megajoust). No Meshy or Tripo
credits spent. All clips are procedural (Blender scripts in `tools/gait/`).

## What shipped

**Merge.** I took the integrator's hitbox-aware `ClubTailBrain` from c016658a, but not its pending branches. I replaced
its inflated, calibrated stego radii.

**Honest close-move hitboxes (stegosaurus).** I measured where each clip puts the part at the hit frame
(`Hitbox.sample_pose`). The hitboxes.json rows now use those bones at the stego's own hurtbox radius, with no
`radius` key:
- stomp: `front_foot_L` + toe
- rear slam: both forefeet + toes
- hind stomps: hind foot + toe
- shoulder slam: `front_forearm` + `front_upperarm`
- tackle leap: forearms + `spine_03`

The ai.json `target_bearing_deg` / `target_dist_m` spots moved to where those parts land: stomp 2.46 m at -13 deg,
rear slam 2.5 m, hind stomps 2.6 m at ±135 deg, slam 1.96 m at ±45 deg. `close_zone.front_min_m` went from 3.0 to 2.2.
t_stegospin now stands her on `strike_spot`.

**Toe drift.** The cause was the 0.08 s cross-fade from the walk into a turn clip keyed from the idle stance. It slid the
planted toes 0.2 m at the start of a spin. The fix: a move never starts out of a stepping clip
(`ClubTailBrain.STEPPING`, `_still_t`). Worst toe slide in a turn is now 0.05-0.09 m (limit 0.15).

**Tackle.** Owner: "legs moving fast, then a jump/lunge that goes kind of far". The move is now:
1. The coil (the existing clip).
2. A run-up at the run gait (`run_m`, `run_mps`).
3. A new `tackle_lunge` leap (both species). The brain carries the body `lunge_m` along the line inside the clip's
   airborne window (anim_events `airborne` [0.14, 0.52]).

Leap distances:

| Species | Before | Now |
|---|---|---|
| Ankylosaurus | 2.5 m run | 5 m x size |
| Stegosaurus | 3.5 m run | 6 m x size |

It lands through the leap's hitbox parts, swept live (`_tick_leap`), and knocks her down. The stegosaurus' chest rides
over a survivor, so it leads with its left foreleg (`aim_side_m` 0.75).

**Shoulder slam.** It replaces both shoves on both species. The owner confirmed `shove_right` was the move that "looks
at you and you get hurt", and later asked for "more range ... throw the ankys body weight at the player".
- Ankylosaurus `shove_left` / `shove_right`, 1.8 s: cocked off, then a bound (airborne 0.24-0.42). The brain throws the
  body up to `carry_m` 4 m x size so the shoulder ends at her (`slam_point`). It lands into her with the shoulder down
  (knockdown), then rocks back, re-plants and steadies. `close_zone.side_max_m` is now 6 m.
- Stegosaurus: the same slam played on the spot.

**Ankylosaurus about-face and rush.** Owner: "rush me ... rotates 180 for a massive tail whip and tail smash". It rushes
in at the run gait beyond `rush_min_m`. The new front-sequence entry `tail` plays `about_left` / `about_right` when she is
inside `tail_radius_m`. That is a 180 deg turn about a point 0.6 m ahead of its origin, in code in step with the clip,
with every foot stepping (walk order, 4 steps each). The whip follows at once. The smash follows after a sidestep lines
it up.

The front order is now stomp, tackle, tail, spin. The whip is "lined up" anywhere on its real club arc
(`sweep_arc_deg` [-110, 100]). It still never walks backwards toward her.

**ANKYLOOPEN.** Owner: "stuck in hold/idle animation when the player initially attacks". I reproduced it on canon
2eecfc3ed: side-on to her, it held forever in `hold` / idle. The root cause is in `ClubTailBrain` (not shared stagger
code). The hold sidestep goal was 0.8 m away, inside the nav agent's 0.9 m `target_desired_distance`, so it never stepped
and never turned. The goal is now `SIDESTEP_M` 2.0. On canon that one change gets it out of the stuck state; it attacks
5.9 s after the first hit. On this branch every opening attacks within about 1 s (0.4-1.0 s).

**BIGSTOMP.** The stegosaurus is opted in: a `tools/gait/big_stomp.json` leg map, `big_stomp` + `pin_foot` clips
(`check_big_stomp` PASS) and `ai.json big_stomp.species.stegosaurus` (land [-0.047, 0.305], measured by t_bigstomp). It
is now in t_bigstomp's SPECIES. The ankylosaurus stays out (canon `big_stomp: false`).

## Tests
- `t_ankyloclose`: front kit (stomp and tackle land), shoulder slam both sides, behind. New checks:
  - the tackle leap covers at least 0.95 x `lunge_m` x size and knocks her down;
  - the about-face plus whip and the about-face plus smash land on her in front;
  - it never moves backwards along its facing while closing;
  - the slam starts from 5 m off the flank, throws the body at least 3 m (`SLAM_CARRY_M`, ASSUMPTION about a body
    length) and lands.
- `t_ankyloopen` (new): a calm, unprovoked ankylosaurus 8 m away at 7 facings; the survivor opens with the lab's
  auto-attack. It must react within 1 s and attack within 3 s.
- `t_stegospin`: positions on `strike_spot`, tackle leap distance, rooted-knockdown reset between cases. The stego's
  `brain.stomp` is nulled per case so the big stomp does not pre-empt the move under test.
- `t_hitboxes`: skips carry, leap and turn moves (they are swept live).

## Gate results (head after the final canon merge)
- t_stegospin, t_ankyloclose, t_ankyloopen, t_hitboxes, t_knockdown, t_plantedflinch, t_combat, t_bigstomp: **PASS**
- run_all: **[tests] PASS**
- `tools/smoke.sh --no-import`: **SMOKE PASS**
- Clip gates: `check_ankylo.py` ANKYLO_CHECK PASS (all clips); `check_stego_moves.py` PASS (`shove_*`, `tackle_lunge`).

## Lab shots (`docs/orchestration/reports/stegospin-port/`)
`--lab=stegospin_lab` saves each move's wind-up and its hit frame. The tackle and the slam also get a mid-air frame:
- stegosaurus: stomp, rear slam, hind stomp, slam, tackle;
- ankylosaurus: stomp, slam both sides, tackle, about-face plus whip.

Gaps: the about-face plus smash shows the turn but no hit, because in the lab the smash's lining-up sidestep never runs.
The stego `shove_left` gets no hit shot, though t_stegospin lands it.

## Assumptions (`# ASSUMPTION` in data)
- `carry_m` 4 m (about a body length), `tail_radius_m` 4.6, `rush_min_m` 6.
- Leap `reach_m` (anky 2.0, stego 1.3) and stego `aim_side_m` 0.75.
- React within 1 s, attack within 3 s.
- `SIDESTEP_M` 2.0.

## For the next agent
- **Joust.** The ankylosaurus' joust still uses its own sphere contact (`_contact`), not hitboxes. canon's new
  `JoustBrain` could replace it.
- **Big stomp vs. close kit.** In play the stegosaurus' big stomp competes with its close kit under the body, on a 3.5 s
  cooldown. Nobody has looked at that in the lab yet.
- **Slam lift.** The anky slam's shoulder cannot drop much: its belly rides a hand's width off the ground, so the floor
  pass lifts the body. The slam reads through the lateral lurch, the roll and the head.
