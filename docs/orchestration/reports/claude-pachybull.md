# PACHYBULL: the creature teleport, and the pachy's bull reset between charges

Owner (fight lab, verbatim): "Pachy is teleporting or something, not sure why. its actually kind of a success. instead of
it walking back slowly, have it jump backwards and wind up like a bull, huff huff, and then charge". Later: "Smilodon kind
of teleports too".
Branch `claude/mmo-pachybull` (from `origin/claude/mmo-overhaul`, canon merged back in). Not merged to canon.
Credits: none (clips built in Blender from `make_pachy_moves.py`).

## 1. Teleport: cause and fix (shared code)
- **Repro.** Pachy vs the GOD survivor in a LabKit world (baked navmesh, survivor auto-fighting). Its global position was
  logged every physics frame. The body jumped **3.46 m in one frame**, with zero velocity, away from the survivor. It
  happened in any brain state (charge, hold, circle) and about once every 6 s.
- **Cause.** The survivor's **kick** (`CombatTactics.kick`, an auto-cast tactic). It moved the target its whole push in a
  single `move_and_collide`. The push is `push_m 3.5 x ref_mass / mass`, capped at 3.5 m:
  - pachy (4.5 x 1.8 = 8.1): 3.46 m;
  - smilodon: 3.18 m.

  That matches the jump exactly, and it explains why the smilodon "kind of teleports too". Every kickable species had
  this bug (compy, raptors, zebraceratops, megaloceros ...). It was never root motion, ground snap, state change or
  the lab respawn.
- **Fix.**
  - New `Creature.shove(push, seconds)`. It slides the body over the kick's stagger, decaying linearly. This is the same
    law as `PlayerSim.shove`: 2d/T at the start, d metres in total, peak 14 m/s for 3.5 m over 0.5 s. The slide
    respects walls and props.
  - `CombatTactics.kick` calls it with `stagger_s`.
  - The frozen branch of `Creature._physics_process` (stagger, knockdown) now slides with the shove velocity instead of
    zeroing it.
  - The push distance is unchanged.
- `t_kicktackle` measured the shove right after the call. It now measures after the clip, when the slide is done.
- Not changed: the tackle still moves the *survivor* up to 1 m in one frame (`lunge_max_m`). That is her own lunge, not
  the creature.

## 2. Pachy bull reset (pachy-specific)
After every charge, hit or miss, the cycle is:
1. **hop_back** x2: 1.6 m each, facing the prey, about 0.58 s each, with the game's arc.
2. **bull_windup**: 1.25 s in place, then the next charge.

It never walks back.
- Brain (`TacticalBrain`, data-gated):
  - `tactics.charge_reset "bull"` -> `_start_bull_reset` -> `bull_hops` x `_start_hop(&"bull")` -> `_start_display` with
    `_seq = [charge]`.
  - `tactics.display_clip` makes the display play that clip for its whole length (default `alert`, unchanged for
    everyone else).
- `pachycephalosaurus.json` tactics add: `charge_reset bull`, `bull_hops 2`, `bull_hop_m 1.6`,
  `display_clip bull_windup`, `backoff leap` (was pack_mule's walk_back scurry), `hop_m 1.6`, `leap_back_m 2.0`. Its
  display_charge sequence opens with the bull windup too.
- `bull_windup` is added to `CreatureAnim.ONESHOT` and `CreatureClips.OPTIONAL`.
- **Clips** (`tools/gait/make_pachy_moves.py`, in `build_pachycephalosaurus.sh`, then `ground_clip.py`):
  - `hop_back`: crouch, airborne 0.2-0.65 (the shared `anim_events hop_back.airborne`) with the feet tucked, then a
    planted squash landing.
  - `bull_windup`: head drops dome-first and the weight goes back. The right foot paws twice: lift, reach forward, then
    scrape back with the toe dug in. A snort lands at the end of each scrape (head and jaw jolt, body jolt). It ends
    head-down.
- `check_pachy.py`:
  - hop_back's airborne frames are exempt from "floats";
  - bull_windup's pawing foot is exempt from "glide".

  **PACHY_CHECK PASS** on both clips: stretch 2.9 / 4.9, lowest -0.008 m, landing planted.
- **Review shots:** `docs/orchestration/reports/pachybull/pachycephalosaurus_{hop_back,bull_windup}.png`. They are
  8-frame sheets, front three-quarter over side, from a self-quitting off-screen run of
  `--lab=creature_lab --species=pachycephalosaurus --clipsheet=DIR`.
- **Not done:** the snort puffs and the huff sound. There is no particle helper for creature breath and no audio
  system in the game, so the snort is animation only.

## ASSUMPTIONS
- Hop distance 1.6 m x 2 and windup length 1.25 s.
- No miss stagger in bull mode: the hops plus the windup (about 2.4 s) are the punish window.
- The kick's slide time is its existing `stagger_s` (0.5 s).

## Tests
- `t_pachybull` (new): **PASS**. Lab world, GOD survivor auto-fighting.
  - 3 cycles: `charge, hop, hop, display, charge` x3.
  - Worst frame step 0.10 m against a limit of 0.29 m (top speed 5.8 m/s x dt x 3). Hips are measured in the body frame
    too.
  - 0 walk_back frames.
  - Every hop plays hop_back; every windup plays bull_windup.
- `t_noteleport` (new, about 3.5 min): **PASS**. Every modelled species (20) fights the GOD survivor for 10 s. No frame
  moves the body, or the hips within the body, further than max(top speed, 20 m/s leaps) x dt x 3. Then the survivor
  kicks each of the 11 kickable species: each slides back and the worst frame is <= 0.23 m.
  - With the old kick line restored it **FAILS**: pachy 3.46 m and smilodon 3.18 m in one frame.
- Also PASS: t_sp_pachycephalosaurus, t_combat, t_tactical, t_canim, t_noboxes, t_kicktackle, t_compyfeel, t_godlab,
  t_zebra, t_styraco, t_styrafix.
  - t_styrafix failed once (ping-pong 1) in a 4-way parallel batch and passed in 3 solo or lighter runs. It is timing
    flaky under load; my change does not touch styracosaurus' path unless it is kicked.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- After merging origin/claude/mmo-overhaul there were conflicts only in the ONESHOT/OPTIONAL lists (STYRAFIX
  charge_windup/impale/charge_recover kept, bull_windup appended). No duplicate func names in the touched .gd files.

## For the next agent
- claude/mmo-knockdown turns the pachy charge into a knockdown-tier hit. My change is after the charge (`_charge_end`),
  so the two should merge cleanly.
- claude/mmo-cornered (shared chase rule): I did not touch the approach or chase code.
- Every kicked creature now slides instead of jumping. If someone wants a smaller push on mid-size animals, that is
  `combat_tuning.json kick.push_m / ref_mass`. Pachy is still shoved 3.46 m, which is a balance call.
- I did not touch the smilodon clips (claude/mmo-smilorun owns its run clip). Its teleport was the kick.
