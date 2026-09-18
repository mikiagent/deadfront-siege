# Cursor milestone M9a — creature nameplates, health bars, combat AI on tiles

The owner wants enemies to read at a glance ("Lv. 3 Compsognathus" with a health bar
under it) and to fight and move like animals, not like capsules sliding to a point.
Do this after M8b and M5b: the world is a 1 m tile grid (`BuildGrid.tile_of`,
`tile_centre`) and `IslandRuntime.spawn_ok(pos, false)` says whether a tile is walkable.

## Read first
- `game/scripts/creatures/creature.gd`, `creature_anim.gd`, `brains/*.gd`, `combat/hunt.gd`, `combat/creature_attack.gd`, `combat/telegraph.gd`
- `game/data/creatures/*.json` (`tier`, `archetype`, `move_speed_mps`, attack clips), `docs/prd/dinosaur-roster-and-3d-pipeline.md` archetype table
- `game/scripts/world/build_grid.gd` (M8b), `island_runtime.gd::spawn_ok`
- **Never add, rename or reorder autoloads and never edit `project.godot`**: the downloader shell (`game/shell/`) bakes the autoload list; a new autoload needs a new app build. Put shared services under an existing autoload (`World.pathing`, `Game.creature_ui`) or on the island runtime.

## Tasks

1. **Nameplate overlay.** One `CanvasLayer` (`scripts/ui/creature_plates.gd`, created by
   `Game` when the first creature spawns) draws a plate for every living creature within
   45 m of the player, positioned with `camera.unproject_position(top of capsule + 0.3)`.
   Layout (canvas units, scale 1.0 at 15 m → 0.7 at 45 m):
   - Line 1: `Lv. 3 Compsognathus` — level = `def.tier` + the island ring offset the
     creature spawned in (store `level` on the creature at spawn), display name from
     the species JSON. Colour by relation: red predator/hostile, amber neutral
     herbivore, green pet, grey sleeping. Pack size pip (`×4`) when in a pack.
   - Line 2: health bar 160×14 px, dark backing, fill green → amber → red by fraction,
     a white "recent damage" chunk that shrinks over 0.6 s, numeric `hp/max` only when
     the debug overlay is on.
   - Line 3: status icons (bleed, venom, knockdown, groggy, fracture, sleeping) as small
     coloured glyphs with a countdown ring; use `icons_manifest.json` glyphs if any.
   Visibility: always for the hunt target and any creature damaged or aggroed in the
   last 5 s; otherwise fade in when tapped or within 10 m, out after 3 s. The old debug
   `Label3D` shows only with the debug overlay. Player keeps the HUD bar.

2. **Tile pathfinding.** `scripts/world/tile_path.gd` (class `TilePath`) owned by the
   island runtime (`World.runtime.pathing`): an `AStarGrid2D` over the island tiles,
   `region = land bounds`, cell 1 m, `diagonal_mode = ONLY_IF_NO_OBSTACLES`,
   `jumping_enabled = false`, weights: grass 1, sand 1.4, slope 2; solid tiles from
   `spawn_ok(pos, false) == false`, buildings (`BuildGrid` occupancy, updated on
   place/pack-up) and tree/rock harvest nodes. `path(from, to, max_len) -> PackedVector3Array`
   of tile centres with `surface_y`, string-pulled so straight runs are one segment.
   Creatures use it instead of `NavigationAgent3D` (`Creature.move_to` requests a path,
   follows waypoints, re-plans every 0.5 s or when blocked). The player's tap-to-walk
   and gather/butcher approach use the same path (keep NavigationAgent only for labs
   without an island). Creatures get separation steering (0.6 × capsule radius) so a
   pack does not stack on one tile, and turn smoothly (lerp yaw, 10 rad/s).

3. **Combat AI.** Rework `CreatureBrain` into a small behaviour set driven by archetype
   (data in `game/data/creatures/ai.json`, create it):
   - **Roam**: wander to a random walkable tile within 6 tiles every 3–6 s, pause to
     idle; herbivores keep within 8 tiles of the herd centre.
   - **Alert**: face the player, play `alert`, 0.6 s; herd/pack alert propagates.
   - **Approach**: path to a tile at `attack_range − 0.3` from the target; strafing pack
     members (`raptor_pack`) take flank slots at ±60° and 2.5 m, one "leader" attacks
     first; a shared pack cooldown staggers hits (no two bites in the same 0.4 s).
   - **Attack**: primary by default; heavy when the target has not moved for 1.5 s or
     after three primaries; respect the telegraph windup; stop moving during the swing.
   - **Reposition / retreat**: predators back off 3 tiles after taking >30 % HP in 2 s,
     then re-approach; herbivores flee toward the herd centre and away from the player
     (8 tiles), fight back only when cornered (`cornered` = no flee tile found).
   - **Disengage**: lose the target after 12 s beyond 1.5 × perception; walk home to
     the spawn tile.
   - **Night**: unchanged (herbivores sleep, raptors +50 % perception).
   Print `[ai] <species> <state>` on state change (debug only).

4. **Hit feedback.** On damage: plate flashes, the "recent damage" chunk animates, a
   small floating number rises from the plate (white normal, red bleed tick, green
   heal), and the creature does a 0.1 s red tint (existing `set_status_fx`).

5. **Lab.** `hunt_lab` headless: spawn a raptor pack + a protoceratops herd; script the
   player to tap a raptor; print at least: `[ai] velociraptor approach`, a flank slot
   line `[ai] pack flank ±60`, `[ai] protoceratops flee`, `[ai] velociraptor retreat`,
   and a `[path] len=N` line from TilePath. Windowed `--shot=` catches the plates.

## Acceptance
- Screenshot `docs/orchestration/reports/m9a-creature-ui.png`: three creatures with
  `Lv. N Species` plates, health bars, one with a status glyph, one damaged (white chunk).
- Headless `--lab=hunt_lab` prints the `[ai]` and `[path]` lines above; no creature ever
  stands in water or inside a building; `--lab=island_lab` still prints `creatures=24 spawn_rejected=0`.
- `tools/smoke.sh` → `SMOKE PASS`. Report `docs/orchestration/reports/cursor-M9a-creature-ui-and-ai.md`.
  Commit as `M9a: creature plates, tile pathfinding, combat AI`.
- Do not edit `game/project.godot`, `game/shell/`, `tools/`, or anything under `game/assets/`.
