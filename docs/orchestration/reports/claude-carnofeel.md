# CARNOFEEL: the carnotaurus charge runs through her, chomp combo, turning radius

Branch `claude/mmo-carnofeel`, cut from `origin/claude/mmo-overhaul`, canon merged again at the end (majungasaurus,
spinosaurus, cooldown-ui, knockroot + windedenergy). Pushed, not merged to canon. Credits: none (no Tripo, no Meshy).

Owner, after the god-mode fight lab: "carnotaurus charges the player and gets stuck on the player model. ideally when it
charges the player, the collision causes the player to get knocked on his ass and fall over. Don't let the carno get
stuck on the player ... Carno should have some chomp attacks like the 3 combo chomp on deinonychus. Its turning speed is
quite fast, maybe slow it down a bit or make it have a turning radius after charging." Earlier: "I love the way it attacks".

## Why it snagged
Two causes, both in shared `TacticalBrain` straight-charge code (carnotaurus, triceratops, woolly rhino, megaloceros,
pack mule):
- The charge steered with `move_to` toward a goal 9 m past her. The nav path ran straight into her capsule, and
  `move_and_slide` stopped the animal against her body until the line timed out.
- The shove that clears her only ran when the damage roll landed. A passive dodge, an accuracy miss or similar left her
  standing in the path, and the animal ground against her.

## What shipped
**1. Charge contact (shared code, `tactical_brain.gd`).**
- The straight charge now drives its locked line (`line_dir`), like the styracosaurus impale run already did. It ends
  when it passes `charge_through_m` beyond her spot.
- Pass-through: during a charge (and its arc or hop-turn), and `charge_pass_s` (0.6 s) after it, a charger and a
  smaller target ignore each other's bodies. The exceptions go both ways and come off again afterwards, never while she
  is still under its footprint, and also when the animal leaves the tree. "Smaller" means shorter `height_meters` x
  size; the survivor counts as 1.8 m. Every straight or impale charger taller than her benefits (styracosaurus,
  triceratops, woolly rhino, megaloceros, carnotaurus).
- Contact knocks her down through `PlayerSim.shove` -> `PlayerKnock`, even when the damage roll misses. Only a roll's
  i-frames get her through. Contact is the horns' hitbox, or, when the horns pass over her, her centre inside its
  footprint (`_body_over`). The carnotaurus' 3.5 m x size 1.5 is the throw tier: she is hooked 60 deg off the line, lands
  on her butt, lies, gets up winded.
- A think the shared rules take over (a disengage) clears `line_dir`, so a charge line cannot keep driving the body.

**2. Chomp combo (`bite_combo` on the carnotaurus rig).**
- New clip in `tools/gait/make_carno_moves.py` (and `build_carnotaurus.sh`), 2.75 s, on the deinonychus' hit fractions
  0.092 / 0.338 / 0.815. It plays: coil with the jaws gaping, chomp to its left, chomp to its right, rear up with the jaws
  wide and trembling (the tell 0.5-0.667), then a MEGA chomp slammed down through the middle and a head shake.
- Each bite really opens and shuts the Jaw, with a head lunge (body forward, neck and head dip). The feet stay
  IK-planted.
- `check_carno.py` gates it: the jaw is ahead and moving at each of the three hit frames, it gapes before each and shuts
  on each, and the feet stay planted.
- Hits go through `hitboxes.json` `carnotaurus.moves.bite_combo` (Jaw 2.48 m and Head 2.55 m, both calibrated with
  `t_hitboxes.gd -- --calibrate --species=carnotaurus`; the `--species` filter is new).
- The tell: the coil before the first chomp plays at 0.3x speed (`combo_tell_scale`, about 0.55 s) with the combo ring
  4.4 m ahead at its jaws (`combo_ring_ahead_m`, a new optional knob in `Telegraph.show_for`). The rear-up before the
  MEGA chomp rings again, as on the deinonychus.
- Wiring: `point_blank` is now combo, heavy, bite. After its charges land, it dashes in for the combo
  (`charge_follow`, `lunge_max_s` 2.5). A 60 s headless fight against a standing survivor gave 33 charges, 16 combos,
  16 hops back and 5 roars: the loop goes charge, return pass, arc, dash in and chomp, back off, charge.

**3. Turning.**
- `turn_rate` is now 1.4 (was 2.0).
- After every charge it arcs instead of hopping round (`charge_arc_r_m` 5 m x size). It slows to 1.3x its run over
  0.8 s, and the yaw is speed / radius, capped at turn_rate.
- The body travels exactly where it faces (`own_yaw`, a new brain flag that Creature honours), so the stride-matched
  run never skids.
- While she is inside the circle it would wheel on, it runs on straight first (the overshoot). Once it faces her within
  15 deg, it makes the one return pass. If it is still not round after 5 s, there is no return pass.
- The `charge_turn` hop clip stays in the pack, unused by the carnotaurus. Other species keep the hop.

## Shots (`docs/orchestration/reports/carnofeel/`, from `--carnoshots=DIR`, windowed off-screen, self-quitting)
- `carno_0_contact.png`: the head hits her and she is launched.
- `carno_1_passing_her_falling.png`: she falls under its belly while it runs on.
- `carno_2_run_through.png`: she is down behind it and it is still at full run.
- `carno_3..7_arc*.png` (high camera): its track is drawn as dots, orange on the line and red round the arc. It is a
  wide U, not a pivot.
- `carno_8_combo_tell.png`: the gaping coil, with the yellow ring at its jaws.
- `carno_chomp_1/2/3.png`: each chomp at its hit frame (left, right, MEGA).

Reviewed by eye:
- The run-through and the arc read right.
- The side chomps close at about 2 m, just above her head and about 1.5 m in front of her, which is why the calibrated
  radii are large. The MEGA chomp comes down to her head.
- The lab rolled the alpha skin in this run.

## Gates (final tree, after merging origin/claude/mmo-overhaul 91f348a6)
- `t_sp_carnotaurus` PASS. New checks:
  - the combo is a point-blank move and opens with its tell (ring, no chomp yet);
  - 3 chomps land (3 hit frames, 3 damage events);
  - for a landed hit and for a damage roll that misses: contact knocks her down (knockdown/throw tier); it runs
    through her (pass-through on, lowest speed after contact 15.4 m/s, about 5 m past her); it arcs round (yaw
    1.40 rad/s against turn_rate 1.40, radius at least 6.7 m against the 5 m limit, slip 0.0 deg); it charges back;
  - after its charges land it closes in for the combo;
  - the exception is gone once the animal is.
  - With the pass-through switched off, the run-through check FAILS (the speed drops to 6.1 m/s), so it catches the snag.
- `t_hitboxes` PASS, `t_knockdown` PASS, `t_styraco` PASS, `t_combat` PASS.
- `run_all` `[tests] PASS`. `tools/smoke.sh --no-import` SMOKE PASS.
- `tools/gait/check_carno.py --height 5.74`: CARNO_CHECK PASS (17 clips).
- **`t_noteleport` is flaky, on canon as well.** Three runs on this branch failed on different species each time:
  - compsognathus kick;
  - gallimimus hop, megarex bite, raptor kick and woolly rhino kick (that run was under load from run_all);
  - raptor flank.

  Two runs alone on a clean `origin/claude/mmo-overhaul` 91f348a6 worktree failed the same way: deinonychus kick and
  gallimimus leap_back, then coelophysis kick. A third, earlier canon run passed. None of the failures involves a
  carnotaurus or a straight charge.

## ASSUMPTIONs
CF1-CF4 in `docs/vision/WildLandsMMO_Open_Questions.md`:
- pass-through rules and the 1.8 m survivor height;
- contact knocks down even on a damage miss;
- the arc numbers and turn_rate 1.4;
- the combo's tell scale, ring distance, cooldown, charge_follow and the lunge reach.

## For the next agent
- `tactical_brain.gd` hooks: `_tick_pass` / `_pass_end` / `_smaller` / `_body_over`, `_start_charge_arc` /
  `_charge_arc` / `arc_radius`, `_tick_combo_tell`, `charge_follow` in `_charge_end`.
- `creature_brain.gd`: `own_yaw`. `creature.gd`: one `elif` in the facing block.
- `creature_anim.gd`: `set_clip_speed`. `telegraph.gd`: `combo_ring_ahead_m`.
- On a merge, keep both sides of the `MOVES` list (`grab` from spinosaurus, `charge_arc` from here).
- Any charger can opt into the arc with `charge_arc_r_m` > 0, and into the follow-up with `charge_follow`.
- The new triceratops "megajoust" branch, if it adds its own charge, gets the pass-through and the knock-on-miss for
  free through `_tick_pass` and `_charge_impact`.
- Debt: the jaws sit about 6 m ahead of the centre and the reach is 4.6 m, so the bite and combo radii are calibrated
  big (2.5-2.7 m). A longer `reach_m` for the carnotaurus (as the tarbosaurus has) would let them shrink.
- Not done: the hop-turn clip is now unused by the carnotaurus. There is no new sound (the game has no audio system).
