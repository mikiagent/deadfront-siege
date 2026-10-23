# Codex — inventory Drop and Destroy actions

## Shipped

- Added Drop and Destroy actions for the exact selected inventory slot.
- Drop removes the item from the bag and creates a persistent, tappable loot bag at the survivor's feet. The dropped item's level, attributes, durability, flags and unique identity survive the move.
- Destroy requires two taps. The first changes the button to `Destroy?`; the second permanently removes the item.
- Locked items disable and refuse both actions.
- Removing the last item assigned to a quick-food slot clears that stale shortcut.
- The two buttons use the inventory action row's 64 px compact-layout height.

## Diagnosis

The inventory action row never created Drop or Destroy controls. No backend work was needed for world drops: `LootBag` already stores and saves exact `ItemStack` instances, and `Inventory.remove_at()` already removes the selected slot without losing its data.

## Assumptions

- Drop and Destroy act on the whole selected slot because the inventory has no quantity picker.
- Drop places the loot bag at the survivor's feet rather than throwing it forward.

## Verification

- `Godot --headless --path game --script res://tests/t_controls.gd` — PASS
  - Drop preserves the selected level and attributes in a world loot bag.
  - Destroy keeps the item on the first tap and removes it on the second.
  - Lock blocks both actions.
- `Godot --headless --path game --script res://tests/t_controls.gd -- --touch` — PASS
- `Godot --headless --path game --script res://tests/t_inventory.gd` — PASS
- `Godot --headless --path game --script res://tests/t_ui.gd` — PASS, zero engine warnings/errors
- `tools/smoke.sh` — `SMOKE PASS`
- `git diff --check` — PASS

## Failed / deferred

- Online inventory mutation is not wired to server intents, so these actions remain disabled if `PlayerActions.online` is true.
- There is no quantity picker; stacked ammunition or currency drops/destroys as one selected stack.

## Credits

- Meshy credits spent: 0.

## Next agent

Preserve the exact-instance and lock checks if a quantity picker or online intent is added. Drop must create one authoritative owner/location transition, never a copied item.
