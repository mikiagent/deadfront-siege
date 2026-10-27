# BLD | Blueprints, worksites, modular rooms and packageable finished structures

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** BUILD-01/02/03, CRAFT-01, WORLD-01/02, HOME-03. **Dependencies:** FND, MAT, INV, CRF, WRK, ISL.

**Source:** `docs/game-design/08-blueprints-worksites-and-building.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
Craft a kitchen blueprint; place a 3×3 worksite with valid connected doorway, deliver real treated timber, stone, wall/roof components, apply worker labor, finish a unique room with bonuses; later unload, pack and trade same room identity.

## 2. Confirmed direction and non-goals
Prefabs-first modular structures; proposed 2×2/3×3/4×4 room families and sockets; crafting menu creates blueprint, placement creates worksite, workers build from physical delivered materials. Finished buildings/turrets package as unique tradeable assets preserving maker identity, material traits and durability. Home-move dismantle refunds 100% installed materials to salvage vault.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
BlueprintInstance{id,recipe_def_id,owner}; Worksite{id,island_id,grid_origin,footprint,committed_component_lots,phase,required_work_ticks}; StructureInstance{id,creator_id,owner_id,footprint,rooms,installed_components,material_signature,condition,mode:PLACED|PACKAGED|IN_TRANSIT|SALVAGED}; Room{id,kind,enclosure_edges,doors,station_ids,ambience}.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
`preview_place`: terrain/spacing/doors/permissions; `place`: blueprint->unique worksite. `deliver`: specific quantities and signed lots reserved then committed. `labor`: progresses stage after parts available, respects construction authorization for initiating. `complete`: material-based appearance/stat resolver. `pack`: only if combat inactive, unoccupied, contents/turret ammo unloaded, and mass fits container; retain structure ID. `redeploy`: reverse transition without copy. `dismantle`: one-time salvage ledger, distinct from packaging.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
PROPOSED construction labor hours = base_stage_hours * (1 + footprint_cells/16) / clamp(1 + 0.01*worker_construction_skill,1,2), with minimum real task duration. Room valid requires roof, floor, enclosure and entrance; ambience = min(cap, sum(furniture_points*condition*trait_efficiency)). These room size and numerical formulas require approval. For home migration refund_installed_component_q = q actually delivered, exactly 100%.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
For a 3×3 kitchen footprint cells=9, base 2h, worker skill=0 -> 3.125h; skilled 50 -> 2.0833h. A valid room with furniture 10 and 5, both condition 1, cap 12 gives score 12. Pack->redeploy retains the same unique room ID and material signatures; store occupied room packing rejects.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Cannot package an occupied building, in-combat tower, loaded structure inventory, active worksite or people; no trading a live dinosaur/person as packaged structure cargo. Door connectivity verified against actual grid. Unstable reset must use approved salvage rule, not silent destruction; duplicate pack command returns existing packed instance.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Room tile/door specifications, recipe size bills, visual materials mapping, stage rates, ambience caps, packed volume/weight, partial-site refund, unstable reset conflict.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
