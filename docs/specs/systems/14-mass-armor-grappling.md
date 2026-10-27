# PHY | Body mass, loaded mobility, armor zones, stomp and pin

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** COMBAT-09/10/11, MOUNT-02, ARMOR-01. **Dependencies:** DIN, CBT, MNT, PLT. **Source:** `docs/game-design/22-dinosaur-mass-armor-and-grappling.md`.

## Player fantasy, scope and non-goals
A heavy plate-clad Titan's planted foot hits several Compys physically under it; extra mass makes the stomp harder yet worsens turning. A little raptor's Pounce bounces from intact Heavy plates without Pin.

**Confirmed owner intent:** Added physical load increases connected stomp/tackle/trample force but burdens acceleration/turn/stamina. Defender's relative mass/stance mitigates connected body force and can prevent stagger. Intact Heavy plate on actual struck pounce zone blocks ordinary raptor Pin/Knockdown->Maul continuation; huge predators retain separately valid body grabs. Creature natural mass, gear load and protected zones remain distinct.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
BodyProfile{base_mass_kg,comfortable_carry_kg,foot_swept_volumes,sockets,reach_shapes}; LoadItem{item_id,mass_kg,mount_socket}; ArmorZone{hit_zone,tier,condition,coverage_polygon}; ContactHit{attacker_id,defender_id,contact_zone,attack_mode,relative_speed}; GripState{captor_id,prey_id,pin_strength,escape_progress}.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Compute actual equipped/cargo/passenger mass once; reject fitting beyond approved structural load. Mass-bearing contact hits validate swept footprint. Before Pounce status application check hit point local armor tier+integrity; if intact Heavy and ordinary raptor Pounce, apply recoil/back-off and no Pin. Otherwise compare effective masses/stance and force/poise to permit Pin and later anatomy-compatible Maul. For stomps compare attacker-v-defender force only after collision.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE load_ratio = carried_mass/comfortable_capacity. mobility_multiplier=1 - 0.4*clamp((load_ratio-0.70)/0.50,0,1). Impact force scale=clamp(sqrt((base_mass + carried_mass)/base_mass),1,1.35), applied only on body-force moves. Defender mass factor = clamp(sqrt(attacker_total_mass/max(defender_total_mass,1)),0.60,2.5); actual stun occurs if computed_stagger > armor+stance_poise_threshold (candidate). Never apply load twice.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Carry 930kg on animal with comfort capacity 1000 -> load ratio .93 -> strain .46 -> mobility .816. Base mass 5000 and load 1250 gives outgoing force sqrt(1.25)=1.1180. Attacker 2000kg / defender 500kg -> raw mass ratio sqrt4=2, then apply bounded factor once. Heavy plate struck by raptor Pounce => 0 new Pin stacks; a huge jaw grapple is evaluated by its own valid move.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Multiple tiny bodies in one foot volume may take damage once each per footfall, not every simulation tick; momentum not a free full-range status. Plate coverage local and wear-driven; a broken plate loses deflection. Riders, turrets and cargo all counted once in mass; cannot load an existing turret twice on same mount.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Choose species mass/carry tables, hitbox geometry, load and damage coefficients, pounce deflection zone thresholds, escape windows and stamina penalties.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
