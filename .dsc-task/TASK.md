# Task: ALPHATAG — alpha animals per Milan's rules

Repo: WildLands MMO, Godot 4.7.1 typed GDScript. Read AGENTS.md first. Work only in this worktree.
Milan (verbatim): "Alpha should be a tag in front of the name (prefix tag). The alpha animals are larger, not tamable/capturable, and drop better loot (and special loot pools specific to alpha animals)".
Alphas already exist (GENETICS + ALPHAS package: creature_genetics.gd, Spawner force_alpha, LootRoller guaranteed rolls, butcher_loot.gd alpha call, t_alphas, t_genetics). Do:
1. Name plate: show "Alpha" as a prefix tag before the creature name (a small gold tag/chip, e.g. "[ALPHA] Deinonychus" styled as a tag, not plain text); wherever the creature's display name shows (plate, target UI, kill/loot notices).
2. Alphas are larger (check the current alpha size multiplier; keep or set a clear one, # ASSUMPTION).
3. Alphas are NOT tamable and NOT capturable: capture/knockout/pen flows refuse with a clear message ("Alphas can't be tamed"). Check every entry point (capture, field tame, pen placement, torpor knock-out if present).
4. Better loot + alpha-specific loot pools: a data-driven `alpha_pool` per species or per class in the loot tables (special drops only alphas give, e.g. alpha trophy/hide/tooth items; add a few items in items.json following existing conventions, # ASSUMPTION names), on top of the existing guaranteed better rolls.
5. Tests: extend t_alphas (prefix tag shown; refusals on every capture path; alpha pool drops present; normal animals never drop alpha-pool items). Print PASS lines as the tests do.
Every number `# ASSUMPTION`, logged in docs/vision/WildLandsMMO_Open_Questions.md; update docs/current creatures page.
Run Godot exactly: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > $TMPDIR/<t>.log 2>&1`, then read the log; never pipe Godot output. After adding a class_name run --import first.
Done when `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_alphatag.sh` prints VERIFY PASS. Write docs/orchestration/reports/dsc-alphatag.md. Commit with a message ending `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Do not push.

## Follow-up (integrator): the merge onto canon fails t_data
Merged onto origin/claude/mmo-overhaul (now 3d5d84b0), everything passes except `t_data`, which canon alone passes:
"[t_data] FAIL recipe improvised_stone_knife takes copper-tier material as its primary with skill gate Lv 0, below the ladder's copper gear gate Lv 30" (same for work_axe, work_pick).
1. `git fetch origin && git merge origin/claude/mmo-overhaul` (keep both sides; Open Questions: both).
2. Find which of this branch's data changes (new alpha items/categories/tiers in items.json, loot tables, material tiers) makes those recipes' primary material read as copper-tier, and fix it at the root without loosening t_data.
3. Add t_data to your verify list mentally: it must PASS. Then VERIFY PASS as before; update the report.

## Follow-up (integrator, 03:01Z): re-merge onto the new canon
Canon moved (FOODTORPOR, SLOWLEVELS, CREATURECHIPS, CHASESPRINT landed). Merging this branch now conflicts in: game/data/items.json, game/scripts/server/world_facade.gd.
1. `git fetch origin && git merge origin/claude/mmo-overhaul`. Resolve keeping BOTH sides' intent (JSON: keep every row from both sides, no duplicate ids, valid JSON; code: combine both changes; docs: keep both sections). Open Questions: keep both.
2. Rerun your verify. VERIFY PASS as before; append a "re-merge" note to your report; commit (message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`). Do not push.
