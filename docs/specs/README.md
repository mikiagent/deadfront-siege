# DEADFRONT technical blueprint | Specification index

**Revision:** 2026-10-26 / blueprint proposal v0.1
**Status:** DESIGN / OWNER REVIEW, not an implementation command.
**Scope:** clean-room Godot 4.7.1 typed-GDScript architecture for the intended game. No game code is changed in this PR.

## Document authority

1. Most recent direct product-owner answers.
2. `docs/game-design/decisions.md` for explicitly confirmed rules and unresolved details.
3. Reviewed, approved, version-stamped contracts in this directory (none are owner-approved yet).
4. `docs/game-design/` and `docs/design/` as source drafts.
5. Older `docs/prd/`, `docs/orchestration/`, `AGENTS.md`, `HANDOFF.md`, `GAUNTLET.md`: historical research and existing-build evidence, not future rule overrides.

**Rule status:** CONFIRMED = owner gave the stated direction; PROPOSED = candidate exact mechanics; OPEN = unresolved; IMPLEMENTED = code actually exists; VERIFIED = tested. Proposed constants and fixtures are **not approved gameplay balance**. The status `BUILD_READY` is withheld until the scope's required decisions, schemas and numerical fixtures are approved. A deterministic candidate model can be implemented in an isolated test harness for evaluation without counting as approved production mechanics.

## Entry points

- [MASTER-CONTEXT.md](MASTER-CONTEXT.md) | North star, game loop, domain topology and forbidden violations
- [ARCHITECTURE.md](ARCHITECTURE.md) | Identifiers, aggregate roots, events, authority, saves, scene layering
- [REGISTRY.md](REGISTRY.md) | All implementation specs, provenance, dependencies, readiness and gaps
- [DECISION-QUEUE.md](DECISION-QUEUE.md) | Prioritized owner review, contradictions and proposed defaults
- [MILESTONES.md](MILESTONES.md) | Dependency-ordered Claude coding tickets, isolated clean build
- [CLAUDE-HANDOFF.md](CLAUDE-HANDOFF.md) | Copy/paste first Claude task and session rules
- [QA-CONTRACT.md](QA-CONTRACT.md) | Goldens, simulation, no-duplication properties and release verification
- [CONSISTENCY-AUDIT.md](CONSISTENCY-AUDIT.md) | Canonical rule and conflict cross-check
- [CONTENT-AUDIT.md](CONTENT-AUDIT.md) | Live item/recipe coverage and 18-weapon missing IDs
- [data/](data/) | Machine-readable candidate balance, fixtures, validation support
- [systems/](systems/) | One contract per domain, specific formulas, state transitions and abuse tests

## Domain contracts

| ID | Document | Core contracts |
|---|---|---|
| FND | [00-identity-persistence.md](systems/00-identity-persistence.md) | ID ownership, atomic moves, snapshots, migration |
| CHR | [01-characters-levels.md](systems/01-characters-levels.md) | personal XP/IV/EV/professions, gear gating |
| ISL | [02-islands-world.md](systems/02-islands-world.md) | safe homes, migration, unstable resets |
| MAT | [03-materials-traits.md](systems/03-materials-traits.md) | signed lots, processing fusion, provenance |
| INV | [04-inventory-equipment.md](systems/04-inventory-equipment.md) | mass, stacks, reservation, vault, equipment |
| FOD | [05-food-spoilage.md](systems/05-food-spoilage.md) | real time freshness, buffs, rotten transformation |
| CRF | [06-crafting-production.md](systems/06-crafting-production.md) | recipe graph, intermediate products, workstation |
| BLD | [07-building-packaging.md](systems/07-building-packaging.md) | blueprints, worksites, room traits, packable unique structures |
| TRB | [08-tribe-population.md](systems/08-tribe-population.md) | human identity, recruitment, housing |
| GEN | [09-lineage-education.md](systems/09-lineage-education.md) | lineage, IV recombination, costly upbringing |
| WRK | [10-workers-automation.md](systems/10-workers-automation.md) | jobs, monitoring stand, hauling, finite production |
| DIN | [11-dinosaurs-genetics.md](systems/11-dinosaurs-genetics.md) | species ecology, capture, genetic traits |
| MNT | [12-expedition-mounts.md](systems/12-expedition-mounts.md) | party slots, physical seats, orders, reach |
| CBT | [13-combat-damage.md](systems/13-combat-damage.md) | D/M × I/P/S, damage and defenses |
| PHY | [14-mass-armor-grappling.md](systems/14-mass-armor-grappling.md) | load, stomp, poise, pin and heavy pounce deflection |
| WPN | [15-weapons-progression.md](systems/15-weapons-progression.md) | six archetypes × three tiers, metallurgy |
| SGE | [16-turrets-siege.md](systems/16-turrets-siege.md) | automatic/crewed emplacements and real ammo |
| PLT | [17-platform-saddles.md](systems/17-platform-saddles.md) | 1/2/1 sockets, two real humans and shared ammo |
| LOG | [18-logistics-boats.md](systems/18-logistics-boats.md) | load/harbor capacity, protected homebound voyage |
| ECO | [19-markets-economy.md](systems/19-markets-economy.md) | trading, currency, item identity, no gear bypass |
| PVP | [20-pvp-custody.md](systems/20-pvp-custody.md) | safe territory, frontier raids, 72h ransom |
| UX | [21-ux-controls.md](systems/21-ux-controls.md) | sit/sleep, bulk inventory, effect inspection, touch |
| TUT | [22-tutorial-progression.md](systems/22-tutorial-progression.md) | first-hour quest path and validation |
| OPS | [23-platform-liveops.md](systems/23-platform-liveops.md) | client target, telemetry, security, economy fairness |

## Contract maturity

Every system contract below is presently **DRAFT / NEEDS OWNER DECISION**. They include concrete, executable candidate math and fixtures to accelerate review, but no system is independently owner-certified BUILD_READY. FND's purely engineering identity/transaction primitives can be prototyped immediately without locking downstream balance.

All future approved numbers go in versioned machine-readable tables, with `ruleset_version`; fixtures must use exactly the corresponding version. A changed formula requires new fixtures and migration policy.

## Design completion acceptance

A spec is ready only if two independent implementation agents would produce equivalent game outcomes, including conservation, persistence, failure paths, idempotence, and identical rounding/seed behavior. Resolve owner questions before promoting a contract.
