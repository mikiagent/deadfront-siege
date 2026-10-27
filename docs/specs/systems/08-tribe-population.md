# TRB | Persistent humans, housing, recruitment and succession

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** TRIBE-01/04/05, WORK-01, PARTY-01. **Dependencies:** FND, CHR, ISL, INV.

**Source:** `docs/design/tribe-lineage-domain-and-labor.md`, `docs/design/safe-home-expeditions-offspring-and-identity.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
After the former player survivor retires from active control, they remain a real skilled individual producing at home, while the newly selected person learns with their own XP, IVs, traits and equipment.

## 2. Confirmed direction and non-goals
Tribe human roster separate from dinosaur roster; all humans persist; control switching does not prestige-reset economy; if every human is lost there is a baseline human recovery mechanism. Humans have differing bodies, stat tendencies with overlap/no job bans, and equal intelligence baseline.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
Tribe{id,owner_account,home_island_id,human_ids,dinosaur_ids,unlock_flags,housing_capacity}; Human{id,parents?,status:ALIVE|DEAD|CAPTIVE|EXILED,location,assignment,household_id,relationships}; AvatarPointer{controlled_human_id}; RecruitCase{candidate_id,offer_cost,expires_at,status}.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Join/recruit validates capacity and living actor uniqueness; reserve food/space; transfer ownership once; housing queue not instant despawn; avatar swap changes input control and previous person's assignment without creating actors; successor at own personal level, saved tribe unlock remains. Last-human recovery spawns new low-IV starter with protected-home rights under explicit anti-abuse lock.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE capacity = floor(sum(housing_bed_slots * occupancy_condition)) - reserved_dependent_slots. Candidate food support/day = sum(human_consumption_by_stage) + reserve; recruitment requires 2 days projected consumption. Example: 4 normal beds, 3 adult residents, no dependents -> one open spot. All rates need approval.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
With three residents and four beds, one valid wanderer recruit succeeds; a second fails without another bed. Switching current level-60 avatar to level-1 child leaves all buildings and former veteran unchanged; child cannot equip veteran gear or enter PvPvE.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
A human on a homebound boat or captured in frontier cannot be reassigned simultaneously to local work or saddle seat. A person dying in an animation still has exact durable state transition; recovery cannot become endless free worker generation.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Recruit sources and currency, household model, natural mortality, sex/physique distributions, per-person knowledge vs tribe-wide and last-human recovery rules.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
