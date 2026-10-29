# claude-rummage: survivor bag rummage, crafting-station work loops, worksite kick

Branch `claude/mmo-rummage` (from `origin/claude/mmo-overhaul`). Owner ask: "make a rummaging through bag
animation where the survivor is opening the bag in the wild and while he is rummaging we will have the bag
inventory menu on the right". No paid generation; no credits spent.

## What shipped

- `game/assets/characters/survivor/anim/rummage_in.glb` (44 frames, 1.8 s): stands holding the satchel in the
  left hand, kneels (left knee up, right knee down), sets the bag on the ground in front, right hand lifts the
  flap and lets it fall open behind the bag.
- `rummage.glb` (121 frames, 5 s, loops, first frame == last): left hand holds the near rim, right hand circles
  and digs in the opening, grabs a rolled bundle and pulls it ~13 cm (half) out, head lifts to look at it, puts
  it back, digs again; head glances across the bag, breathing lean.
- `rummage_out.glb` (47 frames, 2 s): right hand lifts the flap back and pushes it shut, left hand takes the bag
  by its top, stands up carrying it.
- `game/assets/characters/survivor/props/satchel.glb`: leather satchel (open box + flap with strap and brass
  buckle, side rings) and the bundle, built in Blender headless. Own tiny rig (bones Satchel, Flap, Item) in the
  survivor's model space, with animations `rummage_in`, `rummage`, `rummage_out` matching the body clips.
- `tools/make_rummage.py`: authors all four files. Body = Quaternius UAL1 `Fixing_Kneeling` (CC0) retargeted
  with `verifiers/tools/retarget.py`, legs untwisted with `fix_leg_twist.py`, then IK hands, lean and head look
  layered and baked to plain keys (same method as `tools/make_state_idles.py`). Commands in its header.
- `tools/render_survivor_strip.py`: front + side PNG strip of a clip, with the satchel / held props / station blocks.
- Wiring (`game/scripts/player/player_anim.gd`, `game/scripts/core/rigged_model.gd`):
  - `PlayerAnim.play_rummage(on: bool)`: true plays rummage_in, then the rummage loop (forced, locomotion
    leaves it alone) until `play_rummage(false)` plays rummage_out, then idle. `PlayerAnim.is_rummaging()`.
  - The satchel is instanced lazily under `rig.mesh_root`, shown and synced (same clip, same speed) whenever a
    rummage clip plays, hidden on any other clip. Walking (speed >= 0.08) or any other clip (hit, death, gather)
    ends the rummage immediately.
  - `rummage` added to `RiggedModel.LOOPING`; the three clips listed in `data/characters/survivor.json`.
- `game/tests/t_rummage.gd`: has clips, loops, in -> loop handover with the satchel in sync, bag on the ground,
  out -> idle with the bag hidden, walking off cancels. `-- --shots <dir>` saves front/side frames.

## Added scope (coordinator, Milan verbatim)

"crafting stations have interact animations (hammering onto the table)" and "he like kicks the dirt to make the
construction site".

- Clips (stable names, all in `game/assets/characters/survivor/anim/`), 4 s loops at 24 fps (97 frames, the
  idle's length, first frame == last) unless noted:
  - `work_hammer`: at a waist-high bench (top ~0.84 m), left hand steadies the piece, right hand raises the
    hammer and strikes the bench top, 5 strikes per loop. Holds the hammer.
  - `work_stir`: knees bent 24 deg, right hand turns a spit crank (3 turns per loop), left hand on the knee.
  - `work_hang`: hands overhead on a drying-rack bar (~1.9 m), alternate tugs and smoothing.
  - `work_forge`: low anvil (~0.68 m), slight knee bend, 4 heavy overhead strikes, left hand holds the work.
    Holds the hammer.
  - `work_tan`: knees bent 10 deg, both hands push a scraper down a slanted frame, 4 strokes.
  - `kick_dirt`: one-shot, 36 frames (1.5 s): two scuffs of the right foot, back to the idle pose.
- Hammer: `game/assets/characters/survivor/props/work_hammer.glb` (Blender, survivor armature + hammer skinned
  100% to RightHand). No hammer existed among the survivor's held tools (Kenney tool-hammer has a different grip
  convention), so it is a simple Blender hammer. Not used for stir / hang / tan (no prop: ASSUMPTION).
- `tools/make_work_clips.py` authors the six clips and the hammer from the survivor's idle (FK body offsets,
  knee bends as pure hinges, IK hands with targets pulled within 0.51 m of the shoulder because the rig's arms
  are short, hand aim after the bake).
- API (`PlayerAnim`): `play_work(kind)` with kind `&"hammer"`, `&"stir"`, `&"hang"`, `&"forge"`, `&"tan"` (or the
  `work_*` clip name) loops until `stop_work()`; `is_working()`; `play_oneshot(&"kick_dirt")` plays to the end and
  returns to idle. Walking off cancels any of them. The hammer shows only on work_hammer / work_forge.
- Strips: `docs/orchestration/reports/rummage/blender_work_*.png`, `blender_kick_dirt.png` (grey blocks stand in
  for the bench, crank post, rack bar, anvil and frame), and in-engine `godot_work_hammer.png`,
  `godot_kick_dirt.png`.

## Checks

- limb_check (skill verifier) on all nine new clips: `LIMB_OK 0 of 9 clips fail`. Rummage — knee hinge <= 0.5, thigh twist <= 43 (limit 50),
  ankle twist clamped to 36 (limit 40; the raw kneeling back foot read 43), spine twist <= 5, floor >= -0.4 cm.
  The raw retarget failed (thigh 64, knee 54); fix_leg_twist + the ankle clamp fixed it.
- PNG strips in `docs/orchestration/reports/rummage/`: `blender_rummage_in.png`, `blender_rummage.png`,
  `blender_rummage_out.png`, `blender_rummage_closeup.png` (top row front, bottom row side, 8 frames across),
  plus the in-engine strips from the Godot capture (`godot_*.png`).

## For the bag UI agent (claude/mmo-bagui)

Call `player.anim.play_rummage(true)` when the bag menu opens and `play_rummage(false)` when it closes. Poll
`player.anim.is_rummaging()` if the menu should close when the player walks off (the animation stops on its own;
no signal was added).

## Assumptions / known limits

- ASSUMPTION: the bag appears in the left hand at the start of rummage_in and disappears after rummage_out
  (no worn bag exists any more, so there is nothing to swing off the shoulder). A pop at those two moments.
- ASSUMPTION: the pulled item is a neutral rolled linen bundle, not tied to the real inventory.
- The left hand carries the bag by pinching the top of the flap (the satchel has no handle: a handle across the
  top collided with the opening flap).
- The flap rests open at 165 deg behind the bag, its front drop pointing up a little.
- Station heights are mine (bench 0.84, anvil 0.68, rack 1.9 m); station models of other heights will look
  off by that much. The work clips do not move the player to the station.
- `tools/render_rummage.py` became `tools/render_survivor_strip.py` (props, station blocks).
- `t_rummage.gd` covers the work API and the kick too; its island load prints an existing nav-bake error trace
  (island_terrain.gd bake_nav), unrelated.
