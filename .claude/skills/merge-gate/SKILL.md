---
name: merge-gate
description: Decide whether a claude/mmo-<key> branch is ready to integrate into claude/mmo-overhaul, keeping technical pass, design consistency and Milan's gameplay approval as three separate verdicts. Use in the build thread before every merge.
---

# Merge gate

Proposed 2026-10-30 in `docs/orchestration/reports/claude-studio-workflow.md`. It writes down what
GAUNTLET.md steps 6-9 already require, so every merge leaves the same evidence. Inspired by the
gate-check / story-done ideas in Claude-Code-Game-Studios, without its sprint files.

The integrator is the only one who merges, one branch at a time, and pushes only when green.

## 1. Technical (automated, must pass)

Run on a scratch merge of the branch into the current `claude/mmo-overhaul`, not on the branch alone:

```
godot --headless --path game --import
tools/all_tests.sh                       # every game/tests/t_*.gd; exit 0 required
tools/smoke.sh --no-import               # must print SMOKE PASS
python3 tools/docs_wiki/phase_map.py check
```

Plus the brief's own labs and bot runs (for example `-- --tutorial-bot` or `-- --bot`). Fail the gate on:
any FAIL line; a new `SCRIPT ERROR` or `Parse Error` in any test log even if the test passed;
a new `~/Library/Logs/DiagnosticReports/Godot-*.ips`; a save fixture rewritten without Milan's OK.
On the x86 cloud box, time budgets (`t_perfgates`, build-time) are advisory; the Mac run decides.

## 2. Design consistency (fresh reviewer)

Run `goldfish-review` in branch mode. Pass when there are no Blockers and every Major is fixed or
answered in writing. Check that each `# ASSUMPTION:` in the diff is listed in the package report.

## 3. Human gameplay (Milan)

Tests never prove fun or feel. If the brief has `HUMAN:` items, the gate result for them is
`WAITING ON MILAN`, never pass. Merge can still happen (it is reversible) but the roadmap row
gets no "verified" evidence until Milan's play note exists. Milan's gates (species, saves, money,
deploy, merge to main, visual direction) are never decided here.

## Verdict

Append to the package report `docs/orchestration/reports/claude-<key>.md`:

```
## Merge gate <date> at <merge sha>
Technical: PASS | FAIL (<first failing line>, log path)
Design: PASS | FAIL (<blocker>)          Reviewer: <agent id>
Human: n/a | WAITING ON MILAN (<HUMAN: items>) | PASS (<Milan note, date>)
Docs: docs/current/<page> updated? phase-map evidence added? open questions added?
```

Then, on PASS for technical and design: fast-forward `claude/mmo-overhaul`, push, add the roadmap
row's `evidence` (merge sha + test path), and post one line in the thread. Never rewrite
`docs/vision/` to match the code; differences go to the open-questions register.

## Retry budget

A failing gate goes back to the implementer with the first failing line and the log path. After 3
rounds on the same gate, stop: write the failure up (see `repro-bug`) and decide re-scope, park, or
ask Milan. Do not loop.
