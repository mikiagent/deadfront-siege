# ISL | Protected homes, world categories and resets

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** HOME-01..04, WORLD-01/02, PVP-01, LOG-01. **Dependencies:** FND, INV, BLD, LOG.

**Source:** `docs/game-design/03-private-islands-and-upgrade-migration.md`, `docs/game-design/04-world-biomes-and-travel.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
Player confirms purchase of a new protected island. The old structures dismantle into a salvage-only vault, human/dino residents and regular stores migrate separately, and the old island is abandoned. No raider can target either safe home.

## 2. Confirmed direction and non-goals
Exactly one permanently safe private home at a time, upgrades buy a *new larger island* rather than expanding old. Paid migration automatically dismantles buildings and returns 100% of invested building materials into salvage-only vault. Highest home nodes ~50–55; level-60+ material expeditions remain outside. Unstable islands reset and salvage installed bases into vault; refund percent OPEN. Only constructed PvPvE settlements are player-raid targets.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
Island{id,kind:HOME|PVE|PVPVE|UNSTABLE,seed,node_level_band,revision,owner_id}; MigrationIntent{id,old_home,new_home,quoted_cost,confirmed,phase}; SalvageVault{owner_id,material_lots}; ResetJob{island_id,reset_epoch,evacuation_plan,salvage_ledger}. Reset behavior requires explicit ordering with raids.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Purchase quote snapshots exact material and currency costs; confirmation moves cost into escrow; phase 1 reserve/serialize all actors+inventories; phase 2 dismantle buildings to unique constituent material lots; phase 3 relocate residents/storage via non-vault migration; phase 4 atomically change home pointer, abandon old island, publish new map. On interrupted save replay uses migration_id to avoid refund twice. Reset works similarly but without assumed 100% rate.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
Paid home migration salvage returned_by_lot = sum(physically committed input quantities by lot), 100%; losses are zero for completed material contributions only. Candidate purchase cost C(t)=1000 * t^2 currency minor units, t = destination tier > origin tier. Candidate unstable salvage q_refund=floor(q_installed*r), 0<=r<=1; r intentionally OPEN. Never return uncommitted blueprint fantasy costs.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Paid upgrade: three buildings contributed 8 stone, 5 treated plank, 2 scute plate; salvage receives exactly 8/5/2 with original signatures, even if construction traits are negative. Another try with same migration_id changes neither vault nor purchased island. A level-60 wild node is outside max home tier. Unstable 10-plank base with candidate r=0.5 returns 5 planks only IF owner approves r.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
No raid permission can be inferred from home island level or rich buildings. Partial worksite refunds, resident evacuation, tied-up workers and storage ownership need explicit semantics. If purchase fails before commitment, no home pointer/cost changes; distinct attacks and world resets cannot double-process one structure.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
**Blocking source conflict WORLD-02:** unstable reset always recovers installed building materials versus newer prefab text suggesting lost structures; choose exact refund r and live occupant handling. Price/size/node tables and timing OPEN.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
