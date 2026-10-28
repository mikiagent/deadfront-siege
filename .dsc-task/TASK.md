# Task: BUILDSPEED — bring island build time back under the §1.7 budget
t_perfgates (just merged) measured native island build at home 4.3-4.5 s and unstable 2.7-5.4 s against budgets of
2.5 s home and 3.0 s unstable (docs/design/islands-and-loop-plan.md §1.7; budget in game/data/perf_budget.json). The plan
names the work: per-vertex slope and typed packed arrays in `_build_tile_types` (about 5 `surface_y` calls per tile
today) and `TilePath._rebuild` (about 6); skip tiles outside the dry box; build the tile image from a byte array.
First PROFILE: add timing around each build phase (print a phase table from t_perfgates or a small probe) and find where
the 4.3 s goes; tonight's packages added content (more harvest nodes up to the band top, ground cover 78k instances,
UI) so the cost may not be where the plan says. Then fix the top phases.
Rules: identical output. The built island must be the same as before for the same seed (tile types, paths, node
positions, scatter): add a test that hashes the built tile types + harvest node positions + scatter transforms for home
and two unstable seeds and compares against hashes recorded BEFORE your change (record them in M1). No visual changes,
no lower content counts, no balance changes.
Milestones:
M1 profile table + game/tests/t_buildspeed.gd with the before-hashes recorded and an assert that build time is under the
budget (failing at first is expected; commit it with the hashes). Stage 1 (the time assert may be marked expected-fail
until M3; the hash asserts must pass).
M2 optimisations, phase by phase, hashes unchanged after each (commit per phase).
M3 build time under budget for home and both unstable islands on this machine, 3 runs; t_perfgates still passes; set
"enforce": true for the build-time measure only if all three islands pass; report with before/after per phase; full
verify.


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/buildspeed_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=perf_lab --shot-dir=/tmp/buildspeed_shots > /tmp/buildspeed_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/buildspeed_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/buildspeed, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh buildspeed [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_buildspeed.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[buildspeed] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-buildspeed.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
