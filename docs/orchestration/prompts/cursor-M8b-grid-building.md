# Cursor milestone M8b — grid building: place from the bag, snap to the grid

Building must be trivial: open the bag, tap a kit, tap Place, tap where it goes. Nothing
may end up crooked, floating, sunk, or overlapping. Do this after M8a (it uses the tap
semantics and `TouchControls.set_context(&"place")`).

## Read first
- `game/scripts/world/build_placer.gd` (1 m `round()` snap, box ghost, overlap query), `placed_building.gd`, `craft_station.gd`, `taming_pen.gd`, `bonfire.gd`
- `game/data/props_manifest.json` → `buildings` (`model`, `footprint: [w, d]` in 1 m cells) and `model_sizes_m`
- `game/data/items.json` kit items (`place_as`), `game/scripts/ui/inventory_ui.gd`, `craft_ui.gd::_place_kind`
- `game/scripts/world/island_runtime.gd::surface_y`, `spawn_ok`, `_attach_prop`
- `game/scripts/core/save_game.gd` + `World` home building save (M6 schema 1)

## Tasks

1. **BuildGrid.** New `scripts/world/build_grid.gd` (`class_name BuildGrid`), one per
   island runtime. Cell = 1 m, keyed `Vector2i(floor(x), floor(z))`. API:
   `cells_for(kind, cell, rot) -> Array[Vector2i]` from the manifest footprint rotated
   in 90° steps, `can_place(kind, cell, rot) -> String` ("" or a reason: `overlap`,
   `water`, `slope`, `too_far`, `reserved`), `occupy(node, cells)`, `release(node)`,
   `neighbours(cell)`. Rules: every cell must satisfy `IslandRuntime.spawn_ok(pos, false)`
   (dry land); the height spread across the footprint corners must be ≤ 0.6 m (`slope`);
   the harbour and the camp props reserve their cells; the player must be within 8 m
   (`too_far`). Fences and gates occupy their cells like anything else.

2. **Snap and level.** The placed node sits at the footprint centre, `y = mean of the
   corner heights`, rotation = the 90° step; a flat **foundation** slab
   (footprint size × 0.15 m, dirt colour, lit) hides the gap between a sloped terrain and
   the flat base. Fences auto-connect: when placing a fence next to another fence the
   rotation snaps to continue the line, and a `gate` is a fence cell that keeps its own
   model.

3. **Ghost = real model.** The ghost is the Kenney GLB from the manifest (fallback box)
   with a green (valid) or red (invalid) translucent override material, plus a **grid
   overlay**: 9×9 one-metre cells drawn around the ghost (an `ImmediateMesh` line grid
   conforming to `surface_y`, unshaded, 35 % alpha) so the snap is visible. Cells the
   footprint would occupy are highlighted; invalid ones red.

4. **From the bag.** In `InventoryUI`, selecting a stack whose item has `place_as`
   shows a 64 px **Place** button. It hides the bag, calls `placer.begin(kind)` and
   `TouchControls.set_context(&"place")`. Placement HUD (touch layer `place` context,
   all ≥ 64 px): **Rotate**, **Place**, **Cancel**. Tapping the ground moves the ghost
   (snapped); Place confirms if valid (consumes the kit, occupies cells, prints
   `[build] placed tent at (x,z) rot=90`), invalid taps print `[build] rejected <reason>`.
   `CraftUI::_place_kind` uses the same path. Desktop: R rotates, Enter places, Esc cancels.

5. **Real models for placed buildings.** `PlacedBuilding`, `CraftStation`, `Bonfire`
   and `TamingPen` use the manifest GLB (existing `_attach_prop` logic, move it into a
   shared helper) with a collision box from `model_sizes_m` (or the GLB AABB). Keep the
   coloured box as the fallback when the GLB is missing.

6. **Save.** Buildings persist as `{kind, cell:[x,z], rot, contents…}` (bump the save
   `schema` to 2 and migrate schema 1 rows by snapping their `x,z`). On load, rebuild
   the grid occupancy before placing.

7. **Lab** `--lab=build_lab` (headless demo): place tent, basket, three fences in a row
   (the third auto-aligned), a gate, then attempt an overlap and a beach cell, print the
   two `[build] rejected …` lines, save, reload, print `[build] restored 6`. Windowed
   `--shot=` shows the ghost with the grid overlay.

## Acceptance
- On `-- --touch`: bag → kit → Place → tap ground → ghost snaps with visible grid →
  Rotate → Place. Buildings are level, on the ground, never overlapping, fences connect.
- Headless `--lab=build_lab` prints the placements, the two rejections and `[build] restored 6`.
- Screenshot `docs/orchestration/reports/m8b-build-grid.png`.
- `tools/smoke.sh` → `SMOKE PASS`. Report `docs/orchestration/reports/cursor-M8b-grid-building.md`.
  Commit as `M8b: grid building from the bag`.
- Do not edit `game/project.godot`, `tools/`, or anything under `game/assets/`.
