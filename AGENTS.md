# Agent guide for this repository

Three agents work here. Read this file first, then the plan.

| Agent | Owns | Never touches |
|---|---|---|
| Claude Code | `docs/orchestration/`, contracts, reviews, merges, Meshy credit approvals | — |
| Codex | `game/assets/creatures/`, `game/data/creatures/*.json`, `tools/meshy.py`, `tools/render_glb.py` | `game/scenes`, `game/scripts` |
| Cursor | `game/scenes/`, `game/scripts/`, `game/data/*.json` except creatures | `game/assets/creatures/`, Meshy |

Plan and milestones: `docs/orchestration/plan.md`
Art/data contract: `game/data/creatures/SCHEMA.md`
Design source of truth: `docs/prd/durango-wild-lands-systems-prd.md`, `docs/prd/dinosaur-roster-and-3d-pipeline.md`
Engine choice and why: `docs/engine-decision.md`

## Rules that apply to everyone

- The old game is `index.html` plus ~90 HTML snapshots. Treat it as a **spec to read**, never as code to extend. Nothing new goes in the repo root.
- Godot 4.7.1 (Mono build), **typed GDScript**. No C# unless the plan says so.
- **Mobile is the primary target.** All input goes through InputMap actions; the autoloaded touch layer presses them. Tap targets 64 px or larger, respect the safe area, no hover-only UI. Test with `--touch` after `--` on the command line (mouse emulates touch).
- Headless check before you report done: `tools/smoke.sh` must print `SMOKE PASS`.
- Meshy costs credits. Every task that spends them has a cap in its prompt. Stop and report when you hit the cap; do not "try one more".
- When a task ends, write `docs/orchestration/reports/<agent>-<task>.md`: what shipped, what failed, credits spent, what the next agent needs. That report is how the other agents hear from you.
- Do not invent lore, species, or mechanics that are not in the PRDs. If the PRD is silent, pick the simplest thing, mark it `# ASSUMPTION:` in code, and list it in your report.
- Commit with a clear message per milestone. Do not rewrite history.
