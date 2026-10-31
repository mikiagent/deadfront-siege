# SP-MAJUNGASAURUS: a new species, the Majungasaurus

Branch `claude/mmo-sp-majungasaurus`, cut from `origin/claude/mmo-overhaul` with canon merged in again before this report. It is pushed but not merged to canon.

The owner approved the sheet and asked for a name, so it is the Majungasaurus. The sheet is `majungasaurus_owner_sheet_1`, copied to `game/assets/creatures/majungasaurus/ref/majungasaurus_sheet.png`. It shows a warm brown and tan abelisaurid with a deep skull, brow bumps, a skull knob, osteoderm studs and a cream belly. There is no alpha sheet.

## Credits
**Tripo: 50**, from one P1 multiview generation, accepted on the first try with no retry.
- Task `6480a614-155b-4fe6-b906-f572daf7ea62`.
- Balance was 2105 before and 2055 after.
- Meshy 0, no paid images. The Codex CLI drew two images for free.
- The Tripo V3 API was called directly with the key in `~/.tripo/config.json`. The key was never printed.

## Mesh
- The sheet draws the arms large and lowered, so in the side view they read as a second pair of legs.
- Codex redrew two neutral views from the sheet: a left side and a front. The arms are tiny and tucked against the chest, and the hind feet stand side by side.
- The right view is the left mirrored. I checked all three by eye before spending credits. They are in `docs/orchestration/reports/sp-majungasaurus/tripo_inputs.jpg` and in `ref/`.
- The result has two legs and tiny arms (`tripo_mesh_views.png`).
- The source GLB is `game/assets/creatures/majungasaurus/work/majungasaurus_tripo_v1.glb`. It is gitignored; the task id re-downloads it.

## Rig and clips (rebuild: `tools/gait/build_majungasaurus.sh`)
This follows the PACHY route, not the raptor transplant. The transplant's bone-heat weighting failed outright (0 % weighted) whenever the legs were placed by hand.
- **Rig:** `tools/gait/rig_biped.py` with `tools/gait/majungasaurus_rig.json`. The joints were read off ortho renders. The legs use the theropod chain Thigh, Shin, Metatarsal, Toe, and the skin uses heat weights.
- **Jaw:** `tools/jaw/add_jaw.py --open --x-side --pivot 0.05 0.385`.
  - I ported carno's `--x-side` patch byte for byte, so it merges cleanly with that branch. Without it this level jaw opens the wrong way.
  - I also ported carno's `ground_clip.py --fps` patch.
- **Size:** 10.3 m long and 5.0 m tall.
- **Gaits:** `tools/gait/majungasaurus.json` through `make_gait.py`: walk, run, charge, strafe_left, strafe_right and walk_back. The charge is the run with the body level and the jaws pushed out.
- **New `tools/gait/make_majunga_moves.py`**, forked from `make_pachy_moves.py`. The feet stay IK-planted. It makes idle, alert (roar), attack_primary, attack_heavy, kick, pin_stab, hit_react, knockdown, death, sleep and feed. That makes 17 clips in total.
- **Natural speeds:** the `natural_speeds.majungasaurus` row in `anim_events.json` comes from a `bake_clip_speeds.py --dry-run`. Only that row was spliced in.
  - walk 2.87 m/s, run 9.38 m/s.
  - The charge, strafe and walk_back speeds were scaled by stride.

## Moves and AI (new archetype `opportunist`, a TacticalBrain tactics block in ai.json)
Every move fires in a fight and lands from its own body part. canon's `pipeline.hit_parts` / `Creature.part_hit` does the check, because claude/mmo-hitboxes has not landed on canon.
- **Crushing bite** (`attack_primary`, hit 0.42, from the Jaw or Head):
  - It rocks back with the jaws gaping, then darts forward and down to a survivor's height and clamps shut.
  - **A bite that lands grabs her** (new `tactics.bite_pin`, through a new `TacticalBrain.landed()` hook called from `Creature._on_hit`, the same hook carno adds).
- **Grab and shake** (`pin_stab`, hits 0.38 and 0.74, from the Jaw):
  - She is Pinned and held at its jaws, low to the ground. It wrenches its head side to side twice, x1.1 each, then lets go. The grab has a 9 s cooldown.
  - The grab starts deferred. Started inside the bite's hit event, pin_stab skipped its first shake; this was found and fixed by the test.
- **Skull-knob headbutt** (`attack_heavy`, hit 0.72, from the Head, x1.6, point blank in front):
  - It rears back with the chin tucked so the knob faces her, and paws the ground twice with a hind foot. That is the telegraph, with the heavy ground ring.
  - Then it drives in with a step, knob first.
- **Low tail swipe** (the `kick` clip, hit 0.45, from Tail3-5, x1.2): when she is in its rear arc, the hips pivot and the tail sweeps low across its back.
- **The brain: an opportunist that circles wounded prey.**
  - It holds a wide 11 m ring, circling, holding and roaring.
  - On a healthy survivor, a ready rush goes only 25 % of the time (new knob `healthy_commit_chance` in `_start_sequence`). The rest of the time it keeps circling.
  - Under 50 % health, the `weak_prey` block switches on: every ready pick commits, the rush weight is x8, cooldowns are x0.45 and waits are x0.25.
  - The rush is the homing charge, and it ends in the crushing bite, which then grabs.
  - It backs off at a scurry and retreats under 25 % of its own health.
- **Spawns:** one on savannah_45's working ring and one on its far shore. The lab lists it because it has a model.
- Every number is an ASSUMPTION, logged as MJ1-MJ6 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## How to test (god mode)
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate` (or point `tools/fight_lab.command`'s REPO at this worktree). God mode is on; G toggles it.
2. Press SPAWN, pick **Majungasaurus**, set the nature to Aggressive, then SPAWN. NEXT (T) also cycles to it. Debug F3 prints each move.
3. At full health, stand off. It circles at about 11 m, holds and roars, and only now and then rushes in. Turn GOD off and take damage below 50 %: it rushes again and again.
4. Let it bite you: you are grabbed at its jaws and shaken twice, then dropped. Stand in front of its head to get the skull-knob headbutt (paw-scrape telegraph and ground ring).
5. Walk round behind its legs: it swipes its tail low across its back. Its jaws miss you there.

## Shots (`docs/orchestration/reports/sp-majungasaurus/`, off-screen windowed lab runs)
They come from `--position 6000,3000 -- --skip-charcreate --lab=creature_lab --species=majungasaurus --clipshots=DIR --clips=...`. The runs quit by themselves, with the survivor for scale.
- `contact_sheet.jpg`: 3 frames per clip, two clips per row, in this order: idle, walk / run, charge / strafe_left, strafe_right / walk_back, alert / attack_primary, attack_heavy / kick, pin_stab / hit_react, knockdown / death, sleep / feed (repeated).
- `hits.png`: the bite, the grab-shake, the headbutt and the tail swipe, each on its hit frame.
- To support `--clips` and the hit frames, I ported carno's `creature_lab.gd` patch byte for byte.

What read wrong and was fixed:
- the lowered arms on the sheet (redrawn small before Tripo);
- the jaw opening the wrong way (`--x-side`);
- the tail curling up in the bite;
- the swipe's tail dipping under the floor, so ground_clip lifted the feet 0.25 m;
- the swipe only reaching one side (now it crosses straight behind on the hit frame);
- the grab's head going through the floor, which lifted the feet 0.29 m;
- the headbutt driving down instead of forward;
- pin_stab's first shake skipped (the deferred grab).

## Gates (after the canon merge)
- `tools/gait/check_majunga.py --height 5.0` (new, adapted from check_pachy): **MAJUNGA_CHECK PASS**, 17 clips. It checks:
  - stretch, floor, moonwalk and glide;
  - the bite's jaws down at survivor height and closing on the hit;
  - the skull 0.77 m forward and moving at 7.3 m/s at the butt;
  - the tail sweeping at 9.9 m/s, low;
  - both shakes low and fast, over 11 m/s.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_majungasaurus.gd`: **PASS**. It checks:
  - the model and 17 clips load, with no boxes, a Jaw, and the right size;
  - the toes stay planted;
  - each hit part sits where it should on its frame;
  - the bite lands, grabs, holds her at the jaws, shakes twice and releases;
  - the bite misses behind it and the tail swipe hits there;
  - the headbutt lands from the skull;
  - the opportunist commits on 56 of 200 healthy picks and 50 of 50 weak ones;
  - the spawn rows.
- t_noboxes, t_combat, t_canim, t_data, t_ai, t_labspawn, t_tactical, t_boneparts, t_sp_smilodon and t_sp_pachycephalosaurus: PASS.
- `run_all.gd` and `tools/smoke.sh --no-import`: see the merge section below.

## For the next agent / known issues
- **Merge with claude/mmo-sp-carnotaurus:**
  - Both add `TacticalBrain.landed()`. Carno's does `heavy_shove_m`, mine does `bite_pin`. Merge the two bodies into one function.
  - The `creature.gd` call, `add_jaw --x-side`, `ground_clip --fps` and the `creature_lab.gd` patches are byte-identical to carno's.
- **Canon gap:** the survivor's auto-tactics (body tackle, kick) still fire while she is Pinned. The tackle staggers the animal out of the grab, so the test disables her processing. PINFEEL's struggle is not implemented either.
- **Balance:** one bite or headbutt kills a fresh 100 HP survivor (MJ2).
- **Clips I left as they are:**
  - knockdown, death and sleep are the pachy-style folds, resting on the floor;
  - feed brings the head to about 1 m, not onto the carcass.
- **Not done:** no saddle or mount, no eye-glow points, no ragdoll or butchering row, no alpha skin (no sheet). `docs/current/biome-spawns.md` was not regenerated.
