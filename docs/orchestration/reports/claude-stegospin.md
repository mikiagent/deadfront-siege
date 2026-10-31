# STEGOSPIN: the stegosaurus spins and stomps; the ankylosaurus spins from the front, jousts, and never backs in

Branch `claude/mmo-stegospin` (from the ankyloclose head, merged with `origin/claude/mmo-ankyloclose` and
`origin/claude/mmo-overhaul`, and merged with overhaul again before the last test run). Not merged to canon. No Tripo or
Meshy credits spent.

Owner, verbatim:
- "Stego needs a stronger twist attack, tackle attack, etc. it should be spinning a lot, anky and stego are similar"
- "also needs stomp attacks" / "for both stegos"
- "smaller animals hop around more than they strafe, big and heavy dinosaurs strafe more than they hop"

Ankylosaurus addendum, from the coordinator, verbatim: "don't have the ankylosaurus back himself into me for an attack, he
should also joust and be able to hit you with his tail from the front by spinning and smacking you with the tail".

## "Both stegos"

There is one stegosaurus mesh and rig (the v2 Tripo mesh with the Opus rig). It ships in two looks, `graded` and `ochre`
(STEGOFIX `pipeline.model_variants`, an albedo swap). The clips are authored once on that rig, and the tests and shots run
on both looks. No other stegosaur species or model exists in the repo; `v1/` and the gobkit stand-in are not used by any code.

## What shipped

### Stegosaurus: now on ClubTailBrain

`ai.json archetypes.spiked_tail`. `Creature._make_brain` and the lab panel send `spiked_tail` to `ClubTailBrain`.

- **TAIL SPIN** (`spin_right` / `spin_left`, 4.0 s):
  - Wind-up (1.1 s): it crouches, raises and cocks the tail, and the tail trembles.
  - Then it turns 220 deg about the ball of the inner front foot while the tail lags and whips round the outside.
  - The hit is the whole rear body and tail, swept as a line from the hips to the club: knockdown and a 6 m knockback.
  - The ring is drawn round the pivot foot out to the club (9.8 m), with the label "TAIL SPIN - ROLL OR GET TO ITS HEAD".
  - When she is still in reach and on her feet, it spins again at once (double spin).
  - The side is chosen so the tail reaches her first: behind-left gets `spin_right`.
- **PIVOT** (`pivot_left` / `pivot_right`, 1.6 s): a 90 deg turn on a front foot. It pivots when the next tail move is more
  than 75 deg off its aim, or to turn head first toward her when she is behind it and out of reach.
- **STOMP**: the left forefoot is hauled up and slammed down. The weight rocks back and onto the right, and a crouch keeps
  the other forefoot planted.
- **REAR SLAM**: it rears 25 deg on its hind legs with both forefeet high, holds, then slams down ahead. The area is wider
  (3.6 m) and it knocks her down.
- **HIND STOMP** (left / right): the hind foot on her side is hauled up and out and stamped down beside the flank. This is a
  new `close_zone.flank_back_m` band beside the hips.
- **SHOVE** (left / right): head and shoulders swing into her and the near forefoot steps out; it pushes her 4 m sideways.
- **TACKLE**: a coil, then a run of up to 3.5 m.
- Front order: stomp, then rear slam; the tackle comes when she is past the stomp's reach.
- Every move shows its ring and name and can be rolled through, the same way as the ankylosaurus moves.

### Ankylosaurus (`club_tail`)

- **No back-in.** `_position` never walks the animal toward her to bring the tail into range.
  - In reach: it swings, or it re-aims on the spot with a pivot or a sidestep.
  - Out of reach: it pivots and comes head first, so the front moves take over.
- **Front TAIL SPIN.** `front_sequence` is now stomp, spin, tackle. The spin is a 200 deg turn on a front foot that sweeps
  the club and tail round through the front. It also has the 90 deg pivots.
- **JOUST** (`club_tail.joust`). From 11-30 m, it runs straight past her by 10 m at 6 m/s on the run gait. Then it arcs
  round at 60 deg/s and charges again, two passes in all.
  - A body check on contact knocks her down and throws her to the side she stood on, so it runs on past her.
  - Its own hits do not stagger it out of the run (`super_armor`).
  - A run that a body blocks for 1 s ends.
  - If the arc brings it round too close for another run, the close moves take over.
  - `origin/claude/mmo-megajoust` was not pushed (checked twice). This joust is its own minimal version, marked `shortcut:`
    in `club_tail_brain.gd`, to be folded onto the shared one when that lands.
- **Big-heavy rule.** Neither animal ever plays a hop clip; they turn with pivots and sidesteps (strafes).

### How a turn move stays planted

Each turn clip is keyed with the world motion counter-rotated, so the body stays put in armature space and the feet step
round the pivot. While the clip plays, `ClubTailBrain` turns the creature's view by `turn_deg * smoothstep(turn)` about
the same pivot, on every `AnimationTree.mixer_applied`, so the turn and the pose come from the same frame. It hands the
turn to the body at the end, or wherever the clip is cut off, and calls `reset_physics_interpolation`. The clip ends on the
idle pose, so the crossfade back to idle does not pop. `pivot_gltf` is the pivot in the model's glTF x/z.

### Clips and gates

- `tools/gait/make_stego_moves.py` (new): 11 stegosaurus clips keyed from the idle pose, with planted feet, two-bone leg IK
  and generated step schedules for turns.
  - Gate `tools/gait/check_stego_moves.py` (new) checks in the world frame (the code turn put back on): planted toe slide
    at most 0.06 m, no leg gap, no sinking, stretch at most 12, and the end turn.
  - Result: `STEGO_MOVES PASS` (slide at most 0.008 m, stretch at most 7.2). `check_stego.py`: `STEGO_CHECK PASS`.
- `tools/gait/make_tail_club.py` gained turn clips: ankylosaurus `spin_*` and `pivot_*`, pivoting on the sole centre,
  grounded with `ground_clip.py --fps 24`.
  - `check_ankylo.py` now checks turn clips in the world frame.
  - Result: `ANKYLO_CHECK PASS` on all clips (slide at most 0.022 m, stretch at most 9.8).
- `tools/audit_gaits.py --gate`: GATE PASS.
- Engine lists:
  - `CreatureClips.OPTIONAL` has every new clip.
  - `CreatureAnim.ONESHOT` has every new clip; `ATTACKS` has spins, rear slam and hind stomps. Pivots are not in
    `ATTACKS`, so a flinch can cut a pivot; the turn reached so far is kept.
  - `anim_events.json` has rows for the new clips; the species JSON clip lists and the lab panel's `FIGHT_CLIPS` include them.

## Tests

`game/tests/t_stegospin.gd` (new). The stegosaurus parts run on both looks.
- **Spins:** with her round its rear, at least 3 spins of more than 180 deg in 20 s (got 3 of 220, a 4th started). A spin
  lands with a knockdown and a 9.6 m throw. Planted toes hold through every turn in the world (worst 0.06-0.09 m, limit
  0.15).
- **Double spin:** a second spin starts 0.00 s after the first.
- **Pivot:** from 14 m behind it pivots round to face her; toes hold through the pivots.
- **Stomps:** STOMP, REAR SLAM and HIND STOMP (both sides) each land, with the body still. Hind stomps push her 3.9 m off
  that side.
- **Close moves:** SHOVE (both sides) lands and pushes her off that side; TACKLE lands.
- **Ankylosaurus:**
  - The front spin lands (a 200 deg turn).
  - No back-in: 0.00 m toward her while she is behind it, and it turns to face her.
  - Joust: it lands, runs 17 m past her, arcs, and charges again, with no hop clip.

Updated to the owner's new rule, the changes being:
- `t_ankyloclose` "behind it": she now stands in the club's reach (3 m, it was 4.5 m). It swings the tail first and moves
  0.00 m toward her. At 4.5 m it used to walk backwards into her, which is the back-in the owner removed.
- `t_ankyloai` 40 s fight: the ANKYLOAI rules "never runs / never closes under 2 m / at most one hit per 3 s" are gone,
  because the owner asked for the close moves, the front spin and the joust. It now checks: no hop clip, no back-in, it
  fights, a hit lands, and tail moves start with her on the tail side.

Results after the final overhaul merge: see the end of this file.

## Review shots (`docs/orchestration/reports/stegospin/`)

These come from off-screen windowed runs of the new self-quitting `--lab=stegospin_lab`:
`Godot --path game --position 6000,3000 -- --skip-charcreate --lab=stegospin_lab --out=DIR [--species=ankylosaurus] [--variant=ochre] [--moves=...]`.
- `stegosaurus_graded_*`: spin_right (wind-up ring, turned 60/120/180 deg, hit), pivot_left, stomp, rear_slam,
  hind_stomp_right, shove_left, tackle (each with wind-up and hit).
- `stegosaurus_ochre_*`: spin_right and rear_slam on the second look.
- `ankylosaurus_base_spin_left_*`: the front spin. `ankylosaurus_base_joust_00..12`: the joust from above (run, arc, run).

What still reads wrong:
- The spin's foot stepping is fast. A 220 deg turn in 2.3 s means a hind step about every 0.2 s.
- The ankylosaurus' hind feet shuffle long low steps in its spin.
- The telegraph labels are the small Label3D the other club moves use.
- The joust run has no dedicated charge clip; it uses the run gait.
- The ankylosaurus pivot foot's bone head circles about 0.13 m as the foot twists about its sole centre.

## Assumptions (Open Questions SS1-SS8)

All of these are in `docs/vision/WildLandsMMO_Open_Questions.md` (STEGOSPIN):
- spin angles and timing;
- the line hit;
- double-spin rules;
- the pivot threshold;
- the close-move sizes;
- no back-in;
- the joust numbers.

Also:
- The stegosaurus TAIL WHIP (attack_heavy) row was dropped: the spin is the stegosaurus tail move.
- Balance is not tuned: the moves one-shot a fresh 100 HP survivor, as before.

## For the next agent

- **Regenerate the clips.**
  - Stegosaurus: `Blender -b -P tools/gait/make_stego_moves.py -- stegosaurus.glb anim/idle.glb anim`, then
    `check_stego_moves.py -- stegosaurus.glb anim game/data/creatures/ai.json`.
  - Ankylosaurus: `Blender -b -P tools/gait/make_tail_club.py -- ankylosaurus.glb OUT spin_right spin_left pivot_right pivot_left`,
    then `ground_clip.py --fps 24`, then `check_ankylo.py`.
  - If a pivot foot changes, update `pivot_gltf` from the `PIVOT` line the maker prints.
- **Joust:** when claude/mmo-megajoust lands, replace `_try_joust` / `_tick_joust` with the shared behaviour via the
  tactics profile.
- A tamed stegosaurus or ankylosaurus (PetBrain) uses none of this.

## Test results (after the final `origin/claude/mmo-overhaul` merge, 20fc3c10)

- `t_stegospin`, `t_ankyloclose`, `t_ankylo3d`, `t_ankyloai`, `t_combat`, `t_tactical`, `t_canim`, `t_noboxes`: all PASS.
- `run_all`: `[tests] PASS`.
- `tools/smoke.sh`: SMOKE PASS.
- No merged .gd file defines a function twice.
