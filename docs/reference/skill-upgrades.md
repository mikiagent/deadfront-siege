# Durango skill point upgrades (reference)

Source: the owner's workbook `durango_skill_point_upgrades.xlsx` (2026-10-28, compiled from 2019
community sources). It is reference data, not canon. Each sheet is exported next to it as
`durango_skill_point_upgrades__<sheet>.csv` (the first rows of each CSV are the sheet's title block).

## Sheets and columns

| Sheet | Columns | What it holds |
|---|---|---|
| START HERE | coverage, value, interpretation | 12 categories, 73 branches with SP totals, 184 named records, 40 exactly priced Survival rows, 3,223 SP historical total (3,213 in a 2026 restoration; the 10 SP gap is unresolved) |
| Skill Upgrades | ID, Category, Branch, Upgrade / Unlock, Req. Level, SP Cost, Effect, Record Type, Evidence, Notes, Source URL | 184 records. **SP is blank when unknown, never zero.** Only Survival has level-by-level SP |
| SP by Branch | Category, Skill Branch, SP to Master Branch, Category Total, Source Year, URL | 73 branch totals (for budgets, not per-node costs) |
| Combat Builds | Combat Style, Stance, SP Quoted, URL | SP budgets of 2019 example builds |
| Sources & Gaps | Source, Period, Supports, URL, Limitations, Assessment | provenance and known gaps |

## Mapping onto `game/data/skills/trees.json`

| Sheet field | trees.json node field |
|---|---|
| Category | the tree key (`Weapon/Tool` -> `weapon_tools`) |
| Upgrade / Unlock | `name` (id snake_case) |
| Req. Level | `level` |
| SP Cost | `sp` (only when the sheet has a number; then `sp_source` names the row and `sp_assumed` goes) |
| Effect | `unlocks` text; an effect we run becomes `effects`, anything else stays data-only with `impl: defined` ("Not active yet" in the sheet) |
| Record Type "Automatic unlock" | `auto: true`, `sp: 0` |
| Record Type "Skill node / recipe name" | a node with a `recipe` effect only once a matching recipe exists |

## What was imported (SLOWLEVELS, 2026-10-28)

- Survival Stealth I-V: SP and levels now cite the sheet (rows 11-15); Stealth IV costs 4 SP (was an
  assumed 5).
- Survival Animal Handling I-IV: already matched the sheet (rows 27-30: Lv 35/45/55/60, 4/5/5/6 SP).

## Not imported, and why

- **Stealth VI** (Lv 60, 6 SP), **Exploration I-III**, **Bulk Up I-X** (Max Energy +10 each),
  **Surviving Durango I-VII** (free region-survival unlocks): new nodes; our Survival tree is pinned by
  tests (`t_skilltrees` baseline ids and the 918-node catalog). Follow-up: add them with `impl: defined`
  (Bulk Up could be functional through the existing `max_energy` ability), renaming "Surviving Durango"
  to a Wild Lands name.
- **Capturing Quadrupedal / Bipedal / Mammal Dinos I-II**: our capture ladder is spec 09's Capture
  Technique I-V (functional, read by `Data.has_capture_technique`). The sheet's per-family capture
  nodes conflict with it; owner decision (Open Questions SL4).
- **The other 11 categories** (144 records): names and levels only, no SP (the sheet says blank is
  unknown, not zero). Many are recipe names, not proven nodes. They stay reference rows until per-node
  SP or an owner pricing rule exists.
