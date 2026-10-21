# DeepseekCLI improvement log

One dated entry per dsc job: job, outcome, cost, time, cause, and a paste-ready prompt for the DeepseekCLI repo
(https://github.com/mikiagent/deepseekcli). GAUNTLET.md "DeepSeek workers" lists the prompts already due.

- 2026-10-20 mmo-camp (18 Blender camp pieces): success, $0.51, 0.8 h. Narrow kit-based build with a hash-guarded gate.
  Review later found the game's dirt disc hid the fields: gate should render previews with the in-game ground disc.
- 2026-10-20 quads-loco2 (quad walk/run): success, $1.26, 2.4 h. Gate measured stride in mesh units, skin stretch and hips.
  Lost time retrying milestone 1 against the full gate -> prompt 1.
- 2026-10-20 mmo-icons2 (65 item icons): stalled, $0.87, 3.5 h, 0/4 milestones. 20-minute full gate per attempt,
  out-of-scope .uid failed scope check, stop waited on a Blender run -> prompts 2, 4, 5.
- 2026-10-20 ragdoll profiles: stalled, $0.57, 2.1 h, 0/4 milestones. Open-ended physics tuning -> prompt 3; keep tuning for Claude.

## 2026-10-21 audit of five cook workers

Five `dsc cook` workers were checked about 20-25 min into their runs (each started 12:04-12:06 CDT, not 11:10 as the task headers said). None was on track. Together they had spent $0.81, verified no milestones and passed no verify gates. About 45 min of wall time was lost inside blocked bash calls.

| worker | state at check | time / cap | cost / cap | milestones | verify | main problem |
|---|---|---|---|---|---|---|
| card2d | frozen since 12:18:48 in an orphaned bash call | 24 min / 4 h | $0.13 / $6 | 0/6 | fails at line 13 (no baked cards); lines 16-17 can never pass (they read game/data/rules.json, which does not exist) | ran the bake with --headless, so frame_post_draw never fires; then the dsc bash timeout left `Godot \| tail` orphaned |
| saddles | frozen since 12:21:33 in an orphaned bash call | 25 min / 5 h | $0.31 / $8 | 3/7 ticked by hand, 0 through milestone_done | fails: t_mounts.gd missing | lab rewrite never compiled (likely `:=` from max()); lab checks are vacuous; rider-scale K bug not noticed |
| skillbuy | working, read-only | 19 min / 4 h | $0.13 / $5 | no PLAN.md | fails: t_skillbuy.gd missing | 52 steps, 0 edits, scope creep; task threshold needs ~27 newly wired nodes |
| savefix | hung on t_savefix (alarm 400) | 24 min / 4 h | $0.20 / $5 | 0/6 | report missing; the tree does not compile (world.gd:140) | misdiagnosed the energy defect (0.65 fatigue cap) and cut stamina regen 16/s to 1/s; tests built to avoid the cause |
| claimfix | second identical 400 s hang | 20 min / 4 h | $0.04 / $5 | 0/5 | fails: t_claimfix.gd missing | probe calls a method that does not exist, so it hangs; re-ran it unchanged; defect 1 as written does not reproduce |

### Worker mistakes (model side)
- **Long Godot runs with no cheap check first.**
  - card2d: ~550 lines in four files, then a 600 s headless bake.
  - saddles: a 361-line lab, then a 900 s run.
  - savefix: 10 files edited across ~90 calls with no Godot run, which broke the World autoload.
  - claimfix: a probe that dies at line 65 and never reaches quit().
- **Re-ran a failure without changing anything.** claimfix ran the same file into a second 400 s hang.
- **Overthinking.**
  - card2d: five turns spent the whole 16K output window on reasoning, with no content.
  - Reasoning was 72-84% of all output tokens.
  - skillbuy: 107 s for two greps.
- **Skipped planning and nudges.**
  - skillbuy never wrote PLAN.md.
  - savefix wrote PLAN.md only at step ~142.
  - saddles ticked PLAN.md boxes by hand and never called milestone_done.
- **Weak or vacuous tests.**
  - saddles: the drift check is 0 by construction; a coroutine runs without await, so PASS prints even after FAIL lines; the feet-vs-seat check fails by design.
  - savefix: the walking test turns rain off; the gate test runs before any Player exists.
- **Wrong diagnosis fixed with invented rules.** savefix added Vitals.moving and energy_regen_per_s 1.0 and cited PRD 6.2 for them, which the PRD does not say.
- **Edits without checks.** Workers used python heredoc `s.replace()` instead of edit_file (saddles 9 times, savefix ~45 times), with no assert that the text matched.
- **Kept blockers to itself.** card2d found the missing rules.json path at msg 9 and wrote no NOTES.md.

### dsc defects found (source: ~/Documents/DeepseekCLI/deepseek-code/src)
- **P0 bash orphan hang.** `tools/shell.ts runShell` spawns without `detached` and kills only the shell on timeout, then waits for 'close'. Pipeline children keep the pipe open until Godot's own alarm. Fix: put the child in its own process group, kill `-pid`, resolve on exit plus a grace period, return partial output, and add a note on timeout.
- **P0 no plan enforcement.** `task.ts gate()` sends 'call milestone_done' even at 0/0 milestones. Fix: at 15 steps with no plan, nudge to write PLAN.md; at 30, allow only that write; at 45, pause with a stall report.
- **P0 hung calls look like work.** Calls are logged only when they end, and worker.json says 'working' while the worker is blocked. Fix: log a start event per call, show 'bash running Ns' in `cook status`, and add a low-CPU watchdog.
- **P1 truncated tool calls run anyway.** `agent.ts loop()` handles length only when there are no tool calls (saddles calls 39/41 ran a cut-off write_file with no path). Fix: drop the cut-off calls and tell the model to split the write. Retry turns that are only reasoning at effort low. Use maxOutputTokens 32000 in task mode.
- **P1 verify preflight.** Run verify once at start, and flag paths the script reads that do not exist (card2d rules.json).
- **P1 verify blocks the runner.** `runVerify` uses spawnSync (blocks pause/stop/say), and `greenNow()` runs the full gate every 30 steps. Make it async and killable, and use the milestone gate for drift checks. (Extends prompts 2 and 4.)
- **P1 hand-ticked milestones count.** A PLAN.md tick should count only after a passed milestone_done; untick the others and tell the model.
- **P1 per-milestone verify** (prompt 1, still due). Pass `{n}`/`{name}` to `--milestone-verify`.
- **P1 checkpoint sweep** (prompt 5). The first wip checkpoint came before any write and swept in 23-44 import/.uid files that were already in the worktree. Fix: exclude the untracked files present at start, plus a default list (*.import, *.uid, *_Image_*.jpg).
- **P1 edit-check.** PostToolUse hook output never reaches the model. Add `--edit-check <cmd>` and append its failures to the tool result.
- **P1 no long-call memory.** Block once a re-run of a long failed command when no source file has changed since.
- **P1 stale memory.** SHORT.md still said 'orient, then plan' at 25 min. Have the runner refresh it every 10 steps, and ask for a NOTES.md update before compaction.
- **P1 MAP.md.** It stops alphabetically at 400 files and never reaches game/scripts or game/tests. Use git ls-files, a mapIgnore list and per-directory quotas.
- **P1 effort.** 'medium' is mapped to high (config.ts:112). Downshift to low after 3 read-only turns with more than 8K reasoning each.
- **P2 drift nudges.** They count empty turns and name a milestone the worker is already past.
- **P2 ledger and PROGRESS.** Parallel calls get the wrong description (task.ts:137 keys lastDesc by tool name). The PROGRESS 'nudges' count leaves out drift nudges.
- **P2 audit trail.** Store a reasoning tail per call. Keep the path in the image-expiry stub and ask the model to note what it saw.

### Task-writing rules (for the orchestrator)
1. **Godot runs.** Give the exact command with gslot.sh at a stable path. Size the alarm to about 3x a normal run, set timeout_ms to alarm + 30 s, log to a file, and never pipe Godot into tail, head or grep.
2. **Renderer.** Say which runs need a window and gl_compatibility (bakes, labs, shots, timings) and which are headless.
3. **Baseline the verify.** Run it on base before launch, paste the first failure, and make every path it reads exist or be named as a file to create.
4. **Staged gates.** Put 4-6 milestones in TASK.md, each with a staged gate under 2 min (`verify.sh n`). The full gate runs once at the end. Every Godot launch, smoke.sh included, goes through gslot.
5. **Reproduce defects first.** Give measured numbers and the source to measure: savefix 0.65 stamina cap and Wet fatigue; claimfix appends plots, PRD §13.1; skillbuy's gate is deliberate.
6. **Reachable thresholds.** Check the numbers before writing them (skillbuy needs 106 or fewer of 213; Lv 3 per-tree buys are impossible), and say 'report it' if they cannot be met honestly.
7. **Numeric gates.** Verify asserts numbers (rider scale about 1.0, head about 1.78 m, before/after numbers in the report) and fails on edits to other t_*.gd files.
8. **Test patterns.** Copy t_domain.gd for --script tests, add a 60 s quit watchdog, and use only existing API in repro probes. Save before-numbers before any edit.
9. **Known traps.** List them: `:=` on Variant returns (max(), ternaries, instance_on), un-awaited coroutines, frame_post_draw under --headless. Parse-check after each edit batch.
10. **Exact assets.** Name the models and the variant-to-card mapping (card2d).
11. **Other agents' files.** 'Edit, do not rewrite; keep existing asserts.'
12. **Guard hook.** Ship a .dsc.json PreToolUse hook that blocks Godot without gslot, --headless on render labs, and Godot piped into tail/head/grep.
13. **Times and base.** No start times in TASK.md. Cut each worktree from the current package head and state the diff base.
14. **Check early.** Check at 15 min. If a worker is blocked in bash, kill the orphaned pipeline before `dsc cook say`.
