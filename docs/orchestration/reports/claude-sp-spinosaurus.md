# SP-SPINOSAURUS: a new species, the Spinosaurus

Branch `claude/mmo-sp-spinosaurus`, cut from `origin/claude/mmo-overhaul` (f1b05695), canon merged in again at d4825fdf. Pushed, not merged to canon.
Owner's go: "build some of the models ... Be creative with what moves you think they should do when they fight". Species id `spinosaurus` (new; it was "No model yet" in species-art).

## Credits
- **Tripo: 50.** One P1 multiview generation, task `a83eaa9c-8129-4dd0-8031-5dfce167a2c4` (`credits_consumed` 50). No retry.
  - Balance read 1905 before, 1805 after; other species agents share the account.
- Meshy 0, Higgsfield 0, no Tripo rig/animation/retexture. Codex CLI drew 3 images (free).

## Model
- **Views.** Codex drew a neutral standing left view from the owner's sheet (feet together, arms hanging, mouth slightly parted, sail as one membrane), then front and back from it; right = mirrored left. Inputs: `sp-spinosaurus/tripo_inputs.jpg`, copies in `game/assets/creatures/spinosaurus/ref/`.
- **Mesh.** Matches the sheet: long croc snout, dark green with orange bands, cream belly, hooked claws. **Tripo kept the sail whole**, so no separate Blender sail was needed: it is part of the body.
- **Rig.** Canon `rig_biped.py` with joints read off slices and ortho renders (`tools/gait/spinosaurus_rig.json`). New `tools/gait/sail_weights.py`: bone heat gave the sail crest noisy weights (and Thigh weight near the hips), which tore the crest 11-15x in the run; the sail now takes a smoothed blend of the spine chain under it (worst stretch 7.7, at the mouth corner).
- **Jaw.** `add_jaw.py --pivot 0.033 0.285 --split -14 --x-side`, then `open_mouth.py` (lips ripped, mouth bag). Gape capped at 30 deg.
- **Size** (SPN1): 21.6 m nose to tail, `height_meters` 9.0 (sail top), hips 4.9 m; `real_length_m` 28.
- **Rebuild everything:** `tools/gait/build_spinosaurus.sh` (~30 s). Gate: `Blender -b -P tools/gait/check_spino.py -- <glb> <anim> --height 9.0`.

## Clips (18)
Gaits from `make_gait.py` (`tools/gait/spinosaurus.json`): walk, run, **stalk** (low wading creep, snout level just off the ground), strafe_left/right, walk_back. The rest from the new `tools/gait/make_spino_moves.py` (make_cerato_moves machinery, feet IK-planted, lying clips on the floor), all through `ground_clip.py --fps 24`.

| clip | move |
|---|---|
| bite_shake | **snap-and-shake**: head drawn back, jaws gaping, claws raised (tell); low lunge and clamp (0.30); lifts her and thrashes three times; whips to its left and opens (release 0.78) |
| attack_heavy | **forearm claw rake**: rears up with both claws cocked (held to 0.6), drops forward off a step and rakes both claws down (hit 0.72); Bleed |
| attack_primary | **croc snap**: snout swings out with the jaws gaping and claws hooking, snaps shut across her (0.42) |
| alert | **sail-flare display / roar**: turns 65 deg broadside while the head stays on the threat, rears up, arms spread, then roars and shakes the head |
| kick | **tail swipe** behind it (0.45) |
| pounce | **water ambush lunge**: sunk low, flat surge with jaws wide and claws reaching (airborne 0.2-0.65, hit 0.7) |
| idle, hit_react, feed, knockdown, death, sleep | breathing and looking round; stagger; head down tearing with the claws pinning; topples on its side, sail down; belly-down sleep |

## Moves and AI (TacticalBrain, `tactics` block, base saber_cat, every number an ASSUMPTION)
- **Snap-and-shake (new, generic `tactics.grab`)** in `tactical_brain.gd`: point blank, in front, on a survivor or a creature no bigger than itself. Windup shows the ground ring on her. At the clip's hit frame the jaws must reach her (`hit_parts.bite_shake`); then she is held at the jaw point (no control) through the thrash, and flung off to its left at `release_frac` with lift (`grab_fling_m` 6, `grab_up_mps` 5). A miss snaps on air and leaves it open for the rest of the 2.5 s clip. Held prey is re-pinned in `_process` after the AnimationTree (the thrash moves the snout metres per frame). `bite_shake` added to `CreatureAnim.ONESHOT`; anim_events `bite_shake.release_frac` 0.78 (MegaRex ignores it; t_sp_megarex PASS).
- **Point blank** order `kick, heavy, grab, stomp, bite`: tail swipe behind; claw rake if she is within 8 m (under its chest; the claws are short), x1.4, Bleed x2 (`status_clips`), shoves her 3 m (`heavy_shove_m`); snap-and-shake; croc snap.
- **Range 11-17 m** sequences: lunge, strafe into lunge (both sides), sail-flare display into a charge.
- **Water**: the ceratosaurus' water-edge lurk (bank within 45 m of home), ambush lunge inside 12 m (18 m on a turned back); approaches on the stalk creep. No water near home (the lab): it hunts in the open.
- **Heavy-species rules**: `w_hop` 0, `w_dodge` 0, scurry back-off: it strafes and arcs, never hops.
- **Pins**: none. The only hold is the visible clamp in the jaws.
- **Knockdown tiers**: claude/mmo-knockdown is not on canon. The rake shove and the fling (shove with lift) use `PlayerSim.shove`, the call PlayerKnock hooks, so they become knockdown / throw tiers when it lands, with no spino change.
- **Big stomp hook**: `big_stomp: true` and `"stomp"` in point_blank. TacticalBrain ignores the unknown move today, so it costs nothing until claude/mmo-bigstomp reads it.
- Spawns: far shore (coast) of swamp_55 (1) and tropical_40 (1, 50 %). The lab SPAWN list picks it up automatically.

## How to test (god mode)
1. `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate` (or `tools/fight_lab.command` once on canon). GOD (G) on.
2. SPAWN -> **Spinosaurus**, count 1, nature Aggressive, SPAWN (NEXT/T cycles to it too).
3. Stand ~9 m off its snout: the jaws gape with a ring under you, then it clamps, lifts and shakes you and throws you to its left. Roll (Q) out of the ring to dodge.
4. Walk in under its chest (<8 m): it rears with the claws cocked, then rakes down (you bleed, get shoved). Behind its hips: tail swipe. At 11-17 m: the low lunge, or it turns broadside, flares the sail and roars, then charges.
5. In the wild (swamp_55 / tropical_40 far shore) it lurks on a bank and lunges when you come within 12 m. N enrages it.

## Shots (`docs/orchestration/reports/sp-spinosaurus/`, off-screen windowed `spino_lab`, self-quitting)
- `contact_sheet.jpg`: all 18 clips at 30 % and 60 %, side view, with the survivor for scale.
- `hits.jpg`: snap, rake, clamp, mid-thrash, release, tail swipe, lunge and the display at their key frames.
- `live_snap_shake_rake.jpg`: a live TacticalBrain fight showing the windup ring, clamp, held 5.6 m up mid-thrash, fling, landing 13 m out, and the rake windup and hit.
- `live_sail_flare.jpg`: the sail-flare display from her side.
- `tripo_inputs.jpg`: the four Tripo views.
- Run: `Godot --path game --position 6000,3000 -- --skip-charcreate --lab=spino_lab --out=DIR [--live]`.
- **Read wrong, fixed:**
  - crest tearing (sail weights);
  - the sail riding the thighs;
  - the tail swipe drooping into the ground: ground_clip lifted the whole animal 3 m. check_spino now fails a standing clip whose feet leave the floor;
  - the feed's tail digging in;
  - the alert seen edge-on: 38 to 65 deg broadside;
  - the rake's claws digging in;
  - the grab judged against a wall clock 0.15 s ahead of the cross-faded pose (it now reads the tree's clip time).
- **Lab-only oddity**: in the rake/display frames the spino is tinted red. That is the player's tackle-target highlight, not the model.

## Gates (after merging canon d4825fdf)
- `check_spino.py --height 9.0`: **SPINO_CHECK PASS** on all 18 clips. It checks:
  - stretch, sinking, feet on the floor, moonwalk, glide;
  - snout and claws at the hit at or below 2.6 m and driving forward;
  - the rake comes down at 16.7 m/s;
  - the shake is fast;
  - the tail swipe speed.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `t_sp_spinosaurus`: **PASS**. It checks:
  - the model, clips, bones, height and length;
  - feet in 12 standing clips;
  - the parts are ahead at each hit;
  - the spawn rows and the lab list;
  - in live fights: the snap; the rake (from the claws, Bleed, shove); the grab (clamp, lifted 5.7 m, held between the jaws, flung 4.2 m, lands); the tail swipe; the sail-flare into a charge; the water ambush lunge;
  - the stomp hook and no hop/dodge.
- t_noboxes, t_combat, t_canim, t_data, t_ai, t_tactical, t_labspawn, t_boneparts, t_sp_megarex, t_sp_ceratosaurus, t_sp_therizinosaurus, t_sp_tarbosaurus, t_sp_smilodon: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- No duplicate `func`/`var` names in any .gd after the merge. Merge conflicts resolved, keeping both sides:
  - MOVES got canon's `bound` plus `grab`;
  - ONESHOT/ATTACKS got canon's stomp/shove/tackle plus `bite_shake`;
  - the attack_heavy notes kept therizinosaurus and spinosaurus.

## For the next agent
- **Shared files touched:**
  - `tactical_brain.gd`: the `grab` move, about 120 additive lines;
  - `creature_anim.gd`: `bite_shake` in ONESHOT;
  - `anim_events.json`: `bite_shake.release_frac`, two notes, the `natural_speeds.spinosaurus` row (walk 4.65, run 14.35 m/s);
  - `islands.json`: 2 rows.
- **Not done:**
  - no alpha skin (no alpha sheet);
  - no saddle;
  - no butchering/ragdoll row;
  - `docs/current/biome-spawns.md` and `species-art.md` not regenerated (generated docs).
- **Known limits:**
  - it lurks on the bank, it does not wade or submerge (SPN4);
  - the sail does not flare by itself (SPN5);
  - a fresh survivor dies to one snap or rake (SPN2, balance).
- Open questions SPN1-SPN7 in `docs/vision/WildLandsMMO_Open_Questions.md`.
