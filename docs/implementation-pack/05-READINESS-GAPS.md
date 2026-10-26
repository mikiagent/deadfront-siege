# DEADFRONT | Design-to-code readiness register (2026-10-25)

**Scope:** Priority gaps found in current design documents. This is not a replacement for `docs/game-design/audit-and-open-questions.md`, which has the full owner questionnaire. A rich prose draft is not the same as an approved executable contract.

## Why the current library is not yet a complete coding contract

- `docs/game-design/README.md` explicitly warns that many chapter drafts and their formulas have not been owner-approved.
- `docs/game-design/decisions.md` records confirmed goals alongside formulas, capacity and balancing details still OPEN.
- Several numbered chapters in the intended 01..25 library do not exist yet, including 01, 09, 10, 13, 14 and 17..21. They cannot be treated as build-ready merely because the index names them.
- `AGENTS.md` documents older agent ownership and mobile-first launch instructions; `HANDOFF.md` describes a more recent desktop Chrome shipping gate. A from-scratch execution plan should not inherit both as simultaneous unqualified requirements.
- `docs/prd/durango-wild-lands-systems-prd.md` and historical plans reflect earlier project decisions. Current DEADFRONT-specific rules in the canonical v2 library supersede conflicting older research.

## Prioritized blocker matrix

| Priority | Domain / source | Concrete unresolved contract | Blocks |
|---|---|---|---|
| P0 | Global save + ownership; planned chapter 19 | Global IDs, schema versions, migrations, scene/roster ownership, atomic movement of people/items/creatures | Nearly every persistent system |
| P0 | Item lots, traits and progression; chapters 02, 05, 06 | Attribute formulas, roll distributions, stacking, trait cap/merge rules, quality scaling, item level gates and numerical fixture results | Reward, crafting, equipment, market |
| P0 | First-hour loop; planned chapter 01 | Exact onboarding progression, failure/recovery, creature/loot tiers, time-to-first-tame and initial crafting list | Full fresh-build milestone selection |
| P0 | Crafting and building; chapters 07, 08, 23 | Verified item IDs and station recipes, processed material substitutions, byproduct conservation, site labor equations, room bonus caps, packing lifecycle | Whole home economy |
| P1 | Tribe, lineage and workers; design/tribe... and planned 09, 10, 13 | Housing/population constraints, unique human scheduling, offspring IV rules, labor units/rates, nutrition effects and job priorities | Civilization simulation |
| P1 | Combat/mass/armor; chapters 15, 22, 23 | Ordered damage formulas, hit-zone armor, motion/contact mass scaling, interrupt thresholds, body geometry and aim rules | Fair combat and siege |
| P1 | Animal genetics and mounts; chapters 11, 12 | Actual eligible species, tameability reconciliation, solo vs composite party slot ownership, trained driver safety and skill requirements | Expanded mounted gameplay |
| P1 | Platform saddles and turret crew; chapters 24, 25 | Max topology is known (1 crewed, 2 auto, 1 ammo box), but capacity units, socket geometry, auto primitive mechanisms, ammo priority, NPC command and all mass/recoil coefficients remain unapproved | Living siege platform |
| P1 | World lifecycle and recovery; chapters 03, 04 | Unstable reset cadence, how occupants/stored goods evacuate, salvage percent, exact protected-home migration and rollback | Island reset reliability |
| P2 | Optional PvPvE; chapter 16 | Authority model, fair-region classes, raids, anti-exploit resources, ransom formula, offline expiry/notification/claim, settlement loot | Real online frontier |
| P2 | Economy/trade; planned chapter 17 | Trade authority, pricing and sinks, tax/listing mechanics, crafted prefab uniqueness, offline market settlement | Player economy |
| P2 | Platform and interface; planned chapter 18, HANDOFF | First live target (desktop Chrome vs native mobile), touch acceptance, release CI, performance budgets, accessibility | Final ship definition |

These are **design decisions**, not instructions to postpone foundational engineering. A programmer can build an isolated ID allocator or render a controlled creature model without deciding the final market economy; an integrated trait-crafting economy cannot claim design fidelity until its formulas are approved.

## Concrete next steps to make the pack complete

1. Approve the north star and the precedence / status convention.
2. Create and review `docs/specs/foundation/identity-and-save.v1.md`, with schema migration examples.
3. Lock one micro-slice's material/item/recipe/equipment rules, including numeric fixtures. In parallel, inventory existing art and data for the slice.
4. Produce `docs/specs/<domain>/<system>.v1.md` from the contract template, backed by numbered decision entries and owner approval.
5. Store machine-readable tables for constants, curves, recipes, creature profiles and expected numerical fixture input/output, rather than asking Claude to infer them from prose.
6. Generate one milestone ticket per approved contract and use the bootstrap prompt, followed by small context-loaded coding tasks.

## Success criterion for documentation

The test is simple: Give two isolated implementation agents the same `BUILD_READY` spec and numeric fixture set. Both should produce compatible public data contracts and the same gameplay outcomes within declared numerical tolerance, regardless of their internal code style. If they disagree on important gameplay behavior, the spec is not precise enough yet.
