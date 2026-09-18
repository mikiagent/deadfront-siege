# Cursor M9a — creature plates, tile pathfinding, combat AI

Finished the M9a WIP (`ca198fc`): fixed AI state thrashing that blocked acceptance prints, staged the hunt_lab demo/screenshot, and closed the report.

## What shipped (WIP + this finish)

- `game/scripts/ui/creature_plates.gd` + `status_glyph.gd`
  - CanvasLayer plates: `Lv. N Species`, relation colours, pack `×N`, 160×14 HP bar with green→amber→red fill and a white recent-damage chunk, status glyphs with countdown rings, combat floaters, loot plates `Loot · Species`.
- `game/scripts/world/tile_path.gd` (`TilePath`) on `IslandRuntime.pathing`
  - `AStarGrid2D` over land tiles; grass/sand/slope weights; buildings + tree/rock blockers; string-pulled paths; `[path] len=N` in labs.
- `game/data/creatures/ai.json` + reworked `CreatureBrain`
  - Roam / alert / approach (pack flank ±60°) / attack / retreat / flee / disengage / night sleep; `[ai] <species> <state>` on change.
- `Creature` tile follow + separation + smooth yaw; Label3D only with debug overlay; grey death tint; combat float signal.
- `Corpse` no red box: death pose + grey tint, Kenney `box-open` loot marker, pre-rolled butcher loot, `InventoryUI.show_storage` with Take all (≥64 px) and `needs knife` greying.
- `hunt_lab` spawns a raptor pack + protoceratops herd and scripts the acceptance sequence.

## Fixes in this finish pass

- Alert loop: `_scan()` no longer refreshed `alert_left` every frame; `on_aggro` / pack propagate no longer downgrade retreat/flee/approach back to alert (damage was also calling `on_aggro` after `note_damage`).
- Hunt lab timing so approach / flank / flee / retreat all print before quit; shot delay 3.2 s with a late hit so the white HP chunk is in frame.

## Acceptance evidence

- Screenshot: `docs/orchestration/reports/m9a-creature-ui.png` — multiple `Lv. N Species` plates, health bars, status glyph `B`, damaged plate with recent chunk / floater `-18`.
- Headless `--lab=hunt_lab` prints:
  - `[ai] velociraptor approach`
  - `[ai] pack flank ±60`
  - `[ai] protoceratops flee`
  - `[ai] velociraptor retreat`
  - `[path] len=N`
- Headless `--lab=island_lab`: `creatures=24 spawn_rejected=0`.
- `./tools/smoke.sh --no-import` → `SMOKE PASS`.

## Assumptions

- Corpse lifetime 90 s on the ground (`# ASSUMPTION:` in `corpse.gd`).
- Corpses are not saved (expire in-world only).

## Notes

- Meshy credits spent: 0.
- Did not edit `game/project.godot`, `game/shell/`, `tools/`, or `game/assets/`.
- Next agent: M9b can build on plates + tile pathing; corpse loot panel is ready for tame-downed / butcher flows.
