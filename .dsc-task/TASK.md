# Task: ONEGATHER — one item per harvest; upgrades change speed and quality, not amount
Owner, verbatim: "it should be only gathering one at a time. it looks like you gather like 12 of them in one harvest. cap it
to 1 per harvest and upgrades can change the speed and quality of the materials you harvest, not the amount".
Read: game/scripts/gather/ (gather_service.gd, loot_roller.gd, loot_tables.gd, gather_feedback.gd), game/data/loot_tables.json,
game/data/rules.json gather section, tool tiers and gathering skill effects (skill nodes marked functional in trees.json that
touch yield), docs/current/ gathering text, and the top-middle feed (game/scripts/ui/top_feed.gd) which shows each gain.
Rules:
1. Every harvest action at a resource node yields exactly 1 item instance (no stacking; items never stack anyway). Remove
   every multiplier that raises the COUNT per action: tool tier yield multipliers, skill "+N% yield" nodes, rich/bonus
   rolls that add units, and so on.
2. Convert those multipliers into SPEED (shorter time per unit) or QUALITY (higher material level, better rare-trait chance,
   flawless chance), keeping the data in the same places so tuning is easy; every new number is `# ASSUMPTION` unless the
   docs give it. A node's total units (how many times it can be harvested before depleting) stay as today.
3. Skill nodes whose text says "+X% yield" get their effect reinterpreted as speed or quality (update their text in
   trees.json and their `impl` mark); list them in the report.
4. Carcass butchering is out of scope here (another agent owns the butcher UI right now).
5. The top-middle feed shows one item per gain (it already collapses repeats like "+1 Stone" ×2 into "+2"; keep that).
Milestones:
M1 game/tests/t_onegather.gd: every gatherable node yields exactly 1 per action at every tool tier and skill level; a
better tool is faster (time per unit) and/or yields higher material level/quality, never more units; total node units
unchanged; rare-trait rate per unit honoured; the feed shows +1 per action. Stage 1.
M2 implementation + data + skill text. Stage 1.
M3 report (before/after: units per action and seconds per unit per tool tier) + full verify; update docs/current pages.


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/onegather_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=gather_lab --shot-dir=/tmp/onegather_shots > /tmp/onegather_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/onegather_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/onegather, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh onegather [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_onegather.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[onegather] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-onegather.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
