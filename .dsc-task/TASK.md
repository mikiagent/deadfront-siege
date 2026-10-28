# Task: PERFGATES — measure the plan §1.7 performance budget and gate every package on it
Source: docs/design/islands-and-loop-plan.md §1.7 (the budget table with a "Today" column). Roadmap `perf-gates`:
"web p95 and heap-per-island unmeasured — every package must fit." Tonight many UI and gameplay packages landed; nobody
re-measured.
Build ONE headless test `game/tests/t_perfgates.gd` that builds the home island and two unstable islands (use the
existing island build entry points; read game/scripts/core/world.gd, island_runtime.gd and the existing bot/soak tools in
tools/web_soak and tools/production_soak.mjs) and measures, per island: build time (native), HarvestNode count, scene
node count after build, ground-cover instance count, creature count, and static memory delta after build. It asserts
each against the §1.7 budget (budget numbers live in a new data file game/data/perf_budget.json so they're editable),
and prints one table line per island. A measure that can't be taken headless (visible primitives, draw calls, web p95)
is printed as "not measured headless" — don't fake it.
Then a second, windowed measurement script `game/scripts/dev/perf_lab.gd` (+ scene) that, at 1600x900 with
--rendering-method gl_compatibility, stands at the home camp for 20 s and prints `[perfgates] RESULT draws= prims=
shadow_prims= frame_p95_ms= frame_mean_ms=` from RenderingServer/Performance monitors. (The verify runs it only when
the owner allows windowed runs; write it anyway and say so in the report.)
Do NOT optimise anything in this task; if a measure is over budget, report it with the numbers.
Milestones:
M1 game/data/perf_budget.json + t_perfgates.gd measuring home + 2 unstable islands, asserting the headless measures. Stage 1.
M2 perf_lab.gd + scene. Stage 1.
M3 report docs/orchestration/reports/dsc-perfgates.md with a table: measure, budget, plan's "Today", measured now; update
the "Today" column in the plan §1.7 table with the new numbers (that one table only); full verify.


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/perfgates_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=perf_lab --shot-dir=/tmp/perfgates_shots > /tmp/perfgates_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/perfgates_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/perfgates, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh perfgates [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_perfgates.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[perfgates] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-perfgates.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
