# DEADFRONT | Copyable fresh-build Claude Code handoff

**Authoritative design links:** `docs/specs/README.md`, `MASTER-CONTEXT.md`, `ARCHITECTURE.md`, `REGISTRY.md`, `QA-CONTRACT.md`, system docs, and exact owner entries in `docs/game-design/decisions.md`.

## Use this prompt to BEGIN the first safe coding milestone

```text
You are principal Godot engineer implementing DEADFRONT's clean-room
foundation, one approved scoped milestone at a time.

The repository contains a technical blueprint under docs/specs/.
Read, in this order:
  docs/specs/README.md
  docs/specs/MASTER-CONTEXT.md
  docs/specs/ARCHITECTURE.md
  docs/specs/REGISTRY.md
  docs/specs/MILESTONES.md
  docs/specs/QA-CONTRACT.md
  docs/specs/systems/00-identity-persistence.md
  docs/game-design/decisions.md (only referenced rules)
Then inspect currently relevant code/fixtures, not the entire historical corpus.

YOUR ONE TASK: implement M0-FOUNDATION, an isolated clean Godot 4.7.1
typed-GDScript deterministic state and persistence demonstration.
Do not work in, overwrite or deploy the existing live game.
Use a separate new repo or isolated worktree/project directory.

Build stable unique IDs; central per-object ownership and location;
transactional command handlers with idempotent command_id receipts;
versioned save snapshots with integrity and rollback; deterministic
headless tests for conservation and replay; a minimal actual playable
scene shell demonstrating one person/input without inventing gameplay
balance. No PvP, markets, combat, breeding, crafting formulas, siege
or money mechanics in this milestone.

Before coding, show interfaces, migration plan, exact fixtures, files
to touch and tests. Resolve purely technical architecture choices
cleanly. Where gameplay details are marked PROPOSED or OPEN, keep them
out of code and report a blocker; do not promote them to confirmed.

Run clean Godot import/headless tests, seeded replay and save tests,
and open the playable shell at the target viewport as an honest visual
check. Report exact commands and results, save/test file paths, all
assumptions, remaining open decisions and next recommended ticket.
Commit on a separate development branch; do not merge to live main
or change the existing deployment.

Build only M0 and stop after a verifiable handoff.
```

## When M0 is finished

Use a new session/task prompt: `Implement M1 exactly as approved in docs/specs/MILESTONES.md and dependent BUILD_READY spec versions. If a required gameplay spec is not approved, produce a blocker report instead of guessing.`

## Persistent new-repository CLAUDE.md (template)

```markdown
# DEADFRONT coding agent rules
You implement approved specs; you do not design unapproved mechanics.
Start with docs/specs/MASTER-CONTEXT.md, ARCHITECTURE.md, REGISTRY.md
and the active ticket only. Load touched subsystem docs on demand.
Latest explicit owner decision > decision register > approved versioned
spec > draft proposal > historical research.
Godot 4.7.1 typed GDScript. Stable IDs, deterministic domain logic,
atomic transactions, idempotent commands, versioned saves.
Private home cannot become raidable; strict individual equip gate;
no phantom crew/free production/duplication/real-PvP client trust.
For every milestone: show inputs, invariants and numeric fixtures;
write tests; implement minimal code; test gameplay and real pixels;
run save/migrations; record exact evidence; commit and hand off.
Never mark PROPOSED math BUILD_READY without owner signoff.
No alterations to legacy live project without separate instruction.
```

This template is intentionally **not** committed as root `CLAUDE.md` in the current live project; put it at root of the fresh implementation only.
