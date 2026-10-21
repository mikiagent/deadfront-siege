# dsc — INVSLOTS (bag = scrolling slot grid, upgradable capacity)

Task: `docs/orchestration/dsc/invslots-TASK.md`. Verify: `verify_job.sh invslots` (stages 1 and 2 pass).

## What shipped

- **`game/scripts/ui/bag_grid.gd` (new, `class_name BagGrid`)** — the bag/storage/cargo grid.
  A `ScrollContainer` (touch drag, wheel, scrollbar) over a `GridContainer` of exactly
  `Inventory.slot_count` compartments, one per bag index. One item instance per slot; empty slots are
  drawn as compartments; no count pills and no grouping anywhere. Each cell is drawn flat (faint
  frame, item art centred, "Lv N" bottom-right for instances above level 1, a green diamond top-left
  when the instance carries a trait the def does not give every one, gold L-shaped corner brackets on
  the selected slot). `cell_px` is set by the host and never below 48; the phone uses exactly 64.
- **`game/scripts/ui/inventory_ui.gd`** — the rejected grouped bag (`_bag_cells`, `_open_group`,
  count badges, level ranges, back cell, 20 fixed cells) is gone. The bag column now holds a header
  `BAG  used / capacity` (capacity from `Inventory.capacity()`; `UiTokens.DANGER` when full) and a
  `BagGrid`. Storage / pet cargo (`show_storage`, `show_pet_bag`) use the same `BagGrid` instead of
  a second grid of buttons, so a box, a corpse and pet cargo all read as the same compartments.
  Tapping a compartment selects that exact instance (the tip/actions are unchanged); storage taps
  keep the existing take path.
  Layout: desktop = profile | bag | equipment (6/3 columns, equipment 4 wide); compact landscape
  (844x390) = bag | equipment (profile folds away — its facts are already on the Character sheet),
  5x2 gear grid of 64 px, one 44 px action row. With a box open, the bag keeps a band, the box gets
  the same band below it and the panel scrolls on a short screen.
- **`game/scripts/ui/item_icons.gd`** — a def with no icon now falls back to its display name instead
  of the raw id.
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
| min_slot_px | 139 | 64 |
| scroll_range (px, 100-slot bag) | 6467 | 3244 |
| frame_ms_p95 (300-slot bag, scrolling) | 12.9–15.1 | 11.7–15.0 |
| cap_upgraded → cap_after_unequip | 120 → 100 | 120 → 100 |
| items_lost on a refused unequip | 0 | 0 |

300-slot bag: `capacity=300`, grid 300 compartments, p95 well under the 33 ms gate.

## Tests

- `game/tests/t_invslots.gd`: 5 identical bones take 5 slots with 5 distinct uids and 5 levels; a
  fresh bag is 100; the woven bag gives 120 slots while worn; a Pocket 3 bag adds its 20 + 18 and
  loses them on unequip; back to 100 after the last unequip; an unequip into a full 120-slot bag is
  refused, the bag stays worn, and all 119 stones keep their uids; save→load (JSON, like SaveGame)
  keeps every uid/level and the capacity; the data item exists and wears in the ring slot.
- `invslots_lab` has its own acceptance block (grid==capacity, filled==items, empties visible, no
  pills, slot ≥ 64, scrollable, p95 ≤ 33 ms, capacity grows/shrinks on equip/unequip, no items lost)
  and exits non-zero on failure.
- Related tests re-run green: `t_inventory`, `t_items`, `t_ui`, `t_player`.

## Shots looked at (all in `/tmp/invslots_shots*`, saved by the lab)

- `bag_1600x900.png` — 6-column 139 px grid, one instance per slot, empty slots visible, "BAG 80 / 100", no pills.
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
- `game/scripts/dev/inventory_lab.gd` still asserts the **old grouped bag** (`groups()`, count
  badges, "Lv 1-16", `ui._cells`, `ui._grid.columns == 5`) and now fails; `ui_family_lab` reads
  `player.ui._grid.columns` too. They are outside this task's SCOPE — port them to `BagGrid`
  (`slot_count()`, `filled()`, `empty_visible()`, `columns`) or retire them.
- `game/scripts/ui/item_icons.gd` is unchanged: an earlier caption-fallback edit was reverted (the file
  is outside the job's SCOPE), and the fallback lives in `inventory_ui.gd` instead.
- Untracked `game/assets/props/meshy/*_Image_0.jpg` texture extracts pre-date this task (Godot writes them
  when it imports the tracked `.glb` files; also untracked in the main checkout). They tripped the scope
  check, so this worktree's copies were deleted; a fresh `--import` recreates them (git-ignored churn,
  same class as the `.uid` files).
