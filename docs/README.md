# DEADFRONT docs — the archive line

This line (`main`) is the **deep archive**: orchestration prompts, session reports,
playtests, PRDs, superseded designs. It is one deliberate search away through the wiki's
**deep** toggle and `git show main:<path>` — it is never edited in place and never loaded
by default.

## Where the truth lives instead

The **canon line** owns everything true today, single-homed (2026-10-27 consolidation —
one source of truth, updated once):

- the `claude/mmo-overhaul` worktree: `.claude/worktrees/mmo-overhaul/`
- its `docs/vision/` — owner's `WildLandsMMO_*` spec set
- its `docs/current/` — per-system today-truth, including `controls.md` and the generated
  data pages
- its `docs/reference/`, `docs/design/` — build-consumed corpora (sprites2d inputs,
  code-cited prompt specs)
- its `tools/docs_wiki/` — the wiki server itself, rerooted to treat this checkout as the
  deep archive it deep-searches (run from the canon root:
  `python3 tools/docs_wiki/docs_wiki.py serve` → http://localhost:8899)

## Rules for this line

- Archived docs **don't get updated** — they are the record of what was true when written.
  The `docs/controls.md` copy here is the historical input sheet; canon's
  `docs/current/controls.md` is the live one.
- If a canon doc goes stale, `git mv` it here in the same commit; never keep twins. The
  wiki auto-flags any path that exists on both lines with different bytes — every one of
  those flags means a redundant copy to reconcile.
- Rebuild-from-history is always possible: every historical version is in this line's git
  history.
