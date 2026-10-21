# Task: CLAIMS2: claims expand on a predictable grid, have limits, and claimed land has no grass

Owner, verbatim: "claimed land shouldn't have the grass, also claims should expand in a predictable way and there are claim
limits". DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (844x390).
## The docs (docs/prd/durango-wild-lands-systems-prd.md)
- §13.1 (line 797): "First claim: 4x4. One additional same-size expansion free. Further expansions ... orthogonal only (no
  diagonal)." Line 183: raising Pioneer Level expands the domain. The PRD gives no maximum plot count.
## Today (claude/mmo-overhaul)
- game/scripts/world/island_claims.gd: setup() (home: a 14x14 base plot around the camp plus saved plots; unstable: the camp
  plot plus staked ones), claim_at(rt, tile, 14) stakes a 14x14 plot CENTRED ON THE SURVIVOR'S TILE, expand_reason()
  only asks that the new plot share an edge with held land. So where a plot lands depends on where the survivor stands, and
  plots end up offset from each other: this is the "not predictable" the owner means.
- game/scripts/player/player_actions.gd:575 claim() / :594 claim_confirmed(); game/scripts/ui/claim_panel.gd and
  hunt_hud.gd:648 open the confirm panel. World.pioneer_level is the player level (level_display.gd:5), saved in
  save_game.gd. Claims are set up BEFORE resources are scattered (island_runtime.gd:133-134).
- Tests: game/tests/t_claimfix.gd, t_domain.gd (keep their asserts; edit, do not rewrite).
## What to build
1. Plot grid: plots are 14x14 cells on a grid anchored at the base plot (home: the camp plot; unstable: the camp plot).
   The candidates are the free cells orthogonally next to held land that pass block_reason (dry land, nobody else's).
   CLAIM stakes the candidate cell the survivor stands in; standing elsewhere gives a notice naming where to stand. The
   claim panel draws every candidate cell as a dashed ghost outline on the ground (reuse claim_outline / the boundary
   mesh style) with the survivor's cell highlighted, so the next plot is always visible before confirming. Saved plots
   that are off the grid (older saves) load unchanged; new plots always snap to the grid.
2. Limits from data (ASSUMPTION numbers, the owner may change them): game/data/world/rules.json
   `"claims": {"home_base_plots": 2, "plots_per_levels": 10, "home_max_plots": 9, "unstable_max_plots": 2}` -> on home the
   limit is min(home_max_plots, home_base_plots + floor(World.pioneer_level / plots_per_levels)) (the base plot plus the
   PRD's one free expansion, more as the Pioneer Level rises); on unstable islands unstable_max_plots. At the limit CLAIM
   is refused with a notice "Land limit reached (n/n). Raise your Pioneer Level to claim more." and the HUD/panel shows
   "plots used / limit". Do not add T-stone costs (money changes need the owner).
3. No grass on claimed land: grass families (Grass, Grass_Short, WildGrass, DryGrassTuft; ASSUMPTION: FibreTuft, reeds,
   trees, rocks and bushes stay) are not scattered on claimed tiles, and when a plot is claimed their nodes inside it are
   removed at once, together with any grass decor instances inside it (island_scatter.gd `_multimesh_family`). Add
   `signal claims_changed(rect: Rect2i)` on IslandRuntime, emitted after each new plot: another job (GROUND2D, new painted
   ground cover) listens to it to clear its cover. Keep edits to island_scatter.gd to a few lines that call one helper in
   island_claims.gd (another job edits island_scatter.gd's card code).
## Milestones
- M1 game/tests/t_claims2.gd: candidates = the free orthogonal grid neighbours; a claim from inside a candidate cell takes
  exactly that cell; standing outside any candidate is refused with the notice; the limit formula at Pioneer Level 0, 10,
  70 (home) and on an unstable island; the limit refusal; an off-grid saved plot still loads and new plots snap to the
  base grid; grass nodes inside a new plot are removed and non-grass nodes stay; claims_changed fires once per new plot;
  save/load keeps the plots. Stage 1.
- M2 Grid + limits + grass removal + the signal. Stage 1.
- M3 Claim panel ghosts and the "used / limit" readout; game/scripts/dev/claims2_lab.gd + scene: on home, claim up to the
  limit, then try one more; print `[claims2] RESULT candidates= claimed= limit= refused_at_limit= off_grid= grass_in_claim=
  other_nodes_kept= ghosts_drawn= ui_min_px=` (candidates = before the last claim; off_grid = held plots not on the base
  grid made this run; grass_in_claim = grass nodes or decor instances inside claimed plots; other_nodes_kept = 1 when the
  non-grass nodes inside the plots survived; ghosts_drawn = candidate outlines on screen; ui_min_px = the smallest tap
  target in the claim panel) and save shots with the ghosts showing, at the limit, and of a claimed plot with no grass.
  Stage 2.
- M4 Look at every shot (path + verdict in NOTES.md); fix and re-shoot. Stage 2.
- M5 Report (with the limit numbers as ASSUMPTIONS for the owner) and the full verify.

## How to run Godot (exactly)
- Headless test: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 400; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > /tmp/claims2_t.log 2>&1` (bash timeout_ms 460000).
- Labs and screenshots need a window, never --headless (frame_post_draw never fires headless); bash timeout_ms 1020000, and the lab quits itself within 120 s:
  `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=claims2_lab --shot-dir=/tmp/claims2_shots > /tmp/claims2_lab.log 2>&1`, and again with --resolution 844x390 (the phone, landscape).
- After adding a class_name file or an asset: `... perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/claims2_import.log 2>&1`.
- Parse-check every new or edited .gd before a long run: `... --headless --path game --check-only --script res://<path>`.
- Never pipe Godot into tail/head/grep: read the log file afterwards. Never re-run a failed or hung command unchanged.
## Known traps
- `:=` cannot infer from max()/min()/ternaries/Variant returns: use maxf/maxi or an explicit type.
- Await coroutines. A `--script` test has no autoloads on its first frame: load() scripts on the first frame and add a 60 s
  quit watchdog, as game/tests/t_domain.gd does; print `[<test name>] PASS` or FAIL lines.
- game/tests/t_save.gd prints 5 deliberate SCRIPT ERRORs; that is normal.
- A lab log with `SHADER ERROR` or `Unknown character` means the shader did not compile and every card draws grey: the
  gate fails on it. GDScript `##` comments are not shader syntax; shaders use `//`.
- Scratch files go in $TMPDIR/claims2, never /tmp or docs/. Never `rm -r` a path that has tracked files.
- Key any per-item data by a stable id (file name, src_rect), never by list order.
- Write big files in parts (write_file, then edit_file); never python `s.replace()` without checking it matched.
## Gates
- Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_job.sh claims2 [1|2]` (no argument = the full gate). Read it and
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/job_claims2.conf` (TEST, LAB, LAB_ASSERT, RELATED, SCOPE) before you start.
- The lab gets `--shot-dir=<dir>`: save every PNG there. It must print exactly one line `[claims2] RESULT k=v k=v ...` with every
  key LAB_ASSERT reads, MEASURED from the live scene (never constants), then quit.
- Milestones: write them to .dsc/PLAN.md and call milestone_done after each (milestones before MS_STAGE2 run stage 1, later
  ones stage 2). Anything visual: open the PNG, and write the path and a one-line verdict in .dsc/NOTES.md before ticking.
## Constraints
- Your files are the SCOPE regex in the conf; touch nothing else. Edit shared files, do not rewrite them; keep existing asserts.
- Keep game/override.cfg. Never touch other worktrees, ~/Documents/deadfront, the owner's save, or the main checkout. Do not
  merge branches, push or deploy. No new dependencies.
- Do not tune balance numbers (HP, damage, XP, fatigue or energy rates). Owner: "game balancing like tuning hp and damage wont
  make sense until crafting building and skills is done and tuned". Mark every number the docs do not give `# ASSUMPTION`.
- Report docs/orchestration/reports/dsc-claims2.md: what shipped, before/after numbers, the shots you looked at, assumptions,
  what the integrator needs.
