# Codex harbour fix

## Shipped

- Travel now loads the destination harbour and places the survivor at its resolved arrival point instead of trusting the island JSON hint.
- Harbour moves update the runtime marker, publish the resolved arrival back to `World.islands`, move the home cargo basket, and release/re-reserve its grid cell.
- Harbour collision is now a thin deck slab plus a separate shed box, so the pier deck remains walkable while harbour tapping still has collision coverage.
- `HarbourSite.check()` validates every row-0 cell as dry land and every row-1 cell as land or wet sand, rejecting river mud. `build_placer.gd` was not edited.
- `t_harbour.gd` covers moved-pose reload, arrival drift, persistence, basket placement/reservation, and collider count. `t_structart.gd` now checks the new collider contract.

## Repro and verification

Before the fix, the existing command passed its old coverage with `[t_harbour] PASS islands=15`; the added moved-pose probe then went red with:

`[t_harbour] FAIL moved harbour pose survives reload`

`[t_harbour] FAIL moved harbour repro is away from the old json point`

`[t_harbour] FAIL count=16`

After the fix:

- `Godot --headless --path game --script res://tests/t_harbour.gd` -> `[t_harbour] PASS islands=15`
- `Godot --headless --path game --script res://tests/t_structart.gd` -> `[t_structart] PASS`
- `Godot --headless --path game --script res://tests/run_all.gd` -> `[tests] PASS`
- `tools/smoke.sh --no-import` -> `SMOKE PASS`
- `git diff --check` passes.

The required windowed harbour shot command was attempted with 1600x900 and `gl_compatibility`, but this environment exited 70 without creating the PNG, so no visual claim is made.

## Notes for the next agent

The exact review pose `(61,-7), rot 3` is rejected on this checkout as `needs_shore` once the required row validation is applied. The regression uses the legal coast pose nearest that review target, while the placement rule itself covers all row-0/row-1 cells.

Suggested, uncommitted `build_placer.gd` text improvement: map `dock_needs_water` to `"The dock must face deep water"` and `needs_shore` to `"The whole harbour base must be on dry shore"` instead of the raw fallback text. Per task instructions, that file was left untouched.

Meshy credits spent: 0.
