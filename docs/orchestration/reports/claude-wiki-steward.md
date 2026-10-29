# Wiki steward proposal: assessment and what landed

Branch `claude/mmo-wiki-steward`, cut from `claude/mmo-overhaul` at `02362ad2` on 2026-10-29.
Docs and wiki tooling only; not merged anywhere.

## What Milan's zip proposes

A skill (`deadfront-wiki-steward`) plus three templates and a production model. The core ideas:

1. Track every feature on three separate axes (design approved? built? committed to this milestone?)
   instead of one overloaded status.
2. Never call something implemented because a doc says so, and never call it verified without
   evidence at a named commit.
3. Phase gates: concept, prototype/R&D, vertical slice, scoped production, verified delivery.
4. R&D experiments with thresholds written up front, ending in proceed / revise / defer / drop.
5. Milestones with must / stretch / an explicit cut list, and cuts never delete vision.
6. Wiki modes: audit, capture, scope, experiment, reconcile, review, all read-only by default.

## How it compares with what the repo already has

**Already covered.** `docs/wiki-maintenance.md` and `docs/agent-context.md` already separate
current implementation, vision, proposals and archive, already say "a data row does not prove a
feature is reachable", and already forbid turning a candidate number into a rule. The vision index
labels owner-confirmed vs workshop proposal per document. The Roadmap tab (`phase-map.json`) is the
feature index with dependencies. GAUNTLET.md's loop already demands visual proof, independent review
and blind A/B. So ideas 2 and most of 6 are already the house rules.

**Real gaps the zip fills.**
- Roadmap `done` only means "merged". There was no field saying how anyone can check it.
  All 60 `done` features have no evidence linked.
- No place to record experiments, so risky questions (tutorial-island lag, tribe ASSIGN at scale)
  get answered inside build packages with no stop rule.
- No milestone with a cut list. The roadmap has phases but nothing says "this playable slice is
  finished when X, and Y is deliberately out".

**Conflicts with how Milan works.**
- "Read-only by default, write only on instruction" is right for audit modes but contradicts the
  standing order to do anything reversible and say so. The adapted skill keeps read-only only for
  audit and reconcile.
- "Don't scale parallel agents while the core gameplay question is unresolved" contradicts the
  standing fan-out order (subagents + dsc). Left as a recommendation, not a rule.
- The zip's paths are stale: `docs/game-design/*`, draft PR #21 and `docs/release/ship-readiness.md`
  do not exist on the canon line; the vision set lives in `docs/vision/`. Its README suggests
  installing into Codex, which Milan has ruled out.
- A full three-axis status on every feature would mean re-labelling ~130 roadmap rows and changing
  the Roadmap UI's status picker. Too much churn for the value right now; the `evidence` field gets
  most of the benefit (it separates "merged" from "checked") with no migration.

**Drift found while comparing (not fixed, owned by the build thread).**
- GAUNTLET.md tells agents to read and append to `docs/orchestration/mmo/STATUS.md`, `mmo/HANDOFF.md`
  and `mmo/plan-register.md`. None of those exist on `claude/mmo-overhaul` or `main` on GitHub. Either
  they live only in a Mac checkout or the merge log has no home.
- GAUNTLET.md step 5 still assigns debugging to Codex (`gpt-reserve`).
- `phase-map.json` was last seeded 2026-10-27, so the 10-28/10-29 landings (tribe v1, bag redesign,
  taming/pens, hunger rework etc.) are not reflected; `tribes-workers` still reads `next`.
- The roadmap `goal` says "a first hour that is fun on a phone" while AGENTS.md and HANDOFF.md make
  desktop Chrome 1600x900 the ship gate.
- Root `HANDOFF.md` describes shipped state at `ab489b0c` (2026-09-21).

## What landed on this branch

- `tools/docs_wiki/phase_map.py`: optional `evidence` list per feature (repo paths that must exist,
  `commit:<sha>`, or `https://` links), validated like `source`. New read-only CLI:
  `python3 tools/docs_wiki/phase_map.py audit` (buildable next / blocked next / done without
  evidence) and `check`. Tests in `test_phase_map.py`.
- Roadmap tab (`app.js`, `app.css`): shows evidence links, and "no evidence linked" on bare `done` rows.
- `docs/templates/experiment.md`, `docs/templates/milestone.md`, and the log at
  `docs/orchestration/experiments/README.md`. The zip's feature-card template was skipped: a
  roadmap row plus its `docs/current/` page already is the feature card.
- `docs/wiki-maintenance.md`: sections on evidence and on experiments/milestones.
- `.claude/skills/wiki-steward/SKILL.md`: the zip's skill rewritten for this repo's real paths and
  Milan's standing orders (audit, reconcile, capture, experiment, scope).

Validation: all eight `tools/docs_wiki/test_*.py` suites pass; `phase_map.py check` passes on the
authored map. No game code, no `phase-map.json` statuses, no GAUNTLET/HANDOFF edits.

## Recommendations for Milan (these change how the build thread works)

1. When the build thread posts a landing, have it also add `evidence` (merge commit + test, lab or
   screenshot) to the roadmap rows it finished, and run `phase_map.py audit` after each merge.
2. Do one roadmap refresh pass now so it reflects the 10-28/10-29 landings.
3. Write one milestone with a cut list for the tutorial-island first hour, since that is the current
   priority, and make the tutorial-island lag an experiment with a frame-time threshold.
4. Fix GAUNTLET.md's references to the missing STATUS/plan-register files and the Codex line, and
   decide whether the roadmap goal should say desktop or phone.
