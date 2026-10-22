# Task: BIOMEPROPS - the BIOMEASSETS models must render correctly before they are placed again
Owner, 2026-10-22, on the deployed build: "props are broken". Cause: game/data/world/props.json named
the BIOMEASSETS models by the hyphen convention (spire-a, mesa-a, basalt-column-a...) which never
existed, so rock_spire, mesa_cliff, basalt_column, termite_mound and aloe were never placed. Pointing
the paths at the shipped underscore files made them appear - as giant untextured slabs - so the remap
was reverted. This job fixes the models, then re-enables the paths.
The models carry one Principled material "biome_vcol" whose base colour is the COLOR_0 vertex
attribute (per-vertex paint, no texture; tools/blender/biome_props/bp_lib.py). Godot does not use
COLOR_0 as albedo unless the imported material says so, which is why they render flat grey/black.
Milestones:
M1 game/tests/t_biomeprops.gd: for every kind in props.json that points at res://assets/nature/biome/,
the model exists, loads, has a MeshInstance3D with a material, that material uses vertex colour as
albedo, and the mesh AABB fits the kind's declared radius_m (height between 0.5x and 3x of it). Fails
before the fix. Stage 1.
M2 the fix: make the imported biome_vcol material use vertex colour as albedo (an export step in
tools/blender/biome_props/ or a documented Godot import pass like
tools/blender/structures/godot_import_settings.py), and rescale any model whose AABB is out of band.
Do not repaint art; the vertex colours are the owner-approved palette. Stage 1.
M3 re-enable the paths in game/data/world/props.json (hyphen -> shipped underscore ids, one dropped
where no stand-in exists) and make island_props place them; M1 green. Stage 1.
M4 game/scripts/dev/biomeprops_lab.gd + scene: a game-camera shot of each fixed kind on the home
island, printing `[biomeprops] RESULT kinds= vcol_ok= scale_ok= placed= missing_files=` and saving
at least 2 PNGs into --shot-dir. Look at the PNGs and record a verdict in .dsc/NOTES.md. Stage 2.
M5 report docs/orchestration/reports/dsc-biomeprops.md and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/biomeprops_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=biomeprops_lab --shot-dir=/tmp/biomeprops_shots > /tmp/biomeprops_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/biomeprops_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/biomeprops, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh biomeprops [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_biomeprops.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[biomeprops] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-biomeprops.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
