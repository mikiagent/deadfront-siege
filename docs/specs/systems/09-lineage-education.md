# GEN | Human offspring, genetics, upbringing and mentorship

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** TRIBE-02/03/05, LVL-03, ATTR-01/02. **Dependencies:** FND, TRB, CHR, FOD, WRK.

**Source:** `docs/design/tribe-lineage-domain-and-labor.md`, `docs/game-design/02-characters-levels-and-age.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
The tribe spends hard-earned food, nursery support and teachers to raise a descendant with inherited potential but no inherited personal levels, EVs or mastered profession skills.

## 2. Confirmed direction and non-goals
Human reproduction is deliberately very expensive, timed and food-quality dependent. Descendants inherit possible attribute advantage, not parent XP. Education may shape aptitude, but jobs/level are personally earned. Adult apparent age loosely reflects level; growth stages are distinct from career level.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
PregnancyOrBirthProject{id,parent_ids,baby_id?,start_utc,phase,resource_escrow}; Child{id,parents,stage:INFANT|CHILD|YOUTH|ADULT,nutrition_score_by_stage,education_exposure,iv_vector,ev_vector,level}; EducationSlot{teacher_id,pupil_id,subject,rate,location}.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Validate two eligible parent records/kinship and home support, reserve expensive inputs, generate one deterministic child identity and IVs at birth; progress real-time stages only with available food/shelter, log real supplies consumed. Mentor applies education credit toward later learned skills without inheriting teacher's career. On adult transition permit avatar selection at personal level 1.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE each attribute IV_child=clamp(round_half_up((IV_parentA+IV_parentB)/2 + bounded_seeded_delta),1,100), delta uniform integer [-8,+8]; nutrition affects an additional temporary upbringing_potential_bonus in [-5,+5] rather than modifying inherited genotype; base stage durations e.g. 2h/6h/12h, all PROPOSED, not real-year aging.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Parents D=60 and D=80, seeded delta=+4 -> child D=74. Level-60 + level-40 parents yield adult child level 1, XP=0, EV=0, profession skill=0. A second replay of same birth_id yields the existing child ID, never twins.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Never create child without available housing and project resources; dropout pauses growth and handles escrow deterministically; parents captive/dead status rules OPEN; school work cannot train combat without real education/XP system; avoid abuse of recurring cheap baseline births.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Two-parent requirement, food consumption, full stage timing, genetic spreads, risks and caps, education resource costs and apparent-age career mapping.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
