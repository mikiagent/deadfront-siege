# SP-ALLOSAURUS: the allosaurus is a rigged, animated 3D theropod with a hatchet bite, a grab-and-bite pin and a shoulder ram

Branch `claude/mmo-sp-allosaurus`, from `origin/claude/mmo-overhaul`, with canon merged back in (8082c43b, SP-TARBOSAURUS). Pushed, not merged to canon.
The owner confirmed the species ("yes allosaurus"). Species id `allosaurus`: the existing data and both spawn rows are kept.
It used to have no model, so its spawns fell through to deinonychus and gallimimus, and it ran the raptor pack brain.

## Credits
- **Tripo: 50.** One P1 multiview, task `d5b0362a-ca5a-46f2-9736-8d5c0efeaa73`, `credits_consumed` 50. No retry used.
  - The shared balance read 2055 before and 2005 after.
- Meshy 0, Higgsfield 0. No Tripo rig, animation or retexture. Codex images are free.

## Model
- **Views.** The owner's sheet draws the arms raised and forward, low enough to read as extra legs.
  - Codex drew a neutral standing left view from it, with the arms folded tight against the chest, both feet together, the mouth parted and the tail level.
  - Codex then drew the front and back views from that left view. The right view is the left one mirrored.
  - All four views are on one scale and one ground line.
  - They are in `game/assets/creatures/allosaurus/ref/`, beside the owner sheet. The strip is `sp-allosaurus/tripo_inputs.jpg`.
- **Mesh.** Tripo P1 with texture and PBR. It is 1.0 x 0.23 x 0.455 units and matches the sheet: olive streaks, cream belly, black tail bands, orange eye patch and crest.
- **Rig.** `tools/gait/rig_biped.py` (PACHY's hand-placed biped) with the new `tools/gait/allosaurus_rig.json`.
  - The joints were read off ortho grid renders of the mesh.
  - The ankle is at the hock and the ball is at the heel, so the whole sole is the Toe bone.
  - New spec key `foot_level`: the Tripo right foot stood 5.6 cm (game scale) above the left. It is lowered onto the floor, fading out over the shin.
- **Jaw.** `add_jaw.py --open --x-side`. The mesh came with the mouth open. It is closed in the bind pose, and +X opens it.
  - I took carno's `--x-side` flag, the same lines as on its branch. Canon's automatic roll from tarbo is kept beside it.
- **Size** (`# ASSUMPTION`, AL1): `height_meters` 6.5, 14.3 m long. That is 9 m real x the house 1.6. `real_length_m` 18 is kept.
- **Rebuild.** `tools/gait/build_allosaurus.sh` rebuilds everything from `work/allosaurus_tripo_v1.glb`, which is gitignored. The task id re-downloads it.

## Clips (16), all in `anim/`
- **Gaits** (`make_gait.py` + `tools/gait/allosaurus.json`): walk, run, strafe_left/right and walk_back.
  - Speeds are tuned to the game's move speed: walk 2.6 m/s, run 5.9 m/s against the stats' 5.2.
  - The `natural_speeds.allosaurus` row is written from them.
- **Moves.** The new `tools/gait/make_allo_moves.py` is PACHY's poser. The feet are IK-planted, and the lying clips rest on the floor.
  - **attack_primary**, the snap bite: the head draws back, a step in, the jaws dart down to survivor height and shut at 0.42, then a tug.
  - **attack_heavy**, the HATCHET bite:
    - It rears back with the jaws gaping 48 deg. This is held to 0.6, under the ground ring: the telegraph.
    - Then it chops the open upper jaw down like an axe with a step in, and drags back tearing.
    - The hit is at 0.72. The skull comes down from 5.5 m to 2.7 m.
  - **grab_bite** (new clip name): it lunges low and the three-fingered hands reach out and clamp at 0.3. Two downward bites follow at 0.55 and 0.8.
  - **kick** = the SHOULDER RAM: a crouch and a wind to the left, then the right shoulder drives forward and out with a step. The hit is at 0.45.
  - **alert**: a roar, head up then thrust forward with the jaws wide, shaking.
  - **idle, hit_react, feed** (tearing at a carcass), **sleep**.
  - **knockdown, death**: it falls on its side with the legs stretched out stiff. Folded, they had stuck up like a bundle.

## Moves and AI (species `tactics` in `allosaurus.json`, through canon's per-species hook)
The base is `pack_flanker` (the deinonychus brain) x1.8 for a 14 m animal. It now runs the TacticalBrain instead of RaptorPackBrain.
- **Pairs.** Both spawn rows now spawn 2 (`count` 1 -> 2). The pair runs `surround`, so the two hold ring slots on opposite sides of the prey.
- **Opening.** There is no ambush, pounce or leap: it is a 3 t animal. It opens with run-in bites (charge), sometimes after a strafe or a roar.
- **Point blank, in this order:**
  1. **Shoulder ram** (`kick`). It fires when the prey is pressed in under its chin (within 4 m, `kick_max_m`) or behind it. It shoves her 4 m (`kick_shove_m`).
  2. **Grab.** In front at jaw range, on prey it can hold (a survivor, or a creature no bigger than itself), it plays `grab_bite`.
     - If the hands' clamp lands (x0.5), she is **Pinned**. PINFEEL lays her down, and she is held 6.3 m ahead.
     - Both bites land on her (x1.3 each), then it lets go.
     - A missed clamp is just a miss.
  3. **Hatchet bite** (`heavy`, x1.8, 8 s cooldown). It is **the only hit that applies Bleed** (`deep_bleed`, via the new `tactics.statuses_heavy_only`). Fracture was dropped (AL2).
  4. **Snap bite.**
- **Where hits land.** Every hit lands from its part, through canon's `pipeline.hit_parts` / `Creature.part_hit`. claude/mmo-hitboxes is not on canon.
  - The bites and the hatchet land from Jaw/Head, the grab from the hands, and the ram from Chest/Arm.R.
  - Reach is canon's `tactics.reach_m`, set to 7.0: the jaws are about 7 m ahead of its centre at the bite.
- **Feet planted.** Every clip plays in place; the no-glide rule holds. The gate checks that a planted toe never slides more than 10 cm and that the left foot never leaves the floor in a one-shot.
- **Code** (small, additive):
  - `TacticalBrain`:
    - `grab` move and `_grab()`;
    - `landed()` hook: the grab pin, plus `kick_shove_m` / `heavy_shove_m`. It is the same hook carno added;
    - `_pinnable()` and `_hold_victim()`, split out of the smilodon pin, with `_pin_clip`;
    - `kick_max_m`;
    - grab_bite damage mults.
  - `Creature._on_hit` calls `landed`.
  - `CreatureAttack`: `statuses_heavy_only`.
  - `grab_bite` was added to the ONESHOT/ATTACKS/OPTIONAL/FIGHT_CLIPS lists.
  - anim_events: a `grab_bite` row and a `natural_speeds.allosaurus` row.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`, or `tools/fight_lab.command` once this is on canon.
2. Press SPAWN, pick **Allosaurus**, Aggressive, count 1, then SPAWN. Or press NEXT (T) until the info line says allosaurus. Count 2 shows the pair surrounding you.
3. Stand off about 15 m. It roars or strafes, then runs in to bite.
4. Stand in front of its head, about 6 m out:
   - **Hatchet**: it rears with the jaws gaping under the red ring. Roll (Q) out, or take the chop and you Bleed.
   - **Grab**: it lunges and the hands reach out. You go down pinned and get bitten twice.
5. Walk in under its chin (within about 4 m): the **shoulder ram** throws you back about 4 m. GOD (G) keeps you alive, and F3 prints each move.

In the wild, pairs spawn on tropical_40 (far shore, 30 % chance) and desert_50 (far shore).

## Shots (`docs/orchestration/reports/sp-allosaurus/`)
They come from self-quitting off-screen windowed runs of the new `allosaurus_lab` (`--position 6000,3000 -- --skip-charcreate --lab=allosaurus_lab --out=DIR`). The survivor stands where the jaws land.
- `contact_sheet.jpg`: all 16 clips at 30 % and 60 %, side view.
- `hits.jpg`: the snap bite, the hatchet's held gape (50 %, the telegraph; the caption says HIT) and its chop (72 %), the grab clamp and both bites, and the ram.
- `sheet/`: every frame from both cameras.
- `tripo_inputs.jpg`: the four Tripo views.

What read wrong and was fixed:
- the jaw opening the wrong way (`--x-side`);
- the tail flicking 40 deg up in the rear (tail offsets compound down the chain; cut to a quarter);
- the hatchet's reared head pointing at the sky;
- the grab's arms swinging back instead of forward;
- the right foot floating 5.6 cm (`foot_level`);
- the shoulder ram over-reaching so the planted foot lifted;
- the lying legs folded up in a bundle;
- the gaits running 2.4x faster than the game moves it.

## Gates (after the canon merge)
- `tools/gait/check_allo.py --height 6.5` (new, adapted from check_pachy): **ALLO_CHECK PASS**, 16 clips. It checks:
  - stretch: worst 6.7, at the mouth corner;
  - floor;
  - moonwalk;
  - glide;
  - the left foot planted;
  - each hit: the bite jaw 7.8 m ahead and down to 2.4 m; the hatchet chopping down at 29 m/s from 6.2 m higher; the hands +1.2 m forward and both bites at 0.4 m; the ram at 11 m/s.
- `tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_allosaurus.gd`: **PASS**. It checks:
  - GLB, no boxes, 16 clips, bones, 6.5 m x 14.3 m;
  - feet on the floor in 12 clips;
  - parts ahead at their hit frames;
  - spawn rows are pairs, has_model;
  - ram chosen under the chin and grab in front;
  - no pounce;
  - the snap bite lands without bleed, and the hatchet lands and bleeds;
  - grab -> Pinned -> clamp + 2 bites land -> release;
  - the ram shoves her 3.2 -> 6.9 m;
  - the pair's slots 180 deg apart.
- t_noboxes, t_combat, t_canim, t_data, t_tactical, t_ai, t_labspawn, t_sp_smilodon, t_sp_tarbosaurus, t_sp_pachycephalosaurus, t_boneparts, t_capture09: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## Notes and open questions (AL1-AL6 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **Merge notes:**
  - My `landed()` hook is carno's, extended to the kick shove and the grab pin. When claude/mmo-sp-carnotaurus merges, keep the version here; it already includes carno's `heavy_shove_m`.
  - add_jaw's `--x-side` lines are identical to carno's.
- **The grab** lays her down (PINFEEL's pose) rather than lifting her in the hands (AL5).
- **Damage** is the old stat block (attack 480): the hatchet is x1.8 and the bites in a grab are x1.3. It is a balance call.
- **Not done:**
  - no alpha skin (there is no alpha sheet: the genetics recolour only);
  - no saddle (not tameable);
  - no eye glow;
  - `docs/current/biome-spawns.md` was not regenerated (it still says "no model yet").
- `make_allo_moves.py` has a `pose` debug clip: `POSE='{json}'` renders one static pose.
