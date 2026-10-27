# Plan review follow-up

Date: 2026-10-27. The wiki work is in the shared `claude/mmo-overhaul` checkout.

## Shipped in the working tree

- The wiki has a plan-review interface for a pasted or dropped Markdown plan, conflict questions, source excerpts, reviewed vision edits, and document-split previews. OpenCode extended the split workflow while this work was paused.
- Hardened split application against symlinked source directories, a destination created after preflight, and a source revision change detected before replacement. Rollback preserves section files changed by another process. The final hash check and replacement are not an atomic filesystem compare-and-swap, so an external editor can still race them.
- Started a fresh wiki process on localhost:8899 to load the current code. Earlier OpenCode processes may still be running older code on other ports.

## Verification and outstanding work

- All 49 wiki unit tests passed, including 13 split-refactor tests. A same-origin split preview returned two sections, and a cross-origin request was rejected. `tools/smoke.sh` printed `SMOKE PASS`; `node --check` and `git diff --check` passed.
- A live test of the configured OpenCode model returned its free-model quota error. The AI analysis cannot currently be verified end to end. The owner plan and edits were not changed during testing. Retry after the provider limit resets; do not claim conflict detection succeeded until it does.
- The existing OpenCode session stopped with the same quota error while investigating owner UI screenshots; the new screenshot cards were not added. Continue that request only after inspecting its session and current files.
- The canon checkout contains pre-existing uncommitted work and staged asset deletions from another agent. Preserve these; do not stage the entire worktree. No Meshy credits spent. No new game mechanics or assumptions added.
