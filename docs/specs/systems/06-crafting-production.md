# CRF | Processing recipes, stations, products and material conservation

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** CRAFT-01/02/03, MAT-02, BUILD-01. **Dependencies:** FND, MAT, INV, CHR, FOD.

**Source:** `docs/game-design/07-crafting-processing-and-food.md`, `docs/game-design/23-weapons-and-material-crafting-progression.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
Player processes logs into split wood, planks and treated stock; bone into ribs and reinforced bone blocks; ore through a real smelter before forged fittings; combines prepared parts into equipment without using raw ore as an endgame weapon part.

## 2. Confirmed direction and non-goals
Late-game weapons/metal tools require real processed intermediate components, not raw logs/bones/tendons/ore. Main Crafting menu initiates unlocked blueprints, later placed as worksites; all crafting consumes real inputs, stations and time.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
RecipeDef{id,required_station,required_skill,ingredient_groups,quantities,duration_ticks,fuel_cost,outputs,byproducts,stage}; WorkOrder{id,actor_id,station_id,input_reservations,start_tick,duration,progress,state}; CraftedItem{id,components:[item_instance_ids],workmanship,lot_provenance}. Data catalog must reject cycles that increase resources.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Select explicit lots; resolve level/skill and station requirements; preview signed effects; reserve exact quantities; on start transfer to escrow; advance only while worker/station/fuel operational; on completion consume escrow and create output/byproduct once; aborted jobs return eligible escrow minus explicitly committed fuel/consumed partial stages. Use recipe DAG so each derivative requires legitimate prerequisite station.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE progress fraction p=min(1, cumulative_valid_work_ticks / required_work_ticks). Candidate required_work_ticks = ceil(base_ticks * max(0.50,1 - 0.005*profession_level)), minimum bounded. Yield count is from recipe, no multiplicative free yield due to rare traits unless separately approved. Conservation each ingredient: input = consumed + remaining_reserved + refunded + documented_waste.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Example candidate: 2 carved ribs with signed +Resilient and -Brittle and 1 pitch catalyst -> exactly 1 reinforced block; both signatures persist and catalyst count decreases 1. Base 200 ticks, level 20 -> ceil(200*0.9)=180. A cancelled order before work starts returns both ribs and pitch per selected abort policy, no output.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Two orders cannot reserve same final rare lot; persistent station saved mid-job resumes with no new supplies; recipe unlocks never bypass personal level gear restrictions; kitchen use and builder placement use same crafting catalog rather than separate magic recipe interface.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Approve recipe source definitions, station types, work durations, fuel accounting, item/skill level requirements, workmanship and failure byproducts.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
