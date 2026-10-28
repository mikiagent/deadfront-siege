# Task: ROLL — a roll that carries you clear and dodges a well-timed attack

Owner (verbatim, 2026-10-28): "roll should take you farther away and allow you to dodge an enemy attack if well
timed (invincibility for a small amount of time)". Spec: docs/design/durango-prompts/07_combat_and_animal_capture.md §2
(telegraph + timed Roll; roll has stamina/energy/cooldown; Defense XP only for a real narrow dodge, never for spam).

Today: game/scripts/player/player_sim.gd (_roll_left, _roll_direction, _roll_through, buffered roll), the combat roll
tactic (hunt.gd tactic slot 3 "Roll", combat_tactics.gd), creature attack windup/hit (creature.gd, brains), and the
server combat path (game/scripts/server/: intent handlers for hits/dodge — read docs/current/server-contract.md).
Read them first; extend, do not build a second dodge system.

Do (data-driven, every number `# ASSUMPTION` in rules.json or combat_tuning.json unless spec 07 gives it):
1. Roll distance: longer than today (measure today's distance first; target roughly 1.6-2x, e.g. ~4-5 m), speed curve
   front-loaded, never through terrain/obstacles it could not walk through.
2. I-frames: invulnerable to creature melee/ranged hits for the first part of the roll (e.g. 0.30-0.35 s of a ~0.55 s
   roll). A hit whose damage would land inside the window is dodged: no damage, no stagger, a small "Dodged" float.
3. Cost and limits: a stamina/energy cost and a short cooldown (e.g. 0.8-1.0 s) so it can't be chained; input buffer
   kept.
4. Defense XP only when an attack that would have hit is actually dodged (once per attack).
5. Server/authority: the online path must honour the same window (whatever validates hits server-side checks the
   roll state at the hit time) — if the server has no hit validation yet, record that in the report and make the
   shared rule live in one place both paths call.
Milestones (.dsc/PLAN.md; milestone_done each):
M1 game/tests/t_roll.gd ("[t_roll] PASS"; t_combat.gd structure): distance >= the new target and blocked by a wall;
   a deinonychus bite landing at 0.15 s into the roll deals 0 and pays Defense XP once; the same bite at 0.5 s (after
   the window) deals damage; roll during cooldown is refused; stamina is spent; spamming roll with no attack pays no
   XP; server path agrees. Fails on base. Stage 1.
M2 implementation. M3 docs/current (controls/combat facts) + report docs/orchestration/reports/dsc-roll.md + full
verify. Headless only.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/roll_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/roll_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/roll, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh roll [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_roll.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[roll] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-roll.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
