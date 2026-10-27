# LOG | Harbors, load capacity, raids and protected homebound shipping

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** LOG-01/02, HOME-01, PVP-01. **Dependencies:** ISL, INV, WRK, BLD, ECO. **Source:** `docs/design/safe-home-expeditions-offspring-and-identity.md`, `docs/game-design/04-world-biomes-and-travel.md`.

## Player fantasy, scope and non-goals
Raiders reach a contested production outpost while workers finish loading a transport. Boat may depart mid-raid; cargo not yet loaded is vulnerable, but boat, people and cargo become fully protected once it is actually underway to safe home.

**Confirmed owner intent:** Boat departure during raid allowed. Homebound vessel, actual crew and cargo cannot be intercepted/raided after departure. Capacity depends on boat level/traits plus harbor level/traits; no infinite evacuation by spam; loading at contested dock remains at risk until commit.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
Vessel{id,level,traits,mass_capacity,slot_capacity,crew_ids,route_state}; Harbor{id,level,traits,loading_slots,owner_id}; Shipment{id,origin,destination,manifest,reserved_ids,departed_utc,arrival_utc,state:DOCKED|LOADING|DEPARTED_HOMEBOUND|ARRIVED|UNLOADED|LOST}.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Loading transfers items from dock storage into escrow manifest per worker capacity and loading-rate schedule; during raid loading may progress only if workers/path valid. `Depart` atomically transfers manifest to a homebound voyage and changes safety permission. Repeated departures with same command ID don't produce extra protected ships. At destination unload to safe storage, never silently exceed capacity.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE effective_cargo_kg=min(boat_base_capacity_kg*(1+boat_trait_bonus),harbor_export_limit_kg*(1+harbor_trait_bonus)); slots separately min(boat_slots,harbor_slots_per_voyage). Candidate load_rate = sum(valid_loader_kg_per_min); time=ceil(total_mass/load_rate). Every recorded item is in dock OR manifest OR home, never two.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Boat cap 120kg and harbor export limit 100kg -> 100kg permitted before bonuses. 80kg loaded + attempt to load 30kg => reject excess; do not silently place 10kg in phantom cargo unless partial transfer explicitly requested. Raid hits at 80kg loading; departure moves precisely 80kg to protected manifest and 20kg still on dock is vulnerable.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Already departed homebound shipment cannot be targeted through dock proxy, intercept action or destroyed world scene. Boat does not become safe merely when player clicks launch if transition fails. Defeated dock workers leave loaded cargo unchanged, and no offline AI hand-waves a new shipment.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Cap formulas, outbound safety, loss of boat before departure, load times, worker logistics skill, harbor parking and return-trip schedule.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
