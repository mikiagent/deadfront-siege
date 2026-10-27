# PLT | Living siege platforms: 1 crewed + 2 auto + 1 shared box

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** PLATFORM-01, PARTY-01, COMBAT-09..11. **Dependencies:** DIN, MNT, PHY, SGE, INV, TRB, CRF. **Source:** `docs/game-design/25-platform-saddles-and-mobile-siege.md`.

## Player fantasy, scope and non-goals
An armored giant dinosaur is driven by a tribe member while the player mans a deck-mounted ballista; alternatively the player steers while a real tribe gunner fires, and two loaded autonomous defensive guns protect flanks.

**Confirmed owner intent:** For eligible heavy animals maximum 1 manned siege, 2 automatic turrets and 1 shared finite ammunition box. Two valid staffed configurations swap actual player and tribe member in helm/gunner seats. Crewed weapon never fires without one real gunner; autos have real magazines/ammo. Giant saddle fitting restricted by species geometry and capacity.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
PlatformSaddle{id,animal_id,seat_driver_human_id?,seat_gunner_human_id?,main_gun_item_id?,auto_left_id?,auto_right_id?,shared_box_inventory_id?,state,load_kg}; Unique constraints: driver!=gunner; each human seat references actual person; distinct weapon instance IDs; exactly one box owner. CrewOrder{MOVE|FACE|HOLD|RETREAT}.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Attach when animal stopped, fitted stable back socket compatible, total load legal, stations/assets physically present. Seat assignment releases other tasks atomically. Player gunner orders tribe driver; player driver commands named tribe gunner to acquire legal targets. Reload uses one shared reserve and shot idempotence. If either actor KO, physically vacate their seat; gunner lost => main off; driver lost => animal trained HOLD fallback. Firing from moving deck spawns a world-space projectile with launch snapshot and inherited mount velocity if approved.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
PROPOSED carried load = saddle + all turret weights + box + rounds + two people + armor/cargo. Reuse PHY candidate ratio q=load/comfortable_capacity, speed_mult=1-0.4*clamp((q-.7)/.5,0,1). Ammunition invariant per ammo_type: initial+resupply = box+magazines+fired+discarded+transferred_out; concurrent two load requests to one reserve must serialize. For auto aim, sector intersection and tracked target positions evaluated separately.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Saddle 300kg + manned gun180 + autos90+90 + box40 + ammo50 + driver80 + gunner70 + other cargo30 = 930kg. At hypothetical 1000kg comfort q=.93 -> speed 81.6% unloaded. Six rounds, 3 load into guns => 3 box; one shot => 3 box+2 loaded+1 spent. Dismount gunner: main gun cannot fire, both loaded autos still can if legal.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
No player clone on role swap; no three free additional humans; T. rex intended tameable but current data contradiction must be reconciled separately; Brontosaurus is future distinct creature and giant turret-catapult cannot be parented unchanged from fixed 3x3 field model. No infinite-ammo siege across zone safety.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Owner must confirm eligible species/back geometry, exact crew avatar-slot accounting, turret tech realism, comfortable carry capacities, recoil/accuracy and priority under shared ammo scarcity.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
