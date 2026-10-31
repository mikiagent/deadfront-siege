# SP-RAPTOR: the Raptor, a new rideable black-and-gold dromaeosaur with colour morphs

Branch `claude/mmo-sp-raptor`, from `origin/claude/mmo-overhaul` d915e67f, with canon merged in before this report.
Pushed, not merged to canon. Species id `raptor` (new).

What the owner said:
- "black and gold is the original raptor (idk just call it Raptor)"
- "raptor is big enough though" (to ride)
- "it comes in different colors including green and different feathers"
- Overnight: "keep cooking" / "continue".

## Credits
- **Tripo: 50.** One multiview, task `98abc3e6-8f7f-4002-8354-282eb7759663`, `credits_consumed` 50, no retry.
  - Balance read 2305 before and 2155 after. Other agents were generating at the same time.
- Meshy 0, Higgsfield 0. No Tripo rig, animation or retexture. Codex images are free.

## Model
- **Views.** From the owner's sheet (`ref/raptor_owner_sheet_1_black_gold.png`):
  - Codex drew a clean left side view with the arms folded high and the mouth parted. The sheet's arms hang toward the ground, and a hanging arm built a second pair of legs on the deinonychus.
  - Codex then drew the front and back views from that side view.
  - The right view is the left one mirrored. All four are padded to a common scale (`sp-raptor/tripo_inputs.jpg`, `ref/`).
- **Mesh.** Tripo P1 multiview with texture and PBR. It matches the sheet: black scales with gold flecks, the gold crest, spine quills and arm fans, sickle claws, orange eyes.
- **Rig** (`tools/gait/build_raptor.sh` rebuilds everything from `work/raptor_tripo_v1.glb`, which is gitignored; the task id re-downloads it):
  1. `transplant_rig.py` with the Quaternius Velociraptor donor. This is the deinonychus and utahraptor skeleton, so their clips carry over.
  2. `add_jaw.py` fits the mouth line from the texture. `open_mouth.py --corner 0.03` rips the lips and adds a red mouth bag; the short corner keeps the gape web at the mouth corner under the stretch gate.
  3. New `raptor_leg_weights.py`. The transplant had skinned the whole thigh to the hip-socket bone, so a raised foot left the thigh behind as a thin string. The thigh skin now follows the leg.
- **Size** (`# ASSUMPTION`, RP1):
  - `height_meters` 3.5. The back over the hips is about 2.4 m, so it is rideable.
  - It is 7.48 m long on screen: deinonychus is 4.81 m and utahraptor 11.19 m, so it sits between them.
  - `real_length_m` 9.4, the roster's 2x of a 4.7 m true length.

## Clips (22, all in `anim/`)
- **From deinonychus** (`transfer_clips.py --floor-feet`, plus `--pin-toes` on the one-shots): idle, walk, run, charge, strafe_left, strafe_right, walk_back, attack_primary, bite_combo, pounce, hop_back, leap_back, dodge_left, dodge_right, hit_react, knockdown, death.
- **From velociraptor:** feed.
- **New in `tools/gait/make_raptor_moves.py`.** Each is keyed as small turns from rest, with the stance foot held on its print by two-bone leg IK.
  - `pin_stab`: the pin-and-bite.
  - `attack_heavy`: the sickle slash.
  - `alert`: the crest-flare display.
  - `sleep`: lying belly-down with the legs folded and the head down; it loops.
  - The velociraptor's sleep sank 0.7 m on this body, and utahraptor's stretched the legs, so I authored a new one.

## Signature moves and AI
The base is the deinonychus brain: `tactics.base` pack_flanker, with distances x1.25. Species overrides are in `raptor.json`.

- **Pounce, pin and bite** (RPR, "raptor prey restraint", how Deinonychus probably killed). It reuses canon's `tactics.pin` from SP-SMILODON with no new brain code.
  - A landed pounce pins a survivor, or a creature no bigger than itself. She lies in PINFEEL's pinned pose about 2.8 m in front.
  - The raptor stamps its right foot onto her and flaps its gold-feathered arms for balance.
  - It rears with the jaws wide and bites down twice, at 0.38 and 0.74 of the clip, x1.0 each, from the jaws. Then it lets go and leaps back.
- **Sickle slash** (`heavy`, now in `point_blank`, cd 6 s, x2.0).
  - Telegraph: it rocks onto the left leg with the right foot hauled high and the claw cocked, under the attack_heavy ring (the windup hold).
  - Then it drives the foot forward and down through the prey and rakes it back. The hit comes from the right foot (`BackFoot.R`).
- **Crest flare** (new sequence `flare_pounce`: display then pounce).
  - It stops, rears, throws the feathered arms wide and the tail up, and screeches with a head shake.
  - Then it pounces. The display lasts 1.6 s, so the owner can roll before the leap.
- **Kept from the deinonychus:** the three-bite combo, the charge into a bite, back-leaps, power strafes and the ambush from cover.
- **Hit parts.** Canon's `pipeline.hit_parts` / `Creature.part_hit`; claude/mmo-hitboxes has not landed on canon. Bites, pounce and pin bites hit from Head/Jaw; the slash hits from the right foot.
- **Reach.** New: a species `tactics.attack_range` override, read in `CreatureBrain.setup`, set to 2.9.
  - With pack_flanker's 2.0 the bite and slash were judged out of reach: they snapped air in front of her.
  - 2.9 follows the COELOMOVES rule: the snout reaches 2.97 m at the bite's hit frame.

## Colour morphs (palette system)
One mesh with five albedos, set in `pipeline.model_variants`:

| Morph | Hide | Feathers |
|---|---|---|
| `black_gold` | black (the GLB as authored) | gold |
| `black_crimson` (the feather morph) | black | crimson |
| `green` | olive | amber |
| `rust` | rust | cream |
| `slate` | blue-grey | ice-blue |

- `tools/gait/raptor_palettes.py` recolours the hide and the feathers separately and keeps the shading, so the scale and feather detail carry over. The mouth is left alone.
- Each wild spawn picks a morph from its identity (canon's `CreatureView.pick_variant`; equal odds, `# ASSUMPTION` RP4). Pets keep their morph.
- The lab's **Body** button now steps through texture morphs too (`variants_of`). The stegosaurus' graded/ochre looks show up there as well.
- Fix in shared code: `_apply_model_variant` used to put the hide texture on untextured surfaces too. Now the mouth bag keeps its gum red under any morph.
- There is no crest on/off variant: the crest is part of the Tripo mesh, so that would need a second mesh.
- Shot: `sp-raptor/colour_morphs.jpg`.

## Mount and spawns
- **Saddle.** Shared builder, `saddles.json` raptor row: no neck strap (the crest lets the rays out), seat over the hips.
- **New builder option `girth_frac`.** On a biped the girth under the seat took in both thighs and hooped down to the feet. It now sits halfway to the shoulders.
- **Spawns** (RP5): a pair (chance 0.7) on the far shore of `temperate_35` and `tropical_40`. Home climate tropical, tier 42, capture tier 4, pen taming with 4 feeds.
- **Also added:** a butchering row (raptor meat, bone, a black feathered hide, talon), natural speeds in `anim_events.json`, and a fight-lab table row.

## Shots (`docs/orchestration/reports/sp-raptor/`)
They come from off-screen windowed runs of the new `raptor_lab` (`--position 6000,3000`, quits by itself).
- `contact_sheet_side.jpg` and `contact_sheet_tq.jpg`: all 22 clips at 30 % and 60 %, with the survivor for scale.
- `signature_moves.jpg`:
  - the slash windup and its hit;
  - both pin bites;
  - the pounce;
  - the bite and the combo's third bite;
  - the crest flare.
- `colour_morphs.jpg`: the five morphs.
- `tripo_inputs.jpg`.

## Gates
Final numbers after the canon merge are in the commit that adds this report. The list below was green before the merge.
- `check_raptor.py --height 3.5` (adapted from check_smilodon): **RAPTOR_CHECK PASS** on all 22 clips. It checks:
  - stretch, with the gate at 13 because the deinonychus charge's elbow reads 12.8;
  - no sinking;
  - no moonwalk;
  - each hit part at least 1.2 m ahead at its hit frame;
  - the pin bites coming down.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `t_sp_raptor`: PASS. It covers:
  - the model, clips, bones, size and feet;
  - the parts at their hit frames;
  - the spawn rows, tameable with a saddle;
  - the slash hitting in front and missing beside the rump;
  - pounce, then pin, then two bites from the jaws, then release;
  - flare, then pounce;
  - the five morph textures, with the mouth keeping its colour.
- t_noboxes, t_combat, t_canim, t_data, t_mounts, t_saddles: PASS. The rest are listed in the final commit message.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command` once this is on canon.
2. Press SPAWN and pick **Raptor**, then press **Body** to choose a colour (Random, black_gold, black_crimson, green, rust, slate), then SPAWN. Or press NEXT (T) until the info line says Raptor; NEXT walks every morph.
3. Step back about 10 m. It flares its crest (arms wide, screech), then pounces. If the pounce lands you go down pinned under its foot while it bites twice. Roll (Q) out of the ring to dodge.
4. Stand close to see the sickle slash: the foot is cocked under the red ring, then slashes. Stand beside its rump and the slash misses. You also get the combo, the charge and the back-leaps.
5. GOD (G) keeps you alive and N enrages it. Tame it and ride it (it has a saddle). In the wild it spawns on temperate_35 and tropical_40 (far shore).

## Notes and open questions (RP1-RP6 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **Damage.** A landed slash (230 x 2.0) or pounce (x2.5) kills a fresh 100 HP survivor (RP2, balance pass).
- **Bites.** The deinonychus bites step in with a short hop: both feet are up to 0.18 m off the floor for a frame. The gate allows that for those two clips only.
- **Arms.** The arm feathers are part of the arm skin; there are no separate wing fans like the deinonychus'. The flapping and the display spread read small; separate fans would make them read.
- **Shared files touched:**
  - code: `creature_brain.gd` (species `attack_range`), `creature_view.gd` (an untextured surface keeps its colour), `lab_spawn_panel.gd` (texture morphs in Body);
  - data: `anim_events.json` (raptor rows only), `islands.json`, `butchering.json`, `saddles.json`;
  - tools: `build_saddles.py` (`girth_frac`).
- **New files:**
  - tools: `tools/gait/build_raptor.sh`, `make_raptor_moves.py`, `raptor_leg_weights.py`, `raptor_palettes.py`, `check_raptor.py`;
  - lab: `raptor_lab`;
  - test: `game/tests/t_sp_raptor.gd`.
