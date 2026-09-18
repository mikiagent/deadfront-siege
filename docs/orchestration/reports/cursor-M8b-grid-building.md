# Cursor M8b — grid building from the bag

M8b is now wired end-to-end: placeable kits from the bag/craft path, tile-snapped ghost placement with grid visualization, grid occupancy/save integration, and a headless lab proving accepted/rejected placement flows.

## What shipped
- `game/scripts/world/build_grid.gd` (new)
  - Added 1 m `BuildGrid` with `tile_of`, `tile_centre`, `cells_for`, `can_place`, `occupy`, `release`, and `neighbours`.
  - Placement reasons now return `overlap`, `water`, `slope`, `too_far`, `reserved`.
  - Added footprint rotation and fence/gate neighbour-based auto-alignment.
- `game/scripts/world/build_placer.gd`
  - Rebuilt placement around `BuildGrid` tile snaps and 90-degree rotation steps.
  - Ghost now uses manifest GLBs (fallback box), valid/invalid translucent override, 9x9 conforming grid overlay, footprint tile highlights, and a `Label3D` (`WxD`, plus invalid reason).
  - Confirm now prints `[build] placed <kind> at (x,z) rot=<deg>` and invalid confirms print `[build] rejected <reason>`.
- `game/scripts/player/player.gd`
  - M8a ground tap was retargeted to tile centres through `BuildGrid.tile_of/tile_centre`, then snapped to nav.
  - Ground marker replaced with a persistent 1x1 tile highlight quad (40% alpha) that clears on arrival/interrupt.
  - Hold-to-walk now retargets by tile.
  - Placement controls added: `R` rotate, `Enter` place, `Esc` cancel; tap while placing moves ghost.
- `game/scripts/ui/inventory_ui.gd`, `game/scripts/ui/craft_ui.gd`, `game/scripts/ui/touch_controls.gd`, `game/scripts/core/input_setup.gd`, `game/scripts/ui/world_ui.gd`
  - Inventory selected placeable stacks now show a 64 px `Place` button with footprint text (`Place WxD`) and begin placement via the same flow as crafting.
  - `place` touch context now has `Rotate`, `Place`, `Cancel` buttons (all >= 64 px).
  - Craft placement path now calls `TouchControls.set_context(&"place")`.
  - Pause (`Esc`) is ignored while actively placing so `Esc` consistently cancels placement.
- `game/scripts/world/prop_visuals.gd` (new) + building scripts
  - Moved manifest model attach/collision/foundation logic into shared helper.
  - `PlacedBuilding`, `CraftStation`, `Bonfire`, `TamingPen` now use manifest visuals with collision from `model_sizes_m` (AABB fallback) and a dirt foundation slab (`footprint x 0.15 m`).
  - Taming pen visual uses a fortified-fence ring with one gate segment (fallback mesh if models are missing).
- `game/scripts/world/island_runtime.gd`, `game/scripts/world/harvest_node.gd`
  - Island runtime now creates one `BuildGrid`, reserves harbour/camp prop cells, and places camp buildables through grid transforms.
  - Harvest node placement snaps to tile centres via `BuildGrid`.
- `game/scripts/core/save_game.gd`
  - Save schema bumped to `2`.
  - Buildings now persist as `{kind, cell:[x,z], rot, ...}`.
  - Schema 1 rows are migrated by snapping legacy `x,z` to tile cells.
  - On load, occupancy is rebuilt before/while restoring placed buildings.
- `game/data/items.json`, `game/scripts/items/item_def.gd`, `game/scripts/items/item_stack.gd`
  - Placeable kits now carry `footprint` data sourced from manifest footprint values.
  - Item tooltip now includes footprint text for placeables.
- Lab + screenshot
  - Added `game/scripts/dev/build_lab.gd` and `game/scenes/dev/build_lab.tscn`.
  - Added screenshot output: `docs/orchestration/reports/m8b-build-grid.png`.

## Acceptance evidence
- Headless `--lab=build_lab` prints required placements/rejections/restore:
  - `[build] placed tent at (-7,5) rot=0`
  - `[build] placed basket at (-3,5) rot=0`
  - `[build] placed fence at (-7,9) rot=0`
  - `[build] placed fence at (-5,9) rot=0`
  - `[build] placed fence at (-3,9) rot=0` (third fence snaps into line)
  - `[build] placed gate at (-1,9) rot=0`
  - `[build] rejected overlap`
  - `[build] rejected water`
  - `[build] restored 6`
- Screenshot captured: `docs/orchestration/reports/m8b-build-grid.png`.
- Smoke check:
  - `./tools/smoke.sh --no-import`
  - Result: `SMOKE PASS`.

## Notes
- Meshy credits spent: 0.
- No edits were made to `game/project.godot`, `tools/`, or files under `game/assets/`.
