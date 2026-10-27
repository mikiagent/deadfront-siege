# dsc — INVSLOTS (bag = scrolling slot grid, upgradable capacity)

Task: `docs/orchestration/dsc/invslots-TASK.md`. Verify: `verify_job.sh invslots` (stages 1 and 2 pass).

## What shipped

- **`game/scripts/ui/bag_grid.gd` (new, `class_name BagGrid`)** — the bag/storage/cargo grid.
  A `ScrollContainer` (touch drag, wheel, scrollbar) over a `GridContainer` of exactly
  `Inventory.slot_count` compartments, one per bag index. One item instance per slot; empty slots are
  drawn as compartments; no count pills and no grouping anywhere. Each cell is drawn flat (faint
  frame, item art centred, "Lv N" bottom-right for instances above level 1, a green diamond top-right
  when the instance carries a trait the def does not give every one, gold L-shaped corner brackets on
  the selected slot). A compartment selects on *release*, and only when the pointer stayed within a
  12 px deadzone of the press: a touch drag that scrolls a storage box no longer takes the item under
  the finger. `cell_px` is set by the host and never below 48; the phone uses exactly 64.
- **`game/scripts/ui/inventory_ui.gd`** — the rejected grouped bag (`_bag_cells`, `_open_group`,
  count badges, level ranges, back cell, 20 fixed cells) is gone. The bag column now holds a header
  `BAG  used / capacity` (capacity from `Inventory.capacity()`; `UiTokens.DANGER` when full) and a
  `BagGrid`. Storage / pet cargo (`show_storage`, `show_pet_bag`) use the same `BagGrid` instead of
  a second grid of buttons, so a box, a corpse and pet cargo all read as the same compartments.
  Tapping a compartment selects that exact instance (the tip/actions are unchanged); storage taps
  keep the existing take path.
  Layout: desktop = profile | bag | equipment at a slot capped to 96 px (8-9 dense bag columns, 4
  equipment columns) so the equipment column, the tip and the action row all fit inside the panel;
  compact landscape (844x390) = bag | equipment (profile folds away — its facts are already on the
  Character sheet), 5x2 gear grid of 56 px, one 64 px action row, one-line tip. With a box open at
  either size, the bag keeps a band, the box gets the same band below it and the page scrolls to it.
- **Equipped slot text** — a def with no art shows its display name only ("Woven Bag"), never the raw
  id (`woven_bag`), substituted in `inventory_ui.gd` because `item_icons.gd` is outside this task's
  scope and is unchanged.
- **`game/data/items.json`** — one data-only bag item, `woven_bag` ("Woven Bag",
  categories `accessory`/`bag`, `bag_slots: 20`). See assumptions.
- **`game/tests/t_invslots.gd` (new)**, **`game/scripts/dev/invslots_lab.gd` +
  `game/scenes/dev/invslots_lab.tscn` (new)** — see below.

Model changes: **none needed.** `Inventory` already keeps one instance per slot (W2-INV) and
`InventoryEquipment.capacity()` is base 100 + each worn item's `bag_slots` + `pocket × 6`
(`data/inventory.json`), with `resize()` refusing a shrink that would cut occupied slots and
`unequip()` refusing when the bag cannot hold the item. The save format already carries worn gear in
`inventory_extras.worn`, so capacity is derived on load: **no save-format change**.

## Before / after (measured)

Before (inventory_lab, 1600x900 and 844x390): one cell per item id — stones were a single cell with
a "16" corner pill and caption "Lv 1-16", a second tap opened the group; no scroll; no bag capacity in
the bag header (only "Bag 80 / 100" buried in the profile list); 5 fixed columns.

After (`invslots_lab`, measured live at each resolution):

| | 1600x900 | 844x390 |
|---|---|---|
| capacity / grid_slots | 100 / 100 | 100 / 100 |
| items / filled / empty_visible | 91 / 91 / 9 | 91 / 91 / 9 |
| pills | 0 | 0 |
| min_slot_px | 96 (8 dense columns) | 64 |
| scroll_range (px, 100-slot bag) | 2788 | 2802 |
| frame_ms_p95 (300-slot bag, scrolling) | 14.9–24.9 | 13.2–25.0 |
| cap_upgraded → cap_after_unequip | 120 → 100 | 120 → 100 |
| items_lost on a refused unequip | 0 | 0 |
| actions_in_panel / min_action_px | 1 / 44 | 1 / 64 |
| storage_visible after page scroll | 1 | 1 |
| drag_ok (a 50 px drag selects nothing) | 1 | 1 |

300-slot bag: `capacity=300`, grid 300 compartments, p95 well under the 33 ms gate.

## Tests

- `game/tests/t_invslots.gd`: 5 identical bones take 5 slots with 5 distinct uids and 5 levels; a
  fresh bag is 100; the woven bag gives 120 slots while worn; a Pocket 3 bag adds its 20 + 18 and
  loses them on unequip; back to 100 after the last unequip; an unequip into a full 120-slot bag is
  refused, the bag stays worn, and all 119 stones keep their uids; save→load (JSON, like SaveGame)
  keeps every uid/level and the capacity; the data item exists and wears in the ring slot.
- `invslots_lab` has its own acceptance block (grid==capacity, filled==items, empties visible, no
  pills, slot ≥ 64, scrollable, p95 ≤ 33 ms, capacity grows/shrinks on equip/unequip, no items lost,
  action row inside the panel with actions ≥ 64 px, storage grid on screen after the page scroll, a
  drag selecting nothing)
  and exits non-zero on failure.
- Related tests re-run green: `t_inventory`, `t_items`, `t_ui`, `t_player`.

## Shots looked at (all in `/tmp/invslots_shots*`, saved by the lab)

- `bag_1600x900.png` — dense 96 px grid, one instance per slot, empty slots visible, "BAG 80 / 100", no pills.
- `bag_selected_1600x900.png` — gold corner brackets on the tapped slot only.
- `bag_300_scrolled_1600x900.png` — 300-slot bag scrolled, "BAG 90 / 300", scrollbar mid-list.
- `bag_upgraded_844x390.png` — ring slot shows the worn Woven Bag; header grew live 80 / 100 → 80 / 120.
- `bag_300_844x390.png`, `bag_300_scrolled_844x390.png` — phone: 64 px compartments, bag and 64 px gear side by side, no overlap.
- `storage_scrolled_844x390.png` — Storage box open: same compartments, one stone per slot with Lv labels, Lock / Take all row.

## Assumptions

- `woven_bag` `bag_slots: 20` — spec 05 says "equipment adds storage slots" but gives no value. Name,
  category and rarity are invented data to make the upgrade testable; it is the only bag item.
- Pocket is modelled as `attributes.pocket = level` (existing `InventoryEquipment` assumption,
  unchanged): +6 slots per level, capped by `max_pocket_level`.
- The rare green mark uses `Inventory.traits()` (attributes that differ from the def's
  `default_attributes`); the project has no explicit rare-attribute list yet.
- Phone landscape (844x390) folds the profile column away and gives the panel 2 columns; the
  character facts remain on the Character sheet. With a box open the panel scrolls.
- The lab's rare bone is a `hardness` trait, the "300-slot bag" is the woven bag with `pocket = 30`.

## What the integrator needs

- `BagGrid` is the single slot grid; use it for the market/container screens instead of another
  button grid. Selection goes by bag index (`selected` signal), not by uid.
- Three labs still assert the **old grouped bag** and now fail; they are outside this task's SCOPE:
  `game/scripts/dev/inventory_lab.gd` (`groups()`, count badges, "Lv 1-16", `ui._cells`,
  `ui._grid.columns == 5`), `game/scripts/dev/ui_family_lab.gd` (reads `player.ui._grid.columns`), and
  `game/scripts/dev/ui_screenshot_lab.gd:54` (`asserts _grid.columns == 5`, next to the other two).
  Port them to `BagGrid`
  (`slot_count()`, `filled()`, `empty_visible()`, `columns`) or retire them.
- The new files must be **git-added** by the integrator: `game/scripts/ui/bag_grid.gd`,
  `game/scripts/dev/invslots_lab.gd` (**still untracked**), `game/scenes/dev/invslots_lab.tscn`,
  `game/tests/t_invslots.gd` (plus their `.uid` side files).
- Untracked `game/assets/props/meshy/*_Image_0.jpg` texture extracts pre-date this task (Godot writes them
  when it imports the tracked `.glb` files; also untracked in the main checkout). They tripped the scope
  check, so this worktree's copies were deleted; a fresh `--import` recreates them (git-ignored churn,
  same class as the `.uid` files).
- Capacity **model** work (bag types, bag levels, Pocket, crafting preview) is job BAGS' scope on its
  own branch; this branch only changes the grid, the layout and the action row, and leaves `woven_bag`
  (data-only, tested) as it is.

## The `[invslots] RESULT` line

Measured at both resolutions; the lab fails its own run if any of these is wrong:
`capacity grid_slots items filled empty_visible pills min_slot_px scroll_range frame_ms_p95_300
cap_upgraded cap_after_unequip items_lost actions_in_panel storage_visible min_action_px drag_ok`.
`actions_in_panel=1` means the `_actions` row's global bottom is inside the `_panel` rect and every
visible action button (Inspect/Eat/Feed/Lock/Equip/Food 1-2) is >= `min_action_px` tall and inside
it (measured 64 px at 844x390, 44 px at 1600x900); `storage_visible=1` means the storage grid's rect
meets the panel after the page scrolled to the box; `drag_ok=1` means a press plus a release 50 px
away changed no selection.
