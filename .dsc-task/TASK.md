# Task: MAPUI: the map reveals as you explore, with icons and your trail (specs 15 and 25)

Owner, verbatim (spec 25): "For the map, areas that are undiscovered are greyed out and areas that you walk towards are
discovered like a paintbrush on a canvas. There are icons on the map for houses(claims), campfires, your footsteps as you
walk are registered as black dots from where you came from. Other player icons are grey dots. Certain facilities related to
trade, quests, etc, get their own map icons". Read docs/design/durango-prompts/15_island_map_scale.md and 25 (item 2), and the
reference docs/reference/durango-island-map.webp. DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project
`game/`), web build, mobile-first (844x390 landscape).
## Today
- game/scripts/ui/map_screen.gd (MapScreen: open(), _set_zoom(), _mark(at, radius, kind, ring), region cards) and the minimap
  in game/scripts/ui/hunt_hud.gd (the minimap and atlas share one texture, around hunt_hud.gd:1253-1280).
## What to build
1. Fog of war per island: undiscovered area greyed out; walking reveals a soft round brush around the survivor (radius
   ASSUMPTION ~25 m), drawn on both the map and the minimap; saved per island (a compact bitmap, e.g. 2 m cells, stored as
   base64 or run-length in the save; old saves load with everything near the camp revealed). This adds a save field: keep
   it backward compatible and list it in the report as an owner decision.
2. A trail of black dots from where the survivor walked (one dot per ~8 m, the last ~200 kept, saved).
3. Icons: your claims (a house icon), campfires/bonfires you built, the harbour, and facilities (trade, quest givers,
   stations) where they exist; other players as grey dots when the network lists them (skip silently offline).
4. Tap targets >= 64 px on the phone; icons readable at 844x390.
## Milestones
- M1 game/tests/t_mapui.gd (t_domain.gd's pattern): reveal math (a walk reveals cells within the brush and nothing else),
  trail spacing and cap, save/load round trip of fog + trail, an old save with no fog loads with the camp revealed. Stage 1.
- M2 Fog + trail + persistence wired into map_screen and the minimap. Stage 1.
- M3 Icons. game/scripts/dev/mapui_lab.gd + scene: start on home, open the map (fog_start = grey share), walk a path, open it
  again; print `[mapui] RESULT fog_start= revealed_after_walk= fog_after_walk= trail_dots= claim_icons= campfire_icons=
  facility_icons= persist_ok= ui_min_px=` and save shots before, after, and the minimap. Stage 2.
- M4 Look at every shot next to docs/reference/durango-island-map.webp (path + verdict in NOTES.md); fix; report; full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/mapui_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=mapui_lab --shot-dir=/tmp/mapui_shots > /tmp/mapui_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/mapui_import.log 2>&1`.
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
- Scratch files go in $TMPDIR/mapui, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh mapui [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_mapui.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[mapui] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-mapui.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
