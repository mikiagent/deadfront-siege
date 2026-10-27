# CBT | Six combat channels, hit geometry, defense and status

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** COMBAT-01..08, ARMOR-01, COMBAT-03/04. **Dependencies:** CHR, INV, DIN, MNT. **Source:** `docs/game-design/15-pve-exploration-and-combat.md`, `docs/game-design/06-inventory-equipment-and-storage.md`.

## Player fantasy, scope and non-goals
The hunter identifies a fast raptor as a Pierce target, an armored Stegosaurus as an Impact target, and soft huge Brontosaurus as a Slash target; a hammer only staggers a target it physically hits.

**Confirmed owner intent:** Every attack mode combines Dexterity (D) or Might (M) with Impact (I), Pierce (P) or Slash (S): DI,DP,DS,MI,MP,MS. Internal damage counters map Impact→blunt, Pierce→pierce, Slash→cut. Both attributes can support melee and ranged. Proposed overlapping armor matchups Slash against Exposed/Light, Pierce against Light/Medium, Impact against Medium/Heavy; not locked numerically. Attacks have physical arc/reach, telegraphs, energy costs and statuses.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
AttackDef{id,primary_attribute:D|M,channel:I|P|S,delivery:MELEE|PROJECTILE|SIEGE,base_damage,stagger,stamina_cost,windup,active_ticks,recovery,reach_shape,attack_tags}; ArmorZone{id,tier,coverage,condition,mitigation}; HitEvent{attacker_id,attack_id,target_id,hit_zone,contact_position,shot_id?}; StatusStack{effect_id,duration,source,stacks}.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
State IDLE->WINDUP->ACTIVE->RECOVERY. Damage on verified one-time contact: permit target/faction/world zone; collision and visibility; local armor/innate defense; apply attacker's effective personal aptitude and weapon component traits; armor overlap modifier; relative mass only for marked body-force moves; compute HP and stagger separately; apply statuses last if not deflected (especially Pounce). Spawn projectile with world-space launch snapshot.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE base resolution: attack_power=base_damage*(1 + clamp((effective_attribute-50)*0.004,-0.20,0.20)); defense_factor=1 - clamp(armor_mitigation,0,0.75); channel_factor=1.15 for approved favorable band, 1.0 otherwise, or 0.90 for explicit resistance; final_HP=round_half_up(max(0,attack_power*defense_factor*channel_factor)). Treat armor and species resistance as separately versioned tables, not simple visual tags. Candidate Slash combo: 1+min(0.20,0.05*consecutive_landed_followups) only melee and eligible weapons; reset on miss/interruption.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Base 100, attribute 50, armor mitigation .20 and favorable multiplier 1.15 -> final 92. Base 100, attribute 75 -> attack_power 110 before armor. Melee Slash third successful landed attack with 2 followups -> combo x1.10 before defense if approved. Sword attack 2m short of target gives 0 regardless damage.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Heavy armor blocks *ordinary raptor Pounce Pin status* first, not the whole category's regular Impact damage. No blanket tiny-swarm Impact bonus unless footprint actually covers multiple. Friendly and private-home targets must be blocked at authorization. One projectile cannot hit same target twice unless piercing property explicitly says multi-hit.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Approve detailed attributes and armor channel coefficients, species tables, stamina/telegraph timing, status stack precedence, combo reset windows, projectile collision and pounce integration.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
