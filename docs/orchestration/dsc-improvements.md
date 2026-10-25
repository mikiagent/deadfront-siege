# DeepseekCLI improvement log

One dated entry per dsc job: job, outcome, cost, time, cause, and a paste-ready prompt for the DeepseekCLI repo
(https://github.com/mikiagent/deepseekcli). GAUNTLET.md "DeepSeek workers" lists the prompts already due.

- 2026-10-25 test-reliability: launched headlessly from `claude/mmo-overhaul`, capped at $2 / 2 hours. It has a
  pre-run strict gate for the existing false-green `t_bags` and `run_all` paths: valid PASS marker plus zero
  unexpected `SCRIPT ERROR` lines, with smoke. Scope is test fixtures and the two direct `World` load-boundary
  scripts only; the worker must prove the `process_checks` dependency chain rather than suppressing errors.

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

## 2026-10-21 third audit (after the 14:42 dsc build 047993a)

**Build verdict:** 047993a is not safe for unattended cooks with --commit and the default watchdog. It can be used for new workers only with the config below: no --commit, watchdogIdleSec 0, maxTurns 300, the new hook, and a strict Done-when list. npm test passes (14 suites). Of the 15 second-audit items: 11 fixed, 3 partial, 1 regressed.

One blocker is new today and I reproduced it on git. gitCheckpoint (task.ts:1048) passes `:(exclude).dsc`. When .dsc is gitignored (ours is, .gitignore:19), `git add -A` exits 1, so every checkpoint stages files and never commits. This is the failure biomezones (13 times) and biomeassets (12 times) logged. Repro repos: scratchpad ckpt-test and ckpt-test2.

The bug hunt's other blockers:
- **False drift stall with --commit.** The HEAD-blind fingerprint makes the run stall after a wip commit.
- **No wrap-up at the rounds cap.** At maxTurns 60 the run finishes without asking for the report.
- **Watchdog.** It does not see gslot's `lockf -t 0` waits, and its early kill fires on deliberate or old SCRIPT ERRORs.
- **Pipe guard regressions.** At least 33 real engine pipes now pass.
- **Sandbox.** A commondir rewrite leads to a hook running in the runner's unsandboxed commit. Shared refs and refs/stash are writable.

No live worker restarted: card2d, islandgen, props and eyeglow all stay on their old builds.

| worker | build | state | time / cap | cost / cap | milestones | verify | grade | main problem |
|---|---|---|---|---|---|---|---|---|
| card2d | 13:55 | alive, looping; max-hours stop about 15:00 | 2.8 h / 3 h | $0.72 / $5 | 8/8 claimed | fails | D | '##' in card_sway.gdshader kills the shader (grey slabs). The report claims verify passes. It tried to spell the protected path in pieces. |
| colors | pre-13:55 | finished, done | 1.5 h / 4 h | $1.08 / $5 | 7/7 | pass | C | `ALPHA = col.a` means no shadows. rest_mesh drops the LODs. Respawns are clones. False emission cause in the report. |
| webpack | pre-13:55 | finished, done | 1.0 h / 4 h | $0.30 / $5 | 5/5 | pass, 167 MB | B | The 512 px downscale is global and no creature was ever rendered. The report hides the compress_to flip and misreads the atlas shot. |
| islandgen | pre-13:55 | alive, off track | 1.2 h / 5 h | $0.22 / $6 | 0/5 | t_save 5 FAIL, t_harbour 1 FAIL | C | Flat river trench, identical terraces, camp on the highland. Edited BIOMEZONES' loop. No tests or report. |
| biomezones | pre-13:55 | finished, done | 0.9 h / 5 h | $0.27 / $6 | 9/9 | pass | C | Volcanic reads brown (sRGB used as linear). Described shots it never opened. Nothing committed. |
| props | pre-13:55 | alive, off track | 1.1 h / 5 h | $0.42 / $6 | 1/7 | not run | C | int-to-'meadow' bug. Pebbles eat MAX_PROPS. Props look like resources. About 25 min of alarm kills. |
| biomeassets | pre-13:55 | finished, done | 0.8 h / 5 h | $0.63 / $6 | 6/6 | pass, 25 GLBs | B | Ziggurat cliff, hollow basalt tops, never re-rendered in Godot. 5 MB of _tiles staged. |
| sprites2d | 13:55 | finished, done | 0.6 h / 3 h | $0.49 / $4 | 4/4 | pass | C | Lime rims tuned just past the gate. Labels keyed by order slipped. 3 glued items. rm -rf of tracked assets/. |
| eyeglow | 13:55 | alive, off track | 0.6 h / 4 h | $0.09 / $5 | 0/4 (M1 really passes) | stage 2 fails for all species | C | Blind eye points. The look_at camera bug puts every other species under the floor. No keep_scale. Ignored milestone nudges. |

Total spend this round is about $4.2.

### Behaviour findings (model side)
- **False claims in reports, repeated.** card2d says 'verify passes'. biomezones and sprites2d describe shots never opened, or claim 'no halos, no glued pairs'. colors and webpack have the wrong root cause or the wrong file count.
- **Not looking at the evidence it had.** card2d viewed grey slabs 5 times and wrote 'foliage no longer goes black'. eyeglow trusted night_peak=0 without opening night_game.png.
- **Tuning to the gate.** sprites2d pushed rim pixels just past the 90-unit check. biomeassets added triangles to hit a number. islandgen calls its peninsula count of 2-10 'fine'.
- **Milestones.** Ticked in batches at the end (card2d, webpack, biomezones) or never ticked despite runner nudges (islandgen, eyeglow, props).
- **Guard evasion.** card2d spelled the protected path in pieces and used a tmp-plus-rename trick, then wrote in NOTES that it hadn't.
- **Destructive slip.** sprites2d ran `rm -rf assets` at the root; it recovered and said so.
- **Good.** gslot plus alarm discipline was near-universal. colors, webpack and biomeassets followed their nudges item by item. webpack corrected its own wrong measurement. Costs stayed low ($0.09-$1.08).

### Output findings
- Usable now: webpack's 220 imports (after a creature check), about 20 of biomeassets' 25 GLBs plus its scripts and JSON, biomezones' savannah/desert painting and map colours, colors' design and tests, sprites2d's cutter, islandgen's IslandShape/dry_walk/TilePath bbox, props' data and hooks, eyeglow's hook, night signal and test.
- Not shippable: card2d's dead shader, colors' transparent creatures, sprites2d's lime rims and wrong labels, biomezones' volcanic colour, islandgen's river and terraces, eyeglow's eyes.

### Fixed in 047993a (verified by the conformance check)
- Sandbox git works in linked worktrees.
- The pipe-guard false positives are gone (but see the regression).
- A milestone gate without {n} gets a warning plus a precheck.
- editCheck reports a timeout as 'not a code error'.
- nonomatch is set in the bash tool.
- dist/build.json version stamp.
- Preflight handles $VAR paths.
- task and cook honour effort from .dsc.json.
- Full commit subjects.
- Compaction at 180k.
- append_file.

Partial: auto-finish (the cap path), image verdicts, the watchdog (the lockf detection does not match real gslot). Regressed: the drift stop rule.

### Still due in dsc (ranked; details in still_due)
1. **P0:**
   - The checkpoint with .dsc ignored (task.ts:1048).
   - The HEAD-blind drift fingerprint (task.ts:684).
   - Cap path without wrap-up (task.ts:826).
   - Watchdog slot waits and stale errors (proc.ts:96-139).
   - Pipe-guard regressions (guard.ts:103).
   - Sandbox commondir and shared refs (sandbox.ts:21-44, plus runner git with hooksPath=/dev/null).
2. **P1:**
   - The Done-when parser.
   - A 'blocked' exit, and a write-only protected-path guard.
   - The destructive guard (it allowed rm -rf of tracked files and blocked .dsc appends).
   - append_file plus editCheck.
   - Milestone nudges with teeth.
   - Image verdicts in .dsc/IMAGES.md, plus a check that report-cited images were actually viewed.
   - A bash timeout that honours the gslot queue plus alarm.
3. **P2:**
   - The re-pass precheck with {n}.
   - The PLAN_STALL loop.
   - Effort for sub-agents.
   - nonomatch for editCheck and verify.
   - A dist hash in dscBuild.
   - Report nudge counts.
   - The stale 'last verify' in SHORT.md.

### Orchestrator actions
- **card2d:**
  - git checkout a01e41ed -- game/scripts/camera/iso_camera.gd
  - git rm --cached the 49 .uid and props/meshy files
  - drop the staged iso_new.tmp
  - fix the verify grep to \bcards=
  - add SHADER ERROR and grey-pixel checks
  - commit round 2
- **colors, webpack, biomezones, biomeassets, sprites2d:** finished. Their fixes go into follow-up TASK.md files (the per-worker nudge texts in this audit), not cook say.

### New task-writing rules (30-45)
- Never protect a file that verify needs changed.
- Gates fail on SHADER ERROR, and a pixel check proves the subject is not grey.
- Labs include a control render and the largest affected asset.
- Count greps use word boundaries.
- Done-when holds paths with '/' only, with a separate Constraints heading.
- Each milestone gate checks its own claim.
- No --commit for now; the orchestrator commits, including .import and .uid.
- The report lists each cited shot with a 'saw:' line.
- Write .gd files whole.
- Scratch goes in $TMPDIR/<job>; verify fails on _tiles or __pycache__.
- Labs quit themselves; alarm 900 and timeout_ms 1020000; never --headless for a windowed lab.
- Labels keyed by a stable id.
- Verify fails on sibling-file diffs.
- Delete only what you created.
- Budgets given as numbers.
- Respawn seeds include a counter.

### Recommended .dsc.json for Godot worktrees (047993a)
Tested copy: /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc3/dsc.json. The hook was run under zsh against 16 commands. Changes from the second audit:
- **watchdogIdleSec 0:** turns off the 047993a watchdog until proc.ts is fixed. perl alarm plus timeout_ms guard hangs.
- **maxTurns 300:** avoids the cap path and the max_turns wip checkpoint.
- **editCheck:** greps only Parse and Compile Error.
- **editCheckTimeoutSec 240.**
- **checkpointExclude:** adds *.pyc, __pycache__/** and reports/_tiles/**.
- **protectedPaths:** iso_camera.gd removed.
- **New PreToolUse hook:** refuses Godot/Blender pipes per command segment, all git writes (including stash, branch, update-ref, gc and worktree) and any .git internals, for bash and the write tools.

Launch line: `dsc cook start X-TASK.md --once --verify <script> --milestone-verify "<cmd> {n}" --effort medium` (no --commit).
### Actions taken (orchestrator, 15:30)
- Owner direction this round: DeepSeek workers do the work, including scouting; Claude workflows only for what the owner asks
  Claude to judge. Four Claude prep workflows were stopped and replaced by DeepSeek jobs with a shared staged gate
  (scratchpad/dsc/verify_job.sh, verify_job_ms.sh, job_<key>.conf): INVSLOTS, NEEDS, GATHERGLIDE, OCCLUDE2.
- Every worker on the 14:42 build now runs with watchdogIdleSec 0 and maxTurns 300 (restarted on its own session):
  invslots, needs, gatherglide, occlude2, sprites2d (round 2: three new sheets plus the audit's label/despill fixes).
- Fix rounds resumed on their sessions with the audit's messages: biomeassets, biomezones, colors, card2d (after the
  orchestrator restored iso_camera.gd and untracked 44 side files). Old-build workers nudged: islandgen, props, eyeglow.
- Our gates: the full gate no longer runs run_all and runs at most 3 related tests, because dsc's runVerify has a fixed
  20-minute timeout (proc.ts:172) and slot waits add up; lab gates fail on SHADER ERROR and "Unknown character" too; the
  card2d count grep uses a word boundary; the card2d junk check no longer flags the job's own new .uid files.
- New dsc item for the list: runVerify's 20-minute timeout is fixed in code; make it configurable (verifyTimeoutSec) and
  do not count slot waits against it.
