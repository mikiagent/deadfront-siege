# M0-FOUNDATION / core transaction worker

You are one worker in a strictly isolated M0 proof. Work only on the
branch and worktree supplied by the superplan. Do not create a browser,
open a visible Godot window, use desktop control, deploy, push, merge,
or delegate to another agent. Run Godot only headlessly.

Read before editing:
- AGENTS.md
- docs/specs/README.md
- docs/specs/MASTER-CONTEXT.md
- docs/specs/ARCHITECTURE.md
- docs/specs/REGISTRY.md
- docs/specs/MILESTONES.md (M0 only)
- docs/specs/QA-CONTRACT.md
- docs/specs/systems/00-identity-persistence.md

Implement only the engineering-only M0 core in a NEW isolated Godot
project rooted at deadfront-rebuild/. Do not touch game/, hosting/,
existing top-level application files, legacy tests, assets, deployment,
or any gameplay system. Use Godot 4.7.1 typed GDScript only; no C#.

Deliver the smallest deep modules needed for:
1. Stable, non-recycled, typed entity IDs and an entity lookup/store.
2. One authoritative owner/location reference per material lot.
3. Atomic transfer planning/commit with source revision and target
   capacity validation. A rejected transfer must change nothing.
4. A synchronous command bus whose receipt ledger makes a repeated
   command_id return the original receipt without a second mutation.
5. Deterministic tests: ID uniqueness, FND-001 in-memory transfer and
   replay, competing final-unit transfers with exactly one winner, and
   a seeded 1,000-operation conservation property test.

Use only M0 fixture values explicitly required by MILESTONES/QA:
5 fiber, 3 stone, and the stated transfer quantities. Do not introduce
crafting, item balance, stats, combat, PvP, markets, or other unapproved
formulas. Test-only capacities may exist solely to prove atomic rejection
and must be named/documented as harness limits, not game balance.

Keep domain logic independent of scene nodes and avoid a god-object.
Add a concise deadfront-rebuild/README.md describing boundaries and the
exact core verify command. Add deadfront-rebuild/tools/verify_core.sh;
it must clean-import headlessly before running the typed test runner and
print a clear PASS marker only if every required core test passes.

Stay within this job's planned scope. Run the supplied verify command,
inspect its real exit status, commit only your verified change with a
clear M0-core commit message, and stop for review.
