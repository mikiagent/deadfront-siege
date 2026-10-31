# ALLOCHARGE: the allosaurus bull charge (stomp, huff huff, charge, jump-bite) and a faster, forward-only arc

Branch `claude/mmo-allocharge`, cut from `origin/claude/mmo-overhaul` 56d44cdc (allofeel and theroroar both on canon). Canon was merged back in at 30e08c30 (critdebug). Pushed, not merged to canon. No credits spent; the model is untouched.

What the owner said:
- "allosaurus charge is weak looking, he kind of just pads over to the player, what if you do like a bull charge thats like stomp throw back, huff huff, charge (low center of gravity jump with a bite attack) charge jump and bite. Stomp is important, keep it."
- Then: "allosaurus charge circle turn is weird like he walks backwards and doesn't turn fast enough".

## The sequence (live brain, `t_sp_allosaurus`)
1. **Stomp.** This is theroroar's spacing stomp, kept as it was. When she is tucked in under its chin, it stomps.
   - New per-species row `ai.json spacing_stomp.species.allosaurus`:
     - `push_to_m` 14: it throws her out to charge range instead of bite range. The shared throw cap (`PlayerKnock.THROW_MAX_M` 9 plus the tumble) lands her about 12 m out.
     - `follow "bull"`: it goes straight into the bull windup instead of a bite.
   - The under-chin shoulder ram does not compete with it. The stomp ticks before the brain thinks, so it always takes her first. The ram only fills in while the stomp cools down (4 s). The flank keeps the shoulder-check.
2. **Huff huff.** New clip `bull_huff` (1.6 s), played through the pachy's mechanism (`tactics.display_clip` plus `charge_reset "bull"` with `bull_hops` 0).
   - It plants and lowers, head down and level at her.
   - It huffs twice at 0.3 and 0.6: the chest heaves, the head bobs and the jaws puff open.
   - Then it paws: the right foot lifts, reaches, scrapes back low and sets down on its print.
   - The left foot never moves. There is no breath particle; I skipped it as not cheap.
3. **Charge.** New gait clip `charge` (`tools/gait/allosaurus.json` plus `make_gait.py`).
   - It runs crouched, body pitched forward, head down and level on a straight neck, with the tail out straight.
   - Strides are 0.52 units per 0.79 s, which is 9.4 m/s; `natural_speeds.allosaurus.charge` is baked.
   - Speed is `charge_speed_mult` 1.45, giving about 9.7 m/s in the engine, against a 2.6 m/s walk.
4. **Jump-bite.** New clip `charge_leap` (0.8 s): coil, push, a low lunge-jump, then a landing bite.
   - Both feet are off the ground from 0.16 to 0.68; the lowest skin point peaks at 1.5 m.
   - In the air the jaws gape and the arms reach forward with the claws spread.
   - It lands at 0.68 and bites at 0.75, with the head and arms driving down.
   - New `TacticalBrain._charge_leap` (`tactics.charge_leap_m` 6.0):
     - It takes off when her distance equals the jaw reach plus the ground it will cover before the bite at its real speed. It needs at least 0.3 s of run first.
     - If she is nearer, the jump is shorter: the body slows so the jaws land on her, not past her.
     - The bite is judged once, at the clip's own bite frame, from the new hitbox move `charge_leap`: a 1.4 m jaw capsule plus the claw tips.
     - The charge's knockdown, pass-through and run-on apply as in the carnofeel kit.
     - While it is in the air, the "body runs her over" contact is held off. Otherwise the long snout's footprint "hit" her before the jaws shut.
   - The leap is in `CreatureAnim.LEAPS`, so it plays while the body moves.
   - On the ground parts of the leap, the planted feet slide back at charge speed so they stay on their prints in the world. The brain hands back to the charge gait at 0.82.
5. **Arc, then repeat.** The arc is tighter and faster (owner: "doesn't turn fast enough"):
   - `charge_arc_r_m` 3.5 (was 6), `turn_rate` 2.4 (was 2.0), aim 25° (was 95°), at its run speed.
   - There is no return pass (`charge_turn` false). The bull reset runs instead: huff, then charge again.
   - **Moving backwards:** in this test the body moves forward along its facing on every frame of the arc (worst velocity · forward 1.00), playing the run at a matching stride (0 % off).
   - The 0 % is against the run clip's own speed. I didn't capture what read as walking backwards on the old 6 m / 95° setup, so I can't say for sure the cause is gone. The owner should check it in the lab.

## Gates (after the merge with canon 30e08c30)
- `t_sp_allosaurus`: **PASS**. New bull-charge checks (seeded live fight from her under its chin):
  - the clips fire in order: stomp, huff, charge, jump-bite;
  - she is thrown to 12.3 m;
  - the left toe drifts 0.01 m in the stomp and the huff;
  - the charge runs at 9.7 m/s, against a 2.6 m/s walk (at least 1.5x);
  - charge clip stride against body speed: 0 % off;
  - both feet 0.72 m up mid-leap;
  - the bite lands through the jaws hitbox (`leap_bite`), then `charge_hit`, damage, and the knockdown or throw tier;
  - the charge's bite doesn't bleed;
  - in the arc, velocity · forward > 0 on every frame (worst 1.00);
  - the arc's gait is stride-matched;
  - it is back round to her in 2.0 s, under the 4.0 s limit (`ARC_BACK_S`, marked ASSUMPTION);
  - then the huff and the charge repeat;
  - the pass-through exception is cleared.
  - The carno chomp combo checks still pass. The old "return pass" check was replaced: by design there is no return pass now.
- `t_spacingstomp`: **PASS**. For a species with `push_to_m` it now checks that she is thrown out to charge range (12.15 m) and that the follow-up is the bull windup. The other 7 rigs keep the bite-reach checks.
- `t_theroroar`, `t_hitboxes` (which covers `charge_leap` at its reach), `t_knockdown`, `t_combat`, `t_sp_carnotaurus`, `t_tactical`: PASS.
- `run_all`: [tests] PASS. Gait audit: GATE PASS. `check_allo.py`: ALLO_CHECK PASS, 23 clips.
  - `charge` is checked as a gait (no moonwalk).
  - `charge_leap` must be airborne mid-leap (lowest sole 0.66 m) with the bite coming down (jaw at 0.96 m).
  - `bull_huff` passes the planted-foot (no glide) check.
- `tools/smoke.sh --no-import`: SMOKE PASS.
- `t_canim`: skipped, as asked.
- **`t_pachybull` is flaky:** 1 of 2 runs failed on "no walk-back once the charges start (1 frames)".
  - The new code only runs for a species with `charge_leap_m`, so it should not touch the pachy. I couldn't confirm on a clean canon worktree: **the disk is full**, with about 0.7 GB free on /System/Volumes/Data. A canon checkout failed with "No space left on device".

## Shots (`docs/orchestration/reports/allocharge/`, off-screen windowed `allosaurus_lab` runs)
- `beats_side.jpg` and `beats_close.jpg`, in order:
  - the stomp slam (40 %);
  - huff 1 (30 %), huff 2 (60 %), the paw (76 %);
  - the charge (25 % and 75 %);
  - the leap's coil (8 %), mid-air (40 %) and the landing bite (75 %).
- `frames/`: every frame from the side, three-quarter and close cameras.
- Lab: `--lab=allosaurus_lab --hits-only --close --clips=spacing_stomp,bull_huff,charge,charge_leap`.

## Open (ASSUMPTION; logged as AL11)
- Thrown range (14 m asked, about 12 m landed under the shared throw cap).
- Charge speed 1.45x, giving about 9.7 m/s.
- Leap jaw reach 6.0 m, minimum run 0.3 s, clip-start lag 0.1 s.
- Arc 3.5 m at turn_rate 2.4, back round within 4 s.
- The jaw capsule (1.4 m, radius 0.55).
- No return pass.
- After the first stomp the charge is short: she lands about 12 m out, so the jump takes off after about 0.3 s of run. Charges after an arc get a longer run.
