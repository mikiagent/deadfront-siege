# W1-CANIM: creature animation runtime that obeys time scale and speed

Branch `claude/mmo-w1-canim` (from `claude/mmo-overhaul` at ea2d167). Commits: `baf01f5` runtime, bake
tool, data, test; `3a33685` lab and assumption markers; this report. Closes dino-art-05, dino-art-10
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
  - `set_time_scale(x)`: global multiplier over every state's cadence.
  - Walk and run are separate states with a 0.2 s crossfade (was a linear BlendSpace1D of two
    unsynced gaits). Legacy `play_locomotion(frac)` keeps its call shape: run above 0.55, run at the
    anim_events cadence (1.6, which now actually applies).
  - `sleep` and `tail_swipe` nodes are built when the species has the clip (T. rex); `play_clip` on a
    missing clip goes to idle with no travel to a missing node. `feed` keeps its node (idle copy where
    not authored, as before). `tail_swipe` is a one-shot attack (busy, `attack_hit`, `attack_done`).
  - One-shot timers divide by the cadence the clip plays at. `player.play()` is no longer called next
    to the tree (it double-drove the skeleton; the tree won every frame).
- `game/scripts/creatures/creature_clips.gd`: `trim_frozen_tail()` cuts a looping clip where a static
  tail of 25 % or more begins (tolerance 5 % of each bone channel's own swing; cached per
  species/clip). The six donor biped walks go 2.458 s -> 1.209 s (coelophysis 1.229 s); the cut pose
  matches frame 0, so the loop is seamless. Applied to walk and run at `CreatureAnim.setup`.
  `natural_speed(def, clip)` reads the baked speed and scales it with `height_meters`.
- `tools/bake_clip_speeds.py`: runs headless Godot with the game's own clip loader, trims, measures
  each species' walk/run planted-foot speed (stride method of the dino-art audit, 240 samples) and
  writes `anim_events.json` `natural_speeds`. Rebake after changing any walk/run GLB.
- `game/data/creatures/anim_events.json`: `natural_speeds` for the 10 GLB species (reformatted to
  2-space JSON by the bake; the existing keys are unchanged).
- `game/tests/t_canim.gd`, `game/scripts/dev/creature_anim_lab.gd` + `game/scenes/dev/creature_anim_lab.tscn`.

Deviations from the spec's file list:
- No `clip_speeds.json`: `Data._load_creatures` (data.gd:112) parses every other `*.json` in
  `data/creatures` as a species and fails without `species`. The speeds live in `anim_events.json`
  (owned), which Data already loads. No data.gd change needed.
- Test file is `game/tests/t_canim.gd` (wave-1 convention), not `t_creature_anim.gd`.

## Acceptance checklist (exact output lines, run on HEAD 3a33685)

Command: `Godot --headless --path game --script res://tests/t_canim.gd` (exit 0).

1. Time scale (was 1.000):
   `[t_canim] ok   velociraptor attack_primary timed to 2.0 s: time scale 0.184, tree advance / wall = 0.184 (want 0.16-0.21, was 1.000)`
   `[t_canim] ok   velociraptor run at anim_events speed 1.6: tree advance / wall = 1.600 (want 1.5-1.7)`
   `[t_canim] ok   set_time_scale(0.5) on idle: tree advance / wall = 0.500`
2. T. rex heavy sync (was 0.65 s late):
   `[t_canim] ok   tyrannosaurus attack_heavy (len 2.567 s, hit_frac pos 1.848 s): animation hit at 1.208 s, brain damage at 1.200 s, gap 0.008 s (want <= 0.05, was 0.65)`
3. Stride match at walk and run speed:
   `[t_canim] ok   velociraptor set_move_speed(2.80) -> run x0.89: planted foot 2.80 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   velociraptor set_move_speed(7.00) -> run x2.23: planted foot 7.00 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   megaloceros set_move_speed(3.04) -> run x7.31: planted foot 3.04 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   megaloceros set_move_speed(7.60) -> run x16.00: planted foot 6.66 m/s, ratio 0.88 (want 0.75-1.30)`
   `[t_canim] ok   protoceratops set_move_speed(1.68) -> run x2.67: planted foot 1.68 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   protoceratops set_move_speed(4.20) -> run x6.67: planted foot 4.20 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   tyrannosaurus set_move_speed(1.80) -> walk x0.88: planted foot 1.80 m/s, ratio 1.00 (want 0.75-1.30)`
   `[t_canim] ok   tyrannosaurus set_move_speed(4.50) -> walk x2.20: planted foot 4.50 m/s, ratio 1.00 (want 0.75-1.30)`
4. Biped walk loops (was 51 %):
   `[t_canim] ok   7 biped walk loops: longest frozen span 0 % (want <= 25 %, was 51 %)`
5. Optional clips:
   `[t_canim] ok   tyrannosaurus play_clip(sleep): state machine on sleep`
   `[t_canim] ok   tyrannosaurus play_clip(feed): state machine on feed`
   `[t_canim] ok   tyrannosaurus play_clip(tail_swipe): state machine on tail_swipe`
   `[t_canim] ok   velociraptor play_clip(sleep) has no sleep node and stays on idle`
   `[t_canim] PASS`
6. Rig imports (`--script ../tools/verify_rig_imports.gd`, exit 0; run after the runtime commit, the
   loader it exercises is untouched): `RIG IMPORT PASS: 99 clips through production loader`
7. Regression: `tools/smoke.sh --no-import` -> `SMOKE PASS`; `--script res://tests/run_all.gd` -> `[tests] PASS`.

All Godot runs went through scratchpad `gslot.sh` (silent audio driver).

## Screenshots inspected

- `scratchpad/w1/canim/lab_walk.png` (windowed, Forward+, 3 s): four species mid-stride in their lanes,
  heads leading, labels show gait and cadence.
- `scratchpad/w1/canim/lab_rex_sleep.png` and `lab_rex_sleep_crop.png` (11 s): the T. rex plays its
  authored sleep, lying on its side with belly and soles toward the camera, on the ground (shadow
  beneath). That is the DeepSeek-authored clip as shipped; it had never been played in game. Judge its
  look in W2-RERIG/W2-ARTC. A still frame cannot show foot sliding; the stride numbers above are the
  evidence for that.

## Assumptions (`# ASSUMPTION:` in code)

- Species walk speed = 40 % of the listed speed (test and lab only; defs and the PRD give one speed).
- Gait switch at the geometric mean of the two natural speeds, with 10 % hysteresis.
- Cadence guard [0.1, 16] in `set_move_speed`.
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

## Labs to register

- `creature_anim_lab`: `Godot --path game -- --lab=creature_anim_lab [--shot=... --shot-delay=3]`.
  Walk phase 0-5 s, run phase 5-10 s, T. rex sleep/feed/tail_swipe 10-15 s, repeating. It prints
  one `[canimlab]` line per phase and has no PASS gate; the test is the gate.

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
