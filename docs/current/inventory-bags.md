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
- Base bag `Inventory.BASE_SLOTS` = 100 slots (a `Player` constructs `Inventory.new()`).
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

## Storage containers (separate `Inventory`s, never part of bag capacity)
| container | slots | owner |
|---|---|---|
| home cargo (`World.cargo_home`) | 60 | `game/scripts/core/world.gd` |
| harbour cargo basket (`is_cargo`) | 100 (`BASKET_SLOTS`) | `game/scripts/world/placed_building.gd` |
| `chest` building | 100 (`storage_slots`) | `game/data/structures.json` |
| `large_box` building | 160 (`storage_slots`) | `game/data/structures.json` |
| pet bag | species `bag_slots`, else 10 | `game/scripts/pets/pet_record.gd` |
| corpse loot | 12 | `game/scripts/creatures/corpse.gd` |
| ground loot bag | sized to its stacks | `game/scripts/world/loot_bag.gd` |

- Storage UI binds the same grid as a second pane via `InventoryUI.show_storage`; take is
  `_take_all_storage`, store is `_store_selected` (`inventory_ui.gd`). A loot bag is take-only.
- Nothing is deleted on spill: a demolished structure's contents go to home cargo, then to a loot
  bag on the spot (`spill_storage`).
- Cargo warp (the camp chest, `game/scripts/world/cargo_warp.gd`) ships unstable goods to home
  cargo for a T-stone fee — see [economy-trading.md](economy-trading.md).

## Multi-select, locking, transfer (`bag_grid.gd`, `inventory_ui.gd`)
- Cell size: 64 px default, never under 48; tap vs drag separated at `TAP_DEADZONE` = 12 px.
- Select mode (`multi_mode`, `multi: Array[int]`): taps toggle membership instead of moving the
  single selection; `set_multi_mode`, `toggle_multi`, `clear_multi`, `multi_list`. Empty slots and
  `_slot_lock` markers cannot join. Gold brackets = single selection, cool blue = batch mark.
- Batch actions: `_on_batch_lock`, `_on_batch_drop` (spawns a `LootBag`), `_on_batch_destroy`
  (needs a second tap: "armed"). `batch_check` returns `{ok, skip}` with a reason per index
  (`locked`, `empty`, `online`, `world`).
- Lock is the `locked` flag on an instance (`ItemStack.is_locked`, toggled by `_toggle_lock`).
  Locked items refuse drop/destroy/transfer, are skipped by default craft picks and by the
  auto-picked gather tool. A locked item may still be *in* a batch; its actions skip it.
- `Inventory.transfer_to` moves one slot to another container, refusing locked items and markers.

## Saves
- Bag rows: `player.inventory`, one array row per slot including nulls (`Inventory.to_array`);
  `Inventory.load_array` restores positions.
- `player.inventory_extras` = `{worn, quick_food, tool_index}`.
- `home.cargo` = the home cargo rows; building storage saves as each building row's `contents`;
  pet bags save inside each pet row. See [saves-persistence.md](saves-persistence.md).
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
