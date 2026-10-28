# Task: OCCLFIX — trees BEHIND the survivor must stay solid

Owner bug (verbatim): "Occlusion bug. Trees behind the player (from the camera's perspective) are going translucent
when they should stay solid until the tree hides the player model".

Rule: an occluder may fade ONLY when it is between the camera and the survivor — nearer the camera than the survivor
(along the view ray / in view depth) AND overlapping the survivor's screen footprint. A tree farther from the camera
than the survivor must stay fully solid even if its crown overlaps the survivor on screen (it is behind her). Partial
fade rule for real occluders is unchanged (owner 2026-10-20: fade whole object to about half, soft 0.25 s; trunks solid
per OCCLUDE2).

Code: game/scripts/world/occlusion.gd — `in_the_way(chest, back)`, `_box_hit`, `ray_hits_cylinder`, `_instance_hit`,
`unlean`, `_send_body`, `step_between`, plus the fade shader includes (occlu_*.gdshaderinc: if the shader fades by a
screen-space circle around the body without a depth test, that alone would fade trees behind her — check
`_send_body` and the shader). Find the actual cause first and write it in .dsc/NOTES.md before fixing; fix it at the
root (CPU selection and/or a depth comparison in the shader), smallest change.
Milestones: M1 game/tests/t_occlfix.gd ("[t_occlfix] PASS"; t_occlude.gd structure): with the real camera setup
(read CAMERA: iso_camera/camera scripts) place a survivor, a tree directly BEHIND her on the camera ray whose crown
overlaps her on screen -> fade stays 0 (solid); a tree directly IN FRONT on the ray -> it fades; a tree beside her not
overlapping -> solid; also MultiMesh/card instances (props/forest cards) both ways. Fails on base for the "behind"
case. Stage 1. M2 fix. M3 report docs/orchestration/reports/dsc-occlfix.md + docs/current note + full verify.
Headless only (owner reserved the machine): if the shader is the cause, test the uniform/depth inputs the CPU sends
and the shader maths via a GDScript mirror, and say what still needs an on-screen check.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/occlfix_t.log 2>&1` (bash timeout_ms 460000).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/occlfix_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/occlfix, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_job.sh occlfix [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/job_occlfix.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[occlfix] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-occlfix.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
