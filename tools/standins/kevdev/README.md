# Kevin Iglesias (KevDev) free humanoid animation packs

Source FBX files kept for re-running `tools/retarget_human.py`. Only the masculine clips we
use or expect to use are copied here; the full free packs are on itch.io:

- Human Crafting Animations FREE (page slug human-villager-animations-free): idle, gathering,
  mining, hammering, fishing, farming. `crafting/HumanM_Model.fbx` is the 55-bone rig.
- Human Throwing Animations FREE: spear / weapon / ball throws, damage.
- Human Soldier Animations FREE: damage, deaths, in-place walk 2 m/s and run 4 m/s.
- Human Archer Animations FREE and Human Spellcasting Animations FREE were reviewed from their
  itch.io pages only (bow shoot, casting, 8-direction locomotion); nothing there has a gameplay
  hook yet, so they were not downloaded.

Author: Kevin Iglesias, https://www.keviniglesias.com, support@keviniglesias.com. The packs are
name-your-own-price and the author allows use in commercial projects; the FBX sources must not
be redistributed as a pack, which is why only the retargeted GLBs ship in the game. No
generative AI was used by the author.

Rig facts that the retarget relies on: T-pose, faces -Y in Blender, 0.01 armature scale with
centimetre bones, hips at 0.98 m, 1.77 m tall. The soldier and throwing packs import with a
90-degree armature rotation and an animated B-root, so the retarget works in armature-local,
root-relative space.
