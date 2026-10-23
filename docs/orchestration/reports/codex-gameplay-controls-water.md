# Codex report: gameplay controls, camera framing, and water traversal

Date: 2026-10-23

## Shipped

- Added persistent Sprint and Combat toggles to the bottom-right HUD. Both use the existing `HexButton` control and meet the 64 px mobile tap-target requirement.
- Sprint mode works alongside the existing held InputMap action and unlatches when Energy is empty or sprinting is blocked.
- Combat mode targets the nearest living wild animal in the existing attack-seek radius; tapping it again disengages.
- The camera now biases its focus toward a selected gather resource, tame target, or combat target while retaining the survivor in frame.
- Added depth-aware water traversal. Shallow water wades at 60% movement speed; water at least 0.75 m deep swims at 45% movement speed.
- Swimming drains 6 Energy per second. At zero Energy, continued swimming deals 5 Health per second.
- Water taps retain their true water destination and deep water no longer triggers the old shoreline pushback.

## Assumptions

- Camera selection bias is 35%, capped at 6 m.
- The swim threshold is 0.75 m; wade/swim speed multipliers are 0.60/0.45.
- Swimming drains 6 Energy/s and exhausted swimming damages 5 Health/s.

These constants are marked `ASSUMPTION` at their code definitions.

## Verification

- `game/tests/t_controls.gd`: PASS, including camera bias, toggle placement and state, combat targeting, and radial-control stability.
- `game/tests/t_water.gd`: PASS, including real shallow/deep island locations, movement multipliers, swim transition, and exhausted-swimming damage.
- `tools/smoke.sh`: `SMOKE PASS`.
- Headless `--smoke --touch`: PASS with tap-only controls enabled.
- Native 844x390 screenshot confirmed the toggles are readable and unobstructed at a phone landscape size.

## Known limitation / next agent

- The survivor uses the existing locomotion animation while buoyant because the current player clip contract has no swim clip. A dedicated swim clip should be added as an art/animation milestone rather than synthesized in gameplay code.
- The Compatibility-renderer screenshot reproduced the known global shader-variable limit when native Godot is forced to `gl_compatibility`. The normal desktop renderer is Forward+; the web containment test passes with zero instance-uniform users.

## Failed work and credits

- No requested behavior remains failed.
- Meshy credits spent: 0.
