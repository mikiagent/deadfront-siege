# Task: GROUND2D: dense swaying ground cover from the owner's painted grass

Islands plan package P2 (docs/design/islands-and-loop-plan.md, section 4, row 2: "Ground cover (biggest gap)"); spec 28
section "Tall grasses on terrain". DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build
(gl_compatibility), mobile-first; the camera is a long-lens perspective camera (game/scripts/camera/iso_camera.gd).
## Today
game/scripts/world/island_scatter.gd:312-360 `_multimesh_family`: one island-wide MultiMeshInstance3D per decor family
(3D grass meshes), `visibility_range_end = IsoCamera.cull_range(8.0)`, which now covers the whole island. Painted
sprites: game/data/world/sprites2d.json + game/assets/nature/sprites2d/ (grass clumps, reeds, ferns, weeds; more arrive
from sheet-tall-grasses later - read the manifest, never hard-code ids). Card shader: game/shaders/card_sway.gdshader
(sway + parallax; uses the camera's global shader parameters).
## What to build
1. game/scripts/world/ground_cover.gd: ground cover as camera-facing painted cards in a MultiMesh per 32 m cell (like
   VegBatch), placed with retries on dry ground only, density thinning with distance instead of switching off, no
   shadows, never colliding, per-instance tint and scale jitter, sway from the card shader (or a ground_cover.gdshader
   that shares its sway). Sets per climate (ASSUMPTION; zones come later from another job): grassland/temperate: green
   grass clumps, weeds, ferns, flowers; savannah: dry golden tufts; swamp: reeds and lush grass; tropical: ferns, lush
   grass; NONE on desert, tundra, volcanic. Data in game/data/world/ground_cover.json (sprite ids by kind/name from the
   manifest, density per m2, scale range).
2. Hook it from island_scatter.gd with a few lines replacing the `_multimesh_family` grass decor (keep the function for
   non-grass decor if any). Touch nothing else in island_scatter.gd: another job edits its card path near line 175.
## Milestones
- M1 game/tests/t_ground2d.gd: per-climate set selection (none on desert/tundra/volcanic), deterministic placement for a
  seed, no colliders, cell bounds. Stage 1.
- M2 ground_cover.gd + data + the hook. Stage 1.
- M3 game/scripts/dev/ground2d_lab.gd + scene: home_grassland and one forest/temperate spot, print `[ground2d] RESULT
  density_camp= density_forest= density_far= far_ratio= blocking= wrong_biome= grey_cards= prims_camp= ms_frame= ms_base=`
  (density = instances per m2 within 25 m of the survivor; far = a point 150 m from the origin; far_ratio = far/near;
  blocking = ground-cover colliders; wrong_biome = instances on desert/tundra/volcanic tiles in a check on one such island;
  grey_cards = flat/blank card rects; prims_camp = visible primitives at camp (Performance/RenderingServer info);
  ms_base = the same view with ground cover off) and save shots at camp, forest and the far point. Stage 2.
- M4 Look at every shot (path + verdict in NOTES.md): it must read like the owner's sheet (lush clumps, dirt showing
  through, not a carpet of identical stamps). Stage 2.
- M5 Report and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/ground2d_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=ground2d_lab --shot-dir=/tmp/ground2d_shots > /tmp/ground2d_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/ground2d_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/ground2d, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh ground2d [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_ground2d.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[ground2d] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-ground2d.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
