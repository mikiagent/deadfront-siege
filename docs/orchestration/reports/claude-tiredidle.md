# Claude: tired and exhausted idles (TIREDIDLE)

Branch `claude/mmo-tiredidle`, from `origin/claude/mmo-overhaul`. Owner (2026-10-28): "tired animation (idle while tired) looks horrible".

## What was wrong

Both clips come from `tools/make_state_idles.py`, which layers offsets onto the survivor's idle and bakes the result.

**idle_tired** (passed limb_check, but looked bad):
- The head hung about 34 deg (spine 15 + neck 9 + head 10). The chin was on the chest, and in profile the neck jutted forward like a vulture's.
- The arm roll pressed clenched fists into the thighs.
- The pelvis rolled with nothing correcting the legs, so the feet slid and dipped 1 cm in and out of the floor. There was almost no visible breathing.

**idle_exhausted** (same problem, and worse; fixed too). limb_check failed it: ankle twist 175 deg, thigh twist 176 deg.
- The leg IK used `pole_angle = -90`, which is wrong for this rig's leg bone roll and turned the shins half around. The skin was wrung at the ankles and the knees were contorted.
- The hand targets were measured before the feet were pinned. The knees were therefore 12 cm behind where they ended up, and the fists reached back into the groin and past the thighs.
- The bend was too shallow for the hands to reach the knees anyway.

## What changed (tools/make_state_idles.py, both clips regenerated)

- **Tired**:
  - A modest slump of 10 deg in the spine and 11 deg in the head and neck, so the face is still readable.
  - Two slow, deep breaths per 4 s loop. The chest lifts out of the slump and the dropped shoulders rise on each inhale.
  - The weight shifts from foot to foot once per loop: the hips move 3 cm over the loaded foot, the unloaded hip drops, and the torso counters to stay upright.
  - The head tips with the weight shift.
  - The hands hang loose, 55 % of the way from the idle's fist to an open hand.
  - The feet stay planted with leg IK.
- **Exhausted**:
  - The leg IK pole angle is now 90. I tested -90, 0, 90 and 180: only 90 keeps the twist under 12 deg.
  - The knee pole sits ahead of each leg, so the knees track over the feet instead of caving in.
  - The pipeline now bakes in stages: legs first, then hand targets measured on the pinned legs, then arm IK.
  - The torso bends from the hips (32 deg) and the head comes up to look ahead.
  - The elbows bend backward like a bracing arm, the palms roll down onto the knees, and the fingers drape over the knees.
  - The breathing is fast and heaving.
- **Both clips**:
  - Every frame pins each foot to the idle's own foot position and rotation for that frame. Both clips keep the idle's 97 frames at 24 fps, and the last frame equals the first, so they loop.
  - Idle_cold and idle_heat were not regenerated. Their code path gives the same result as before.

## Checks

- limb_check: both clips pass. Tired: knee hinge 4.7, ankle twist 12.3, thigh twist 13.7, floor 0.0. Exhausted: knee hinge 3.8, ankle twist 11.5, thigh twist 9.2, floor 0.0.
- Tests `t_weather t_rest t_player t_playervisible t_playerturn`: 5/5 pass.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Before/after strips (in-engine, RiggedModel)

Each strip is 6 frames across the loop, front view on the top row and side view below. They are in `docs/orchestration/reports/tiredidle/`:
`before_idle.png`, `before_idle_tired.png`, `before_idle_exhausted.png`, `after_idle_tired.png`, `after_idle_exhausted.png`.

The capture script is a scratch `--script` SceneTree that builds a `RiggedModel` and runs windowed at `--position 6000,3000`. It was not committed because it lives outside the game tree.

## Notes for the next agent

- No paid generation was used. Credits spent: 0.
- In the exhausted pose the left hand still sits a few cm in front of the knee cap when seen from the side. It reads as resting on the knee at game distance.
- ASSUMPTION: the breath rates (tired 2 per 4 s, exhausted 3 per 4 s) and the 3 cm weight shift have no PRD numbers.
- The owner has not seen the new clips in motion yet. Run the clip viewer recording for approval.
