# Art drop: survivor v2, armor kits, Stegosaurus v2, T. rex howdah (+ spec for Cursor)

Agent: Claude Code (art pipeline). Branch: `claude/art-survivor-v2-armor-mount-7e5bcf` (not merged, not pushed).
Credits spent in this task: 0 (all assets were produced earlier in other sessions).

## What shipped (art side, done)

| Package | New path | Old version kept at | Verified |
|---|---|---|---|
| Survivor v2: 65-bone Mixamo-named rig, 1.78 m, faces +Z, 29 clips, 5 held tools | `game/assets/characters/survivor/{survivor.glb,anim/,tools/}` | `game/assets/characters/survivor_v1/` | headless smoke: all 29 clips remap 50/50 tracks, 0 missing |
| Body regions (helmet, chest, arms, legs) | `game/assets/characters/survivor/body/body_*.glb` | — | kit-verify, all bind to base (Δ ≤ 2e-5) |
| Armor kits, replace mode | `game/assets/characters/survivor/armor/{travel_clothes,hide_and_bone,forager}/` | — | `kit-verify.mjs`: KIT OK ×3 |
| Stegosaurus v2: Tripo mesh, Opus rig (34 bones, 7 tail, jaw), graded hide, faces -Z, 6.4 m | `game/assets/creatures/stegosaurus/{stegosaurus.glb,anim/,sheet.png}` | `game/assets/creatures/stegosaurus/v1/` | `creature-verify.mjs --height 6.4`: ALL HARD CHECKS PASSED (feed/sleep/tail_swipe optional, absent) |
| T. rex howdah saddle + mount.json (with `rider_in_mount` added) | `game/assets/creatures/tyrannosaurus/mount/` | — | converted with `mount_to_model_space.py` against the game's own `tyrannosaurus.glb` (same file as the clip viewer's) |

Data changes (mine):
- `game/data/characters/survivor.json` now describes v2 (1.78 m, +Z, 29 clips, clip notes). v1 json kept as `survivor_v1.json`.
- `game/data/creatures/stegosaurus.json`: `pipeline` replaced (forward_axis `-Z`, source_height_m `6.4`, version 2, provenance); the old block is under `pipeline.v1`. Gameplay fields (stats, taming, clips text, height_meters) untouched.

Godot: `--headless --import` on a fresh worktree finished in 42 s with no errors or warnings. `tools/smoke.sh --no-import` prints `SMOKE PASS`.

**Important: the player already runs on v2.** `player.gd` loads `res://assets/characters/survivor/survivor.glb` by path, so the swap took effect with no code change; every clip name the game uses exists in v2. If something looks wrong before you've switched over, point `SURVIVOR_BASE_GLB`/`SURVIVOR_ANIM_DIR`/`SURVIVOR_JSON` at `survivor_v1` to roll back.

Pending from the art side: **a rein-fit fix for the howdah is in progress.** The parent session will send a new `saddle.glb`; I'll drop it in at the same path with no `mount.json` changes, so nothing needs to change on your side.

Review videos (outside the repo, watch before wiring):
- Equip showcase: `/Users/milankinzy/Documents/DeepseekCLI/survivor-v2/kits/review/equip_showcase_v2.mp4`
- T. rex ride: `/Users/milankinzy/Documents/DeepseekCLI/survivor-v2/anim/out/mount/review/trex_ride_v3_howdah.mp4`
- Stegosaurus v2: `/Users/milankinzy/Documents/DeepseekCLI/bakeoff/review/steg2_tripo_v3/all.mp4`

---

# Spec for Cursor

Everything below is in `game/scripts`, `game/scenes` or `game/data/*.json` outside creatures, so it's yours. Reference implementations that already work against `RiggedModel`:
`/Users/milankinzy/Documents/DeepseekCLI/clip-viewer/equip.gd` and `.../clip-viewer/mount.gd`.

## 1. Survivor v2: clips and code references

v2 clips (all in `assets/characters/survivor/anim/`, lengths in s):
idle 4.0, walk 1.21, run 0.83, **sprint** 0.79, **alert** 1.5, hit_react 0.79, death 2.29, attack_primary 1.21, attack_heavy 1.58, punch 0.92, roll 1.0, gather 1.58, **gather_berry** 2.0, gather_chop 1.5, gather_mine 2.0, **gather_dig** 2.0, craft 2.0, **butcher** 2.5, farm 2.0, **drink** 2.0, **eat** 2.0, knockdown 2.0, mount_idle 1.71, throw_spear 1.42, fish_cast 1.71, fish_wait 3.0, sleep 3.0, sleep_down 1.67, sleep_up 1.71.
Bold = new in v2. No clip was renamed, so nothing in code breaks.

Code that references survivor clips or v1 assumptions:
- `scripts/player/player.gd:5-7`: paths (already v2). `:1831-1841`: reads `forward_axis` (+Z, unchanged) and `height_meters` (now 1.78) from survivor.json, then `rig.scale *= 1.18`. With the taller source, check that the 1.18 fudge still gives the size you want.
- `scripts/player/player_anim.gd`: uses idle, walk, run, attack_primary, attack_heavy, punch, hit_react, roll, knockdown, death, gather, gather_chop, gather_mine, craft, mount_idle, sleep, sleep_down, sleep_up. `_play()` speeds attack_primary ×1.5 and punch ×1.3. Those factors were tuned for the 3 s Meshy clip. v2's attack_primary is 1.21 s, so ×1.5 may now be too fast. Retune by eye.
- `scripts/core/rigged_model.gd:106-109`: the gather trim (>2 s) and the punch trim (>1.1 s) no longer fire with v2 (1.58 s / 0.92 s). They're harmless and can go when v1 is dropped.
- Sockets: v2 bones are `Hips`, `RightHand`, `Spine2`… (no `mixamorig:` prefix), already in `_bone_marker`'s list.
- **attack_primary hit timing:** in v2 the blade connects at about **30%** of the clip, not 42%. `data/creatures/anim_events.json` (`attack_primary.hit_frac 0.42`) is read only by `creature_anim.gd` and is shared by every creature, so I did **not** change it. The player applies damage on the swing in `combat/hunt.gd:130-136`. If you sync player damage or hit FX to the animation, use 0.30 for the survivor.
- Wiring the new clips is optional and up to you: `sprint` (sprint state), `alert` (combat ready), `gather_berry` (bush harvest instead of `gather`), `gather_dig` (dig/hoe nodes), `butcher` (corpses), `eat`/`drink` (food buffs/water).
- Held tools: `assets/characters/survivor/tools/tools.json` lists 5 tools (work_axe, work_pick, stone_knife, hoe, spear). Each has `socket: RightHand`, a `grip_offset` (16 floats, column-major, relative to the RightHand bone) and `used_by` (the clips that show it). Show the tool on a `BoneAttachment3D` on RightHand, with that offset, while a `used_by` clip plays. Optional, but gather_chop and gather_mine look empty-handed without it.
- Weak clip fits, so you know which ones aren't bugs: gather_mine is a sword strike standing in for a pick, farm is a watering motion, drink and eat share one clip, sleep is a held frame.

## 2. Visual equipment: four armor slots

### Inventory changes
- `scripts/items/inventory.gd:13`: add `&"arms"` to `EQUIP_SLOTS` (the user asked for this):
  `[&"weapon", &"head", &"body", &"arms", &"legs", &"accessory1", &"accessory2"]`
- `slot_for()`: add `[&"armor_arms", &"arms"]` (and `[&"gloves", &"arms"]` if you want an alias).
- `equipped_armor()` and `equipped_health_bonus()` hardcode `[&"head", &"body", &"legs"]`. Add `&"arms"`, or arms armor won't count.
- `has_raid_protection()` stays head/body/legs (the raid set has no arms piece).
- `scripts/ui/inventory_ui.gd:46` `EQUIP_LABELS`: add `"arms": "Arms"`. `:166` `equip_order`: add `"arms"` after `"body"`. The grid is 3 columns, so it stays tidy: head/body/arms, legs/weapon/tool, rings, food.
- Save games store `equipment` as a dict keyed by slot name, so old saves load with arms empty.

### Item → kit piece
Add an optional item field `"visual": "<kit>/<piece>"`, e.g. `"forager/helmet"`, which resolves to `res://assets/characters/survivor/armor/forager/helmet.glb`. Kit slot names → equipment slots: `helmet→head`, `chest→body`, `arms→arms`, `legs→legs`. Each `kit.json` lists the slots it has and the body region each piece `hides`. An item with no `visual` (raid gear today) changes stats only and leaves the body region showing.

### Equip logic (new component, e.g. `scripts/player/player_equipment.gd`)
Port `clip-viewer/equip.gd` (the code is also in `~/.claude/skills/modular-armor-kit/references/godot-equip.md`):

1. **At rig load** (after `rig.setup` in `player.gd`): hide every MeshInstance3D under `rig.mesh_root` (the single survivor mesh), then attach `body/body_helmet.glb`, `body_chest.glb`, `body_arms.glb`, `body_legs.glb` with `_attach`. Keep `body[region] -> Array[MeshInstance3D]`.
2. **`_attach(path)`**: instantiate the GLB, and for each MeshInstance3D take its transform relative to the GLB's own Skeleton3D (`_relative`, from local-transform chains). Reparent it under the live `rig.skeleton`, then restore `transform` and `skin`, set `skeleton = NodePath("..")`, and free the instance. The pieces share the base skeleton's bone names and bind poses, so every clip works unchanged and the AnimationPlayer needs nothing.
3. **`equip(slot, visual)`**: unequip the slot, `_attach` the piece, and **only if something attached**, hide the body regions in its `hides`. A set without that piece (travel_clothes has no helmet) leaves the body region showing.
4. **`unequip(slot)`**: `queue_free()` the slot's meshes and show its body regions again.
5. Hook it to `inventory.changed`: for each of head/body/arms/legs, compare the equipped item's `visual` with what's shown and equip or unequip the difference. Mixing kits per slot works with no extra code (shown in the showcase video).
6. Load the GLBs with `load()` and cache the PackedScene per path. They're small (1–6k tris each).

Accessories (rings, hats as accessories) are out of scope for now and come later.

### Proposed item defs (stat values are a suggestion; loot/recipe placement is your call)
Existing reference: the raid set (level 55 tailoring) is head 300 / body 700 (+90 HP) / legs 300. These three sets sit below it.

| id | display_name | categories | armor_value | extra | visual |
|---|---|---|---|---|---|
| travel_shirt | Travel Shirt | armor_body, clothing | 30 | — | travel_clothes/chest |
| travel_sleeves | Travel Sleeves | armor_arms, clothing | 15 | — | travel_clothes/arms |
| travel_trousers | Travel Trousers | armor_legs, clothing | 20 | — | travel_clothes/legs |
| forager_hood | Forager Hood | armor_head | 50 | — | forager/helmet |
| forager_vest | Forager Vest | armor_body | 110 | — | forager/chest |
| forager_wraps | Forager Arm Wraps | armor_arms | 40 | — | forager/arms |
| forager_leggings | Forager Leggings | armor_legs | 70 | — | forager/legs |
| hide_bone_helm | Hide and Bone Helm | armor_head | 150 | — | hide_and_bone/helmet |
| hide_bone_cuirass | Hide and Bone Cuirass | armor_body | 350 | health_bonus 40 | hide_and_bone/chest |
| hide_bone_bracers | Hide and Bone Bracers | armor_arms | 120 | — | hide_and_bone/arms |
| hide_bone_greaves | Hide and Bone Greaves | armor_legs | 150 | — | hide_and_bone/legs |

All with `stack_max 1`, `base_level 1`, `max_durability` 150 / 250 / 350 per set, and `stats_per_level {"armor_value": 0.02}` like the raid set.
Suggested recipe tiers (tailoring): travel = starting outfit (the PRD survivor arrives in travel clothes), forager ≈ level 10 (fibre, cloth, hide), hide_and_bone ≈ level 30 (hide, bone, lashing).
`# ASSUMPTION:` the stat numbers and tiers are mine; the PRD doesn't specify these sets.

## 3. Mounting the T. rex: howdah saddle + rider placement

Files: `assets/creatures/tyrannosaurus/mount/saddle.glb` and `mount.json`:
- `socket`: `"Spine2"` (the T. rex back, just behind the shoulders).
- `rider_in_mount`: 16 floats, column-major. The rider's armature root in the **T. rex glTF model space** (Y-up, rest pose, 8 m model): position (0, 7.083, -4.17), rotated 180° so the rider faces where the T. rex faces. **Use this one.**
- `rider_offset`: the same pose, relative to Spine2 as Blender imports it. Blender re-orients bones on import, so it's wrong in Godot's joint frames. **Don't use it.**

Replace `creature_view.gd:85-101` (MountSocket = Marker3D on `hips_socket` with a fixed `height*0.08` offset) and `player.gd:1594-1603` (`reparent(mount_socket())`, `position = -_mount_hips_offset`) with the `clip-viewer/mount.gd` approach:

1. **Saddle**: when a mount-role T. rex view loads (or when mounted, if the saddle should only show while ridden), `_attach_skinned(rig.skeleton, "…/mount/saddle.glb")`. It's the same reparent-to-skeleton code as the armor `_attach`. The saddle is skinned to the T. rex skeleton and follows every T. rex clip.
2. **Socket offset, computed once**:
   ```gdscript
   var sk := mount_rig.skeleton
   socket_idx = sk.find_bone(mj["socket"])
   var bone_rest_world := sk.global_transform * sk.get_bone_global_rest(socket_idx)
   var want_world := mount_rig.mesh_root.global_transform * _mat(mj["rider_in_mount"])
   socket_offset = bone_rest_world.affine_inverse() * want_world
   ```
   `_mat` builds a Transform3D from the 16 column-major floats (see mount.gd). Compute it **after** RiggedModel has scaled and oriented the T. rex (it scales to `height_meters`), so the offset is in the live scale.
3. **Follow on `skeleton_updated`**: don't parent the rider under a BoneAttachment3D. In testing, a skinned character inside another skeleton's bone attachment didn't draw. Keep the player node where it is and move its visual root every frame:
   ```gdscript
   sk.skeleton_updated.connect(func(): rider_visual.global_transform = sk.global_transform * sk.get_bone_global_pose(socket_idx) * socket_offset)
   ```
   This must run on `Skeleton3D.skeleton_updated` (after the AnimationPlayer has posed the bones), **not** in `_process`/`_physics_process`. Reading the pose there gets last frame's bones, so the rider lags a frame and bounces.
4. **Rider pose**: play `mount_idle` (seated, hands on the reins). The 180° turn is already in `rider_in_mount`. In mount.gd the rider rig gets no extra orientation; with the player rig (`forward_axis +Z`), make sure the transform you drive is the one *outside* RiggedModel's orientation step, or cancel that step while mounted. Check one frame against the ride video. Disconnect on dismount.
5. The player's CharacterBody/collision should follow the mount's root (or be disabled) while mounted; only the visual follows the bone. That keeps physics stable.
6. Scale: `rider_in_mount` assumes the T. rex at 8 m (`tyrannosaurus.json` height 8.0, source 8.0) and the rider at 1.78 m. The player's extra `rig.scale *= 1.18` makes the rider about 2.1 m, which pushes the feet past the footboard. Drop the 1.18 while mounted, or accept the mismatch.

Other mount-role creatures keep the current hips-offset path until they get their own saddles.

## Assumptions / open items
- `# ASSUMPTION:` item stats, ids and tiers above (not in the PRD).
- The `kit.json` `provenance` paths (`../sheet_v1.png` etc.) point at the source folders outside the repo (`/Users/milankinzy/Documents/DeepseekCLI/survivor-v2/kits/<kit>/`). They're informational only.
- The saddle rein fix is still to come (same path).
- Not done: no in-game visual check of v2 at gameplay scale, no equip or mount runs inside deadfront itself (they need the code above). The review videos are from the clip viewer, which uses the game's own `RiggedModel`.
