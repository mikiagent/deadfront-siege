# SP-CERATOSAURUS: a new species, the Ceratosaurus

Branch `claude/mmo-sp-ceratosaurus`, cut from `origin/claude/mmo-overhaul`, with canon merged in again at 8082c43b (after SP-TARBOSAURUS). Pushed, not merged to canon.
Owner's go: "build some of the models ... Be creative with what moves you think they should do when they fight". The owner approved the species by sending the sheets ("I made it look more like a ceratosaurus"). Species id `ceratosaurus` (new).

## Credits
- **Tripo: 50.** One P1 multiview generation, task `402c6567-0c34-488c-9128-03352078ebe6` (`credits_consumed` 50). No retry.
  - The shared balance read 2155 before and 1955 afterwards. Other species agents were generating on the same account at the same time.
- Meshy 0, Higgsfield 0, no Tripo rig, animation or retexture. The Codex CLI drew 4 images, which were free.

## Model
- **Views.** The owner's sheet 1 has a mid-stride side view with the mouth gaping. Carno's mid-stride input came back with four legs, so I did not use it. Instead:
  - Codex drew a neutral standing left view from the sheet. The first draft gave it a tall rhino horn, so it was redrawn with the sheet's short, low nasal horn.
  - Codex then drew the front and back views from that left view. The right view is the mirrored left.
  - All four are on one scale with one background. Inputs are in `ref/` and in `sp-ceratosaurus/tripo_inputs.jpg`.
- **Mesh.** It matches the sheet: rust and dark brown bands, a cream belly, the short nose horn, two brow horns, the osteoderm row, and the mouth slightly parted. It is 1.0 x 0.2 x 0.41 units.
- **Rig.** Canon's `rig_biped.py` (the pachy route) with joints read off slices of the mesh (`tools/gait/ceratosaurus_rig.json`).
  - `add_jaw.py --x-side`. Canon's own roll fix does not cover a level jaw whose X points down, so a +X key yawed the jaw sideways. I re-added carno's flag beside it, off by default.
  - `open_mouth.py`. Tripo had bridged the parted lips with 2 mm faces that stretched 29x at a 30 deg gape. The lips are now ripped apart and the mouth has a gum-red bag.
- **Size** (CE1): 9.7 m nose to tail, `height_meters` 4.0, hips at 2.3 m. That is a ~6 m animal at the house 1.6x. `real_length_m` is 12, the 2x convention.
- **Rebuild everything:** `tools/gait/build_ceratosaurus.sh` (about 25 s).

## Clips (16)
- **Gaits:** walk, run, strafe_left/right and walk_back, from `make_gait.py` with `tools/gait/ceratosaurus.json`.
- **Everything else:** from the new `tools/gait/make_cerato_moves.py`, built on make_pachy_moves' machinery. Feet are IK-planted in every standing clip, and the lying clips rest on the floor.
- **Grounding:** `ground_clip.py --fps 24` runs on every clip. The `--fps` change is carno's, identical, and it caught a 3.6 cm sink in the roar.

| clip | what it is |
|---|---|
| attack_primary | **slashing bite**: the head cocks up and to one side with the jaws gaping, rakes down and across, and shuts at the hit (0.42); the teeth rip back |
| attack_heavy | **nose-horn gore**: a crouch with the head dropped so the horn points at the prey, then a snort and a horn wag (the held telegraph). It drives off a big step into an upward jab-and-hook (hit 0.72) |
| kick | **tail swipe** (the brain's kick slot): the head looks back, the hips coil, and the tail whips across behind it at survivor height (hit 0.45) |
| pounce | **water-edge lunge**: a low crouch, a flat surge with the jaws wide (airborne 0.2-0.65), the snap on landing (hit 0.7) and a twisting tug |
| alert | roar: it rears back, then thrusts the head forward with the jaws wide, shaking the horns |
| idle, hit_react, feed, knockdown, death, sleep | breathing and looking round; a stagger; tearing at a carcass; toppling onto its side; belly-down sleep |

## Moves and AI
Its own `tactics` block uses `base: saber_cat` without the stalk and the pin. It runs the TacticalBrain. Every number is an ASSUMPTION (CE2-CE4).

- **Water-edge ambush.**
  - It lurks if it finds a dry spot within 40 m of home that is either:
    - beside the river (within 9 m of the channel's centre line), or
    - beside the shore.
  - It opens with the crocodile-like LUNGE (the ambush pounce) at prey:
    - inside 10 m, or
    - inside 15 m when the survivor's back is turned.
  - With no water near home, or in the lab, it hunts in the open.
  - Code: new `TacticalBrain._ambushes` and `_find_water_edge`, `tactics.ambush_cover: "water"`.
- **From 5 to 11 m.** It picks one of:
  - the lunge, telegraphed by the gore crouch under the ground ring;
  - a sidestep into the lunge;
  - a roar into a charge;
  - a plain charge.
- **Point blank.** The order is `kick, heavy, bite`:
  - the tail swipe when she is behind it (x1.3);
  - else the gore (x1.8, 6 s cooldown);
  - else the slashing bite.
- **Bleed.** Only the bite applies it (Bleed x2). New generic hook: `pipeline.status_clips` in `CreatureAttack._apply_token`. The gore does not bleed, and the test checks this.
- **Hits come from the part.** The hitbox system is not on canon, so this uses canon's `pipeline.hit_parts` / `Creature.part_hit`:
  - the bite and the lunge from Jaw;
  - the gore from Head and Jaw;
  - the tail swipe from Tail4-6.
- **Reach.** `tactics.reach_m` is 4.9, canon's tarbosaurus mechanism. The lunge lands that far short of the prey, so the jaws, about 3.8 m ahead of the centre at the hit, land on her.
- **Alpha.** Canon's `pipeline.model_variants.alpha` gives alphas `ceratosaurus_alpha_albedo.jpg`, made by `tools/gait/ceratosaurus_alpha_skin.py`.
  - It recolours the regular texture to the sheet-2 camo (olive, dark brown, cream) with an orange throat and belly.
  - The alpha's bigger blocky nasal crest is **not** carried: it is a texture swap, and I spent no second generation (CE5).
  - ASSUMPTION: sheet 2 is the Alpha skin, per the owner's two-sheet rule.
- **Spawns.** One per island:
  - swamp_55's working ring;
  - tropical_40's working ring, at a 60 % chance.
  - The lab lists it automatically.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command` once this is on canon. GOD (key G) is on.
2. Press SPAWN, pick **Ceratosaurus**, count 1, nature Aggressive (Alpha ON for the camo skin), then SPAWN. NEXT (T) also cycles to it.
3. Stand 6-10 m off. It crouches head-down under the red ring, then lunges low with its jaws wide. Roll (Q) out of the ring to dodge, or it roars and charges.
4. Stand at its snout. You get the slashing bite (you start bleeding) and the gore (a held head-down horn wag, then an upward hook; no bleed).
5. Walk behind its hips and it swings round with the tail. In the wild (swamp_55 or tropical_40) one lurking at a riverbank or the shore ambushes with the lunge when you come within 10 m. N enrages it.

## Shots (`docs/orchestration/reports/sp-ceratosaurus/`)
- **Source.** Off-screen windowed runs of the new `cerato_lab` (`--position 6000,3000 -- --skip-charcreate --lab=cerato_lab --out=DIR [--alpha]`). They quit by themselves.
- **Files:**
  - `contact_sheet.jpg`: all 16 clips at 30 % and 60 %, side view, with the survivor for scale.
  - `hits.jpg`: bite, gore, tail swipe and lunge at their hit frames, side and three-quarter.
  - `alpha_sheet.jpg`: the alpha skin.
  - `tripo_inputs.jpg`: the four Tripo views.
- **What read wrong and was fixed:**
  - the rhino horn in the first Codex view;
  - the jaw yawing instead of opening (`--x-side`);
  - the lip web (`open_mouth.py`);
  - the tail drooping when it was meant to rise, in the gore, roar and lunge;
  - the tail swipe peaking past the hit and passing above the survivor's head;
  - the bite and the gore hitting above her head;
  - the roar sinking 3.6 cm.

## Gates (after merging canon 8082c43b)
- `tools/gait/check_cerato.py --height 4.0` (new, adapted from check_pachy): **CERATO_CHECK PASS** on all 16 clips. It checks:
  - stretch, worst 6.5;
  - no sinking;
  - no moonwalk;
  - no glide: planted toes stay within 6 cm in every one-shot;
  - at the bite and the gore, the snout leads and is at least 0.5 m forward of rest;
  - the gore hooks up at 10.7 m/s;
  - the tail sweeps at 20.7 m/s at the swipe's hit.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_ceratosaurus.gd`: **PASS**. It checks:
  - the model, all 16 clips, the bones, the 4.0 m height and the 9.7 m length;
  - feet on the floor in 10 standing clips;
  - each part ahead at its hit frame;
  - the spawn rows and the lab list;
  - in a live fight: the bite lands and she bleeds, the gore lands without bleed, the tail swipe is picked behind it and lands;
  - the water-edge ambush lunge springs and lands, and with no water it does not lurk;
  - the alpha skin.
- t_noboxes, t_combat, t_canim, t_data, t_ai, t_tactical, t_labspawn, t_sp_smilodon, t_sp_pachycephalosaurus, t_sp_tarbosaurus: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## For the next agent
- **Shared files touched:**
  - `tactical_brain.gd`: the water-edge ambush, about 35 additive lines. My `pounce_land_m` was dropped for canon's `reach_m` at the merge.
  - `creature_attack.gd`: `status_clips`, 4 lines.
  - `creature_lab.gd`: carno's `--clips` / no-HUD clipshots diff, applied verbatim.
  - `tools/jaw/add_jaw.py`: `--x-side`, beside canon's roll fix.
  - `tools/gait/ground_clip.py`: `--fps`, carno's identical diff.
  - Data: `anim_events.json` (one `natural_speeds.ceratosaurus` row spliced in: walk 2.91, run 11.15 m/s, from a `bake_clip_speeds.py --dry-run`) and `islands.json` (2 rows).
- **Not done:**
  - no saddle or mount role;
  - no eye-glow points;
  - no ragdoll or butchering row;
  - `docs/current/biome-spawns.md` and `species-art.md` were not regenerated (generated docs).
- **Known limits:**
  - The water-edge spot is only the bank. It does not wade or submerge; the "water" is where it lurks.
  - The lunge's flight is a low arc carried by the brain.
  - A fresh 100 HP survivor dies to one gore or one tail swipe (CE2, balance).

Report head: the commit that adds this file on `claude/mmo-sp-ceratosaurus`.
