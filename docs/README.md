# Wildlands MMO documentation

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
- The [Open Questions register](vision/WildLandsMMO_Open_Questions.md) tracks
  unresolved decisions and points to the document that will own each answer.

## `current/` — how the build works today
The [current index](current/README.md) lists implemented-system pages and the
pages still to write. Each page cites the code or data that owns its facts.
The [vision index](vision/README.md) separates owner-confirmed design from
workshop proposals. Coding agents can use [agent context](agent-context.md) to
find the relevant sections, code, and tests for a task.

## Everything historical lives on the archive line
The old corpus (~420 docs: orchestration prompts, reports, playtests, the PRDs,
old release notes) was removed from this line on 2026-10-27. Read it from the
`main` checkout, `git show main:<path>`, or by entering `/archive <term>` in
the wiki search box. Normal wiki searches do not search the archive. Code comments
that cite a removed path keep working as history pointers — treat them as
"where it came from", not as a file to open.

## Build-asset corpora that stay on this line (not doc truth)
- `docs/reference/` — art reference sheets consumed by `tools/sprites2d/` and cited in
  code comments
- `docs/design/` — the owner's numbered prompt series (code comments cite these by spec
  number) plus the design refs the code cites
- `docs/art/species/` — the owner's creature reference sheets (JPEG copies); see
  [species art](current/species-art.md) for each sheet's role and status
- `docs/art/durango-asset-benchmarks-and-tripo-prompts.md` — the adopted budget authority;
  a future `current/` assets page should absorb it
- `docs/release/simulator.md` — the simulator-build how-to cited by `tools/sim_run.sh`
  and `tools/export_ios.sh`

## Flow & rules
- A doc change lands in the same commit as the change it documents.
- Generated pages (`current/{recipes,world-biomes,items-traits,biome-spawns}.md`) come from
  `tools/docs_wiki/gen_game_data.py`, which reads `game/data/*.json`; re-run it after any
  balance pass or accepted sheet sync. The owner's editable sheets live in
  `game/data_sheets/` (see its `NOTES.md`).
- Follow [wiki maintenance](wiki-maintenance.md) when retiring a document. Check
  for consumers and preserved decisions before coordinating archive and canon commits.
