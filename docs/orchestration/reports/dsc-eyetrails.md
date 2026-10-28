# DSC — EYETRAILS: motion trails behind the glowing eyes

Owner request (2026-10-28): "Also add trails to the glowing eyes", refined mid-task to "a FLAME IN THE
WIND — a streak that lags behind the eye as the head moves, tapering, with a little flicker/turbulence
(noise-driven width/alpha wobble and slight upward/sideways drift)".

## What shipped

| File | Change |
|---|---|
| `game/scripts/creatures/eye_trail.gd` | **new** `class_name EyeTrail extends MeshInstance3D`: one ImmediateMesh, one surface, both eyes; additive/unshaded/no shadow/no depth write; `top_level` world-space vertices; ring buffer <= 12 samples/eye; flame shaping (taper, power-tipped alpha, hot head, drift, two-sine flicker); distance cull; per-species knobs. |
| `game/scripts/creatures/creature_eyes.gd` | builds the trail after the two dots (`trail`, child of the Eyes node) and ticks it from `_process(delta)`. Species eye points untouched. |
| `game/tests/t_eyetrails.gd` | **new** acceptance test, plus an optional windowed look-pass (`-- --shot-dir=DIR`). |
| `docs/current/eyes.md` | **new** current-implementation doc (dots + trail, knob table, cost, tests). |

No new JSON under `game/data/creatures/`: `Data._load_creatures` parses *every* `*.json` in that folder
as a species and logs `malformed ... creature json missing species` for anything else (verified by
dropping a probe file in and running `t_eyeglow`; it printed exactly that failure line). Knobs are named
constants in `eye_trail.gd` with an optional per-species `"trail": {...}` object inside the existing
`eyes` block. `data.gd` is not in this task's scope, so that is the honest data path.

## Before / after numbers

| Measure | Before | After |
|---|---|---|
| eye trail | none | 1 mesh + 1 draw call per eyed creature while it shows |
| tick cost, 20 ribbons at full strength | — | **0.04–0.05 ms/frame** (measured in `t_eyetrails`, 240 frames) |
| worst geometry per creature | — | 2 eyes × 13 points × 6 verts = 156 verts |
| samples held per eye | — | ≤ 12 (asserted), both eyes ≤ 24 |
| streak length on screen, game camera | — | ~84 px at 1600x900, 15 m screen height |
| width flicker (rel. spread over 60 moving frames) | — | **0.42** with `flicker` 0.45, **0.00** with `flicker: 0` |

## Shots I looked at (and judged)

All under `$TMPDIR/eyetrails/shots/`:

1. `flame_89.png` — black: the look-pass camera stayed at the origin while the animal ran out of shot.
   Not a trail verdict; the pass was fixed to ride with the animal.
2. `flame_79.png` (2nd) — framed on the feet, label in frame, no trail visible. Framing bug, not the trail.
3. `flame_79.png` (3rd/4th) — eye close-up: a yellow-green streak is drawn across the skull, so it
   renders in the eye colour and trails correctly, but the framing was too tight to judge shape.
4. `flame_game.png` — real iso camera on the body: a small yellow glint at the brow; the 84 px streak is
   there but the night is very dark and the head sits near the frame edge. Read: "a glint that smears only
   at speed", which is the intent.
5. `flame_head.png` (side-on, final) — **GOOD**: two tapered yellow-green streaks streaming off the eye
   line, whitening at the head, dissolving to a point at the tail, rising slightly and stepping with the
   flicker. Reads as "flame in the wind" at head close-up.
   **Caveat:** in this lab frame the eye dots themselves draw dark (the lab's own camera/lighting, plus the
   shared eye material only repaints on a night change inside `CreatureEyes._process`; the look-pass now
   calls `CreatureEyes.apply_night()` itself). Brightness balance between streak and dot is therefore not
   settled by this shot — the game-camera frame shows the dot glint and reads correctly in-game. Owner
   visual pass still wanted; if the streak ever outshines the dot, lower `ENERGY` in `eye_trail.gd`.

## Assumptions (all marked `# ASSUMPTION` in code)

- Fade 0.22 s (owner gave 0.15–0.3); the test asserts the constant stays in that band.
- Head speed 0.9 m/s starts the trail, 3.2 m/s is full strength (a lunge is 4+ m/s), 0.9 m length cap,
  55 m camera cull, width 1.9 × eye radius, brightness 2.2 × the dot.
- Flame look: flicker 0.45 @ 13 Hz, drift 0.55 m/s up/sideways, taper 0.16, tip power 1.8, hot head 0.30.
- The trail obeys the eyeshine's own visibility rule (awake and not sleeping/dead) *and* the same night
  fraction, with a floor: below 2 % glow (daytime glint) no ribbon is built.
- Trails are culled by the active camera's distance, because the iso camera is 40 m from the survivor and
  any player-relative radius would either cull everything or nothing.

## Verified

- `verify_job.sh eyetrails 1` green; mutation-checked (removing the visibility gate, the sample cap, the
  distance cull and the flicker noise each make the test fail).
- Related `t_eyeglow` green after the deinonychus import by-products were restored (see below).
- Rendered look-pass; the shots above are from that pass, not from the headless gate (HEADLESS_ONLY).

## What the integrator needs to know

1. **The visual lab is deferred** (`HEADLESS_ONLY` present), so there is no stage-2 visual approval from
   the gate. The judge evidence is the look-pass PNGs, which want a human eye at 1600x900.
2. **Deinonychus import by-products.** This worktree was cut at `f330e3bf`, which predates the art thread's
   `b11af93b` (that commit adds the three textures Godot unpacks from the new deinonychus GLB). Running
   `--import` here re-creates them, and a checkpoint commit picked them up; they are byte-identical to
   `b11af93b`'s blobs and outside this task's SCOPE. They were put back to the merge-base state (absent),
   and `t_eyeglow` passes without them once the stale `.godot/imported` scene is regenerated. The earlier
   "deinonychus has no Eyes node" failure came from that stale import cache, not from the missing files.
   **Merge `b11af93b` (or rebase onto it) before shipping the animal's look**; nothing in the trail needs
   those files.
3. `docs/current/README.md` (the index) is outside SCOPE (`README.md` does not match `[a-z-]+\.md`), so
   the new `docs/current/eyes.md` has no index row yet — one line to add.
4. Nothing tuned: no stats, no balance numbers touched.
