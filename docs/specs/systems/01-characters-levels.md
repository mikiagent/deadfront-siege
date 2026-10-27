# CHR | Individual levels, IVs, EVs and learned professions

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** LVL-01/02/03, ATTR-01/02, TRIBE-01. **Dependencies:** FND.

**Source:** `docs/game-design/02-characters-levels-and-age.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
A level-1 descendant with exceptional Dexterity can become an exceptional tailor later, but cannot equip the former level-60 avatar's bow or inherit their Tailoring mastery.

## 2. Confirmed direction and non-goals
Every human earns personal XP/levels and separate professions; equipment is gated by individual's actual level regardless of item acquisition source. Tribe retains unlocked level-60 access, but current avatar must personally be level-60 for PvPvE. Dexterity and Might innate IVs remain separate from occupation XP. Endurance relates to building work and Intelligence to research/leadership.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
HumanStats{level,xp_total,iv_d,iv_m,iv_end,iv_int,ev_by_attribute,skill_xp_by_profession,age_stage,learned_recipes}. ItemDef{equip_required_level}. TribeUnlocks{frontier_unlocked:bool}. ControlledActor{human_id}. IV, EV and skill values cannot alias each other.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
On XP reward: verify specific work/combat event and its unclaimed unique source, compute owner, add XP, advance level by approved threshold table, emit level events. On equip: require human.level >= equip_required_level and knowledge/slot/ownership predicates. On switch avatar: move control pointer only. On frontier entry: both tribe unlock and current avatar.level >=60.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
CANDIDATE threshold table: XP_to_reach(L)=round_half_up(100*(L-1)^1.65), 1<=L<=60, cumulative XP; monotonic thresholds. Candidate occupation yield: skill_xp=min(base_work_xp, 50 per unique work order) to discourage AFK cycling. Intrinsic IV remains fixed after birth; optional trained EV contribution to effective aptitude: A=IV + min(EV,40)*0.25 (units abstract). This is not a final combat/quality coefficient.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
Threshold example at level 1 is 0, level 2 is 100; level 3 round_half_up(100*2^1.65)=314. A character with IV_D=70, EV_D=20 has candidate A_D=75; professional skill is a *separate* factor. Level 20 equipping a level-21 sword rejects; switching to level-60 veteran succeeds only for that veteran; after switching back, sword stays on veteran.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
No XP granted to dead/prisoner/not-participating person; replay attack/craft event never awards duplicate XP. A captured person acquired as level-1 adult retains inherited IVs but earned XP, EVs and skills reset per PVP-04. Gear previously worn becomes unequippable when explicit level reset occurs; transaction must unequip safely before handover.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Owner must approve XP curve, levels above 60, IV ranges/sex tendency distribution, EV training policy, skill levels, class affinities, knowledge ownership and adulthood timer. Candidate numbers are not locked.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
