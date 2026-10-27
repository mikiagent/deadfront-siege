# UX | Interface, interaction, rest, status and accessibility

**Stage:** NEEDS OWNER DECISION / candidate model PROPOSED. **Rev:** v0.1 2026-10-26. **Anchors:** UX-01, WORK-02, MAT-01, FOOD-01. **Dependencies:** FND, INV, CHR, FOD, WRK, MNT. **Source:** `docs/controls.md`, `docs/game-design/README.md`, `GAUNTLET.md`.

## Player fantasy, scope and non-goals
On desktop and phone, player taps/sits safely on valid ground and sees exhaustion decrease incrementally, opens detailed signed status effects, then bulk-selects items to lock, drop or destroy with irreversible confirmation.

**Confirmed owner intent:** Sleep relieves exhaustion continuously instead of at end; Sit anywhere valid gradually reduces exhaustion/restores Energy. Hover/tap status explanations show real numeric effects. Inventory batch select supports lock/drop/destroy. Current desktop Chrome is known real-visual validation target, touch support preserved, initial fresh-build export target OPEN.

**Non-goals:** No unsanctioned PvP/network authority, new modern technology, implicit destruction of safe home, copying older draft values as if confirmed, or gameplay implementation based solely on these proposals.

## Entities, typed data and ownership (PROPOSED)
ActionIntent{action_id,actor_id,target_ref,client_tick}; UiProjection{actor_vitals,selected_item_ids,tooltip_effects,rest_state,error_code}; InputProfile{keyboard_mouse,touch,gamepad}; DeviceSafeArea{insets,density}. Game rules apply in application layer, never independently in UI callbacks.

Each persistent object keeps stable identity and a single authoritative location/owner. Instances reference versioned definition IDs. Command handlers, not scene scripts, own mutations. Names and artwork do not define game rules.

## Legal actions and state machine (PROPOSED)
On Sit: check solid safe accessible land, no damage/interruption; transition standing->sitting; tick exhaustion down and Energy up continuously; taking damage or movement interrupts and commits relief already earned. On Sleep require real bed/shelter. Bulk action snapshots selected legal item IDs, confirms irreversible destroy, performs individual atomic operations or a documented partial-failure report. Tooltip fetches resolved effect formula and current values.

**Transaction contract:** command carries `command_id`, actor, expected revisions, world/territory context and ruleset hash. Check preconditions before any mutation; transitions are atomic and idempotent. Actors cannot simultaneously occupy conflicting physical roles; `Denied` exposes reason without spending resources.

## Numerical model and evaluation order (PROPOSED, not final balancing)
CANDIDATE recovery per second sitting: exhaustion_next=max(0,exhaustion-0.25*dt), energy_next=min(100,energy+0.20*dt); sleeping at tier1 bed exhaustion -1.0/s, energy +0.5/s. Affected by modifiers only if exact displayed equation matches. Use simulation ticks for live display; full duration paid upfront not permitted.

Calculate once per eligible domain event in a pure typed function; use physical units/meaningful caps, apply rounding only at explicit final steps, make all constants versioned. If a target decision conflicts with an owner rule, stop rather than deploy the numeric proposal.

## Deterministic golden examples
At exhaustion 50/energy 40, sit 20s without interruption -> exhaustion45, energy44; damage at 10s -> exhaustion47.5, energy42 and state interrupted, not rollback to 50. Sleep first 5 seconds grants 5 exhaustion relief even if abruptly awakened.

These are example expectations for the proposed algorithms. They must not be presented as product-approved balance until owner review, versioned input tables and reproducible fixture tests agree.

## UI, accessibility and interactions
Show relevant target/actor/source, action eligibility, cost/time/weight and current effect values. Present legal orders and state changes on desktop and mobile with visible disable reasons; user can inspect source trait, protected-state and ammo/cargo/crew when applicable.

## Persistence, integration, failure and exploit cases
No sit while mounted, swimming or physically obstructed without approved behavior. Tooltips must avoid tiny text/hover-only controls on touch; 64px historical touch target is reference, not automatic desktop padding. Bulk destroy must never include locked items without explicit unlock, and food decay alerts remain accessible.

All operations survive save/reload. Replaying same event/command never duplicates XP, money, lots, living actors, structures or ammunition; invalid input leaves all source reservations intact. Later server authority should enforce the same preconditions rather than trusting client scenes.

## Test and handoff checklist
1. Golden inputs give the exact stated outputs with approved constants and documented floating/fixed-point tolerance.
2. Boundary invalid/zero/max cases reject without partial mutation; include concurrent attempts, reload, death and zone change.
3. At least 1,000 seeded simulation actions satisfy inventory identity, conservation and role exclusivity properties.
4. One reachable gameplay scene shows result through real input and inspected visuals; target platform export/smoke gate passes.
5. Consumer domain contracts and save migration are updated; report concrete commands/test outcomes.

## Unresolved owner questions
Recovery numbers, actual status catalog, input layout and final desktop/mobile verification target; readability screen sizes and gamepad inclusion.

**Readiness: NOT BUILD_READY** until the owner accepts mechanics, tables and fixture values. Existing source chapter or live code is not implicit acceptance.
