# M0-FOUNDATION / persistence worker

Work only in the isolated superplan worktree. The owner permits a
visible Godot window and desktop interaction for this M0 project.
Automated tests must remain headless and repeatable. Do not deploy,
git push, merge, or delegate. The prior M0 core phase is your base;
preserve its behavior unless a real defect requires a compatible repair.

Re-read the M0 sections of docs/specs/README.md, MASTER-CONTEXT.md,
ARCHITECTURE.md, REGISTRY.md, MILESTONES.md, QA-CONTRACT.md, and
systems/00-identity-persistence.md before editing.

Implement only persistence engineering inside deadfront-rebuild/:
- A versioned snapshot containing enough M0 state to restore IDs,
  inventories, ownership/location links, revisions, command receipts,
  ruleset reference, simulation tick, and schema version.
- Canonical deterministic serialization plus an integrity checksum/hash.
- Explicit migration chain for known old schemas and rejection of unknown
  future schemas without changing the source save.
- Atomic-save behavior using a temporary file and retained last-known-good
  backup. A corrupt primary must recover from a valid backup without
  overwriting that backup; unrecoverable corruption must fail safely.
- Journal/recovery semantics sufficient for synchronous M0 transfer:
  no partial debit on failed validation and no double application after
  an interrupted/reloaded receipt.

Expand the deterministic tests and fixture data to prove the mandated
M0 scenario exactly: human A begins with 5 fiber and 3 stone; T1 moves
2 fiber and 1 stone to escrow preserving lot provenance; replaying T1
before AND after save/reload changes nothing and returns its original
receipt; oversized T2 rejects atomically. Compare the canonical final
state hash against a checked-in M0 fixture. Also prove corrupted-primary
backup recovery and future-schema rejection are non-destructive.

Do not add crafting outcomes, character progression, combat, PvP, market
systems, content balance, or approval claims. Do not touch game/ or any
legacy/deployment path. Update README and provide
deadfront-rebuild/tools/verify_persistence.sh
that first runs the existing core verification, then clean imports and
runs persistence tests headlessly with a truthful PASS marker.

Run the supplied verify command, record no invented results, commit only
this verified phase with a clear message, and stop for review.
