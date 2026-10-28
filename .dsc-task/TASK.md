# Task: MOVEPRIORITY — click-to-move beats combat unless you take damage
Owner, verbatim: "Click to move navigation should take a priority over combat, unless the player takes damage, then it
attacks damage source/nearest."
Read first: game/scripts/player/player_input.gd (click/tap to move, auto-attack), game/scripts/combat/hunt.gd (combat
state, auto-attack, targeting), game/scripts/player/player.gd (damage handling: `_on_vitals_damaged`, the hurt stun),
docs/current/controls.md, and the owner targeting rule in docs/design/ui-redesign-spec.md §11 (out of combat a tap on an
enemy selects it; in combat a tap on another enemy retargets; ATTACK NEAREST retargets).
Rule:
1. A click/tap on the ground (a move order) is always honoured: auto-attack/auto-chase must not pull the survivor off
   her path, even with a target selected or enemies nearby, until she arrives or the player issues another order.
   Tapping an ENEMY is still a target/retarget, not a move.
2. If she takes damage while executing a move order, the move order is cancelled after the hurt stun and she attacks
   the damage source (the creature that hit her); if the source is unknown, gone or out of reach, the nearest hostile.
   DoT ticks (bleed/poison) do not count as "taking damage" for this (they have no attacker to turn to; the existing
   rule already skips the stun for ticks).
3. Without a move order, today's combat behaviour is unchanged.
Milestones:
M1 game/tests/t_movepriority.gd: with an enemy in auto-attack range, a ground click makes her walk to the point without
attacking; a hit from creature A during the walk cancels the move and she attacks A; a hit with no live source attacks
the nearest hostile; a bleed tick during the walk does not cancel it; tapping an enemy during the walk retargets per the
§11 rule; with no move order, auto-attack works as before. Stage 1.
M2 implementation. Stage 1.
M3 report + full verify; update docs/current/controls.md (and the §11 owner rules in ui-redesign-spec.md, dated
2026-10-28 [owner]).


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/movepriority_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=creature_lab --shot-dir=/tmp/movepriority_shots > /tmp/movepriority_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/movepriority_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/movepriority, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh movepriority [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_movepriority.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[movepriority] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-movepriority.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
