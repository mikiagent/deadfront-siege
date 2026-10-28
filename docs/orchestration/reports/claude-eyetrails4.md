# Claude: EYETRAILS round 4 (daytime eye glow, no trail)

Owner, verbatim: "can you actually make the eyes glow a little bit in the daytime too but no trail?"
`claude/mmo-overhaul` was merged first, then imported.

## What shipped
- `game/data/world/eye_glow.json` (new, ASSUMPTION numbers) holds the curve:
  - `day` 0.16: the dot at noon;
  - `day_halo` 0.3: the core and bloom at noon;
  - `ramp_pow` 1.5;
  - `trail_from` 0.2 / `trail_to` 0.5: the night range over which the flame fades in.
- `game/scripts/creatures/creature_eyes.gd`:
  - `glow_at(n)` drives the dot. Energy is 3.2 at noon instead of 0.2, and 20 at night as before.
  - `halo_at(n)` drives `EyeTrail`'s core and bloom.
  - `trail_at(n)` gates the flame.
  - The values are read once from the JSON and clamped.
- `game/scripts/creatures/eye_trail.gd`:
  - The core and bloom now draw by day, faintly.
  - The flame strength is multiplied by `trail_at(night)`, so by day no sample is taken: no flame and
    no sparks.
  - The round-3 far-eye occlusion is the same code path, so it works by day too.
- The rim lights stay night-only.

## Tests
- `t_eyeglow` `_test_daytime` (deinonychus, T. rex):
  - At noon the dot energy is 3.2 and the halo alpha is about 0.25, both above 0 and under half the night
    level (20 / 0.81).
  - A 5 m/s run at noon draws 0 flame vertices and takes 0 samples.
  - Across 9 steps from noon to midnight, `glow_at`, the dot energy and the halo only rise.
  - In the noon profile the far halo is at most 2 % of the near one.
- `t_eyetrails`: every species' day run now expects no flame and a glowing core. Round 1 expected
  nothing at all by day.

## Captures (`docs/orchestration/reports/eyetrails4/`)
Settings: game camera, noon, 60 fps, a crop around the head at 2x. Each pair has **left = A (round 3, no
day glow), right = B (round 4)**. All shots are Forward+ except `AB_noon_web_head_on_2x.png`, which is
gl_compatibility (the web renderer).
- `AB_noon_deinonychus_profile_2x.png`: B has a small green glint at the eye; the far eye stays hidden.
- `AB_noon_deinonychus_head_on_2x.png`: B shows two green glints.
- `AB_noon_tyrannosaurus_profile_2x.png`: B has one amber glint in the socket.
- `AB_noon_tyrannosaurus_head_on_2x.png`: B shows two pale glints.
- `AB_noon_run_no_trail_2x.png`: deinonychus and T. rex running at noon. B glows, with no trail and no
  sparks.
- `AB_noon_web_head_on_2x.png`: the same head-on shots on the web renderer. The T. rex glints are faint
  there: the eye sits in the shadow of the brow, and an additive glow on sunlit skin adds little. Raise
  `day_halo` if the owner wants it stronger.

## Gates
`t_eyetrails`, `t_eyeglow`, `t_web`, `t_colors` and `t_lighting` PASS; `run_all` `[tests] PASS`; smoke
SMOKE PASS.

## Risks
- In B the daytime core is mostly white-hot, with only a little of the eye colour: at noon the bloom is
  too faint to carry the colour.
- Dusk (night ~0.45) keeps most of the flame. Dawn mirrors dusk.
- No credits spent. No creature brains or animation clips touched.
