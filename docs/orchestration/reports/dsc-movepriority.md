# dsc-movepriority: click-to-move outranks combat

Branch `claude/mmo-movepriority`, cut from `072bcb84` (main integration line). Credits spent: 0. No
art, no sound, no paid generation. Not pushed, not merged.

Owner rules implemented (both dated 2026-10-28):

1. A click/tap on the ground is a **move order** and is always honoured — auto-attack does not pull
   the survivor off her path. Real damage (a creature hit, not a bleed/DoT tick) ends the move after
   the hurt stun and she fights the damage source, else the nearest hostile.
2. A ground click also **cancels a pending interact pathfind** — walking to a tent to sleep and then
   clicking elsewhere drops the sleep intent and the path, so she never sleeps. Same for gather, and
   for a station recipe that was queued but not started.

No balance numbers changed.

## What landed

- `game/scripts/player/player.gd` — new `Player.move_order: bool` (the state flag for an active move
  order). `receive_creature_hit` now clears the order and the route, then turns on the attacker if it
  is non-pet, alive and within `PlayerActions.ATTACK_SEEK_RANGE` (28 m), otherwise on
  `actions.nearest_creature(28.0, false)`. Bleed and other status ticks never reach this function
  (`_on_vitals_damaged` returns before the flinch), so they leave a walk alone — this needed no change.
  The self-defence block below it now skips a biter that is already the hunt target (one log line, no
  double `hunt.start`).
- `game/scripts/player/player_sim.gd` — `nav_to`'s owner keeps `move_order` in step; `clear_nav()` and
  arrival clear it. New `cancel_errand()` drops a pending sleep (`_sleep_pending`). The keys/stick
  path in `_walk` cancels the same errands, so a stick nudge abandons a walk-to-sleep too.
  Two engine-level fixes the test host needed, both defensible on their own: `closest_nav_point`
  returns the query point when the navigation map has no region (an unbaked floor or a bare test
  host used to be sent to the origin), and `_nav_dir` ends a route once she is inside the route's own
  arrival tolerance instead of chasing a further waypoint.
- `game/scripts/player/player_input.gd` — `_walk_to_tile` is the only place that sets
  `move_order = true`, and only for ground taps. It first calls `sim.cancel_errand()`,
  `actions.cancel_work()` and `station_craft.abandon_errand()`, clears selection and stops the hunt.
  An enemy tap still selects (out of combat) or retargets (in combat) and does not touch the move
  order, per the §11 in-combat tap rule.
- `game/scripts/combat/hunt.gd` — `_process`, `_auto_attack` and `swing_now` return early while
  `player.move_order`. That is what stops the auto-chase and the in-reach `clear_nav()` from pulling
  her off a tap route.
- `game/scripts/items/station_craft.gd` — new `abandon_errand()`: drops a queued recipe session
  (refunding as `cancel_and_refund` does) but never touches a craft that has already started burning.
- `game/tests/t_movepriority.gd` (new, 344 lines, `t_targetui.gd`-shaped, 240 s watchdog) — five case
  groups: baseline auto-attack with no order; ground click with an enemy in reach (walks, 0 swings, no
  chase, enemy tap and bleed tick do not cancel); damage breaks the move (attacker within reach /
  no live source → nearest hostile); ground click cancels tent sleep, gather node and workbench craft.
- Docs: `docs/current/controls.md` — new "Move orders and interacting" section.
  `docs/design/ui-redesign-spec.md` §11 — two dated `[owner 2026-10-28]` bullets.

## Verification

- `game/tests/t_movepriority.gd` → `[t_movepriority] PASS` headless.
- Broken-code check: reverting the `hunt.gd` guard and the `move_order = true` line produces 12
  failing asserts; reverting only the key-path errand cancel fails the key/hold assert. The test bites.
- Gate: `verify_job.sh movepriority 1` → `VERIFY STAGE 1 PASS` (the test plus the related suite
  `t_controls t_targetui t_combat t_player t_tactical t_roll`, `tools/smoke.sh` → `SMOKE PASS`, and the
  scope check). Stage 2 (windowed `creature_lab`) is deferred by the gate's `HEADLESS_ONLY` marker;
  `creature_lab` itself was not changed.

## What failed / did not ship

Nothing was dropped. The touch path is the same code (`_walk_to_tile` is shared by the touch layer),
but only the desktop headless gate was run here — a `--touch` pass in the windowed build is still
owed before this ships to mobile.

## What the next agent needs

- `Player.move_order` is the single source of truth for "she is following a tap route". Anything new
  that auto-moves or auto-attacks her should check it (`PlayerSim.clear_nav()` and arrival clear it;
  only `_walk_to_tile` sets it).
- The errand cancel is split by owner on purpose: `PlayerSim.cancel_errand()` (sleep),
  `PlayerActions.cancel_work()` (gather/butcher/tame), `StationCraft.abandon_errand()` (queued
  recipe). A future errand type (mount, tame-drive, build) must add its cancel to `_walk_to_tile`'s
  batch or it will survive a move order.
- A **started** station craft is deliberately left running through a move order. If the owner wants
  the click to abort it, `StationCraft.cancel_and_refund()` is the call; do not change
  `abandon_errand()`.
- `verify_job.sh movepriority 1` is the cheap gate for anything touching these files.
