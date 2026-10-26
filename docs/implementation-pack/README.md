# DEADFRONT | Claude implementation package (proposed)

**Purpose:** Provide a bounded entry point for building DEADFRONT from scratch without stuffing every research note, historical implementation report and undecided mechanic into one prompt.

**Status:** Proposed packaging and execution method, 2026-10-25. This folder is an **adapter** over the existing design library, not a declaration that unresolved gameplay formulas are approved. Do not start a full rebuild solely from these files. No game code is modified by this proposal.

## Read order

1. [00-NORTH-STAR.md](00-NORTH-STAR.md): the game, player experience, constraints, and exclusions. Approximately one context page.
2. [01-SYSTEM-MAP.md](01-SYSTEM-MAP.md): domain graph, shared data ownership, dependencies and canonical chapter links.
3. [05-READINESS-GAPS.md](05-READINESS-GAPS.md): blockers and prerequisites before treating any system as coding-ready.
4. [02-SPEC-CONTRACT.md](02-SPEC-CONTRACT.md): the mandatory specification format for each complex mechanic.
5. [03-EXECUTION-PROTOCOL.md](03-EXECUTION-PROTOCOL.md): how a coding agent loads only relevant specs, develops, tests and reports.
6. [04-CLAUDE-BOOTSTRAP-PROMPT.md](04-CLAUDE-BOOTSTRAP-PROMPT.md): copyable entry prompt for a future fresh-build repository.

## What the agent receives per task

**Always loaded:** north star + system map + execution protocol + task ticket. **Load on demand:** only approved subsystem specs, dependencies, data contracts and directly relevant examples. **Never automatically load:** all of `HANDOFF.md`, `GAUNTLET.md`, legacy PRDs, older orchestration prompts and all chapters simultaneously.

A task ticket names one outcome, exact file paths, design IDs, prerequisites, approved algorithm version, input/output contracts, acceptance examples, target platform and required checks. It must say what is explicitly out of scope. It is not a request to invent missing rules.

## Authority and evidence

For future design intent use, in order:
1. Newest explicit owner decisions.
2. `docs/game-design/decisions.md` for confirmed rule IDs.
3. Approved and versioned system specifications, once reviewed.
4. `docs/game-design/` chapter drafts and the newer `docs/design/` workshop material.
5. Historical `docs/prd/` and `docs/orchestration/` as inspiration/reference.

For what **currently exists** in the existing Godot project, inspect code, tests, `HANDOFF.md` and `GAUNTLET.md`. They are not authority to silently change the future design. `AGENTS.md` includes older mobile/agent ownership instructions, while `HANDOFF.md` identifies desktop Chrome as the present verification gate; a fresh project must make its own explicit shipping target decision. Never present existing implementation as proof that a future mechanic is approved.

**Required labels at the rule level:** `CONFIRMED` (owner direction), `PROPOSED` (candidate solution), `OPEN` (decision required), `IMPLEMENTED` (present in code), `VERIFIED` (passed specified tests). Labels are not interchangeable. A document is `BUILD-READY` only when all behavior on its implementation path is determinate and tests have expected results.

## Definition of a finished implementation-grade spec

A programmer can answer: Who owns each entity? Which inputs are legal? What exactly changes on every operation? What are the formulas, units, order of operations, randomness seeds and rounding rules? What must never happen? What is saved? What happens at interruption, offline simulation, migration and concurrency boundaries? Which numerical fixtures prove it? What is out of scope?

If any answer matters to implementation and remains open, record a blocked decision rather than guessing. Store tunable numbers in versioned data, but do not make tuning a substitute for an agreed mathematical model.

## Scope of this pull request

This is the **scaffolding layer** for turning the current long-form design library into contracts. It deliberately does not mass-rewrite old chapters, certify unapproved balance values or start building a second game. The next design pass should graduate **one small vertical slice** and all its prerequisite specs to `BUILD-READY` before giving Claude a coding milestone.
