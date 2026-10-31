# STEGOSLAM: the stegosaurus gets the ankylosaurus' body-weight slam

Branch `claude/mmo-stegoslam` was cut from the stegospin head and merged with canon after stegospin landed (a0d9bf1d0).
No credits spent.

Owner, 2026-10-31: "give stego that body weight slam you have to ankylo".

## What shipped
- **The clip.** `tools/gait/make_stego_moves.py` makes `shove_right` and `shove_left` as the ankylosaurus' slam on the
  stego rig, 1.8 s:
  1. It cocks away (0-0.22).
  2. A bound: all four feet are off the ground, airborne 0.24-0.42 (the same anim_events window as the ankylosaurus).
  3. It lands with the near feet wide and drives the shoulder down and over into her (impact 0.46).
  4. It rocks back, re-plants and steadies.

  Both looks (graded, ochre) share the rig and clip. `check_stego_moves.py` PASS (slide 0.000, stretch 3.7).
- **ai.json `spiked_tail.close_moves.shove_*`.** The same keys as the ankylosaurus:
  - `carry_m` 4.0 (ASSUMPTION: about a body length, times size);
  - `slam_point` [±1.3, -1.4] (where the clip drives the near foreleg at impact, measured);
  - `leap_height_m` 0.3, strike [0.46, 0.5], knockdown.

  `close_zone.side_max_m` went from 4.6 to 6, so it starts from its flank range. ClubTailBrain needed no change.
- **Rear slam.** `target_bearing_deg` 15 / `target_dist_m` 2.4, so she stands in front of the right forefoot. At some
  genome sizes the two forefeet straddled a survivor stood dead ahead.

## Tests
- **New in t_stegospin:** for graded and ochre, each side, she stands 5 m off the flank. The slam starts, throws the body
  at least 3 m (measured 3.3-3.5 m) and lands.
- **Fix in t_stegospin's tackle case:** she now stands at 8.7 m × body size. Genomes vary the size from 0.87 to 1.14,
  and at small sizes a fixed 9.5 m was outside the front zone.

## Gates (head after the canon merge)
t_stegospin, t_ankyloclose, t_ankyloopen, t_hitboxes, t_knockdown, t_plantedflinch, t_combat, t_bigstomp: PASS.
run_all: [tests] PASS. `tools/smoke.sh --no-import`: SMOKE PASS.

## Lab shots (`docs/orchestration/reports/stegoslam/`)
`--lab=stegospin_lab --moves=shove_right,shove_left`, both looks, from 5 m off the flank: wind-up, airborne, hit.
The left-side shots include the hit frame. In the right-side lab runs the survivor is already lying down by the airborne
frame, so there is no hit frame. t_stegospin lands the right side, so this is a lab staging issue; I did not chase it.
