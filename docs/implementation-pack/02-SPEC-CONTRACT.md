# DEADFRONT | Mandatory implementation-grade subsystem contract

**Status:** Proposed documentation standard. A subsystem is not `BUILD-READY` simply because a Markdown chapter exists.

The objective is to finish **game design** in the specification and leave **engineering choices** (clean code, performance, Godot nodes, test harness integration) to Claude.

## Required spec header

```yaml
spec_id: SYS-XX
title: ...
version: 0.1.0
stage: DRAFT             # DRAFT | OWNER_REVIEW | BUILD_READY | IMPLEMENTED | VERIFIED
owner_rule_ids: [ ... ] # link exact confirmed entries in docs/game-design/decisions.md
last_reviewed: YYYY-MM-DD
depends_on: [SYS-00, SYS-...]
consumed_by: [SYS-...]
source_docs: [ ... ]    # canonical Markdown links
blocking_decisions: [Q-...]
number_set: candidate-v1 # approved-vN only when actually approved
implementation_target: Godot 4.7.1 / typed GDScript
```

**Every binding field/rule individually records provenance:** CONFIRMED owner, PROPOSED design math, OPEN decision, IMPLEMENTED code, VERIFIED test. A file-wide `BUILD_READY` label does not auto-approve any `PROPOSED` subrule.

## A complete spec has these sections, in this order

1. **Player outcome and example:** What player does, sees, learns, earns, loses; one realistic 30-second example.
2. **Purpose, non-goals and constraints:** Where active, unlocks, exceptions, invariants, non-features.
3. **Dependency & ownership table:** Consumes/emits which entities, owning domain and allowed mutation events.
4. **Domain types and data definitions:** All IDs, field types, enumerations, units, persistence, nullable conditions, sources and references.
5. **Operations and preconditions:** Input, actor permissions, state guards, atomic effects, failure codes and user-visible feedback for each command.
6. **State machine:** Legal states, transitions, triggering events, interrupts, timeouts, disconnection/death/rollback behavior.
7. **Mathematics and randomness:** Exact equation, evaluated order, typed units, constants, caps, rounding, seeds, probabilities and explicit treatment of zero/negative/overflow values.
8. **Pseudocode reference algorithm:** Step-by-step pure/domain-function implementation without Godot scene specifics.
9. **Canonical numerical fixtures:** Given/When/Then examples with **exact expected numbers** for minimum/typical/maximum and tricky boundaries.
10. **Economy/exploit invariants:** Conservation of assets, no duplicate inventory, XP abuse, unattended labor, recursive crafting, offline progression and raid protections.
11. **Presentation and interactions:** Touch/mouse, valid actions, disabled states, tooltips, icons and feedback; reference sketches when helpful.
12. **Networking and save lifecycle:** Single-player now, future authority boundary, state versioning, migrations, idempotent transfers and reconnect handling.
13. **QA and acceptance:** Deterministic unit/property tests, scene integration tests, save/load and visual regressions; expected artifacts and pass condition.
14. **Dependency handoff:** New contracts exposed, code ownership, migration needed by downstream systems, explicit non-goals.
15. **Remaining open decisions:** Decision ID, options, affected systems, safe temporary isolation (if possible), and whether it **blocks building**.

## Mathematics checklist

Use a function contract rather than writing "higher-quality materials give better weapons." Example format:

```text
input:
  base_damage: float (>0) [points]
  weapon_quality: float [0, 1]
  material_modifier: float [-0.2, +0.2]
  target_armor: float [0, 1]
outputs:
  health_damage: integer [points]
operation:
  raw = base_damage * quality_multiplier(weapon_quality)
  adjusted = raw * (1 + material_modifier)
  mitigated = adjusted * (1 - target_armor)
  health_damage = max(0, round_half_up(mitigated))
```

**This example is solely a formatting demonstration. It is NOT approved DEADFRONT combat math.** The real combat spec must also define critical hits, resistances, armor tiers, stagger, hit zones, attribute coefficients, projectile physics and exact order before it is BUILD-READY.

For every real formula state how values are tuned, prove that increasing an input has intended monotonic effects (or explain why not), clamp exploits, test extreme values and preserve backward-compatible save meaning.

## Example: shared saddle-ammunition conservation

**Confirmed design direction:** one shared ammo box, at most one crewed and two automatic turrets. Every real round is deducted on load and cannot be spent twice. **Proposed implementation:** a weapon may hold a counted loaded chamber, while the box is the single reserve inventory.

```text
total_ammo_initial =
    rounds_in_shared_box + sum(rounds_loaded_in_3_weapons)

For all transfers and reloads:
    rounds_in_box + sum(rounds_loaded) + rounds_fired + rounds_discarded
    = total_ammo_initial + rounds_resupplied
```

This identity holds per ammo type and over a chosen accounting interval; separately record rounds looted/transferred out as outflows. Use an atomic inventory transaction for every load, firing, unloading, packing and reallocation operation. A projectile may only spawn after successful authoritative shot consumption.

**Fixture A:**
- Given 6 identical rounds in the box and zero loaded, loading 1 into each of main, auto-left and auto-right yields box = 3, loaded = 3, shots fired = 0.
- When the main gun fires once, box = 3, loaded = 2, fired = 1. Conservation = 6.
- When main reloads once, box = 2, loaded = 3, fired = 1. Conservation = 6 (initial supply plus no resupply = 6, so check corrected ledger: box 2 + loaded 3 + fired 1 = 6).

**Fixture B (concurrent demand):**
- Given exactly 1 compatible round in reserve and two simultaneous empty-turret reload requests, exactly one load succeeds. Reserve ends at 0; other turret remains empty; no item duplication.
- Which turret wins is a **PROPOSED/OPEN priority policy**, not a decision Claude may invent.

**Fixture C:** If the gunner dismounts after one round loads, that round remains in the weapon chamber; the main gun becomes inoperable but ammo is not refunded/doubled. A packing operation must account for it exactly once.

This is the level of specificity expected for **every** complex system. The same exact fixtures are eventually implemented as tests next to the code. A user need not read a code diff to confirm core semantics.

## Build-ready gate

A subsystem earns `BUILD_READY` only when:
- All owner-rule conflicts are resolved or explicitly and safely deferred outside this milestone.
- Every touched persistent entity has an ID, owner, serializer and transfer contract.
- Every touched mathematical operation has complete equations, constant set, units and fixture results.
- Gameplay failure paths and edge cases are specified.
- Test criteria are objective, not "feels good."
- A human reviewer approves the rule version and target slice.

If any check fails, output a **design-blocker report** rather than implementing an improvised approximation.
