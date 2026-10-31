# ALLOFEEL: allosaurus arms in every attack, three new moves, the carnotaurus kit

Branch `claude/mmo-allofeel`, from `origin/claude/mmo-overhaul`, with canon merged back in (bigstomp 2eecfc3e, megajoust f1b73788, then carnofeel c8a64c14; every gate rerun after the last merge). Pushed, not merged to canon.
Credits: Tripo 0, Meshy 0, Higgsfield 0. The model and rig (`allosaurus.glb`) are untouched; only clips, data and code changed.

What the owner said: "Alosaurus model turned out great! the arms should be moving as part of the attack animation and add more attacks generally. Carnotaurus attacks are welcome on this".

## 1. Arms in every attack
- `tools/gait/make_allo_moves.py` gained `arm_keys()`: per-side tracks for shoulder swing (`up`, `out`), elbow and wrist, in raptor_overlay.py's arm language. The rig has no finger bones, so the claws "spread" and "curl" through the wrist.
- **attack_primary** (snap bite): the arms cock back with the claws curled, thrust out with the head (claws presented), and rake down on the bite. The right arm leads the left.
- **attack_heavy** (hatchet): the arms rise and spread wide with the claws open through the held gape, which is the telegraph. They slam down with the chop, hook in on the hit, then drag back to the chest.
- **grab_bite**: the arms reach out wide with the claws spread, then stay extended and clench on the clamp (0.3). On each bite the elbows fold to haul her to the jaws. They fling open on the release.
- **kick** (shoulder ram): both arms tuck in the wind. The right arm drives out with the shoulder and rakes down after the hit, while the left swings back.
- Measured in the engine, from the first frame to the hit, with the claw tip in the chest's frame (so the body carrying the arm doesn't count):

| clip | canon before (tip m / elbow deg / wrist deg) | now (lead / other tip m, elbow, wrist) |
|---|---|---|
| attack_primary | 0.25 / 0 / 0 | 1.15 / 1.00 m, 64, 60 |
| attack_heavy | 0.70 / 19 / 0 | 1.51 / 1.52 m, 40, 59 |
| grab_bite | 0.83 / 20 / 14 | 1.61 / 1.61 m, 44, 58 |
| kick | 0.43 / 10 / 0 | 1.16 / 0.66 m, 44, 42 |

- **ClawTip rows** (`hitboxes.json`): a part at the tip of the claws. It is the `Hand.L/R` bone plus a 0.64 m offset along it (`_part: ClawTip.X`), radius 0.45 m.
  - The rig has no ClawTip bone. Adding one means re-exporting the approved model, so I didn't.
  - The rows sit on every move where the hands are at the prey at the hit frame: bite, hatchet, grab, ram (right hand), rake, slash and the checks (near hand).

## 2. Three new moves (TacticalBrain `tactics.moves`, data-driven)
| move | clip | when | hit | effect |
|---|---|---|---|---|
| ARM RAKE | `claw_rake` 1.1 s | prey 3.5-5.2 m in front (under its chest) | 0.5, claw tips | x1.1, no bleed |
| HATCHET SLASH | `slash_bite` 1.3 s | prey 5.2-6.8 m in front | 0.42, jaw/skull + claws | x1.3, **Bleed** (with the hatchet: `tactics.status_clips`), then it pulls back off her |
| SHOULDER-CHECK | `check_left` / `check_right` 1.0 s | prey at its flank, 45-120 deg off its facing, within 3.2 m | 0.45, stepping leg + chest + near claws | x0.9, shoves her 3.5 m sideways |

- **Rake:** it rears with both arms high and the claws trembling, holds, then pitches forward and rakes both arms down through her. The left arm goes a beat ahead.
- **Slash:** the slash-and-retreat bite. The head cocks high to its left with the jaws gaping, then the open upper jaw slashes down through the middle and across to its right.
- **Check:** it leans away, then slams sideways. The near foot steps out into her and the near arm lashes out.
  - The chest is about 4 m up, over a 1.78 m survivor, so at her height it is the leg that connects.
- **Telegraphs:**
  - Each new clip has `tell_fracs` in `anim_events.json`, so a ground ring appears at the start of its held windup.
  - The new `tactics.rings` puts that ring where the move lands, for example beside the flank for the check. Before, every ring was 1.2 m ahead of centre, which is under this animal's chest.
- Order: point_blank is kick, check, grab, rake, slash, heavy, bite. Cooldowns: rake 6 s, slash 9 s, check 5 s.
- **Code** (small, generic; any species can use it):
  - `TacticalBrain`: `_move_row`, `_move_of_clip`, `_move_clip` (front/side arc, side picks the clip), `_play_move`, plus the mult and shove hooks. A side move keeps its flank to the prey instead of turning to face her.
  - `Telegraph.show_for` reads `tactics.rings`.
  - The new clips are added to the ONESHOT/ATTACKS/OPTIONAL/FIGHT_CLIPS lists.

## 3. Carnotaurus kit: ON (after carnofeel landed, c8a64c14)
Enabled through the allosaurus' own tactics and clips. No carnotaurus code was copied.
- **Charge** (`charge_straight`): the run-in is now a straight charge on a locked line.
  - Pass-through: it runs through her, using carnofeel's `_tick_pass` with `charge_pass_s` 0.6.
  - Contact knocks her down even when the damage roll misses: `charge_shove_m` 3.5, `charge_toss_deg` 60, the throw tier.
  - It still plays the run clip, because the allosaurus has no `charge` clip. The charge contact parts in `hitboxes.json` are Head, Jaw (calibrated to 2.17 m) and Chest, plus carnofeel's body-over contact.
  - The charge's impact no longer carries Bleed. `CreatureAttack._carries_status` with `status_clips` now treats a charge impact as "charge", not as the `attack_heavy` it rolls as.
- **Wide arc** (`charge_arc_r_m` 6 m): after every charge it wheels round on the arc, then makes one return pass (`charge_turn`, max 22 m).
  - `charge_arc_aim_deg` is 95, against the carnotaurus' 15. Measured: with her knocked down in the middle, the allosaurus settled into an orbit about 12.5 m out with her 90 deg off its nose. It never came within 15 deg and timed out, so there was no return pass.
  - At 95 deg it breaks off there and charges back. `charge_arc_max_s` is 7.
  - **Shared-logic note for the carnofeel owner:** carnofeel's arc runs straight while she is inside its circle, and that rule can lock into this orbit. The carnotaurus' own test passes, but the orbit is possible for any long-reach charger.
- **3-chomp combo:** the allosaurus' own `bite_combo` clip (`make_allo_moves.py`, 2.75 s on the shared hit fractions 0.092 / 0.338 / 0.815).
  - Chomp left with the left arm raking, chomp right with the right arm.
  - The rear-up tell (0.5-0.667) with the jaws wide and both arms raised, claws spread.
  - Then a MEGA chomp through the middle with both arms raking, and a head shake.
  - Wiring: `point_blank` is now kick, check, grab, combo, rake, slash, heavy, bite. `charge_follow ["combo"]` closes in after landed charges.
  - Tell: `combo_tell_scale` 0.3, with the ring at its jaws (`combo_ring_ahead_m` 6.4). The first chomp lands 1.1 s after the combo starts.
  - Hits through `hitboxes.json` `bite_combo`: Jaw, Head and both claw tips. The right claw tip is calibrated to 1.32 m.
- **Shoulder ram:** the ram (`kick`) is now front-only (`kick_max_m` and not behind). It was also firing as the after-charge "hind kick" at prey behind it, which a forward ram can't reach.
- The turn_rate stays 2.0. The owner's turning complaint was about the carnotaurus. The arc sets its own pace: yaw about 1.0-1.2 rad/s, radius at least 6.2 m.
- The numbers are first guesses scaled from the carnotaurus (CF1-CF4), logged as AL10.

## 4. Not touched
No roar and no spacing stomp (claude/mmo-theroroar owns those).

## Gates (on the merged head)
- `tools/gait/check_allo.py --height 6.5`: **ALLO_CHECK PASS**, 20 clips. New checks:
  - arms in every attack: lead claw tip >= 1.0 m, the other >= 0.4 m, elbow and wrist >= 30 deg;
  - the rake drives the claws down (24.6 m/s, to 1.23 m);
  - the slash cuts down through the middle (34.7 m/s, side +0.03 m);
  - the check is a sideways lurch (11.7 m/s).
  - Worst stretch: 9.33, in check_right (a 2.8 cm edge in the left hand, limit 10).
- `t_sp_allosaurus`: **PASS**. New checks:
  - the ClawTip offset runs along the hand;
  - in the engine, every attack's claw tip travels > 1.0 m (the other > 0.4 m) and the elbow and wrist each bend > 25 deg;
  - each new move is picked only in its range and arc (the check by side);
  - its ring covers her before the hit;
  - it lands; the slash bleeds and the rake doesn't; the check throws her > 1.5 m sideways.
- `t_hitboxes`: **PASS**. It now also covers `tactics.moves` rows: front moves at the middle and far end of their range, the checks at 60 and 90 deg on each flank. Calibrated radii are in AL8.
- **Carno kit in `t_sp_allosaurus`** (seeded, like t_sp_carnotaurus):
  - the kit is on in its tactics;
  - the combo plays its own clip and opens with its tell (ring, no chomp yet), then 3 chomps land;
  - for a landed hit and for a damage-roll miss: the charge knocks her down, runs on through her (pass-through on, still above 60 % speed), arcs round wide (yaw <= speed / radius and <= turn_rate, slip under 2 deg) and charges back;
  - the charge doesn't bleed;
  - after its charges land it closes in for the combo;
  - the pass-through exception is gone afterwards.
- t_sp_carnotaurus: PASS. t_styraco: PASS.
- `check_allo.py` also gates `bite_combo`: each chomp is at least 1.5 m down and never pulled back, and the arms move.
- Shots: `carnokit_chomp_combo_sheet.jpg` shows chomp left, chomp right, the rear-up tell and the MEGA chomp; the frames are in `hit_frames/bite_combo_*`.
- t_knockdown, t_combat, t_tactical, t_canim, t_raptorflank: PASS.
- `run_all.gd`: **[tests] PASS**. `tools/audit_gaits.py --gate`: **GATE PASS**. `tools/smoke.sh --no-import`: **SMOKE PASS**.

## Shots (`docs/orchestration/reports/allofeel/`)
They come from off-screen windowed runs of `allosaurus_lab` (`--position 6000,3000 -- --skip-charcreate --lab=allosaurus_lab --hits-only --close`). The survivor stands where the jaws land.
- `hits_close_sheet.jpg`, `hits_threequarter_sheet.jpg`: every attack at its hit frame, plus the held tells of the hatchet, rake, slash and checks.
- `arms_zoom_rake_grab_ram_check.jpg`: the arms close up.
- `hit_frames/`: every frame from the side, three-quarter and close cameras.

## Rebuild
`tools/gait/build_allosaurus.sh` builds the 4 new clips too. It needs the gitignored Tripo mesh for the rig step.
I built these clips from the committed `allosaurus.glb` with the same poser and `ground_clip.py` step, so the model is unchanged.

## Open (AL7-AL9 in `docs/vision/WildLandsMMO_Open_Questions.md`)
- **AL7:** the new moves' numbers are first guesses.
- **AL8:** the ClawTip offset rows and the calibrated radii.
- **AL9:** the "shoulder" check lands through the leg at survivor height.
- **AL10:** the carnotaurus kit numbers on the allosaurus (arc 6 m / aim 95 deg, charge shove 3.5 m, combo cd 7 s).
- The check rings sit beside the flank, but an attack on her side doesn't turn the camera; the owner should feel-test it in the fight lab.
