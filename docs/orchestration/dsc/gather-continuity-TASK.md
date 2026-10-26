# Task: GATHER-CONTINUITY — finish multi-resource gathering without a false “depleted” state

Owner outcome: a player selects a tree, chooses Logs, automatically equips an axe, gathers every
log, and can immediately choose Branches/Fruit on that **same visible tree**. The picker closes and
the tree falls/disappears only when every resource pool is empty.

The base now has per-resource harvest pools (`HarvestNode.pools`) and `has_harvests_left()`. The
keyboard Hands route already uses the whole-node rule. The remaining broken gameplay path is the
open gather radial: `PlayerActions.finish_gather()` closes it as soon as the currently selected
pool reaches zero, even if other options remain. That makes the tree look finished and makes the
player reselect it unnecessarily.

## Read first

- `AGENTS.md`
- `docs/design/durango-prompts/22_gather_ui_walkthrough.md`
- `game/scripts/world/harvest_node.gd`
- `game/scripts/player/player_actions.gd`
- `game/scripts/player/player_input.gd`
- `game/scripts/ui/gather_radial.gd`
- `game/tests/t_player.gd` and `game/tests/t_gatherglide.gd`

## Requirements

1. When a gather cycle exhausts its active resource but `HarvestNode.has_harvests_left()` is true:
   - Stop only that gather cycle; do not begin another pass for the empty resource.
   - Keep the existing `GatherRadial` open, keep it focused on the same node, refresh its counts,
     and make the exhausted option unavailable with its visible `0` count.
   - Clear its active/progress state so a remaining option can be tapped. The next selected option
     gathers on the same node normally and applies its own tool rule (Logs must still auto-equip an
     axe; bare-hand branches must not demand one).
   - Do not retain a stale `gather_target` or work animation while waiting for the next choice; the
     radial's own focus keeps the camera framing the node.
2. If every resource pool is empty, keep the current terminal behaviour: close the radial, clear
   the target, and let the node's normal fall/deplete path run. Do not create a second fall, log, or
   yield.
3. Preserve ordinary cancellation, full-bag, tool-break, target-invalid and tap-away behaviour:
   those close the menu as they do now. Never permit choosing an option with no units left.
4. Add a regression to `game/tests/t_player.gd` that uses a real `CommonTree`, a real axe and a
   real player/radial. It must demonstrate:
   - auto-equip + repeated log collection;
   - after the final log, the tree is visible, branches remain, the radial is still open/focused,
     and the empty Logs option cannot be selected;
   - selecting Branches immediately from that radial works;
   - after the final branch the tree is depleted and the radial closes.
   The test must fail against the base behaviour before the fix and print a clear assertion label.
5. Keep the implementation typed GDScript and mobile-first: the existing 64 px hexes and safe-area
   layout remain the one interaction surface. Do not launch a visible Godot window, browser, or
   desktop-control tool: all work and verification is headless.

## Scope

Allowed product files are strictly:

- `game/scripts/player/player_actions.gd`
- `game/scripts/player/player_input.gd` only if required to preserve the already-fixed whole-node selection rule
- `game/scripts/ui/gather_radial.gd`
- `game/scripts/world/harvest_node.gd` only for a small, reusable radial-state API
- `game/tests/t_player.gd`
- `docs/orchestration/reports/dsc-gather-continuity.md`

Do not alter pool sizes, item yields, tool durability, animations, shaders, scene layout, art, saved
data, unrelated tests, the old HTML game, other worktrees, the user's save, Git remotes, or deployment.
No paid services or asset generation. Do not merge, push, or deploy.

## Milestones

1. Add the real-player regression and run it against the base. Record its red result in the report.
2. Implement the narrow state transition and make the regression pass.
3. Run the full verification gate, commit the implementation, and write the report with the exact
   changed flow and any assumptions. Credits spent must be reported (expected: 0).

## Headless commands

Use Godot only through:

```sh
/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh \
  perl -e 'alarm 300; exec @ARGV' \
  /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_player.gd
```

Never pipe a Godot process to `grep`, `head`, `tail`, or `tee`; redirect it to a log and inspect the
log after it finishes. `t_save` is the only test allowed to print its documented corrupt-save errors;
this task's tests must have no `SCRIPT ERROR` lines.

## Final gate

Run `bash docs/orchestration/dsc/gates/verify_gather_continuity.sh`. It must print `VERIFY PASS`.
