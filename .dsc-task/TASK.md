# Task: NEEDS: a player can eat, drink, wash, sleep, dry off and feed pets, end to end, on desktop and phone

Owner, verbatim: "we need to be able to eat, sleep, clean, drink, etc" - before any balancing.
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`) modelled on Durango: Wild Lands, web build,
mobile-first (phone 844x390 landscape, tap targets >= 64 px).

## The design (from the PRD and specs; read the refs)
There are NO hunger, thirst, hygiene or body-temperature meters (cut: docs/prd/durango-wild-lands-systems-prd.md :72, :1030).
Needs are statuses that change fatigue, plus Energy and Health:
- Eat (spec 08; PRD :404, :594-605): eating food from the bag restores Energy (cooked better than raw) and gives Full; raw
  meat/fish can give stomachache; the bag item card must show raw/poison state.
- Drink (spec 17 water context actions; PRD :314, :416): a context hex at fresh water clears Thirsty and gives Quenched.
  Fill a water container at fresh water.
- Wash (PRD :314): a context hex at fresh water clears Dirty / Very dirty and gives Clean.
- Sleep and rest (spec 01; PRD :803, :931): sleeping (tent, bed, ground) lowers fatigue; sitting at a bonfire is a recovery
  source and clears Wet (PRD :285); camp gives Coziness.
- Feed pets (spec 02, 09): feed from the pet radial or pet card with food from the bag; an unfed pet cannot fight.
Already in code: statuses wet, full, stomachache, dirty, very_dirty, thirsty, quenched, clean (game/data/statuses.json);
game/scripts/player/water_access.gd has drink(), wash(), fill(); eating in game/scripts/items/eat_session.gd and food.gd;
sleep in the player and game/scripts/dev/sleep_lab.gd; water in game/scripts/dev/water_lab.gd; bonfire.gd; pets in
game/scripts/pets/ and the pet radial. Your job is to PROVE each action works for a player and fix what does not.
Do not add meters the docs cut, and do not change any rate or number (balance comes later).

## Milestones
- M1 game/tests/t_needs.gd: for each action call the SAME method the HUD/radial calls (find it), from a precondition (e.g.
  give Thirsty, stand at fresh water) and assert the effect: Energy up after eating and Full applied; Thirsty -> Quenched;
  Dirty -> Clean; container filled; fatigue down after sleeping; Wet cleared at a bonfire; pet hunger up after feeding; the
  statuses survive save and load. Stage 1.
- M2 Fix every failing action inside your scope (wrong method, effect not applied, missing save field). Stage 1.
- M3 game/scripts/dev/needs_lab.gd + game/scenes/dev/needs_lab.tscn: run each action the way a player does (open the context
  hex at water, the bag item menu, the tent/bed prompt, the bonfire, the pet radial), save one screenshot per action showing
  the control a player taps, and print `[needs] RESULT eat_ok= drink_ok= wash_ok= fill_ok= sleep_ok= fire_dry_ok=
  feed_pet_ok= persist_ok= unreachable= ui_min_px=` (ok = 1 or 0 measured from the effect; unreachable = actions with no HUD
  control; ui_min_px = the smallest tap target among those controls, in px). Stage 2.
- M4 Make every action reachable and >= 64 px at 844x390. Stage 2.
- M5 Report (a table: action, how a player starts it on desktop and phone, effect, before/after) and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/needs_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless):
  `... perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=needs_lab --shot-dir=/tmp/needs_shots > /tmp/needs_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/needs_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh needs [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_needs.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[needs] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-needs.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
