# PLANTEDFLINCH: hit reactions keep the feet on the ground

Owner, 2026-10-31: "when the ankylosaurus is hit, the feet go through the floor. make it so it is rattled but the
feet stay planted to the floor. This is likely a fix needed for most dinosaurs"

Branch `claude/mmo-plantedflinch` (from `claude/mmo-overhaul`, not merged to canon).

## Cause

Two hit reactions exist (`Creature._on_damaged`):

1. **Procedural flinch** (`CreatureView.flinch`) for species with no authored `hit_react` (ankylosaurus, stegosaurus,
   megaloceros, tarbosaurus, woolly rhino, pachycephalosaurus, raptor, smilodon). It tweened the whole rig node: a
   shove of 7 % of body length and a 0.16 rad pitch (x1.4 on a crit) about the model origin. On a 6 m body the
   pitch pushes the front feet ~0.3-0.6 m into the floor and lifts the back ones.
2. **Authored hit_react clip** (13 species). Several of the transplanted clips (coelophysis, utahraptor, gallimimus,
   velociraptor, compsognathus) translate the BackFoot bones and the body back about 2-3 cm in source units, which
   is a 5-21 cm slide in game. None of them sinks much.

## Measured (t_plantedflinch, crit hit, worst foot over 1 s, cm)

Feet = the skinned bones within 6 % of body height of the lowest one, excluding the root bone, anything on the
head, and the skinless `_end` tips.

| Species | Reaction | Before: sink / lift / slide | After: sink / lift / slide |
|---|---|---|---|
| ankylosaurus | flinch | **56.6** / 11.1 / 60.6 | 0.0 / 0.0 / 0.0 |
| stegosaurus | flinch | **32.9** / 31.3 / 46.1 | 0.2 / 0.6 / 1.5 |
| raptor | flinch | **29.3** / 1.2 / 45.7 | 2.4 / 1.2 / 6.0 (idle alone slides 4.2) |
| tarbosaurus | flinch | **27.5** / 0.0 / 45.2 | 0.5 / 0.0 / 1.0 |
| smilodon | flinch | **22.6** / 0.0 / 44.2 | 0.0 / 0.0 / 0.0 |
| megaloceros | flinch | **13.6** / 42.5 / 42.7 | 0.6 / 0.0 / 1.0 |
| woolly_rhino | flinch | **9.9** / 51.2 / 45.6 | 0.2 / 0.2 / 0.7 |
| pachycephalosaurus | flinch | **6.6** / 0.2 / 40.7 | 0.1 / 0.2 / 0.3 |
| utahraptor | hit_react | 0.0 / 0.0 / **20.7** | 0.0 / 0.0 / 0.0 |
| gallimimus | hit_react | 0.0 / 0.0 / **15.8** | 0.0 / 0.0 / 0.0 |
| coelophysis | hit_react | 0.0 / 0.0 / **10.7** | 0.0 / 0.0 / 0.0 |
| deinonychus | hit_react | 3.3 / 1.6 / 8.1 | 3.2 / 4.9 / 7.9 (idle alone: 0.5 / 2.8 / 5.4) |
| compsognathus | hit_react | 0.0 / 0.5 / 5.7 | 0.0 / 0.1 / 0.0 |
| velociraptor | hit_react | 0.0 / 0.0 / 5.4 | 0.0 / 0.0 / 0.0 |
| carnotaurus, triceratops, styracosaurus, zebraceratops | hit_react | under 1.5 | under 1.5 |
| tyrannosaurus | none (TyrantBrain never flinches by design) | 0.6 | 0.6 |

Sank before (over 5 cm): the eight flinch species above, ankylosaurus worst. Slid before (over 5 cm): utahraptor,
gallimimus, coelophysis, deinonychus, compsognathus, velociraptor. After: none sinks; deinonychus still moves its
feet a few cm, about as much as its own idle does.

## Fix (shared, every rigged creature)

`game/scripts/creatures/planted_flinch.gd`, a `SkeletonModifier3D` that `CreatureView.setup` adds to every rigged
skeleton. It runs after the AnimationTree and does nothing until a hit.

- `shake(strength)` replaces the rig-node tween. It applies a damped pitch and yaw rattle (about 6 Hz, gone by
  0.45 s) to the head chain, meaning the head and every ancestor that no foot hangs from: the neck on quadrupeds, the
  torso too on bipeds. It also sways the tail. Legs and root never move. The placeholder box body keeps the old
  tween.
- `pin(seconds, still_on)` runs with an authored `hit_react`. Each frame it subtracts the feet's drift since the hit
  from the root bone: the mean horizontal drift, plus the lowest foot's height change. The clip's upper-body motion
  stays. The correction eases out over 0.15 s when the clip ends.
- Godot 4.7 calls `_process_modification_with_delta`, not `_process_modification`. I checked this.
- Bone reads outside `skeleton_updated` return the animation pose without modifiers. The test reads poses on that
  signal for this reason.

Assumptions (marked `# ASSUMPTION` in code where relevant): rattle amplitude 0.5 rad pitch / 0.3 rad yaw over the
head chain at peak, 6 Hz, 0.12 s decay; foot band 6 % of height. These numbers were chosen by eye and have not been
tuned.

Skipped: a hip shift. Moving the hips without IK moves the feet, so the rattle stays on the neck, head, torso and
tail. A real hip shift needs two-bone IK on each leg.

## Test and shots

- `game/tests/t_plantedflinch.gd` (run with `--fixed-fps 60`) hits every species with a model (crit). It asserts that
  every foot stays within 5 cm of where it stood, plus whatever the same window of idle already moves it, and that a
  flinch moves the head at least 2 % of body height.
- Review shots come from `--lab=plantedflinch_lab --out=DIR` (`game/scripts/dev/plantedflinch_lab.gd`) and are in
  `docs/orchestration/reports/plantedflinch-shots/{before,after}/<species>_<ms>.png` for ankylosaurus, stegosaurus,
  raptor and utahraptor (0 = before the hit, then 70 / 200 / 450 ms). In the before shots the ankylosaurus front foot
  is in the floor at 70 ms. In the after shots the feet are on the floor and the head rears up.
- Results: t_plantedflinch, t_combat, t_canim, t_ankylo3d, t_rexclips and t_boneparts PASS. run_all failed once on
  the econ timing check (search page 1 under 50 ms: 116 ms at load average 9.5), then PASSED on a rerun (22 ms).
  tools/smoke.sh: SMOKE PASS.

## For the next agent

- Gallimimus shows a one-frame knee swing (shin tips 9 cm off) in the hit_react-to-idle crossfade. Those tips have
  no skin weights, so the test ignores them. If it ever shows on screen, look at the crossfade time, not the pin.
- Ankylosaurus brain and attack work on `claude/mmo-ankyloclose` is untouched. Only `Creature._on_damaged` (2
  lines) and `CreatureView` changed.
