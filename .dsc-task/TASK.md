# Task: CRAFTFEEL: crafting has stakes (success rate, failure, flawless, rare traits, skewer slots)
Design truth: docs/design/islands-and-loop-plan.md section 3.3 "Crafting" and package P7; specs 04 (success =
clamp(1 - (shortfall/100)^2, 0, 1) where shortfall is how far the crafting ability falls short of the recipe),
08 (skewer: Food slot meat + Tool slot Long Stick/Stick/Short Stick or a leg bone; the result shows inherited
traits) and 25 section 8 ("if crafting fails, materials disappear"). Flawless 5 % with a stat bump and rare
attribute chance 5 % at gather (rules rare_attribute_chance) are the plan's values: keep them in data.
Read game/scripts/items/crafting.gd (the craft path, level/attribute inheritance; BUILDFLOW and BAGS changed it
- reuse their preview functions) and craft_ui.gd / craft_card.gd. Do not tune XP or other balance numbers.
Milestones: M1 game/tests/t_craftfeel.gd (the success curve at shortfall 0/50/100; a failed craft consumes the
picked instances exactly once and makes nothing; flawless and rare-trait rates within +-2 % over 2000 seeded
crafts; skewer slot rules; the preview equals the result; craft XP paid once). M2 the rules in crafting.gd. M3
the preview in the craft UI (chance, flawless chance, "materials are lost on failure"). M4
game/scripts/dev/craftfeel_lab.gd + scene printing `[craftfeel] RESULT success_curve_ok= fail_consumes=
flawless_rate= rare_trait_rate= skewer_slots_ok= preview_matches= xp_once= ui_min_px=` with shots of the
preview, a failure and a flawless result. M5 report and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/craftfeel_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=craftfeel_lab --shot-dir=/tmp/craftfeel_shots > /tmp/craftfeel_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/craftfeel_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/craftfeel, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh craftfeel [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_craftfeel.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[craftfeel] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-craftfeel.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
