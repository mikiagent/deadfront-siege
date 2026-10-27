# Agent context and archive search

Date: 2026-10-27. Work is in the `claude/mmo-overhaul` canon checkout.

## Shipped in the working tree

- The ordinary wiki index contains canon documents only and does not enumerate the archive. `/archive <term>` performs an explicit historical text search; explicit archived-document links and saved curation state remain available. Automatic cross-line diff detection no longer runs as part of the default index.
- `docs/agent-context.md` directs coding agents to relevant sections of the same vision documents, current docs, game code, and tests the wiki uses. The canon and archive `AGENTS.md` files point to that entry point. The current and vision indexes now link to their documents; the canon docs README describes the new archive command and links to the maintenance guide.
- The recipe generator and generated recipe page now distinguish skill, minimum skill, ability target, and configured output cap, and say that a data row does not prove an output is playable. Regeneration used temporary sheets; existing live sheets were not overwritten.
- The system classifier no longer treats the project name as a multiplayer signal. The outdated model API test fixture was made into a valid minimal GLB and isolated from the user's state.

## Verification, remaining work, and handoff

Thirteen wiki unit tests passed, as did the isolated archive browser test and a live search for `/archive taming` followed by opening a historical article. `tools/smoke.sh` printed `SMOKE PASS`; `node --check` and `git diff --check` passed. No Meshy credits were spent and no new game mechanics were assumed.

Ordinary search still filters titles, paths, and systems rather than article bodies. Several current-system docs and the vision Open Questions register remain missing. Wiki Markdown still needs sanitization before untrusted documents are accepted. The archive command is opt-in; it reads history on request. Owner marks remain local state.

Canon wiki files and the new guide remain uncommitted in the shared worktree, which already contained other OpenCode changes and staged coelophysis asset deletions. Do not stage or commit the whole worktree. Coordinate with OpenCode before integrating, and preserve the existing staged changes. The running preview was started on localhost:8899; another OpenCode wiki server was on port 18992.
