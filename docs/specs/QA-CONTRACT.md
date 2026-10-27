# DEADFRONT | Deterministic specification and verification contract

**Scope:** Tests for the candidate technical blueprint and future Claude implementation. Numerical values marked candidate remain evaluation examples, not final balance.

## Test taxonomy

**Pure domain unit:** formulas, quality caps, trait origin merges, level gates, RNG draws. **Property/fuzz:** asset conservation, unique ownership, correct role occupancy and commands replay. **Integration:** import/export, collisions, animation, worker routing, screens, clean saves. **Migration:** old schema snapshots to future explicit version. **Visualization:** screenshots at the product's selected viewport, real user input. **Server-only future:** security of PvP/trade/real-time capture and clocks.

## Universal invariants (check after *every* seeded event)

1. Entity ID globally unique, never reused. Actor exists in exactly one physical location/status.
2. No item stack negative, no destroyed item equipped, no same unique building packaged and placed.
3. No resources produced by a work order without recorded input + labor + source limits.
4. Actor personal skill/XP never shared solely because avatar switches.
5. `item.equip_required_level > human.level` => equip command always denied.
6. Private HOME cannot be an attack/raid target.
7. Consecutive command_id replay leaves canonical state unchanged and returns same receipt.
8. Work tool durability never passes below 1 due to automated normal labor.
9. Food freshness is monotonic nonincreasing before an explicit cooking/transform into a **different** item; no rotten item becomes edible by move.
10. Material origin contributor occurs once in one output lineage even when split/reprocessed; minus traits cannot vanish implicitly.
11. For each shared ammo ledger, loaded+reserve+fired+lost+transferred_out = initial+resupplied (per ammo definition and accounting interval).
12. Gunner seat empty => crewed gun cannot shoot; automatic turret needs a compatible valid mechanism.
13. Seat driver human ID cannot equal gunner ID; human actor cannot exist in two seats/jobs simultaneously.
14. A disembarked player does not receive an automatic free companion slot without reconciliation.
15. After departure homebound, boat/crew/cargo not targetable; dock assets still targetable by their own rules.
16. 72h ransom case acts on trusted UTC epoch, exact boundary; pay-before-expiry returns experience/EV, unpaid claim resets earned progression only.
17. No active raid ability inferred from a high-level or rich private home.
18. Created player-facing effects derive from actual occupied material components, ingredient signatures and persisted data, not tooltip-only invented stats.
19. Every unknown schema load aborts with saved backup unmodified.
20. No gameplay constant unreviewed and labeled PROPOSED is silently shipped as owner-approved.

## Golden fixture catalog (PROPOSED)

| Fixture ID | Operation | Expected |
|---|---|---|
| FND-001 | transfer 2 fiber +1 stone from 5/3 | source 3/2; escrow 2/1; retry idempotent |
| CHR-001 | level20 equip level21 gear | denied |
| CHR-002 | body switch veteran60 to descendant1 | tribe unlock retained; descendant can't enter PvPvE |
| ISL-001 | paid move with installed 8 stone,5 planks | exactly 8/5 in salvage-only vault |
| MAT-001 | +800bp Resilient + +400bp same trait | candidate +900bp if cap>=900 |
| MAT-002 | Resilient+ + Brittle- | both signs conserved |
| INV-001 | bag cap 30kg, load22kg, add9kg | denied and no loss |
| FOD-001 | raw 12h at normal rate for 6h | freshness=50%; remaining 6h bag or 12h at 0.5 rate |
| CRF-001 | 2 prepared ribs + catalyst1 -> block1 | 2 consumed, catalyst 1 consumed, output1 |
| BLD-001 | package→redeploy built unique room | same structure ID, maker, traits |
| TRB-001 | 3 residents,4 beds, recruit 1 | occupancy=4; another denied |
| GEN-001 | parental D 60/80, delta+4 | offspring D74, level1 no earned skills |
| WRK-001 | durability3, 1 spent per ore, stop at1 | at most 2 jobs |
| DIN-001 | dino parent IV60/80, delta+3 | offspring IV73 |
| MNT-001 | 1 composite rider/dino follower, 2 singles | exactly 3 follower slots |
| CBT-001 | base100, attribute50, armor20%, favorable+15% | 92 HP |
| PHY-001 | 930kg load,1000kg comfort | candidate mobility multiplier 0.816 |
| WPN-001 | component quality .8, skill workmanship .6, station1 | quality .77, multiplier1.135 |
| SGE-001 | 6 bolts, load 3, fire1 | reserve3, loaded2, spent1 |
| PLT-001 | no gunner, autos loaded | crewed cannot fire; legal autos can |
| LOG-001 | boat cap120, harbor cap100 | effective capacity 100kg |
| ECO-001 | sale 1000, 3% tax | buyer debit1000, seller credit970, treasury30 |
| PVP-001 | captive captured epoch1000000 | expiry1259200, pay 1259199 accepted, pay 1259200 denied |
| UX-001 | Sit 20s exhaustion50 Energy40, rates .25/.2 | exhaustion45 Energy44 |
| TUT-001 | tutorial step event replay | no duplicated reward |
| OPS-001 | build hash X served hash Y | release gate fails |

## Property generator

Use a seeded deterministic random sequence and generate 10,000 operations over 20 actors, 50 lots, 10 inventories and 8 structures (candidate QA workload), intermix splits, transfers, crafting, packing, save/load and attempted illegal operations. Verify invariants after every command. Log first failing seed, command and minimal reproduction. Build importable replay script from fixture JSON.

## Serialization golden

Canonical IDs and sorted maps, rule_version, last_utc and snapshot checksum. Serialize→deserialize→serialize must be semantically identical (byte identity optional only if canonical encoder implemented). Crash before transaction journal commit must not apply, crash after must apply once. Tampered/corrupted files do not overwrite older good backup.

## Visual/interactive evidence

An accessible UI must be usable from real inputs. Headless Godot `--headless` import, tests and `tools/smoke.sh` from old repository are known reference tests, but **new project's test paths are to be created in M0**. Do not claim old test pass proves new project compliance. Test initial desktop Chrome 1600×900 and touch profile 390×844 **only as candidate coverage** until owner locks the actual platform target. Inspect true pixels, tooltip legibility, collision and animation.

## Definition of spec conformance

No unspecified discrepancy in golden values, ownership, authorizations or state machine outcomes. If formula constants change, bump balance ruleset version and regenerate goldens. Player impression can require further tuning, but failing gameplay policy is not a subjective visual judgment.
