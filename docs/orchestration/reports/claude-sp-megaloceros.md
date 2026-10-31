# SP-MEGALOCEROS: new stag and doe, own rig, every clip re-authored

Branch `claude/mmo-sp-megaloceros` (from `origin/claude/mmo-overhaul` cf3128fc, canon merged back in at 4d460989).
Not merged to canon. Owner: Milan, "the model and animations suck, use the new references and redo the 3D model";
then "male and female variants both".

## Credits
- **Tripo 100** (balance 2705 -> 2605): two P1-20260311 multiview generations, texture + PBR, face limit 15000, no retry.
  - stag `bcfbeaa9-7512-43e7-8dc4-d468de798bd3`, doe `0ed68442-1cbd-43f6-a33b-9f9ef7a682da`.
  - Called the V3 API directly with the key in `~/.tripo/config.json` (never printed); the helper is in my scratchpad, not committed.
- Codex (free): three antler-less stag views (front, side, back) from the owner's stag sheet; the right view is the side mirrored.
- The doe views are the four clean panels of her sheet, cropped and padded. Inputs: `game/assets/creatures/megaloceros/ref/{stag,doe}_tripo_*.png`.
- Meshy 0, no Tripo rig, animation or retexture.

## Model and rig (`tools/gait/megaloceros/build.sh` rebuilds everything)
- `build_rig.py`: a hand-built deer skeleton on each Tripo body, in game metres.
  - Legs: scapula, upper, lower, cannon, hoof. Real carpus, hock and fetlock.
  - Also a jaw, a two-bone neck, a two-bone tail, and the bones `Hips`, `Torso`, `Shoulders`, `Head`, `BackFoot.*` and `FrontFoot.*` that the game and tools look for.
  - Leg joints below the belly are cross-section centroids; the rest are placed from the grid renders (`{stag,doe}.json`).
  - Weights are geometric, with side gating and a few smoothing passes.
  - The leg webbing Tripo leaves between the legs is cut away, and the groin and brisket follow the trunk.
  - The doe mesh had a flat card behind her left foreleg; it is cut out.
- Stag antlers are modelled in Blender and skinned 100 % to `Head` as a separate `Antlers` mesh.
  - Each side has a beam, a brow tine and a broad cupped palm with 12 fanned tines, coloured dark at the base and pale at the tips.
  - Span ~6.4 m, top 5.4 m.
- Size (ASSUMPTION MG1): stag withers 3.36 m (2.1 m x the 1.6 house factor), head 3.95 m. The doe is ~15 % smaller.
  - `real_length_m` 6.0 keeps the small pen (MG2).
- Sex is a body variant (`megaloceros.json` pipeline.model_variants):
  - stag = `megaloceros.glb` + `anim/`;
  - doe = `doe/megaloceros_doe.glb` + `doe/anim/`, her own saddle in `doe/mount/` and her own tactics.
  - Picked per animal, ~50/50 by spawn spot (MG3). tundra_30 spawned 6 stags and 5 does in the test.
- Saddles were rebuilt for both bodies. `build_saddles.py` gained `--glb` and `--out-dir`.
- `CreatureView` loads a variant's own model, clips and saddle. `TacticalBrain` merges a variant's `tactics`.

## Clips (`clips.py`, authored on the rig, no donor)
- Every leg is solved analytically to a hoof target. The stifle always bends forward and the elbow back; the cannon keeps a set tilt; the pastern points at a toe target that stays flat on the ground in stance.
- Clips (stag 16, doe 15): idle, walk (lateral sequence), run (transverse gallop), strafe_left/right, walk_back, alert, attack_primary, attack_heavy, kick, hit_react, knockdown, death, sleep (kneels front first), feed, plus charge for the stag only.
- Strides are in stag metres for both sexes, so the one baked natural speed fits both: walk 2.29 m/s, run 10.1 m/s.

## Signature moves and AI
- **Antler ram (stag)**: the alert clip is the rut roar, then the antlers lowered and shaken; this is the display tell. Then `charge`, a head-down gallop, on a locked line that shoves.
- **Rear-up stomp (both)**, attack_heavy:
  - sinks onto the hocks and rises ~40 deg with the forelegs folded and pawing (the tell);
  - crashes forward, and both forehooves hit the floor 1.2-1.5 m ahead of their stance at 0.72.
- **Rear kick (both)**: weight onto the forelegs, both hind hooves 1.3-1.5 m back and ~1.4 m up at 0.45. It fires when she is behind the animal.
- **Antler hook (stag)**, attack_primary: the head drops and rips up through the target at 0.42.
- **Doe**:
  - attack_primary is a forehoof strike;
  - no straight ram: her charge runs in to that strike;
  - point blank she stomps, kicks or strikes.
- AI: canon's skittish-territorial `antlered` profile (coelomoves: flees once, turns and fights, flees again under 30 %) is kept. My clip-driven numbers sit on top (MG5).
  - `attack_range` 1.9 -> 3.2, because the head is 2.5 m ahead of the body centre.

## Shots (`docs/orchestration/reports/sp-megaloceros/`, off-screen windowed `--lab=megaloceros_lab`)
- `contact_{stag,doe}_{side,tq}.jpg`: every clip at 30 % and 60 %, with the survivor for scale.
- `hits_{stag,doe}.jpg`: hook/strike, stomp and kick at their hit frames.
- Fixed after looking:
  - head/neck/body pitch signs were inverted;
  - the hook peaked after the hit;
  - the lying stag put an antler under the floor (the head now rolls up);
  - the doe's leg card;
  - stretch at the groin, brisket and leg webbing.
- Left as is:
  - the lying poses read stiff;
  - the palms are smooth plates;
  - in the neutral coloration the doe reads plain tan (her grey cape is in the texture but faint);
  - the loop clips carry one duplicated end frame.

## Gates
- `check_megaloceros.py` (stretch, ground, moonwalk, and stomp/kick reach): **PASS** for stag 16 clips and doe 15 clips.
- `audit_gaits.py --gate`: GATE PASS.
- `t_sp_megaloceros`: **PASS**. It checks:
  - both bodies, clips and antlers;
  - withers, and hooves planted;
  - stomp, kick and hook poses at the hit;
  - stomp, kick, ram and hook/strike damage a survivor;
  - the doe has no ram;
  - tundra_30 spawns both sexes.
- Also PASS: t_noboxes, t_combat, t_canim, t_data, t_godlab (updated: NEXT shows the stag then the doe), t_mounts, t_saddles, t_stationstate, t_boneparts, t_labspawn, t_ai, t_tactical, t_ragdoll (new megaloceros profile), t_coelomoves.
- `run_all.gd`: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS (all after the canon merge).

## How to test (god mode)
1. `/Applications/Godot_mono.app/Contents/MacOS/Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`
2. Press NEXT (T) until "Megaloceros ... [stag]" appears; NEXT once more gives the doe.
3. Or press SPAWN, pick Megaloceros and set Body to Stag or Doe.
4. Fight it with F, 1-4, Q and Shift. It runs first, then turns: watch the roar and antler-drop before the ram, the rear-up stomp when you are close in front, and the kick when you get behind it.
5. Clip review without fighting: `--lab=megaloceros_lab --variant=stag|doe --out=DIR`.

## For the next agent
- At 150 attack, a stomp, kick or ram one-shots a 100 hp survivor when god mode is off. That is a balance call.
- A herd with one stag (MG3) needs Spawner code. The Body pick in the lab is dev-only.
- `ragdoll.json` megaloceros radii fit the stag; the doe uses them too.
