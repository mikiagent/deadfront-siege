# System registry, owner review and build readiness

**Current certification:** **0 of 24 system contracts BUILD_READY**. All numerical balancing introduced by this blueprint is candidate **PROPOSED**. Pure engineering scaffolding may proceed in a fresh isolated proof without approving gameplay formulas.

| Domain | Stage | Rule anchors | Depends on | Key unresolved requirement |
|---|---|---|---|---|
| FND | DRAFT / engineering prototype permitted | TRIBE-01, HOME-03 | — | ID/cross-island ownership migration contracts |
| CHR | NEEDS OWNER DECISION | LVL-01, LVL-02, ATTR-01/02, LVL-03 | FND | XP/IV/EV/growth/level thresholds |
| ISL | NEEDS OWNER DECISION | HOME-01..04, WORLD-01/02, PVP-01 | FND, INV, BLD | reset recovery conflict, pricing, evacuation |
| MAT | NEEDS OWNER DECISION | MAT-01..03 | FND | distributions, signed fusion caps, trait transfer |
| INV | NEEDS OWNER DECISION | LVL-02, HOME-03, BUILD-03 | FND, MAT, CHR | exact stack equivalence and cargo capacities |
| FOD | NEEDS OWNER DECISION | FOOD-01/02 | FND, INV, MAT | shelf lives, buff caps, offline clock |
| CRF | NEEDS OWNER DECISION | CRAFT-01..03 | INV, MAT, CHR | recipe quantities, station gates, output scaling |
| BLD | NEEDS OWNER DECISION | BUILD-01..03, WORLD-02 | INV, CRF, MAT, WRK | refund, room bonuses, packed lifecycle |
| TRB | NEEDS OWNER DECISION | TRIBE-01..05 | FND, CHR, INV | housing/citizen acquisition, succession |
| GEN | NEEDS OWNER DECISION | TRIBE-02/03, LVL-03 | TRB, CHR, FOD | inheritance and upbringing coefficients |
| WRK | NEEDS OWNER DECISION | WORK-01/02 | TRB, CRF, INV | scheduling, labor yield, offline policy |
| DIN | NEEDS OWNER DECISION | TRIBE-03, COMBAT-03/04, MOUNT-01 | FND, CHR, CBT | species compatibility and tame/trait odds |
| MNT | NEEDS OWNER DECISION | PARTY-01, MOUNT-01/02, PLATFORM-01 | DIN, TRB, CHR | 3-slot/avatar accounting, crew seat orders |
| CBT | NEEDS OWNER DECISION | COMBAT-01..08, ARMOR-01 | CHR, INV, DIN | order of resolution / six-mode balance |
| PHY | NEEDS OWNER DECISION | COMBAT-09..11 | CBT, DIN, MNT | load/stomp mass and pounce thresholds |
| WPN | NEEDS OWNER DECISION | CRAFT-02/03, COMBAT-01/05 | CRF, CBT | full 18 recipes and progression costs |
| SGE | NEEDS OWNER DECISION | TURRET-01 | WPN, INV, TRB, CBT | primitive automatic mechanism, LOS rules |
| PLT | NEEDS OWNER DECISION | PLATFORM-01, PARTY-01 | SGE, PHY, MNT, CRF | species sockets, load, ammo priority |
| LOG | NEEDS OWNER DECISION | LOG-01/02 | ISL, INV, WRK | departure moment, capacity, travel time |
| ECO | NEEDS OWNER DECISION | ECO-01/02, BUILD-03 | INV, BLD, TRB | currency, market pricing, dupes and taxes |
| PVP | NEEDS OWNER DECISION | PVP-01..05, LVL-01 | ISL, LOG, CBT, SGE | raids, local bracket fairness, ransom price |
| UX | NEEDS OWNER DECISION | UX-01, FOOD-01 | FND, INV, CHR | input/shortcuts, rest rates, target platform |
| TUT | NEEDS OWNER DECISION | ECO-01, LVL-01 | CHR, ISL, MAT, CRF, DIN | first hour pacing and actual milestones |
| OPS | NEEDS OWNER DECISION | ECO-02, PVP-03 | FND, UX, PVP | platform, online moderation, live balance |

## Existing source chapters

`docs/game-design/` currently includes 02,03,04,05,06,07,08,11,12,15,16,22,23,24,25. Missing planned source chapters include 01,09,10,13,14,17,18,19,20,21. This blueprint supplies *new candidate specs* for those gaps; it does **not** retroactively assert old planned files exist.

## Blocker categories

- **BLOCKING CORE:** Identity/save schema, lot stacking/consumption, XP/gear gate, crafting calculation, first playable recipe list and first playable creature data.
- **BLOCKING LATER:** Tribe childbirth mechanics, worker production, home upgrades/unstable resets, armor combat tuning, mobile siege, economy and real PvPvE.
- **DESIGN CONTRADICTION:** WORLD-01 reset salvage to vault vs newer prefab reference suggesting abandoned structures/materials are lost (WORLD-02); home-move 100% refund remains intact.
- **IMPLEMENTATION EVIDENCE:** Existing code for crafting/combat/mounts is reference only; its current behavior is not proof a proposed formula is approved or feature fully implemented.

## Certification protocol

Owner reviews exact rule IDs and balance sheet; design lead records `approved_rule_version`, numerical goldens and external contract versions; independent QA checks fixtures; only then stage becomes BUILD_READY. No certification by a model's self-assessment.
