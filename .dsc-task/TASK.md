# Task: RAGDOLL r2 — fix the three review majors, then bring the branch up to date
You are on claude/mmo-ragdoll, cut from claude/mmo-w2-ragdoll (dinosaurs ragdoll onto the terrain on death and freeze once
settled; owner asked for it). First merge the current canon: `git merge claude/mmo-overhaul` (resolve conflicts keeping
both sides' behaviour; canon's creature.gd now has `ridden`, energy and turn-rate code, keep all of it), then import.
Review majors to fix:
1. An aborted ragdoll (killed then the ragdoll is cancelled or fails) makes the body STAND UP again. It must fall back to
   the death clip pose and stay down.
2. Only one blow direction is tested. Test hits from front, back, left, right: the body topples away from the blow.
3. The T. rex sinks 0.66 m into the ground once settled. No species may settle more than 0.08 m below the terrain at its
   lowest contact point (ASSUMPTION threshold).
Milestones:
M1 game/tests/t_ragdoll.gd extended: aborted ragdoll stays down; four blow directions; settle depth <= 0.08 m for every
species with a ragdoll entry (the T. rex included); the corpse is still harvestable (butchering) after settling. Stage 1.
M2 the fixes in ragdoll.gd / ragdoll_rig.gd / ragdoll_skin.gd / corpse.gd / ragdoll.json. Stage 1.
M3 report + full verify.

## Round 2 (integrator review)
Your round 1 landed the three majors. Canon is now merged into your branch (the deinonychus is smaller with wider
wings; the tactical AI and new clips landed). Remaining before merge:
R1 The lab's lying gate fails `deinonychus` (hips ~0.8 m, a foot up) in every case: fix its ragdoll.json profile for the
new mesh (bone list, masses, wing bones limp, not stiff) so it lies flat; add a t_ragdoll assert that every species'
settled hips sit within its lying limit.
R2 compsognathus / coelophysis joint stretch on 30° slopes (the remaining fallbacks): fix or clamp so no joint stretches
more than 10% of its rest length; assert it.
R3 Re-run the full verify after an import (canon added files).


## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/ragdoll_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=ragdoll_lab --shot-dir=/tmp/ragdoll_shots > /tmp/ragdoll_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/ragdoll_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/ragdoll, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh ragdoll [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_ragdoll.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[ragdoll] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-ragdoll.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
