# SP-TYRANNOSAURUS: T. rex v2, the open-mouth remodel with a real jaw

Branch `claude/mmo-sp-tyrannosaurus` (canon `origin/claude/mmo-overhaul` merged in, PINFEEL included). Not merged to canon.
Owner go: Milan, "go" on remodelling the rex with a real jaw (the old mesh was made mouth-shut, so the lips stretched).

**Credits: Tripo 50** (balance 2555 -> 2505). One multiview generation, task `7270b4be-bf0b-4ce6-ab92-bbceb3a48eea`,
P1-20260311, texture + PBR, face limit 15000. No retry. Meshy 0, Higgsfield 0, no Tripo rig/anim/retexture. The Alpha
costs nothing: it is a texture variant on the same mesh.

## Mesh
- Views: crops of the owner's sheet `trex_owner_sheet_1.png` (side panel as left, mirrored as right, front and back panels),
  labels painted out, padded square on the sheet grey. In `game/assets/creatures/tyrannosaurus/ref/v2_views/`.
- Tripo matched the sheet: olive-khaki croc scales, pyramid scutes, heavy brow, mouth wide open with separate teeth.
- It modelled a mid-stride stance: left foot forward under the hips, right leg trailing 2 m back with a longer thigh,
  left sole 0.2 m off the floor. Posing that into a square stance stretched the thigh into a sheet, so
  `fit_rex_rig.py` keeps the left half and mirrors it (seams welded, normals recalculated). The animal is symmetric.
- 8 m tall, 16.5 m long (v1 was 19.4 m long; same height).

## Rig (`tools/gait/build_tyrannosaurus.sh base`, all reproducible)
1. `tools/gait/fit_rex_rig.py`: the same 30-bone rig, same bone names and local axes, joints measured on grid renders of the
   new mesh. Every rex tool carries over (make_rex_moves, make_gait + tyrannosaurus.json, check_rex_clips, the howdah).
2. Weights: distance to the bone segments, legs and arms limited to their own side, smoothed over the welded skin, soles
   rigid to the foot. Two failed first: the old skin warped onto the new joints left shards at the knee, and Blender
   bone heat leaked Arm.R down to the right foot. **The mirrored-leg bug is gone**: no left vertex is on a .R bone.
3. Jaw: `tools/jaw/add_jaw.py --open --weld --pivot 0.349 5.887 --split -24 --close 20 --blend 0.25`. A real Jaw bone
   under Head, bound with the mouth closed 20 of the modelled ~24 deg (lips never fuse). Two `add_jaw.py` fixes:
   - `--weld` (new, default off): the glTF import splits the skin at every UV seam, so the per-island tooth logic
     treated each triangle as an island and the lips cracked open along every seam.
   - The jaw's roll now flips on +Y-facing rigs so a +X turn always opens it (the ankylosaurus, -Y, is unchanged).
4. Clips scale every jaw key by 0.7 (`JAW` in make_rex_moves): the roar opens 31 deg, the bites 33-34, inside the
   modelled gape. Close-ups at 0 and 30 deg showed a clean mouth, no cracks, no lip stretch.

## Clips (17, all re-authored on the new rig)
- From REXFEEL, re-run on v2: heavy breathing idle, roar (alert), lunge bite, stomp, tail whip, low stalking walk, run,
  strafes and walk_back (make_gait + tyrannosaurus.json).
- PINFEEL's `pin_foot`, re-authored on v2: the neck dips less (the bigger skull reached the floor), and PIN_LIFT is
  0.30 -> 0.45 because the v2 toes hang lower. t_pinfeel passes.
- New in `make_rex_moves.py`:
  - **bite_shake** (signature, 2.5 s, clamp at 0.30): a short lunge with the jaws wide, they clamp, four head and
    shoulder thrashes, then a fling to her left.
  - **hit_react**: she jolts back off the blow, the head snaps up with a bellow.
  - **feed**: head down to the carcass, two braced tugs (the second with a shake), then two gulps.
  - **Lying clips, the known sinking fixed**: knockdown (crash onto the belly, heave, get back up), death (crash, then
    sag 30 deg onto the right flank), sleep (belly-down loop, head on the ground, deep breaths). Lying frames "settle"
    the lowest skin onto the floor every frame, so nothing sinks or hovers.
  - Side-lying was tried first and tore the thigh skin on this rig, so she goes down sternal (TR4).

## Fight AI (TyrantBrain)
- Carried over: fixed-facing timed attacks with telegraphs, the bite, the stomp every third attack (it pins with the
  foot, PINFEEL), the tail whip on a target behind her, the follow-through, the roar on spotting.
- **Bite and shake**: every third bite on something she can lift (a survivor, or a creature 3 m tall or less) becomes
  the bite and shake.
  - Telegraph "BITE & SHAKE - ROLL OR GET BEHIND", 0.75 s windup.
  - 1.5x damage, and the catch lands knocked down.
  - Pinned stays the stomp's (PINFEEL fairness: no pin off a bite).
- **Battle roar**: in melee, at most every 16 s (the first 6 s into the fight), she stops and roars ("ROAR - GET
  CLEAR", 18 m ring). Survivors and creatures 3 m tall or less inside the ring go Groggy and flinch; big animals don't.
- Numbers are guesses, logged as TR1-TR3 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## Alpha
- `tyrannosaurus_alpha_albedo.jpg`: the owner's armoured sheet colours (dark slate, blue-grey, ash belly; the mouth and
  teeth keep their colour), made by `tools/gait/rex_alpha_skin.py`.
- `pipeline.model_variants.alpha`. Only alphas wear it (`Creature.spawn` -> `CreatureView.use_variant`); normal spawns
  never draw it.
- No horns or spike row: that geometry needs its own Tripo mesh (one more generation). Not spent; the owner decides (TR3).

## Also carried over
- **Howdah**: `tools/blender/saddles/refit_rex_howdah.py`. Each saddle vertex moves with its bones to the v2 rest pose,
  then the howdah slides 0.8 m back off the new neck hump and lifts 0.48 m onto the back. `rider_in_mount` is rewritten.
  t_mounts, t_saddles and t_dismount pass.
- **Ragdoll**: `ragdoll.json` tyrannosaurus had leg capsules offset 2.3 m sideways, to match the v1 skin bound to the
  opposite side. Removed; the thighs are now free joints, so the upper leg drops when she rolls; metatarsals run to the toe.
- **Eyes** re-aimed on the new skull: spacing 1.07 m vs 1.05 m skull.
- Old v1 textures removed; `ref/.gdignore` keeps the reference PNGs out of the import.

## Shots (`docs/orchestration/reports/sp-tyrannosaurus/`)
From off-screen windowed runs (`--position 6000,3000`, self-quitting, `-- --skip-charcreate --lab=creature_lab
--species=tyrannosaurus --clipshots=DIR` / `--pinshots=DIR`).
- `contact_sheet.jpg`: all 17 clips, three frames each, with the survivor for scale. The 41 MB of raw frames are not committed; the clipshots command remakes them.
- `hits.jpg`: bite_shake clamp and thrash, the roar, sleep.
- `pin/`: the stomp pin on the v2 rig.
- The lab's `--pinshots` now skips the lab's tame rex (it picked the pet and quit).
- The `pin_foot` row of the contact sheet is not representative: the clip only reads right through the real stomp, as in `pin/`.

## Gates
| Gate | Result |
|---|---|
| `tools/gait/check_tyrannosaurus.py` (new; check_rex_clips on all 17, lying-aware) | REXCHECK PASS 17 clips |
| `python3 tools/audit_gaits.py --gate` | GATE PASS |
| `game/tests/t_sp_tyrannosaurus.gd` (new) | PASS. It checks: model, clips, Jaw opens 31-34 deg, feet grounded, lying poses, bite and shake lands, roar staggers small / not big / not far, Alpha skin, spawn row |
| t_rexclips, t_pinfeel, t_canim, t_ragdoll, t_eyeglow, t_mounts, t_saddles, t_dismount, t_noboxes, t_combat, t_data, t_turnrate, t_alphas, t_godlab, t_labspawn, t_ai, t_boneparts | PASS |
| `run_all.gd` | [tests] PASS |
| `tools/smoke.sh --no-import` | SMOKE PASS |

t_ragdoll failed once on compsognathus (slope stretch 26 % vs 25 %) and passed on the rerun. It is physics noise; the
compsognathus is untouched.

## How to test (owner)
1. Merge this branch into canon (or point `tools/fight_lab.command`'s REPO at this worktree) and double-click
   `tools/fight_lab.command`: the creature lab in GOD mode.
2. Press NEXT (or T) until "Tyrannosaurus" spawns: one aggressive rex, 8 m in front, coming at you.
3. Stand at her head: bite, then BITE & SHAKE (the head thrash and fling), then STOMP (foot pin). Every 16 s in
   melee she stops and roars; a small animal spawned near her (SPAWN) staggers.
4. Walk behind her for the tail whip; hit her until she drops to watch knockdown and death.
5. For the Alpha skin, spawn an Alpha tag rex (the Alpha roll), or check `t_sp_tyrannosaurus` "an Alpha wears the armoured skin".

## Not done, risks
- The bite-and-shake damage (1.5x) one-shots a 100 HP survivor, as the bite already did. That is balance, logged.
- The howdah fit is checked in Blender renders and by t_mounts and t_saddles. No ridden in-game shot was taken.
- The Alpha has no horns or spike row (TR3).
- `sheet.png` (the old asset validation render) was not regenerated.
- Shared files: `creature_clips.gd` OPTIONAL (+bite_shake), `anim_events.json` (+bite_shake row), `creature_lab.gd`
  CLIPSHOTS list, `add_jaw.py` (--weld, roll), `check_rex_clips.py` (LYING), `ragdoll.json` (rex block). Other species
  agents editing those lines will conflict on merge; keep every row.

Report head: see the commit that adds this file on `claude/mmo-sp-tyrannosaurus`.
