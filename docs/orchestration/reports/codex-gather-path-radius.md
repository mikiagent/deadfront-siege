# Codex report: quick-gather path radius

## Shipped

- HANDS and Space now search for the nearest live resource within 12 m.
- A resource outside the normal 2.6 m interaction reach becomes a gather target and starts the existing navigation route. Gathering begins after the survivor reaches it.
- Resources beyond 12 m are ignored. The HUD reports `No resource within 12 m` when no valid node is nearby.
- The ordinary E or gamepad interaction search remains at 2.6 m. The server-side gather reach is unchanged.

## Assumption

- The PRDs do not set a quick-gather search radius. This change uses 12 m because it covers nearby on-screen resources without selecting nodes across the island. The value is `PlayerInput.QUICK_GATHER_RADIUS`.

## Verification

- Added a red regression case with a branch pile 8 m away and another 14 m away.
- The test now proves HANDS selects the 8 m node, starts navigation toward its closest navigable point, and rejects nodes outside 12 m.
- `game/tests/t_controls.gd`: PASS
- `tools/smoke.sh`: SMOKE PASS
- Direct `--smoke --touch`: PASS

## Failures and credits

- No requested behavior remains failed.
- Meshy credits spent: 0.

## Next agent

- Keep the 2.6 m interaction and server validation distances separate from the 12 m quick-gather search radius.
