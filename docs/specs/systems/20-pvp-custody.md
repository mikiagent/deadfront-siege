# PVP | Optional frontier, local alphas, raids and 72h captive ransom

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** PVP-01..05, LVL-01, LOG-01/02. **Dependencies:** ISL, CHR, CBT, LOG, SGE, TRB, DIN, ECO. **Source:** `docs/game-design/16-pvp-frontier-siege-and-captives.md`, `docs/design/pvp-raiding-local-alphas-and-siege-fairness.md`.

## Player fantasy, scope and non-goals
A personally level-60 survivor builds an exposed frontier outpost; a costly eligible enemy raid breaches it, captures a human, and a 72-hour real-world deadline gives original owner the option to pay game-calculated ransom and recover complete learned progress.

**Confirmed owner intent:** Home unraidable, only constructed PvPvE settlements face player raids. No scheduled vulnerability windows. Frontiers require controlled individual's personal level>=60 and historical tribe unlock. Ransomed human/dino returns inherited IV + earned level/skills/EV intact. Unpaid after 72h attacker may acquire the SAME adult physical identity/IV but career restarts at level1, XP/skills/EV reset. Price must be game-calculated.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
FrontierSettlement{id,owner_id,zone,defender_roster,raid_status}; RaidAttempt{id,attacker_id,target_settlement_id,committed_supply,power_band,phase}; CaptiveCase{id,captive_actor_id,original_tribe_id,captor_tribe_id,captured_at_utc,deadline_utc,ransom_minor_units,status:PENDING|PAID_RETURNED|EXPIRED_CLAIMABLE|CLAIMED}.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Authorize entry and raid only by server-validated personal level and zone/class eligibility. On capture move existing actor into custody and freeze progression by unique actor ID; compute formula once, persist quote and deadline= capture_utc + 259200 seconds. `Pay` checks clock<deadline and sufficient funds then returns original actor with earned progress. On expiry attacker may claim if allowed, resetting career but not identity/IV/appearance. Decide atomically race between pay and claim.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
Deadline 72h exactly 259200 seconds. PROPOSED price R=round_half_up(base_species_ransom*(1 + 0.02*original_level + 0.005*sum(rare_iv_above_threshold))) with minimum and affordability cap pending owner. Raid cost candidate proportional to power mismatch and supplied siege resources, not flat. These are *design candidates*, absolutely not approved ransom or anti-punch-down balance.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Captured at epoch 1000000 -> deadline 1259200. Payment at 1259199 eligible; at 1259200 not under strict < boundary. Original level60 paid -> same level60 and trained skills/EV returned. Unpaid claimed -> level1, zero XP/EV/learned skills, same inherited IV and original physical identity. Private home target always raid-denied.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Server clock and commands authoritative; repeated payment cannot duplicate captive/credit. Outage/notification policies OPEN; client timer not sufficient. Offline captives cannot be used for labor, mounted turrets or reproduction. Raiders cannot cheaply farm their own captive alts; region force bands and anti-punch-down must be approved before online PvP.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Exact ransom price/currency/upper bounds, offline outage extension, claim timing/loyalty, raids and loot budget, permitted region matchmaking, defenders' recovery and PvE attacks at PvPvE outposts.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
