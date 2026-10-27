# MAT | Harvest lots, signed traits and two-primary fusion

**Stage:** NEEDS OWNER DECISION / numerical rules PROPOSED. **Revision:** candidate v0.1 (2026-10-26). **Owner rule anchors:** MAT-01/02/03, CRAFT-03. **Dependencies:** FND, INV, CRF.

**Source:** `docs/game-design/05-material-level-traits-and-loot.md`. Confirm binding intent against `docs/game-design/decisions.md`. Nothing here asserts current implementation or owner-approved balancing.

## 1. Player experience and outcome
A Resilient positive bone rib and a Brittle negative rib combine into a reinforced block retaining both traits. Fusing two resilient ribs strengthens the single Resilient effect with diminishing returns, not unlimited duplication.

## 2. Confirmed direction and non-goals
Nearly all gathered lots have meaningful drawbacks and rare positives. Two eligible material lots can combine into one advanced composite inheriting BOTH signed input signatures, with bounded duplicate-ID effects and source provenance. No global free purification. Material level and trait effects remain distinct.

**Non-goal:** Do not silently resolve OPEN policy or simulate online authority/client monetization. Only the listed exact scenario is a candidate design, not blanket approval of related features.

## 3. Data and ownership contract (PROPOSED)
MaterialLot{id,def_id,level,qty,source_id,source_roll_id,trait_contributors:[{trait_id,sign,magnitude_bp,origin_lot_id}],process_stage}; TraitDef{id,allowed_sources,roles,sign,max_bp}; FusionDef{required_input_defs:[2],stage_in,stage_out,catalysts,output_def}. Signature stored canonical by origin ID + trait ID.

Every persistent record is referenced by one stable typed ID and mutated through one owner aggregate; all cross-entity transfers use `command_id`, authorization, capacity guard, atomic commit and saved idempotence receipt. Serialize definitions separately from instances, never by display name.

## 4. Commands, states and reference algorithm (PROPOSED)
Harvest rolls one signed trait signature with deterministic seed/counter; no reroll on split or move. Fusion validates two recipe-compatible lots and catalyst, settles reservations, consumes exactly one from each, computes canonical *union by origin_lot_id+trait_id*, groups contributors per display trait, applies same-ID curve once, assigns output source lineage, commits. A source already represented twice is counted once. No generic same-stage infinite recursive fusing.

**State machine convention:** `AVAILABLE -> RESERVED -> COMMITTED` for one-off transfers; `FAILED` releases reservations, and retries with same ID return the prior receipt. The named domain state transitions above override this generic transaction lifecycle. No actor may occupy incompatible physical assignments concurrently.

## 5. Mathematics and units (PROPOSED)
PROPOSED positive/negative roll: 90% negative, 8% positive, 2% neutral (owner requires near-all negative; probabilities OPEN). Same trait contributions magnitudes sorted descending: effective_abs_bp = min(cap_bp, m1 + round_half_up(0.25*m2) + round_half_up(0.125*m3) ...), apply negative sign separately. Positive and negative of same trait ID remain separate signed entries rather than cancelling invisibly. Output level = min(recipe_level_cap, floor((level_a+level_b)/2)), absent approved skill refinement.

**Computation contract:** use explicitly typed units and nonnegative checks, clamp bounds before mutation, compute derived values in a deterministic order, use `round_half_up` only where indicated. All gameplay constants must move to a `ruleset_version` balance catalog before BUILD_READY; pure calculations operate without scene nodes.

## 6. Deterministic golden fixtures
A Resilient +800bp and Shock-Absorbent +600bp yield both +800bp and +600bp. Resilient +800bp fused with Resilient +400bp yields +900bp (cap >=900). Brittle -500bp and Resilient +800bp both persist with their original signs. Level 41 and 40 fused with cap 60 -> level 40.

Expected fixture outputs are for **candidate mechanics**, and must be updated alongside any approved balance adjustment. Fail tests if results or changed entity IDs differ.

## 7. UI / player feedback
Show legal action, costs, signed changes, affected entity/lot IDs where relevant, immediate updated counters, visible disabled/error cause, and confirmation for irreversible loss. Mouse and touch use the same validated application command, not separate gameplay shortcuts.

## 8. Dependencies, save/migration and exploit guardrails
Splitting a lot preserves identical roll and origin; recombining copied ancestry never duplicates an origin. Different lot signatures cannot silently stack or overwrite a rare drawback. Source-level traits inappropriate to a finished item's slot remain traceable but mechanically inactive. Prohibit food + iron fusion absent explicit recipe. Market trades and packed structures retain lineage.

On save/load, preserve entity IDs, rule versions, reservations and timestamps; verify ownership links and no negative balances, phantom people, free XP, copied components or duplicated goods. If a domain depends on later online multiplayer, keep single-player simulation authoritative and never claim real server guarantees.

## 9. Acceptance and failure tests
- All golden fixtures above pass in deterministic headless tests with the stated parameter set.
- Same `command_id` replay (before/after save reload) produces no second reward, no second actor/item and no second debit.
- Unauthorized actor, nonexistent source, over-capacity target and invalid world/actor state reject atomically.
- A property test across at least 1,000 seeded valid operations checks ID uniqueness, no negative counts and matching in/out ledgers.
- Relevant UI action is reachable on the target viewport, and real scene behavior and visuals are inspected, not inferred from logs.

## 10. Owner review blockers (OPEN)
Approve roll rates, permitted trait pools, magnitude ranges, same-ID diminishing factor and cap, process-stage DAG, output levels/skill effects, storage compression/provenance retention. All numbers here PROPOSED.

**Readiness:** NOT BUILD_READY. Owner approval, final machine-readable tables and updated golden outputs required before productive gameplay code is authorized.
