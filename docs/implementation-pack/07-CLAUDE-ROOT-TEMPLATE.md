# Fresh repository CLAUDE.md template

**Status:** This is **not** a root-level `CLAUDE.md` for the existing DEADFRONT build. Copy/adapt this file to the **new project's root** only when choosing to build from scratch. Automatic loading in the existing repo could interfere with current shipping work.

---

# DEADFRONT coding instructions

You are implementing an original prehistoric survival, civilization and expedition game. Do not improvise game-design rules.

## Start-of-session reading

Read:
1. `docs/implementation-pack/00-NORTH-STAR.md`
2. `docs/implementation-pack/01-SYSTEM-MAP.md`
3. `docs/implementation-pack/03-EXECUTION-PROTOCOL.md`
4. The active task ticket and its exact `BUILD_READY` approved spec paths.

Read `docs/game-design/decisions.md` only for the rule IDs required by the task. Read dependent chapters and interfaces on demand. Avoid loading the full historical corpus.

## Authority

Explicit current owner decisions > confirmed decision register > owner-approved versioned subsystem specs > draft chapters > historical research/old implementation. When specs conflict, report the exact conflict. `OPEN` and `PROPOSED` are not authorization to code arbitrary behavior. Stop on gameplay blockers.

## Coding behavior

- Godot 4.7.1, typed GDScript, deterministic testable domain functions, versioned saves, stable unique IDs. Follow latest platform target task; do not assume an old shipping gate.
- Keep one owner for each item, human, creature, structure and cargo record. Inventory, crafting, firing, seat transfers and ownership changes must be atomic and idempotent.
- No code that makes protected home raidable or bypasses individual equipment level gates.
- Do not implement fake remote player authority, offline raids, real money or monetization just to fill missing docs.
- Implement one bounded ticket, its contract tests and a visible playable outcome. Run the declared smoke/headless/visual gates and report exact results.

## Before writing code

State: task goal, confirmed rules with IDs, exact spec versions, dependencies, invariants, formulas, fixtures, unknowns, files to change, tests and out-of-scope. On missing essential spec, create a concise design blocker report.

## At completion

Report: changed files, actual commands/tests, test outcomes, visual evidence, assumptions, migration impacts and remaining risks. Never claim "implemented" when only docs exist or "verified" when no playable test ran.

---

This root template and `04-CLAUDE-BOOTSTRAP-PROMPT.md` serve different purposes: the template is persistent project behavior; the bootstrap prompt is an initial one-time scoped assignment.
