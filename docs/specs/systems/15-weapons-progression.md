# WPN | 18 defining weapons, tool chain, primitive metallurgy

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** CRAFT-02/03, COMBAT-01/02/05/06. **Dependencies:** CRF, MAT, CHR, CBT. **Source:** `docs/game-design/23-weapons-and-material-crafting-progression.md`.

## Player fantasy, scope and non-goals
A new explorer builds stone/bone weapons; later dinosaur sinew, scutes and first copper become worth extracting; final iron weapons require actual smelter, refinery, forging and processed bone/wood/tendon components.

**Confirmed owner intent:** Six defined attack classes DI,DP,DS,MI,MP,MS each have one defining early/mid/late craftable weapon, **18 total**. Era progression early stone/bone, mid composites+copper, late forged iron+dinosaur trophies. Final weapon assembly never consumes raw ore/logs/animal hide/tendon directly; all must be processed, with real sources for all ingredients.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
WeaponDef{id,era,primary_attribute,damage_channel,delivery,component_roles,ammo_def_id,weight,required_level,required_profession}; ProcessingNode{input_defs,stage,station,outputs}; MaterialSource{biome,minimum_node_tier,drop_table}; RecipeDef{ingredients,quantity,station,work_ticks}. Missing item-source links block BUILD_READY.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Validate recipe graph acyclic and each ingredient has a source and production operation. Craft components first: wood_log→split_wood→plank→treated_plank→reinforced_haft; dense_bone→carved_bone_rib→reinforced_bone_block; predator_tendon→sinew_cord→braided_sinew_cable; iron_ore→smelted_ingot→refined_iron_bar→shaped_head. Assemble item from prepared roles, preserving signed provenance, then apply personal equip gate and actual attack modes.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE weapon quality Q = clamp(0.45*mean(component_role_quality) + 0.35*workmanship + 0.20*station_condition,0,1). Damage = round_half_up(base_era_damage*(0.75 + 0.5*Q)), prior to normal combat defense. Era base damage table is not approved. Need explicit role weights for each weapon; don't average decorative parts into blade damage.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
If components quality=.8, workmanship=.6, station condition=1, Q=.36+.21+.20=.77 and quality multiplier=1.135. For candidate base 100 -> 114 after rounding; actual final damage is later affected by target armor and attack attribute. Attempt forge with raw iron_ore directly fails recipe; copper crossbow without actual bolt ammo cannot fire.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Prevent historical workbench generic `ingot` from bypassing smelter gate. Require actual ore source Tier45–50 before claiming iron tier achievable. Player may trade high-level weapon but cannot equip above personal requirement. All 18 weapon classes need different handling, not merely icon changes.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Approve actual 18 item names and ingredient amounts, source content backlog WPN-01..24, three era level cutoffs, balance table, smelter fuel and recipe skill requirements.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
