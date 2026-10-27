# Worker capabilities

Last checked: 2026-10-26. The available CLI is `dsc`; the configured model is
`deepseek/deepseek-v4.1-flash-1017`. It supports isolated Git worktrees, a
verification command, budgets, timeouts and `dsc plan` orchestration. Actual
success depends on the configured OpenRouter account and the execution sandbox.

The earlier isolated M0 core worker passed its own test gate, but that work was
on the paused rebuild branch and is not evidence that it can safely migrate the
existing game. A broad C0 save task stalled in two sessions without an accepted
change. A read-only migration-analysis benchmark returned invented source and an
incorrect answer without calling a read tool; an explicitly read-first retry
answered the core question correctly but included an unsupported aside. See
`WORKER-FAILURES.md`.

Ten distinct benchmark exercises are recorded in `BENCHMARKS.md`. Five passed
their stated checks outright, the UI edit has static evidence only, the trail
review was partial, and the initial source analysis, ambiguous task and save
review failed their first-attempt criteria.
These simple exercises suggest promise for tightly specified tests and utilities;
they do not establish production reliability for their broader categories.

**Current policy:** the lead owns save integrity, migrations, resource ownership
and cross-system decisions. DeepSeek may receive small, bounded tasks with
explicit source paths and independently checked results. Require owner decisions
to be escalated rather than guessed, and treat an exhausted turn limit as failure.
