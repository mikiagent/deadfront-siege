# DEADFRONT | Clean-room implementation roadmap and task tickets

**Status:** Proposed engineering sequence and explicit gates; game implementation is NOT authorized by document existence alone.

## Phase 0: review and architecture foundation

| Ticket | Goal | Depends on | Acceptance / stop condition |
|---|---|---|---|
| M0 | New isolated Godot 4.7.1 typed-GDScript project, test runner, core IDs, transactions and save versioning | FND engineering fields | Deterministic identity and replay tests, clean import, no live-file changes. Can be coded as architecture proof before gameplay formulas approved |
| M1 | One controllable character with interactive safe home, input abstraction and headless state | M0 + CHR/ISL/UX approved slice | Real desktop/touch controls, no home targetable damage, save/load actor identity |
| M2 | Harvestable sources, signed lots, inventory and first craft | M1 + MAT/INV/CRF owner-locked | 2 input traits propagate correctly, no duplication, player-visible trait tooltip |
| M3 | Food/rest/recovery + workstation and processing chain | M2 + FOD, UX, CRF | Online/offline spoil conversion and time-based Sit/Sleep numerical fixtures |
| M4 | One creature's complete AI/hunt/down/capture/tame loop | M2 + DIN/CBT | Real animation and collision, status, capture, unique dino save |
| M5 | Blueprint/worksite, finite human labor and home storage | M3 + BLD/WRK/TRB | Real delivered material lot traits, construction timer, saved unique structure |
| M6 | Expedition travel, three companion slots and riding | M4/M5 + MNT/ISL | Real seat and party cost, separate reach geometry, carried cargo |
| M7 | Forge and weapon eras, local body mass, barding | M3/M4/M6 + WPN/PHY | Six mode counters, processed ingredients, capped load and no free source nodes |
| M8 | Human recruitment/upbringing, workers, tradeable prefabs and economy | M5/M7 + TRB/GEN/ECO | Unique citizen production, lineage IV/XP distinct, pack/redeploy same ID |
| M9 | Boat shipping, remote PvE settlement hazard and unstable reset | M5/M8 + LOG/ISL | actual loading/departure, world reset salvage according to approved policy |
| M10 | Defense towers + crew + platform saddle on eligible giant | M6–M9 + SGE/PLT/PHY | 1/2/1 limits, shared atomic ammo, both real driver/gunner configurations |
| M11 | Frontier prototype in private simulated environment; actual PvPvE only with server authority | M8–M10 + PVP/ECO | personally level60, safe-home denial, 72h custody case, server anti-exploit and outage policy |
| M12 | Performance, accessibility, content breadth, real release | M0–M11 + OPS | approved export gate, screenshots, clean save migrations, target device profile |

**Dependency warning:** These are independently testable milestones and are not a time estimate. Do not implement M11 as actual online competitive mode inside a client-only game.

## M0 implementation ticket: engineering-only

```yaml
ticket: M0-FOUNDATION
mission: Prove an isolated Godot 4.7.1 typed-GDScript deterministic simulation architecture
inputs:
  - docs/specs/MASTER-CONTEXT.md
  - docs/specs/ARCHITECTURE.md
  - docs/specs/systems/00-identity-persistence.md
  - docs/specs/QA-CONTRACT.md
target_directory: separate new repo or isolated deadfront-rebuild/ worktree
contracts:
  - stable unique typed entity IDs and entity lookup
  - single authoritative owner/location reference
  - command_id idempotence ledger
  - transactional transfer with revision and capacity validation
  - versioned save snapshot and safe rollback on corruption
  - headless fixture runner and basic playable Godot scene shell
test_requirements:
  - same command consumed once before and after reload
  - concurrent competing reservations leave only one winner
  - schema migrator rejects unknown future version without overwrite
  - seeded randomized 1000-operation conservation test
  - Godot import/headless static smoke pass
out_of_scope:
  - actual combat, creature genetics, PvP, markets, crafting balance
  - owner-unapproved gameplay constants or final release-platform decision
owner_approval_needed_before_gameplay: true
```

### M0 required demonstration

Run one headless scenario: human A owns 5 fiber + 3 stone. Command T1 transfers 2 fiber and 1 stone to an escrow inventory, preserving unique lot provenance. Replay T1 with identical command_id does nothing. Save, reload, replay T1 again does nothing. Command T2 attempts an invalid transfer larger than remaining supply and rejects completely. Hash the final saved state and compare against a checked-in golden fixture. Scene shell can show one person and simple interaction prompt but must not invent character stats/combat UI.

## Future milestone ticket shape

`ticket_id`, `approved_spec_versions`, `task_goal`, `allowed_paths`, `inputs_outputs`, `dependencies`, `quantitative_fixtures`, `scene_visual_gate`, `migration`, `non_goals`, `definition_of_done`. A ticket is blocked when required `approved_spec_versions` are absent.

## Ship gate per milestone

1. Compile/import from clean checkout.
2. Run only correct current suite, then all domain fixtures and property tests.
3. Drive actual scene controls with real mouse/keyboard/touch when applicable.
4. Inspect screenshot/pixels at agreed display size and compare readability/geometry to visual goals.
5. Save, reload, migrate a fixture and repeat selected action.
6. Commit one bounded change and hand off exact commands, results and remaining risk.

## Branch safety

Do not rebase/overwrite existing main, historical `game/`, iOS pipeline or deployment. Use new worktree/repo and distinct game root. Existing `HANDOFF.md`/asset pipeline may be read for verified behavior but never override approved future rules.
