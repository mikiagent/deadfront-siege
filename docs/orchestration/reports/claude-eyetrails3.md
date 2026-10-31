# Claude: EYETRAILS round 3 (eye spacing measured from the mesh, hidden far eye)

Owner, verbatim: "I've seen the eye trails and i don't like how the eyes are very close together and
like when the enemy is facing you such that you should only see one eye, you see both eye trail candle
sources (should be just the one facing you I think, but you can see the trail of the other one)".

The branch `claude/mmo-eyetrails2` was merged with `claude/mmo-overhaul` first (this brings in the
smaller deinonychus with wider wings), then imported.

## 1. Eye spacing, measured
New lab mode `eyeglow_lab --sockets` (`game/scripts/dev/eyeglow_lab.gd`). It takes no hand-picked pixels:
1. It renders an unlit, albedo-only side close-up of the bind-pose head, with the dots and flame hidden.
2. It finds the painted eye as the strongest contrast blob near the old point, then re-centres that blob
   on its luminance-weighted centroid.
3. It ray-casts that pixel to the mesh to get the near eye on the skin, and mirrors that point across the
   midline for the far eye.

It prints JSON-ready points and saves a marked image per species. On the marked images, the cross lands
within about a third of the painted eye's radius of its centre.

| Species | Old to new (near eye, world) | Eye spacing / skull width at the socket |
|---|---|---|
| deinonychus | 13 mm up | 0.193 m / 0.183 m |
| tyrannosaurus | 23 mm forward | 1.057 / 1.024 |
| utahraptor | 40 mm up, 11 mm forward | 0.465 / 0.456 |
| velociraptor | 32 mm up, 18 mm back | 0.286 / 0.278 |
| coelophysis | 14 mm back | 0.188 / 0.178 |
| compsognathus | 17 mm up | 0.137 / 0.127 |

The spacing is 3-7 % wider than the skull because of the dots' 5 mm surface push. The new points are
written to the six `game/data/creatures/*.json` `eyes.points` blocks; nothing else in those files changed.

**Honest finding:** the mesh does not support "too close together". The deinonychus eyes were already
the skull's own width apart: 0.200 m on a 0.183 m skull. Every pair was already mirrored in world space.
Its head-bone points only look asymmetric because the head bone is rotated. What read as two eyes close
together was the far eye's glow showing on top of the skull in profile. Look at the left half of
`AB_deinonychus_profile_2x.png`: the second glow is at the brow.

## 2. Hidden eye (`game/scripts/creatures/eye_trail.gd`)
The core and bloom draw without a depth test, so they showed through the head. Now each frame, each eye's
outward axis (from the other eye to it) is compared with the direction to the camera. At or below -0.45
the eye's core and bloom are gone; at or above -0.1 they are full.
- Head-on gives about 0, so both eyes glow.
- A 90 deg profile from the iso camera gives about -0.8 for the far eye, so only the near one glows.

The hidden eye's flame and embers start transparent at the eye and fade in between 0.9 and 1.6 eye
separations along the flame. It therefore appears only once it has streamed out past the skull. All of
this is CPU-side vertex alpha, so it works the same on gl_compatibility (`B_web_profile_2x.png`).

Also fixed: the view cull used the Eyes node, which sits at the animal's feet. A T. rex whose feet were
off the bottom of the screen lost its eye glow even with its head in frame. The cull now uses the eye.

## Tests
- `t_eyetrails` `_test_hidden_eye` checks the deinonychus and the T. rex from 190 m, 35 deg up:
  - in profile the far halo alpha is at most 2 % of the near one (measured 0.000 vs 0.79 / 0.78);
  - head-on both are within 10 % of each other (0.816 / 0.796 and 0.818 / 0.803);
  - the far flame is 0 at the eye and fully on 2 separations out; the near flame is full at the eye.
- `t_eyeglow` `_test_spacing`: for all six species, the dots mirror across the midline within 3 % of
  their separation, and the spacing matches the skin-to-skin skull width at the socket within 12 %. The
  width comes from rays along the lateral axis, bind pose, headless.
- In the tests, the camera that jumps between views has physics interpolation off. With it on,
  `is_position_in_frustum` read the old place, and that flaked the head-on view.

## Captures (`docs/orchestration/reports/eyetrails3/`)
Settings: game camera (default 14 m zoom, 18 m for the T. rex, ~190 m back), midnight, Forward+,
1600x900, 60 fps. Each AB pair has **left = A (before: round 2 as merged), right = B (round 3)**: a crop
around the head shown at 2x nearest.
- `AB_deinonychus_profile_2x.png`: A has two glows (the far eye on top of the skull); B has one.
- `AB_tyrannosaurus_profile_2x.png`: A has a far-eye glint at the brow; B has only the near eye.
- `AB_deinonychus_head_on_2x.png`, `AB_tyrannosaurus_head_on_2x.png`: both eyes glow in A and B (B with
  the measured points).
- `AB_run_profile_2x.png`: running in profile. The top row is the deinonychus; the bottom row is the
  T. rex. In B, the far eye's flame shows only once it has streamed out past the skull.
- `B_web_profile_2x.png`: B in gl_compatibility (the web), profile: one eye each.

## Gates
`t_eyetrails` PASS, `t_eyeglow` PASS, `t_web` PASS, `t_colors` PASS, `run_all` `[tests] PASS`,
`tools/smoke.sh --no-import` SMOKE PASS.

## Risks / next
- The socket detector is a contrast blob. It sits at the upper edge of the eye for utahraptor and
  velociraptor (about 1-2 cm). A new species with a low-contrast painted eye needs its marked image
  checked.
- The visibility test uses the line between the eyes as the eye's outward axis. For a species with
  forward-facing eyes it would hide the far eye too early in a three-quarter view. All six current
  species have side-facing eyes.
- The skull length behind the eye is one number for all species: 0.9-1.6 eye separations.
- Head-on from the iso camera, the deinonychus eyes are still about 13 px apart at game distance. That
  is the skull's width; making them look wider would mean moving them off the head.
- No credits spent. No brains or animation clips touched. No Godot process I did not start was touched.
