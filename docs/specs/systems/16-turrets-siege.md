# SGE | Crews, automatic defenses, siege and ammunition

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** TURRET-01, PVP-01/03, PLATFORM-01. **Dependencies:** INV, CBT, WPN, TRB, BLD. **Source:** `docs/game-design/24-turrets-siege-ammunition-and-guard-crews.md`.

## Player fantasy, scope and non-goals
A real tribe guard mans a heavy ballista supplied with manufactured bolts, while a clockwork side repeater covers a narrow lane with finite loaded rounds, clear LOS and upkeep.

**Confirmed owner intent:** Distinct automatic and physically crewed turret types. Crewed device requires present qualified real human; autos require plausible primitive triggering mechanisms, finite ammo/winding, firing arc, cooldown, clear line of sight and target/zone permission. Finished defensive towers are packable unique structures but not during active combat.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
TurretInstance{id,weapon_def_id,ammo_inventory_id,loaded_magazine,gunner_human_id?,owner_structure_id?,orientation,condition,orders,next_ready_tick,mode:SAFE|ARMED|DISABLED}; ShotReceipt{shot_id,ammo_type,origin_world_pose,projectile_id,source_actor_id}. TurretAmmoManager binds reserve ledger and magazine identities.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
On auto acquire: evaluate mechanically supported sensory field, LOS, arc, allowed target and allied risks; on crewed fire also require living present gunner and relevant learned operating skill. Load atomically debits reserve. Fire consumes loaded chamber exactly once, records shot_id before projectile; projectile born into world independent of mount or tower. On turret destroyed, drop/lose remaining ammo via an explicit loss event.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
PROPOSED effective shots/min = min(60/cooldown_seconds, sustainable_supply_rate_rounds_per_min); loaded reserve always conserved across box, magazines, fired, destroyed, transferred. Auto DPS = actual_hit_probability * damage_per_hit * shots_per_second; candidate to keep autos lower expected DPS than similarly priced staffed siege. Target arc candidate [-45°,45°]; two perpendicular turrets don't magically each get 360°.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
One reserve box with 6 bolts, load 1 into each of 3 guns -> reserve=3, loaded=3. Fire main -> reserve=3, loaded=2, fired=1. Reload one -> reserve=2, loaded=3, fired=1. Box=1 while two autos concurrently reload -> one gets 1, other 0. No gunner -> crewed fire rejected even with ammo.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Don't model omniscient faction-recognizing mechanical tripwires; trap contact can harm friendlies if that's how tech works, with warning/arm zone. No projectile through own deck, human seat or mountain. Home immunity and legal hostile permissions supersede automated orders.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Automatic mechanism by era, detection and friendly-fire policy, loaded magazine size, crew skill formula, tower footprint, recoil, maintenance and ammo priority.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
