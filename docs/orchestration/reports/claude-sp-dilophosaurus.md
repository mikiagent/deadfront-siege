# SP-DILOPHOSAURUS: the dilophosaurus is a rigged, animated 3D theropod with a flaring frill, a venom spit and a leaping slash

Branch `claude/mmo-sp-dilophosaurus`, from `origin/claude/mmo-overhaul` (d915e67f, after SP-SMILODON); canon re-merged before
this report (already up to date). Pushed, not merged to canon.
Owner's go: "build some of the models ... Be creative with what moves you think they should do when they fight", then
"keep cooking". Species id `dilophosaurus`; the existing data and the four spawn rows are kept.

## Credits
- **Tripo: 50** (one multiview, task `edf6ddcc-0972-4860-800b-c2bc732cab43`, `credits_consumed` 50). No retry.
  - Shared balance 2205 before (50 frozen by another agent), 2155 after.
- Meshy 0, Higgsfield 0, no Tripo rig/anim/retexture. Codex images are free.

## Model
- **Views without the frill.** The owner's sheet draws a paper-thin flared frill, a Tripo risk. Codex drew a frill-less
  standing left view from sheet 1 (crests, tan/khaki with green mottling, mouth parted), then front and back from it (the
  back redrawn once: the tail hung to the floor). Right = left mirrored. Inputs in `game/assets/creatures/dilophosaurus/ref/`.
- **Mesh.** Tripo P1 multiview, texture + PBR: 1.0 x 0.15 x 0.34 units. Matches the sheet (double crest, mottling, banded
  whip tail, red-brown feet).
- **Rig** (`tools/gait/build_dilophosaurus.sh` rebuilds everything from `work/dilophosaurus_tripo_v1.glb`):
  1. `rig_biped.py` + new `tools/gait/dilophosaurus_rig.json` (joints read off ortho renders): Hips/Spine/Neck/Head,
     Tail1-7, Thigh/Shin/Metatarsal/Toe, Arm/Forearm/Hand.
  2. `add_jaw.py --open` (the mesh was modelled mouth open; closed in the bind pose).
  3. **New `tools/gait/dilophosaurus_frill.py`: the frill built in Blender.** A serrated fan membrane on each side of the
     neck behind the skull, on 7 rib bones a side (`Frill1-7.L/R`, children of Neck2).
     - Rest pose is FOLDED (ribs lying back along the neck), so clips that never key the ribs (the gaits) keep it shut.
     - Clips flare it by rotating each rib to its open rotation (`tools/gait/dilophosaurus_frill.json`).
     - Painted procedurally (yellow cells, red veins, dark serrated rim) into a strip added under the body atlas, so the
       model keeps one material and the alpha stays a plain albedo swap.
     - Rest normals are the open fan's normals carried into the fold (Godot skins rest normals; recomputed pleat normals
       came out as dark streaks when it opened).
     - The origin moves to mid-torso: at the bbox centre the snout sat 5.3 m ahead of the origin, out of every reach.
- **Size**: unchanged data, `height_meters` 3.6 (crest top), 10.5 m long, hip 2.1 m (DL1).

## Clips (16), all in `anim/`
- **Gaits** (`make_gait.py` + new `tools/gait/dilophosaurus.json`): walk, run, strafe_left/right, walk_back.
- **New `tools/gait/make_dilo_moves.py`** (make_pachy_moves' pose engine + frill keys, feet IK-planted):
  - `alert`: the frill snaps open and rattles, body sinks, head sways, long hiss. The telegraph and hold pose.
  - `attack_primary`: quick snapping bite (hit 0.42).
  - `attack_heavy`: flare and slash. Flared hissing crouch (telegraph), then the right foot rakes forward and down
    (hit 0.72). Its first 72 % is also the leaping slash's windup.
  - `spit` (new clip): frill flares, head draws back gaping, then whips forward; the glob leaves at 0.62.
  - `pounce`: leaping slash. Crouch, legs tucked then thrown forward toes-up, lands feet first raking (hit 0.7).
  - idle, hit_react, knockdown, death, sleep, feed.
- Every clip but the pounce goes through `ground_clip.py`.

## Moves and AI (species tactics block in `dilophosaurus.json`; TacticalBrain)
- **Frill flare + hiss is the telegraph.** It flares before the spit, the slash and the leaping slash, and in the hold
  and display beats. The quick snap has only a frill flick.
- **Venom spit** (new move `spit`):
  - From 3.5-11 m with a clear line.
  - It stops, faces her and plays `spit` under a ground ring ("SPIT - DODGE!") that follows her until the release.
  - At the hit frame `TacticalBrain.launch_spit` fires a `VenomSpit` glob (new `scripts/combat/venom_spit.gd`) from the
    Jaw bone at her chest. It flies at 16 m/s with no homing.
  - It hits through `CreatureAttack` if she is still within the ring, so a roll in its window or a wall also stops it.
  - **Venom** rides on the spit only (new `tactics.status_clips`): the existing status, nothing invented (DL2).
  - It also opens with the spit on the approach and spits after prey that runs (`approach_spit`).
- **Leaping slash**: the existing pounce machinery with the dilophosaurus clip, from 4-8 m. Hit from either foot.
- **Point blank**: the rake (`heavy`, from the right foot) or the snap (`bite`, from the jaws), then it backsteps out to
  spitting range.
- **Sequences**: spit; display -> spit; backstep -> spit; strafe -> spit; pounce; display -> pounce.
- **Where hits land**: canon's `pipeline.hit_parts` / `Creature.part_hit` (`docs/current/hitboxes.md` is not on canon).
- **Alpha**: Alpha tag in the lab or a genetics roll. It wears `dilophosaurus_alpha_albedo.jpg`: olive with rust
  blotches, fiery orange frill, from new `dilophosaurus_alpha_skin.py`, via `model_variants.alpha`.

## Shared files touched
- code:
  - `tactical_brain.gd`: spit move, `launch_spit`, `approach_spit`.
  - `creature.gd`: `_on_hit` hands the spit hit to the brain.
  - `creature_attack.gd`: `status_clips`.
  - `creature_anim.gd` and `creature_clips.gd`: `spit` as a one-shot attack.
  - `telegraph.gd`: `show_pounce` takes a label.
  - `lab_spawn_panel.gd`: `spit` in FIGHT_CLIPS.
- data:
  - `ai.json`: venom_ranged attack_range 2.4 -> 3.0 (DL5).
  - `anim_events.json`: `spit` clip row, pounce note, dilophosaurus natural_speeds row. Only these rows were spliced.
- docs: `biome-spawns.md`, `species-art.md`, Open Questions DL1-DL7.

## Shots (`docs/orchestration/reports/sp-dilophosaurus/`)
- They come from off-screen windowed runs of the new `dilophosaurus_lab`, which quits by itself.
- `contact_sheet.jpg`: all 16 clips at 30 % and 60 %, with the survivor for scale.
- `hits.jpg`: the snap, the rake, the spit at release and the glob in flight, the slash in the air and at the hit, and the
  flared display. Side and three-quarter views.
- `alpha_sheet.jpg`: the alpha skin. Full frames are in `sheet/` and `alpha/`.

### What read wrong in my reviews, and what I did about it
- **Fixed:**
  - The frill drew dark radial streaks in Godot. The atlas padder matched "orm" inside "NormalGL", so the frill's normal
    map was orange; the fix also dropped the back sheet and carries normals.
  - The tail shot up vertically in alert and the pounce.
  - The rake slid and left both feet off the ground.
  - The run toes dipped 3 cm under the floor.
- **Left as is:**
  - The folded frill is a visible yellow ruff along the neck (DL7).
  - The near frill goes dark when it is back-lit.
  - Knockdown and death are pachy-style side falls.

## Gates
- `check_dilophosaurus.py --height 3.6`: **DILO_CHECK PASS**, all 16 clips. It covers:
  - stretch at most 5.1;
  - no sinking;
  - no moonwalk or glide;
  - the snap leads with the snout (3.8 m ahead);
  - the rake sweeps at 10.6 m/s;
  - the spit whips at 10.9 m/s with the jaws open;
  - the slash leads with the claws;
  - the frill is under 1.4 m across folded and 2.8 m open.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `t_sp_dilophosaurus`: **PASS**. It covers:
  - model, clips, bones, size and toes on the floor;
  - frill folded in the gaits and flared in alert/heavy/spit;
  - parts ahead at their hit frames;
  - spawn rows: tropical_25, tropical_40 x2, swamp_55;
  - the spit lands and Venoms a survivor who stands still;
  - a sidestep after the release dodges it (no damage, no venom);
  - the snap lands without venom;
  - it opens with the spit at 11 m on the approach;
  - the leaping slash lands from the feet;
  - the alpha skin.
- t_noboxes, t_combat, t_canim, t_data, t_labspawn, t_tactical, t_ai, t_godlab, t_sp_smilodon,
  t_sp_pachycephalosaurus: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command`
   once this is on canon.
2. SPAWN -> **Dilophosaurus**, count 1, Alpha on for the orange-frilled alpha -> SPAWN. Or press NEXT (T) until the
   info line says Dilophosaurus.
3. Stand 8-11 m off. It flares and hisses, then spits under a "SPIT - DODGE!" ring. Step or roll (Q) out of the ring
   after the frill whips forward to dodge; a hit leaves you Venomed (green tint, accuracy down).
4. At 4-8 m watch the flared crouch, then the leaping slash. Point blank you get the foot rake (crouch first) or the
   quick snap, then it backsteps to spitting range. Run away and it spits after you.
5. GOD (G) keeps you alive. Press N to enrage it (more spits, shorter cooldowns). In the wild it spawns on tropical_25,
   tropical_40 and swamp_55.

## For the next agent
- **Damage.** It one-shots a fresh 100 HP survivor with the snap and the slash, and nearly with the spit (attack 210, the
  old stat block). That is a balance pass (DL4).
- **Reuse.** `VenomSpit` and the `spit` move are generic: any species with a `spit` clip and `spit_*` tactics gets them.
- **Size.** The GLB is 13.5 MB with PNG Color/ORM maps; a JPEG pass on the Color map would roughly halve it.

Report head: see the commit that adds this file on `claude/mmo-sp-dilophosaurus`.
