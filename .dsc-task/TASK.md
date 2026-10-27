# C0 save safety in the existing game

Continue the existing game rooted at game/. Base is origin/main
923657262cd335fefee9126df61dd0fff4b93321. Work only in this plan's
isolated worktree and preserve all existing game and save behavior.
The owner permits visible Godot for the existing project; automated
tests run headlessly. Never open or modify the owner's real save during
tests. Use only unique temporary fixture paths. Do not deploy or push.

Read AGENTS.md, docs/orchestration/plan.md, game/scripts/core/save_game.gd,
save_migrations.gd, game/tests/run_all.gd and relevant existing save
fixtures. The continuation docs exist on Git branch
origin/docs/current-code-continuation-blueprint-2026-10-26, not this
base. Read docs/continuation/05-FIRST-TICKET.md and
02-COMPATIBILITY-AND-MIGRATIONS.md from that branch via git show.

Scope: game/scripts/core/save_game.gd, save_migrations.gd if needed,
a small save_recovery.gd helper, targeted existing test runner/fixtures,
a focused save_recovery_lab and its scene, and the report. Preserve
save_now(), load_now(host), user://save_1.json, bot-only bot_save.json,
schema 3 and migration 0->1->2->3. Preserve all saved fields and legacy
inventory, pets, buildings, cargo, skills, progression and UI.

Use red-green cycles around the user-visible save/load behavior. Add
representative schema 0,1,2,3 fixtures and prove fields/quantities and
building positions survive. Add regressions for corrupt/truncated saves,
schema 99, failed/partial staged writes and interruption before/after
promotion. Preserve bad/future primary bytes and valid backups, prevent
autosave or explicit save from overwriting blocked files, and expose a
clear safe error state through the existing boot path. A recoverable
backup must remain available; never silently accept a future schema by
falling back and overwriting it. Avoid inventing irreversible new-game
or data-loss policy. Check rename/flush results and handle every failure.
Document platform limits accurately, especially web filesystem syncing.

Keep tests isolated from real user://save_1.json and use unique test
directories. Existing --bot path selection must remain isolated. Do not
alter gameplay formulas, item/crafting code, combat or deployment.
Preserve old public APIs and avoid replacing the save schema.

Run Godot 4.7.1 via /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh
and perl alarm timeouts. Never pipe Godot output to grep, head, tail,
or tee. Seed the fresh worktree with a clean headless import. Capture
exact failing regression evidence before implementation and passing
results after. The focused lab must quit with exit 0 and print the exact
marker SAVE RECOVERY LAB PASS only after its checks pass. tools/test.sh
and tools/smoke.sh must pass. Write
docs/orchestration/reports/dsc-c0-save-safety.md with actual results,
assumptions, unresolved risks, credits and files changed. Commit only
scoped code and stop for orchestrator review.
