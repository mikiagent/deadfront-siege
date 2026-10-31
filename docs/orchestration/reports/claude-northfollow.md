# claude-northfollow: TACKLE caption fix, card re-bake for the north-up camera, the t_controls hang

Branch `claude/mmo-northfollow`, cut from `origin/claude/mmo-overhaul` and merged with it after NORTHUP (49f3318f) landed. Not merged to canon.

## 1. t_fieldhud: TACKLE caption overlapped the auto-ability hex (1600x900)
- Cause: on desktop, `HudLayout.place_desktop` put the AUTOABILITY hex one hex left of Auto, which placed it directly under TACKLE, on top of TACKLE's caption.
- Fix (`game/scripts/ui/hud_layout.gd`): the hex now sits under TACKLE's caption, centred on TACKLE, between KICK and Auto. At 1600x900: hex (1116,730), caption (1106,788)-(1185,805). Phone and portrait layouts are unchanged; at 844x390 there were already 0 overlaps and the tap targets are 64 px.
- t_fieldhud PASS: 0 overlaps at both 844x390 and 1600x900, idle and in combat.

## 2. Card re-bake for yaw 0
- `card_bake.gd` already reads the camera basis from an `IsoCamera` instance, so it followed `YAW_DEG` = 0 without any change. One hard-coded angle remained: the bake's key light used a fixed world yaw of 35 deg, picked for the 45 deg camera. It is now `IsoCamera.YAW_DEG - 10`, which keeps the light where it was relative to the camera.
- `card2d_lab.gd`: `SCREEN_RIGHT` / `SCREEN_DEPTH` were constants for 45 deg. They are now derived from `IsoCamera.YAW_DEG`.
- I re-ran `--lab=card_bake` windowed and off-screen: `[cardbake] PASS cards=24`. All 24 albedo/normal PNG pairs were rewritten, `card2d.json` got new pivots, sizes and content boxes, and `--import` ran after.
- Most resources on the islands are the owner's painted sprites (872 painted vs 433 baked nodes in switch2d). Painted sprites do not depend on the camera angle, so the re-bake only changes the baked families (grass, bushes, mossy rock, branch pile, trees that have no painted art).
- Evidence (docs/orchestration/reports/northfollow/):
  - `before/switch2d_*.png`: north camera, old 45 deg cards. `after/switch2d_*.png`: re-baked cards. Home island and tropical_25, cards vs models, night, painted shading.
  - `card_<id>_before.png` / `card_<id>_after.png`: the albedo of tree-common-a, bush-berries-b, rock-moss-a and branch-pile, old vs new.
  - `before_card2d_split.png` / `after_card2d_split.png`: see the open issue below.
- PASS: t_card2d, t_switch2d (facing_err 0.00, grey_cards 0, tap_ok, empty_ok), t_structart.

## 3. t_controls "exit 70, no FAIL line"
- Cause: the test hangs. `_walk_case` steps the survivor `min(WALK_MPS/60, dist - REACH_M)` until `dist <= REACH_M`. On the north-up axes the last step lands at 1.6000004 m. The next step is then 3.8e-7 m, which rounds to no movement, so the loop spins forever. On the old 45 deg diagonals the rounding happened to land at or under 1.6.
- Exit 70 is `lockf` (inside gslot.sh) reporting that the child was killed by a signal. Killing a hung run reproduces exactly "rc=70, no FAIL line".
- Fix (test only, no game bug): the loop condition is now `> REACH_M + 0.001`. t_controls ran 3 times in a row, PASS each time, with 147 frames per walk direction.

## Gates
t_fieldhud PASS, t_controls x3 PASS, t_card2d PASS, t_switch2d PASS, t_structart PASS, t_autoability PASS, t_northup PASS, run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

## Open (not fixed, pre-existing)
- In `--lab=card2d_lab` the card half draws nothing: only the 3D half and its shadows appear, and `--mode=cards` shows an empty field. It is the same with YAW_DEG temporarily set back to 45, so NORTHUP did not cause it. The in-game cards render fine (switch2d shots). The likely suspect is the occlusion fade in that lab's setup, but I have not checked it.
- Credits spent: 0.
