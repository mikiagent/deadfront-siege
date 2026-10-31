# SP-PACHYCEPHALOSAURUS: rebuilt model, rig, clips and fight moves

Owner (Milan, verbatim): "the Pachy's model is completely ruined. the legs are mangled. And the color is off. See if
you can unmangle the legs, if not, redo model in Tripo".
Branch `claude/mmo-sp-pachycephalosaurus` (from `origin/claude/mmo-overhaul`, canon merged back in). Not merged to canon.

**Credits: Tripo 50** (balance 2605 -> 2555). One multiview generation, task `c890b902-ab1d-4a89-b997-fc74254abcf7`.
No retry used. No Meshy, no Tripo rig/anim/retexture. Views drawn by Codex (free).

## Step 1: diagnosis (no credits)
The legs could not be fixed cleanly on the old model.
- **Rig.** The v1 rig was a Velociraptor skeleton transplant. The landmark warp put Hips/Torso/Shoulders 25 cm ahead of
  the real pelvis (y -0.27 vs -0.03) and ran Tail1-2 through the belly. 9 000 verts sat on Head and 5 000 on Neck.
  The legs used the raptor's 3-bone chain, with the "knee" at the real ankle.
- **Clips.** idle/attacks/hit/death were the raptor's own (attack_heavy was a raptor leap). Every one crumpled the legs.
- **Mesh.** The v1 Tripo mesh itself is in a deep crouch. Each thigh carries a fused rear lump that hangs to the knee,
  and the shin is about 6 cm long. No joint placement articulates that into a clean stride. Re-rigging alone would have
  kept a lumpy, folded leg.
- **Colour.** `coloration.hue_deg` was 355. It is read as a ±range and clamped to ±40°, so wild pachys rolled orange
  to purple hides. A `stripes` pattern was also drawn on top of the painted stripes.

## Step 2: new model (Tripo, approved)
- **Views.** Codex drew a clean standing left side view from the owner's sheet: legs straight, mouth parted, sheet
  colours. From it, Codex drew front and back; right is the mirrored left. The four inputs are in
  `game/assets/creatures/pachycephalosaurus/ref/pachycephalosaurus_view_*.png`.
- **Mesh.** Upright legs, separated feet. The texture matches the sheet: cream base, dusty-pink stripes, red back,
  tan lower legs. The mesh is `work/pachycephalosaurus_tripo_v2.glb` (gitignored; the task id re-downloads it).
- **Rig.** New `tools/gait/rig_biped.py` builds a hand-placed T. rex-style skeleton from
  `tools/gait/pachycephalosaurus_rig.json`. Bones: Hips/Spine1/Chest/Neck1/Neck2/Head, Tail1-6,
  Thigh/Shin/Metatarsal/Toe, Arm/Forearm/Hand. Weights:
  - heat weights, with the voxel proxy where heat misses;
  - side-cleaned (no left skin on right bones);
  - the leg zone stays on its own leg chain, with claws rigid on Toe/Metatarsal;
  - loose shells (dome spikes, back scales) pinned to the nearest hide vertex, and unweighted verts filled from the
    nearest neighbour. Before this, a spike shot out of the head.
- **Jaw.** `add_jaw.py --open`.
- **Clips (16), one script:** `tools/gait/build_pachycephalosaurus.sh`.
  - Gaits from `make_gait.py` and `tools/gait/pachycephalosaurus.json`: walk, run, **charge** (head down, dome
    leading), strafe_left/right, walk_back.
  - New `tools/gait/make_pachy_moves.py`: idle, alert, attack_primary, attack_heavy, **kick**, hit_react, knockdown,
    death, sleep, feed. Standing clips keep the feet IK-planted. Lying clips fold the legs on body-relative hinges and
    rest on the floor.
  - Every clip then goes through `ground_clip.py`.
- **Saddle.** Rebuilt (`saddles.json`: socket Spine1, shoulder Chest, neck Neck1). Mount and t_mounts/t_saddles pass.
- **Eyes** re-cast onto the new mesh. **natural_speeds** row re-baked (walk 1.20, run 4.22 m/s); only that row was spliced in.

## Fight moves (# ASSUMPTION, logged as PC1-PC5 in the Open Questions)
| Move | Clip | When the brain uses it | Hit |
|---|---|---|---|
| Dome headbutt with knockback | `charge` | display -> charge sequences (pack_mule) | the ram shoves the survivor 3.5 m (was 2.5), x2.0 |
| Hip check / shove | `kick` | point blank, survivor behind it | rump and tail slam sideways at 4.1 m/s at hit 0.45 |
| Stomp | `attack_heavy` | point blank otherwise (7 s cooldown) | rears, right foot held high (telegraph), slams down at 0.72, x1.4 |
| Dome butt | `attack_primary` | point blank, both above cooling | chin tucked, dome is the front-most point at 0.42, 2.18 m ahead of centre |

- **Wiring.** A new optional species `tactics{}` block is merged over the archetype's ai.json tactics.
  - Code: `CreatureDef.tactics`, plus two lines in `TacticalBrain.setup`. Documented in SCHEMA.md.
  - The pachy keeps `pack_mule`'s herd and grazer rules.
  - Its point-blank order is `kick, heavy, bite`. The hip check comes first because it only fires when the survivor is
    behind; otherwise the stomp runs.
- **Reach.** The dome reaches 2.18 m at the hit. The contact reach is 2.1 m, and a hit is accepted up to 2.4 m, so hits
  land where the dome is.

## Gates (after merging origin/claude/mmo-overhaul)
- `tools/gait/check_pachy.py --height 1.8` (new; check_ankylo adapted): **PACHY_CHECK PASS**, 16 clips. It checks:
  - stretch at most 7.1 (gate 8; the worst edges are 7 mm mouth corners);
  - no sinking;
  - no moonwalk on gaits and strafes;
  - no gliding in one-shots (worst slide 3 cm);
  - the dome is the front-most point at the butt's hit;
  - the stomp lands at 3.4 m/s from 0.47 m;
  - the hip check swings at 4.1 m/s.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_pachycephalosaurus.gd`: **PASS**. It checks:
  - GLB, no boxes, all 16 clips, bones;
  - 1.8 m tall;
  - feet planted in 7 standing clips;
  - the dome drives 0.47 m forward;
  - hue roll within ±10°;
  - in a live fight: stomp picked in front and lands, hip check picked behind and lands, the charge connects with the
    charge clip.
- t_noboxes, t_combat, t_canim, t_data, t_mounts, t_saddles, t_zebra, t_styraco, t_ai, t_godlab: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/sp-pachycephalosaurus/`)
Taken from self-quitting off-screen windowed runs of the new `pachy_lab`
(`--position 6000,3000 -- --skip-charcreate --lab=pachy_lab --out=DIR`).
- `contact_sheet.jpg`: all 16 clips at 30 % and 60 %, side view, survivor for scale.
- `hits.png` and `hits/`: dome butt, stomp and hip check at their hit frames, side and three-quarter.

## How to test
1. Double-click `tools/fight_lab.command` (or `Godot --path <canon>/game -- --lab=creature_lab --god --skip-charcreate`) once this branch is merged; until then run it with `--path` pointed at this worktree's `game`.
2. Press NEXT (T) until "pachycephalosaurus" is shown, or SPAWN -> Pachycephalosaurus. It spawns Aggressive and comes at you.
3. Stand off 6-8 m: it lowers its head (display) and charges dome-first. Get hit and you are shoved back about 3.5 m. Sidestep it and it stands staggered.
4. Stay at point blank in front of it: stomp (it rears with a foot held high, dodge then) and dome butts. Walk behind it: hip check.
5. GOD keeps you alive. Press 1-9 out of combat to force its clips. Ride it after a tame to check the saddle.

## For the next agent
- **Not on any spawn table** (it was not before either). Where it lives is the owner's call (PC5).
- **Damage.** It hurts: ~49 per stomp, ~61 per hip check, ~87 per charge on a fresh survivor. That is the species
  attack 48 times the moves; it is a balance call and I did not tune it.
- **Lying clips.** The knockdown and death show the folded legs pointing out of the belly side; the sleep sits
  belly-low on folded legs rather than flat.
- **Shared code.** `tools/gait/rig_biped.py` and `make_pachy_moves.py` take any Tripo biped that has a spec JSON.
  `CreatureDef.tactics` is a shared hook; merge with any branch that also edits `creature_def.gd`.
