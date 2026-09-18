# Cursor M8a — tap to walk, auto-gather ring, contextual touch buttons

Tap-to-play now drives movement and harvesting without a permanent right-side action cluster.

## What shipped
- `game/scripts/player/player.gd`
  - Tap ground now navigates to the nearest navmesh point, cancels gather/butcher, and drops a 0.6 m fading ground ring marker.
  - Hold-to-walk is implemented from InputMap state (`tap`) + `Game.pointer`: after 0.25 s hold, the target retargets every 0.15 s while dragging.
  - Tap selection now does `intersect_ray` first, then a 0.6 m `intersect_shape` sphere fallback to pick nearby interactables.
  - Gather became unit-by-unit auto-gather (continues until depleted/full/broken/interrupted), with per-unit fatigue at 1/4 legacy gather cost (`# ASSUMPTION:`).
  - Touch context updates call `TouchControls.set_context(...)` and `TouchControls.set_hurt_overlay(...)`.
- `game/scripts/world/harvest_node.gd`
  - Added `pool_max`, `pool`, `session_gathered`, save/restore support, and per-unit `consume_unit()`.
  - Default pool assumptions implemented (`# ASSUMPTION:`): trees/rocks 30, bushes/plants 12, overridable from `nature_manifest` (`families.<id>.pool`).
  - Collision box now meets tap-target size floor (1.0 × 1.6 × 1.0 m, trees/rocks 1.4 m wide).
  - Trees now fall only when pool reaches 0, then refill linearly while depleted.
- `game/scripts/ui/gather_ring.gd` (new)
  - New floating ring UI above active gather node (72 px): thick outer arc = session progress, thin inner arc = current unit progress, center count `pool/pool_max`, icon by `icons_manifest` when available.
  - Ring fades out over 0.6 s when gathering stops.
- `game/scripts/ui/touch_controls.gd`
  - Reworked to contextual button sets:
    - `explore`: BAG / CRAFT / MAP
    - `hunt`: ROLL / tactic 1 / tactic 2 / HOLD
    - `mounted`: USE
    - `hurt` overlay: AID while bleed/deep bleed is active
    - `place` hook wired via context id for M8b
  - Joystick visibility cycle on `touch_toggle`/F4: `tap-only -> tap+joystick -> hidden`.
  - `blocks_screen_point(...)` now only blocks visible controls.
- `game/scripts/core/world.gd`
  - Harvest snapshots now save/restore pool state (`pool`, `pool_max`, `session_gathered`) and still read older depleted-only rows.
- `game/scripts/core/game.gd`
  - `Game.pointer` now updates on drag/motion events (screen drag + mouse motion) so hold-to-walk retargeting tracks finger/mouse movement.
- `game/scripts/world/island_runtime.gd`
  - Harvest nodes receive per-family pool max from manifest (or defaults).
- `game/scripts/items/inventory.gd`
  - `wear_gather_tool(...)` now returns `bool` to stop auto-gather immediately when tools break.
- `game/scripts/dev/island_lab.gd`
  - Added lab hook for headless acceptance: taps nearest tree using the player tap path, gathers 5 units, prints completion line, exits.
  - `--shot=` path now stages an active gather so the ring appears in screenshots.

## Acceptance evidence
- Headless lab:
  - `/Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game -- --lab=island_lab`
  - Output contains five `[item] +... (pool .../30)` lines and `[item] gather 5/30 done`.
- Screenshot:
  - `/Applications/Godot_mono.app/Contents/MacOS/Godot --path game -- --lab=island_lab --shot=/Users/milankinzy/Documents/deadfront-siege/docs/orchestration/reports/m8a-gather-ring.png`
  - Saved `docs/orchestration/reports/m8a-gather-ring.png` shows the ring above a tree.
- Smoke:
  - `tools/smoke.sh` -> `SMOKE PASS`.

## Assumptions
- Per-unit gather fatigue uses `legacy gather fatigue / 4` (`1.5 / 4.0`).
- Pool defaults are role-based until explicit `pool` values are provided in `nature_manifest`.

## Credits + handoff
- Meshy credits spent: 0.
- No changes made outside this milestone scope; `game/project.godot`, `tools/`, and `game/assets/` were not edited.
