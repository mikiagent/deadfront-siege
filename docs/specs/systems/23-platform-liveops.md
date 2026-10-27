# OPS | Release target, online staging, telemetry and fair live operations

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** ECO-01/02, PVP-03/05, HOME-01. **Dependencies:** FND, UX, ECO, PVP. **Source:** `docs/engine-decision.md`, `HANDOFF.md`, `GAUNTLET.md`, `docs/release/ship-readiness.md`.

## Player fantasy, scope and non-goals
The developer exports a verifiable Godot build, inspects real gameplay at target viewport, and reviews gameplay economy metrics without invalidating existing save profiles or charging users for competitive power.

**Confirmed owner intent:** Mobile compatibility is long-term direction; current project focuses desktop Chrome testing while iOS status/older plans differ. Protected home, fair progression and the possibility of non-PvP success constrain monetization and live balance; online multiplayer does not exist simply because client states suggest it.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
BuildManifest{git_sha,game_version,ruleset_hash,asset_revision,export_target}; TelemetryEvent{event_id,type,timestamp,context_no_personal_secrets}; FeatureFlag{key,version,cohort}; MigrationReport{old_save_version,new_save_version,converted_ids,warning_count}. Server future: authenticated actors, authoritative actions and privacy controls.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
For each milestone run headless compile/labs, deterministic fixture suite, save/migration roundtrip, actual desktop Chrome visual/click soak and optional mobile/touch exploratory check. Stamp build with exact hash and validate served version if using web. Online transition adds server persistence and rate limiting, anti-cheat logging and moderation before allowing player raids and real economic escrow.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE performance acceptance: median frame >=30 fps on defined baseline device, p95 input-to-feedback <=150ms offline, 0 lost/duplicated transactions in 10k seeded fuzz actions; target hardware and instrument sampling OPEN. Balance metric: non-PvP wealth accumulation must remain viable versus raid profit; measure comparable invested time and loss risk rather than arbitrarily balancing per action.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
A build tagged SHA X but served with runtime stamp Y fails ship check. 10,000 seeded transfers/crafts do not duplicate IDs or produce negative quantities. Two clients sending same purchase command ID yield exactly one transaction on authoritative server (future-only test).

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
No deployed environment claims without exact rendered evidence. No credits or monetization purchases are authorized by design documents. Retention analytics cannot include private conversations, passwords or unnecessary location. Missing server prohibits advertising functional competitive multiplayer.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Initial target platform/export, target devices/visual quality gate, online hosting/security staffing, accessibility benchmarks, telemetry privacy and monetization choices.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
