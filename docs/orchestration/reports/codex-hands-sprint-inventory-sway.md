# Codex report: HANDS gather, sprint routing, inventory sheet, and prop sway

## Shipped

- HANDS now gathers the nearest live resource in reach. A one-option resource begins gathering immediately; a multi-option resource opens its gather radial.
- Added the `gather_nearest` InputMap action on Space.
- Moved keyboard roll to Q because Space is now reserved for gather.
- Ground-click navigation now uses the same Sprint state as direct movement. With Sprint off it walks; with Sprint toggled or held it sprints.
- Added a 64 px BAG hex above HANDS. It opens the inventory and HANDS hides while the inventory is open.
- Changed inventory from a full-screen modal to a right-side sheet. It uses 68% of the viewport, capped at 1120 px, and leaves the live game visible and unobstructed on the left.
- Removed sway from plant and bush card roles. Trees and grasses remain the only swaying resource-card roles, so branch piles remain still.
- Added regression coverage for the bindings, nearest-resource choice, Sprint routing, BAG placement and opening, sheet geometry, and sway policy.

## Root causes

- `PlayerSim._walk()` treated any active navigation route as running, bypassing the Sprint toggle.
- A short HANDS tap called the old held-tool cycle behavior instead of a gather action.
- Branch piles shared the `plant` card role, whose sway amplitude was non-zero. Bushes also retained sway despite the requested trees-and-grass-only policy.
- Inventory used a full-screen panel and backdrop, so no game view remained visible.

## Assumptions

- Q is the replacement keyboard binding for roll after Space becomes gather.
- The inventory sheet uses 68% of the viewport (minimum 520 px when available, maximum 1120 px) to keep all three existing inventory columns usable.

## Verification

- `game/tests/t_controls.gd`: PASS
- `game/tests/t_card2d.gd`: PASS (contains a pre-existing non-fatal format warning at line 241)
- `game/tests/t_player.gd`: PASS
- `game/tests/t_ui.gd`: PASS
- `game/tests/t_switch2d.gd`: PASS
- `tools/smoke.sh`: `SMOKE PASS`
- Direct `--smoke --touch`: PASS
- Native 844 x 390 captures checked for BAG/HANDS placement and right-side inventory geometry.

The older aggregate `game/tests/run_all.gd` still logs pre-existing global-class and `process_checks.gd` errors while incorrectly printing PASS. Its new Space/Q assertions are present, but this aggregate runner should not be treated as a clean gate until that unrelated harness issue is repaired.

## Failures / credits

- No requested feature remains failed.
- Meshy credits spent: 0.

## Next agent

- Preserve the `gather_nearest` action name and the HANDS/BAG signals when changing input or HUD code.
- If another roll key is preferred, change the Q assumption in `input_setup.gd` and its assertion in `run_all.gd` together.
