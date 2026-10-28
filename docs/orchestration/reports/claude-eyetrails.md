# Claude: EYETRAILS finish (glowing eyes, bloom, trails)

Owner asks, in order: "Also add trails to the glowing eyes", "glowing eyes with trails that look like a
flame in the wind?", then, after seeing an intermediate version: "supposed to make them creepy, deadly and
cinematic. right now it looks like 2 misplaced candles. It should emanate from the eye outwards more?"

The previous worker's report (`dsc-eyetrails.md`) said the flame was done. It was not. Its trail was culled
at 55 m, and the real game camera stands about 190 m back (4.3 deg lens), so at the game camera there was
no trail at all and the eye was a 1-2 px white dot (`A_*` shots). Up close the trail was a hard-edged
segmented bar sitting above the eyes.

## What shipped

| File | Change |
|---|---|
| `game/scripts/creatures/eye_trail.gd` | Rewritten. Still one ImmediateMesh, one surface, one draw call per creature. It now draws three things. (1) Per eye, a white-hot core in the socket and a bloom that spreads outward and dims ring by ring, both with pixel floors so the eye shows from the game camera. (2) A wisp per eye while the head moves fast: a Catmull-Rom curve with 12 rows and 5 vertex columns, feathered edges (edge alpha 0), a thin body tapering to a point, alpha fading with age and along its length, flowing value-noise flicker on width, alpha and lateral offset, and the older part dragged downwind. (3) Embers shed along the wisp that twinkle and drift. Length scales with eye separation (a T. rex burns a longer wisp than a compy). A frustum and distance cull replaces the 55 m cull. |
| `game/scripts/creatures/creature_eyes.gd` | Rim light: one shadowless OmniLight3D per eye, just outside the socket, in the eye colour, only at night. Energy is set by push distance squared because Godot's omni uses inverse-square falloff, and a flat energy burned small heads white. The eye positions are not changed. |
| `game/data/creatures/tyrannosaurus.json` | **Eye points corrected.** I was allowed to change them this time, and I say so here. They sat in the brow socket, about 10 cm above and ahead of the painted eyeball. They moved from `[±0.4838, 1.0528, 0.8699]` to `[±0.5119, 0.9485, 0.7624]`, measured with `eyeglow_lab --species=tyrannosaurus --aim=958,348 --ray`. Deinonychus, velociraptor and utahraptor were checked side-on and front-on and left alone (their dots sit on the painted eye). |
| `game/tests/t_eyetrails.gd` | Updated for the bloom, which shows while the head is still. New `_test_shape` uses the real game-camera lens and distance and checks: the tail is narrower than the base; the body swells past its base; edge alpha / core alpha < 0.05, plus the vertex alphas run from below 0.01 to above 0.5; the width is at least 5 px at the eye and at least 8 px at its widest; the length is at least 30 px; a still head draws the bloom with length 0. The flicker tests now skip the 20 warm-up frames. The vertex budget uses `MAX_VERTICES`. The shot pass is rewritten (see below). |
| `docs/current/eyes.md` | Rewritten for the current implementation: rim light, bloom/wisp/embers, the table of constants, the T. rex point correction, cost. |

## Shots (`docs/orchestration/reports/eyetrails/`, all at midnight under `WorldLighting`, game `IsoCamera`, 1600x900 Compatibility, 800x450 crops of the game-camera frame, not rescaled)

`A_` = before (the dsc version and the old T. rex points), `B_` = after. Deinonychus uses the default 14 m
zoom. The T. rex uses 18 m (max game zoom), because at 14 m its 8 m height puts the head out of frame.

- `A_deinonychus_still.png`, `A_deinonychus_run_b.png`, `A_tyrannosaurus_run_a.png`: the eye is a 1-2 px
  white point and no trail ever appears.
- `B_deinonychus_still.png`: a white-hot point in the socket with a green glow spilling over the side of
  the face and fading out. The far eye shows as a small spark at the brow. No wisp.
- `B_deinonychus_run_a/_b/_c.png`: a short sequence, 0.25 s apart, running across the screen. Two thin
  green wisps stream back from the eyes over the head and neck for about 90 px, with sparks along and
  beyond them. The wisp's thickness and brightness change between frames (flicker). Honest note: the
  far-eye wisp starts at the top of the skull, because that is where the far eye projects, so it reads
  as starting slightly above the near one.
- `B_deinonychus_turn.png`: after a stop and a fast 150 deg head turn, one bright arc sweeps up and over
  from the eye with a spark at its tip. Honest note: it reads more as a comet streak or a scythe than as
  smoke.
- `B_tyrannosaurus_still.png`: a hot point in the socket, and the rim light paints the socket and the
  brow orange. This reads as a lit predator eye, not a sprite.
- `B_tyrannosaurus_run_a.png`: two orange wisps, about 70 px, streaming back from the eyes, with sparks.
  Partly hidden by the skull ridge.
- `B_tyrannosaurus_turn.png`: the same arc as the deinonychus turn, in orange.
- `placement_*`: magenta crosses on the dots in day light. `placement_rex_side_before.png` shows the
  cross in the empty brow socket. `placement_rex_side_after.png` and `placement_rex_front_after.png` show
  it on the eyeball. The deinonychus, velociraptor and utahraptor side views show the cross on the
  painted eye.

My verdict: B no longer reads as candles. It reads as eyes that glow from the socket outward, with
wisps dragged behind on a run. It is not yet "cinematic" in the way a hand-made shader would be. The wisp
is still fairly smooth and even along most of its length, and the turn arc reads more as a streak than as
wispy smoke. If the owner wants more, the next steps are a noise texture on the wisp (a real shader), or
2-3 thinner strands per eye.

## Gates (all through gslot)
t_eyetrails PASS, t_eyeglow PASS, t_web PASS, t_colors PASS, t_ai PASS, `tools/smoke.sh --no-import`
SMOKE PASS, run_all `[tests] PASS`. The SCRIPT ERRORs are only the known ones: TouchControls compile order
and the deliberate econ fault.

## Cost and risks
- 20 creatures at full strength take **1.5 ms of GDScript per frame** on this Mac (the gate is 2 ms). On
  the web, GDScript is slower. The bloom is rebuilt every frame even while still. If the web frame budget
  suffers, move the bloom to a static billboard mesh that only follows the camera, or rebuild every
  other frame.
- Two omni lights per glowing creature at night. Compatibility has a per-object light limit (8), so
  packs of 5+ predators in one spot could drop lights on shared meshes.
- The wisp is pulled 1.5 eye separations toward the camera (along the view ray) so it clears the skull.
  It does not move on screen, but the wisp can draw over a tree directly in front of the animal.
- No credits spent. No sound. No new data files. Per-species `"trail"` overrides inside `eyes` still
  work and are clamped.

## Assumptions (marked in code)
Thresholds 1.6 / 4.5 m/s; fade 0.3 s; base length 1.6 m scaled by eye separation; bloom/core sizes and
pixel floors; rim light level; one fixed wind direction (no wind system exists).
