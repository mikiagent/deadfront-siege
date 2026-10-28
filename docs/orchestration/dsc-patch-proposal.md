# dsc patch proposal (2026-10-28)

Milan asked: if dsc workers keep failing, propose a dsc patch. This is the proposal, built from the failure log kept
during the 10-27/28 build. It is not applied; the dsc repo is https://github.com/mikiagent/deepseekcli.

## How the workers did

Overnight 10-28, on GLM 5.3 Flash / DeepSeek V4.1 Flash with the shared `verify_job.sh` gate:

| Job | Result | Cost |
|---|---|---|
| petfollow, rareattr, cookroles, tamingodds, buildquality | done first try, merged | $0.14-0.50 each |
| butcher | done; stopped as blocked on my gate-config error (correct behaviour) | $0.44 |
| docsaudit | done; also wrote a page for code its base did not have (I dropped it) | $0.16 |
| ragdoll r1 / r2 | r1 done; r2 blocked on physics tuning, handed to a Claude agent | $0.43 |
| outputs | 1.4 h of reading with no file written; the stall detector paused it; nudged | $0.69+ |

Bounded logic tasks with a headless test work well and cheaply. The failures cluster in four patterns.

## The four failure patterns

1. **Scouting without writing** (shapegates, outputs). The worker reads code for an hour and writes nothing. The stall
   detector catches it only after 61 steps.
2. **Visual work claimed done** (eyetrails r1 and r2). The worker ticks visual acceptance from its own notes. In r2 the
   PNG was the same look as r1 and no rendering code had changed.
3. **Gate edges handled badly** (capture09, statusicons). A windowed lab ran even though the `HEADLESS_ONLY` marker was
   set. When verify failed only on SCOPE, the worker reverted tracked files and kept looping.
4. **Documenting outside its tree** (docsaudit). It wrote a page for a feature its base didn't contain, apparently
   from reports and other worktrees.

## Proposed changes

| # | Change | Fixes |
|---|---|---|
| a | **File-first budget:** if no tracked file has changed after N steps (default 25, `--scout-steps`), the runner injects "write the test file now with what you know", and at 2N stops as blocked with its NOTES. | 1 |
| b | **`--visual-gate <shot cmd> --criterion "<text>"`:** before a task may finish, the runner renders the shots itself. It refuses "done" when they hash the same as the previous round. It then sends them to a separate vision-capable judge model with the criterion, and the task is done only on a judge PASS. | 2 |
| c | **HEADLESS_ONLY enforced by the runner:** when the marker exists, a Godot launch without `--headless` is refused unless `--allow-windowed` is passed. | 3 |
| d | **Scope-only verify failure:** auto-stop as blocked with the file list. No looping, and no `git checkout`/revert of tracked files. | 3 |
| e | **Tree-bound docs:** for doc tasks, the runner rejects a cited path or function that is not in `git ls-files` of the worker's own tree. Today `verify_docsaudit.sh` checks existence only. | 4 |

Changes a, c and d are runner-side and small. Change b is the biggest win for this project, because visual work is
where dsc output can't be trusted without a separate check. Until b exists, the integrator keeps visual packages on
Claude agents. That's what the overnight run did: UI screens, status effects, sky shadows and eye trails went to
Claude agents; logic packages went to dsc.
