# MNT | Companion slots, expeditions, mount commands and reach

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** PARTY-01, MOUNT-01/02, PLATFORM-01. **Dependencies:** TRB, DIN, CHR, CBT, PHY. **Source:** `docs/game-design/12-expedition-mounts-and-command.md`.

## Player fantasy, scope and non-goals
A survivor rides a trained dinosaur across rough terrain, orders a tribe follower into a realistic flank, and never slices a tiny Compy on the ground from the saddle of an enormous T. rex.

**Confirmed owner intent:** Three shared active expedition companion slots; one human+dinosaur rider pair uses one composite slot. Rider weapon has true hit reach independent of dino jaws/stomp/tail. Seven working roles include Cavalry, Skirmisher, Charger, Bulwark, Berserker, Tyrant, Titan. T. rex intended tamable/rideable.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
Expedition{id,avatar_human_id,slot_assignments[3],zone}; SlotAssignment{slot,kind:HUMAN|DINO|MOUNTED_PAIR,actor_ids}; MountSeat{id,dino_id,human_id?,role:DRIVER|GUNNER}; MountCommand{actor_id,order:MOVE|FACE|HOLD|RETREAT,target,issued_tick}. The avatar does not imply an extra follower; exact slot accounting is OPEN.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Assign requires owner, living actor, party slot capacity, physical proximity, supported saddle geometry and nonconflicting job. Composite rider+mount is one slot only if a legitimate follower rider and mount. Rider inputs direct animal movement through actual stamina/steering; absent qualified driver, trained Hold fallback. Attack collision tests actual weapon tip/capsule and target geometry.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
PROPOSED seat reach predicate: weapon_attack_reaches = swept_weapon_shape.intersects(target_hurtbox) AND raycast_clear AND within_yaw_arc. Momentum strike candidate: closing=max(0,dot(attacker_velocity-target_velocity,unit_attack_direction)); bonus = min(0.30,0.30*max(0,closing-2)/8) after >=3m straight run-up and <=30deg alignment. No momentum reward when stationary. Longshot candidate bonus = 0.20*clamp((distance/range - 0.67)/0.33,0,1) upon verified hit, not for bounce/path inflation.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
With 3 available slots, a valid rider+dino follower composite consumes 1; another human and another dinosaur fill total 3. A mounted spear at closing=6m/s and valid run-up yields bonus 0.15 (15%), if no other class modifier. At 10m/s ->0.30 cap; 0m/s ->0. A 2m-reach sword from 5m-high saddle cannot hit a ground target 5m below absent proper collision geometry.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Dismount revalidates party slots before two independent actors can follow; driver KO removes seat occupancy and stops phantom inputs. No free independent full DPS from mount plus mounted human without action scheduling. Paths/speeds real, terrain blocks line of attack.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Controlled avatar and its mount slot accounting, follower dismount overflow behavior, rider attack cadence, companion injury recovery and exact role assignments to species; all momentum values are candidate.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
