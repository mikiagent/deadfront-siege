# Task: UNCLAIM — release claimed land (owner)
Owner, verbatim: "Also need a way to unclaim land too".
Read: the domain/claim code (game/scripts/world/island_claims.gd, claim_panel.gd, domain_screen.gd, build grid claim checks),
docs/design/durango-prompts/29_domain_land_claiming_and_territories.md (any rule on releasing, refunds, cooldowns), and
docs/current/ domain text.
Do:
1. A "Release plot" action on a claimed cell (from the Domain screen plot grid and from the claim panel when standing on
   your land), with a confirm step stating the consequence (the plot stops being yours; what happens to buildings on it).
2. Rules per spec 29 if given; otherwise (ASSUMPTION): you can't release your last/home cell; releasing a cell that would
   split your domain into disconnected parts is refused with the reason; buildings on the released cell become unowned
   (they stay but you lose management) — or are refused until removed, whichever is simpler and safer (prefer: refuse while
   a building stands on it, with a clear message); no T-stone refund unless spec 29 says so.
3. Released cells can be claimed again later; props do not respawn instantly (CLAIMPROPS cleaned them; the island rebuild
   rules decide).
4. Saves: the claim list just loses the cell; no format change.
Milestones:
M1 game/tests/t_unclaim.gd: release a free edge cell works and persists through save/load; the last cell is refused; a
split is refused; a cell with a building is refused with the reason; the confirm step is required (no release without
confirm); re-claim works. Stage 1.
M2 implementation + UI buttons (≥ 64 px, SheetChrome/claim panel style). Stage 1.
M3 report + full verify; update docs/current pages.


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/unclaim_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=snap_build_lab --shot-dir=/tmp/unclaim_shots > /tmp/unclaim_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/unclaim_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/unclaim, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh unclaim [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_unclaim.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[unclaim] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-unclaim.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
