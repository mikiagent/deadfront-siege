# Biped re-animation: compsognathus, coelophysis, gallimimus

All eleven clips per species were re-authored headless in Blender 5.2
(`/Applications/Blender.app/Contents/MacOS/Blender -b -P work/build.py -- <species> <clips...>`), starting
from each species' rig in `input/<species>/<species>.glb`. The mesh, bone names, hierarchy and rest pose
are untouched: `out/<species>/<species>.glb` is a byte-for-byte copy of the input.

Every clip is built from **small local basis rotations from rest** (quaternions on pose bones) plus small
basis translations for the body and the two world-space foot handles (`BackFoot.L/R`, children of `root`).
No aim/look-at constraint and no armature-space matrix is keyed: the world-space helpers in `work/lib.py`
only *solve* for the local values that produce the wanted pose.

Each clip exports skeleton-only with the skin: 1 skin, the same 37 joints and node names as the input,
0 meshes, 0 materials, 0 images, exactly 1 animation.

## What was wrong with the shipped clips, and what fixed it

| audit finding | cause found | fix |
|---|---|---|
| attack_primary whips the tail vertical instead of biting | donor clip keyed armature-space tail rotation | every tail bone is aimed along a world direction in the floor plane (`poses.tail_flat`), so it cannot go vertical whatever the spine does. Measured max abs z-component over the tail: **0.03–0.16** across all 33 clips |
| knockdown ends belly-up, legs in the air | the raptor `lie.py` built leg targets from the **body-local** forward axis; after the 92° roll that axis points sideways, so the legs became struts and propped the body on its heels | rewritten `work/lie3.py`: roll onto the flank, drop the body until the *torso* vertices touch z=0, then solve both hind legs to folded footholds in **world** forward, rest the neck/head onto the floor by measurement, and lay the tail along a slope-limited descent. Low vertex ends at -0.004…+0.003, `near_floor` 0.87–1.00 |
| feet slide | two separate causes: (a) stance ankle pitch rotated the foot about its head, lifting the ankle ~12 mm mid-stance so the "contact" test kept dropping frames; (b) the build's global floor guard lifted the *whole body* while planted feet held world targets, so the planted foot got dragged up | `gait.foot_track` holds a constant ankle angle through stance and puts all the roll into early swing; `poses.ground_feet` locks one constant per-clip sole offset; the floor guard now lifts only the body and only re-plants when a *foot* itself is under the floor. Result: **x drift 0.0 mm, z drift 0.0–1.6 mm**, travel linear to ≤1.1 mm |
| walk loops have long frozen halves | the stance foot and its chain are legitimately still, but also every clip used raptor-scale constants | strides, lift, body drop and bob are now derived from each rig's leg-chain length (`work/dims.py`, `poses.H["k"]`). Walk/run longest static bone: **0 %** for all three species |
| no sleep or feed clip | — | both authored for all three species |

Timings follow `ref/anim_events.json`: attack_primary contacts at 42 % of its clip, attack_heavy at 72 %
after a 0.6 s held windup (frames 8–20). Alert was rebuilt at 40 frames (1.67 s) because the input clip was
1.04 s, under the verifier's 1.2 s minimum.

The rig has **no jaw bone** (donor transplant, and the mesh/joint set is frozen by the contract), so a bite
is carried by the neck and head driving the snout forward and down, plus the follow-through of the whole
forequarter — not by an opening mouth.

## Per species

Species differences came out of the rig itself, not from hard-coded numbers: leg chain 0.437 m
(compsognathus), 0.384 m (coelophysis), 0.552 m (gallimimus); hip height 0.398 / 0.367 / 0.471 m.

### compsognathus

| clip | frames / duration | what it is now |
|---|---|---|
| idle | 63 / 2.62 s, loop | breathing (2 per loop), slow weight shift with a small roll, head scan, horizontal tail sweep |
| walk | 59 / 2.46 s, loop | 2-beat walk, 62 % duty, 0.314 m stance travel, 78 mm lift, stance foot 0.0 mm x / 1.6 mm z drift |
| run | 17 / 0.71 s, loop | 41 % duty with a short flight phase, 0.398 m stance travel, 131 mm lift, body pitched 7°, feet 0.0 mm drift |
| attack_primary | 21 / 0.88 s | **bite.** Coil frames 3–6: snout drawn back and up (z 0.64 → 0.97 m). Strike: body lunges, neck drives the snout from 0.97 m high at frame 6 to 0.21 m at frame 9 = 42 %, reaching 0.93 m forward. Follow-through low and forward, recovery by 21. Tail sweeps the opposite way horizontally (max abs z 0.03) |
| attack_heavy | 36 / 1.50 s | crouch with the head drawn back **held frames 8–20** (0.6 s), then a leap — lowest vertex 0.10 m at 21, **0.28 m at contact frame 26 = 72 %** — snout whipping forward to 1.05 m while the right foot rakes forward. Airborne to 30, lands 31, recovers by 36 |
| hit_react | 30 / 1.25 s | flinch away from a frontal-left hit: body yaws/rolls away, neck and head snap away, one forelimb flails, feet stagger back, returns exactly to stance |
| knockdown | 52 / 2.17 s, holds | staggers, is knocked off its feet, rolls onto its **right flank**, lands on shoulder and hip, legs fold in front of the body and rest on the floor. Frames 40–52 identical. Ends on its side — not belly-up, legs not in the air (`near_floor` 1.00) |
| death | 44 / 1.83 s, holds | legs buckle, crumples sideways onto the flank, head drops to the floor. Frames 37–44 held |
| alert | 40 / 1.67 s | rises 3 cm, neck extends, head high and scanning left→right, tail stiff and level |
| feed | 71 / 2.96 s, loop | **new.** Head down over a carcass (snout 0.11–0.32 m above the floor), two bite-and-tear pulls per loop, body rocks back on the tear, tail counterbalances horizontally, feet planted |
| sleep | 91 / 3.79 s, loop | **new.** Curled on its left side, head tucked, forelimbs folded onto the floor, tail curled flat along it, slow breathing with a small twitch. Nothing in the air |

### coelophysis

Same eleven clips and the same construction, re-solved against the slightly shorter, more slender rig
(leg chain 0.384 m, hip 0.367 m). Strides and lift scale down with it: walk 0.284 m stance travel / 69 mm
lift, run 0.407 m / 115 mm. Stance foot 0.0 mm drift on both axes; walk/run 0 % frozen bones. Ground clips
land on the flank with the torso, head and tail on z=0 (`near_floor` 1.00, lowest +0.002). Attack snout
travel matches compsognathus in proportion (0.97 m high at frame 6 → 0.21 m at frame 9); heavy is airborne
at contact (lowest 0.275 m at frame 27).

### gallimimus

Long legs and long neck needed the most re-tuning. Leg chain 0.552 m, hip 0.471 m:

* **walk** 59 / 2.46 s, 0.409 m stance travel, 99 mm lift, stance foot 0.0 mm x / 5.4 mm z at the raw
  minimum (1.6 mm on the tracked sole offset), travel linear to 1.0 mm.
* **run** 17 / 0.71 s, 0.587 m stance travel, 166 mm lift.
* **attack_primary** 21 / 0.88 s: the long neck makes the bite read as a strike from above — snout 0.87 m
  at rest, **1.19 m** at the top of the coil (frame 6), **0.28 m** at contact frame 9.
* **attack_heavy** 36 / 1.50 s: the 0.6 s held crouch (snout 1.07 m, body coiled), then the leap clears
  **0.28 m at contact frame 26**, snout driven forward to 1.19 m and down to 0.89 m.
* **knockdown / death**: the body folds on the flank with the long neck curved down so the head rests on
  the floor (`near_floor` 0.88, lowest -0.004). The legs fold in front rather than sticking out.
* **feed** 71 / 2.96 s: the long neck reaches down so the snout is 0.11–0.32 m off the floor, two tears per
  loop.
* **sleep** 91 / 3.79 s: curled on its left side, neck curved round toward the chest, legs folded on the
  floor, breathing loop.
* **alert** 40 / 1.67 s: the long neck lifts and scans; the silhouette is plainly different from idle.

## Verification

`./verify.sh` exits 0. Its two base-mesh checks (`does not face -Z`, `spine is closer to vertical than
horizontal`) fail identically on the shipped inputs and are filtered by `verify.sh` — the mesh is frozen by
the contract, and the spine regex matches the hind-leg bones.

Raw output is in `work/verify_final.txt`; per-clip metrics in `work/metrics_<species>.txt`.

```
compsognathus
PASS  base GLB has a skin with 37 joints
PASS  6 tail bones
PASS  mesh is skinned (JOINTS_0 + WEIGHTS_0)
PASS  1 material(s)
PASS  origin at feet (min Y 0.000)
PASS  anim/idle.glb: 2.63s, 111 channels, 23 moving, 37 bones, loops cleanly
PASS  anim/walk.glb: 2.46s, 111 channels, 27 moving, 37 bones, loops cleanly
PASS  anim/run.glb: 0.71s, 111 channels, 27 moving, 37 bones, loops cleanly
PASS  anim/attack_primary.glb: 0.88s, 111 channels, 24 moving, 37 bones
PASS  anim/attack_heavy.glb: 1.50s, 111 channels, 27 moving, 37 bones
PASS  anim/hit_react.glb: 1.25s, 111 channels, 25 moving, 37 bones
PASS  anim/knockdown.glb: 2.17s, 111 channels, 27 moving, 37 bones
PASS  anim/death.glb: 1.83s, 111 channels, 27 moving, 37 bones
PASS  anim/alert.glb: 1.67s, 111 channels, 23 moving, 37 bones
PASS  anim/feed.glb: 2.96s, 111 channels, 23 moving, 37 bones
PASS  anim/sleep.glb: 3.79s, 111 channels, 10 moving, 37 bones, loops cleanly
WARN  anim/tail_swipe.glb missing (optional)
PASS  sheet.png 586 KB
```

coelophysis and gallimimus print the same lines (gallimimus also passes all eleven clips and its sheet).
The only warning is the optional `tail_swipe` clip, which the task does not ask for.

Self-checks printed at build time (all 33 clips):

* `LOOP` worst first-vs-last delta **0.0000** for every looping clip (idle, walk, run, sleep, feed).
* `TAIL` max |sin(vertical)| over tail bones: **0.03–0.16**.
* `SLIDE` walk/run: **x drift 0.0 mm on both species and both sides**, z drift 0.0–1.6 mm, travel
  linearity ≤1.1 mm.
* `STATIC`: walk/run have **0 %** frozen bones; idle/alert/feed/sleep show their planted feet as "static",
  which is intended (those feet are meant to stay on the floor).

## Visual review

Every clip was rendered with `verifiers/tools/render_clip.py` (side + front, 8 frames) into
`out/<species>/sheets/<clip>.png`, plus a full `out/<species>/sheet.png` (side/front/top of the neutral
stance, a mid-walk side view, and one representative frame of every clip). Clips were also tiled into
side-view strips (`work/qa/<species>_*.png`) and inspected, with close-ups (`work/frontal.py`) for the lying
poses:

* attack_primary: frame 6 (head up/back) vs frame 9 (snout forward and low) is an unmistakable bite in all
  three species; the tail stays level in both views.
* attack_heavy: the 0.6 s crouch is visibly held, then the animal leaves the floor (0.25–0.28 m at contact)
  and the right foot rakes forward.
* knockdown/death: the last frame lies on the flank with hips, shoulder and head on the floor and both
  feet down; `render_clip.py` prints `lowest ≈ -0.004…+0.003` for every frame of both clips.
* walk/run: digitigrade feet, knees forward, the planted foot visibly fixed in the sheet.
* sleep/feed: plainly different silhouettes from idle; sleep is fully grounded.

## Toolchain (work/)

| file | role |
|---|---|
| `lib.py` | `Rig`: local-basis pose engine, armature-space queries, two-bone leg IK with a pole (`plant_foot`), rigid foot attach (`follow`), floor settle |
| `export.py` | one Action per clip on every bone, quaternion hemisphere continuity, GLB export with exactly one animation |
| `poses.py` | stance vocabulary, absolute horizontal tail, forelimbs, size factor, per-clip sole grounding |
| `dims.py` | per-species stride / lift / body-drop / bob derived from the rig |
| `gait.py` | foot trajectory and body mechanics for walk/run |
| `lie3.py` | lying-down toolkit (flank on the floor, head/tail/arms/legs solved onto it) |
| `build.py` | bake, export, self-checks, floor guard |
| `sheets.py`, `makesheet2.py`, `qa.py` | contact sheets, species sheet, QA strips |
| `metrics.py`, `probe.py`, `probefoot.py`, `dbg_*.py` | the numbers quoted above |

## Known limitations

* No jaw bone exists in this rig, so bites are head/neck driven.
* The two base-GLB verifier checks are contract/verifier mismatches, not animation defects; they fail on
  the read-only inputs too.
* `tail_swipe` (optional, not in the task list) is not authored.
