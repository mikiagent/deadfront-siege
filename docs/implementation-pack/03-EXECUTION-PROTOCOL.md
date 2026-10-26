# DEADFRONT | Fresh-build Claude execution protocol

**Status:** Proposed coding-agent operating procedure, not a game design rule.

## Agent context budget

Do not paste the complete 300+ KB of game design and historical handoff into one prompt. Keep a durable small root package in the repo and use filesystem reading to resolve links as work progresses.

**Session start, always read:**
- `docs/implementation-pack/00-NORTH-STAR.md`
- `docs/implementation-pack/01-SYSTEM-MAP.md`
- `docs/implementation-pack/03-EXECUTION-PROTOCOL.md`
- current task ticket
- `docs/game-design/decisions.md` entries named in the ticket

**On demand:** the single system spec being implemented, explicitly listed prerequisites, the canonical fixture and schema files, only the code/interfaces necessary for the task. Claude must quote exact rule IDs and file paths in its implementation plan. Never mix historical implementation reports into new-build design authority.

## Work in gates

**Gate D: Design completeness**
1. Verify requirements and stage labels against owner decisions.
2. Confirm dependencies and external contracts exist.
3. Mark all blocking unknowns and request a design pass when essential formulas or rules are unapproved. No gameplay implementation at this gate if blocked.

**Gate A: Architecture and interfaces**
1. Build plain domain/data types and command/event interfaces first.
2. Preserve single ownership of persistent IDs, inventory and transactions.
3. Distinguish simulation state from scenes/UI, with deterministic core functions that can run headless.
4. Define saved schema version and migration/rollback behavior before writing new persistent data.

**Gate T: Tests first**
1. Write canonical fixture tests from the spec's exact Given/When/Then cases.
2. Include invalid input, zero assets, capacity bounds, animation interruption, death, save-reload and repeated commands.
3. Add conservation/property checks for ammo, items, crafted materials, XP and labor.
4. For probabilistic mechanics, use seeded reproducible simulation and statistical bounds from the approved spec.

**Gate I: Implementation**
1. Implement only the ticket's declared paths/operations with typed GDScript.
2. Integrate through named signals/interfaces, not silent writes into neighboring systems.
3. Make all actions reachable from real player controls and leave useful error feedback.
4. Avoid speculative platform networking, market trades or PvP state that lacks authority contracts.

**Gate V: Visual and runtime verification**
1. Run project import, headless tests, smoke and targeted domain/scene tests.
2. Exercise real interactions in the declared release target, inspecting actual pixels.
3. Run save/load and identity-invariance scenarios.
4. Validate known desktop/mobile/touch constraints specified in the task; do not claim desktop Chrome testing based only on node trees.
5. Report failures and exact reproduction instructions.

**Gate H: Handoff**
1. Commit one bounded milestone with a descriptive message.
2. Report files touched, rules implemented, tests run with command/output, code assumptions, unresolved issues, and dependency contracts for next task.
3. Do not move a rule to `VERIFIED` unless tests actually passed.
4. Do not mark a feature shipped without build/export and user-reachable visual verification.

## Example task ticket

```yaml
ticket: M03-TRAIT-AWARE-PROCESSING
goal: Process one source material lot into one distinct component
target: Godot 4.7.1, typed GDScript, desktop test + preserve touch
design_rules: [MATERIAL-..., LVL-...]
spec: docs/specs/materials/processing-fusion.v1.md
dependencies:
  - docs/specs/foundation/identity-and-save.v1.md
  - docs/specs/items/material-lots.v1.md
acceptance_tests:
  - Processing correctly consumes inputs once
  - Result carries both positive and negative source signatures per approved merge rule
  - Save/reload preserves provenance and exact traits
  - Duplicate command cannot manufacture a free extra component
out_of_scope:
  - New NPC workers
  - Market listing
  - Remote multiplayer
blocked_if:
  - Fusion caps, stacking equivalence or coefficient set unapproved
```

The ticket above is illustrative only; those `docs/specs` files are future deliverables, not current paths.

## Scratch rebuild boundary

Treat the current `game/` directory as **reference implementation and test evidence**, not code to transplant blindly. Build the new product in an isolated branch or separate repository/project directory; preserve current live builds and avoid replacing `main` as a side effect of a design exercise. Reuse working algorithms/assets only after schema and licensing review. Keep versioned assets and export pipeline separate from specifications.

## Important engineering decisions Claude may make

Code organization, scene node factoring, caching, local event-bus conventions, test harness utilities, performance optimizations that preserve visible rules and clean integration details are engineering discretion.

**Decisions Claude must not invent:** world raiding safety, level gates, actual crafting yields, loot odds, genetics inheritance, economy sinks, refugee/captive ownership, person/animal duplication, companion-count rules, online-offline advantages, and final material/combat balance formulas. These need approved game-spec versions.

## Definition of done

Feature is deterministic and correct against spec, persists through save/load, is reachable through UI/input, looks and animates legibly, passes the declared target smoke and scene checks, and has an auditable handoff. Compiling alone is not done.
