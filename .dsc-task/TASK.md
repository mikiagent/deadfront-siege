# Task: FIREPITS — permanent firepit vs temporary bonfire (owner rules)
Owner, verbatim: "for the permanent "firepit" (bonfire with rocks in a circle) don't show wood unless wood is loaded into
the bonfire. For temporary fire "bonfire" show fire and wood and it burns out eventually, and loses durability over time
(especially if it's outside of a domain)".
Today: game/data/items.json has campfire_kit, bonfire_kit and stone_fire_pit_kit (place_as campfire / bonfire /
stone_fire_pit); game/data/structures.json has the three structures (around line 2155); game/scripts/world/bonfire.gd
runs fires; fuel/cooking flows go through station_menu.gd and the bonfire. Read docs/design/durango-prompts/30 and 10 for
any fire, fuel, burn or durability rules; use their numbers where given, else `# ASSUMPTION` in data.
Rules to implement:
1. stone_fire_pit (the permanent "firepit"): permanent (no decay). Its wood model/mesh is hidden while it holds no fuel;
   loading wood shows the wood and it burns while fuel lasts; when fuel runs out the wood disappears again and the fire goes
   out (the rocks stay).
2. bonfire and campfire (temporary): always show wood and fire from placement; burn out after a fuel time (ASSUMPTION data
   value); lose durability over time, decaying faster outside a Domain (ASSUMPTION ~2x; use the existing domain/claim
   check the build grid uses for "outside the Domain"); when burnt out or at 0 durability they are removed (or left as
   ash, whichever already exists; else removed). Cooking at a fire only works while it burns.
3. The structure info/inspect text shows fuel left and, for temporary fires, durability.
4. Save/load keeps fuel, burning state and durability; older saves without the fields load sanely.
Milestones:
M1 game/tests/t_firepits.gd: empty firepit hides its wood node and doesn't burn; loading wood shows it and burns; fuel out
hides it again; bonfire shows wood+fire at once, burns out after the fuel time, durability falls over time and ~2x faster
outside a Domain, removed at 0; cooking refused when not burning; save/load round-trip. Stage 1.
M2 implementation + data. Stage 1.
M3 report + full verify; update docs/current/building.md (or the structures section) and recipes.md if cooking changed.


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/firepits_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=kitchen_lab --shot-dir=/tmp/firepits_shots > /tmp/firepits_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/firepits_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/firepits, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh firepits [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_firepits.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[firepits] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-firepits.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
