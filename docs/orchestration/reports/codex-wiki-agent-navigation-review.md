# Wiki agent-navigation review

Date: 2026-10-27. Review of the live `claude/mmo-overhaul` checkout and the wiki at localhost:18992.

## What shipped

This report records a read-only walkthrough, not a wiki change. The home page and maintenance guide distinguish current implementation, vision, proposals, and archive, but the wiki alone does not yet give an agent a reliable, short route from a system request to the authoritative design, code, and tests.

## Findings

- The document search filters title, path, and system name, not article text (`tools/docs_wiki/app.js`, `visibleDocs`). Searching for taming missed relevant sections of the umbrella vision. The system classifier puts all five WildLandsMMO vision files under Multiplayer & server because it matches `mmo` in the filename (`tools/docs_wiki/docs_wiki.py`, `system_of`).
- Current and vision index tables use code-formatted filenames rather than links. The Open Questions register is referenced but absent. A focused link check found 10 broken occurrences among 25 relative non-fragment links in current and vision docs. The current index lists five important system pages as unwritten.
- The generated recipes page labels `max_level` as a skill threshold. For `raid_maul` it shows `weapon_tools ≤ 60`, while `recipes.json` specifies `min_level: 55`, `max_level: 60`, and `required_ability: 95`; the crafting code uses the minimum as a progression gate and the maximum as an output-level cap. Fix the generator and review generated pages without overwriting sheet edits. The catalog also includes outputs named `(Planned)`, so a data row is not proof of playable functionality.
- `/api/index` returns metadata for both canon and archive even when the interface hides archive entries. It returned 218 entries, 136 archive. It does not automatically put all document bodies in an LLM context. Curation marks are in gitignored `tools/docs_wiki/state.json`, so file-only agents may miss them.
- Canon `docs/README.md` says the survival and HUD pages are pending, although both now exist. Its cross-worktree `git mv` instruction conflicts with the accurate guidance in `docs/wiki-maintenance.md`.

## Suggested next work

Create a concise per-system map linking specific vision sections and approval status, current behavior, owning code/data, tests, and unresolved questions. Make index links clickable; implement section-level body search with explicit archive opt-in; correct classification and recipe semantics; add the missing question register and current-system pages. Provide a stable machine-readable route to owner curation without duplicating authoritative content. Separate versioned design decisions from machine-local review marks.

## Verification and handoff

Used the running wiki for a taming search, inspected a crafting example against source, and checked navigation and links. `tools/smoke.sh` printed `SMOKE PASS`. No game mechanics or assumptions were added; no Meshy credits spent. The next agent should coordinate with the active OpenCode work and preserve its uncommitted changes. The supplied browser URL used port 8899, while the running wiki was on 18992 during this review.
