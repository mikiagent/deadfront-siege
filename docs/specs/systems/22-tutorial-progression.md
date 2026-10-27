# TUT | First hour, encounters, progression gates and playtests

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** ECO-01/02, HOME-04, LVL-01/02. **Dependencies:** UX, CHR, ISL, MAT, INV, CRF, DIN, CBT, BLD. **Source:** `docs/game-design/README.md`, `docs/orchestration/plan.md`, `docs/design/progression-risk-and-island-economy.md`.

## Player fantasy, scope and non-goals
A new player learns to gather flawed materials, choose a lot, make a knife, treat injury, capture a small creature, return valuable materials to a permanently safe home, and craft the first usable worksite; later generations and PvPvE stay optional.

**Confirmed owner intent:** Protected home and legitimate non-PvP progression are central. Personal levels can go to 60, rare 60+ resources remain outside high-tier home. Learning crafting and capture must be real playable mechanics; initial build favors small polished vertical slice.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
TutorialStep{id,prerequisites,required_events,allowed_zone,feedback,success_next,recovery_next}; MissionProgress{player_id,step_id,completed_event_ids}; MilestoneMetrics{time_to_first_gather,first_craft,first_tame,return_cargo,first_worksite,failures}. Tasks use event IDs, not per-frame state polls.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
Start at owned protected home. Observe gather event -> inspect at least one trait -> consume actual lot to craft basic weapon/bandage -> perform safe early combat -> inspect injury and rest -> knockdown/capture permitted starter species -> return with cargo -> spend material on worksite -> save and reload. Skip steps only when equivalent genuine events already in receipt ledger.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE pacing targets: first interact <60s, first craft <=5min, first combat <=10min, first return <=20min, first tame<=30min, first small worksite <=45min for tested baseline player; NOT owner-approved elapsed durations. Retention/engagement metrics must not favor forced loss or dark patterns. Tutorial difficulty curve constrained by time-to-kill and heal resources.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
Given a player with prerequisite first 3 events, replaying Gathered event does not grant duplicate tutorial reward. At save midway through tame step, reload resumes without re-triggering capture. An attacker attempt at novice home gets denied regardless UI quest state.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
Beginner must be able to recover from tool break, inventory full, enemy aggression and death without irreversibly losing home; no tutorial step forces PvPvE. Touch UI teaches tooltips and lot select, not hidden hover gestures.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Pacing targets, starter island/creature and full early-level recipe set, tutorial narrative/quests, first-hour death consequence, quest compensation and supported devices.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
