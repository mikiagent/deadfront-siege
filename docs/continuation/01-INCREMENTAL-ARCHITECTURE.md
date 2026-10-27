# Incremental architecture | Enhance rather than replace

**Starting point:** in-place Godot `game/` at `main` code; existing `ShellLoader`, `InputSetup`, `Data`, `Game`, `World` autoloads and UI/scenes are retained. These additions are *suggested seams*, not a command to add everything before gameplay features exist.

## General rule: preserve -> test -> extract -> extend -> migrate -> verify

1. Establish observed main behavior with existing test + live screenshot.
2. Write a targeted red test for an explicitly approved new rule.
3. Introduce a small reusable subsystem adapter, maintaining existing API signatures until all existing callers are migrated.
4. Add optional fields in current objects, not a new parallel actor/item/world model.
5. Make migration data-only and one-way with compatibility checks before enabling new behavior.
6. Reach the feature from existing interaction/menu, test old and new, and protect production deployments with exact build stamp gates.

## Where new code belongs

| Domain extension | Keep these as owners | Suggested additive seam and call path |
|---|---|---|
| Signed trait provenance / fusion | `ItemStack`, `Inventory`, `Crafting`, `Data` and `recipes.json` | `items/material_trait_def.gd`, `items/trait_resolver.gd` pure functions; enrich `ItemStack.attributes` or an optional explicit `trait_lineage` dictionary; `Crafting.build_output(rec, primary, level, consumed)` uses all actual consumed inputs only for recipes opting into fusion |
| Personal human progression / tribes | `Player`, `SkillState`, `World`, `SaveGame` | `tribe/tribe_roster.gd`, `tribe/human_record.gd`, player control points to current human; preserve legacy single-survivor save representation and create roster entry by migration |
| Worker production | `World`, placed workstations, `Inventory`, `Crafting` | `tribe/worker_order.gd`, `tribe/job_scheduler.gd`; real records, tool/food inputs, field availability, offline eligibility validated by command; monitoring stand remains a physical building |
| Real-time food freshness | `ItemStack`, `Food`, `Inventory`, `SaveGame` | `items/food_freshness.gd`; explicit optional `food_state` with timestamps; settle on transfer/consume/craft/load and handle old stacks conservatively |
| Modular worksite/prefab lifecycle | `BuildGrid`, `BuildPlacer`, `PlacedBuilding`, `Crafting` | `world/worksite.gd`, `world/structure_record.gd`, `world/structure_packaging.gd`; stable identity persisted within existing building row; original kit placement remains supported during migration |
| New combat/armor/mass | `Hunt`, `CombatCounters`, `CreatureAttack`, `Creature`, `PetRecord` | `combat/attack_mode.gd`, `combat/hit_zone_resolver.gd`, `creatures/load_profile.gd`; adapter from existing `blunt/pierce/cut` to new DI/DP/DS/MI/MP/MS tags without global enum rename |
| Animal platform saddle | `Player.mount/dismount/_mounted_move`, `CreatureView.mount_socket`, `PetRecord` | `pets/platform_saddle_record.gd`, `pets/crew_seat_controller.gd`, `combat/mounted_siege.gd` with compatible specimen and real actor references; do not teleport/create phantom tribe people |
| Siege and automatic guns | `FieldCatapult`, `SiegeProjectile`, `Inventory`, `World` | `combat/siege_fire_service.gd` shared ballistic/fire validation while keeping `FieldCatapult.fire(Player, Creature, bool)` callable; `world/automatic_turret.gd` with physical sensors and ammo |
| Home upgrade + unstable reset | `World`, `SaveGame`, `BuildGrid`, `PlacedBuilding` | `world/home_migration.gd`, `world/reset_salvage.gd` behind confirmed rules; do not reinterpret current `World.cargo_warp` as a boat |
| Physical boats and commerce | `World.travel`, `World.cargo_home`, `Harbour`, `Inventory` | `world/cargo_shipment.gd` and a lightweight transfer ledger; physical loading/launching validated before homebound protection; markets later require server authority |
| Custody/PvPvE | `World`, existing combat/status/animal records, save | `frontier/captive_case.gd`, `frontier/raid_permission.gd` only after server and fairness design. No client-only competitive PvP described as live |
| UI / visual | `HuntHud`, `InventoryUI`, `CraftUI`, `Game`, hex controls | Add existing-style panels/actions, not a second interface framework; mouse and touch must call same gameplay action |

## Compatibility adapter pattern

A replacement engine component should **not** be handed to the old script all at once. Example `Crafting.build_output` already accepts an optional `consumed` array but uses only primary attrs. Add a `TraitResolver.resolve(rec, consumed, primary)` which:
- Preserves current primary inheritance for recipes without an approved `fusion_rule_id`.
- Uses all actual reserved/consumed lot records only when the recipe opts in.
- Produces output attributes/optional provenance compatible with `ItemStack.to_dict/from_dict`.
- Never changes unrelated food/cooking, level scaling, old station behavior or stack equality without tests.
- Keeps deterministic source ordering and trait identities across saves, split stacks, transfers and future structure use.

## Avoid a global ID rewrite

Existing `ItemStack` identity is def ID + stack attrs/flags/count. **Do not casually add a unique per-instance ID to every stack and then change `can_merge_with`**, which would stop legacy merging or duplicate persistence. Add a stable provenance ID for feature-bearing material *lots* when needed and preserve merge equivalence. For unique finished prefabs, durable human records, cargo and captive cases, add IDs in those particular objects with `SaveMigrations` fallback. Ownership remains consistent through existing `Inventory` operations until a specific transaction boundary proves insufficient.

## Respect real engine/data constraints

- `Data` is the catalog loader. Verify new item IDs, recipe output IDs, material sources in `nature_manifest` and `butchering`, station IDs, and compatibility with existing `ItemDef.from_dict` before loading.
- `Crafting` categories are live behaviors. Avoid turning a category predicate into a literal fake item ID to make a speculative recipe compile.
- A positive or negative material trait that affects a station/worksite must come from real consumed/installed lots, never paper blueprint defaults.
- `CreatureGenetics` currently has seven IV stats with existing caps and save representation. New Dexterity/Might is a **future mapping/migration design** requiring explicit adapter and approval. Do not throw away old IV/EV/capture progress.
- `FieldCatapult` has Player-only `fire`, 8-24m range and one player inventory; future universal turret source abstraction must continue honoring its legacy tests.
- `World` owns actual islands and reset timer. Safe-home paid replacement, workers, live human squads and boat immunity add new lifecycle logic, not another World singleton.

## Rollout protocol

Feature-specific flags allowed only for truly reversible behavior, with default matching current player experience. A data migration should be idempotent and preserve older known fields. Save schema changes require increasing `SaveMigrations.CURRENT_SCHEMA` exactly once and adding the next migration function in order; never change historical semantics of old schema versions. Progressive UI behind data readiness; avoid menus referring to non-existent humans, structures, ammo magazines or markets.

## Coding-agent discretion

Claude may choose typed helper class boundaries and internal optimizations; Claude may **not** silently choose irreversible-loss policy, market economy, item level gate exceptions, attribute transfer equations, multiplayer authority or final crafting balance. Respect confirmed user direction and label exact numeric proposals for approval.
