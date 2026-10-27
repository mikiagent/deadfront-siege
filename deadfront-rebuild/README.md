# DEADFRONT rebuild — M0 engineering proof (core)

This directory is a **new, isolated Godot 4.7.1 typed-GDScript project**. It
contains only the engineering foundation from M0 of
`docs/specs/MILESTONES.md`: stable typed IDs, one authoritative location per
material lot, atomic transfers, and a synchronous idempotent command bus. It
contains no gameplay: no crafting, stats, combat, PvP, markets, loot, creatures,
currency or balance formulas. `game/`, `hosting/`, the legacy HTML snapshots and
the deployment pipeline are untouched.

## Verify

```sh
deadfront-rebuild/tools/verify_core.sh
```

It deletes `.godot/`, clean-imports headlessly, runs the typed test runner, and
prints `M0 CORE VERIFY PASS` only if import and every required test pass. Logs
land in `deadfront-rebuild/.verify-logs/`. Godot is found at
`$GODOT` (default `/Applications/Godot_mono.app/Contents/MacOS/Godot`). The
script sets `HOME` to a project-local scratch dir because Godot derives `user://`
from `HOME`, which is not writable in sandboxed runs.

The superplan gate wraps it:

```sh
bash docs/orchestration/dsc/gates/verify_m0_phase.sh core
```

## Boundaries

| Layer | Path | May do |
|---|---|---|
| Domain | `domain/` | pure data + invariants; no scene nodes, no `Input`, no rendering |
| Application | `application/` | command objects, planning/commit, receipt ledger |
| Tests | `tests/` | deterministic headless suites |

- `domain/identity/entity_id.gd`, `entity_store.gd` — typed IDs `kind:seq`; the
  store is the only allocator and only counts forward, so an ID is never reused
  for a different entity. Lookup and per-kind sorted listing live here.
- `domain/identity/actor.gd` — an ID + label only. M0 has no character state.
- `domain/inventory/location_ref.gd` — the single authoritative owner/location
  reference (InventorySlot / Equipment / World / Transit / Prison / Consumed).
  Immutable; there is deliberately no second "owner" field anywhere.
- `domain/inventory/material_lot.gd` — `id`, `def_id`, `quantity`, opaque
  `provenance`, one `location`, `revision`.
- `domain/inventory/inventory.gd` — a place that holds lots; membership is
  **derived** from lot locations, so ownership cannot desync from a second list.
- `domain/inventory/ledger.gd` — collections + lookups + derived totals only.
  Rules live elsewhere; this is not a god-object.
- `application/transfer_command.gd` — command with `command_id`,
  `expected_source_revision` and per-definition lines.
- `application/transfer_planner.gd` — `plan()` validates (supply, capacity,
  revision, ids) and mutates nothing; `commit()` applies an accepted plan.
- `application/command_bus.gd` — `execute()`: ledger hit returns the stored
  receipt; otherwise plan → commit → record. Rejections are recorded too.

### Atomicity

Validation happens entirely in `plan()`, so a rejected transfer performs no
mutation at all: no partial debit, no orphaned split lot, no revision bump. A
moved *portion* of a lot becomes a new lot ID carrying the source lot's
provenance (IDs are never reused and a lot never has two owners); a whole-lot
move keeps its ID.

### Idempotence

`CommandBus` keys receipts by `command_id`. A repeated ID — accepted or
rejected — returns the original `Receipt` object and touches nothing. There is
no global revision counter, so two competing commands that both read the same
`expected_source_revision` resolve exactly one winner: the second is rejected
with `REVISION_MISMATCH`.

### Harness limits, not game balance

Capacities exist **only** to prove atomic rejection and are labelled
`HARNESS LIMIT` where used:

- `tests/transfer_test.gd` — a 1-unit escrow.
- `tests/property_test.gd` — inventories 7 (12 units) and 8 (20 units).

Fixture quantities are exactly the M0 ones from `MILESTONES.md` / `QA-CONTRACT.md`
(FND-001): 5 fiber, 3 stone, transfer 2 fiber + 1 stone.

## Tests

| Suite | Proves |
|---|---|
| `tests/identity_test.gd` | typed unique IDs, no recycling, lookup + duplicate refusal, allocation order |
| `tests/transfer_test.gd` | FND-001 transfer, replay, provenance, oversized/capacity/stale-revision atomic rejection, competing final unit (one winner), single location per lot |
| `tests/property_test.gd` | seeded 1,000-operation conservation, no negative/empty/homeless lots, capacity respected, replay inert, no recycled lot identity |

The PRNG is a local 32-bit LCG (high bits used for draws) with recorded seed
`0x5EED0001`, because the QA contract requires reproducible seeds and treats
engine PRNG details as unapproved. The run prints its commit/reject mix and
rejection reasons so the generated workload is auditable.

## Assumptions

- `# ASSUMPTION:` M0 has no permission model; a valid `actor_id` may move
  material between the two inventories it names. Authorization is M1+.
- `# ASSUMPTION:` sequence numbers start at 1 so a default/empty ID can never
  name a real entity.

## Not in this project (M0 continuation, other workers)

Persistence (versioned snapshot, checksum, migration, corruption recovery,
replay across reload), the scene shell, and the audit report belong to later M0
phases. Save paths and rollback depth are still OPEN in
`docs/specs/systems/00-identity-persistence.md`.
