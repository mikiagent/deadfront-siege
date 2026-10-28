# OCCLFIX — trees behind the survivor stay solid

Date: 2026-10-28. Owner bug: "Trees behind the player (from the camera's perspective) are going
translucent when they should stay solid until the tree hides the player model." Headless only: the
owner's `HEADLESS_ONLY` marker was present, so stage 2's windowed `occlude_lab` run is deferred. This
report is **not** visual approval; the on-screen check below still has to be done.

## Cause (found first, measured)

The CPU was never wrong. `Occlusion.in_the_way(chest, back)` walks from her chest only towards the
camera (ray `t >= 0`), so a prop behind her is never selected and its fade stays 0 — proved by the
new test on the unmodified code: all three prop kinds placed behind / in front / beside her gave
`in_the_way` = {front only} and fade 0 for behind and beside.

The fade came from the **fragment shader**. `occl_cut()` in `game/scripts/world/occlu_fade.gdshaderinc`
applied the survivor-silhouette rule to *every* prop, with no depth test and no "am I fading?" test:

```glsl
if (occl_body.w > 0.0 && dot(q, q) < 1.0) {
    if (max(trunk ? 0.0 : occl_drop, OCCL_COVER_DROP) > occl_bayer4(px)) { discard; }
```

So a solid tree (`occl_drop` 0) whose crown crossed her screen ellipse had `OCCL_COVER_DROP` (11/16 =
68.75 %) of those pixels discarded — exactly "behind the player, goes translucent".

Before/after, measured by the new test's GDScript mirror of `occl_cut` over a 40x40 probe grid of the
1600x1600 headless frame (her ellipse is ~161 px):

| | base code | after fix |
|---|---|---|
| pixels a **solid** prop (fade 0) drops over her silhouette | **337 of 928** (36 %) | **0** |
| pixels a **fading** prop still drops over her silhouette | 68.75 % | 68.75 % (unchanged) |
| CPU `in_the_way` behind / front / beside (mesh, MultiMesh, card) | {front} | {front} |

## What shipped

- `game/scripts/world/occlu_fade.gdshaderinc` — `occl_cut()` returns early when `occl_drop <= 0.0`,
  with the reason in the comment. Smallest change at the root: the shader only opens a prop that the
  CPU actually selected, i.e. one between the camera and the survivor. A real occluder's partial fade
  (whole object to ~half, `FADE_S` 0.25 s, trunks solid) and the "she always shows through a stack"
  cover share are unchanged.
- `game/tests/t_occlfix.gd` (new) — real `IsoCamera` + `Player` from `lab_kit`; spots from the live
  camera ray: **behind** 2 m up-screen (farther from the camera; at this pitch a tree past 2.6 m
  stands entirely above her head on screen, so 2 m is where a real crown overlaps her), **front** 4 m
  towards the camera, **beside** 3 m across. Each kind through its own path (plain `MeshInstance3D`
  via `occlusion_material`, VegBatch-style MultiMesh via the slots, CARD2D card via
  `make_card_occludable`): only the front prop is selected, only it reaches `BETWEEN_DROP`, the
  behind prop's `occl_fade` is never written (0), it takes no MultiMesh slot, and the shader's own
  lookup (`occl_drop_of` + `occl_match`, mirrored) gives it 0. Plus the `occl_cut` mirror above and a
  check that the include still contains the guard.
- `docs/current/occlusion.md` (new). Its row in `docs/current/README.md` is NOT added: that file is
  outside this job's SCOPE regex (`docs/current/[a-z-]+\.md`) — the integrator should add the row
  `| Occlusion (see-through props) | [occlusion.md](occlusion.md) |`.

No CPU change was needed; no constant was tuned; nothing outside the job's SCOPE was touched.

## Verification

- `game/tests/t_occlfix.gd` → `[t_occlfix] PASS`; on the base code it failed only the shader rule
  (337 px), the three selection cases passing — that is the reproduction.
- `t_occlude` PASS, `t_occlude2` PASS, `t_camera` PASS (no SCRIPT ERROR).
- `verify_job.sh occlfix 1` → `VERIFY STAGE 1 PASS`; full gate: stage 2 skipped by `HEADLESS_ONLY`,
  report + smoke + scope check as the full run reports.

## Assumptions

- `# ASSUMPTION`-free: no new numbers. The guard uses only the existing `occl_drop` (0 = solid).
- The test's "behind" spot (2 m) is geometric, from the headless 1600x1600 frame at the default 14 m
  zoom; it is not a gameplay tuning number.

## For the integrator / what still needs an on-screen check

1. **Windowed run to do:** at 1600x900, stand with a tree's crown over your head and the tree farther
   from the camera than you (walk towards the camera so the tree is up-screen) — it must stay fully
   solid. Then have a tree between you and the camera (up-screen of you, you below/behind it) — it must
   fade to ~half in 0.25 s with its trunk solid. `--lab=occlude_lab --occl-gates=<dir>` already has the
   pixel gates for the second case.
2. **Two drifted copies of the fade include:** `game/shaders/occlusion/occlusion.gdshaderinc` (CARD2D
   cards, out of this job's scope) has **no** `occl_body` at all, so cards never open over her
   silhouette — they were never part of this bug, and they do not have the new guard either (nothing
   to guard: no silhouette rule there). Folding the two copies back into one file is worth a job.
3. `occlu_fade.gdshaderinc` and the two `t_occlude*` tests still know about each other by source text
   (`t_occlude2`'s `body_rule`, `t_occlude`'s bayer formula); the guard is asserted in `t_occlfix` the
   same way, so keep that line if the comment around it is reworded.
