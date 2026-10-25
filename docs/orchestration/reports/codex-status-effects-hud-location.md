# Codex — player status HUD location

## Shipped

- Moved the player's status-effect row from the minimap to eight pixels beneath the top-left vitals panel.
- Kept the existing compact-landscape spacing that places the row after visible pet-command buttons, avoiding overlap while keeping it inside the vitals block.
- Added a regression in `game/tests/t_controls.gd` that activates Wet and asserts the rendered status row is directly below and horizontally contained by the vitals panel.

## Diagnosis

The desktop and portrait path in `HuntHud._draw()` explicitly derived the status origin from `_minimap.position`. Only compact landscape already replaced that origin with the vitals panel. Before the fix the regression measured vitals at `(8, 6)`, size `(300, 90)`, and the status row at `(1430, 238)`; after the fix the status row is at `(16, 104)`.

## Verification

- `Godot --headless --path game --script res://tests/t_controls.gd` — PASS
- `Godot --headless --path game --resolution 844x390 --script res://tests/t_controls.gd -- --touch` — PASS
- `Godot --headless --path game --script res://tests/t_ui.gd` — PASS
- `tools/smoke.sh` — `SMOKE PASS`
- `git diff --check` — PASS

## Failed / deferred

- Nothing.

## Credits

- Meshy credits spent: 0.

## Next agent

The status location is now guarded by rendered HUD geometry. Preserve the invariant that player statuses stay directly beneath the vitals panel; target-creature statuses remain on creature/target plates.
