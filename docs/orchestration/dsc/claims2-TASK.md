# Task: CLAIMS2: the Tamed Island Domain per the owner's spec 29 (cells, 13-plot cap, Domain menu, preview, no grass)

Owner, verbatim: "claimed land shouldn't have the grass, also claims should expand in a predictable way and there are claim
limits", then the owner gave a full spec: docs/design/durango-prompts/29_domain_land_claiming_and_territories.md (READ IT
FIRST, sections 2-4, 9, 12-14) and three Durango screenshots: docs/reference/durango-domain-menu.webp (Domain menu with tabs
Tamed Island / Civilized Island / Clan / Outpost; "While you're on your Tamed Island, you can only use buildings in your
Domain"), durango-domain-tamed-island-select.webp, durango-tamed-island-overview.webp (a tamed island with claimed areas).
DEADFRONT is a Godot 4.7.1 typed-GDScript survival game (project `game/`), web build, mobile-first (844x390 landscape).
This job is spec 29 Phase A (domain foundation) + Phase B (Tamed Island) + the footprint rule of Phase C + the owner's grass
rule. Phases D-G (Communications Center upgrades, Civilized Islands, clans, outposts) are LATER jobs: show their tabs as
locked with the reason ("Civilized Islands are not in the game yet"), wire nothing fake.
## Today (claude/mmo-overhaul)
- game/scripts/world/island_claims.gd: rt.claims is an Array of Rect2i; setup() claims a 14x14-tile base around the camp on
  the home (private) island plus saved rects (World.home_claims rows [x,y,w,h]); claim_at() stakes a 14x14 plot centred on
  the survivor's tile; expand_reason() only asks for a shared edge. BuildGrid tiles are 1 m (build_grid.gd:5 CELL_SIZE).
- game/scripts/player/player_actions.gd:575 claim() / :594 claim_confirmed(); game/scripts/ui/claim_panel.gd; hunt_hud.gd:648
  opens the panel; hunt_hud.gd:850 is the MENU sheet (Bag, Craft, ...): add "Domain" there. Claims are set up BEFORE resources
  are scattered (island_runtime.gd:133-134). World.pioneer_level is the player level (not Durango's Pioneer rank).
- Tests to keep passing (edit, do not rewrite; keep their asserts): game/tests/t_claimfix.gd, t_domain.gd, t_save.gd.
## What to build
1. Cells: a domain is a set of cells; one cell = `cell_tiles` x `cell_tiles` world tiles (4 by default, spec 29 §3), on a grid
   anchored at the island origin. A domain record per spec 29 §3 (domain_id, kind "tamed_island", island_id, owner, cells,
   max_cells, status). Config in game/data/world/domains.json: {"cell_tiles": 4, "tamed_island": {"start_cap": 13,
   "rank_caps": {"1": 13, "2": 17, "6": 23, "7": 30}}} (spec 29 §4: only these ranks are documented; a rank between them
   keeps the previous cap; mark them `historical, provisional`). Pioneer rank starts at 1 (its upgrade track is a later job).
2. Declare and Expand (spec 29 §2, §4): Domain screen (Main Menu -> Domain) with the four tabs; the Tamed Island tab shows
   island, cells used / cap, and Declare (no domain yet) or Expand (domain held). Both open a ground-grid PREVIEW: claimed
   cells, eligible cells (contiguous: edge-adjacent to the domain; for Declare any valid cell), invalid cells (water, cliff,
   another owner, outside the island) drawn clearly in different colours; tap cells to select up to the cap, see the
   candidate count, Confirm / Cancel; the camera can still move. Refusals say why: cap, terrain, ownership, not adjacent.
3. Persistence and old saves: save the domain record; an OLD save's 14x14 rects become the cells that cover them (keep every
   placed building inside the domain; the cap may be exceeded by a migrated save: then allow no new cells until under the
   cap, never remove cells). Old saves must load. This changes the save format: keep it backward compatible and list the
   change in the report as "owner decision" (the owner asked for this spec).
4. Building rule (spec 29 §9): a building's whole footprint must be on owned cells (no anchor-only placement across the
   border); on the Tamed Island buildings are usable only inside the domain (the Durango notice in the screenshot).
5. No grass on claimed land (owner): grass families (Grass, Grass_Short, WildGrass, DryGrassTuft; ASSUMPTION: FibreTuft,
   reeds, trees, rocks, bushes stay) are not scattered on claimed tiles, and claiming a cell removes those nodes and any
   grass decor instances inside it at once (island_scatter.gd `_multimesh_family`). Add `signal claims_changed(rect: Rect2i)`
   on IslandRuntime, emitted once per newly claimed cell batch (another job's painted ground cover listens to it). Keep
   island_scatter.gd edits to a few lines calling one helper (another job edits its card code).
## Milestones
- M1 game/tests/t_claims2.gd (model): cell size from data; declare one cell; expand only edge-adjacent cells; refuse at cap 13
  with the reason; refuse a non-adjacent cell; rank caps 1->13, 2->17, 4->17, 6->23, 7->30; a cell another owner holds is
  refused; the same cell twice is refused (no double claim); a legacy 14x14 rect save migrates to covering cells with every
  building inside; save/load round trip keeps cells and cap; claims_changed fires once per claim. Stage 1.
- M2 Model + data + persistence + migration. Stage 1.
- M3 Footprint rule, grass removal, the signal. Stage 1.
- M4 Domain screen, tabs, preview; game/scripts/dev/claims2_lab.gd + scene: open Main Menu -> Domain, Declare, expand to the
  cap, try one more and one non-adjacent cell, place a building half across the border; print `[claims2] RESULT cell_tiles=
  cap= claimed= refused_at_cap= non_contiguous_refused= eligible_shown= invalid_shown= tabs= grass_in_claim=
  other_nodes_kept= footprint_cross_refused= legacy_buildings_inside= save_roundtrip= ui_min_px=` and save shots of the
  Domain screen, the preview (claimed / eligible / invalid colours), the full 13-cell domain, and a claimed area with no
  grass. Stage 2.
- M5 Look at every shot (path + verdict in NOTES.md); compare with docs/reference/durango-domain-menu.webp; fix and re-shoot.
  Stage 2.
- M6 Report (config values marked historical/provisional, the save change, what later phases need) and the full verify.

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
