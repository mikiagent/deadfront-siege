# POSEFIX: survivor stuck bent sideways

Owner: "character is stuck bending sideways? weird bug." (tutorial town, rain, Wet 2).

## Root cause

The survivor's clips do not all key the same bones. `swim`, `swim_idle`, `idle_tired`, `idle_exhausted`,
`rummage*`, `work_forge/stir/tan`, `kick_dirt` and `mount_idle` key `Spine` (and most of them the feet);
`idle`, `walk`, `run`, `idle_cold`, `idle_heat` and every KevDev/Meshy one-shot leave `Spine`, `LeftFoot` and
`RightFoot` out (`idle_heat` also leaves out the right hand's fingers). The rig's AnimationPlayer is created
in code with `deterministic = false`, so a bone the playing clip does not key keeps the last value any
earlier clip wrote. After swimming, `Spine` stayed at the swim stroke's roll: she stood, walked and ran
about 23 deg bent sideways at the waist, for the rest of the session. Wet 2 in the rain fits: she had just
been in the water. Smaller leftovers came from the other clips: the exhausted idle left a 12 deg forward
slump in the plain idle, and the tired idle about 3 deg.

None of the state idle clips has a bad keyframe. Every one starts and ends upright and loops cleanly. The
state-idle selection and transitions (`PlayerAnim.pick_idle` / `_play`) worked: `current_clip` was `idle`
again. Only the leftover bone was wrong.

## Fix

`game/scripts/player/player_view.gd`: `rig.anim_player.deterministic = true` right after the survivor rig
is set up. When a bone is missing from the playing clip, it now goes back to its rest pose. Crossfades
still blend. One line, player rig only.

Side effect: `idle_heat`'s right-hand fingers, which that clip does not key, now rest open while she fans
herself. Before, they held whatever clip played last.

## Test

`game/tests/t_posefix.gd` (headless; windowed it writes the PNGs):
1. Every state idle (`idle` plus `MOOD_IDLES`) starts and ends within 5 deg of the plain idle's side tilt
   (hips to head) and loops without a pop.
2. For every clip in the library, sampled at 0/25/50/75/100 %, the plain idle that follows matches a
   fresh idle within 4 deg on both axes. Before the fix this failed at swim@0%: 24.5 deg.
3. In play, on the tutorial isle in the rain with Wet 2: swim then out of the water, the bag rummage,
   exhausted then rested, tired then rested, cold then warm. Each time `current_clip` is `idle` within
   0.8 s and she stands like a fresh idle. Before the fix: out of the water side -23 deg, lean 23 deg;
   after exhausted, lean 18 deg.

## Shots (docs/orchestration/reports/posefix/)

- `before_1_after_swim.png`: out of the water, bent sideways at the waist (the owner's screenshot).
- `after_1_after_swim.png`: the same moment after the fix, standing straight.
- `before_0_idle_in_rain.png` / `after_0_idle_in_rain.png`: the baseline idle in the rain.

## Gates

PASS: t_posefix, t_playervisible, t_weather, t_rest, t_tentsleep, t_rummage, run_all, `tools/smoke.sh --no-import` (SMOKE PASS).
t_player FAILS with the same 2 failures with and without this change ("HOLD in reach: 0 hits", "Auto off: F swings and lands once (0)"). The failure is already on canon d1f710b3 (combat auto-swing), not caused by POSEFIX.

## For the next agent

- Creatures share `RiggedModel` and still run non-deterministic. If a species' clips key different bone
  sets, the same leftover-pose bug can happen there. Not changed here because nobody has reported it.
- Credits spent: none.
