# Task: EYETRAILS — motion trails behind the glowing eyes

Owner (verbatim, 2026-10-28): "Also add trails to the glowing eyes". Glowing eyes (eyeshine at night) live in
game/scripts/creatures/creature_eyes.gd, with per-species eye points in game/data/creatures/<id>.json "eyes" (do NOT
change those points — the art thread owns them). Read creature_eyes.gd and t_eyeglow.gd first.

Do: a short fading ribbon / afterimage behind each eye point, in that eye's colour, that shows when the head moves
fast (lunge, quick turn, run) and is barely visible at idle; it fades out over ~0.15-0.3 s (`# ASSUMPTION`); only
while the eyes glow (same visibility rule as the eyeshine itself). Cheap on the web Compatibility renderer: no
particles-per-frame explosion — a small ring buffer of past eye positions drawn as one ImmediateMesh/ribbon per eye
(or a GPU trail if Compatibility supports it), capped (e.g. <= 12 samples per eye), additive/unshaded, no shadows,
and disabled beyond a camera distance. Data knobs (length, fade, min speed, max samples) in a small JSON (e.g. extend
the existing eyeglow data file or add game/data/creatures/eyeglow.json).
Milestones: M1 game/tests/t_eyetrails.gd ("[t_eyetrails] PASS"): trail sample count stays <= the cap; trail
length/alpha is ~0 when the head is still and grows when the head moves fast; trail hidden when eyes do not glow;
per-creature cost bounded (count draw calls/meshes for 20 creatures). Stage 1. M2 implementation. M3 docs/current
note + report docs/orchestration/reports/dsc-eyetrails.md + full verify. Headless only.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/eyetrails_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/eyetrails_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
  `--check-only` ALWAYS prints "Identifier not found: Data / World / Game / TouchControls" (autoloads do not exist in that
  mode): ignore those lines; only `Parse Error` lines are real. Real tests run with `--script res://tests/<t>.gd`, where the
  autoloads DO exist once the first frame runs: the test must load() every game script on its first frame instead of
  naming classes at compile time (copy game/tests/t_domain.gd's structure exactly).
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/eyetrails, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh eyetrails [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_eyetrails.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[eyetrails] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-eyetrails.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
