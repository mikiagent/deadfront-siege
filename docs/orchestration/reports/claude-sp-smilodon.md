# SP-SMILODON: the smilodon is a rigged, animated 3D cat that stalks, pounces, pins and stabs

Branch `claude/mmo-sp-smilodon`, from `origin/claude/mmo-overhaul`, with canon merged in at afa2e7c9 (after SP-WOOLLY_RHINO,
SP-MEGALOCEROS, PINFEEL, COMPYFEEL). Pushed, not merged to canon.
Owner's go: "build some of the models ... Be creative with what moves you think they should do when they fight", then
"keep cooking". Species id `smilodon`; the existing data and spawn rows are kept.

## Credits
- **Tripo: 50** (one multiview, task `aad4a28f-718f-4e91-ad56-27300a8e3246`, `credits_consumed` 50). No retry.
  - The shared balance read 2505 before and 2355 after. Other species agents were generating at the same time.
- Meshy 0, Higgsfield 0, no Tripo rig, animation or retexture. Codex images are free.

## Model
- **Views.** The owner's sheet 1 (white/grey tiger stripes, dark mane, glowing blue eyes, ivory sabres) shows a mid-stride side view and no back view.
  - Codex drew a neutral standing left view from it, then a front view (redrawn once to hide the tail, which stuck out to one side) and a back view.
  - The right view is the left one mirrored. All four are on a common scale.
  - Inputs are in `game/assets/creatures/smilodon/ref/`, with both owner sheets.
- **Mesh.** Tripo P1 multiview with texture and PBR, 1.0 x 0.28 x 0.57 units, facing +X. It matches the sheet: mane, stripes, black tail tip, sabres and blue eyes.
- **Rig** (`tools/gait/build_smilodon.sh` rebuilds everything from `work/smilodon_tripo_v1.glb`):
  1. `transplant_rig.py` with the Triceratops donor. Its knockdown and death are kept.
  2. New `tools/gait/smilodon_rig.py` gives it digitigrade cat legs.
     - Hip/shoulder -> knee/elbow -> hock/wrist, and the Foot bone runs from the hock/wrist to the toe tips.
     - The donor's hind knee had been 6 cm in the air in front of the thigh.
     - Leg skin is re-weighted by position: the haunch and shoulder swing with the leg, and the paw is rigid on Foot.
     - Fixed along the way: a vertex-group removal bug had left tail weights on the paws, which then sank in the stalk.
  3. `add_jaw.py` with the pivot set by hand, then new `smilodon_sabres.py`.
     - The sabres hang below the lip line, so add_jaw gave them to the jaw. They are now rigid on the skull.
  4. Eyes block: glowing pale blue eyeshine on the painted eyes.
- **Size** (`# ASSUMPTION`, SM1): `height_meters` 2.0 (top of the mane; shoulder about 1.6 m, 3.5 m long). `real_length_m` 2.5 -> 4.4 (the 2x convention).

## Clips (17), all in `anim/`
- **Gaits** (`make_gait.py` + `tools/gait/smilodon.json`): walk (lateral cat walk), run (rotary gallop with a flight phase), stalk, strafe_left/right, walk_back.
  - The first gaits dragged the toes forward through the swing (the paw curl pointed them at the floor). Lift and curl were retuned, and the toes now clear about 18 cm.
- **Moves** (new `tools/gait/make_cat_moves.py`, keyed from rest, IK feet, per-paw and body floor passes):
  - attack_primary (forepaw swipe)
  - attack_heavy (pounce windup and sabre lunge)
  - pounce
  - pin_stab
  - alert (roar with a head shake)
  - idle, hit_react, feed
  - sleep (lies on its belly, tail curled)
- Knockdown and death are the donor's roll onto the side.

## Signature moves and AI (saber_cat tactics in `ai.json`; the smilodon is the only saber_cat)
- **Stalk.** Out of pounce range, it approaches on the low `stalk` creep at 0.25 x walk (about 1.2 m/s).
  - New `tactics.stalk`; TacticalBrain sets `gait_clip` while approaching.
- **Pounce-and-pin.**
  - From 4 to 9 m, attack_heavy is the telegraph: a flat crouch, a rump wiggle and the jaws gaping, under the ground ring for 1.0 s.
  - Then the pounce leaps and slams both forepaws down. The sabres hit at 0.7.
  - A landed pounce PINS the prey: a survivor, or a creature no bigger than itself.
    - The prey gets Pinned and lies down in PINFEEL's pinned pose.
    - It is held 1.5 m in front of the chest while `pin_stab` drives the sabres in twice (x1.2 each).
  - It lets go when the clip ends, when a struggle clears Pinned, or when either animal dies.
  - Code: `TacticalBrain._start_pin/_pin/_end_pin`, `tactics.pin`.
- **Point blank.** It uses the forepaw swipe (`bite` -> attack_primary) or the sabre lunge (`heavy` -> attack_heavy).
- **Sequences.** pounce; strafe -> pounce; backstep -> pounce; charge (a run into a swipe).
- **Where hits land.** Every hit lands from the body part, using canon's `pipeline.hit_parts` / `Creature.part_hit` from SP-WOOLLY_RHINO; the hitbox system has not landed yet.
  - The swipe lands from FrontFoot.R; the lunge, the pounce and the pin stabs from Head (the sabres).
  - The pounce landing checks the part too.
  - t_sp_smilodon proves it: a survivor beside the rump is inside the old centre reach, and the swipe now misses her.
- **Alpha.** Alphas (the Alpha tag in the lab, or a genetics roll) wear the brown-maned sheet 2 skin.
  - The skin is `smilodon_alpha_albedo.jpg`, a recolour of the regular albedo made by `smilodon_alpha_skin.py`.
  - It is wired through canon's `model_variants.alpha`. Shots are in `sp-smilodon/alpha_sheet.jpg`.
- **Saddle.** Built with the shared saddle builder (it has `tamed_role` mount). The builder gained two options:
  - `neck_strap: false`, because the mane let the section rays out and drew a hoop over the head;
  - `body_half_w`.

## Shots (`docs/orchestration/reports/sp-smilodon/`)
- They come from off-screen windowed runs of the new `smilodon_lab` (`--position 6000,3000`, quits by itself).
- `contact_sheet.jpg`: all 17 clips at 30 % and 60 %, with the survivor for scale.
- `hits.png`: the swipe, lunge, pounce and both pin stabs at their hit frames, side and three-quarter views.
- `alpha_sheet.jpg`: the alpha skin.
- Full frames are in `sheet/` and `alpha/`.

## Gates (after the canon merge)
- `check_smilodon.py --height 2.0`: **SMILODON_CHECK PASS**. It covers every clip:
  - worst stretch 10.9 (gate 12, at the mouth corner; the jaw gape is capped at 48 deg for this);
  - no sinking (worst -0.017 m);
  - no moonwalk, measured on the paw contact patch;
  - each hit part 1.5-1.8 m ahead at its hit frame, with the sabres 0.6-0.8 m down.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `t_sp_smilodon`: PASS. It covers:
  - model, clips, bones, size and toes on the floor;
  - part hits ahead at their hit frames;
  - spawn rows on tundra islands, with nothing falling through any more;
  - the swipe from the paw, and its miss at the rump;
  - pounce -> pin -> pinned pose -> two stabs -> release;
  - the stalk approach;
  - the alpha skin.
- t_noboxes, t_combat, t_canim, t_data, t_mounts, t_saddles, t_tactical, t_ai, t_labspawn, t_pinfeel, t_sp_woolly_rhino, t_boneparts, t_tame: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command` once this is on canon.
2. Press SPAWN and pick **Smilodon** with count 1 (Alpha on for the brown alpha), then SPAWN. Or press NEXT (T) until the info line says Smilodon.
3. Step back about 15 m and wait. It creeps in on the stalk, crouches and wiggles under the red ring, then pounces. If it lands, you go down pinned while it stabs twice. Roll (Q) out of the ring to dodge the pounce.
4. Stand close to see the swipe and the sabre lunge. Strafe beside its rump to watch the swipe miss.
5. GOD (G) keeps you alive. Press N to enrage it (shorter cooldowns, more pounces). In the wild it spawns on tundra_30 and tundra_55 (crater, far_shore, working rings).

## Notes and open questions (SM1-SM6 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **Size.** The owner's sheet draws it about twice the survivor's shoulder height. I kept the house 1.6x (SM1).
- **Damage.** A fresh 100 HP survivor dies to the pounce alone (attack 360 x 1.6). That is the old stat block and needs a balance pass (SM4).
- **Alpha.**
  - The alpha is a recolour, so it has the same mane shape.
  - Its eyeshine stays blue; the sheet's alpha eyes are amber (SM5).
- **Clips.**
  - There is no hop_back clip, so the back-off leap plays the attack_heavy timed arc. The stalk is used only for the approach, not for circling.
  - The gallop's back flex is mild.
  - Knockdown and death are the donor's side roll.
- **Shared files touched:**
  - code: `creature.gd` (rolled-alpha skin), `tactical_brain.gd` (stalk, pin, pounce part check), `creature_anim.gd`, `creature_clips.gd`, `rigged_model.gd`, `creature_brain.gd` (`pin` combat state), `lab_spawn_panel.gd`;
  - data: `ai.json`, `anim_events.json` (smilodon rows spliced), `saddles.json`;
  - tools: `build_saddles.py` (the two new options).
- **New tools:** `tools/gait/smilodon_rig.py`, `smilodon_sabres.py`, `make_cat_moves.py`, `smilodon_alpha_skin.py`, `check_smilodon.py`, `build_smilodon.sh`; lab `smilodon_lab`.

Report head: see the commit that adds this file on `claude/mmo-sp-smilodon`.
