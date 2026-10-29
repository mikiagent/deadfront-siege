# Task: HUNGER — the stomach becomes a budget (owner-approved memo, Part 1)

Repo: WildLands MMO, Godot 4.7.1 typed GDScript. Read AGENTS.md first. Work only in this worktree.
Milan approved this design: read it in full with `git show origin/claude/mmo-hunger-tribe-doc:docs/design/hunger-and-tribe-automation.md` — Part 1 (§1.4 Recommendation and §1.5 "What changes in data and code"). Implement exactly §1.4 items 1-6 and the §1.5 table:
- rules.json gets a `hunger` block (decay_per_min 2.5, band edges, fatigue_mult per band, starving_after_s 600, well_fed_regen 0.2); retire fatigue.fullness_mult.
- foods.json: rescale `fullness` per food class (raw fruit/berries 6-10 with `snack: true`; simple cooked 25-30; dishes with roles 45-60; feast 80+).
- statuses.json: starving 0.1 HP/s, stacks every 180 s up to 3, stays nonlethal (stops at 1 HP); new well_fed buff chip.
- digestion.gd: fullness is a stored, saved value with add_fullness(n) from EatSession and decay in tick; save adds `fullness` and `empty_for_s`; an old save seeds it from today's formula once.
- meal buffs with duration_mode "while_fed" (default for cooked dishes) last until fullness < 10.
- hud_stomach.gd inner ring reads stored fullness with the band colours; outer ring = meal buff time left.
- player_sim.gd: Starving only after starving_after_s on an empty stomach; autofeed fires at Peckish.
- tribe.json: drop fullness_per_day, use the shared hunger block.
- Status damage ticks (starving) must NOT cancel gathering or sleep (existing rule; keep it).
- Tests: update t_hudrules (stomach states), t_needs, t_foodfx, t_tribe as needed; add game/tests/t_hunger.gd (decay rate, bands, while-fed buff expiry, starving delay, old-save seed). Print `[t_hunger] PASS`.
Mark every number `# ASSUMPTION` as the memo does. Update docs/current pages that describe hunger.
Run Godot exactly: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > $TMPDIR/<t>.log 2>&1`, then read the log; never pipe Godot output. After adding a class_name run --import first.
Done when `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_hunger.sh` prints VERIFY PASS. Write docs/orchestration/reports/dsc-hunger.md (what changed, save change, assumptions). Commit with a message ending `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Do not push.
