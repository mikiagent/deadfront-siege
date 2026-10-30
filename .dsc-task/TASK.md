# Task: FOODFX: eating and drinking have effects beyond a flat Energy number
Owner: "add this to the docs and plan" (spec docs/design/durango-prompts/32_food_drink_consumption_effects.md).
Research: docs/reference/durango0-wiki/06_FOOD_DRINK_TASTE_AND_BUFF_FORMULAS.md (digestion, taste grades,
the buff keys) - reconstruction values stay tagged, never presented as original constants.
Extend the systems that exist; do not build a second food, inventory or status architecture.
Today: game/scripts/items/food.gd (Energy only: base x (1 + 0.35 x process_count) x level), eat_session.gd
(3 s eat, move cancels the remaining restore, raw-food risk past half), a flat BUFFS table in
game/data/food_buffs.json, and game/scripts/status/status_def.gd + combat/status_effects.gd for timed
statuses. BAGS and CRAFTFEEL change the item/craft path - read them first and reuse their preview functions.
Do not tune balance numbers; every value spec 32 does not give is `# ASSUMPTION` and configurable, and every
example from the reconstruction keeps its provenance tag (spec 32 s15 and s13).
Milestones:
M1 game/tests/t_foodfx.gd: instant + digested Energy split at release ratio 0/0.4/1; the delayed share is never
paid twice across a save/load or a second eat intent; an interrupted eat consumes nothing and grants nothing;
eating twice quickly cannot consume one instance twice; a Maximum Fatigue buff expiring clamps current fatigue
and never touches base stat values; a drink that lowers current fatigue and a drink that raises the maximum are
different effects; same-container foods replace each other while Enhanced Ability and Enhanced Survival coexist;
a plain Energy food leaves an unrelated buff alive; a profession ability buff changes a real ability check
without granting category levels; raw bad food can apply Stomach Pain. Stage 1.
M2 the effect bundle + evaluator in data-driven code (consumption channels, per-field transforms, caps and
conflict validation as in spec 32 s8), delayed-digestion persistence, buff slots. Stage 1.
M3 consumption transaction: validate -> timed action with interrupt -> atomic consume of the exact instance ->
immediate effects -> schedule digestion -> buff slot replacement -> taste/temperature -> persist. Stage 2.
M4 game/scripts/dev/foodfx_lab.gd + scene printing `[foodfx] RESULT instant_split_ok= digest_once_ok=
interrupt_refunds= double_eat_blocked= buff_slots_ok= maxfatigue_expiry_ok= fatigue_vs_maxfatigue_ok=
buff_coexist_ok= plain_food_keeps_buff= ability_check_moves= bad_food_status= taste_grade_ok=
save_roundtrip= ui_min_px=` with shots of the food inspect panel and the two drinks. Stage 2.
M5 report (before/after, the shots, every assumption and provenance) and the full verify.
Data slice, not dozens of foods: water, tea, coffee, a raw berry, cooked meat, one profession-buff meal, one
fatigue restorative. The UI is spec 32 s12: item level, exact traits, Energy immediate/over time, fullness,
thirst, health, fatigue, max-stat effects, ability bonuses, negative effects, buff group, duration and
consumption time, plus a line saying when this food would replace an active buff.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/foodfx_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=foodfx_lab --shot-dir=/tmp/foodfx_shots > /tmp/foodfx_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/foodfx_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/foodfx, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh foodfx [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_foodfx.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[foodfx] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-foodfx.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
