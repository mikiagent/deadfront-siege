# SP-DEINONYCHUS: the deinonychus rebuilt from the owner's turnaround sheet (v4)

Branch `claude/mmo-sp-deinonychus`, from `origin/claude/mmo-overhaul`, with canon merged in twice (last: sp-gallimimus and
compyrevert, 91010e7f). Pushed, not merged to canon. Species id `deinonychus`, unchanged.

What the owner said:
- On the sheet (filed as "Feathered Utahraptor Turnaround Sheet"): "this is deinonychus, fix".
- "dude turn this into a new deinonychus model. The current one is messed up".
- Raptor-type species should use their arms in attacks.

## Credits
- **Tripo: 50.** One multiview, task `18b9c322-1d35-48ed-beec-632399315f00`, no retry. Balance 1755 before, 1705 after.
- Meshy 0, Higgsfield 0, no Tripo rig, animation or retexture. Codex images are free.

## Model
- **Views** (`sp-deinonychus/tripo_inputs.jpg`, `game/assets/creatures/deinonychus/ref/`):
  - Codex drew a clean left side view from the owner's sheet. The wings are folded high on the flank with the tips above the knee, because the sheet's hanging wings had built a second pair of legs on v2. The mouth is parted.
  - Codex then drew the front and back views from that side view.
  - The right view is the left mirrored. All four are scaled to one body height on the ground line.
- **Mesh** (`sp-deinonychus/tripo_mesh_views.jpg`): Tripo P1 multiview with texture and PBR. It matches the sheet:
  - brown mottled feathers with a cream belly, throat and face stripe, and orange eyes;
  - an open toothed jaw;
  - dark barred wings folded on the flanks;
  - a wide horizontal tail fan;
  - big sickle claws.
  Tripo kept the thin parts, so nothing had to be rebuilt in Blender. The wings came out as their own shells, which made them easy to skin.
- **Rig** (`tools/gait/build_deinonychus.sh` rebuilds everything from `work/deinonychus_tripo_v4.glb`, which is gitignored; the task id re-downloads it):
  1. `transplant_rig.py` with the Quaternius Velociraptor donor. This is the same skeleton as the Raptor and the old deinonychus.
  2. `add_jaw.py` and `open_mouth.py` give it a **real Jaw bone**, cut lips and a mouth bag. `raptor_leg_weights.py` makes the thigh follow the leg.
  3. **New `deino_wing_weights.py`.** The transplant had given the wing shells torso and thigh weights, so the arms moved 54 vertices. Now each wing goes to its arm, FrontUpLeg at the shoulder blending to FrontLowLeg at the tip, so every arm swing swings the wing. Vertices the transplant left unweighted copy their nearest neighbour; they had torn the tail fan 60-130x.
  4. **New `add_claw_tips.py`.** It adds `ClawTip.L/R` as non-deforming markers. The hands are folded inside the wings on this mesh, so the markers sit at the hand bones' ends.
- **Size** (DN1): `height_meters` stays 2.87 and the data is kept. The v4 body is 6.0 m long on screen with its fan; v3 was 4.8 m.
- **Old texture files** from v3 were removed. `sheet.png` is now the owner's sheet.

## Clips (21)
- **Kept from v3:** the 3-hit chomp combo, the pounce, leap_back, hop_back, the dodges, idle, hit_react, knockdown and death. All are moved onto the new rig with `transfer_clips.py`.
  - The v3 rig and its clips are kept in `work/v3/` as the source.
  - `build_raptor.sh` and `build_utah_arms.sh` now point there.
- **Arms:** `raptor_overlay.py` runs on every attack and leap.
  - The arms, and the wings with them, reach out with the claws spread, then rake down on each bite and each chomp. They flare in the pounce and the leaps.
  - The gate checks that each arm swings 62-106 deg in every attack.
- **Gaits:** `make_gait.py` on `tools/gait/deinonychus.json`, which is the Raptor's gaits. Walk, run, charge, walk_back and the strafes.
- **New:**
  - `attack_heavy` is the sickle slash.
  - `alert` is a wing-and-fan display: it rears, spreads the wings, raises the fan and screeches.
  - `sleep`.
  - `feed` comes from the velociraptor.
- `ground_clip.py` runs on sleep, knockdown and death. The v3 fall had put a foot 10 cm under the floor.

## Moves and AI
- **Kept exactly:** the pack_flanker profile. That covers the sequences, the ring, the ambush, the 3-hit chomp combo, the pounce and the leap-backs. The data, spawns, taming and mount are unchanged.
- **Added (DN2):**
  - The **sickle slash** at point blank (`heavy`, cd 7 s, x1.8, from `BackFoot.R`). The foot is cocked under the windup ring before the slash.
  - `attack_range` 2.6, because the snout is 2.7 m ahead at the bite. With pack_flanker's 2.0 the bites snapped short.
- **No pounce pin.** I tried the Raptor's pin, where a landed pounce holds the prey and bites twice.
  - Every landed pounce became a 2.4 s hold, and the pack fight lost its repositioning (t_tactical). That held even with a 20 s cooldown.
  - The pin stays the Raptor's move. I removed the pin_stab clip.
- **Hop/strafe:** HOPSTRAFE is on canon, and the deinonychus stays "mixed" (bulk 17.2), so its strafe is kept. The strafe now takes about 1.3 m steps (stride 0.21, 0.79 s cycle; the Raptor's is 0.97 m), so it no longer reads as twinkle toes. `natural_speeds` is baked to match.
- **Hitboxes** (`hitboxes.json` deinonychus, DN3):
  - The bite, the combo and the pounce strike from the Jaw, the Head and **ClawTip.L/R**. The slash strikes from the right foot. The charge strikes from the jaws.
  - Calibrated rows from `t_hitboxes.gd -- --calibrate`:
    - Jaw 0.69 (bite), 0.82 (combo);
    - ClawTip.L/R 0.83/0.74 (bite), 0.97 (pounce);
    - BackFoot.R_end 0.32 (slash).
  - The clip imports keep constant tracks, so a seeked clip poses every bone and the baked jaw sweep matches the live jaw.

## Colour morph hook (DN5)
`pipeline.model_variants` = `{"brown": ""}`, the GLB as authored. The red-orange body with blue wings needs the owner's screenshot. When it arrives:
1. Make the albedo the way `tools/gait/raptor_palettes.py` does for the Raptor, recolouring the body and the feathers separately.
2. Add `"red_blue": "deinonychus_red_blue_albedo.jpg"`.

Wild spawns and the lab's Body button then pick it up.

## Other shared edits
- `docs/current/species-art.md`: the sheet moved from the utahraptor's section to a new Deinonychus section (`docs/art/species/deinonychus/`). The utahraptor model is untouched.
- `ragdoll.json` deinonychus:
  - The hip-socket capsules are thinner; the v4 hip sockets sit 1 m apart and propped the carcass.
  - The wing and fan capsules are wider; their skin had pushed the corpse up in the conform.
  - `lie_frac` 0.62 (DN6). It settles at 47-57 % of the standing hips height.
- Saddle rebuilt: `saddles.json` deinonychus row with the Raptor's biped settings.
- Eye-glow points refitted to the orange eye texels.
- `t_tactical.gd`: the direct pounce-damage check now resets the body's leap arc. The fight it interrupts left the body mid-air, 2.2 m up.
- New files: `deinonychus_lab` (review shots), `check_deinonychus.py`, `t_sp_deinonychus.gd`.

## Shots (`docs/orchestration/reports/sp-deinonychus/`)
These come from off-screen windowed runs of `--lab=deinonychus_lab` (`--position 6000,3000`, quits by itself).
- `contact_sheet_side.jpg` and `contact_sheet_tq.jpg`: all 21 clips at 30 % and 60 %, with the survivor for scale.
- `hits_side.jpg` and `hits_tq.jpg`:
  - the bite;
  - the three chomps;
  - the slash windup and its hit;
  - the pounce;
  - the display.
- `close_hits.jpg`: the arm strikes up close.
- `tripo_inputs.jpg` and `tripo_mesh_views.jpg`.

What read wrong, and what happened:
- **Fixed:**
  - wings that did not move (wing weights);
  - the torn tail fan (unweighted vertices);
  - a foot under the floor in death and knockdown;
  - a strafe that floated (duty 0.62).
- **Left as is:**
  - In the sickle slash, the raised thigh's cream feathers spread into a pale sheet. Moving the thigh weights broke the stretch gate on other clips (20x).
  - Death and knockdown are the v3 roll onto the side, so the fan stands up vertical.

## Gates (after the last canon merge)
- `Blender -b -P tools/gait/check_deinonychus.py -- deinonychus.glb anim --height 2.87`: **DEINONYCHUS_CHECK PASS** on 21 clips. It checks stretch, sinking, floating, moonwalk, the hit parts ahead at the hit frames, and the arms in every attack.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `t_sp_deinonychus`: **PASS**. It covers:
  - the GLB with no boxes, all clips, the Jaw and ClawTip bones, 2.87 m tall and 6.0 m long;
  - the feet on the floor;
  - the hit parts ahead, and the claws reaching forward in the bite, the combo and the pounce;
  - the slash landing in front through the hitboxes and missing beside the rump;
  - the pounce landing once, with no pin;
  - the combo's 3 chomps, the pounce and leap_back all kept;
  - the strafe mix, with steps of 1.1 m or more;
  - the Jaw and ClawTip hitbox rows, calibrated;
  - the morph hook;
  - the 10 spawn rows, tameable with a saddle.
- PASS: t_noboxes, t_combat, t_canim, t_data, t_hitboxes, t_tactical, t_hopstrafe, t_eyeglow, t_eyetrails, t_raptorfeel, t_raptorflank, t_mounts, t_saddles, t_dismount, t_boneparts, t_labspawn, t_godlab, t_coelomoves, t_compyfeel, t_bigreach, t_ai, t_sp_raptor.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: **SMOKE PASS**.
- **Failing on canon as well** (checked in a clean canon worktree at the same head):
  - t_ragdoll, on the velociraptor slope death only. Every deinonychus check in it passes.
  - t_turnrate, on the T. rex side bite.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command` once this is on canon.
2. Press SPAWN, pick **Deinonychus**, then SPAWN again (or press NEXT (T) until the info line says Deinonychus).
3. Step back about 10 m. It circles, strafes with long steps, back-leaps, and pounces with its wings flared and the claws raking.
4. Stand close. You get the 3-chomp combo with alternating arm rakes, and the sickle slash: the foot is cocked under the red ring, then slashes. Roll (Q) out of the ring.
5. GOD (G) keeps you alive and N enrages it. Press H for the hitbox debug draw: the jaw and claw spheres show on each hit. In the wild it spawns on temperate_25/35/45, tropical_25/40, savannah_45 and swamp_55. You can tame and ride it.

## For the next agent
- Colour morph: see the hook above.
- `tools/gait/add_claw_tips.py` and `deino_wing_weights.py` work on any Velociraptor-donor transplant with shell wings.
- Assumptions DN1-DN6 are in `docs/vision/WildLandsMMO_Open_Questions.md`.
