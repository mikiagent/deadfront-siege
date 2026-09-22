# OPUS-SAFE - DEADFRONT Durango-style UI redesign (pointer)

The canonical spec is `OPUS-UI-REDESIGN-PROMPT.md` at the repository root (committed by the
other session on 2026-09-21). Read that file and `HANDOFF.md` and carry the spec out completely.
The reference screenshots it names are in `docs/reference/`.

Run notes for the implementing agent (Cursor, Grok 4.7, driven by `tools/run_cursor.sh`):

- Stage only the files you changed; never `git add -A` (the tree carries untracked art and
  addon folders that are not yours).
- Do not run `tools/publish_pck.sh`, `tools/deploy_web.sh` or any Vercel deploy; Claude Code
  publishes after review. Report the commit hash where the spec asks for an alias stamp.
- If `ui_family_lab` or another named lab does not exist, say so in the report and use the
  closest existing lab plus the screenshot lab the spec asks you to add.
- Report: `docs/orchestration/reports/cursor-ui-redesign.md`.
