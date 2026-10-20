# TASK: t_canim check that a hit animal can still fight back (hit_react free window)

## Why

An independent review of DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) found a stunlock:

- When a creature takes damage, `Creature._on_damaged` (`game/scripts/creatures/creature.gd`, around line 565-600)
  staggers it (`stagger_left = 0.3`, or 0.45 on a crit) at most once per wall-clock second
  (`_stagger_immune_until = _now_s() + 1.0`) and, when that stagger fired and the species has an authored
  `hit_react` clip (`def.pipeline.authored_clips` has `"hit_react"`) and `view.using_glb`, plays
  `anim.play_clip(&"hit_react")`.
- `hit_react` is a one-shot, so `creature.anim.is_busy()` stays true until the clip ends.
- The brain only starts an attack when `not creature.anim._busy and creature.stagger_left <= 0.0`
  (`game/scripts/creatures/brains/creature_brain.gd`, around line 459).
- Several authored `hit_react` clips are 1.125-1.25 s long. A player hitting once per second (a punch, a rate-1.0
  weapon) kept the animal busy 100 % of the time: it could never attack back.

The fix is already on this branch: `game/data/creatures/anim_events.json` has `"hit_react": { "speed": 2.0 }` under
`"clips"`, so `CreatureClips.clip_speed(&"hit_react")` returns 2.0 and the clip plays twice as fast. Your job is
the test that would have caught the bug and that fails again if anyone removes or lowers that speed.

## What to write

Only one file changes: `game/tests/t_canim.gd`. Add a function `_test_hit_react_window()` and call it from
`_process` next to the other `_test_*` calls (before `_test_optional_clips()` is fine). Follow the file's
style: typed GDScript, tabs, short `##` why-comment above the function, use the existing helpers
`_spawn(id)`, `_expect(ok, what)` and the `DT` constant. Load nothing by class_name at parse time.

For every creature id in `data.creatures.keys()` whose def has `def.pipeline.get("authored_clips", {})`
containing `"hit_react"`:

1. `var c = _spawn(id)` (it disables the brain and physics and puts the AnimationTree on manual advance).
   If `c.brain is TyrantBrain`-like (compare by script: `c.brain.get_script() == load("res://scripts/creatures/brains/tyrant_brain.gd")`)
   or `not c.view.using_glb`, print a `[t_canim] note:` line, free it and skip.
2. Simulate 6 hits, one per second of tree time. For each hit:
   - set `c._stagger_immune_until = -1.0` (one wall-clock second has passed; the real code reads the wall clock,
     which a manual-advance test cannot move);
   - call the REAL damage path: `c._on_damaged(1.0, null)`. Do not call `play_clip` yourself.
   - after the first hit, `_expect` that `c.anim.current_clip == &"hit_react"` (proves the real gate played it).
   - then step 60 frames: each frame `c.anim.tree.advance(DT)` and
     `c.stagger_left = maxf(0.0, c.stagger_left - DT)` (this mirrors `creature.gd` `_physics_process`, which the
     test disabled). Count the frame as free when `not c.anim.is_busy() and c.stagger_left <= 0.0`.
   - the free time of that second is `free_frames * DT`.
3. Take the smallest free time over seconds 2..6 (skip the first second, it starts from idle).
4. `_expect(worst_free >= 0.3, ...)` with exactly this message shape (the verify script greps it):
   `"%s hit_react %.3f s at x%.2f under a 1.0 s hit cadence: free to attack %.2f s of each second (want >= 0.30, was 0.00)" % [id, length, speed, worst_free]`
   where `length` is `c.anim.player.get_animation(&"hit_react").length` and `speed` is
   `clips.clip_speed(&"hit_react", c.def)` (`clips` is the already-loaded `creature_clips.gd` script in the test).
5. `c.free()`.

Make sure `_on_damaged` with `source = null` does not crash or aggro; if some call in it needs a node in the
tree, `_spawn` already adds the creature under `root`.

## Rules (binding)

- Run Godot ONLY via `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`
  with a perl alarm, from this work tree, never with `--editor`:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_canim.gd`
  The test makes no sound; never play audio by other means.
- Change only `game/tests/t_canim.gd`. Do not touch `game/scripts/`, `game/data/`, `game/assets/`, `game/override.cfg`,
  `game/.godot/`, `TASK.md` or `verify_hitwin.sh`. Do not add `class_name` files. Do not run `--import`.
- Do not change or weaken any existing check in t_canim.gd.
- Commit your change with a clear message ending with the line
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. `git add game/tests/t_canim.gd` only; never `git add -A`.
  Never push.

## Milestones

1. The function exists, is called from `_process`, and t_canim prints `[t_canim] PASS` with one
   `ok   <id> hit_react ... free to attack` line per species with an authored hit_react (9 today:
   coelophysis, compsognathus, deinonychus, gallimimus, megaloceros, protoceratops, utahraptor, velociraptor,
   zebraceratops).
2. `./verify_hitwin.sh` exits 0. It also removes the `hit_react` speed from a temporary copy of the data,
   runs t_canim and requires your check to FAIL for zebraceratops and velociraptor, then restores the file.
