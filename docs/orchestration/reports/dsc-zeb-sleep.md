# dsc: zebraceratops sleep clip re-authored on the new mesh

## Result

| clip | before (measure_skin, --ignore Jaw,Head) | after |
|---|---|---|
| `anim/sleep.glb` | max=16.17 over2=1943 (legs tore when it lay down) | **max=4.12 over2=41** |
| `anim/feed.glb` | max=4.12 over2=261 | unchanged (kept; see below) |

Verify: `tools/gait/measure_skin.py ... sleep.glb --ignore Jaw,Head` prints over2=41 (< 300) and
`tools/smoke.sh` prints `SMOKE PASS` (runner gate prints `ZEB PASS`).

Clip shape is unchanged: one action `sleep`, 67 keys, 24 fps, 0.0417 s .. 2.7917 s, frame 67 == frame 1
(same length and loop as the clip it replaces).

## What the new clip is

The animal lies on its flank (rigid 88 deg roll about the forward axis), body settled on the floor
(`root` translation, so the lowest skin vertex sits at z = 0), head curled down to the ground, legs
folded at the knee with the paws tucked against the belly, tail curled along the ground, and a slight
breath in the neck/head/tail so it is not frozen. Rigid root transforms do not change any edge length,
so the roll and the floor settle contribute 0 torn edges; the remaining 41 edges are the paw/ankle seam
where the Tripo skin binds sole vertices partly to `Shoulders`/`Back` (see below).

## Why the old clip tore and what the skin allows

- `BackFoot.*` / `FrontFoot.*` are children of `root`, not of the shanks, and the paw/sole vertices are
  skinned 20-30 % to `Shoulders`/`Back`/`Neck` with rest edge lengths of ~2 mm. Any pose that moves a
  paw relative to the body tears that seam: a full leg tuck alone measured over2 46-256, a belly-down
  prone attempt 128-3800 depending on the fold.
- Measured clean: the rigid flank roll (over2 0), thigh folds up to ~half of the old tuck table
  (over2 3 at 0.4 scale), and knee folds with the paw carried by the shank (over2 41 at hind -70 /
  front -50 deg). Larger knee folds stay under 150 but the visible tear count grows, and the paws start
  to poke through the belly.
- `--ignore Jaw,Head` hides the head and mouth, which move by design.

## feed.glb (kept unchanged)

Measured 261 (worst frame 41); the task said keep it unless over2 could be brought under 120 "the same
way". It cannot: the same 2 mm paw/ankle seam is the floor. `work/sleep/feed_damp.py` damps the
Neck/Head rotation frame by frame and re-scores the real mesh:

| Neck/Head rotation scale | over2 (worst frame) |
|---|---|
| 1.0 (shipped) | 268 |
| 0.7 | 224 |
| 0.5 | 212 |
| 0.35 | 212 |

Past 0.5 the count stops falling — the remainder is `BackFoot.L/R` (86-88 edges) moving over the body,
which damping the neck cannot fix. Reaching 120 would mean re-authoring the eating motion (paws pinned
and the whole body stepping through the lunge) rather than a pose tweak, and feed is already inside the
300 gate, so feed.glb and feed.glb.import are untouched.

## Renders (judged by eye)

- `game/assets/creatures/zebraceratops/work/sleep/renders/final_f001_side.png` … `_f067_side.png`
  (`--frames 1,17,34,50,67 --views side --span 1.5 --forward -0.3 --down 0.3`, the framing the task
  asked for)
- Wider checks: `renders/k70_f017_side.png`, `renders/k70_f017_top.png`, `renders/wide_f017_side.png`,
  `renders/wide_f017_top.png` (span 2.2, side/threeq/top).
- The animal reads as asleep: body on the ground, head down, legs folded under the belly, no spikes,
  no holes, no stretched flaps.

## Code

Everything used to author the clip is in `game/assets/creatures/zebraceratops/work/sleep/`
(ignored by Godot): `build.py` (the exporter that wrote `anim/sleep.glb`), `explore.py`, `sweep.py`,
`fold.py`, `diag.py` (measurement/sweeps). To rebuild:

```
/Applications/Blender.app/Contents/MacOS/Blender -b -P game/assets/creatures/zebraceratops/work/sleep/build.py -- \
  game/assets/creatures/zebraceratops/zebraceratops.glb \
  game/assets/creatures/zebraceratops/anim/sleep.glb \
  --hind 0 --front 0 --spine 0.5 --knee-b -70 --knee-f -50 --paw 1
```

`--out -` scores a pose without exporting.

## Open

- The paw/ankle seam is a rig/skin issue, not an animation one. It would go to 0 if the paw vertices were
  re-weighted off `Shoulders`/`Back` or the foot bones parented to the shanks in the mesh pipeline (owned
  by the art-pipeline agent); that also unblocks a proper feed clip under 120.
