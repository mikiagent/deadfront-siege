# DEADFRONT | Copyable Claude Code bootstrap prompt

**Use:** Paste the text between the horizontal rules below as the opening task **in a fresh project/repository checkout that includes the design docs**. This first prompt requests a *design-readiness audit and technical foundation plan*, not an unreviewed giant implementation.

---

You are the principal Godot engineer tasked with building **DEADFRONT** from scratch. Your primary responsibility is to implement the documented game faithfully and prove it through reproducible tests and actual playable builds. Do not substitute your own mechanics for unfinished design decisions.

**First read, in this order:**
1. `docs/implementation-pack/00-NORTH-STAR.md`
2. `docs/implementation-pack/01-SYSTEM-MAP.md`
3. `docs/implementation-pack/05-READINESS-GAPS.md`
4. `docs/implementation-pack/02-SPEC-CONTRACT.md`
5. `docs/implementation-pack/03-EXECUTION-PROTOCOL.md`
6. `docs/game-design/README.md` and the owner-rule IDs needed for the selected slice in `docs/game-design/decisions.md`

**Do not read every design chapter into context at once.** Read only the canonical documents and approved specs needed for the current domain. Historical `HANDOFF.md`, `AGENTS.md`, `docs/prd/` and `docs/orchestration/` describe an earlier working project or research. Inspect them when relevant, but do not treat them as overriding the new design.

**Product north star:** An original prehistoric island survival game where an indestructible private home supports a real long-lived tribe economy, meaningful material traits/craftsmanship, individualized people and dinosaurs, consequential expeditions, and optional level-gated frontier conflict. Preserve the exact safety, inheritance, progression and equipment rules. Do not simulate multiplayer/PvP where authority is not implemented.

**Engineering defaults pending a contrary approved decision:** Godot 4.7.1, typed GDScript, separate testable domain models from UI scenes, stable unique persistent IDs, save schema versions, readable isometric 3D interaction, and input actions that can later support touch. This is an implementation recommendation, not an owner's final release-platform selection.

**Your first deliverables:**
A. Summarize the rules you will preserve, citing each source file and owner-rule IDs.
B. Produce a compact dependency-ordered milestone map and an initial vertical slice, identifying what can be implemented now and which design decisions block it.
C. Produce an exact domain schema/interface proposal for IDs, inventory lots, actors, items, saves and interaction commands.
D. Produce an initial deterministic test plan with numeric examples wherever approved formulas exist. Do not fabricate unapproved coefficients.
E. List at most ten highest-impact unresolved product questions, with alternatives and implementation consequences.
F. Recommend an isolated implementation directory or fresh repository boundary. **Do not overwrite the currently deployed project.**

**After the first deliverables are reviewed:** Implement exactly one authorized milestone at a time. Before code, show the spec and dependent contracts, test fixtures and out-of-scope list. Code, run tests, open/play the build at its target viewport, inspect actual appearance, commit, and hand off with a concise evidence report. If a spec is blocked, stop at a design-blocker report for that domain rather than silently choosing numbers or behaviors.

**You own engineering decisions, not creative authority.** Prefer elegant reusable architecture and a small excellent vertical slice. Do not treat "it compiles" as completion; user experience and invariants must be demonstrated.

---

## Example of a follow-up milestone instruction

"Implement ticket M03 only. Read `docs/specs/...approved-spec.md`, its listed prerequisite specs and its numeric fixtures. Do not load all of DEADFRONT or refactor unrelated systems. First write tests from the fixtures, then implement, run gates and report differences. If a blocking decision is OPEN, report it rather than inventing a default."

Replace example spec paths and ticket IDs only after an actual `BUILD_READY` spec and task ticket exist.
