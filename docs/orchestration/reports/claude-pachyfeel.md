# PACHYFEEL: more backstep charges, the windup sets how far the charge goes, less passive, no moonwalk

Owner, fight lab (god mode): "pachy behavior is really good, just give it more backstep charges and make some charges go
really far and some go shorter depending on the wind up", "make it less passive aggressive", "might have a walking
backwards bug hard to tell".
Branch `claude/mmo-pachyfeel`, cut from `origin/claude/mmo-overhaul` 30e08c30, canon e32ea4e2 (allocharge) merged back in.
Pushed, not merged to canon. Credits: none (the two new clips were built in Blender from `make_pachy_moves.py`).

## Before and after
Same 60 s fight: the pachycephalosaurus (Aggressive) against the GOD survivor fighting back (Hunt, Auto and Auto-ability
on, as in the fight lab). Its HP is held full.

| | Before (canon 30e08c30) | After (merged head, 5 runs) |
|---|---|---|
| Mean gap between its attack starts | 4.84 s (max 11.5 s) | 3.55 - 4.52 s |
| Backstep charges (hop back, windup, charge) | 83 % (10 of 12) | 92 - 100 % |
| Stood down mid-fight | yes, 8.3 s of nothing at 45.9 s | never |
| Frames moving against the clip (moonwalk) | 5 (hop_back while flying forward, one per reset) | 0 |
| Charge distance by windup | one windup; 4.2 - 6.6 m, all stalled pushing her | short 0.63 s: mean 4.8 - 6.0 m; medium 1.25 s: 7.2 - 12.2 m; long 2.25 s: 12.8 - 15.6 m (up to 19.8) |

## Causes found
- **Moonwalk.** After a charge she is behind it. The bull reset hopped straight away, "back" from her, which is forward along
  its facing, while hop_back played. Turning at 4.5 rad/s, the body flew forward under a back-hop for the first frames of
  each reset.
- **Every charge the same length.** The pachycephalosaurus is not taller than her, so CARNOFEEL's pass-through never
  applied. After the hit it pushed her along in front of it until `charge_max_s` ran out. Every charge ended near 6.6 m,
  whatever `charge_through_m` said.
- **Passive gaps.** `guard_m` 16 (pack_mule): the charges and the 3.5 m shoves drift the fight past 16 m from its home,
  so it stopped being provoked, stood down and stood in alert. Besides that, `charge_cd` 6 s and 0.8 - 1.6 s circles from
  the ring.

## What shipped
1. **Windup tiers** (`ai.json bull_windup.tiers`, # ASSUMPTION). Picked at random per charge, equal weights. The clip is the tell:

   | Tier | Clip | Windup | Past her | Speed |
   |---|---|---|---|---|
   | short | `bull_windup_short`: light head drop, one quick paw and snort | 0.63 s | 1 m | 1.4x run |
   | medium | `bull_windup`: the PACHYBULL clip, two paws | 1.25 s | 3.5 m | 1.6x run |
   | long | `bull_windup_long`: deep crouch (1.3x the drop), head held low, three slow paws | 2.25 s | 10 m | 2.0x run |

   The tier's `charge_through_m`, `charge_speed_mult` and `charge_max_s` replace the species' values for that one charge
   (`TacticalBrain._pick_tier`, `_ck`). The tiers only apply with `display_clip` bull_windup, so the allosaurus'
   bull_huff is untouched.
2. **New clips.** `tools/gait/make_pachy_moves.py bull_windup_tier()` (both clips are in `build_pachycephalosaurus.sh`).
   `check_pachy.py` exempts the pawing foot. **PACHY_CHECK PASS** on all 20 clips. The first long clip (1.5x crouch) sank
   6.5 cm, so it was cut to 1.3x.
   Sheets: `docs/orchestration/reports/pachyfeel/pachycephalosaurus_bull_windup{_short,,_long}.png`, from an off-screen,
   self-quitting `--clipsheet` run.
3. **More backstep charges, less passive** (`pachycephalosaurus.json`, # ASSUMPTION):
   - The ring sequences are `bull_charge` [backstep, display, charge] weight 4, `display_charge` 1, and the strafe
     charges 0.5 each.
   - `backoff_bull`: every back-off after a point-blank move is a bull reset.
   - `charge_cd` 3 (was 6), circles 0.4 - 0.9 s, `guard_m` 40.
   - One back-hop of 2 m per reset (was two of 1.6 m).
4. **Run-through, turn and come back.**
   - `charge_toss_deg` 45: the dome throws her off the line.
   - `charge_pass` (new tactics key, `_tick_pass`): a charger no taller than her still passes through her body.
   - After the line it wheels round on a 1 m arc at a run (`charge_arc_*`, CARNOFEEL's code). Only then does it hop.
5. **HOP TURN, shared** (`TacticalBrain._start_hop`/`_hop`): a back-hop with the prey more than 60 deg off the facing first
   turns in place to within 25 deg (at most 1.2 s), then hops. This fixes the same moonwalk for every species that hops
   back after passing its prey or after a hind kick. The in-place turn plays idle.
6. No positive stance drift: `tools/audit_gaits.py --gate` GATE PASS. `check_pachy` moonwalk check on walk, run, charge
   and walk_back: PASS.

## Gates (merged head)
| Gate | Result |
|---|---|
| `t_pachybull` (extended) | PASS, and 3 more runs PASS |
| `t_sp_pachycephalosaurus` | PASS |
| `t_noteleport` | pachy case ok (worst frame 0.15 m). FAIL 2 on other species: a compsognathus kick miss and a raptor flank/charge_turn 1.12 m. Clean canon e32ea4e2, run alone in its own worktree, fails the same way: coelophysis and megaloceros kick misses, raptor flank 1.51 m. |
| `t_stunlock` | PASS (pachy 5 % staggered by her, longest gap 1.5 s) |
| `t_hitboxes`, `t_knockdown`, `t_combat`, `t_tactical`, `t_sp_allosaurus`, `t_sp_carnotaurus` | PASS |
| gait audit `tools/audit_gaits.py --gate` | GATE PASS |
| `run_all.gd` | `[tests] PASS` |
| `tools/smoke.sh --no-import` | SMOKE PASS |
| `t_canim` | skipped: canon e32ea4e2 fails it too (triceratops, utahraptor, carnotaurus "_on_damaged starts hit_react (got idle)") |

New checks in `t_pachybull`:
- **Standing survivor**, until each tier has run 3 charges:
  - no teleport;
  - every charge after the first is hop, windup, charge;
  - every windup plays a tier clip;
  - the long windup is over twice the short one;
  - long charges run more than 5 m farther than short ones;
  - no frame moves against its clip.
- **60 s fight against her fighting back:**
  - backstep share >= 85 %;
  - mean attack-start gap < 4.84 s (the before value);
  - no stand_down;
  - no moonwalk frame.

  The moonwalk rule: a forward clip (walk, lope, run, sprint, charge) needs velocity . facing > 0.2 x |v|, and a back
  clip (walk_back, hop_back, leap_back) the opposite. It applies when the animal moves faster than 0.5 m/s and is not
  being shoved, with the clip judged at both ends of the frame.

## Merge note
Canon's allocharge gave the allosaurus `charge_reset: bull` too, so the "back-off = bull reset" rule is behind its own key
(`backoff_bull`, pachy only). The ONESHOT/OPTIONAL conflicts were resolved by keeping canon's lists and adding the two
clips.

## ASSUMPTIONS
PF1-PF5 in `docs/vision/WildLandsMMO_Open_Questions.md`:
- the tier numbers;
- every back-off is a bull reset, plus the cooldowns;
- the arc, toss and pass-through numbers;
- the hop-turn thresholds;
- `guard_m` 40.

## For the next agent
- The owner should re-test in the fight lab: whether the three windups read at phone size, and whether point-blank moves
  (hip check, stomp, dome butt) now come up too rarely.
- The mean gap ranges 3.6 - 4.5 s run to run (long windups are 2.25 s). The 4.84 s gate has a small margin on a bad
  run, and the test stays green over 5 runs.
- No snort puffs or huff sound (no particle helper, no audio system).
- The raptor's 1.1 - 1.5 m flank and charge_turn jump in `t_noteleport` is on canon. It is a separate bug.
