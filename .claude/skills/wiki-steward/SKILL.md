---
name: wiki-steward
description: Audit or reconcile the WildLands MMO wiki (docs/current, docs/vision, the Roadmap phase map) against the code, capture owner decisions, and frame experiments or milestones. Use for drift reports, post-merge reconciliation and scoping a playable slice.
---

# Wiki steward

Adapted from Milan's `deadfront-wiki-steward` proposal (2026-10-29) to this repo's real layout.
It keeps three things apart: what Milan decided, what the build does, and what has been checked.

## Sources, in order of authority

1. Milan's newest explicit message in the thread. It beats every file.
2. Vision: `docs/vision/` (owner-confirmed vs workshop proposal labels per `docs/vision/README.md`),
   open questions in `docs/vision/WildLandsMMO_Open_Questions.md`, binding design input in
   `docs/design/`.
3. Plan of record: `tools/docs_wiki/phase-map.json` (the wiki's Roadmap tab).
4. Today's build: code and data under `game/`, summarized in `docs/current/` (each fact cites a file).
5. Evidence: tests (`game/tests/t_*.gd`, `tools/all_tests.sh`), labs (`--lab=...`), reports in
   `docs/orchestration/reports/`, screenshots, Milan's play notes.

Rules for writing docs are in `docs/wiki-maintenance.md`; read it before editing anything.
`main` is the archive line; do not load it unless provenance is the question.

## Non-negotiables

- A doc describing a feature is not proof it exists. Check the code; if you did not, say UNKNOWN.
- `done` on the roadmap means merged. Only call something verified when a test, lab, screenshot
  or Milan's play note backs it, and link it in the feature's `evidence` list.
- A proposal, example or candidate number is never a rule until Milan approves it.
- Show conflicting sources side by side; never quietly pick one.
- Cutting a feature from a milestone moves it to `later`; it never leaves the vision.
- No gameplay code changes from this skill. `claude/mmo-overhaul` and the Mac checkouts belong to
  the build thread; propose roadmap status changes to it rather than rewriting them in bulk.

## Modes

**audit** (read-only). Run `python3 tools/docs_wiki/phase_map.py audit`. For the systems asked about,
compare the vision section, the `docs/current/` page and the owning code. Report a table: feature,
what the wiki says, what the code does (with path), confidence, proposed fix, who must approve.

**reconcile <branch|commit>** (read-only unless asked). Diff against `claude/mmo-overhaul`, map the
changed files to roadmap ids, and propose: status changes, `evidence` entries, `docs/current/` pages
that need updating, missing tests.

**capture** (after a design conversation). List only Milan's explicit decisions, with his wording,
and the questions still open. Say which doc owns each. Default: it does not change current scope.

**experiment <question>**. Fill `docs/templates/experiment.md`: one question, thresholds written
before the run, timebox and spend cap, and a PROCEED / REVISE / DEFER / DROP decision at the end.

**scope <slice>**. Fill `docs/templates/milestone.md`: the success story a player can actually do,
must / stretch / cut list, and the exit check. Judge it by Milan's yardstick: is this fun?

## Output shape

1. Current truth, with paths and the commit you read.
2. The main discrepancy or unknown.
3. The smallest next step (a test, a decision for Milan, or a bounded package).
4. Proposed edits, kept separate from edits actually made.
5. Evidence and what still needs Milan's sign-off.
