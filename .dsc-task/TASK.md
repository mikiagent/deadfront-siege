# Task: CAPTURE09 — capture when stunned at any HP, or at <= 30 % HP (owner spec 09)

Owner rule (docs/design/durango-prompts/09_capture_threshold_and_bonded_pet_limits.md §1, STATUS owner decision
2026-10-20): a wild animal is capturable when it is **stunned/collapsed at ANY HP, OR its HP <= 30 %**. The code still
requires BOTH (knocked out AND under 30 %). Fix it in the one shared rule; do not build a second capture system.

Where the old rule lives today (read all of them first):
- game/scripts/pets/field_tame.gd: CAPTURE_HEALTH_FRAC, health_allows_capture(), can_attempt() (feeding tame).
- game/scripts/pets/capture_system.gd: attempt() refuses above 30 % even when stunned; chance = base x (1.5 - hp).
- game/scripts/combat/hunt.gd use_net/_net_health_ok: "Weaken it below 30% health before netting it."
- game/scripts/server/intent_handlers.gd ~359/~408: server refusals with the old wording.
- game/scripts/creatures/creature.gd ~597: groggy -> knockdown only under 30 %.
- game/scripts/combat/status_effects.gd ~212: DoTs stop inside the capture window.
"Stunned" = the existing `knockdown` status (statuses.json). Do not invent a new status.

Do:
1. One function, e.g. `FieldTame.capture_window(creature) -> bool` = not dead, tameable, not a pet, and
   (statuses.has(&"knockdown") or hp_fraction <= CAPTURE_HEALTH_FRAC). Note `<=` (spec), not `<`. Every site above
   calls it (feeding tame, net capture, hunt UI, server intents). Keep technique/net-tier/cooldown checks as they are.
2. Chance keeps using ACTUAL current HP (spec: "use actual current HP, level and Capture Ability"; never substitute 30 %).
   Keep the existing formula shape; do not retune its numbers.
3. Messages: hunt.gd and server refusals say "Stun it or weaken it to 30% health to capture it."
4. Tutorial hint once per creature when a tameable wild animal you are fighting drops to <= 50 % HP and is not stunned:
   "Stun the dinosaur to capture it safely." Use the existing say()/notice path in hunt.gd; no new UI widget.
5. Never force damage onto a stunned capturable animal: the DoT guard in status_effects.gd must use the same window.
6. t_tame.gd's capture-rule asserts are updated, never deleted.

Milestones (.dsc/PLAN.md, milestone_done after each):
M1 game/tests/t_capture09.gd (copy t_domain.gd / t_tame.gd structure, load() scripts on the first frame, 60 s watchdog,
   prints "[t_capture09] PASS"): stunned at 80 % HP -> capturable; not stunned at 30 % -> capturable; not stunned at 31 %
   -> not; dead / pet / non-tameable -> not; CaptureSystem chance at 80 % stunned < chance at 20 % stunned (actual HP
   used); the DoT guard skips a stunned 80 % animal; the 50 % hint fires once. Fails on the old code. Stage 1.
M2 the shared window + every call site above. Stage 1.
M3 messages + hint, t_tame updated, report docs/orchestration/reports/dsc-capture09.md, full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/capture09_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=capture_lab --shot-dir=/tmp/capture09_shots > /tmp/capture09_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/capture09_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/capture09, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh capture09 [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_capture09.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[capture09] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-capture09.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
