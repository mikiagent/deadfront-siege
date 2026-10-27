# DEADFRONT | Continue the existing game, do NOT rebuild

**Status:** Proposed implementation blueprint, grounded in `main` at commit `923657262cd335fefee9126df61dd0fff4b93321` (2026-10-26 review). **Target repository:** [mikiagent/deadfront-siege](https://github.com/mikiagent/deadfront-siege). **Intended project:** existing `game/` Godot project, existing tests, assets, user saves, deployment and web pack pipeline.

> This continuation blueprint explicitly supersedes a **clean-from-scratch interpretation** of the separate documentation PRs #18 and #19. Those are candidate design references, not migration/architecture instructions for the shipped code. **Do not replace `game/`, change project roots, add a parallel engine foundation or move production to a fresh repository.**

## Read order for Claude Code

1. [00-AS-BUILT-BASELINE.md](00-AS-BUILT-BASELINE.md) | What is really present in `main`, which files own behavior, and what remains DESIGN ONLY.
2. [01-INCREMENTAL-ARCHITECTURE.md](01-INCREMENTAL-ARCHITECTURE.md) | Extension seams, where to add logic, how to avoid monolithic script growth.
3. [02-COMPATIBILITY-AND-MIGRATIONS.md](02-COMPATIBILITY-AND-MIGRATIONS.md) | Save schema 3, non-destructive upgrades, rollback and duplication hazards.
4. [03-SYSTEM-BRIDGE.md](03-SYSTEM-BRIDGE.md) | Current implementation to future behavior for each major system.
5. [04-INCREMENTAL-MILESTONES.md](04-INCREMENTAL-MILESTONES.md) | Focused C0-C13 build tickets with test gates and dependencies.
6. [05-FIRST-TICKET.md](05-FIRST-TICKET.md) | Executable coding ticket for the first in-place reliability milestone.
7. [06-REGRESSION-AND-RELEASE.md](06-REGRESSION-AND-RELEASE.md) | How to prove existing game stays playable.
8. [07-CLAUDE-CONTINUATION-PROMPT.md](07-CLAUDE-CONTINUATION-PROMPT.md) | Exact opening and follow-up prompts.
9. [08-DECISIONS-AND-RISKS.md](08-DECISIONS-AND-RISKS.md) | Owner approvals required and upstream contradictions.
10. [data/code-map.json](data/code-map.json) | Machine-readable file ownership, existing work and forward migration notes.

## Non-negotiable starting point

- This is **the existing game**. Preserve `game/project.godot`, its `ShellLoader`, `InputSetup`, `Data`, `Game`, `World`, `TouchControls` autoloads, `game/scenes/main.tscn`, scenes and asset references.
- Existing `SaveGame` uses `user://save_1.json`, `SaveMigrations.CURRENT_SCHEMA == 3`, world/island state, equipment inventory extras, pets, buildings, cargo, skill state, offline farming and older migration paths. Continue those records. DO NOT replace saves with a new generic `entities` root just to fit the rebuild blueprint.
- `game/scripts/items/ItemStack` and `Inventory` currently store item def IDs, levels, per-stack `attributes`, flags and durability, not comprehensive unique object identities. Add *compatible optional fields* only when demanded by a specific feature and migration.
- `game/scripts/items/crafting.gd` already plans ingredient consumption, weighted crafted levels, and uses primary material attributes for output. Extend trait fusion within that behavior and protect all legacy recipes.
- `Player.mount`, `Player.dismount`, `PetRecord`, `Creature` and the creature's mount socket exist. Add NPC crews/platform hardpoints later, not an unrelated mount engine.
- `FieldCatapult` exists as a placed, Player-operated weapon with real ammo consumption; keep that behavior, extract a shared launch service/ability and layer a mobile variant instead of transplanting a complete stationary 3x3 catapult onto a dino.
- `World` already handles real islands, instability, cargo warp, home building cache, T-stones and saves. Treat design-only safe-home migration, boat shipping and frontier PvPvE as **future additions**, not silently shipped features.

## Feature authority

**Current code and tests** prove existing behavior. **Owner confirmed design** in `docs/game-design/decisions.md` defines intended future behavior. When they disagree, use a deliberate opt-in migration and acceptance tests. Research/ideas and candidate mathematical constants in PR #19 remain `PROPOSED` unless the owner approves them.

Change rule status is per behavior: `EXISTING`, `PARTIAL`, `DESIGN_ONLY`, `PROPOSED`, `OWNER_APPROVED`, `IMPLEMENTED`, `VERIFIED`. Never call a documentation draft implemented.

## First priority

**C0, compatibility and regression safety**, then **C1, an approved material-lot/trait fusion vertical slice**. C0 is about protecting existing players and establishing evidence; C1 transforms the existing crafting system rather than reimplementing it. Do not deploy as a side effect of reviewing documentation.

## Relationship to other documents

- `HANDOFF.md`, `GAUNTLET.md`: production workflow and current architecture, but may reference historical commit. Always re-read actual `origin/main`.
- `docs/game-design/README.md`, `decisions.md`, `audit-and-open-questions.md`: intended future rules and open product decisions.
- `docs/game-design/02...` through `25...`: deep domain drafts for features.
- [Separate rebuild blueprint PR #19](https://github.com/mikiagent/deadfront-siege/pull/19): optional formula and long-term domain model reference only. Its `M0-FOUNDATION` *fresh-project* task and proposed new snapshot schema **must not be executed** against current production code.
