# Delegation performance

This is a small, non-representative sample, not a benchmark scorecard.

| Task | First attempt | Cost and time | Accepted into current game |
|---|---|---|---|
| Isolated M0 core | Worker gate passed | Reported $0.13, about 12 minutes | No; rebuild paused |
| Broad C0 save task | Stalled | First session about $0.05, 7m 50s | No |
| Read-only migration analysis | Incorrect invented source | $0.00018583520571, one model call | No |
| Same analysis, explicit read-first retry | Required facts correct; one unsupported aside | $0.00112103046, two model calls | Analysis only |

The ten distinct benchmark exercises in `BENCHMARKS.md` yielded five clear
first-attempt passes, one UI result with static evidence only, one partial trail
review, and three failures.
The analysis retry answered the core question with an unsupported aside. This
small sample does not support category-level reliability or regression rates.
Supervision included baseline tests, task correction, worker restarts and manual
inspection; wall-clock supervision time has not been measured precisely.
