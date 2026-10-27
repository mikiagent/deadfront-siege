# Codex — minimap footstep fade

## Shipped

- Added deterministic age tracking for map footsteps.
- Footsteps now fade linearly and expire after 30 seconds on both the circular minimap and the full atlas.
- Saved trail rows retain age; legacy `[x, z]` rows still load and receive a finite lifetime.
- Added a regression test covering fade, expiration, age persistence, malformed rows, and legacy rows.

## Assumptions

- The PRDs require black footstep dots but do not specify a lifetime. The implementation uses 30 seconds so the recent route remains useful without permanently filling the map.

## Verification

- `game/tests/t_mapui.gd`: PASS.
- `tools/smoke.sh`: `SMOKE PASS`.
- Native touch boot (`-- --smoke --touch`): PASS, tap-only controls active.
- `tools/test.sh`: exits 0 and reports `[tests] PASS`; it also prints pre-existing global-class and process-check errors unrelated to this change.

## Failed / credits

- Nothing failed in the map regression, smoke, or touch checks.
- Meshy credits spent: 0.

## Next agent

- The lifetime is centralized in `MapFog.TRAIL_LIFETIME_S` if playtesting calls for a shorter or longer breadcrumb window.
