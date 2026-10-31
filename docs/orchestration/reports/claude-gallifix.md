# GALLIFIX: the gallimimus face and passive-aggressive behaviour

Owner, verbatim: "gallimimus model, face looks mangled or something. give it passive aggressive behavior like the compy".
Branch `claude/mmo-gallifix`, cut from `origin/claude/mmo-overhaul` 30e08c30. Pushed, not merged to canon.

**Credits: 0.** The Tripo retry was not used. The mesh was fine; the rig was the problem. Balance stays at 1675.

## 1. Face
**Cause.** The Jaw bone's roll came out skewed: add_jaw.py ran without `--x-side`. Every jaw key in the clips therefore yawed the lower beak sideways out of the face instead of opening it. The lower beak stuck out of the side of the mouth in the display, the kick, the idle hiss and every bite. On canon the jaw tip sits up to 24 cm off the upper beak's line (alert 0.243 m, attack_heavy 0.229, bite_combo 0.226, attack_primary 0.203; feed, hit_react and the bounds 0.16-0.17).

**Fix** (`tools/gait/build_gallimimus.sh`, rebuilt):
- `add_jaw.py ... --close 38 --x-side --ramp 0.6`:
  - `--x-side` rolls the Jaw so +X is the animal's left;
  - make_galli_moves.py now keys + as open (it was keyed with the opposite sign);
  - `--close 38` shuts the modelled gape in the bind pose.
- The new opt-in `add_jaw.py --ramp` widens the stretch of skin over which the snout fades from neck weights to rigid skull or jaw (default 0.3, unchanged for other species). At 0.3, the half-neck-weighted mouth corners stretched 2.3x when the peck pitched the skull down.
- The display and kick gape is down from 30 to 24 deg.

**New check_galli.py gate.** Head and jaw skin edges may stretch at most 2.0x in any frame, and the lower beak tip must stay within 6 cm of the upper beak tip sideways (standing clips; a lying body turns the head's side axis).

| | canon (before) | gallifix (after) |
|---|---|---|
| jaw skew, worst clip | 0.243 m (alert); 17 of 20 clips fail | 0.042 m (bite_combo) |
| face stretch, worst clip | 2.40 (attack_primary) | 1.83 (bite_combo) |

Close-ups: `docs/orchestration/reports/gallifix/face_before.jpg` and `face_after.jpg`. Each has rows for rest, the display gape, the peck hit and the kick hit, from the side, three-quarter and front. Before: the lower beak juts out sideways in the display and the kick. After: the beak opens straight down and closes cleanly at rest.

## 2. Passive-aggressive behaviour
Before, a chased gallimimus turned and fought for `fight_s` (14 s), then dropped the fight and wandered off 25-27 m. It made one attack a minute.

The fix is a new opt-in `cornered.hold_m` / `hold_s` in `brain_cornered.gd` (gallimimus only: 25 m, 4 s):
- Once engaged, it keeps the fight while the survivor stays within 25 m.
- Its back-offs are the brain's own hop_back, leap_back and side bounds (out to about 15 m), then the sprint back in to the peck, kick or peck-peck-kick. It never makes a long flight.
- It still keeps away from a survivor who leaves it alone (a chase turns it, as before).
- 4 s after she leaves the 25 m ring, it lets her go.
- Under 30 % HP it runs.
- `carry_s` stays at 6 s: it turns about 4 s into a 7 m/s chase, which is fine.
- It still runs from much bigger things through the normal flight brain. I did not touch or test that.

Measured in t_sp_gallimimus over a 60 s engaged fight against a survivor standing her ground (GOD on):

| | before (hold off) | after |
|---|---|---|
| fleeing | 1.0-2.7 % | 0 % |
| out of the fight | 89-90 % | 0 % |
| attack starts a minute | 1 | 12-13 |
| farthest from her | 25-27 m | 14.9 m |

Gate (ASSUMPTION GM7): fleeing at most 10 %, out of the fight at most 10 %, at least 6 attacks a minute. Also checked: she walks 60 m away and it lets her go.

## Gates
| check | result |
|---|---|
| `check_galli.py` (with the face gate) | GALLI_CHECK PASS, 20 clips |
| `audit_gaits.py --gate` | GATE PASS |
| t_sp_gallimimus | PASS (5 runs) |
| t_hitboxes, t_knockdown, t_noboxes, t_combat, t_data, t_coelomoves, t_hopstrafe, t_tactical, t_ai, t_mounts, t_saddles, t_labspawn, t_godlab, t_plantedflinch | PASS |
| `run_all.gd` | `[tests] PASS` |
| `smoke.sh --no-import` | SMOKE PASS |

Failing on canon as well, so not caused by this branch:
- t_canim: styracosaurus hit_react;
- t_cornered: "stegosaurus hits the survivor after turning". It fails the same way with this branch's brain_cornered.gd change reverted.

## How to test
1. Run `Godot --path <this worktree>/game -- --lab=creature_lab --god --skip-charcreate`. SPAWN → Gallimimus.
2. Look at its face up close (H shows the hitboxes). The beak gapes straight down in the display and the kick, and closes at rest.
3. Walk up and stand still: it bolts and leaves you alone.
4. Chase it until it turns, then stand your ground. It keeps coming: peck, kick, bound back about 15 m, sprint in again. It never runs off while you stay within 25 m.
5. Walk 30 m or more away and it lets you go. Knock it under 30 % HP and it runs.

## Merge notes
`brain_cornered.gd` (hold_m and hold_s, opt-in), `add_jaw.py` (`--ramp`, default unchanged), `gallimimus.json` tactics.cornered, the gallimimus GLB and clips, check_galli.py, t_sp_gallimimus.
