# DEADFRONT docs — the canon line (single source of truth)

This line owns every doc that is true **today**. Nothing about a living system
exists in two places: the archive line (`main`) holds history and is never
edited in place; when a doc here goes stale it moves there, it does not get a
twin.

## `vision/` — permanent, evolving design
What the game **should** be, at the experience and rule level. Anchored by the
owner-authored `WildLandsMMO_*` spec set (2026-10-27):

- `WildLandsMMO_Game_Vision.md` — umbrella encyclopedia; experience design is canon
- `WildLandsMMO_Loss_Recruitment_Revival.md` — owner-confirmed rules (72 h ransom window,
  two revival routes, first tame by discovery, solo-friendly frontier tiering)
- `WildLandsMMO_Combat_Math.md`, `WildLandsMMO_Crafting_Building_Math.md`,
  `WildLandsMMO_Traits_Gathering_Processing_Math.md` — workshop **proposals**: formulas and
  percentages are candidates until the balance workshop approves them; do not quote their
  numbers as shipped fact
- The umbrella doc references a `WildLandsMMO_Open_Questions.md` decision register (not yet
  in this repo — pending)

## `current/` — how the build works today
One doc per system, facts and numbers only, each citing the code path that owns
it. `controls.md` (input truth) and the three generated data pages exist today;
`survival-needs.md` and `hud.md` are pending but tracked in `current/README.md`.

## Everything historical lives on the archive line
The old corpus (~420 docs: orchestration prompts, reports, playtests, the PRDs,
old release notes) was removed from this line on 2026-10-27. Read it from the
`main` checkout, `git show main:<path>`, or through the wiki's **deep** search
(the wiki indexes the archive line, but never auto-loads it). Code comments
that cite a removed path keep working as history pointers — treat them as
"where it came from", not as a file to open.

## Build-asset corpora that stay on this line (not doc truth)
- `docs/reference/` — art reference sheets consumed by `tools/sprites2d/` and cited in
  code comments
- `docs/design/` — the owner's numbered prompt series (code comments cite these by spec
  number) plus the design refs the code cites
- `docs/art/durango-asset-benchmarks-and-tripo-prompts.md` — the adopted budget authority;
  a future `current/` assets page should absorb it
- `docs/release/simulator.md` — the simulator-build how-to cited by `tools/sim_run.sh`
  and `tools/export_ios.sh`

## Flow & rules
- A doc change lands in the same commit as the change it documents.
- Generated pages (`current/{recipes,world-biomes,items-traits}.md`) come from
  `tools/docs_wiki/gen_game_data.py`, which reads `game/data/*.json`; re-run it after any
  balance pass or accepted sheet sync. The owner's editable sheets live in
  `game/data_sheets/` (see its `NOTES.md`).
- Stale docs are `git mv`-ed to the archive line's `docs/` (mark them stalled in the wiki
  first: http://localhost:8899). Copying docs between the lines is how they drift; the
  wiki's cross-line diff list is the drift alarm.
