# Task: SHAPEGATES — prove the island shape generator's consumer gates, fix what fails

The island shape generator landed (game/scripts/world/island_shape.gd, ISLANDGEN + ISLANDPICK). The roadmap item
"shape-consumers" stays open until its gates are measured. Source: docs/design/islands-and-loop-plan.md, the P3
ISLANDSHAPE package "Verify:" line (read §P3 in full). Measure these on EVERY island in the island data (home with each
of the five Tamed Island shapes, and every unstable/other island), built the way the game builds them (read
game/scripts/dev/islandgen_lab.gd and island_runtime.gd to see how; reuse their code paths, do not re-implement the
generator in the test):
- 0 dry (land) tiles outside the walkable TilePath grid.
- camp-to-dock distance <= 40 m on non-home islands, <= 70 m on the home island.
- the river, where an island has one, is connected hill-to-sea.
- land size within +-10 % of the island's target (IslandShape.target_long / target_short for its tier).
Do not test the art gates (heightmap variety, look); do not change the target numbers.

Milestones (.dsc/PLAN.md; milestone_done after each):
M1 game/tests/t_shapegates.gd (structure of game/tests/t_domain.gd: load() scripts on the first frame, 60-300 s watchdog,
   one line per island "[t_shapegates] <island> dry_outside=N camp_dock_m=X river_ok=B size_err=P", then
   "[t_shapegates] PASS" or FAIL lines). Record in .dsc/NOTES.md which islands fail which gate on the base. Stage 1 runs it.
M2 if any gate fails: fix the root cause in the world scripts within scope (e.g. TilePath bounds from the dry bbox,
   camp/dock placement clamp), smallest change, keep every existing assert. If nothing fails, say so and skip to M3.
M3 report docs/orchestration/reports/dsc-shapegates.md (per-island table before/after, what changed, assumptions) and
   the full verify.
Headless only: the owner has reserved the machine. Do not run windowed labs or take screenshots.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/shapegates_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/shapegates_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/shapegates, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh shapegates [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_shapegates.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[shapegates] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-shapegates.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
