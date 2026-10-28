# Task: DOCSAUDIT — bring every docs/current page in line with the code after tonight's merges
docs/current/ is the wiki's "facts only" section: it must describe what the code does today, nothing planned. Tonight
these landed on claude/mmo-overhaul and several pages may now be stale: pet follow slots, status-effect boxes (STATUSFX),
the tactical enemy AI template (docs/current/enemy-ai-template.md), the nav menu and the new screens (Character, Skills,
Orders, Craft/place materials, Build drawer, Animals, World Atlas, Harbour, Island Market), rare material attributes,
cooking roles. Read `git log --oneline -40` and the reports in docs/orchestration/reports/ for what changed.
For each page in docs/current/: check every claim, path, function name, number and screen description against the
code (grep the scripts and data), fix what is wrong, remove what no longer exists, and add a short paragraph for any
shipped behaviour the page's topic covers but doesn't mention. Keep each page's structure and voice; no planned work,
no speculation (anything not in code goes nowhere, or into a one-line "not built yet" note). Update docs/current/README.md
so it lists every page with a one-line description.
Do NOT touch any file outside docs/current/ and docs/orchestration/. No Godot runs are needed.
Milestones:
M1 an audit list in .dsc/NOTES.md: per page, each stale claim found with the code evidence (file:line).
M2 the fixes, page by page, committed per page.
M3 report docs/orchestration/reports/dsc-docsaudit.md: per page what changed and why; then the full verify.
Verify: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_docsaudit.sh` (every cited path and `func()` must exist).
