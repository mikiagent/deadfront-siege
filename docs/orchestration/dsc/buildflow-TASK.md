# Task: BUILDFLOW: the Craft/Build construction pipeline and a working Basic Workbench (owner's spec 30, phases 1-3)

The owner's spec: docs/design/durango-prompts/30_building_construction_and_crafting_stations.md - READ IT ALL FIRST. Goal
(§18): gather logs + reeds/stalks -> craft 2 Plank Shape, 2 Pillar Shape, 6 Strap -> unlock Basic Workbench -> place it in
your claimed land -> a CONSTRUCTION SITE appears -> deposit each exact item -> do build work -> a level-calculated
Workbench is finished -> open it -> run a real queued processing job -> collect the output once -> save/reload keeps it all.
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (844x390 landscape).
## What this tree holds (merged for you; reuse, never build a parallel system - spec 30 §0)
- claude/mmo-overhaul (camera, claims, inventory with unique item instances W2-INV, skills W2-SKILLS with recipe node
  gates SkillRules.recipe_block, W2-DATA items/recipes incl. "plank" and "pillar" items in game/data/items.json).
- W2-PROCESS (merged here): game/scripts/world/process_station.gd (stations with timed jobs that keep running, COLLECT,
  exact picks by uid, destroyed-station salvage), game/data/processing.json, craft_station.gd, station_craft.gd.
- W2-BUILDSYS (merged here, not yet reviewed): modular building, building HP, tiers, repair/upgrade/demolish, chest/large
  box/signboard, build placement (game/scripts/world/build_placer.gd, placed_building.gd). A reviewer is writing a gap map
  of W2-BUILDSYS against spec 30; you will get it by message - use it.
- Claims: game/scripts/world/island_claims.gd (IslandClaims.is_claimed etc.). ANOTHER JOB rewrites claims into 4x4-tile
  cells right now: call IslandClaims' public functions only and do not edit island_claims.gd.
- 3D models for workbench tiers and construction-site stages are being made by another job (names basic_workbench,
  site_small_0/1/2, site_large_0/1/2 under game/assets/props/blender/): load them by name when the file exists, else fall
  back to today's workbench model and a simple stand-in, so the code works before the art lands.
## First fix the merged base (M0): game/tests/t_process.gd fails 2 checks here (W2-PROCESS predates W2-INV's unique,
non-stacking instances):
  `[t_process] FAIL a forged 1e9 x lv 5e6 output loads as one stack of <= 1 at lv <= 60 ({ "jobs": 0, "ready": 999,
  "refund": 999, "level": 60, "units": 40, "left": 959 })`
  `[t_process] FAIL a destroyed rack hands over its dried meat (same uid), the drying hide and the drying meat`
  Find why (read inventory.gd's instance model and process_station.gd's load/salvage), fix the code (not the asserts).
## Build (spec 30 phases 1-3; keep every number in data and mark guesses # ASSUMPTION; do not tune balance)
1. Components (§4-5): tag-based ingredient slots (slot_id, quantity, accepted_tags, min_level, role, level_contributing);
   recipes Raw Log -> Pillar Shape, Raw Log -> Plank Shape, reed/stalk/root -> Strap, producing unique instances with
   levels from their inputs; the player picks exact instances (never auto-consume a rare one).
2. Blueprint + site (§2, §3, §6-8): Craft/Build menu entry with the categories of §2 (only Basic Workbench needs to be
   buildable now); its details panel shows unmet prerequisites exactly (Construction level, the learned skill node, tools,
   ingredients, land). Placing creates a persistent ConstructionSite (unique id, owner, blueprint, transform, footprint,
   empty slots, progress) - NOT a working station. Site UI: slots with deposited instances, Deposit / Withdraw / Work /
   Cancel; deposits move the real instances into the site's escrow (no clones); Work is a real timed action; completion is
   atomic: consumes escrow once, computes level = min(clamp(floor(weighted avg of level-contributing inputs), bp_min,
   bp_max), Construction level) (§9), removes the site, creates exactly one Workbench; cancel returns the instances.
3. Station (§10-11): the finished Workbench has tags [workbench] and its level; its UI lists eligible recipes and says
   why others are not (tag, level, skill); one processing recipe requiring Workbench >= N runs as a queued job through
   W2-PROCESS's job machinery; output collected exactly once; a full bag never deletes it.
## Milestones
- M0 t_process passes on this tree (and t_build, t_save still pass).
- M1 game/tests/t_buildflow.gd (spec 30 §17 items 1-6, 8-10, 12-14, 16, 18): write the asserts first. Stage 1 will fail
  until the code lands; that is expected for M1 only.
- M2 Components. M3 Blueprint + placement + site + escrow + persistence. M4 Work + completion + level. M5 Station + job.
  (Stage 1 from M2 on: the tests you wrote must pass for the parts built.)
- M6 game/scripts/dev/buildflow_lab.gd + scene: play spec 30 §18 on the home island through the real UI calls; print
  `[buildflow] RESULT steps_total= steps_ok= site_not_station= dup_items= lost_items= collected_once= save_roundtrip=
  wrong_tag_refused= low_station_refused= ui_min_px=` and save shots: the Craft/Build menu, the blueprint details, the
  site with materials, the finished workbench, its station UI with a running job. Stage 2.
- M7 Look at every shot (path + verdict in NOTES.md); report docs/orchestration/reports/dsc-buildflow.md (what is historical
  vs estimated per spec 30, the data you added, the t_process fix, what phases 4-5 need) and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/buildflow_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=buildflow_lab --shot-dir=/tmp/buildflow_shots > /tmp/buildflow_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/buildflow_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/buildflow, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh buildflow [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_buildflow.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[buildflow] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-buildflow.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
