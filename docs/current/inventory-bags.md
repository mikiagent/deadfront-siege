# Inventory & bags — instances, slots, capacity, storage, saving

The container is `game/scripts/items/inventory.gd` (`Inventory`: fixed slot array + equipment dict).
One occupant is `game/scripts/items/item_stack.gd` (`ItemStack`). Rules data: `game/data/inventory.json`
(stacking categories, pocket rules); bag types: `game/data/bags.json`. Capacity math lives only in
`game/scripts/items/bag_capacity.gd`; wearing/unwearing and resizing in
`game/scripts/items/inventory_equipment.gd`. UI: `game/scripts/ui/bag_grid.gd` (grid, multi-select),
`game/scripts/ui/inventory_ui.gd` (host: lock, batch actions, storage transfer). Item numbers:
[items-traits.md](items-traits.md).

## Instances, uids, stacking
- Every occupant is an instance with `def_id, count, level, process_count, attributes, flags,
  durability, max_durability, uid, origin, creator, created_at`.
- `uid` is empty for fungible stacks. The server issues `i<seq>…`; an offline game mints `l<hex>`
  (`Inventory.mint`). The loader accepts `^[il][0-9a-f]+$` only (`item_stack.gd`).
- `origin` is one of `gather, loot, craft, tame, breed, settlers, objective, market`.
- Merging (`ItemStack.can_merge_with`) needs the same def, level, process_count, durability,
  attributes (ignoring `climate`) and flags. Any uid on either side blocks a merge.
- An item whose `stack_max` is ≤ 1 is one instance per slot (`is_fungible`).
- Only the categories in `game/data/inventory.json` → `stacking_categories` keep their `stack_max`:
  `currency, ammunition, siege_ammunition, counter_supply, medicine, building`. Everything else
  (materials, food, gear) is one instance per slot — no stacking by name.
- Per-instance traits = attributes that are neither bookkeeping (`level, climate, processed,
  material_tier`) nor the def's defaults (`Inventory.traits`).
- A captured animal (`captured_animal`, `slot_span` 4) occupies its slot plus the next three; the
  tail slots hold `_slot_lock` markers whose `attributes={"anchor": start}` (`Inventory.place_span`).
- A split mints a fresh uid for the removed unit (`Inventory.remove_at` → `remint_uid`).

## Slots & capacity
- Base bag `Inventory.BASE_SLOTS` = 100 slots (the survivor's `Inventory`, built once per `Player`).
- Total = 100 + Σ storage of worn gear (`BagCapacity.inventory_total`, `count`). Only worn gear
  counts; items sitting in the bag add nothing.
- A bag type's storage = curve(level) + inherited storage attributes (points × slots per point) +
  the type's `storage_bonus`. Curves interpolate linearly between rows and clamp at both ends
  (`BagDef.base_capacity`). `pocket` = 6 slots/point, `capacity` = 1 slot/point; pocket level is
  clamped to 60 (`game/data/bags.json`, `game/data/inventory.json`).
- Ordinary (non-bag) gear adds `def.bag_slots` + pocket only.
- Wearing a bag resizes the bag on the bonus delta; a shrink that would cut an occupied or
  span-tail slot is refused (`InventoryEquipment.resize`).

| bag (`game/data/bags.json`) | curve `[level, slots]` | storage_bonus | inheritable | min craft level |
|---|---|---|---|---|
| basic_bag | 1:20, 10:24, 20:28, 30:32, 45:38, 60:44 | 0 | pocket, capacity | 1 |
| small_pouch | 1:8, 10:12, 20:16, 30:20, 45:24, 60:28 | 0 | capacity | 1 |
| large_pouch | 1:14, 10:20, 20:26, 30:32, 45:40, 60:48 | 0 | capacity | 8 |
| advanced_backpack | 1:26, 10:34, 20:42, 30:50, 45:60, 60:70 | 0 | pocket, capacity | 20 |
| specialized_storage_bag | 1:22, 10:30, 20:38, 30:46, 45:56, 60:66 | 8 | pocket, capacity | 30 |

All five wear in `accessory1`. The seven equipment slots (`Inventory.EQUIP_SLOTS`): weapon, head,
body, arms, legs, accessory1, accessory2. Worn stacks live in `Inventory.equipment`, out of the
grid. Level 1–60 is the instance's `level`; there is no bag "quality" field in the data.

### Worn bag on the survivor (BACKPACKS)
- `PlayerEquipment.refresh` (on every `inventory.changed`: equip, unequip, preset switch, save load)
  shows the bag worn in `accessory1` or `accessory2`: `RiggedModel.attach_skinned(rig.skeleton,
  assets/characters/survivor/bags/<bag_id>.glb)`. Packs are skinned to Spine2, pouches to Hips; the
  mesh rides the skeleton, so it stays on while mounted. Unequip frees it, a swap replaces it.
- Tint (spec 35): the `bag_body` material's albedo × the bag instance's `tint` attribute; `bag_trim`
  and `bag_bone` keep their colours. A crafted bag now keeps its primary hide's `tint`
  (`BagCapacity.apply_inheritance`: the natural colour is bookkeeping, not a trait). A bag with no
  `tint` (untinted hide, older saves) draws `PlayerEquipment.DEFAULT_BAG_TINT` (# ASSUMPTION: plain
  tanned hide `#9a7a55`; no item defines a default hide colour).
- Taking a bag off follows the capacity rule above unchanged: when its extra slots are occupied the
  unequip is refused, the bag stays worn and so does its mesh.
- The Character sheet has no 3D survivor preview, so nothing to show there. Both accessory slots
  can hold a bag; two packs on Spine2 would overlap (not prevented).
- Test `game/tests/t_backpacks.gd`; look check `--lab=backpack_lab` (sheets in
  `docs/orchestration/reports/backpacks/`).

## Storage containers (separate `Inventory`s, never part of bag capacity)
| container | slots | owner |
|---|---|---|
| home cargo (`World.cargo_home`) | 60 | `game/scripts/core/world.gd` |
| harbour cargo basket (`is_cargo`) | 100 (`BASKET_SLOTS`) | `game/scripts/world/placed_building.gd` |
| `chest` building | 100 (`storage_slots`) | `game/data/structures.json` |
| `large_box` building | 160 (`storage_slots`) | `game/data/structures.json` |
| pet bag | species `bag_slots`, else 10 | `game/scripts/pets/pet_record.gd` |
| tame gear (`PetRecord.gear`) | one `saddle` slot | `game/scripts/items/entity_equipment.gd` |
| corpse loot | 12 | `game/scripts/creatures/corpse.gd` |
| ground loot bag | sized to its stacks | `game/scripts/world/loot_bag.gd` |

- Storage UI binds the same grid as a second pane via `InventoryUI.show_storage`; take is
  `_take_all_storage`, store is `_store_selected` (`inventory_ui.gd`). A loot bag is take-only.
- Nothing is deleted on spill: a demolished structure's contents go to home cargo, then to a loot
  bag on the spot (`spill_storage`).
- Cargo warp (the camp chest, `game/scripts/world/cargo_warp.gd`) ships unstable goods to home
  cargo for a T-stone fee — see [economy-trading.md](economy-trading.md).

## Entity equipment (SADDLES, `entity_equipment.gd`)
- `EntityEquipment` is the gear of anything that is not the survivor: `{slot: ItemStack}` with an
  allowed slot list. Tames get `TAME_SLOTS` = `saddle` (armour and bags would be new slots + a
  category in `slot_of`). `HUMAN_SLOTS` are the survivor's seven slots for a tribe member; no
  tribe-member entity exists in code yet, so nothing uses them.
- `equip_from(inv, index, fits)` moves the exact instance out of the bag; what was worn goes into
  that same cell, so it never needs a free slot. Locked items, stacks and non-gear are refused, and
  `fits` is the owner's rule (`PetRecord.saddle_fit`: size class). `unequip_to(inv, slot)` refuses
  when the bag has no room; gear is never dropped. Player-side wrapper: `PetGear` (dismounts first).
- Saddles: `saddle_small` / `saddle_medium` / `saddle_large` (categories `saddle` + `saddle_<size>`,
  one instance per slot, tailoring). Recipes (ASSUMPTION costs): small by hand, 3 dried hide + 3 fibre
  + 2 lashing, min level 1; medium at a workbench, 5 cured hide + 3 lashing + 2 wood, min level 12,
  ability 55; large at a workbench, 8 cured hide + 4 lashing + 3 wood + 2 bone, min level 25, ability 65.
  The hide is the primary, so the saddle inherits its `tint` (spec 35). Icons: renders of the
  zebraceratops and velociraptor saddle GLBs (`assets/icons/saddle_*.png`; large borrows medium).

## Bag screens (spec 13, `inventory_ui.gd`, INVSCREENS)
- One sheet docked on the right (68 % of the view, 520-1120 px). Header: Bag tab, `used / capacity`
  (`Inventory.capacity()`, danger colour when full), the open container's tab, Character, close.
- Bag page: `BagGrid` + bottom toolbar: Auto Sort (cycles bag order / type / level / name), Filter
  (all, materials, food, gear, tools, building, rare, locked), Select, Lock, Destroy (two taps);
  Take all on a take-all container's tab. Sort and filter change only the draw order
  (`BagGrid.view_order`); every cell keeps its real slot index and nothing in the bag moves.
- Cells: `Lv. N` grey top right (level > 1, non-fungible), blue NEW tag top left, green corner for
  a rare trait, small lock for a locked item, gold brackets for the selection, blue for batch marks.
- NEW: uids that enter the bag after `bind` (worn gear coming off is not new). A tap acknowledges
  one; closing the bag acknowledges all. Not saved: a load shows nothing as NEW.
- Item card (`item_inspect_panel.gd`): floats left of the sheet over the world (over the sheet's
  left half when the strip is under 220 px). Tan title band, art + level + kind, durability,
  processing left, damage / armour / storage, food energy and raw/poisoned, traits classed by
  `InvAttributes` (gold positive and grey negative from `game/data/inv_ui.json`, green rare from
  `rules.json crafting.rare_attributes`), then only the valid actions (`InventoryUI.valid_actions`:
  eat / food1 / food2 / inspect / feed / equip / place / store / take / drop). `look_row` +
  `show_look()` is the empty hook for spec 35's material swatch.
- Containers (`show_storage`, `show_pet_bag` = "<name> cargo"): their own tab with the same grid;
  a tap selects, the card's "Transfer to Bag" / "Transfer to <title>" moves that exact instance.
  A take-only container closes when emptied; a deposit container stays open.
- Character page (full view): portrait, name, title, level, occupation, XP bar, Combat / Crafting /
  Gathering Power (highest skill in each `inv_ui.json powers` group), My Info Attack / Defense /
  Accuracy (`InvStats`, computed from what is worn), Detailed Stats; Gear | Decorative tabs
  (no decorative gear exists yet: the tab says so), presets 1-4 (open at shown level 1/10/30/50),
  ten slots with faded silhouettes when empty; a tapped worn slot shows its line and Unequip.
- Every button is >= 64 px; t_invscreens proves no overflow at 844x390 and 1600x900.

## Multi-select, locking, transfer (`bag_grid.gd`, `inventory_ui.gd`)
- Cell size: 64 px on a phone, up to 120 on desktop; tap vs drag separated at `TAP_DEADZONE` = 12 px.
- Select mode (`multi_mode`, `multi: Array[int]`) from the toolbar's Select, a long press
  (`long_press_s` = 0.45 s without moving) or a Shift-press on a cell. In Select mode a press paints:
  every cell the pointer passes joins, moving back onto a cell already on the gesture's path
  un-paints the cells after it, a plain tap toggles one. Painting accepts the events so the grid does
  not scroll; near the grid's top or bottom edge it auto-scrolls. Outside Select mode a drag scrolls.
  Empty slots and `_slot_lock` markers never join. Works on the bag grid and a container's grid.
- Batch actions (bag): Lock, Drop (loot bag at the survivor), Destroy (second tap confirms), Store
  (into an open deposit container); container tab: Transfer to Bag. `batch_check` returns `{ok, skip}`
  with a reason per index (`locked`, `empty`, `online`, `world`); locked items may be marked but every
  destructive or moving action skips them.
- Lock is the `locked` flag on an instance (`ItemStack.is_locked`, toggled by `_toggle_lock`).
  Locked items refuse drop/destroy/transfer/equip, are skipped by default craft picks and by the
  auto-picked gather tool.
- `Inventory.transfer_to` moves one slot to another container, refusing locked items and markers.

## Saves
- Bag rows: `player.inventory`, one array row per slot including nulls (`Inventory.to_array`);
  `Inventory.load_array` restores positions.
- `player.inventory_extras` = `{worn, quick_food, tool_index}` plus `presets`
  (`{active, sets: [{slot: uid}]}`, `GearPresets`) only once a preset was used; `GearPresets.sanitize`
  cleans it on load (known slots, `^[il][0-9a-f]+$` uids, at most 4 sets) and an old save loads with {}.
- `home.cargo` = the home cargo rows; building storage saves as each building row's `contents`;
  pet bags and tame gear (`gear`) save inside each pet row. See [saves-persistence.md](saves-persistence.md).
- Loading (`game/scripts/items/inventory_migration.gd`, `load_into`): keeps slot positions, grows
  to the last row, splits a stacked row of a now-non-stacking def into one instance per unit,
  overflows to home cargo, deletes nothing, caps at `MAX_LOAD_UNITS` = 100000. `unique_uids`
  remints duplicate uids across cargo, bag, worn gear, building storage and pet bags. Worn rows are
  re-validated and unwearable ones go back to the bag (`InventoryEquipment.load_worn`).

## Screens (phone landscape, [all screens](ui-screens.md))

**Bag and equipment**

![bag](screens/bag.webp)

**Food inspector**

![bag_food_inspect](screens/bag_food_inspect.webp)

**Bag inspector**

![bag_bag_inspect](screens/bag_bag_inspect.webp)
