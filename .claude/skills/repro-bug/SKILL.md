---
name: repro-bug
description: Investigate a WildLands bug or failing gate by reproducing it in a headless test or lab first, measuring, and writing a failure report with a retry budget instead of guessing. Use for Milan's bug reports, red tests and stalled packages.
---

# Reproduce before fixing

Proposed 2026-10-30 in `docs/orchestration/reports/claude-studio-workflow.md`. GAUNTLET.md step 4
already says "write the probe or test and see it fail on the old code"; this skill makes the steps
and the stop rule explicit. Bug-report shape loosely from Claude-Code-Game-Studios.

## Steps

1. **Pin the report.** Restate Milan's words, the branch and commit, and the exact path (island,
   species, screen, item). If his note is ambiguous, pick the likeliest reading and say which.
2. **Find existing coverage.** `docs/agent-context.md` lists tests per system; grep `game/tests/`
   and `game/scripts/dev/*lab.gd` for the feature. Run the closest test alone:
   `tools/all_tests.sh t_<name>` (logs path is printed on the TOTAL line).
3. **Reproduce.** Write the smallest failing check: a new assertion in the owning `t_*.gd`, or a
   new `t_<key>.gd` that extends the pattern (`extends SceneTree`, prints `[t_<key>] PASS`, exits
   0/1, uses a temp HOME like `all_tests.sh`). For behaviour that needs the real loop, drive it
   through `BotSurvivor` / `tutorial_bot.gd` helpers rather than calling private functions.
   Visual bugs: a lab screenshot at 1600x900 (and 844x390), before and after.
4. **Measure, then change one thing.** Print `[tag] key=value` lines for the quantities involved
   (positions, counts, timers, durability). Each fix attempt states its hypothesis and the number
   it expects to move.
5. **Prove it.** The new check fails on the base commit and passes on the fix; the rest of the
   owning system's tests still pass.

## Budget and escalation

- 3 attempts per hypothesis family, 2 hours without progress on a package: stop.
- Never retry the same command hoping for a different result; flaky = investigate (seed, timing,
  shared `user://`), not rerun.
- Escalate to the lead with the report below. Escalate to Milan only for a design call or a gate,
  in one focused question.

## Failure report

Write to the package report (or `docs/orchestration/reports/claude-<key>.md`):

```
## Failure <date>: <one line>
Repro: <command>  (fails on <sha>)
Expected / actual: <numbers>
First error: <line>   Log: <path>
Tried: 1) <hypothesis> -> <result>  2) ...  3) ...
Best guess now: <cause>, confidence low/med/high
Needs: <lead decision | Milan decision | more info>
```

Do not ask Milan to paste terminal output: the agent runs the command and quotes the log.
