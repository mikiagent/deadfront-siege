# SP-TRIKEALPHA: the Alpha triceratops, its own bull-horned body

Branch `claude/mmo-sp-trikealpha` (from `origin/claude/mmo-overhaul` d915e67f, canon merged back in at 09b0e765).
Not merged to canon. Owner: "whatever happened to that bulky triceratops with the bull horns, is that in?"
It was not: alphas wore the regular body. Now every alpha triceratops is the owner's alpha sheet.

## Credits
- **Tripo 50** (balance 2005 -> 1955): one P1-20260311 multiview generation, texture + PBR, face limit 20000, no retry.
  Task `b48de3cb-10cd-4302-a5f8-591494609b18`. V3 API called directly with the key in `~/.tripo/config.json` (not printed).
- Codex (free): four clean views of the owner's alpha sheet with the beak closed (`sp-trikealpha/tripo_inputs.jpg`,
  copies in `game/assets/creatures/triceratops/alpha/ref/`). Meshy 0, no Tripo rig/anim/retexture.

## Model and rig (`tools/blender/triceratops/build_alpha.sh` rebuilds all of it)
- The Tripo mesh matches the sheet: charcoal hide with brown mottling, pale bull horns swept out and forward, nose horn,
  spiked frill rim, spines down the back, bulky low body (`tripo_render.webp`).
- Scaled to the species' 4.645 m frill top, so it is 10.9 m beak to tail (the regular is 9.0): longer, lower, wider.
- **Same rig layout as the regular** (31 bones, same names, parents and roll rule) so clips, saddle socket and AI all work.
  The regular's own scripts build it, switched by env:
  - `joints_alpha.py`: joints placed on the Alpha body, plus weighting tunables;
  - `build_rig.py` now reads those tunables with the regular's numbers as defaults, so the regular rebuilds unchanged.
    New for the Alpha: frill boxes, because the solid frill has no air gap for the occlusion rays; foot-top blend;
    wider knee band; extra smoothing on a thin skin web in front of the thighs, which tore 16x before.
- Weights: `sp-trikealpha/weights.jpg`.

## Clips (16)
- The regular's nine (`clips.py`) are solved again on the Alpha rig.
- `clips_alpha.py` adds:
  - walk_back and strafe_left/right: the walk's footfalls along the travel direction;
  - charge: the run with the horns levelled;
  - feed: head down, three bites with a rip;
  - sleep: lies down on its left side and breathes;
  - toss: the signature move.
- `tools/gait/ground_clip.py` lifted knockdown, death and sleep; a toe dipped 3.5 cm while falling.
- Strides equal the regular's, so `natural_speeds.triceratops` fits. Charge and strafes fall back to run/walk.
  No anim_events change.

## Signature move and AI (# ASSUMPTION, Open Questions TA1-TA6)
**Bull-horn hook-and-throw.** The regular horned_charger loop still runs (paw display, charge, horn hook, heavy).
When the Alpha's charge lands, it plays `toss`:
- the head is driven low (the charge pose);
- at 30 % it twists hard to its right and up, and the brow horns swing ~2 m sideways;
- `TacticalBrain._charge_impact` throws her sideways to the Alpha's right (`toss_side_m` 5), 1.5 m along the line,
  lifts her at 4.5 m/s, and staggers her 1.2 s;
- charge cooldown 6 s (regular 8).

The rhino's toss mechanics are reused. Only the sideways term is new, and only rigs with a toss clip use it.

Hits: hitboxes are not on canon, so `model_variants.alpha.hit_parts` judges the charge, heavy and primary at the Head bone
(2.4-2.6 m). `Creature.part_hit` now reads a variant's own `hit_parts`. The regular triceratops is unchanged.

## Wiring (canon's per-variant model mechanism)
- `triceratops.json` `pipeline.model_variants.alpha` = `{model: alpha/triceratops_alpha.glb, anim: alpha/anim,
  mount: alpha/mount, hit_parts, tactics}`, plus a `pipeline.alpha` provenance block.
- `Creature.spawn` already gives an alpha the `alpha` variant: wild rolled alphas, the lab's Alpha toggle (Spawner
  force_alpha) and tamed alphas. `pick_variant` never rolls it, so regular spawns keep the regular body.
- `lab_spawn_panel.variants_of` drops `alpha`, so the Body pick and NEXT never offer the Alpha body as a non-alpha.
- Saddle: built by the shared builder on the Alpha GLB into `alpha/mount/`.
  - `equip_mount_lab --species=triceratops --alpha` PASS: drift 0, boot_clear 0.17. It judges at size 1; the lab's numbers do not scale with genetics.
  - Shots: `saddle_side.png`, `saddle_iso.png`.
- `PlayerPets.mounted_move`: a ridden mount never plays strafe clips (TA6). The slow-turning Alpha strafed under the rider.
  This touches every mount with strafes; t_mounts still passes.

## Shots (`docs/orchestration/reports/sp-trikealpha/`, off-screen windowed `--lab=trikealpha_lab --variant=alpha`)
- `contact_side.jpg`, `contact_tq.jpg`: every clip at 30 % and 60 %, plus the hit frames, with the survivor.
- `hits_tq.jpg`: charge, the heavy hook at 72 %, and the toss at 30 % and 60 %; at 60 % the head is twisted with one horn up.
- `blender_new_clips.jpg`: the seven new clips.
- `saddle_*.png`: ridden. Alpha genetics darken it to the sheet's charcoal.

Fixed after looking:
- the frill tore off the shoulders (39x), until the frill boxes;
- the thigh web and the front heel pad stretched;
- the knockdown toe sank.

Left as is:
- In the neutral lab coloration the hide reads brown; alphas get the darker genetics.
- Feed lowers the head but the beak stays above the grass.
- The lying clips are the regular's roll onto the left side.

## Gates (after the canon merge)
- `check_trike.py` on alpha/: TRIKE_CHECK PASS, 16 clips. Stretch is at most 8.6 (gate 12), the lowest skin -0.012 m, and walk/run feet slide back.
- `audit_gaits.py --gate`: GATE PASS.
- `t_sp_trikealpha`: PASS. It checks:
  - the GLB, its 16 clips, its saddle and its tactics;
  - the regular's bones, height 4.64 m, length 11.1 m, and feet planted in 13 standing clips;
  - the toss swings the horns 2 m right;
  - an alpha spawn gets the Alpha body and a regular keeps the regular;
  - a charge lands, plays the toss, hurts, and throws her 4.9 m right and 1.1 m up;
  - the lab Body pick hides it.
- Also PASS: t_noboxes, t_combat, t_canim, t_data, t_mounts, t_saddles, t_godlab, t_labspawn, t_alphas, t_trikeland, t_petfollow, t_ai, t_tactical, t_sp_woolly_rhino, t_sp_megaloceros, t_sp_carnotaurus, t_sp_smilodon, t_sp_tarbosaurus.
- `run_all.gd`: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS.

## How to test (god mode)
1. `/Applications/Godot_mono.app/Contents/MacOS/Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`
2. SPAWN -> species Triceratops -> Alpha: ON -> nature Aggressive -> SPAWN (or turn Alpha ON, then press NEXT until the triceratops).
3. Stand ~10 m in front. It paws and charges; stay in its line and the horns hook you and fling you sideways to its right.
   Roll aside and it misses and stands staggered.
4. Up close: the head-toss hook and the held-horns heavy, both judged at the head. Tame one to ride it on its own saddle.
5. Clip review without fighting: `--lab=trikealpha_lab --variant=alpha --out=DIR` (windowed off-screen, self-quitting).

## For the next agent
- When claude/mmo-hitboxes lands, move `model_variants.alpha.hit_parts` there. The rig has no horn bones; add HornTip markers
  under Head if needed.
- The Tripo input GLB is not in the repo. Re-download it by task id to rerun `build_alpha.sh`.
