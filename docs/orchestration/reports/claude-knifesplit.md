# KNIFESPLIT: Work Knife for butchering, Stone Dagger for combat

Owner 2026-10-30: "separately have a work knife (for butchering) and a stone dagger (for combat) don't use up the
durability of the work knife in combat".

## What shipped
- **Names (ids unchanged, saves load as before):** `stone_knife_work` reads "Work Knife", `stone_knife` reads
  "Stone Dagger". Recipe `improvised_stone_knife` reads "Work Knife", recipe `stone_knife` reads "Stone Dagger".
  The two icons were already distinct (spade-shaped work blade, pointed dagger); the HUD knife pill and the
  Butchering skill icon now show the Work Knife.
- **The Work Knife is not a weapon:** its `weapon` category is gone, so it cannot go in the weapon slot. Its item
  card shows "Work tool: butchers and harvests, never used in combat" instead of a Damage row.
- **Combat never wears it:** `Inventory.equipped_weapon()` returns only a real weapon. If no weapon is worn, it
  picks a carried non-work weapon (the Dagger) before a work-tool weapon (the axe), and otherwise returns fists.
  So with only the Work Knife in hand the survivor fights bare-handed, and a carried Dagger is used automatically.
  The same guard is on the tribe member's weapon and on the server's act.attack weapon pick.
- **Butchering never wears the Dagger when a Work Knife is carried:** `find_gather_tool` takes the held tool only
  when it is a work tool, so a Dagger chosen as the held tool loses to the Work Knife. The Dagger still butchers
  as a fallback when no Work Knife is carried, at the existing weapon-as-tool wear (3 per use, against 1).
- **Recipes:** the Stone Dagger recipe loses its `makeshift_shovel_hoe` node gate, and its costs drop from
  2 stone + 2 lashing to 1 + 1. It now costs the same as the Work Axe (stone, branch, twine at the workbench), so
  it can be made before the first hunt.
- **Tutorial:** tut_knife becomes "Knap a work knife" (the hint says it butchers and never fights). The new order
  **tut_dagger**, "Make a stone dagger at the bench" (workbench > CRAFT > Weapon tab > Stone Dagger), comes after
  tut_axe and before tut_logs and tut_hunt. The tutorial now has 20 orders; TASKSCREEN's checks count with `>=`,
  and `tutorial_resume_at` is unchanged. The tutorial bot crafts the Dagger, and `bot_survivor` maps `tier_stone`
  to stone. The standing "knife" order is retitled to match.

## Save impact
No id migration. A save whose survivor wore `stone_knife_work` in the weapon slot (possible before the split)
moves it back to the bag on load (`Inventory.extras_from_dict`). If the bag is full it stays worn, but combat
ignores it and it still butchers.

## Assumptions
- # ASSUMPTION: auto-swap, not a hard "unarmed": a carried Stone Dagger fights when the Work Knife is the only
  thing in hand. With no dagger, it is fists.
- # ASSUMPTION: Stone Dagger costs 1 stone + 1 branch + 1 twine at the workbench (Work Axe parity) and has no
  skill-node gate.
- The Work Axe keeps its weapon category; it is the combat fallback after a real weapon.

## Tests
New `t_knifesplit`: names and recipes; 5 hits with only the Work Knife in hand leave it at 120/120 (fists);
a carried Dagger is chosen over the axe and wears 5 over 5 hits while the knife stays at 120; butchering wears
the Work Knife and not a held Dagger; with no Work Knife the Dagger butchers at wear 3; an old save's worn Work
Knife returns to the bag. PASS. Also t_combat, t_butcher, t_gather, t_items, t_data, t_tutguide (tut_dagger's
bench > CRAFT > Weapon > Stone Dagger path), t_save, t_taskscreen, t_inventory, t_uicraft, t_tribe, run_all,
and smoke --no-import pass. t_tutorial (own HOME, TEST_TIMEOUT 1200): the first run failed at tut_butcher with "carcass gone". Retaliating compys kept cancelling the cut, which is the known hit-interrupt flake; tut_dagger passed in that run. The rerun passed all 20 orders (449 s).

No credits spent.
