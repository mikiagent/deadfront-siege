# Codex — multi-resource tree harvesting (2026-10-25)

## Outcome

Fixed the gather-selection path that treated an empty active resource pool as an exhausted harvest
node. A tree whose logs have run out remains selectable through Hands/Space while branches, fruit,
or another resource pool remains.

## What shipped

- `HarvestNode.has_harvests_left()` defines the invariant used outside the node: all resource pools
  must be empty before a node is considered exhausted.
- `PlayerInput._nearest_harvest_node()` now uses that invariant instead of the currently selected
  pool. After the last log, the player can select the same tree again and choose branches.
- Batched full/empty visuals also use whole-node availability, preventing a multi-yield resource
  from drawing as depleted while a non-berry pool remains.
- Added `gather-tree-01` to `t_player`: it verifies automatic axe selection, repeated log gathers,
  continued branch selection after logs are gone, and disappearance only after every pool is empty.

## Verification

- Focused regression: `t_player` PASS (including `gather-tree-01`), no Godot errors.
- Adjacent item behavior: `t_items` PASS.
- Required boot gate: `tools/smoke.sh` printed `SMOKE PASS`.

## Credits / assumptions

- Meshy / external credits spent: 0.
- No new species, lore, or mechanics were introduced.
