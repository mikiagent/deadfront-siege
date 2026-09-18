# Cursor milestone M8a — tap-to-play: walk by tapping, auto-gather with a ring

The owner does not want a screen full of buttons. On a phone the whole game should be
played by tapping the world: tap ground to walk there, tap a tree to chop it, tap an
animal to hunt it. Buttons appear only when they mean something right now.

## Read first
- `docs/orchestration/prompts/addendum-mobile.md` (input only through actions; the `tap` action + `Game.pointer` is the one screen-position exception)
- `game/scripts/player/player.gd` (`_tap_world`, `_begin_gather`, `_on_arrived`, `_finish_gather`, `nav_to`)
- `game/scripts/ui/touch_controls.gd` (`BUTTONS`, `blocks_screen_point`), `game/scripts/ui/virtual_joystick.gd`
- `game/scripts/world/harvest_node.gd`, `game/data/nature_manifest.json` (`harvest` ranges per family)
- `game/scripts/combat/hunt.gd` (hunt already auto-attacks once started)
- Claude's commit bc0413f: `IslandRuntime.spawn_ok`, creature roam now snaps to the navmesh. Do not undo it.

## Tasks

1. **Tap the ground to walk.** In `Player._tap_world`, when the ray hits the terrain
   (`StaticBody3D` named `Floor*` or any collider that is not an interactable), call
   `nav_to(NavigationServer3D.map_get_closest_point(map, hit.position))`, cancel any
   gather/butcher, and drop a **ground marker**: a small flat ring mesh (0.6 m, unshaded,
   player colour) at the target that fades out over 0.5 s. Reaching the point clears it.
   **Hold to walk**: if the finger stays down on the ground for more than 0.25 s, keep
   re-targeting to the finger's ground point every 0.15 s while it drags (use the `tap`
   action's pressed/released state plus `Game.pointer`; do not read touch events in the
   player). Keyboard `move_*` still works and cancels navigation (already does).

2. **Auto-gather with a pool.** `HarvestNode` gets `pool_max` and `pool` (units left).
   `# ASSUMPTION:` default `pool_max = 30` for trees and rocks, 12 for bushes and plants;
   read `pool` from `nature_manifest.json` per family when present, else the default.
   Tapping a node walks there once; on arrival the player gathers **one unit at a time**:
   every `gather_seconds` roll one stack of `yield_min..yield_max` (existing `roll_yield`)
   until the pool is empty, the inventory refuses, the tool breaks, or the player taps
   elsewhere / moves / gets hit. Each unit prints the existing `[item] +N id {...}` line
   plus `(pool 12/30)`. Fatigue per unit = current per-gather fatigue / 4
   (`# ASSUMPTION:`). Trees fall to a log only when the pool hits 0; the pool refills
   over `regen_seconds` (linear). Save the pool with the M6 `harvested` snapshot.

3. **The ring.** A `GatherRing` Control (new script under `scripts/ui/`) is shown
   above the active node, positioned each frame with `camera.unproject_position(node.global_position + Vector3(0, top_of_node + 0.3, 0))`.
   Draw it with `_draw()`: a 72 px circle, thick outer arc = **items gathered from this
   node this session / pool_max** (fills as the pile grows), a thin inner arc = progress
   of the current unit (0→1 each `gather_seconds`), and the count `12/30` in the middle.
   Item icon from `icons_manifest.json` if one exists for the yield id, else the yield
   name. Fades out 0.6 s after gathering stops. Only one ring at a time.

4. **Contextual buttons instead of the cluster.** Rewrite `TouchControls` so buttons
   belong to contexts and only the active context's buttons are visible:
   - `explore` (default): top bar only — BAG, CRAFT, MAP (unchanged positions).
   - `hunt` (a hunt target exists): ATK is not needed (hunt auto-attacks) — show ROLL,
     tactic 1, tactic 2, HOLD in the right thumb zone.
   - `hurt` overlay: AID appears while a bleed status is active.
   - `mounted`: USE (dismount).
   - `place` (build placer active): handled in M8b; leave a `set_context(&"place")` hook.
   The player (or Hunt) calls `TouchControls.set_context(...)` on state changes. The
   **joystick is hidden by default**; F4 / the `touch_toggle` action cycles
   `tap-only → tap+joystick → hidden`. `blocks_screen_point` must reflect what is visible.
   Everything stays bound to InputMap actions.

5. **Tap targets.** Creatures, harvest nodes, corpses and buildings must be easy to hit
   with a thumb: give `HarvestNode` a collision box at least 1.0 × 1.6 × 1.0 m (trees
   1.4 wide), and pad the creature capsule query by using
   `intersect_ray` first and, on a miss, a 0.6 m sphere `intersect_shape` at the hit
   point to pick the nearest interactable.

6. **Lab hook.** In `island_lab` headless mode, after the nav bake, script the player:
   tap the nearest tree (call the same method the tap handler calls), wait, and let it
   auto-gather 5 units, printing `[item] gather 5/30 done` then quit. Windowed
   `--shot=` should catch the ring.

## Acceptance
- `-- --touch` with the mouse: tapping ground walks (marker visible), holding drags the
  walk target, tapping a tree walks then chops unit after unit with the ring above it
  showing count and per-unit sweep; tapping elsewhere stops it; no joystick, no button
  cluster in explore context; ROLL/1/2/HOLD appear only during a hunt.
- Keyboard still works (WASD cancels navigation, E still interacts).
- Headless `--lab=island_lab` prints five `[item] +… (pool …)` lines and `[item] gather 5/30 done`.
- Screenshot `docs/orchestration/reports/m8a-gather-ring.png` (island_lab, `--shot=`) shows the ring above a tree.
- `tools/smoke.sh` → `SMOKE PASS`. Report `docs/orchestration/reports/cursor-M8a-tap-to-play.md`.
  Commit as `M8a: tap to walk, auto-gather ring, contextual touch buttons`.
- Do not edit `game/project.godot`, `tools/`, or anything under `game/assets/`.
