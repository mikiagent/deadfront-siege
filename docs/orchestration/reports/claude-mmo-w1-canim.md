# W1-CANIM: creature animation runtime that obeys time scale and speed

Branch `claude/mmo-w1-canim` (from `claude/mmo-overhaul` at ea2d167). Commits: `baf01f5` runtime, bake
tool, data, test; `3a33685` lab and assumption markers; `ba9306f` review round 1 fixes; review round 2 (limp factor, `is_busy`, report); this report. Closes dino-art-05, dino-art-10
(runtime half), dino-art-03 (loop-trim half), dino-art-04 (runtime half; wiring is W2-CVIEW).
Credits spent: 0.

## What shipped

- `game/scripts/creatures/creature_anim.gd`: every state machine state is now a BlendTree
  `clip -> AnimationNodeTimeScale`. The tree ignored `AnimationPlayer.speed_scale`, so run x1.6, the
  T. rex retiming and every other cadence change were dead. Now:
  - `play_timed_attack(clip, windup)` retimes through the state's TimeScale; the T. rex heavy hit
    frame lands at the brain's 1.2 s impact (was 0.648 s late: the clip is 2.567 s, hit at 1.848 s).
  - `set_move_speed(mps)`: picks walk or run from baked natural stride speeds and sets the cadence to
    mps / natural speed, so the planted foot keeps pace with the ground. Falls back to the legacy path
    when a species has no baked data (placeholders).
  - `set_time_scale(x, factor = &"base")`: global multiplier over every state's cadence. Each caller
    owns a named factor and the tree plays at their product, so the limp (`&"fracture"`) survives a
    hit-stop or slow writing `&"base"` (review round 2).
  - `is_busy()`: read-only view of the one-shot busy flag.
  - Walk and run are separate states with a 0.2 s crossfade (was a linear BlendSpace1D of two
    unsynced gaits). Legacy `play_locomotion(frac)` keeps its call shape: run above 0.55, run at the
    anim_events cadence (1.6, which now actually applies).
  - `sleep` and `tail_swipe` nodes are built when the species has the clip (T. rex); `play_clip` on a
    missing clip goes to idle with no travel to a missing node. `feed` keeps its node (idle copy where
    not authored, as before). `tail_swipe` is a one-shot attack (busy, `attack_hit`, `attack_done`).
  - One-shot hit and end events fire from tree time (review round 1; were wall-clock timers). `player.play()` is no longer called next
    to the tree (it double-drove the skeleton; the tree won every frame).
- `game/scripts/creatures/creature_clips.gd`: `trim_frozen_tail()` cuts a looping clip where a static
  tail of 25 % or more begins (tolerance 5 % of each bone channel's own swing; cached per
  species/clip). The six donor biped walks go 2.458 s -> 1.209 s (coelophysis 1.229 s); the cut pose
  matches frame 0, so the loop is seamless. Applied to walk and run at `CreatureAnim.setup`.
  `natural_speed(def, clip)` reads the baked speed and scales it with `height_meters`.
- `tools/bake_clip_speeds.py`: runs headless Godot with the game's own clip loader, trims, measures
  each species' walk/run planted-foot speed on the left and right foot (stride method of the
  dino-art audit, 240 samples), bakes their mean, and marks a gait `<gait>_replace` with no speed
  when one foot strides more than 1.6x the other. Rebake after changing any walk/run GLB.
- `game/data/creatures/anim_events.json`: `natural_speeds` for the 10 GLB species, spliced in as the
  last key; the hand-formatted lines above it are byte-identical to the branch point (review fix).
- `game/tests/t_canim.gd`, `game/scripts/dev/creature_anim_lab.gd` + `game/scenes/dev/creature_anim_lab.tscn`.

Deviations from the spec's file list:
- No `clip_speeds.json`: `Data._load_creatures` (data.gd:112) parses every other `*.json` in
  `data/creatures` as a species and fails without `species`. The speeds live in `anim_events.json`
  (owned), which Data already loads. No data.gd change needed.
- Test file is `game/tests/t_canim.gd` (wave-1 convention), not `t_creature_anim.gd`.

## Review round 2

| Finding | Fix | Check that would have caught it |
|---|---|---|
| major: limp still broken (creature.gd:393-394 writes `ap.speed_scale = 0.65`, which the tree ignores; no hook) | `set_time_scale` takes a named factor; product of all factors. W2-CVIEW hook added below. The old line also never reset `speed_scale` when fracture ended | t_canim: `limp: fracture 0.65 x base 0.5 ... 0.325` and `limp: fracture 0.65 kept after base reset to 1.0 ... 0.650` |
| minor: quadruped/T. rex gait picks look poor with donor clips | Agreed, asset problem. Replacement rows kept; W2-CVIEW hook says not to wire `set_move_speed` for quadrupeds and the T. rex until W2-RERIG clips land (or cap cadence near 3x) | n/a (asset) |
| minor: rex sleep row omits the float | Row now says the body floats about 1 m above the ground (root height) | n/a (report) |
| minor: server hit timing depends on the tree | Note for W1-SRVDOM added under risks | t_canim item 2b drives `tree.advance()` manually, the path a server would need |
| minor: test reads `anim._busy` | `is_busy()` added; test reads it | `grep _busy game/tests/t_canim.gd` is empty |

## Review round 1 (commit ba9306f)

| Finding | Fix | Check that would have caught it |
|---|---|---|
| major: stride check circular (left foot only) | Bake measures both feet, bakes the mean; feet >1.6x apart -> `<gait>_replace`, no speed (runtime then falls back: legacy path if both gaits are out, else the other gait) | t_canim asserts the ratio on both feet (item 3) |
| major: one-shot timers ignore a mid-clip time-scale change | `attack_hit` and `attack_done` fire from tree time, polled on `AnimationTree.mixer_applied` (fires on idle and manual `advance()`; `mixer_updated` does not). Wall-clock timers removed. Replaying a one-shot the machine is still on uses `start()` (found by the new test: `travel` to the current node did not replay it, so a back-to-back attack finished instantly) | item 2b |
| major: replacement list incomplete | Rows added below; sleep pose description corrected after re-looking at the screenshot | n/a (report) |
| minor: NaN/INF | `set_move_speed` / `set_time_scale` return on non-finite input | item 2c |
| minor: stale bakes | `natural_speed(def, clip, clip_len)` ignores a bake whose `*_len` differs by >1 %, one print per species/gait | item 2c |
| minor: copied windup constant | Test drives the real `TyrantBrain._do_attack()` (third attack = heavy) and reads `phase_left`; brains/ is W1-AI's, so no const was added there. Normal `play_clip` hit timing is asserted at time scale 0.5 | item 2, 2b |
| minor: anim_events.json reformat | Bake splices `natural_speeds` in as the last key; the rest of the file is byte-identical to ea2d167 | `git diff ea2d167 -- game/data/creatures/anim_events.json` shows only added lines |
| minor: tail_swipe interrupted by hit_react | Listed under W2-CVIEW hooks (creature.gd is not mine) | n/a |
| minor: test/lab read private members | Added `current_state()`, `cadence(state)`, `has_state(clip)`; the test reads play positions from `tree.get("parameters/playback")`. The test still reads `_busy`, which brains, hunt.gd and probes already read | n/a |

On the 30 % threshold: with both feet measured, the velociraptor walk (L 0.839, R 0.643, 1.30x) and
run (L 3.14, R 4.30, 1.37x) and utahraptor (1.49x, 1.39x) exceed 30 %, so a 30 % rule would mark the
acceptance species' clips REPLACE and leave nothing to stride-match. 1.6x is where a mean cadence
can no longer keep both feet inside the [0.75, 1.30] acceptance window (that limit is 1.67x). It
marks exactly the clips the review named: coelophysis walk (2.02x) and run (2.74x), compsognathus
run (1.95x), gallimimus run (4.82x). The 1.3-1.6x clips are baked and still listed for replacement.

## Acceptance checklist (exact output lines, run on ba9306f, rerun after review round 2 on 2026-10-19)

Command: `Godot --headless --path game --script res://tests/t_canim.gd` (exit 0).

1. Time scale (was 1.000):
   `[t_canim] ok   velociraptor attack_primary timed to 2.0 s: time scale 0.184, tree advance / wall = 0.184 (want 0.16-0.21, was 1.000)`
   `[t_canim] ok   velociraptor run at anim_events speed 1.6: tree advance / wall = 1.600 (want 1.5-1.7)`
   `[t_canim] ok   set_time_scale(0.5) on idle: tree advance / wall = 0.500`
   1b. Limp (dino-art-10), named factor survives a base write (review round 2):
   `[t_canim] ok   limp: fracture 0.65 x base 0.5 on idle: tree advance / wall = 0.325 (want 0.325)`
   `[t_canim] ok   limp: fracture 0.65 kept after base reset to 1.0: tree advance / wall = 0.650`
2. T. rex heavy sync (was 0.65 s late), windup read from TyrantBrain:
   `[t_canim] ok   tyrannosaurus attack_heavy (len 2.567 s, hit_frac pos 1.848 s): animation hit at 1.208 s, TyrantBrain damage at 1.200 s, gap 0.008 s (want <= 0.05, was 0.65)`
   2b. One-shot events in tree time:
   `[t_canim] ok   velociraptor attack_primary, time scale 0.5: attack_hit at 0.737 s (want 0.735), attack_done at 1.750 s (want 1.750), busy after false (was hit 3.399 s, done 8.477 s for hit-stop)`
   `[t_canim] ok   velociraptor attack_primary, hit-stop 0.1 for 0.1 s then 1.0: attack_hit at 0.458 s (want 0.458), attack_done at 0.967 s (want 0.965), busy after false (was hit 3.399 s, done 8.477 s for hit-stop)`
   2c. Guards:
   `[t_canim] ok   set_move_speed(NAN/INF) and set_time_scale(INF/NAN) are ignored: idle cadence 1.0`
   `[t_canim] ok   velociraptor walk bake: 0.741 m/s on the 1.209 s clip, 0.000 on a 5 % longer clip (stale bake ignored)`
3. Stride match at walk and run speed, both feet:
   `[t_canim] ok   velociraptor set_move_speed(2.80) -> run x0.75: planted feet L 2.36 R 2.96 m/s, ratio L 0.84 R 1.06 (want 0.75-1.30)`
   `[t_canim] ok   velociraptor set_move_speed(7.00) -> run x1.88: planted feet L 5.91 R 8.41 m/s, ratio L 0.84 R 1.20 (want 0.75-1.30)`
   `[t_canim] ok   megaloceros set_move_speed(3.04) -> run x7.31: planted feet L 3.04 R 3.04 m/s, ratio L 1.00 R 1.00 (want 0.75-1.30)`
   `[t_canim] ok   megaloceros set_move_speed(7.60) -> run x16.00: planted feet L 6.66 R 6.66 m/s, ratio L 0.88 R 0.88 (want 0.75-1.30)`
   `[t_canim] ok   protoceratops set_move_speed(1.68) -> run x2.67: planted feet L 1.68 R 1.68 m/s, ratio L 1.00 R 1.00 (want 0.75-1.30)`
   `[t_canim] ok   protoceratops set_move_speed(4.20) -> run x6.67: planted feet L 4.20 R 4.20 m/s, ratio L 1.00 R 1.00 (want 0.75-1.30)`
   `[t_canim] ok   tyrannosaurus set_move_speed(1.80) -> walk x0.88: planted feet L 1.80 R 1.80 m/s, ratio L 1.00 R 1.00 (want 0.75-1.30)`
   `[t_canim] ok   tyrannosaurus set_move_speed(4.50) -> walk x2.20: planted feet L 4.50 R 4.50 m/s, ratio L 1.00 R 1.00 (want 0.75-1.30)`
   The quadrupeds and the T. rex walk are symmetric, so their ratios stay 1.00: the mean-of-two-feet
   bake still uses the same method as the test, so the check proves both feet track, not that the
   method is right in absolute terms.
4. Biped walk loops (was 51 %):
   `[t_canim] ok   7 biped walk loops: longest frozen span 0 % (want <= 25 %, was 51 %)`
5. Optional clips:
   `[t_canim] ok   tyrannosaurus play_clip(sleep): state machine on sleep`
   `[t_canim] ok   tyrannosaurus play_clip(feed): state machine on feed`
   `[t_canim] ok   tyrannosaurus play_clip(tail_swipe): state machine on tail_swipe`
   `[t_canim] ok   velociraptor play_clip(sleep) has no sleep node and stays on idle`
   `[t_canim] PASS`
6. Rig imports (`--script ../tools/verify_rig_imports.gd`, exit 0): `RIG IMPORT PASS: 99 clips through production loader`
7. Regression: `tools/smoke.sh --no-import` -> `SMOKE PASS`; `--script res://tests/run_all.gd` -> `[tests] PASS`.
8. Lab headless (`--lab=creature_anim_lab`), real idle-mode tree:
   `[canimlab] t=0.1 velociraptor  run x0.75  2.8 m/s | protoceratops  run x2.67  1.7 m/s | megaloceros  run x7.31  3.0 m/s | tyrannosaurus  walk x0.88  1.8 m/s`
   `[canimlab] t=5.0 velociraptor  run x1.88  7.0 m/s | protoceratops  run x6.67  4.2 m/s | megaloceros  run x16.00  7.6 m/s | tyrannosaurus  walk x2.20  4.5 m/s`

All Godot runs went through scratchpad `gslot.sh` (silent audio driver).

## Screenshots inspected

- `scratchpad/w1/canim/lab_walk.png` (windowed, Forward+, 3 s): four species mid-stride in their lanes,
  heads leading, labels show gait and cadence.
- `scratchpad/w1/canim/lab_rex_sleep.png` and `lab_rex_sleep_crop.png` (11 s), re-read for review
  round 1: the T. rex lies on its back, belly toward the camera, both feet and both hands in the air,
  claws up. The first report called this "lying on its side"; that was wrong. It is a dead-bug pose,
  not sleep, and is now a REPLACE row. A still frame cannot show foot sliding; the stride numbers
  above are the evidence for that.

## Assumptions (`# ASSUMPTION:` in code)

- Species walk speed = 40 % of the listed speed (test and lab only; defs and the PRD give one speed).
- Gait switch at the geometric mean of the two natural speeds, with 10 % hysteresis.
- Cadence guard [0.1, 16] in `set_move_speed`.
- Bake: a gait whose planted feet differ by more than 1.6x gets no speed and a `<gait>_replace` note.
- "No bone channel static for more than 25 % of the loop" is measured as the longest span in which
  no bone channel moves more than 1e-4 per step (whole pose frozen). That metric reproduces the
  audit's 51 % on the untrimmed walks. Individual channels (planted-foot rotation) still hold still
  through a stance phase, which is correct motion.

## Integrator hooks

None needed in core files. For W2-CVIEW (wiring is theirs per the spec):
- creature.gd:290-291: replace `anim.play_locomotion(frac)` with `anim.set_move_speed(speed)`.
- Brains: hold sleep with `anim.play_clip(&"sleep", true)` and wake with `anim.play_clip(&"idle")`
  (creature.gd:295 calls `play_idle()` every idle frame unless `_forced`). Same for `feed`. Species
  without the clip fall back to idle.
- creature.gd:541: the hit_react guard is `not str(anim.current_clip).begins_with("attack")`, so a hit
  would interrupt `tail_swipe` once a brain uses it. Use
  `not (anim.current_clip in CreatureAnim.ATTACKS)`.
- creature.gd:393-394 (the limp, dino-art-10): delete `if statuses.has(&"fracture"): ap.speed_scale = 0.65`
  and put `anim.set_time_scale(0.65 if statuses.has(&"fracture") else 1.0, &"fracture")` in `_status_fx()`
  unconditionally, so it resets when fracture is removed. Hit-stop or slows use their own factor key
  (for example `&"hitstop"`), never `&"fracture"`; `&"base"` (the default) belongs to whoever owns
  global slow-motion. The tree plays at the product of all factors.
- Do not wire `set_move_speed` for megaloceros, protoceratops, zebraceratops or the T. rex until the
  W2-RERIG clips land: with the donor clips they play the run at walking speed (velociraptor too at
  the 40 % walk assumption), megaloceros hits the 16x cadence cap and reads as standing still, and the
  T. rex plays its walk at 2.2x. If they must be wired sooner, cap cadence near 3x and accept sliding.
- Read `anim.current_state()` / `anim.cadence(state)` / `anim.has_state(clip)` / `anim.is_busy()` instead of private fields.

## Labs to register

- `creature_anim_lab`: `Godot --path game -- --lab=creature_anim_lab [--shot=... --shot-delay=3]`.
  Walk phase 0-5 s, run phase 5-10 s, T. rex sleep/feed/tail_swipe 10-15 s, repeating. It prints
  one `[canimlab]` line per phase and has no PASS gate; the test is the gate.

## Assets to mark for replacement (rows for `docs/orchestration/mmo/asset-replacement.md`)

Owner rule 2026-10-19. This package does not own the register; the integrator should add or extend
these rows. Evidence is the baked `natural_speeds` in `anim_events.json` (planted-foot m/s at x1).

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| tyrannosaurus sleep clip | Lies on its back with legs and arms in the air (dead-bug pose), belly to camera (`lab_rex_sleep_crop.png`), and the whole body floats about 1 m above the ground with a clear gap to its shadow (reviewer's `rex_sleep_after.png`, `rex_sleep_after_gl.png`): fix the root height as well as the pose | dsc re-animation | W2-RERIG | REPLACE |
| coelophysis walk + run clips | Feet disagree (walk L 0.436 R 0.216 m/s, run L 0.406 R 1.111), and the run strides slower than the walk on the left foot; with the old bake it played the walk at x16 at top speed and x6.6 at 2.9 m/s. Now unbaked: legacy cadence | dsc re-animation | W2-RERIG | REPLACE |
| gallimimus run, compsognathus run clips | Feet disagree 4.8x (L 2.789 R 13.45) and 1.95x (L 2.193 R 4.267); unbaked, so these species use their walk at every speed | dsc re-animation | W2-RERIG | REPLACE |
| velociraptor, utahraptor, deinonychus, gallimimus walk; velociraptor, utahraptor, deinonychus run | Asymmetric donor stance, 1.2-1.5x between feet; baked from the mean so each foot slides up to ~20 %. Run naturals per metre of height also disagree across the same donor clip (deinonychus 13.9 m/s at 3.6 m vs velociraptor 3.7 at 2.4 m) | dsc re-animation with the bespoke rigs | W2-RERIG | REPLACE |
| megaloceros, protoceratops, zebraceratops walk clips | Natural walk 0.11-0.17 m/s: at walking speed the run clip wins the gait pick, so these walks are never seen, and the run plays at x2.7-x7.3 | dsc re-animation | W2-RERIG (zebraceratops: W2-ARTC) | REPLACE |
| megaloceros, protoceratops, zebraceratops run clips | Barely stride (natural run 0.42, 0.63, 0.39 m/s): listed speeds need 7-18x cadence; megaloceros hits the 16x cap; legs read as vibration | dsc re-animation (extends the existing W2-RERIG row) | W2-RERIG (zebraceratops: W2-ARTC) | REPLACE |
| tyrannosaurus run clip | Strides slower than its own walk (0.42 vs 2.05 m/s), so `set_move_speed` never selects it | dsc re-animation, re-check with the stride method | W2-RERIG | REPLACE |
| Donor biped walks (velociraptor, gallimimus, utahraptor, compsognathus, deinonychus, coelophysis) | Second half of each loop was frozen (51 %); trimmed at load as a stopgap, the GLBs still carry it | Re-export trimmed clips with the bespoke rigs | W2-RERIG | REPLACE |

After any replacement walk/run GLB lands, rerun `tools/bake_clip_speeds.py`.

## What failed or is left, and risks for other packages

- Donor quadruped clips barely stride (natural run: megaloceros 0.42, zebraceratops 0.40,
  protoceratops 0.63 m/s). Matching their listed speeds needs 7-18x cadence; megaloceros at 7.6 m/s
  hits the 16x guard (ratio 0.88). The ratio passes, but legs that fast will read as vibration once
  W2-CVIEW wires `set_move_speed`. The fix is new clips (W2-RERIG), not runtime.
- By the stride method the T. rex run (0.44 m/s) and coelophysis run (0.41) stride slower than their
  walks (2.05, 0.44), so `set_move_speed` never picks those run clips. That is either the clip or the
  method's planted-foot pick on a gait with a flight phase; W2-RERIG should check.
- W1-AI: if the 10 Hz staggered think also ticks TyrantBrain's `phase_left`, the impact can land up
  to 0.1 s after the animation hit frame, more than this package's 0.05 s.
- W1-QA: Godot exits 0 when a `--script` test fails to parse (seen here on a type-inference error:
  exit 0, no PASS line). The t_*.gd runner must require the PASS line, not only exit 0.
- perf-anim-load-01 is unchanged: on web the DirAccess scan misses the T. rex `sleep`/`tail_swipe`
  GLBs, so on web they fall back to idle (no error).
- In game today (before W2-CVIEW), visible changes are: run plays at 1.6x, walk/run no longer
  blend 87/13 but crossfade, biped walks loop the real stride, and the T. rex windup is retimed.
- `end_timed_attack` still cuts the boss clip at the hit frame and crossfades to idle (unchanged).
- Merge: stegosaurus walk/run GLBs landed on mmo-overhaul after this branch point and dsc
  re-animations of raptors and quadrupeds are in progress. Rerun `tools/bake_clip_speeds.py` after the
  merge; until then a changed clip's length mismatch makes the runtime ignore its stale bake and
  print `[creature] <species>/<gait> natural speed baked on ...` once.
- One-shot end/hit events now depend on the AnimationTree updating. A creature whose tree is
  inactive or paused stays busy until it resumes (the old wall-clock timers would have released it
  while the clip stood still). Nothing in this branch deactivates creature trees. Probe:
  `set_time_scale(0)` leaves a creature busy after 3 s and it recovers when the scale is restored.
- W1-SRVDOM: creature hit timing (`attack_hit` -> creature.gd `_on_hit`) is driven by the
  AnimationTree. A headless authoritative server must keep creature trees active and advancing, or
  replace this with a tree-time model that does not need the mixer.
- The idle-mode one-shot path (mixer_applied in a live tree) is exercised by run_all and the lab,
  but only the manual-advance path has a timing assert.
