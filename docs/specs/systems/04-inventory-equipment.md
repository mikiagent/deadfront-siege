# INV | Inventory, storage, equipment and salvage vault

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** LVL-02, HOME-03, ECO-02, BUILD-03. **Dependencies:** FND, MAT, CHR.

**Source:** `docs/game-design/06-inventory-equipment-and-storage.md`, `docs/game-design/05-material-level-traits-and-loot.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
A player bulk-locks rare material lots, crafts using an expressly selected unlocked lot, sends non-perishable supplies in a boat, and cannot equip a purchased level-50 sword on a level-5 worker.

## 2. Confirmed direction and non-goals
Item ownership and lot signatures must persist; strict individual equip gate for high-level items regardless of acquisition; 100%-refund vault is salvage-only rather than regular bank; inventory supports select/lock/drop/destroy.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
Inventory{id,owner_ref,slot_limit,mass_limit,entries}; Stack{item_id,quantity,signature,lock_state,revision}; Equipment{human_id,socket,item_id}; Reservation{command_id,inventory_id,item_id,quantity,expires_tick}; Vault{owner_home_id,kind:SALVAGE_ONLY}; Content identifiers distinct from item instance IDs.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
`transfer` checks selected lot signature, slot and mass capacity, zone and owner permission, then all-or-nothing moves quantity with originating unique item trace. `equip` verifies own human level; `lock` prohibits auto-consumption but not authorized deliberate unlock. Split creates new child lot instance with same trait roll origin lineage; merge only on canonical signature+definition+freshness-state equivalence. Every move across bag/box/world/boat mutates one ownership reference.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
PROPOSED mass load = sum(qty_i * unit_mass_kg_i), capacity check load + incoming <= max. Stack key K=canonical(def_id, level, roll_signature, freshness_bucket, preservation_state, owner_bound, durability_class). Never average freshness. If two locked stacks merge, locked flag remains true. Bag example 30kg capacity, 22kg held, 9kg new -> reject rather than overflow into nowhere.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Capacity 30, current 22, attempt to add 9 rejects and leaves item at origin. Two Resilient ribs of different origin but same inherited trait magnitude may stack only if approved exact-equivalence provenance strategy can preserve both origins; else remain separate. Level-49 wearer rejects level-50 armor; level-50 wearer succeeds. Vault returns only dismantled materials, not crew or dinosaur inventory.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Concurrent trade and crafting attempts on same item permit one winner; bags cannot lose locked items on mass-batch default destroy. Equipment moves should preserve item id even across deaths/raids; transfer of occupied storage structure prohibited until inventory is emptied. Locked food can rot without becoming fresh or unowned.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Approve slot/mass thresholds, selected-lot UX, exact lot aggregation/provenance compression, lock-protected spoil behavior and legacy save migrations. Do not confuse armor-tier design chapter 06 with complete inventory schema.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
