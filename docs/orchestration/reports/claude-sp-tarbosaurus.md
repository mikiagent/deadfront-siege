# SP-TARBOSAURUS: the tarbosaurus is a rigged, animated 3D tyrannosaur that stalks, bursts in, foot-pins, slashes and tail-whips

Branch `claude/mmo-sp-tarbosaurus`, from `origin/claude/mmo-overhaul` d915e67f (canon had not moved when I merged
before reporting). Pushed, not merged to canon. Owner's go: "build some of the models ... Be creative with what moves
you think they should do when they fight", then "keep cooking". Species id `tarbosaurus`; its data and spawn row
are kept.

## Credits
- **Tripo: 50** (one multiview, task `a969df84-2c34-4b51-b832-44af5a805aaa`, `credits_consumed` 50). No retry.
  - The shared balance read 2305 before and 2155 after (other agents were generating at the same time).
- Meshy 0, Higgsfield 0, no Tripo rig, animation or retexture. The back view came from Codex (free).

## Model
- **Views** (`game/assets/creatures/tarbosaurus/ref/`): the owner's sheet 2 side panel as the left view (the scale
  figure painted out), mirrored as the right; its front panel; a back view Codex drew from the sheet and the front view.
- **Mesh**: Tripo P1 multiview, texture + PBR, 15k faces. Rust-red/orange hide with maroon banding, cream belly, open
  jaws, long whip tail, no scutes. Tripo stood it square (both feet level), so the mirror only evens it out.
  - Tripo drew two claw "spikes" from the hands to the floor and left two claw tips floating ahead of the hands.
    `tools/gait/tarbo_clean.py` removes both.
- **Rig**: the T. rex's 30-bone rig fitted with MegaRex's `fit_rex_rig.py`. It gained `--joints <json>`, and the joints
  for this mesh are in `tools/gait/tarbosaurus_joints.json`, measured on ortho grid renders.
- **Jaw**: `add_jaw.py --open --weld`. The modelled gape is about 49 deg, and the jaw is bound closed 44 deg. Jaw keys
  are scaled 0.85, so the widest bite is about 45 deg. Checked at 0, 30 and 48 deg: no lip tearing.
- **Size**: `height_meters` 6.8 (kept from the data; the T. rex is 8.0). It is 19.4 m long on screen (TB1).
- `tools/gait/build_tarbosaurus.sh` rebuilds everything from `work/tarbo_tripo_v1.glb`. That folder is gitignored; the
  task id re-downloads the mesh.

## Clips (18, `anim/`), all by `make_rex_moves.py --tarbo` and `make_gait.py tools/gait/tarbosaurus.json`
- **Gaits**: walk, run, strafes and walk_back with a longer and quicker stride than the rex. Every clip uses the
  lower Durango carriage (head level with the back).
- **stalk**: a low crouched creep, 1.6 m stride over 2.2 s.
- **Signature moves (new)**:
  - **attack_primary, the slashing bite** (1.25 s, hit 0.42): it cocks its head right with the jaws wide, then whips
    the head across to the left as the body drives forward on a step. The jaws snap mid-sweep and the skull rolls
    through the rake.
  - **attack_heavy, crouch and lunge** (1.67 s, hit 0.72): it sinks and coils with the neck flat, the jaws gaping and
    the tail tip twitching. Then it explodes forward on a long step, clamps and wrenches twice.
  - **pounce, the burst** (1.0 s, airborne 0.2-0.65, clamp 0.7): one long low bound out of the crouch. The rear leg
    trails, the front reaches, it lands square and the jaws slam shut.
  - **kick, the tail whip** (1.6 s, hit 0.45): the rex tail whip, retimed so the tail crosses behind it on the hit
    frame. The tail drops through the windup so it sweeps at waist height instead of 5 m up.
  - **pin_foot**: the PINFEEL foot pin, starting from the lunge's strike pose.
- **From the MegaRex set, on this carriage**: idle, alert (the head dip is shallower so the chin clears the floor),
  hit_react, feed (a shorter reach), and knockdown, death and sleep lying on the belly.
  - The tail lies flat when it is down. On the first pass the long tail hung below the belly, so the settle stood the
    body on the tail tip.

## Moves and AI (TacticalBrain, its own `tactics` block in `tarbosaurus.json`: base saber_cat, scale 1.6)
- **Stalk**: out of burst range, it closes in on the `stalk` creep at 0.35x its walk.
- **Burst**: from 10-17 m it crouches and coils for 1.2 s under the ground ring (attack_heavy is the telegraph),
  then bounds in.
  - A landed burst is an attack_heavy hit. Under the PINFEEL rule that applies Pinned, and it plants its right foot
    on her (`pin_foot`) until Pinned runs out.
  - Sequences: burst; strafe then burst (either side); and run_down, a homing charge that ends in the bite.
- **Point blank**, in this order:
  1. the crouch-and-lunge clamp (heavy, which also pins);
  2. the tail whip when she is behind it (TacticalBrain's `kick` slot);
  3. the head-whip bite.
  - Backing off is a short scurry, not a leap.
- **Reach**: its jaws are about 8 m ahead of its centre, so the old centre reach (3.2 m) put her under its belly and
  every bite missed.
  - New `tactics.reach_m` (8.0): `TacticalBrain.contact_reach()` uses it when present, so species without it are
    unchanged.
  - With it, a burst lands with the jaws on her (`_land_short`).
- **Where hits land** (canon's `pipeline.hit_parts` / `Creature.part_hit`; claude/mmo-hitboxes has not landed on canon):
  - the bite, lunge and burst hit from Head and Jaw;
  - the whip hits from Tail4-7 with a 2.0 m radius, because the tail sweeps metres between two frames.
- No alpha skin, because no alpha sheet was given (TB6).

## Shots (`docs/orchestration/reports/sp-tarbosaurus/`)
These come from the new `tarbosaurus_lab` (off-screen windowed, `--position 6000,3000`, quits by itself). The survivor
stands ahead of its jaws for scale.
- `contact_sheet.jpg`: all 18 clips at 30 % and 60 %, side view.
- `hits.jpg`: the bite, lunge, burst, tail whip and pin at their hit frames, side and three-quarter.
- `pin/`: the live burst and pin on the survivor (`creature_lab --pinshots`, which now drives a TacticalBrain's burst).
- `pin_sheet.jpg`: the live burst windup under the ring, the plant, the hold from a wide camera and a low one, and the release.
- `sheet/`: every frame, as JPG.

## Gates
| Gate | Result |
|---|---|
| `tools/gait/check_tarbosaurus.py` (check_rex_clips on every clip: sink, float, slip, airborne outside the burst's window, ends, moonwalk; the lying clips rest on the floor) | REXCHECK PASS 18 clips |
| `tools/audit_gaits.py --gate` | GATE PASS |
| `game/tests/t_sp_tarbosaurus.gd` (new) | PASS. It checks: the model, all 18 clips, the bones, 6.8 m tall and 19.4 m long, a foot on the floor in every standing clip, each hit part placed right at its hit frame (the jaws 8.9-9.8 m ahead, the tail 6 m out behind), the spawn row and has_model, the fight-lab listing, the TacticalBrain with its tactics, the bite landing, the burst landing then Pinned then the pinned pose then the foot pin (`pin_foot`) then the release, the tail whip firing on a survivor behind it and landing from the tail, and the stalk approach slower than its walk |
| t_noboxes, t_combat, t_canim, t_data, t_labspawn, t_godlab, t_tactical, t_ai, t_pinfeel, t_alphas, t_eyeglow, t_sp_smilodon, t_rexclips | PASS |
| `run_all.gd` | [tests] PASS |
| `tools/smoke.sh --no-import` | SMOKE PASS |

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command`
   once this branch is on canon.
2. Press SPAWN, pick **Tarbosaurus** with count 1, then SPAWN. Or press NEXT (T) until the info line says Tarbosaurus.
3. Back off about 25 m. It creeps in low on the stalk. At 10-17 m it crouches and coils under the red ring, then
   bounds in. If the burst lands you go down Pinned under its foot. Roll (Q) out of the ring to dodge it.
4. Stand in front of its head to see the head-whip bite and the crouch-and-lunge. Walk behind its hips to get the
   tail whip. Stand under its belly and its jaws cannot reach you (TB3).
5. GOD (G) keeps you alive. N enrages it: shorter cooldowns and more bursts. In the wild it spawns on tundra_55
   (far_shore).

## Notes for the next agent / merge
- **Shared files touched**:
  - code: `tactical_brain.gd` (`contact_reach` with `reach_m`, `_land_short`), `creature_lab.gd` (pinshots for a
    TacticalBrain pinner);
  - data: `anim_events.json` (tarbosaurus natural speeds, pounce/kick notes; keep every other row),
    `tarbosaurus.json`;
  - docs: `biome-spawns.md`, `species-art.md`, and Open Questions TB1-TB6.
- **The rex tools came from the MegaRex branch** (`claude/mmo-sp-tyrannosaurus`, not on canon yet): `fit_rex_rig.py`,
  `make_rex_moves.py`, `check_rex_clips.py`, `tools/jaw/add_jaw.py`, copied byte for byte and then extended.
  - My additions: `--joints`, `--tarbo`, the `stalk` travel and the leap window in the checker.
  - Whichever of the two branches merges second will conflict in those four files. Take this branch's version: it is
    the MegaRex version plus additions, and without `--tarbo` or `--joints` it behaves exactly the same.
- **New tools**: `tools/gait/tarbo_clean.py`, `tarbosaurus_joints.json`, `tarbosaurus.json`, `build_tarbosaurus.sh`,
  `check_tarbosaurus.py`; lab `tarbosaurus_lab`; test `t_sp_tarbosaurus.gd`.
- **Damage** is the old stat block (attack 700): a fresh survivor dies to one burst. That needs a balance pass.

Report head: see the commit that adds this file on `claude/mmo-sp-tarbosaurus`.
