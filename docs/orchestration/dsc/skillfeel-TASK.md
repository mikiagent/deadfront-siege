# Task: SKILLFEEL: skills give clear feedback (XP toasts, FULL at the cap, a pulsing Skills button, a useful first hour)

Owner: the build/craft/skill systems must be "done and tuned" before balance, with "a clear gameplay loop that is fun".
Design truth: docs/design/durango-prompts/03_leveling_progression_skill_trees.md, 12_remaining_skill_trees.md, 25 (section 7:
"skill bar FULL at the character level cap with XP shown") and docs/design/islands-and-loop-plan.md section 3.3 "Skills":
"skill XP toast, skill bar 'FULL' at the character-level cap, a pulse on the Skills hex when a node is affordable (nothing
listens to `skill_changed` today). First-hour node menu: at least 2 useful buys per tree the first hour touches (Gathering,
Butchering, Cooking, Weapon and Tool Crafting, Construction, Survival, Melee) at 1-5 SP each, each with a visible number on use."
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (844x390 landscape).
## Today
- game/scripts/skills/skill_state.gd: `signal skill_changed(tree, level)` (line 9); level_cap(tree) caps a tree at the
  character level and banks the XP (lines 85-108). Nothing listens to skill_changed.
- game/scripts/ui/hunt_hud.gd:228 `_skills_hex` (the SKILLS hex button) opens game/scripts/ui/skills_sheet.gd.
- game/scripts/ui/pickup_toast.gd is the existing toast; game/data/skills/trees.json holds the nodes (SKILLBUY made 103 of
  213 buyable via SkillRules.buyable in game/scripts/skills/skill_rules.gd).
## What to build (do not change XP amounts, costs or levels: balance comes later)
1. A small toast when a skill gains XP ("+4 Gathering XP"), merged when several arrive within a second; a bigger one on a
   tree level-up. Never covers the HUD blocks; readable at 844x390.
2. The skills sheet shows each tree's bar; at the character-level cap the bar reads "FULL" with the banked XP shown.
3. The SKILLS hex pulses (a soft glow, not a jump) whenever at least one buyable node is affordable with the SP held, and
   stops when none is.
4. Check the first hour: for each of the 7 trees above, list the nodes a new character can buy at 1-5 SP in its first
   hour (from trees.json + SkillRules.buyable), and their visible effect. If a tree has fewer than 2, write that in the
   report as a gap (do not invent nodes or effects; the owner decides).
## Milestones
- M1 game/tests/t_skillfeel.gd (copy t_domain.gd's pattern): XP gain emits a toast request with the right text; toasts merge
  within 1 s; FULL shows exactly at the cap; the pulse state follows affordability; the first-hour count per tree. Stage 1.
- M2 Toasts + FULL + pulse wired in. Stage 1.
- M3 game/scripts/dev/skillfeel_lab.gd + scene: grant XP, reach a cap, get SP; print `[skillfeel] RESULT toast_shown=
  full_shown= pulse_when_affordable= no_pulse_when_not= first_hour_trees= first_hour_trees_ok= ui_min_px=` (first_hour_trees_ok
  = trees with >= 2 buys at 1-5 SP in the first hour), shots: a toast, the sheet with FULL, the pulsing hex. Stage 2.
- M4 Look at every shot (path + verdict in NOTES.md); fix; report with the first-hour table. Full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/skillfeel_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=skillfeel_lab --shot-dir=/tmp/skillfeel_shots > /tmp/skillfeel_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/skillfeel_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/skillfeel, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh skillfeel [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_skillfeel.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[skillfeel] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-skillfeel.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
