# Disk cleanup inventory (2026-10-28)

Mac data volume before cleanup: 695 GiB used, 189 GiB free (`df -h /System/Volumes/Data`).
Sizes are `du`, which counts APFS clones in full, so worktree totals overstate real use.
Nothing below has been deleted yet. Deletion waits for Milan's OK in the thread.

## What takes the space

| Area | Size | Bucket | On GitHub? | Proposal |
|---|---|---|---|---|
| `deadfront-siege/.claude/worktrees/` (197 registered + 35 stray entries) | 388 GB | build worktrees, owned by the build thread | see below | build thread removes its own |
| `deadfront-dsc-work/` (DeepSeek rig/anim workspaces, Oct 18-20) | 18 GB | unused but intended | **no, not in git at all** | archive light part, delete the rest |
| `deadfront-art-wave/.dsc/worktrees/` (3 dsc tasks from today) | 4.2 GB | completely unused | yes, merged into `claude/mmo-jaws` (pushed) | delete |
| `deadfront-siege/.dsc-plan/merge/props2d-stale-*` (3 dirs) | 3.2 GB | completely unused | orphaned copies, their git link is gone | delete |
| `~/Documents/deadfront` (separate clone on `claude/mmo-overhaul`) | 3.0 GB | unused but intended? | yes, clean, nothing unpushed, 1189 commits behind | delete if Milan no longer works there |
| `deadfront-siege/.git` (object store shared by every worktree) | 2.1 GB | necessary | yes | keep |
| Godot export templates (`~/Library/Application Support/Godot`) | 2.2 GB | necessary | n/a | keep |
| `deadfront-art-wave/` (rest of the art checkout) | 1.7 GB | general game files | yes | keep |
| `deadfront-siege/` game, docs, archive, tools | 1.7 GB | general game files | yes | keep |
| `deadfront-gate/` (integration checkout, build thread is merging here) | 1.5 GB | necessary | yes | keep, not touched |
| Active dsc runs: `m0-plan-jobs` 1.7 GB, `c0-save-recovery` 1.2 GB, `m0-foundation` 0.9 GB, `c0-plan-jobs` 0.9 GB, codex `dsc-test-gate` 1.4 GB | 6.1 GB | necessary while running | branches backed up (below) | keep until the runs finish |
| `deadfront-siege/.dsc/worktrees/task-10271023-ee0` (Stegosaurus skin weights) | 1.3 GB | completely unused | yes, backed up as `claude/archive-wt/dsc-task-10271023-ee0` | delete |
| codex worktree `deadfront-overnight` (Codex is retired) | 0.9 GB | completely unused | yes, backed up as `claude/archive-wt/codex-deadfront-overnight` | delete |
| Per-worktree game saves `~/Library/Application Support/deadfront-*` (512 dirs) | 1.3 GB | 247 `deadfront-scratch*` dirs (439 MB) are test saves | n/a | delete only `deadfront-scratch*` |
| `deadfront-siege/export/web` (old web export, Oct 17, untracked) | 0.3 GB | completely unused | regenerable | delete |
| `deadfront-ui-screens/` | 38 MB | unused but intended | regenerable with `tools/ui_screens.sh` | archive, delete |
| `.dsc-plan/merge/*-gate` logs | 21 MB | completely unused | n/a | delete |

## Build worktrees (owned by the build thread)

The build thread said these are all on GitHub. They were not. On 2026-10-28 I found:

- 75 registered worktrees had commits on no remote branch (72 with commits whose patch is not in `origin/claude/mmo-overhaul` either).
  All 73 local-only branches are now pushed as backup refs `claude/archive-wt/<branch with / replaced by ->`
  (for example `claude/archive-wt/claude-mmo-invui`). No existing branch was changed.
- 41 worktrees have modified tracked files that no push covers (largest: `mmo-int-1793226373` 2616 files, `mmo-webpack2` 222, `mmo-icons4` 82).
  The build thread has to commit or deliberately discard these before `git worktree remove`.
- 35 entries in `.claude/worktrees/` are not registered worktrees (stale `deadfront-*.js` job files, `mmo-foodfx-stale-20261025-0953`); safe to delete with the worktrees.

## Proposed delete list (needs Milan's OK)

Total about 31 GB, not counting the build worktrees.

1. `~/Documents/deadfront-dsc-work` (18 GB), after the light archive below is pushed.
2. `~/Documents/deadfront-art-wave/.dsc/worktrees/*` (4.2 GB) via `git worktree remove --force`.
3. `~/Documents/deadfront-siege/.dsc-plan/merge/` stale dirs and gate logs (3.2 GB).
4. `~/Documents/deadfront` (3.0 GB), only if Milan confirms they no longer work from it.
5. `~/Documents/deadfront-siege/.dsc/worktrees/task-10271023-ee0` (1.3 GB) via `git worktree remove`.
6. `~/.codex/worktrees/deadfront-overnight` (0.9 GB) via `git worktree remove --force`.
7. `~/Library/Application Support/deadfront-scratch*` (0.44 GB).
8. `~/Documents/deadfront-siege/export/web` (0.3 GB) and `~/Documents/deadfront-ui-screens` (38 MB).

## The dsc-work archive

`deadfront-dsc-work` has never been in git. The light part (task files, verify scripts, Python tools, reference and review
images, logs, about 0.9 GB) is staged for a new **private** repo `mikiagent/deadfront-archive`, together with
`deadfront-ui-screens` and the two untracked codex overnight files. Creating that repo needs Milan's OK.
Left out: `work/` scratch dirs, per-workspace `.git` checkpoint histories, and about 3 GB of .glb/.blend/.fbx/.mp4
intermediates. The shipped results of those tasks are in deadfront-siege under `game/assets`.
A separate repo keeps those binaries out of every deadfront-siege clone and fetch.

## Restore

- Any backed-up worktree branch: `git -C ~/Documents/deadfront-siege worktree add ~/Documents/deadfront-siege/.claude/worktrees/<name> origin/claude/archive-wt/<branch>`
- `~/Documents/deadfront`: `git clone -b claude/mmo-overhaul https://github.com/mikiagent/deadfront-siege ~/Documents/deadfront`
- dsc-work light archive, UI screens: `git clone https://github.com/mikiagent/deadfront-archive`
- A slim checkout without archive and docs: `git sparse-checkout set --no-cone '/*' '!/archive/' '!/docs/'`, undo with `git sparse-checkout disable`
