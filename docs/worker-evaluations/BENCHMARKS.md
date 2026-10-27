# DeepSeek benchmark results

Run on 2026-10-26 against source from `923657262cd335fefee9126df61dd0fff4b93321`.
The seven editing exercises used separate sparse disposable worktrees under
`/private/tmp/deadfront-worker-bench.8gW3Ov/`. They were not merged into the
game. The migration analysis used the isolated C0 worktree in read-only mode.
All used `deepseek/deepseek-v4.1-flash-1017`; seven editing exercises used low
effort, an eight-turn limit, a $0.10 cap and workspace-write sandboxing.

| Task and acceptance criterion | Observed outcome | Independent check | Reported cost |
|---|---|---|---:|
| Analyze actual save migrations: versions 0-3, reject future, name v3 fields | First answer invented a different file. Read-first retry answered required facts but included an unsupported aside. | Compared with `game/scripts/core/save_migrations.gd`; retry session contains `read_file`. | $0.000186 first, $0.001121 retry |
| Change only `rules.json` top-level `_about` to `BENCHMARK ONLY` | Completed. | Reviewed the one-line Git diff. | $0.002827 |
| Write tests for schema absence, basket coordinates and empty inventory in existing v0 fixture | Completed. | Read `bench/test_v0.py`; three independently rerun unittest cases passed. | $0.001259 |
| Implement a nonnegative, capacity-bounded quantity utility against supplied tests | Completed. | Independently reran two unittest cases, including negative and excess inputs. | $0.001198 |
| Fix the same seeded quantity bug against supplied tests | Completed. | Independently reran the boundary unittest. | $0.002163 |
| Add a typed caption setter that redraws an existing `HexButton` | Change matches the requested four-line diff. | Static diff inspection only; no runtime or visual check in the sparse checkout. Provisional, not gameplay acceptance. | $0.001340 |
| Implement an isolated record validator with type, schema range and no-mutation requirements | Completed. | Independently reran two supplied unittest cases and inspected the read-only implementation. | $0.001492 |
| Handle ambiguous faster-gathering request without changing rules | No answer before eight-turn limit. | Exit 1, `max_turns`; tracked files unchanged. The session shows repeated investigation, not an escalation. | $0.002041 |
| Review the in-progress save changes for concrete data-loss risks | No answer before six-turn limit. | Session `20261027-042757-avaf` read the named files and searched related code, then exited `max_turns` without findings. | $0.004979 |
| Review the generated decision trail for weak evidence | Flagged genuine gaps, but also described a nonexistent fourth data row. | Compared session `20261027-043007-q4lx` with `.audit/c0-worker.tsv`; it did not read the referenced evidence or a transcript. Partial only. | $0.001288 |

The ambiguity retry used an explicit one-file limit and read-only mode. It
identified the missing owner decisions without edits, but misattributed the
repository guide; its reported cost was $0.000609. See `WORKER-FAILURES.md`.

Five exercises passed their stated checks outright on the first attempt, one UI
edit has only static evidence, the trail review is partial, and three did not
meet their first-attempt criteria.
The source-analysis retry met the three requested facts but is not counted as a
clean acceptance because of the extra unsupported aside. This is a small sample;
none of the synthetic quantity/record checks proves safe inventory or save
integration. The reported total including both retries is approximately $0.020502.
Individual wall-clock times and full supervision time were not measured.

Session files in the temporary worktrees contain the prompts, tool calls and
model output. They are local evidence and may be removed by the OS; this document
records the outcome independently. `WORKER-FAILURES.md` describes the two major
failure modes and the uncontrolled variables in the retry.
