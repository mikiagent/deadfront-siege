# RAPTORSCALE — velociraptor, deinonychus, utahraptor sized to the owner's reference

Branch `claude/mmo-raptorscale` (from `origin/claude/mmo-overhaul` 9cd557b6). Not merged. No credits spent.

## What the reference says

Owner, 2026-10-30: velociraptor 1.8 m, deinonychus 3 m, utahraptor 7 m long; velociraptor smallest, utahraptor much larger and bulkier.
The PNG at `.claude/worktrees/species-ref/raptor_size_comparison.png` is a single dromaeosaur painting, not a three-way lineup, so the ratio comes from the lengths in the message.

## How size works

- `height_meters` scales the mesh: the mesh is scaled uniformly so its height equals that number. On-screen length follows from the mesh's shape.
- `real_length_m` is a gameplay size, not a display fact. It sets the collision capsule radius (0.12 x L), melee reach, the kick-shove mass (L x H), pen tiers (`taming_pens.json` max_length_m), the default turn rate and feeds when no taming block is given, ragdoll reach, and plate/camera framing.
- The roster stores 2 x true length there (commit c75fca4f: compy 1.5 -> 3.0, T. rex 12 -> 24, utahraptor 5.5 -> 11). Velociraptor and deinonychus got 3x (2.0 -> 6.0, 3.4 -> 10.2). So 6.0 was not feet: it was the 3x raptor factor.
- On screen, measured with the new `creature_lab --lineup`, compsognathus is 2.39 m long for 1.5 m and T. rex 19.4 m for 12 m: **1.6 x true length** is the house exaggeration on screen.

## Change

| species | on-screen length (m) | height_meters | real_length_m | saddle class |
|---|---|---|---|---|
| velociraptor | 6.53 -> **2.88** | 2.4 -> **1.06** | 6.0 -> **3.6** | medium -> **small** |
| deinonychus | 3.35 -> **4.81** | 2.0 -> **2.87** | 10.2 -> **6.0** | small -> **medium** |
| utahraptor | 9.69 -> **11.19** | 4.0 -> **4.62** | 11.0 -> **14.0** | medium |

The on-screen ratio is now 2.88 : 4.81 : 11.19 = 1.8 : 3.0 : 7.0. `size_note` in each JSON's pipeline block carries the `ASSUMPTION`. Logged as RS1-RS3 in `docs/vision/WildLandsMMO_Open_Questions.md`.

Shot: `docs/orchestration/reports/raptorscale/lineup.png` (survivor, velociraptor, deinonychus, utahraptor, orthographic, side-on, body size 1.0). `raptorscale/before/lineup.png` is the old sizes; its survivor shows as a box because that run loaded the scene directly instead of going through `--lab=`.
Run it with: `Godot --path game --position 6000,3000 --resolution 1688x780 -- --skip-charcreate --lab=creature_lab --lineup=DIR [--species=a,b,c]`. The lab saves the PNG, prints each mesh's measured length and height, then quits.

## Things the owner should decide

1. **Deinonychus height.** On 2026-10-28 the owner set it to 2.0 m, about chest height on the survivor. At the house factor it is 2.87 m, above her head, because its mesh is stubby (length is only 1.7 x height). The alternative: keep deinonychus at 2.0 m and scale the others to match (factor 1.12). The velociraptor would then be 0.74 m tall, shorter than the compsognathus, and the utahraptor 3.23 m.
2. **real_length_m is not true metres.** I did not apply "fix real_length_m to true metres". Every species stores 2 x true length there, and gameplay reads it as body size. True metres on three species alone would give the velociraptor a smaller hitbox and kick mass than the compy. I set the three to the roster's 2x instead. The pen UI's "about N m long" line therefore shows 2x for every species; a separate display length would fix it across the roster.
3. **Velociraptor as a mount.** At 1.06 m its back is about 0.67 m, under the SADDLES rule (a 1.78 m rider needs back x 1.6 >= rider). It keeps its saddle, mount.json and mount role. t_mounts only checks the rule on skipped species. Saddle class moves to small. To follow the rule it would go into `mounts_skip.json` and its saddle files would come out (deletes left to the owner).
4. Compsognathus (1.2 m) now stands slightly taller than the velociraptor (1.06 m), though it is shorter (2.39 m vs 2.88 m). Compy is 2.4x on screen, above the 1.6 house factor; I did not touch it.

## Unchanged

Pen tiers: velociraptor small; deinonychus medium (set by its value); utahraptor large (set by its value). Taming feeds and requires_pen are explicit per species. Turn rates are explicit. Butcher tables are explicit per species. Clip speeds scale with height_meters (`creature_clips.gd`), so the raptorfeel investigate/sniff clips play at the new size. t_raptorfeel passes.

## Tests touched

- `t_saddles`: the velociraptor now takes a small saddle; the medium-saddle ride, save and gate checks use the deinonychus.
- `t_kicktackle`: the target velociraptor was spawned with its feet at the survivor's capsule centre, 1 m up. The 1.06 m raptor then hung in her path, the tackle landed her on it and launched her. It now spawns on the ground.
- `t_petfollow` fails on the base branch too ("a settled pet moved 0.248 m"). That is not from this change.

## Gates

t_raptorfeel, t_combat, t_canim, t_tame, t_stationstate, t_mounts, t_noboxes, t_saddles, t_kicktackle PASS; `run_all.gd` [tests] PASS; `tools/smoke.sh --no-import` SMOKE PASS. t_genetics, t_tactical, t_turnrate, t_capture09, t_tamingodds, t_swarm, t_energy, t_boneparts, t_dodgetext also PASS.
