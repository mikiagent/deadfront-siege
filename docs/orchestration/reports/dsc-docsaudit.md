# dsc — DOCSAUDIT: docs/current brought back in line with the code

Task: after tonight's merges (pet follow slots, STATUSFX boxes, tactical AI, the UINAV/UICHAR/UICRAFT/
UIANIMALS/UIMARKET screens, RAREATTR, COOKROLES), audit every page in `docs/current/` against the code
and fix what is stale. Docs only; no Godot runs. Verify:
`verify_docsaudit.sh` (every `` `path` `` and `` `func()` `` cited by a page must exist; the report must
exist; nothing outside `docs/current/` and `docs/orchestration/` may change).

*(This report is completed at the end of the run; the sections below are filled per page as each page is
fixed.)*
