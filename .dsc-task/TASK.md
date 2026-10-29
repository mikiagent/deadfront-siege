# Task: HUDFALLOUT — two tests red on canon after the HANDS button was removed

Repo: WildLands MMO, Godot 4.7.1 typed GDScript. Read AGENTS.md first. Work only in this worktree; commit at the end.

Canon (origin/claude/mmo-overhaul) removed the HANDS quick-slot (NOHANDS): `HeldItemSlot` and `HuntHud.hands_spot()` are gone,
replaced by `HuntHud.quick_row_y()`. Two standalone tests still fail on canon:

1. `game/tests/t_death.gd` fails "the lab kit has a HuntHud": around line 36 it finds the HUD with `c.has_method("hands_spot")`.
   Fix: find the HUD the way the other tests now do (`c.has_method("quick_row_y")`, see game/tests/t_fieldhud.gd / t_uinav.gd).
2. `game/tests/t_gather.gd` fails a HUD notice-position check (`_test_hud_notice_life` or another HUD-notice check; run it and
   read the FAIL line). Find out whether the test still assumes the old HANDS slot / quick-row layout (then update the test's
   expectation to the new layout from game/scripts/ui/hunt_hud.gd) or whether the HUD really places notices badly now (then fix
   the placement in game/scripts/ui/, smallest change). Say which in the report.

Do not change gameplay code outside game/scripts/ui/. Do not touch other tests except those two.
Run Godot exactly like this (headless): `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 600; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/<t>.gd > $TMPDIR/hf_<t>.log 2>&1`, then read the log. Never pipe Godot output.
Done when `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-gate/a2917b6d-2049-454d-9c63-314953df33d7/scratchpad/dsc/verify_hudfallout.sh` prints VERIFY PASS.
Write docs/orchestration/reports/dsc-hudfallout.md (what failed, why, what changed). Commit with a message ending in
`Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`. Do not push.
