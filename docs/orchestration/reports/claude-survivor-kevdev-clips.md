# Survivor work animations from the KevDev free packs

Date: 2026-09-21. Agent: Claude Code (art pipeline). Meshy credits spent: 0.

## What shipped

- `tools/retarget_human.py`: Blender 5.2 headless retarget from Kevin Iglesias's 55-bone "Human"
  rig onto the survivor's 24-bone Meshy skeleton. Per bone it applies the source's rotation delta
  from rest in armature-local space (both rigs are T-posed, -Y facing, centimetre bones under a
  0.01 armature scale); hips also take the translation delta scaled by hip height. Source poses
  are taken relative to `B-root`, which is what makes the soldier/throwing packs work (they
  import with a 90-degree armature rotation and a wandering root). Output is the survivor
  armature plus a one-triangle proxy skin, so Godot builds a Skeleton3D and `RiggedModel`
  remaps every track by bone name. Clips are 40-140 KB instead of Meshy's 7 MB skinned copies.
- New survivor clips in `game/assets/characters/survivor/anim/`:
  - `gather` (berry-bush reach), `gather_chop` (one-hand swing at chest height, trees),
    `gather_mine` (crouched swing, rocks), `craft` (kneeling hammer, station crafting).
  - `idle`, `hit_react`, `death` replaced with the KevDev versions.
  - Unwired extras for Cursor: `throw_spear`, `fish_cast`, `fish_wait`, `farm`.
- Code (Cursor's files, small and additive):
  - `PlayerAnim.on_gather(kind)` picks `gather_chop` / `gather_mine` / `craft` / `gather` and
    falls back to `gather` when the rig lacks a variant. Work clips are short one-shots that
    `_on_clip_finished` replays while the player is still gathering, so no idle frame between
    units. `GATHER_CLIPS` replaces the hard-coded `gather` checks.
  - `HarvestNode.gather_kind()` returns chop for tree families, mine for rock, gather otherwise.
  - `Player._start_gather_cycle` passes the target's kind; `StationCraft` passes `craft`.
- `tools/standins/kevdev/`: the masculine FBX sources actually used plus a README with the
  author, licence note and rig facts. Archer and spellcasting packs were downloaded and read
  but nothing from them is used (no bow or casting gameplay hook).
- `game/data/characters/survivor.json`: clip list and a `pipeline.kevdev` provenance block.

## Validation

- `tools/smoke.sh`: SMOKE PASS.
- `--lab=creature_lab` headless: all 19 survivor clips remap with `missing=0`.
- `-- --gather-test` with `GATHER_ITEM=berries` gathers with the bush reach; with
  `GATHER_ITEM=branch` logs `[player] work clip gather_chop` and gathers.
- Blender renders of every clip on the real survivor mesh (`tools/render_rig_review.py`):
  gather reaches forward at chest height, chop swings, mine crouches, craft kneels with the
  hammer overhead, hit_react recoils, death ends flat on the back, spear throw reads.

## Assumptions

- `# ASSUMPTION:` the free crafting pack has no chopping clip (that is in the paid pack), so the
  one-hand mining swing against a wall stands in for axe chops.
- Walk and run stay Meshy: the KevDev in-place cycles are authored for 2 m/s and 4 m/s and the
  game's locomotion is tuned to the current clips.
- Melee (attack_primary, attack_heavy, punch), roll, knockdown and mount_idle stay Meshy; none
  of the five free packs has melee.

## For the next agent

- Cursor: hook `throw_spear` to a thrown-spear action and `fish_cast` / `fish_wait` to fishing
  when those systems land; `farm` for the plow field. The clips are already loaded by name.
- If a real chop is wanted, KevDev's paid Human Crafting Animations pack has "Chopping wood";
  retarget with the same tool.
- The pack's masked poses (`Human@ObjectGripHands01.fbx`) could close the hands around tools;
  the survivor has no finger bones, so that needs a hand-bone tweak in the transplant, not here.
