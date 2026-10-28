# SADDLES — craft a saddle, equip it per tame, ride only with one

Owner, 2026-10-28: "make saddles something you need to craft and equip per dinosaur. (per tamed
dinosaur inventory, consider working on the tribe member inventory too)".
Branch `claude/mmo-saddles2` (worktree `.claude/worktrees/mmo-saddles2`; the old `claude/mmo-saddles`
is the earlier, already merged saddle-mesh branch and was left alone). Canon merged in (incl. DISMOUNTFIX).
Credits spent: none (saddle icons are Blender renders of the existing saddle GLBs).

## What shipped
- `EntityEquipment` (`game/scripts/items/entity_equipment.gd`): a small `{slot: ItemStack}` with an
  allowed slot list, equip from a bag (exact instance, old one swaps back into the cell), unequip back
  (refused when the bag is full), `to_dict`/`from_dict` (unknown slots and non-gear dropped).
  Tames use `TAME_SLOTS` = `saddle`. `HUMAN_SLOTS` (the survivor's seven) is there for tribe members.
- `PetRecord.gear` (saved as `gear` in the pet row, sanitized; old saves load with none),
  `saddle_size(def)`, `saddle_fit(stack)`, `ride_refusal()`, `fit_saddle()` (labs/tests).
- Items `saddle_small/medium/large` and one tailoring recipe each; the hide is the primary, so the
  saddle carries its natural `tint` (spec 35). Icons rendered from the zebraceratops and velociraptor
  saddle GLBs.
- `PlayerPets.mount` refuses with the reason as a notice. Pet radial: Ride is a greyed row labelled
  "Needs a saddle" / "Needs a medium saddle" (dimmed icon and label; a tap repeats the notice); a new
  Gear segment on mount species. Animals screen: Ride reads "Ride · needs a saddle" (disabled), new
  Gear button (the action grid grows to three rows).
- The saddle mesh shows on the dinosaur only while equipped, ridden or not, leather tinted by the
  saddle's colour (`CreatureView.show_saddle`, refreshed on `gear.changed`); also on the Animals/Gear
  stage. `begin_ride` no longer attaches the mesh and `end_ride` no longer removes it.
- Gear sheet (`pet_gear_sheet.gd`, `HuntHud.open_pet_gear`, layer 97 above the Animals screen): stage,
  size class, SADDLE slot, bag saddles (fitting first, wrong size edged red). Tap or drag to equip, tap
  Unequip or drag back to unequip. `PetGear.unequip` dismounts first through `PlayerPets.dismount`.
- Vault: `AssetValidator.pet` knows `gear` and refuses a pet still wearing any (like a full pet bag).
- Tests/labs updated for "riding needs a saddle": t_petradial, t_energy, t_targetui, pet_radial_lab,
  equip_mount_lab, creature_lab (`--ride=` still works: it fits a saddle), hudrules_shot.

## Gates
t_saddles, t_mounts, t_tame, t_petradial, t_uianimals, t_craftfeel, t_save, t_energy, t_data,
t_player, t_targetui, t_iconart PASS; run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS
(after the canon merge).

## Shots (`docs/orchestration/reports/saddles/`, `--lab=saddles_lab`)
`saddle_compare_1600x900.png`, `saddle_compare_844x390.png` (unsaddled vs saddled velociraptor, reddish
hide), `gear_1600x900.png`, `gear_844x390.png` (the Gear sheet with one equipped and three in the bag).

## Assumptions (Open Questions A12-A15)
Size bands by height; recipe costs; old tames load unsaddled; one tame slot, tribe slots unused; the
vault refuses gear.

## For the next agent
- No tribe-member entity exists in code. When one does, give it `EntityEquipment.new(EntityEquipment.HUMAN_SLOTS)`.
- Armour or bags for tames: add the slot to `TAME_SLOTS`, a category in `EntityEquipment.slot_of`, art.
- Smilodon, styracosaurus and triceratops have no saddle model: they need the item but show nothing.
- Pet gear uids are not part of `InventoryMigration.unique_uids` (an edited save could duplicate a saddle uid).
- The INTERACT hex still reads "PET" on your tame (it opens the radial, where the refusal shows).
