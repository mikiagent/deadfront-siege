# SP-MEGATHERIUM: the giant ground sloth, a new temperate species

Branch `claude/mmo-sp-megatherium` (from `origin/claude/mmo-overhaul` f1b05695, canon merged back in at 2bb7c48b). Not merged to canon.
Owner: "build some of the models ... Be creative with what moves you think they should do when they fight".
Species id `megatherium`: no sloth id existed in `game/data/creatures`, the PRDs or the species-art wiki (the wiki row is "Giant sloth (Megatherium)").

## Credits
- **Tripo 50**: one P1-20260311 multiview, texture + PBR, face limit 15000, no retry. Task `972a0652-726a-474d-90f6-199e99255b4f`, `credits_consumed` 50.
- Shared balance 1905 before, 1805 (+50 frozen) after; other species agents were generating at the same time.
- Called the V3 API directly with the key in `~/.tripo/config.json` (never printed); the helper is in my scratchpad, not committed.
- Meshy 0, no Tripo rig/anim/retexture, no paid images. Codex images are free.

## Model
- Views: the owner's sheet (`giant_sloth_owner_sheet_1`) has a raised-arm side view and no back view. Codex drew a neutral
  all-fours, knuckle-walking left view (claws curled, mouth slightly parted, tongue in), a front view and a back view from it;
  the right view is the left mirrored. All padded to one scale (`sp-megatherium/tripo_inputs.jpg`, files in
  `game/assets/creatures/megatherium/ref/`).
- Tripo result: matches the sheet (rufous shag with the cream shoulder/flank bands, thick tail, curled grey claws). The claws
  came out as part of the hands, so no separate Blender claws were needed. Tripo grew one thin spike up off each fore-claw;
  the rig build cuts those vertices (`cut_boxes`).
- Size (# ASSUMPTION GS1): 2.8 m at the withers (1.75 m x the 1.6 house factor), 3.39 m to the head top, 8 m nose to tail;
  reared in the tripod the head reaches 5.1-5.3 m. `real_length_m` 12 (2x of 6 m).

## Rig and clips (reproducible: `tools/gait/megatherium/build.sh`)
- `build_rig.py`: SP-WOOLLY_RHINO's hand-built mammal rig, with the deer leg names the shared tools read. FrontCannon = the hand
  (wrist to knuckles), FrontFoot = knuckles to claws, HindCannon/BackFoot = a plantigrade foot.
  It adds Tail1-3 (the tail is the tripod's third leg), `ClawTip.L/R` marker bones and a Jaw.
- Weight fixes: the belly midline is never a leg's (it tore 16x as the legs walked). Skin below the ankle or wrist rides the
  foot or hand only (a heel half on the shin dug 0.3 m into the ground in the upright advance). The trunk is preferred over
  the arms above the belly.
- `clips.py`: the rhino's analytic leg solver plus keyed poses. The TRIPOD pitches the body ~58° about the hip joints; the hind
  feet stay planted and a tail solver lays the tail along the ground (it also keeps the tail out of the floor in every clip).
  Every clip then goes through `ground_clip.py --fps 24`.
- 19 clips: idle, walk (slow knuckle-walk), run (rolling amble), strafe_left/right, walk_back, alert, attack_primary,
  attack_heavy, grab, pounce, pin_stab, charge, toss, hit_react, knockdown, death, sleep, feed (it rears and hooks a branch down
  to its mouth). Hit fracs are the shared anim_events rows: hook 0.42, swipe 0.72, hug 0.7, crush 0.38/0.74, topple 0.3.

## Moves and AI (`megatherium.json` tactics: base horned_charger, archetype titan)
1. **Tripod threat display** (`alert`, 2.6 s): it rears on its hind legs and tail, throws its arms wide with the claws
   splayed, and roars. This is the display step that leads every fight sequence.
2. **Bear hug** (pounce machinery; display -> hug, weight 3):
   - the `grab` windup (reared, arms flung open) plays timed for 1.3 s under the ground ring;
   - the hug lurches forward and both arms close round her at 0.7;
   - a landed hug PINS her under its chest (PINFEEL's pinned pose), and `pin_stab` crushes twice (x1.3 each).
   - It comes from a visible grab, never a snap. A roll out of the ring dodges it, and a miss leaves it open for 2 s.
3. **Lumbering advance** (straight charge, display -> advance 1.5, plain 1):
   - it walks upright on its hind legs with the arms out, at 0.65x its run (~2.7 m/s), for up to 4.5 s;
   - it has **super armour**: hits do not flinch it;
   - on contact it topples onto her (`toss` clip, both arms crash down) with a 4.5 m shove;
   - a miss leaves it standing 2 s.
4. **Two-arm overhead swipe** (attack_heavy, point blank, x2.0): it rears, holds both arms high and trembling (the tell), then
   both claw hands come down through the front. It **bleeds** her and shoves her back 2.5 m.
5. **Hooking claw pull** (attack_primary, the basic): it half-rears, the right arm sweeps wide, then hooks in across her and drags
   her up to 2 m toward it (stops 3.3 m from its centre).
- **Hits** land from the claws (`pipeline.hit_parts` + `Creature.part_hit`; the hitbox system is not on canon). The swipe misses
  a survivor standing behind its rump.
- **Temperament** (# ASSUMPTION GS2): titan (defensive). Unprovoked it browses and ignores her; one hit makes it fight. Timid
  ones flee.
- **Owner rules:**
  - fleeing animals turning to fight (claude/mmo-cornered) is a shared rule on every brain, so nothing is needed here;
  - big and heavy: no leaps (`leap_height_per_m` 0), and the back-offs are scurries, not hops;
  - knockdown tiers (claude/mmo-knockdown, not on canon) read shove x size: the advance is the throw tier, the swipe the knockdown tier (noted in tactics `_knockdown`);
  - big stomp (claude/mmo-bigstomp, not on canon): only a hook (`_big_stomp` in tactics, with the leg map it needs). I did not build one.

## Code (small, shared)
- `TacticalBrain`:
  - `tactics.pounce_windup_clip`: a species' own pounce windup (default attack_heavy);
  - `tactics.charge_armor`: super armour for the whole straight charge;
  - the `primary_pull_m` hook pull in `landed()`, beside canon's therizinosaurus `hook_pull_m`.
- `CreatureClips.OPTIONAL`: `grab`.
- Data:
  - `anim_events.json`: the `grab` row, a megatherium note on `toss`, and `natural_speeds.megatherium` (walk 1.226, run 3.707 from `bake_clip_speeds.py`; strafes and walk_back as the walk; charge 1.55 from the clip's stride);
  - `butchering.json` row; `t_boneparts` row;
  - spawns in the gathering ring of `temperate_35` (2) and `temperate_45` (1) (GS5).
- Lab: `--lab=sloth_lab` (review shots). Docs: fight-lab row, species-art status, Open Questions GS1-GS6.

## Shots (`docs/orchestration/reports/sp-megatherium/`, off-screen windowed sloth_lab runs)
- `contact_sheet_side.jpg` and `contact_sheet_tq.jpg`: all 19 clips at 30 % and 60 %, with the survivor.
- `signature_hits_{tq,side}.jpg`: the display, the grab, the hook, the swipe (rear, overhead, hit), the hug, the crush, the advance and the topple.
- `tripo_inputs.jpg`.
- Fixed after looking:
  - the tail sank 0.7 m whenever it reared; the tail solver fixed it;
  - the belly and heel skin tore or sank (the weights above);
  - the hook swung wide of her and missed; it now sweeps in across her;
  - the swipe and hook landed above her head and were lowered;
  - the advance strided too short, so its legs would windmill at game speed.

## Gates (after the canon merge)
- `Blender -b -P tools/gait/check_megatherium.py -- megatherium.glb anim --height 3.39`: **SLOTH_CHECK PASS**, 19 clips.
  - Worst stretch 11.97 (gate 12, the knockdown roll); nothing sinks; no moonwalk.
  - Each move's claws are where they should be at the hit frame (hook in front, swipe coming down, hug closed, crush on the ground).
  - The tripod rears the head past 5 m on planted feet and tail; the advance keeps it upright.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_megatherium.gd`: **PASS**. It covers:
  - data, tactics, the spawn tables and the lab list;
  - the model, the 19 clips and the bones; size 3.39 m and 8 m long;
  - feet planted (looser bone tolerance on the plantigrade gaits and the advance; the Blender gate checks the skin);
  - the move geometry;
  - the hook drags her in (3.8 -> 2.9 m) and the swipe bleeds; the swipe misses at the rump;
  - display -> grab -> hug -> pinned -> two squeezes -> let go;
  - the advance walks upright with super armour, topples onto her, hurts and shoves her;
  - unprovoked it does not attack.
- Also PASS: t_noboxes, t_combat, t_canim, t_data, t_ai, t_boneparts (after canon's MegaRex row), t_labspawn, t_tactical, t_pinfeel, t_sp_woolly_rhino, t_sp_smilodon and t_sp_therizinosaurus.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- Merged .gd files checked for duplicate func names: none.

## How to test (god mode)
1. `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate` (or `tools/fight_lab.command` once merged).
2. SPAWN -> species "Giant ground sloth" -> nature Aggressive (or any, then hit it once) -> SPAWN, or press NEXT (T) until the info line says it.
3. Stand ~8 m in front. It rears into the tripod and roars. Then either:
   - it throws its arms wide under the red ring and lurches in for the hug: roll out of the ring, or get pinned and crushed twice;
   - or it walks at you upright. Hitting it does not stop it; it topples onto you and throws you back.
4. Walk up to its chest. It either hooks you in with the right claw, or rears and brings both arms down (watch the arms held high: that is the tell; the swipe bleeds). Stand behind its rump and the swipe misses.
5. GOD (G) keeps you alive; N enrages it. In the wild it is in the gathering ring of temperate_35 (2) and temperate_45 (1).

## For the next agent
- When claude/mmo-hitboxes lands, move `pipeline.hit_parts` into `hitboxes.json`. Use ClawTip/FrontFoot capsules for
  attack_primary/heavy/pounce/pin_stab/charge, then drop `Creature.part_hit`.
- No alpha skin (no alpha sheet given), no saddle, no ragdoll profile, no eye-glow points.
- `docs/current/biome-spawns.md` is generated; rerun `tools/docs_wiki/gen_game_data.py` after merge.
- Open questions GS1-GS6: size, temperament and stats, move numbers, bleed on the hug/advance, spawn rings, and the lying hug pose.

Report head: merge commit 2bb7c48b on `claude/mmo-sp-megatherium` (pushed); this report is the commit after it.
