# Experiment: <short name>

Copy to `docs/orchestration/experiments/<yyyy-mm-dd>-<key>.md` and add a row to the
[experiment log](../orchestration/experiments/README.md). Use it for one risky question that a
build cannot answer by being careful: performance, feel, a pipeline that may not scale.

**Roadmap feature:** `<phase-map id>` · **Branch:** `claude/mmo-<key>` · **Started:** `<date>`
**Timebox:** `<hours or agent runs>` · **Spend cap:** `<Tripo/Meshy credits, or none>`

## One question
What must this answer? One sentence.

## Hypothesis
We think <approach> gives <observable result> because <reason>.

## Smallest convincing proof
What gets built, what may be faked, what must be real, which files are touched.

## Thresholds (write these before running it)
- **Proceed if:** <measured number or a play observation, e.g. "tutorial island holds 60 fps p95 at 1600x900">
- **Revise if:** <partial result>
- **Defer or drop if:** <the result that means we stop>

## Evidence
Commit, command or lab (`--lab=...`), test output, screenshots, Milan's play notes. Keep automatic
checks separate from how it felt to play.

## Decision
`PROCEED | REVISE | DEFER | DROP | PENDING` · decided by `<Milan or build thread>` · `<date>`.
A good experiment is not a shipped feature: the roadmap row only moves to `done` when the real
package lands with evidence.
