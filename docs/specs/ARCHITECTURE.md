# DEADFRONT | Clean-build Godot technical architecture

**Status:** PROPOSED engineering contract v0.1. Client shipping target remains an owner decision; use Godot 4.7.1 typed GDScript with distinct headless simulation and view scene layers.

## Project layout (new build only)

```text
game/
  project.godot
  autoload/      WorldSession.gd, CommandBus.gd, DataCatalog.gd, SaveGateway.gd
  domain/
    identity/    Ids.gd, AggregateStore.gd, Transaction.gd
    inventory/   ItemStack.gd, MaterialLot.gd, Storage.gd
    progression/ Human.gd, Experience.gd
    economy/     Recipe.gd, WorkOrder.gd, OrderBook.gd
    world/       Island.gd, Region.gd, ResetJob.gd
    fauna/       Species.gd, Dinosaur.gd, Genetics.gd
    combat/      Attack.gd, Armor.gd, PhysicalContact.gd
    crew/        Expedition.gd, Seat.gd, PlatformSaddle.gd
    frontier/    Permission.gd, Raid.gd, CaptiveCase.gd
  application/   commands/, handlers/, events/, projections/
  presentation/  actors/, camera/, screens/, widgets/, touch/
  data/          definitions/, balance/, schemas/
  tests/         unit/, property/, integration/, visual/, saves/
  assets/        characters/, creatures/, biome/, structures/, icons/
```

Do not create one god-script owning everything. Domain functions take immutable input state and return next state and domain events. Rendering/UI subscribes to projections and may never mutate owned state directly.

## Shared identity contract

All persistent entities have typed prefixes and collision-resistant UUIDs or monotonic scoped IDs. Example `human:<uuid>`, `dino:<uuid>`, `item:<uuid>`, `structure:<uuid>`, `island:<uuid>`, `shipment:<uuid>`, `captive:<uuid>`; one globally stable identifier is never recycled. `LocationRef` is a tagged union `InventorySlot/EquipmentSocket/WorldPlacement/Transit/Prison/Consumed`; it has one authoritative value. Actors additionally store world/tribe ownership without pretending ownership and scene presence are the same.

**Aggregate owners:** `ActorAggregate` owns vitals and equipment occupancy; `InventoryAggregate` owns stacks/reservations; `StructureAggregate` owns place/pack state; `WorldAggregate` owns island generation and home immunities; `CustodyAggregate` owns ransom deadline and original/prospective claim rights; `EconomyAggregate` owns escrow and ledgers. Mutations across aggregates use one all-or-nothing application transaction.

## Pure command handler protocol

```text
handle(command_id, actor_id, ruleset_version, payload, world_revision):
  if command_id in applied_command_ledger: return stored_result
  validate actor exists, alive/available, location and permissions
  validate current revision / expected aggregate generations
  compute one ordered list of events in memory
  verify nonnegative inventories, capacities and invariants
  commit snapshot delta + command receipt atomically
  publish events to projections/UI
  return receipt with exact affected entity IDs and quantities
```

**Replay rule:** duplicate command ID produces the original result, not a second item/XP grant. Concurrent reservations use compare-and-swap/revision lock for items. For single-player, implement synchronous deterministic atomic commit with transaction journal and crash recovery. Server multiplayer later replaces trust boundary without changing event semantics.

## Common field types and units

- `WorldTick`: integer 1/30 seconds (proposal); timers using world motion in ticks, `elapsed_seconds = ticks/30`.
- `UtcEpochSeconds`: integer from trusted clock, only for real-world periods such as 72-hour ransom or food spoilage; protect clock rollback with monotonic persisted max-observed time where possible.
- `MassKg`, `DistanceM`, `VelocityMps`, `AngleRad`, `EnergyPoints`, `DurabilityPoints`, `ExperiencePoints`, `CurrencyMinorUnits`: distinct documented units; do not store disguised percentages as integer points.
- `FixedPointPercent`: signed integer basis points, 10000 = 100%; use where exact reproducibility matters (craft multipliers, transaction taxes). `round_half_up` for positive final values unless individual spec overrides.
- `RuleSetRef`: semantic version + SHA-256 of balance definitions. Store with saves and transaction receipts; never reinterpret historical crafted traits under new tables without migration.

## Versioned content IDs

Definitions use stable `def_id` strings, not display names. Item instances reference definition ID + immutable roll and source record. Rename by display strings only. Recipe graph definition stores ingredient predicates, fixed costs, stages, outputs, station and skill gates. Creature definitions separate species from unique instance and inherited IVs; no dinosaur in a saddle is an inventory item.

## Seeded randomness

Non-presentation random calls use a deterministic PCG32-like generator with documented seed and counter. A loot/offspring command derives its own seed from authoritative world seed + stable source ID + command ID (via stable hash, never language `hash()`). Consume draw indices in listed order; fixtures record seed, draw sequence and exact outputs. **Engine PRNG details are candidate engineering choice, not already-approved inherited RNG.**

## Save contract / migration

Snapshot root: `save_schema_version`, `ruleset_version`, `simulation_tick`, `last_trusted_utc`, `tribes`, `humans`, `dinos`, `islands`, `inventories`, `structures`, `reservations`, `shipments`, `captive_cases`, `transactions`. Each map keyed by stable ID; validate all foreign keys. Save via temporary file + flush/fsync where supported + atomic replace, retain previous safe copy. On load verify checksum and schema, apply migrator chain `n -> n+1`, reject unknown future schema without corrupting old file. Staged home migration/packaging first writes a durable intent journal, then commits once; crash either resumes idempotently or rolls back.

## State machines with side effects

Every movement of goods or custody transition emits idempotent events. Multiple views may reference one entity but never create copies. For example `ShipDeparture` transfers goods from `DockReserved` to `ShipmentManifest`; only after a committed `DEPARTED_HOMEBOUND` transition may attack authorization ignore the shipment.

## Client/server staging

**M0–M7:** local single-player authoritative simulation; prepared UUIDs, explicit faction IDs, all commands validated as if potentially remote. **Future online frontier:** authoritative server solely decides permissions, inventories, generation RNG, economy and raid results. Do not ship player-PvP/currency exchange/captive ransom as merely client-trusted features. Include threat model: client clock edits, inventory replay, tampered economy payloads, target spoofing, duplicate shipping, disconnect during combat.

## Render and platform

Scene graphs own collision, animation, camera, audio, effects, UI; they report intended actions to application handlers. Orthographic/isometric camera is a proposal consistent with existing inspiration. Implement mouse/keyboard and touch through InputMap actions, with safe areas and accessible targets. Current implementation has desktop Chrome production gate, but final fresh-build release target must be chosen. Do not confuse historic native mobile ambition with a proven current export requirement.

## Required quality gates

Headless domain fixtures, save-roundtrip and migration tests, deterministic command replay and fuzz tests, player-reachable visual screen at agreed resolution(s), actual input soak, profile/memory target and export smoke. Tests are never replaced by logging success strings alone.
