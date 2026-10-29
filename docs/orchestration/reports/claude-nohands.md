# claude-nohands: remove the HANDS quick-slot hex

Owner (Milan): "remove this vestigial hands button (interact is the same)". Branch `claude/mmo-nohands`
from `origin/claude/mmo-overhaul` (2c446449). Not pushed or merged.

## Shipped
- `game/scripts/ui/held_item_slot.gd` (`HeldItemSlot`) deleted; `StationCraft` no longer builds `held_slot`
  (and its `_on_equip` / `_on_unequip`). The hand model still follows the held tool: `_sync_hand_tool` runs
  every frame.
- `HuntHud.hands_spot()` replaced by `quick_row_y()` (the quick row's top). Its users now use that:
  the quick-row layout, the portrait context-hex row, `LevelUpCelebration.desktop_anchor`. The context-hex
  wrap now stops at the CHASE slot's right edge instead of HANDS'.
- Landscape HUD zone 4 (`UiTokens` quick row) is 240 px wide instead of 308, so the fourth slot is free.
- HANDS removed from `taken_rects` (hunt_hud, hud_layout) and the pet radial's fade.
- Bag: on the tool you're holding, the Equip button now reads **Unequip tool** and clears the held tool
  (back to the best tool in the bag, which was what the old long-press did).
- Tests and labs: t_ui (checks the CHASE slot and that no fourth slot is reserved), t_fieldhud (asserts no
  HeldItemSlot), t_controls (presses the INTERACT hex and checks the same nearest-gather, nav and radius
  cases HANDS had), t_claimfix / t_uinav comments. The HUD lookup `has_method("hands_spot")` in 12 tests
  is now `has_method("quick_row_y")`. HeldItemSlot code is gone from ui_icons_lab, ui_real_capture_lab,
  claimfix_lab, pet_radial_lab and craft_lab.
- Docs: docs/current/hud.md, docs/current/controls.md.

## How tools are swapped now
- Gather nearest: INTERACT (E, pad A, the HUD hex) falls back to the nearest resource within 12 m along
  the same path HANDS used (`PlayerInput.interact_choice` -> `_gather_choice` -> `_gather_node`).
  Space still works.
- Equip a tool: open the bag, select it, press Equip tool. To unequip, select the held tool and press
  Unequip tool.
- Cycle: tap the tool slot on the Character sheet. Each tap goes to the next tool, like HANDS' `cycle()`.
- Picks are still auto-swapped when a node needs a better one (`HarvestNode`).

## Checks
- t_ui, t_fieldhud, t_controls, t_uinav, t_claimfix, t_targetui, t_uiicons: PASS.
- run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
- ui_real_capture_lab at 844x390 (windowed, off-screen): screenshot is
  `docs/orchestration/reports/nohands/hud_nohands_844x390.png`. The lab prints FAIL lines, all outside the
  bottom-left area: the minimap overlaps orders_badge (top right), the atlas card count, the bag profile
  columns, toast counts, an 11 pt text floor, the AUTO hex vs nameplate in combat. None of them involve the
  quick row or rail. I did not rerun them on the base, so whether they predate this branch is not confirmed.
  The orders_badge one may be the hudtweak agent's area.

## Not done / assumptions
- The fists/hands icon logic is gone with the slot because nothing else used it. The `fists`/`hands` icon
  files stay.
- Meshy credits spent: 0.
