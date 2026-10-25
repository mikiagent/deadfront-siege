# ISLANDPICK (dsc) — five Tamed Island shapes, picked once

Branch: `claude/mmo-islandpick` (dsc worktree). Verify: `bash .../dsc/verify_job.sh islandpick` →
`VERIFY PASS` (t_islandpick, the pick lab at 1600x900 and 844x390, t_islandgen/t_save/t_harbour, smoke, scope).

## What shipped

**The five shapes are data.** `game/data/world/island_shapes.json` lists `meadow`, `forest`, `rocky`,
`riverside`, `coastal`: each has a `seed` (drives the ISLANDGEN landmass), the `terrain` row it uses
from `home_grassland.json`'s `terrains`, a display name, a one-line blurb and an accent colour for the
preview. Meadow is seed 17, i.e. exactly the island every save had before this task, so a fresh meadow
pick and an old save build the same ground.

**World (`game/scripts/core/world.gd`).** `home_shapes` / `home_shape`, `_load_shapes()` (reads the
json at boot), `shape_def(id)`, `shape_ids()`, and `pick_shape(id)`: the first call sets `home_shape`
and `home_terrain`, every later call returns false — the choice is final (PRD 4.2). `def_of()` overlays
the chosen shape's seed and display name on `home_grassland` only; every other island is the catalogue
row unchanged. `start_new()` no longer relies on WorldUI's terrain sheet: after `CharacterCreation.done`
it opens `IslandPick`, and on `picked` it calls `pick_shape`, builds the home island, calls
`finish_creation()` and saves. Old `WorldUI.show_terrain` is left in place as the fallback for a pending
creation with no layer up.

**Save (`save_game.gd`, `save_sanitizer.gd`).** `home.shape` is written next to `home.terrain` and
restored on load. Schema stays 4. An old save has no row → `home_shape` is `""` → `def_of` returns the
stock row (seed 17, legacy core) and the picker is never shown again because a survivor exists. Re-saving
an old save adds `"shape": ""`, which keeps it on the same island.

**The screen (`game/scripts/ui/island_pick.gd`).** A CanvasLayer at layer 62 over character creation.
Reference layout (docs/reference/durango-domain-tamed-island-select.webp): gold "GET YOUR OWN TAMED
ISLAND!" heading, "Select the desired terrain of your Tamed Island." subtitle, one card per shape with
a **real top-down map**, a gold frame + SELECTED tick on the choice, and a centred footer with
"! Terrain selection is final." and SELECT AND MOVE. Every card and the button are at least 64 px
(measured: `ui_min_px=64` at both 1600x900 and 844x390). The maps are rendered from
`IslandShape.make` at res 81 with the home generator settings — sea, shallows, beach, height-shaded land
in the shape's accent and the generated river drawn in — so a shape added to the json gets a correct
preview, not a placeholder. While open the layer joins the `character_creation` group so WorldUI does not
re-open the old terrain sheet under it, and `picked` fires once.

**Lab (`game/scripts/dev/islandpick_lab.gd` + `scenes/dev/islandpick_lab.tscn`).** Opens the real pick
over a bare host, measures the live controls, saves shots, then proves permanence through the World API
and a real save/load (seed compared on the built runtime) and loads `fixtures/save_v0.json` to check the
old-save path. Prints one line:

`[islandpick] RESULT shapes=5 previews_shown=5 pick_persists=1 final_warning=1 old_save_ok=1 ui_min_px=64`

## Shots looked at

- `/tmp/islandpick_shots/pick_1600x900.png`, `pick_selected_1600x900.png`, `previews.png`
- `/tmp/islandpick_shots2/pick_844x390.png`, `pick_selected_844x390.png` (landscape phone)
Verdicts (one line each) are in `.dsc/IMAGES.md`. The early screenshots were broken (HFlowContainer
wrapped the warning one glyph per line, cards clipped their text); the final layout uses HBox rows,
anchored preview/text blocks and hides the blurb on the landscape phone.

## Round 2 and round 3 (orchestrator review)

- **Harbour landing after the pick.** `World.complete_pick()` is the path the screen's SELECT AND MOVE
  takes: it applies the pick, builds the island, seats the survivor on `IslandRuntime.arrival_point()`,
  finishes creation, saves, and raises the existing `WorldUI._show_arrival` layer. The old terrain sheet's
  behaviour (harbour landing + arrival screen) is preserved instead of dropping the player at the origin.
- **`home.shape` is handled by `SaveSanitizer` (round 3).** `SHAPE["home"]` now lists `shape: ""`, so the
  existing shape pass erases an array/number/null/object row; `clean()` then drops any string that is not
  in a five-id allowlist read from `data/world/island_shapes.json` by `SaveSanitizer.shape_ids()` (no
  autoload needed, so tests and non-World callers work). What reaches `SaveGame._apply` is therefore always
  a catalogue id or no row at all. `_apply` keeps its `World.has_shape` check as a second line of defence.
  Old saves have no row and are untouched; a save whose row is dropped leaves `home_shape` `""`, builds
  the stock seed-17 island, and a survivor that does not exist yet can still make the first pick.
- **All five shapes build for real.** t_islandpick no longer stops at forest: each of the five ids goes
  through `complete_pick` → `IslandRuntime`, asserting its own landmass seed, a harbour site on the coast,
  a dry camp, an arrival on the harbour approach strip, `spawn_ok` at both points, and a walkable
  camp → arrival path.
- **Confirm debounce.** `IslandPick._confirm` sets `_confirmed` and disables every card and the button
  before emitting `picked`; a double tap emits once. `World` only proceeds when `pick_shape` succeeds and
  calls `failed()` (which re-arms the screen) on a refusal.
- **Merge.** `git merge claude/mmo-overhaul` is *not* done here: the orchestrator has said the integration
  gate combines the branches, so this branch keeps only ISLANDPICK-owned changes. No merge artefacts,
  index tricks or wiki files are committed; the untracked `docs/reference/durango0-wiki/` in this worktree
  comes from the earlier sync attempts and is left untouched for the orchestrator to delete.
- **Visuals deferred by the owner** (`HEADLESS_ONLY`): the pick lab was not re-run this round. Stage 2 of the
  gate reports `VERIFY HEADLESS-ONLY: visual lab deferred by owner`.

### Gate and scope

`bash .../dsc/verify_job.sh islandpick` → `VERIFY PASS`: `t_islandpick` (no SCRIPT ERROR), `t_islandgen`,
`t_save`, `t_harbour`, smoke, report and the scope check. Stage 2 reports
`VERIFY HEADLESS-ONLY: visual lab deferred by owner`.

`game/scripts/core/save_sanitizer.gd` changed this round (the review required `home.shape` to be part of the
trust boundary), so its path was added to the `SCOPE` alternation in `docs/orchestration/dsc/gates/job_islandpick.conf`
(`game/scripts/core/(save_game|world|save_sanitizer)\.gd`) and in the installed copy the runner uses.
Nothing else in the gate was touched.

## Assumptions## Assumptions

- `# ASSUMPTION`: the five shape names/seeds are picked to match the five old terrain rows; the docs give
  five shapes but no names or seeds. The accent colours are the grassland palette's own tones.
- `# ASSUMPTION`: the pick keeps setting `home_terrain` (the old terrain row) as well as the seed, so
  scatter density stays meaningful per shape; the reference's "terrain" reads as the landmass.
- The reference's "Select and move" becomes SELECT AND MOVE (the landing sequence after the pick is the
  existing harbour arrival).

## What the integrator needs

- `game/scripts/core/save_sanitizer.gd` changed this round (the review required `home.shape` to be part of
  the trust boundary) and is not in the task's SCOPE regex: widen `job_islandpick.conf`'s `SCOPE` to
  `game/scripts/core/(save_game|world|save_sanitizer)\.gd` or the scope step fails on a correct change.
- Nothing outside the task's SCOPE regex was touched except `game/tests/t_islandpick.gd`,
  `game/scripts/dev/islandpick_lab.gd`, `game/scenes/dev/islandpick_lab.tscn`, the two save files and the
  new data json — all inside it.
- `World.def_of()` now returns a duplicate for home when a shape is held; any code that mutates
  `World.island_def` expecting the catalogue row should be checked (current callers only read it).
- A pick made in-game replaces the old free-standing terrain panel; the panel code in `world_ui.gd` can
  be deleted once the integrator is happy that no boot path needs it.
