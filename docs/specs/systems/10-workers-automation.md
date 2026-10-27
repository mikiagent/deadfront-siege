# WRK | Human workers, jobs, hauling and monitoring stand

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** WORK-01/02, TRIBE-01, LOG-01/02. **Dependencies:** FND, TRB, INV, CRF, ISL.

**Source:** `docs/design/tribe-lineage-domain-and-labor.md`, `docs/design/2026-10-25-systems-vision-and-open-decisions.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
A named miner travels to a mine, extracts finite ore with an owned pickaxe, stops at 1 durability, hauls ore to a real stockpile if capacity permits, and consumes actual work time and supplies.

## 2. Confirmed direction and non-goals
Worker output depends on actor's real stats, specializations, equipment and task assignments; a monitoring stand controls priorities; AI workers stop using job tools at 1 durability. No autonomous magic goods or phantom humans.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
WorkOrder{id,kind,site_id,actor_id,input_reservations,tool_id,effort_required,progress,last_tick,state}; WorkerSchedule{actor_id,priority_list,shift,needs,travel_target}; Site{resource_remaining,access,storage_id,availability}; MonitoringStand{priority_profiles,allowed_jobs}.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Scheduler chooses valid task with highest weighted preference and legal physical route; reserves worker and tools, consumes movement time, food/energy and tool durability per completed action. Material outputs appear at site inventory first, then actual hauled quantities move through actor capacity. Tool at durability<=1 blocks next work action, emits RepairRequired, no destruction.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE productivity units/tick = base_units*(0.75+0.005*profession_level)*energy_fraction*tool_efficiency; clamp >=0 and <=approved per-job bound. Mine yield = min(floor(accumulated_effort / effort_per_ore), remaining_node_stock, free_storage_slots). Offline catch-up loops deterministic fixed work windows with persisted resources and timestamps.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Site holds 10 ore, tool durability 3, each ore action costs 1 durability, worker may produce at most 2 ore before tool reaches 1. Given full crate, no ore spawn in overflow. Pausing game for 1h with no ore left produces 0 ore on reload.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
A worker cannot simultaneously drive a mounted dinosaur, be a gunner, be a captive, haul a cargo boat and mine. Worker assignment must end on KO/death/absence; release reservations on cancellation. Offline calculation never starts impossible raids on protected home.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Offline allowed time and resource simulation caps, priority policies, pathfinding budget, shift/fatigue consumption, tool repair automation, hauling limitations and monitoring radius.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
