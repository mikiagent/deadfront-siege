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

## 2026-10-21 second audit (after the 13:55 dsc build)

Seven cook workers were checked between 14:02 and 14:05 CDT. All six live ones started 13:13-13:45, so **none runs the 13:55 build**. Running workers are not at risk of mixing old and new modules: the only lazy imports in dist/index.js (371-528, 650) run at startup or for the board. Total spend is about $1.73.

| worker | state | time / cap | cost / cap | milestones | verify | main problem |
|---|---|---|---|---|---|---|
| card2d | finished by runner 13:52 | 1.8 h / 4 h | $0.31 / $6 | 0/6 ticked | passes | Report never written. Parallax squashes small cards. Empty-card bug. Gates print PASS unconditionally. Runner auto-finished during new owner scope. |
| colors | working, off track | 0.85 h / 4 h | $0.68 / $5 | 6/7 claimed | fails (no report) | Creatures render as white ghosts, yet 'visually natural' was ticked. About 100 calls of shader bisect with probes that sampled grass. Server tame re-rolls colour. |
| webpack | working, off track | 0.5 h / 4 h | $0.21 / $5 | 1/5 | cannot pass | VRAM mode 2 cannot shrink the pack (s3tc+etc2 = 2x113 MB). No export since the change. Project-wide import defaults changed. Gate diffs against a moving branch. |
| islandgen | working, off track | 0.3 h / 5 h | $0.09 / $6 | 0/5 | cannot pass | verify line 12 forbids t_save's deliberate SCRIPT ERRORs. Needle peninsulas against plan 1.2. Home layout ignored. Harbour JSON rewrite unplanned. |
| biomezones | working, on track | 0.3 h / 5 h | $0.11 / $6 | 1/9 | far | Parse error hung 300 s. 7 Godot runs without gslot. Probed the owner's userdata. Global zone tints. In-place smooth(). No ASSUMPTION marks. |
| props | working, slow | 0.3 h / 5 h | $0.17 / $6 | 0/7 | far | 40 steps of reading, 0 edits. Skipped READ FIRST and reference images. Overthinking (94% reasoning). |
| biomeassets | working, on track | 0.3 h / 5 h | $0.16 / $6 | 3/6 | 3 files missing | Never looked at the concept art. Three identical 410-tri mesas. No buried base. Crystals matte. Everything doubleSided. |

### Worker mistakes (model side, new today)
- **False completion on visual milestones.** colors ticked 'visually natural' after viewing a white-ghost shot. card2d left shear and black plants in its evidence image.
- **Invalid measurement.** colors' centre-pixel probes all read the same grass value (0.674,0.777,0.638) about 10 times.
- **Optimising before measuring.** webpack made 22 SSIM views and no export after its texture change. The lever it chose cannot meet the target.
- **Tuning to the gate instead of the plan.** islandgen made 20 m needle peninsulas to satisfy a 45% rule. Its bbox aspect is gamed by rotation.
- **Scope creep into siblings' files.** islandgen planned edits to island_scatter.gd (PROPS) and _build_tile_types (BIOMEZONES). biomezones edited island_runtime.gd.
- **Rules ignored until enforced.** biomezones ran Godot without gslot and launched a lab with no parse check. card2d piped Godot until the owner intervened.
- **Unchecked edits.** There were regex edits to .import files (webpack, 4 corrupted) and python `s.replace` edits without an assert (biomezones, about 8).
- **READ FIRST skipped.** props and biomeassets opened none of the reference images they were pointed to.

### What the 13:55 build fixes (verified in src)
Most of the first audit's P0 and P1 items:
- **Hangs:** proc.ts:runGroup (process-group kill, CPU watchdog, grace period); ledger tool_start and worker.json `current`.
- **Plan and milestones:** the plan rule 15/30/45; enforceTicks; `{n}`/`{name}` in the milestone gate.
- **Model output:** cut-off tool calls are dropped (agent.ts loop); a reasoning-only turn is retried at effort low; 32k output in task mode.
- **Verify:** async, killable verify; preflight.
- **Checkpoints:** checkpointExclude.
- **Memory and effort:** editCheck; the failed-long-call memory; SHORT.md refresh every 10 steps; the pre-compaction NOTES prompt; MAP quotas plus mapIgnore; `medium` effort plus the 3x8k downshift.
- **Hooks and guards:** PreToolUse hooks that can block, protectedPaths.

The audit trail is only partly there: a 400-character reasoning tail per call and saved-path labels on images.

### Still due in dsc (ranked)
1. **P0, auto-finish ignores `cook say` scope** (task.ts:570 never resets greenNotices) and skips the report. Add a wrap-up turn, and do not finish while a named deliverable is missing.
2. **P0, sandbox excludes the linked worktree's gitdir** (sandbox.ts:30). Four workers failed step one, and webpack corrupted .import files as a workaround.
3. **P0, guard.ts:pipedLongRun is unanchored.** About 15 refusals were triggered by project.godot and tools/blender paths.
4. **P1:**
   - The drift nudge with zero edits or visual acceptance.
   - A warning when the milestone gate has no `{n}`.
   - A timeout reported by editCheck as a code error.
   - The CPU-only watchdog: gslot waits look hung, and parse errors take 300 s.
   - zsh NOMATCH.
   - Version pinning: the dsc repo is uncommitted and nothing records which build a worker runs.
5. **P2:**
   - Preflight `$VAR` false positives.
   - task/cook ignore `effort` in .dsc.json (index.ts:439).
   - Truncated commit subjects.
   - Image verdicts not captured.
   - The 350k compaction threshold.
   - No append_file tool.

### Orchestrator fixes today (our side)
- verify_islandgen.sh:12: drop `! grep SCRIPT ERROR` for t_save.
- verify_webpack.sh:13: diff against base 2f9b3251, not claude/mmo-overhaul.

Both take effect without a restart.
- Tighten verify_card2d.sh (report, cards==models, new asserts) before resuming card2d (`--resume 20261021-170404-nv78`).

Restart no live worker for the build.

### New task-writing rules (15-29)
- No git writes in tasks. Pre-merge, use --commit, restore files with `git show`.
- Verify checks every deliverable, the report included, and is re-tightened before a resume.
- Visual acceptance needs a pixel proxy, and the lab prints PASS only when its counts agree.
- Gates diff against the base sha, accept deliberate SCRIPT ERRORs and check exit codes.
- Use staged `{n}` gates through gslot with a scratch HOME.
- gslot lives at a stable path, and each worker gets its own scratch directory.
- List the lab .tscn and protect the sibling-owned and project-wide files.
- Say which spec wins in a conflict, and give the anchors as numbers.
- Add a milestone to regenerate test-pinned data.
- Launch with --effort medium and --commit, and never --skill without --model.
- Quote globs for zsh.
- Measure before polishing.
- Art jobs include a reference-vs-render side-by-side in the report.

### Recommended .dsc.json for Godot worktrees
This file is always protected and is swept into commits unless untracked at start, so add it to .git/info/exclude. The `effort` key has no effect in task or cook: pass `--effort medium` on the launch line. Hook and editCheck were tested; the hook blocks Godot without gslot, `--headless` bakes and git writes, and lets `grep project.godot | head` through.
```json
{
 "sandbox": "workspace-write",
 "watchdogIdleSec": 180,
 "editCheck": "case \"$DSC_FILE\" in game/*.gd) export HOME=/private/tmp/dsc-godot-home; mkdir -p \"$HOME/Library/Application Support\"; G=$(tools/find_godot.sh); bash /Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul/docs/orchestration/mmo/handoff/scripts/gslot.sh perl -e 'alarm 60; exec @ARGV' \"$G\" --headless --path game --check-only --script \"res://${DSC_FILE#game/}\" > .dsc/editcheck.log 2>&1; if grep -qE 'Parse Error|SCRIPT ERROR|Compile Error' .dsc/editcheck.log; then grep -E 'Parse Error|SCRIPT ERROR|Compile Error|at: ' .dsc/editcheck.log | head -12; exit 1; fi; exit 0;; *) exit 0;; esac",
 "checkpointExclude": ["*.import", "*.uid", "*_Image_*.jpg", "_diag_*", "*_probe.gd", "*_probe.tscn", "*.orig", "*.rej"],
 "mapIgnore": ["game/.godot/**", "game/assets/**", "*.import", "*.uid", "*.html", "docs/orchestration/mmo/handoff/findings/**", "docs/reference/**"],
 "protectedPaths": ["game/project.godot", "game/export_presets.cfg", "game/override.cfg", "tools/smoke.sh", "tools/find_godot.sh", "AGENTS.md", "GAUNTLET.md", "HANDOFF.md", "docs/orchestration/dsc/*-TASK.md", "game/tests/t_save.gd", "game/scripts/camera/iso_camera.gd"],
 "toolChoice": "required",
 "autoEscalate": true,
 "effort": "medium",
 "routingLog": true,
 "hooks": {"PreToolUse": [{"timeoutMs": 10000, "command": "[ \"$DSC_TOOL\" = bash ] || exit 0; a=\"$DSC_ARGS\"; if printf '%s' \"$a\" | grep -Eq '(find_godot[.]sh|/Godot(_mono)?([^/a-zA-Z]|$)|smoke[.]sh)' && ! printf '%s' \"$a\" | grep -q 'gslot[.]sh'; then echo 'Run Godot and tools/smoke.sh only through gslot.sh, exactly as TASK.md shows.'; exit 2; fi; if printf '%s' \"$a\" | grep -q -- '--headless' && printf '%s' \"$a\" | grep -Eq -- '(--shot|bake|shots/)'; then echo 'Bakes and shots need a window: drop --headless.'; exit 2; fi; if printf '%s' \"$a\" | grep -Eq 'git +(merge|checkout|stash|commit|add|reset|rebase|restore)'; then echo 'git writes fail in the dsc sandbox. Restore a file with: git show HEAD:path > path. Leave commits to the runner. Note blockers in .dsc/NOTES.md.'; exit 2; fi; exit 0"}]}
}
```
Why each key:
- **watchdogIdleSec 180:** biomezones' parse-error hang sat 300 s. Do not go lower, because a gslot slot wait looks CPU-idle.
- **editCheck:** parse-checks each edited .gd through gslot with a scratch HOME. It is grep-based, so a timeout does not read as a code error.
- **checkpointExclude:** adds the probe and diag junk that colors left in the index.
- **mapIgnore:** keeps MAP.md on code.
- **protectedPaths:** the files workers touched today that they should not have. A task that owns one overrides the list in .dsc.local.json.
- **toolChoice required:** the run ends only through task_done.
- **routingLog:** shows when a run was routed to jev-router.
- **hooks.PreToolUse:** rule 12 from the first audit.
### Actions taken (orchestrator, 14:20)
- Nudges sent to colors, webpack, islandgen, props, biomezones and biomeassets (no restarts, as the audit advised).
- Fixed our own gates: verify_islandgen.sh accepts t_save's deliberate SCRIPT ERRORs; verify_webpack.sh diffs against its
  base 2f9b3251.
- CARD2D resumed for round 2 on the new build with a stricter verify (report, cards == models > 0, ms_cards < ms_models,
  parallax/empty/fade asserts, untouched iso_camera.gd, no junk) and a t_card2d milestone gate.
- The DeepseekCLI working tree (TUI, routing, guard rails) was committed as c00856e on the owner's word.
