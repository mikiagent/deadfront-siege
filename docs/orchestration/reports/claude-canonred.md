# CANONRED: red standalone tests on canon

Branch `claude/mmo-canonred` off `origin/claude/mmo-overhaul`. No credits spent.

## Gate

`tools/all_tests.sh` runs every `game/tests/t_*.gd` headless (after an import) and prints one
`PASS t_x (Ns)` / `FAIL t_x rc=N ... first FAIL line` per test and `TOTAL n pass=p fail=f logs=<dir>`;
exit 0 only when all pass. Env: `GODOT_PATH`, `WRAP` (e.g. the gslot wrapper), `JOBS` (default 4),
`TEST_TIMEOUT` (600 s), `LOGS`. Args: test names for a subset. `t_waves_render` is skipped: it is
t_waves' windowed child, not standalone; t_waves now opens it at `--position 6000,3000`.

## Failures and their kind

Real regressions (code fixed):
- **t_server_domain / t_srvdom, journal replay**: crafted non-stacking items got a wall-clock
  `created_at` from `ItemStack.stamp_identity` inside `Crafting.run_plan`, so a replay differed by
  seconds. `CharacterState.commit(inv, origin, seq, now)` now stamps new rows with the op's server
  time; `act.craft` passes it. The test's failure message now shows both sides.
- **t_claimfix, 844x390 placer overlaps HANDS**: `HudLayout.placer_anchor`'s grid started at x=90,
  where the left hex is always off-screen, and its 56 px step jumped past the only free spot. The grid
  now starts and ends where the row sits flush with the room.
- **t_uimarket, harness T-stones**: `MarketHarness.earn` deposited one bag row per order; with
  ONEGATHER each pass is its own one-unit row, so it now fills an order row by row (dev harness only).

Tests out of date with owner-approved changes (assertion updated):
- **t_items "Rock stone rolls"**: ONEGATHER, every roll is exactly one unit.
- **t_light / t_lighting "rain layer missing"**: WEATHER round 2 added `RainSplash`; the test finds `Rain` by name.
- **t_biome foliage ALBEDO line**: SKYSHADOWS' `* v_sky` (canon fixed it the same day; took canon's version on merge).
- **t_fieldhud MENU badge**: TRIBE M1 dock recruits badge MENU (a starter recruit waits); the
  notice-count section empties the dock and restores it after.
- **t_savefix ten-minute walk**: FULLFATIGUE doubles fatigue on an empty stomach (5.2/min vs 2.6);
  the walk is now measured on a normal stomach, like the other held factors (rain, level gap, clock).
- **t_buildsys "the ramp keeps rot 1"** and **t_playerturn island tap walk-away** (red only after the
  TERRAINSMOOTH merge): its new scatter put a harvest node on the module west of the build pad and beside
  the fixed walk-away goal (the tap opened the node). Fixtures now pick a pad whose ramp module is free
  and a goal tile with no harvest node within 2.5 m. Placement and tap rules unchanged.

## Notes for the next agent

- Timing tests were not flaky in these runs. t_waves timed out once under the full 5-slot load: its windowed child stalled for 600 s and outlived the parent. The child now runs under a 90 s perl alarm; three solo reruns pass in 10 s.
- Untracked `.uid` files from the import (`skyshadows_lab.gd.uid`, `t_playervisible.gd.uid`) were left out.
