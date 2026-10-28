# Task: XPECON — XP economy from the islands-and-loop plan

Source (owner-approved plan, read it): docs/design/islands-and-loop-plan.md, "XP economy (spec 03: scale against
difficulty, no repeat exploits)" and the 3.4 knobs table:
- Gather XP = 1 + round(pass seconds) per pass (stone 4, log 4, berries 2), not a flat 2. W2-GATHER now computes pass
  time (GatherService.unit_seconds / unit_seconds_for) — use the ACTUAL pass seconds of that pass, so tools and skill
  that speed gathering also change XP per pass the way the plan intends (say what you chose in the report).
- Build XP: first placement of each kit type +30, repeats +8, and the same kit within 10 m of another of its kind
  within 60 s pays 0 (`# ASSUMPTION` in the plan).
- Keep the level curve (World.xp_for_level) unchanged.
Today: player_actions.gd:~168 pays gathering skill 2 + World.add_xp(2); build_placer.gd / world.gd pay 38 per build
(read both; docs/current/ pages describe them). Both the character XP (World.add_xp) and the skill XP must follow.
Data-driven: the numbers go in rules.json (`xp` block), not code.
Milestones: M1 game/tests/t_xpecon.gd ("[t_xpecon] PASS"): XP for a stone/log/berry pass equals 1+round(seconds) of
that pass; first kit +30, repeat +8, spam (same kit within 10 m inside 60 s) 0, a different kit is first-of-kind again,
save/load keeps the first-of-kind memory. Fails on base. Stage 1.
M2 implementation. M3 docs/current update + report docs/orchestration/reports/dsc-xpecon.md + full verify.
Headless only. Do not change any other number.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/xpecon_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/xpecon_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/xpecon, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh xpecon [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_xpecon.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[xpecon] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-xpecon.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
