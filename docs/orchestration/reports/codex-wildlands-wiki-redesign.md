# Wildlands MMO wiki redesign

Date: 2026-10-27. The live wiki is in the `claude/mmo-overhaul` worktree.

## Shipped

- `aff0801d` gives the wiki a light, article-centered layout and the visible name Wildlands MMO. The home page separates current implementation from vision; the archive is hidden until enabled.
- Article links survive reload and browser navigation. Relationships keep their canon or archive identity, legacy path-only relationships remain readable, anchored Markdown links work, and system lists no longer truncate. Clearing a document status retains its notes and relationships.
- `afdcc41e` stages generated data pages and refuses to overwrite differing CSV sheets or sheet notes without `--force-sheets`. The focused test uses temporary output directories.
- The existing OpenCode session continued documenting the game and committed current survival and HUD pages in `d55be2e8`.

## Verification and remaining work

- Canon `tools/smoke.sh` printed `SMOKE PASS`. JavaScript syntax, `git diff --check`, and the focused generator test passed. Isolated Chrome checks passed for conflict links, legacy relationships, internal anchors, external links, browser history, and full system lists. Test artifacts for this session are under `/tmp/wildlands-*`.
- The wiki does not yet edit vision documents or spreadsheets in the browser. The nine CSVs can be edited externally; the sync script applies them to game data. A failing sync gate currently leaves the written JSON changes in place.
- Full-text search is not implemented. The system classifier still misclassifies several vision files, and the referenced vision Open Questions register is missing. Some current-system docs remain unwritten.
- Markdown rendering still permits raw HTML. Add a vetted sanitizer and malicious-input tests before accepting untrusted documents or broadening access. Generation can leave partial output on a filesystem write failure; `--force-sheets` can discard unsynced edits, so review differences first.
- Running the Godot smoke check produced untracked CSV import/translation sidecars under `game/data_sheets/`; other untracked asset imports already existed. Do not stage them blindly.

Meshy credits spent: 0. No lore or gameplay assumptions added. Next agent: continue the editable vision and spreadsheet workflows, verify source-of-truth labels against code and owner-approved vision, and coordinate with the active OpenCode session before editing its files.
