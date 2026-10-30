# claude-loading: loading screens between transitions

Owner (Milan, 2026-10-30): "also we don't have loading for some reason. You should add loading screens in between".

Branch `claude/mmo-loading`, cut from `origin/claude/mmo-overhaul` 4a685bc4. Not merged to canon.

## What shipped

- `game/scripts/ui/loading_screen.gd` (`LoadingScreen`, CanvasLayer 128, above every other layer).
  Opaque `UiTokens.HEADER` backdrop with a faint flat-top hex lattice, a flat-top hex emblem whose
  gold edge walks round, the destination title (Roboto Condensed via `SheetChrome.ui_theme()`), a GOLD
  bar with the current build stage and percent, and a rotating tip. Safe-area insets from
  `UiTokens.safe_insets`; compact sizes under 500 px tall. Fades in and out (0.18 s).
- `game/data/ui/loading_tips.json`: 11 tips, each about a system the game has (taming at 30 %, torpor
  and Sedative, Food Bag order, spoilage into Rot, timed research every 5 levels past 20, skill points,
  Warp Gem sailing and Survival gates, expedition resets and the half refund, the Tamed Island, tool
  affinity). No lore. Factions left out: the Faction Hall is still being built by another agent.
- Real progress: `PerfTrace.mark` (already called at every build phase, always, cheap) now also calls
  `LoadingScreen.stage(phase)`. The bar fraction per phase is the cumulative share of a home build's
  `[buildprofile]` table (shape, terrain, nav, camp, ground cover, biome dress, landmarks, families,
  props, pathing, spawns). The build stays synchronous: no caller changed, no `await` added to it.
- Frame kept alive: on a stage, if an overlay is up and the run is windowed, `RenderingServer.force_draw`
  shows a new frame, at most one per 200 ms. The live parts (bar, stage line, percent, emblem) are
  painted straight into a RenderingServer canvas item, because a Control's redraw waits for deferred
  calls that a forced frame mid-build never runs (first try showed 0 % at 58 %).
- No input reaches the world: the overlay's root Control stops mouse and touch, its `_input` marks
  every event handled (keys, pads, the touch layer), and the tree is paused while it is up (movement
  polls, AI, clocks); the overlay itself runs PROCESS_MODE_ALWAYS.
- Headless (tests): no fades and no forced frames, so `work` runs in the caller's frame exactly as
  before, and the overlay leaves the tree (and unpauses) before `run()` returns.

## Transitions covered

| Transition | Where | Title |
|---|---|---|
| Boot -> game scene load | `shell/boot.gd` `_enter_game` (windowed, not smoke/lab/shot) | "Loading the world" |
| Boot with a save | `World.ensure_survivor` | "Loading your save" (same overlay, retitled) |
| Boot without a save -> character creation | `World.ensure_survivor` | boot overlay fades off creation |
| Character creation -> tutorial island | `World.start_new` (cc.done) | "Entering the Tutorial Island" |
| `--skip-tutorial` pick -> Tamed Island | `World.start_new` (ip.picked) | "Sailing to Meadow Isle" (picked shape's name) |
| Tutorial last order -> own island grant | `Tutorial.ferry` via `World._fade_to` | "Sailing to <shape name>" |
| Harbour sailing, harbour home | `World.travel` via `_fade_to` | "Sailing to <island>" |
| Warp home (Warp Gems / map) | `World.travel` mode `warp_home` | "Warping to <island>" |
| Expedition reset while standing on it | `World.reset_expedition` | "The island shifted: charting <island>" |

`World._fade_to` (the old black 0.25 s fade, layer 80) is now the overlay; the WorldFade layer is gone.
There is no main menu in this build (boot goes straight to the save or creation), so "boot -> main menu"
is the boot overlay above. Not wrapped: `world_ui._choose_terrain` (the pre-ISLANDPICK terrain sheet,
not reachable in the current flow) and the dev `main._test_island`.

## Screenshots (windowed, off-screen, self-quitting via `-- --loading-shot=<png>`)

- `docs/orchestration/reports/loading/tutorial_1600x900.png` - "Entering the Tutorial Island", 58 %
- `docs/orchestration/reports/loading/tutorial_844x390.png` - same at phone landscape
- `docs/orchestration/reports/loading/save_1600x900.png` - "Loading your save", 64 %
- `docs/orchestration/reports/loading/save_844x390.png` - same at phone landscape

Runs: `--new-game --occupation=soldier` (never sits on the character screen), then a second run on that
HOME's save. `--loading-shot` saves the first forced frame past 50 % and quits when the overlay is gone.

## Build-time impact

- Headless and any build without an overlay: one null check per PerfTrace mark (~25 per build). The
  build code is otherwise unchanged; t_buildspeed digests and budgets: see Tests.
- Windowed with the overlay: the forced frames are the only added time. Measured (printed as
  `[loading] <title>: N forced frames, X ms`): save load 11-12 frames, 40-43 ms; tutorial entry
  12-16 frames, 214-238 ms (~14 ms a frame there, mostly the vsync swap). Plus the 0.18 s fade in and
  out, which replaces the old 0.25 s black fade on travel.
- Tried and dropped: disabling vsync around each forced frame (slower, 342 ms) and `disable_3d` while
  opaque (no change; the cost is the swap, not the 3D).

## Tests

All headless, own HOME per test (tools/all_tests.sh, gslot wrapper, TEST_TIMEOUT 1200).

- t_loading (new): PASS. Tips equal the data file's rows and the overlay shows one; tree paused and
  overlay at layer 128 while up; a pushed key, click and touch reach no world input stage (a probe that
  hears them once the overlay is gone is the control); an island load under `run()` moves the bar to
  0.96 from the build's stages, ends at 1.0, hides, leaves no node; `World.travel` shows "Sailing to
  Savannah 15", arrives, ends at 1.0, hides, unpauses.
- t_tutorial: PASS (504 s). A first run under 5 parallel jobs failed at step 14 (tut_butcher "carcass
  gone", the bot's timing under load); rerun passed, and base 4a685bc4 passed alongside it (451 s).
- t_save, t_charcreate, t_islandpick, t_savefix, t_taskscreen: PASS. run_all: `[tests] PASS`. smoke:
  `SMOKE PASS`.
- t_buildspeed: FAILS on digests, identically on base 4a685bc4 (home fff95c7f..., savannah bc0b4799...,
  volcanic e06016a4...: canon's ISLANDMATRIX M5 changed the islands without re-recording). Same
  digests on this branch = the loading change places nothing differently.
- t_perfgates: timing only, flips with machine load on both trees (base FAIL home 2557 ms vs budget
  2500 in one run, PASS in another). Side-by-side run (both at once, load ~8): best home 2509 base /
  2747 here, savannah 2652 / 2983, volcanic 2345 / 2366, tutorial 7829 / 7174. The only code on the
  build path is one null check per PerfTrace mark, so this spread is the box, not the change.

## Assumptions

- `# ASSUMPTION`-free in code: titles reuse island `display_name` / the shape's `display_name`.
- The tree is paused while loading. `Game` already pauses it on app background; nothing else uses pause.
- Tip copy is mine, each checked against the code/data named in the tips file's `system` field.

## Next agent

- A travel screenshot was not taken windowed (no harbour driver in a short run); the headless t_loading
  covers the travel overlay, and it is the same overlay.
- If a later change adds/renames PerfTrace marks, update `LoadingScreen.STAGES` (a missing mark only
  leaves the bar where it was).
