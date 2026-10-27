# Actual current-code baseline, not a redesign

**Audited:** GitHub `main` commit `923657262cd335fefee9126df61dd0fff4b93321`. This is a *static code inspection*, not a fresh runtime or deployment verification. Before implementation compare `origin/main` and inspect a live build.

## Godot entry and service ownership

- `game/project.godot` boots via `res://shell/boot.tscn`, with autoloads `ShellLoader`, `InputSetup`, `Data`, `Game`, `World`, and `TouchControls`.
- `game/scripts/core/data.gd` loads data catalogs from `game/data/...`: items, recipes, creature JSON, butchering, worlds, nature, statuses, skills. Add definitions to these paths rather than introducing a second parallel catalog.
- `game/scripts/core/world.gd` stores loaded island, `home_grassland` routing, `pioneer_level/xp`, T-stones, unstable harvest snapshots, player name, craft/build progression, `cargo_home` inventory, home building cache. World routes are not a finished multishipment NPC boat system.
- `game/scripts/core/main.gd` binds existing Player, UI overlays and labs. `game/scripts/ui/hunt_hud.gd` and `game/scripts/ui/inventory_ui.gd` own established interaction surfaces. Do not replace all screens to fit a new mockup.

## Explicit existing implementation

| Feature | Present implementation | Source/evidence | Not yet the new future design |
|---|---|---|---|
| Inventory and equipment | `Inventory` fixed slots, item stacks, equipped def-id slots, quick food, transfers, partial acceptance | `game/scripts/items/inventory.gd`, `item_stack.gd` | No complete item-instance-ID/trait-lineage ledger or owner-approved new personal level equip restriction |
| Crafting/stations | `Crafting._plan`, slot category inputs, `build_output`, material-level contribution; stationed crafting, recipe data | `crafting.gd`, `station_craft.gd`, `game/data/recipes.json` | Output currently copies **only primary `attributes`**; no general signed dual-lot fusion |
| Level/skills | Pioneer level/XP in `World`, `SkillState` and occupation data, item material levels, creature training/genetics | `world.gd`, `skills/skill_state.gd`, `data/skills`, `creature_genetics.gd` | No finalized multigenerational human roster, inherited D/M+I/P/S unified attributes or level-60 personally qualified PvPvE |
| Animal capture/riding | Species definitions, AI/brains, `PetRecord`/bonded animals, `Player.mount` and `dismount`, `_mounted_move`, actual model mount socket | `creature.gd`, `pets/`, `player/player.gd:1594+` | No two-human crew platform saddle; no broad engineering-weight/footprint system |
| Combat/siege | Existing attack/status/counter logic, projectiles and placed `FieldCatapult.fire(player, victim)` | `combat/`, `world/field_catapult.gd` | Catapult expects a `Player`, uses player inventory for `stone_shot`/`toxin_pot`; no shared mounted ammo box, auto sentries or genuine multiplayer |
| Building/grid | Place/move kits on tiles, rotation, `PlacedBuilding`, grid reservations, basket storage and bedding state | `build_placer.gd`, `build_grid.gd`, `placed_building.gd` | No full manufactured prefab UUID/creator/material signature, staged supplied-ingredient worksites or connected room ambience |
| World/reset/logistics | `World.travel`, `cargo_warp` (2 T-stone fee constant), instability and claimed plots, cargo-home storage | `core/world.gd`, `island_runtime.gd`, `harbour.gd` | No physical guarded homebound boat shipments; safe-home **paid replacement + 100% special vault** is future design |
| Food/rest | Food definitions/buffs, vitals/exhaustion, sleeping structures, offline field catch-up | `items/food.gd`, `combat/vitals.gd`, `placed_building.gd`, `SaveGame` | No per-lot all-location real-time food freshness and rotten transformations; continuous sit/sleep behavior needs approved constants |
| Saves | Snapshot `SaveGame`, ordered `SaveMigrations` 0->1->2->3; records player, pet records, buildings, world and inventory | `core/save_game.gd`, `save_migrations.gd` | No comprehensive transaction journal or new global actor/structure identity schema; avoid rewriting current save outright |
| Tests/labs | Central headless tests and multiple focused labs, scripts for build/import/smoke, web/browser soak | `game/tests/run_all.gd`, `game/scripts/dev/*lab.gd`, `tools/` | No proof new future specs are tested just because old suite exists |

## Current save contract, schema 3

`SaveGame.path` is `user://save_1.json` (bot uses throwaway `user://bot_save.json`). Current `SaveGame.save_now()` writes JSON with `schema`, `player: vitals, statuses, inventory, inventory_extras, position`, `pets`, `ground_snares`, `skills`, `skills_v2`, `home: terrain, buildings, cargo, claims, camp_layout`, progression, island and `unstable` fields, clock and `saved_unix`. `load_now` migrates before restoring scene and fields. Existing save file is currently opened with `FileAccess.WRITE` (not transactional temp/rename); on malformed JSON or unknown schema it starts a new world. **Treat save integrity as the first risky behavior to improve, without silently overwriting a damaged file.**

`SaveMigrations.CURRENT_SCHEMA == 3`: existing `v0 -> v1`, `v1 -> v2`, `v2 -> v3`; older building coordinate conversion happens on restoration. Future additions must use `v3 -> v4`, etc., retaining every old migrator. Test actual v0/v1/v2/v3 payloads and round trips. A new `UUID` on each stack must not be generated afresh on every load or recipe view.

## Specific important details

- `ItemStack.to_dict()` fields: `id` (definition), `count`, `level`, `process_count`, `attributes`, `flags`, `durability`, `max_durability`. `can_merge_with` requires matching def/level/process/durability/attributes/flags.
- `Inventory.add(stack)` mutates supplied stack's `count` and returns leftover count. `transfer_to()` sends accepted units and removes exactly that many from source. Any new transaction wrapper must preserve this behavior for existing calls and tests.
- `PlacedBuilding.pack_up(player)` currently converts a building into an ordinary kit, tries to add stored items, then queues the original free. Because it doesn't explicitly verify returned kit/contents capacity first, adding more complex prefab identity requires deliberate overflow rejection and no-duplication tests.
- `FieldCatapult.fire` rejects invalid range (8m..24m), requires the player near the catapult (<=3m), consumes ammo from player inventory, reloads in 3 seconds and creates `SiegeProjectile`. A new mounted weapon cannot alter this existing flow without comparative tests.
- `CreatureGenetics` currently uses seven combat stats with `IV_MAX=31`, `EV_MAX_PER_STAT=100`, `EV_TOTAL_MAX=300` and serializes both. Do not silently replace these values with the rebuild proposal's illustrative `1..100` range.
- `game/data/creatures/tyrannosaurus.json` currently has `tameable:false`, `capture_tier:0`, empty `tamed_role`, although intended owner design says it should eventually be rideable. This is a deliberate reconciliation ticket, **not an editing shortcut**.
- `World.cargo_warp()` strips the `unstable` flag on accepted cargo and charges T-stones only when an accepted transfer occurs. Do not confuse this existing convenience transfer with future physical boats.
- The current implementation tests include `_test_save_migrations`, `_test_multistack_crafting`, `_test_storage_transfer`, `_test_creature_genetics`, `_test_catapult_recipe_save`, `_test_tyrant_counters` and more in `game/tests/run_all.gd`.

## Verify the actual build before altering any state

These are **static findings from repository sources**, not claims of production deployment state, screenshots or tests freshly passing today. For each subsequent coding ticket, first run the existing import/test/smoke and targeted lab in a working checkout. If a test already fails on `main`, report the baseline failure separately rather than blaming your change.

## Architectural constraints

Large files currently include `player/player.gd`, `world/island_runtime.gd`, `ui/hunt_hud.gd`; avoid piling new features into them. Extract dedicated helpers only after a focused lab protects existing behavior. Do not start a second `WorldSession`, `DataCatalog`, `SaveGateway` or UI shell when comparable stable autoloads already exist.
