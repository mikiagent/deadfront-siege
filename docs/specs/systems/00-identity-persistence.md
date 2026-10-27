# FND | Identity, transactions, persistence

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** TRIBE-01, HOME-02/03, BUILD-03, PVP-04. **Dependencies:** none.

**Source:** `docs/game-design/03-private-islands-and-upgrade-migration.md`, `docs/game-design/08-blueprints-worksites-and-building.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
Survivor puts two signed bone lots into a laminator, saves and reloads; the output exists exactly once, ingredients remain consumed, and each source ID remains traceable.

## 2. Confirmed direction and non-goals
Each real person, animal and packable building persists individually. Home migration must not duplicate salvage, cargo or people. Shared loaded ammo and captured persons similarly have unique custody.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
Human{id,tribe_id,level,inventory_id,location,control_state}; Dinosaur{id,species_id,owner_id,location}; Item{id,def_id,lot_signature,location,revision}; Structure{id,creator_id,owner_id,placement_or_pack_location,material_contributors}; CommandReceipt{id,status,events,world_revision}; TransactionJournal{command_id,proposed_delta,commit_state}. Exactly one LocationRef per object.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Commands contain actor_id, command_id, expected_revision, ruleset_id, payload. Validate authority and capacities; acquire ownership reservations in stable ID sort order; build all deltas; check conservation; commit journal+snapshot; emit events; cache result by command_id. Crash before commit -> rollback; crash after commit -> replay event projections without reapplying state. A transaction never consumes inputs on validation failure.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
Use a proposed 64-bit nonnegative integer minor-unit quantity type with checked addition. Conservation for item definition d: initial_d + harvested_d + crafted_outputs_d + inbound_d = final_d + consumed_recipe_inputs_d + destroyed_d + outbound_d. Equipment sockets, escrow and shipment inventories count in final_d until transformed. No rounding permitted for discrete counts.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Fixture A: store 5 fiber and 3 stone; recipe costs 2 fiber+1 stone; after 1 successful craft inventory has 3 fiber, 2 stone, 1 output. Replaying command_id yields identical receipt and counts. Fixture B: two agents simultaneously attempt to consume same final stone: at most one succeeds; failed path leaves no fiber spent. Fixture C: a structure packs/unpacks 100 times and retains same id, creator_id and signed traits.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Corrupt/unknown save schema is rejected with preserved backup; references to nonexistent humans fail validation; a dropped actor in one scene is not automatically deleted; never reassign same human ID on death or switching; journal recovery is idempotent.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Approve UUID format, local save path, save rollback depth and explicit reversible failure policy for cross-island migrations; decide authoritative clock before real online systems.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
