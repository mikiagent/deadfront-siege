# Task: OCCLUDE2: the survivor is always visible

Playtest: the survivor was hidden under the harbour roof at spawn and behind bushes. Spec:
docs/design/durango-prompts/21_tall_trees_transparency.md. DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project
`game/`), web build (gl_compatibility), mobile-first (phone 844x390 landscape).
Today: see-through trees exist (W2-OCCLUDE): game/scripts/world/occlusion.gd, occlusion_material.gd, game/tests/t_occlude.gd,
lab game/scripts/dev/occlusion_lab.gd (+ scene). Another job (CARD2D, unmerged) adds occlusion.make_card_occludable() for 2D
cards: keep the existing occlusion API working and name the merge point in your report. A camera change is coming on another
branch (perspective camera): never hard-code the projection or the angle; use the active Camera3D.
## What to build
1. Roofs (the harbour, tents, buildings) fade when the survivor is under or behind them.
2. Bushes and canopies between the camera and the survivor fade or dither PER OBJECT; tree trunks stay solid.
3. Fades are smooth (>= 0.15 s, no pop).
## Milestones
- M1 Measure today: extend occlusion_lab to place the survivor at the harbour spawn, in a dense bush field, and under a tree
  canopy, and measure the share of the survivor that is visible (pick a measurable method: e.g. render a flat-colour ID pass
  of the survivor alone and with the scene, and count pixels). Write the before numbers in NOTES.md. Write
  game/tests/t_occlude2.gd for the logic (which objects fade for a given camera and survivor position; trunks never fade).
  Stage 1.
- M2 Roof fades. Stage 1.
- M3 Per-object bush/canopy fade, trunks solid; the lab prints `[occlude2] RESULT vis_harbour= vis_bush= vis_canopy=
  fade_s= pops= trunk_alpha_min=` (pops = frames where an object's alpha jumps > 0.25) and saves 3 shots into --shot-dir.
  Stage 2.
- M4 Both resolutions pass. If 0.6 visible is impossible in a case, keep the gate, write why in the report, and stop.
- M5 Report with before/after numbers and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/occlude2_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless):
  `... perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=occlusion_lab --shot-dir=/tmp/occlude2_shots > /tmp/occlude2_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/occlude2_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh occlude2 [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_occlude2.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[occlude2] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-occlude2.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
