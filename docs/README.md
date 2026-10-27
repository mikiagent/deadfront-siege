# DEADFRONT docs — the wiki's live tracks

## Two tracks (what the wiki loads by default)

### `vision/` — permanent, evolving design
What the game **should** be, at the experience and rule level. Currently anchored by the
owner-authored `WildLandsMMO_*` spec set (2026-10-27):

- `WildLandsMMO_Game_Vision.md` — umbrella encyclopedia; experience design is canon
- `WildLandsMMO_Loss_Recruitment_Revival.md` — owner-confirmed rules (72 h ransom window, two
  revival routes, first tame by discovery, solo-friendly frontier tiering)
- `WildLandsMMO_Combat_Math.md`, `WildLandsMMO_Crafting_Building_Math.md`,
  `WildLandsMMO_Traits_Gathering_Processing_Math.md` — workshop **proposals**: formulas and
  percentages are candidates until the balance workshop approves them; do not quote their numbers
  as shipped fact
- The umbrella doc references a `WildLandsMMO_Open_Questions.md` decision register (not yet in
  this repo — pending)

### `current/` — how the build works today
One doc per system, facts and numbers only, each citing the code path that owns it. Start:
`survival-needs.md`, `hud.md`. New one lands whenever a system changes in a way that matters.

## Everything else is deep history — search, don't load
The rest of `docs/` (orchestration, reports, playtests, old PRDs, design notes) is **not indexed
by the wiki by default**. It stays one deliberate search away ("deep" toggle in the wiki header)
for provenance, but nothing in it should sit in a working session's context. Old implementations
and superseded design decisions belong there, not in the top-level load set.

## `archive/` — parked for good
Any folder named `archive` is skipped by the wiki scanner entirely (closed tabs in
`tools/docs_wiki/docs_wiki.py`). Stale-marked docs move here, e.g. the superseded
dinosaur-roster PRD (Meshy pipeline era), `orchestration/plan.md`'s historical numbering and
`engine-decision.md`'s historical import specifics.

## Flow
Mark docs in the wiki (http://localhost:8899) → stale ones get `git mv`-ed into `archive/` →
the promoted truths get rewritten as a `current/` doc so a fresh session reads one page instead
of twenty sessions of history.
