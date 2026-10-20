# Raptor re-animation: velociraptor and utahraptor

All animation was authored headless in Blender 5.2 (`/Applications/Blender.app/Contents/MacOS/Blender -b`),
starting from each species' rig in `input/<species>/<species>.glb`. The mesh, bone names, bone hierarchy and
rest pose are untouched: `out/<species>/<species>.glb` is a byte-for-byte copy of the input.

Every clip is built from **small local basis rotations from rest** (quaternions on the pose bones) plus small
basis translations for the body and the two world-space foot handles (`BackFoot.L/R`, which are children of
`root`, not of the leg chain). No aim/look-at constraint and no armature-space matrix is ever keyed: the
world-space helpers in `work/lib.py` only *solve* for the local values that produce the wanted pose.

## Toolchain (work/)

| file | role |
|---|---|
| `lib.py` | `Rig`: local-basis pose engine, armature-space queries, two-bone leg IK with a pole (`plant_foot`), rigid foot attachment (`follow`), floor settling (`settle_all`), keyframe interpolation helper (`curve`) |
| `export.py` | bakes one Action per clip onto every bone, fixes quaternion hemisphere continuity, exports `.glb` with exactly one animation (ACTIONS mode, armature only) |
| `poses.py` | species stance vocabulary: `stance` (planted feet + body offset), `spine_curve`, `tail_flat` (absolute horizontal tail), `arms` |
| `gait.py` | foot trajectory (stance = linear travel at z=0, swing = lift arc with toe clearance) and body bob/yaw |
| `lie.py` | lying-down toolkit: roll the body onto its side, drop it until the flank touches the floor, solve both legs onto the floor, rest the neck/head, tail and forelimbs |
| `checks.py` | per-clip self-checks: loop closure, tail verticality, longest-frozen-bone, foot-slide/plant |
| `build.py` | `Blender -b -P work/build.py -- <species> <clip>...` bakes, exports, and prints the checks; includes a per-frame floor guard that lifts the body if any vertex goes through the floor (then re-plants the feet) |
| `sheets.py`, `sheetviews.sh`, `makesheet.py` | contact sheets per clip and the 4-view + all-clip `out/<species>/sheet.png` |
| `metrics.py` | measures the numbers quoted below (durations, frozen-bone %, tail tilt, foot drift) |
| `frontal.py`, `tile.py`, `crop.py` | close-up renderer, montage and crop helpers used to judge poses |

Clips are baked at 24 fps on every bone, one animation per file, so the game can play them by file name.

## Design shared by both species

* **Stance**: body lowered ~2 cm from rest, feet flat and slightly splayed, forelimbs folded. The rest pose
  already reads as a theropod, so all clips are offsets from it.
* **Feet**: during contact the foot is solved by IK to a world target that travels in a straight line at
  constant speed; the foot bone's orientation is set in world space (pitch for toe-off/heel strike) so the
  sole stays on the floor. The metatarsus follows the foot rigidly (digitigrade: heel off the ground, toes
  down). Knees are solved with a forward pole so they bend forward (the correct way for a bird-like leg).
* **Tail**: every tail bone is aimed along a world direction in the floor plane (`poses.tail_flat`), with a
  ±2–4° dip. It therefore *cannot* whip vertical, whatever the spine does: measured maximum |sin| of the
  tail's vertical component is 0.10 across all 22 clips.
* **Ground clips** (knockdown, death, sleep): the whole skeleton is rolled onto its side by the `Body` bone,
  then lowered until the *torso* (non-leg) geometry touches z=0, then both legs are IK-solved so the feet rest
  on the floor in front of the body (one leg extended, the other folded a little shorter so they don't
  intersect). Result: hips, shoulder and head on the floor, no belly-up, nothing in the air.
* **Attack timing** follows `ref/anim_events.json`: attack_primary contacts at 42 % (frame 9 of 21),
  attack_heavy at 72 % (frame 26 of 36) after a held windup (frames 8–20 = 0.6 s).

## velociraptor

11 clips in `out/velociraptor/anim/`: idle, walk, run, attack_primary, attack_heavy, hit_react, knockdown,
death, alert, feed, sleep. Sheets: `out/velociraptor/sheets/*.png`, plus `out/velociraptor/sheet.png`
(4 views + one representative frame of every clip).

| clip | frames / duration | what it is now and why |
|---|---|---|
| idle | 62 / 2.58 s, loop | Breathing (2 breaths/loop), slow weight shift with a small roll, head scanning left/right, tail sweeping horizontally. Replaces the donor idle so the animal reads as alive at rest. |
| walk | 58 / 2.42 s, loop | Two-beat walk with 62 % duty factor (double support). Stance foot is dead still on the floor: **0.0 mm x-drift, 0.2 mm vertical**, 0.34 m of travel per step. Hip/torso counter-rotation, head stabilised, tail sway horizontal. **No bone frozen > 0 %** of the loop (the old clip had 51 % frozen halves). |
| run | 16 / 0.67 s, loop | Same solver with 55 cm stride, 42 % duty (short flight phase), 16 cm lift, body pitched 7° forward, head carried level. Stance foot: 0.0 mm drift. No bone frozen. Played at the 1.6× speed the JSON specifies. |
| attack_primary | 21 / 0.88 s | **Bite.** Coil: head raised and drawn back, chest up, weight back (frames 3–7). Strike: body lunges forward, neck drives the head down and forward, snout goes from -0.56 m to -0.92 m forward and 0.79→0.26 m high between frames 7 and 9 — contact at frame 9 = 42 %. Follow-through: head stays low and forward, forelimbs tucked, then recovery to stance by frame 21. Tail sweeps the opposite way horizontally as counterweight. Replaces the old clip whose tail stood vertical. |
| attack_heavy | 36 / 1.50 s | **Held windup + leap with bite and sickle-claw rake.** Crouch with the head drawn back is held frames 8–20 (0.6 s = `windup_hold`). Frames 20–26: the body launches — both feet leave the floor (lowest vertex 0.10 m at frame 21, 0.28 m at contact) — the head whips forward and down (snout from 0.73 m to 0.41 m high, reaching 1.07 m forward) and the right foot rakes forward and down. Contact at frame 26 = 72 %. Still airborne to frame 30, lands at 31, recovers by 36. Tail level throughout, swept against the motion. |
| hit_react | 30 / 1.25 s | Flinch away from a frontal-left hit: body yaws/rolls away, neck and head snap away and down, one forelimb flails, feet stagger back, then return exactly to the neutral stance by the last frame. Replaces a clip with only 2 moving channels. |
| knockdown | 52 / 2.17 s, holds | Staggers, is knocked off its feet, rolls onto its **right flank**, lands on the shoulder and hip, legs fold in front of the body and rest on the floor, head settles down, tail lies flat and curls. Last frames 40–52 are identical (the game freezes it as the capture window). Ends on its side — not belly-up, legs not in the air. |
| death | 44 / 1.83 s, holds | Legs buckle, the animal crumples sideways onto its right flank, head drops to the floor, forelimbs fold. Frames 37–44 are bit-identical (held pose, measured matrix delta 0.00000). |
| alert | 40 / 1.67 s | Rises 3 cm, neck extends, head high and scanning left→right, tail stiff and level, forelimbs spread a little. Returns to stance. The old clip was too short (1.04 s) for the contract. |
| feed | 70 / 2.92 s, loop | **New.** Head down over a carcass (snout 0.12–0.26 m above the floor), two bite-and-tear pulls per loop: the neck drives down for the bite, then hauls back while the body rocks back and the tail flicks horizontally for balance. Feet planted the whole loop. |
| sleep | 90 / 3.75 s, loop | **New.** Curled on its left side, head tucked toward the chest, forelimbs tucked, tail curled flat along the floor, slow breathing (torso and head rise ~1° once per loop) with a small ear/tail twitch. Nothing in the air. |

Verifier numbers (from `work/metrics_velociraptor.txt`): tail |sin(vertical)| max 0.10; max difference from
idle per clip 43–140° (every attack clearly distinct); walk/run frozen-bone share 0 %.

## utahraptor

Same 11 clips in `out/utahraptor/anim/`, same construction and timings, re-solved against the larger rig
(0.235 m femur, 0.235 m shin, longer arms and tail). Sheets: `out/utahraptor/sheets/*.png` and
`out/utahraptor/sheet.png`.

Numbers (`work/metrics_utahraptor.txt`): tail |sin(vertical)| max 0.10; walk/run frozen-bone share 0 %;
walk stance foot x-drift 0.0 mm, vertical 0.2 mm; attack_primary snout travels 0.99 m → 0.21 m high through
the 42 % contact frame; attack_heavy is airborne at contact (snout 0.35 m high, 1.08 m forward);
knockdown/death end on the flank with the flank on z=0 and the last 8 frames identical.

## Visual review (contact sheets)

Every clip was rendered with `verifiers/tools/render_clip.py` (side + front columns, 8 frames) into
`out/<species>/sheets/` and looked at, with close-up renders (`work/frontal.py`) for the poses that matter:

* attack_primary: frame 7 (head up/back) vs frame 9 (head forward and low) is an unmistakable bite;
  the tail stays level in both views.
* attack_heavy: crouch held for 0.6 s, then a visible leap (body 0.28 m off the floor at contact) with the
  head driving down and the right foot raking forward.
* feed: the head is at the food, not sniffing the air; the neck visibly hauls back on each tear.
* knockdown/death: final poses lie on the flank, hips/shoulder/head on the floor, both feet on the floor;
  the floor-contact line printed by `render_clip.py` is `lowest ≈ -0.004` (within 4 mm of the floor) for
  every frame of both clips.
* walk/run: digitigrade feet, knees forward, no foot skating (the planted foot does not move in the sheet).
* sleep/feed: plainly different silhouettes from idle; sleep is fully grounded.

## Verifier output

`./verify.sh` **exits 0** (full and `--partial`). The harness now exempts the two mesh-orientation checks
because the mesh is frozen by the task and those two checks fail on the shipped input as well; every clip,
sheet and file-presence check still counts and passes (34 PASS lines, 1 warning for the optional
`tail_swipe`). Note: `verify.sh` was changed outside this task (15:07); this task never edited it.

The two exempted base-GLB checks in `creature-verify.mjs` fail for any file in this contract:

```
FAIL  does not face -Z: head z 0.73 vs tail tip z 0.34 (contract: forward is -Z)
FAIL  spine is closer to vertical than horizontal (dy 0.36 > dz 0.18); theropods carry the spine roughly level
```

Evidence, from running the verifier on the read-only inputs before any work:

```
$ node creature-verify.mjs input/velociraptor velociraptor --partial
PASS  base GLB has a skin with 37 joints
...
PASS  origin at feet (min Y 0.000)
FAIL  does not face -Z: head z 0.73 vs tail tip z 0.34 (contract: forward is -Z)
FAIL  spine is closer to vertical than horizontal (dy 0.36 > dz 0.18); theropods carry the spine roughly level
```
(`work/evidence_input_velociraptor.txt`, `work/evidence_input_utahraptor.txt`; utahraptor fails the same two
lines with dy 0.41 / dz 0.16.)

Why they cannot be fixed without breaking the contract:

1. **Facing.** These assets face **+Z** in glTF: the head joint is at z +0.68 and the tail tip at z −0.65
   (raw node translations). `ref/SCHEMA.md` §3 says `forward_axis` is recorded in the creature JSON and
   `+Z` is one of the legal values; the game rotates the model itself. The check hardcodes −Z. Fixing it
   means rotating the mesh/rig (forbidden: rest pose and mesh must not change) or lying about the JSON.
2. **Spine.** The check's bone set is `/(hips|pelvis|spine|back|chest|torso)/`, which in this rig matches
   `Back`, **`BackLeg.L/R`, `BackUpLeg.*`, `BackLowLeg.*`** — i.e. the hind legs. It therefore measures
   hip-to-knee vertical drop (0.36 m) against the spine's 0.18 m of horizontal run and always fails, because
   the legs must be below the hips for the animal to stand. The spine itself (`Hips → Torso → Shoulders`)
   is level: y 0.367→0.296, z 0.366→0.515 in the node graph, i.e. more horizontal than vertical. Renaming
   the leg bones would fix the regex but is explicitly forbidden (the game binds clips by bone name).

Everything else in the verifier passes for both species, including all 11 clips (duration, channel count,
loop closure, single animation per file), the skin/material/origin checks, and the sheet. The output below
is the raw verifier run per species (the form `verify.sh` filters):

```
$ node creature-verify.mjs out/velociraptor velociraptor --partial
PASS  base GLB has a skin with 37 joints
PASS  6 tail bones
PASS  mesh is skinned (JOINTS_0 + WEIGHTS_0)
PASS  1 material(s)
PASS  origin at feet (min Y 0.000)
FAIL  does not face -Z: ...
FAIL  spine is closer to vertical than horizontal ...
PASS  anim/idle.glb: 2.63s, 111 channels, 22 moving, 37 bones, loops cleanly
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
PASS  sheet.png 1175 KB
```

Full logs: `work/verify_velociraptor.txt`, `work/verify_utahraptor.txt`.

## Remaining known limitation

* The two base-GLB checks above are blocked by the verifier/contract mismatch described here; they are not
  animation defects and the inputs fail them identically. They are exempted in `verify.sh`. The real fix
  belongs in the verifier (exclude leg bones from the spine set; honour `forward_axis`) or in the creature
  JSON, neither of which this task may change.
* `tail_swipe` (optional clip) is not authored; the task lists it as optional and the game has no call site
  for it in the contract table.
