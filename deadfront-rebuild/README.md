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

It deletes `.godot/`, clean-imports headlessly, runs five typed suites (identity,
transfers, the FND-001 fixture, idempotence, the seeded property run), and
prints `M0 CORE VERIFY PASS` only if the import succeeded, no Godot script error
appeared, every declared suite actually ran, the runner reported
`0 failures`, and it printed its own PASS marker. Logs
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
  It also carries the minimal M0 `owner_id` authorization fixture (the actor
  allowed to spend from it). There is no role/tribe/permission model.
- `domain/inventory/ledger.gd` — collections + lookups + derived totals only.
  Rules live elsewhere; this is not a god-object.
- `application/transfer_command.gd` — command with `command_id`,
  `expected_source_revision` and per-definition lines.
- `application/transfer_planner.gd` — one entry point, `execute()`, which
  validates (ids, authorization, quantities, revision, supply, capacity),
  normalizes lines, then applies. Validation is private: no caller can hold a
  plan and commit it later. The apply step re-checks every revision and every op
  against the live ledger before its first mutation.
- `application/command_bus.gd` — `execute()`: ledger hit returns the stored
  receipt; otherwise planner execute → record. Rejections are recorded too.

### Atomicity

Validation precedes every mutation, so a rejected transfer performs no mutation
at all: no partial debit, no orphaned split lot, no revision bump. A plan held
across another mutation is refused by the same re-check, so a stale plan cannot
partially commit. A moved *portion* of a lot becomes a new lot ID carrying the
source lot's provenance (IDs are never reused and a lot never has two owners); a
whole-lot move keeps its ID.

### Lines, authorization

Command lines are normalized per definition to **one op per source lot**: a lot
is either moved whole or split exactly once, so repeated lines can never drain a
lot to zero (repeated `fiber 1` three times equals one `fiber 3` line and yields
the same state). The only authorization rule is the fixture one FND requires: an
actor may move material **out of an inventory it owns**; an unowned inventory is
nobody's to spend from (default deny). Putting material *into* an inventory does
not require owning it — FND-001 moves A's goods into escrow.

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
(FND-001): 5 fiber, 3 stone, transfer 2 fiber + 1 stone. The fixture lives in
`tests/fixtures/fnd_001.json` so expectations can be reviewed (and later hashed)
without reading GDScript.

## Tests

| Suite | Proves |
|---|---|
| `tests/identity_test.gd` | typed unique IDs, no recycling, lookup + duplicate refusal, allocation order |
| `tests/transfer_test.gd` | FND-001 transfer, replay, provenance, oversized/capacity/stale-revision/unauthorized atomic rejection, unowned-source deny, repeated-line normalization, never-zero-a-lot drain, stale-plan refusal, competing final unit (one winner), single location per lot |
| `tests/fnd001_fixture_test.gd` | FND-001 driven from `tests/fixtures/fnd_001.json`: exact per-inventory quantities, provenance, totals, receipt count, T1 replay inert, rejected T2 inert |
| `tests/idempotence_test.gd` | reused command_id returns the original receipt even with a different payload; rejected IDs stay sticky; distinct IDs both apply; competing same-revision transfers |
| `tests/property_test.gd` | seeded 1,000-operation conservation on four seeds (`0x5EED0001` primary, plus `0x5EED0002`, `0x5EED0003`, `0xC0DE`), no negative/empty/homeless lots, capacity respected, 200-command replay inert, no recycled lot identity |

The PRNG is a local 32-bit LCG (high bits used for draws) with recorded seeds,
because the QA contract requires reproducible seeds and treats engine PRNG
details as unapproved. The workload is weighted (about 70% valid transfers) and
forces each guard on purpose — stale revision, over-capacity target, oversized
quantity — so rejections are exercised deterministically rather than by luck.
The run prints its commit/reject mix and rejection reasons so the generated
workload is auditable.

## Assumptions

- `# ASSUMPTION:` the only authorization rule is source-inventory ownership
  (`Inventory.owner_id`, set at fixture construction). Roles, tribes, shared
  storage and escrow policy are M1+ and deliberately absent; target ownership is
  never checked.
- `# ASSUMPTION:` command lines are summed per definition and executed as one
  op per source lot. Which lot a definition draws from is lot-ID order within
  the source inventory.
- `# ASSUMPTION:` sequence numbers start at 1 so a default/empty ID can never
  name a real entity.

## Not in this project (M0 continuation, other workers)

Persistence (versioned snapshot, checksum, migration, corruption recovery,
replay across reload), the scene shell, and the audit report belong to later M0
phases. Save paths and rollback depth are still OPEN in
`docs/specs/systems/00-identity-persistence.md`.
