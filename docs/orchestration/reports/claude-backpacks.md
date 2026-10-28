# claude — BACKPACKS (worn bag visible on the survivor)

Owner ask: "add equipable backpacks that the player wears and it adds slots to his inventory". Slots,
recipes and the Bag slot already existed; this adds the visible pack.

## Shipped
- `game/scripts/player/player_equipment.gd`: `refresh()` (every `inventory.changed`: equip, unequip,
  gear-preset switch, save load) also shows the bag worn in `accessory1`/`accessory2` via
  `RiggedModel.attach_skinned(rig.skeleton, assets/characters/survivor/bags/<bag_id>.glb)`; unequip frees
  it, a swap replaces it. Tint: `bag_body` albedo × the bag's `tint` attribute; `bag_trim`/`bag_bone` keep
  theirs. Mounted it rides the skeleton (no extra code).
- `game/scripts/items/bag_capacity.gd`: `apply_inheritance` keeps the primary material's `tint` on a crafted
  bag (it used to strip it with the non-storage traits), so a raptor-hide bag is raptor-hide brown (spec 35).
- Art fix (`tools/blender/bags/build_bags.py`, rebuilt `advanced_backpack.glb`, `specialized_storage_bag.glb`):
  side pockets used an absolute z on top of the bag centre and floated ~0.8 m above the head. Now offsets.
- `game/tests/t_backpacks.gd` (equip = one mesh, 3 materials, skinned to the survivor skeleton; unequip
  removes; swap replaces; JSON save/load restores; tint on bag_body only; crafted bag keeps tint).
- `--lab=backpack_lab` (`game/scripts/dev/backpack_lab.gd`): 2x2 sheets per bag and pose.
- `docs/current/inventory-bags.md`: "Worn bag on the survivor" section.

## Pictures (`docs/orchestration/reports/backpacks/`)
Each sheet: game camera from behind, game camera 3/4, close-up behind, close-up 3/4. Raptor-hide tint.
`basic_bag_on_foot.png`, `advanced_backpack_on_foot.png`, `basic_bag_mounted.png`, `advanced_backpack_mounted.png`
(mounted sheets downscaled to 1000 px wide to fit 300 KB). Looked at: no clipping through the torso, straps
sit on the shoulders, scale reads right; mounted, the pack's base rests just above the T. rex saddle's
backrest without passing through it.

## Gates
t_backpacks, t_invscreens, t_uichar, t_player, t_mounts, t_save, t_canim, t_bags PASS; run_all `[tests] PASS`;
`tools/smoke.sh --no-import` SMOKE PASS; `verify_rig_imports.gd` RIG IMPORT PASS (99 clips).

## Assumptions
- `# ASSUMPTION:` an untinted bag (untinted hide, older saves) draws `DEFAULT_BAG_TINT` #9a7a55 (plain
  tanned hide); no item in items.json defines a default hide colour.

## Not changed / risks
- Unequip with the extra slots occupied is still refused by `InventoryEquipment` (bag and mesh stay on).
- The Character sheet has no 3D survivor preview, so there is nothing to show there.
- Both accessory slots accept a bag; two packs on Spine2 would overlap. Not prevented.
- Mounted at the game camera the rider sits at the top edge of the frame on a T. rex (existing camera
  follow, not this change).
- Credits spent: 0.
