# Codex report: resource click camera focus

## Shipped

- Clicking a resource now shifts the follow camera toward that resource as soon as its gather radial opens.
- Closing the radial removes that camera interest, so framing returns to the survivor.
- Gather progress still uses `active_node()`, which only becomes active after the player picks an option.

## Root cause

`Player.camera_interest()` asked `GatherRadial.active_node()` for the selected resource. That method intentionally returns `null` until a gather option is chosen. A plain resource click opened the radial but gave the camera no interest node, leaving the measured shift at 0.00 m.

`GatherRadial.focus_node()` now exposes the open radial's anchor for camera framing without changing gather-cycle state.

## Verification

- Added a regression path that clicks a real `HarvestNode` through `PlayerInput.interact_tap_target()`.
- Before the fix, the radial opened and the camera shift measured 0.00 m.
- After the fix, the same click shifts the focus 3.50 m toward the resource without centring it.
- `game/tests/t_controls.gd`: PASS
- `game/tests/t_ui.gd`: PASS
- `tools/smoke.sh`: SMOKE PASS
- Direct `--smoke --touch`: PASS

## Failures and credits

- No requested behavior remains failed.
- Meshy credits spent: 0.

## Next agent

- Use `focus_node()` for selection framing and `active_node()` for a chosen, running gather option.
