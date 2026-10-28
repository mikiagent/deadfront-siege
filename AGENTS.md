# Agent guide for this repository

Three agents work here. Read this file first, then the relevant source documents.

**Game implementation:** Before building or changing a game system, use `docs/agent-context.md`
to find its vision, current behavior, owning code, and tests.

**Wiki maintenance:** Before changing the wiki, documentation, visual boards, or tuning sheets,
read `docs/wiki-maintenance.md`. It defines how to distinguish current implementation, vision,
proposals, and archive material and how to hand off changes.

| Agent | Owns | Never touches |
|---|---|---|
| Claude Code | `docs/orchestration/`, contracts, reviews, merges, Meshy credit approvals | — |
| Claude Code (art pipeline, since Codex ran out of usage) | `game/assets/creatures/`, `game/assets/characters/`, `game/assets/nature/`, `game/data/creatures/*.json`, `game/data/characters/`, `tools/` | `game/scenes`, `game/scripts` |
| Cursor | `game/scenes/`, `game/scripts/`, `game/data/*.json` except creatures | `game/assets/creatures/`, Meshy |

Historical plan and milestones: `main:docs/archive/plan.md` (use `git show main:docs/archive/plan.md`)
Art/data contract: `game/data/creatures/SCHEMA.md`
Current implementation and intended design: `docs/current/` and `docs/vision/`
Historical PRDs: `main:docs/prd/durango-wild-lands-systems-prd.md`, `main:docs/archive/prd/dinosaur-roster-and-3d-pipeline.md`
Engine choice and why: `main:docs/archive/engine-decision.md`

## Rules that apply to everyone

- The old game is `index.html` plus ~90 HTML snapshots. Treat it as a **spec to read**, never as code to extend. Nothing new goes in the repo root.
- Godot 4.7.1 (Mono build), **typed GDScript**. No C# unless the plan says so.
- **Desktop Chrome (1600x900, real mouse, 16:9) is the primary acceptance target and ship gate; mobile/touch stays a supported secondary target.** All input goes through InputMap actions; the autoloaded touch layer presses them. Tap targets 64 px or larger, respect the safe area, no hover-only UI. Test with `--touch` after `--` on the command line (mouse emulates touch).
- Headless check before you report done: `tools/smoke.sh` must print `SMOKE PASS`.
- Meshy costs credits. Every task that spends them has a cap in its prompt. Stop and report when you hit the cap; do not "try one more".
- When a task ends, write `docs/orchestration/reports/<agent>-<task>.md`: what shipped, what failed, credits spent, what the next agent needs. That report is how the other agents hear from you.
- Do not invent lore, species, or mechanics that are not in the PRDs. If the PRD is silent, pick the simplest thing, mark it `# ASSUMPTION:` in code, and list it in your report.
- Commit with a clear message per milestone. Do not rewrite history.

## Tools available to every agent

- **dsc (deepseek-code)**, https://github.com/mikiagent/deepseekcli — a Claude Code style agent on DeepSeek V4.1 Flash
  via OpenRouter. Cheap, slow, prone to overthinking; use it for long mechanical tasks with a verify command
  (rigging and animation in Blender, retargeting, batch asset work), not for design decisions. Install: clone,
  `./install.sh`, then `dsc` once for the OpenRouter key. Write the task as a `TASK.md` (see `TASK.example.md`
  in the repo) and run `dsc task TASK.md --verify "tools/smoke.sh" --budget 5 --worktree --commit`; the exit
  code is 0 only when verify passed. `dsc cook start/status/attach/pause/resume/stop` runs it unattended.
  Keep `.dsc/` and `.dsc.json` out of git. Reference task set-ups: `~/Documents/DeepseekCLI/survivor-v2/anim`.
