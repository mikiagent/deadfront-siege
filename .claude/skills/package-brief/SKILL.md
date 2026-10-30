---
name: package-brief
description: Turn one approved WildLands roadmap row or Milan ask into a build package brief (canonical sources, open questions, owned files, acceptance tests, retry budget) before any code is written. Use when the lead starts a package or splits work for parallel agents.
---

# Package brief

Proposed 2026-10-30 in `docs/orchestration/reports/claude-studio-workflow.md`. Inspired by the
story/readiness ideas in Claude-Code-Game-Studios, cut down to this repo's one-file-per-package habit.
The brief is the contract an implementation agent works from. It points at sources; it never
defines new game rules.

## When

- The lead (the build thread) is about to hand a package to an Opus subagent or the cloud thread.
- Two or more packages might run at once: write a brief for each first, then compare owned files.

Skip it for a one-line bug fix with a known cause; use `repro-bug` instead.

## Steps

1. **Find the row.** `python3 tools/docs_wiki/phase_map.py audit` and pick the roadmap id. If the
   ask is not on the roadmap, say so in the brief; do not add a row without the lead's say-so.
2. **Read the canon, in authority order** (same order as the `wiki-steward` skill): Milan's newest
   message, `docs/vision/` (owner-confirmed vs proposal labels), `docs/design/` and
   `docs/design/durango-prompts/`, the row's `source`, then `docs/current/<system>.md` and the
   owning code. `docs/agent-context.md` maps systems to files and tests.
3. **Separate what is decided from what is not.** Quote the binding lines with paths. List every
   question the sources leave open. For each one: is it a Milan gate (species, saves, money,
   deploy, merge to main, visual direction)? If yes, stop and route it. If no, pick the simplest
   default and mark it `# ASSUMPTION:`; it must also go into the package report.
4. **Name owned files.** List the files the package will edit. Check them against
   `docs/orchestration/mmo/plan-register.md` and GAUNTLET step 3's integrator-only list
   (`game/scripts/core/{game,main,world}.gd`, `game/project.godot`, `game/tests/run_all.gd`,
   `game/scripts/ui/touch_controls.gd`). Those get exact hooks in the report, not edits.
   Flag hot shared files (`game/scripts/ui/hunt_hud.gd`, `game/data/items.json`,
   `game/data/recipes.json`, `game/scripts/player/player*.gd`, `tools/docs_wiki/phase-map.json`).
5. **Write acceptance as tests.** Each acceptance item names the test or lab that proves it and
   whether that test exists. New behaviour needs a new or extended `game/tests/t_<key>.gd` that
   fails on the current code. Mark anything only a human can judge (feel, look, fun) as
   `HUMAN:`; tests never stand in for it.
6. **Set the budget.** Default: 3 fix attempts per failing gate, 2 hours without a passing
   milestone, then stop, commit WIP and write a failure report (see `repro-bug`).

## Output

Write `docs/orchestration/briefs/<key>.md` on the package branch `claude/mmo-<key>`:

```
# <KEY>: <one visible outcome in Milan's words>
Roadmap: <id> (<status>)   Branch: claude/mmo-<key>   Base: claude/mmo-overhaul@<sha>
Risk: FABLE-CRITICAL | OPUS-SAFE (one sentence why)

## Binding sources        (quoted line + path for each)
## Open questions         (Milan gate? / default chosen, marked # ASSUMPTION)
## Scope                  (in / explicitly out)
## Owned files            (edit) / Hooks for integrator-only files / Hot files touched
## Acceptance             (item -> test or lab -> exists? / HUMAN: items)
## Gate                   (commands the integrator will run; see merge-gate)
## Budget                 (attempts, hours, Tripo/Meshy spend cap if any)
## Depends on / conflicts with   (other packages in flight and shared files)
```

Keep it under one screen where possible. A brief that cannot name its tests is not ready.
Before handing it out, run `goldfish-review` on it.
