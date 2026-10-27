# FOD | Food, freshness, meal effects and preservation

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** FOOD-01/02, UX-01. **Dependencies:** FND, INV, MAT.

**Source:** `docs/game-design/07-crafting-processing-and-food.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
An uncooked meat lot starts with 100% freshness, sits six hours in a bag and reaches 50%, then spends 12 more hours in a cooler operating at half decay rate before rotting to useful inedible scrap.

## 2. Confirmed direction and non-goals
All perishable food spoils in real time online/offline, in every location including protected home; freshness is NOT gear durability; at zero becomes rotten material useful for compost/bait, not deleted. Preservation extends shelf life; signed ingredient traits affect finite Energy/buffs, never permanent IV.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
FoodState{lot_id,freshness_bp,last_settled_utc,base_life_seconds,container_rate_bp,trait_rate_bp,preservation_profile_id}; MealEffect{effect_id,stat,amplitude_bp,duration_seconds,origin_lot_ids}; LocationHistory{since_utc,storage_id,climate_id}. Store rates alongside past segment records or settle before transfer.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Before any eat, craft, transfer, save inspect or container rate change: settle decay for nonnegative real seconds at previous environment, update timestamp, then reclassify rotten atomically at freshness zero. Split preserves total units and freshness; cooking explicitly consumes input and creates new item with its own age, without refreshing other lots. Preserve signed bad-food traits and safety warnings.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE from source chapter: F_next=max(0,F_old-round_half_up(10000*elapsed_seconds*env_rate*storage_rate*trait_rate/L)), using rates as fractions and F as bp. Raw meat L=43200s (12h), cooked L=86400 (24h), smoked L=259200 (72h), dried L=432000 (120h), salt preserved L=604800 (168h) are all PROPOSED. World-clock authority and complete plant table OPEN.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Fresh raw meat 10000bp, standard bag for 21600s -> 5000bp; moving to 0.5-rate cold box settles at old rate then after 43200s more -> 0 and becomes rotten once. Smoked meat after 259200s in normal ambient -> rotten. Saving twice at same time makes no extra decay or duplicate rotten item.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Clock rollback uses max(last_settled_utc,current_utc), never increases freshness; local offline client clock can still be cheated until server authority. Perishables in boat/dinosaur/feed caches keep decaying. Negative trait does not become a new permanent IV penalty. Rotten-to-compost conversion cannot reverse spoilage or generate edible food.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Approve shelf lives, food buff curves, container bonus bounds, spoil transforms per item, raw safety effects, location climate rates and real-time authority.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
