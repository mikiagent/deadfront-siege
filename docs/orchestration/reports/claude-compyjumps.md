# Report: COMPYJUMPS (compsognathus leaps, pounces, strafe jumps, landing hits, "Missed" text), Claude

Branch `claude/mmo-compyjumps`, cut from `origin/claude/mmo-overhaul` (cc79a457). Not pushed, not merged.

Milan's requests, verbatim:
- "new compsagnathus doesn't have a walk backward animation and should jump back similar to the deinonychus (far
  jumps, far pounces, far strafe jumps, combo moves, it can jump and miss the player)"
- added mid-run: "compsagnathus attacks aren't landing very often, it should land some attacks. also there should
  be a damage text that says "Dodged" "Blocked" or "Missed""

## Clips (Blender headless, no paid generation)
- **`tools/gait/make_leap.py`** (new) builds in-place one-shots for the Meshy/transplant biped rig: `hop_back`
  0.458 s, `leap_back` 0.667 s, `pounce` 0.75 s, `dodge_left` / `dodge_right` 0.417 s. It uses the shared
  anim_events phases: crouch 0-0.2, airborne 0.2-0.65 (the game moves the body only inside this window and lifts
  it on its own arc), landing squash, then recovery to rest.
  - Hind legs use two-bone IK. On the ground frames the toe tips stay on their rest prints. A crouch rolls the
    foot heel-up about the toe tip (digitigrade), so the ankle skin never folds into the ground.
  - In the air the feet tuck: up to 11-17 cm at game scale.
  - The pounce opens the jaws 28 deg in the air and snaps them shut at hit_frac 0.7, with the arms thrown
    forward. The hops hiss the jaws open 10 deg.
  - The tail counter-pitches against the body, so its tip never swings into the ground. A dodge banks into the
    direction of travel.
- **`walk_back`** is replaced by a real backpedal loop built for this rig:
  `make_gait.py ... compsognathus.json strafe --as walk_back --travel 0,1,0`, 0.625 s.
  - The old one was v1's walk reversed: 2.42 s, a long stretched stride. That is probably why Milan saw "no walk
    backward".
  - Natural speed `natural_speeds.compsognathus.walk_back` is 0.576 m/s (`_len` 0.625).
- **`tools/gait/check_leap.py`** (new) is the verifier. It measures on the skinned mesh: ground penetration
  against the rest pose, planted toe slide on the ground frames, feet peak and jaw maximum. It also renders side
  and front frames.

| clip | len | penetration | planted slide | feet peak | jaw max |
|---|---|---|---|---|---|
| hop_back | 0.458 s | -0.18 cm (= rest pose) | 0.00 cm | 11.3 cm | 9.8 deg |
| leap_back | 0.667 s | -0.18 cm | 0.00 cm | 17.0 cm | 10.0 deg |
| pounce | 0.750 s | -0.18 cm | 0.00 cm | 16.9 cm | 28.0 deg |
| dodge_left / right | 0.417 s | -0.18 cm | 0.00 cm | 11.4 cm | 3.9 deg |

On the new walk_back: -1.7 cm, the same as the shipped strafe loops from make_gait. `audit_gaits.py --gate` GATE
PASS.

`anim_events.json`: a `note_compsognathus` on each of these clips, plus the walk_back natural speed. Clip names are
already in `CreatureClips.OPTIONAL`, so nothing changed there.

## AI (`ai.json archetypes.swarm.tactics` only; pack_mule untouched)
All numbers are ASSUMPTIONs, logged as C1-C7 in `docs/vision/WildLandsMMO_Open_Questions.md`.
- **Back-offs are leaps.** `backoff: "scurry"` is removed for the swarm (the code path stays for herds).
  - A bite is followed by `leap_back` over 4 m; fillers and backsteps use `hop_back` over 3 m.
  - It never goes past `max_retreat_m` 5.5 m, its short leash.
  - The arc is `leap_height_per_m` 0.15.
- **Pounce.** Range 2-6 m, cooldown 5 s, telegraph 0.45 s, 1.6 x bite, 20 % overshoot by 1.5 m, 1.0 s recovery
  after a miss.
  - `approach_pounce` (new knob): it opens with a pounce on the way in. A lone compy does not.
  - The landing point is locked at take-off (already TacticalBrain behaviour). A sidestep after take-off misses.
- **Strafe jumps.** `strafe_m` 2.5, `w_dodge` 0.4, mixed with the strafe walk (`w_strafe` 0.5). In a surrounding
  pack a filler dodge jumps towards its own ring slot.
- **Combos.** dart, pounce, strafe -> dart, strafe -> pounce, backstep -> strafe -> pounce. `w_pounce` is scaled
  by pack_bold 1.3, alone 0.4, weak_prey 1.3 and enraged 1.4.
- **Landing.** Before: a walking survivor was never bitten. Compys trotted glued to her at 0.3 m with the bite
  blocked by the beat rule.
  - `bite_track`: the bite keeps lunging until its contact frame.
  - `chase_hop`: at her heels with no bite allowed, it hops back and chases again.
  - `slot_catchup_mult` 2: back to its ring slot at twice its circling pace after a jump.
- Code changes, all gated on those knobs:
  - `tactical_brain.gd`: `_approach_ring`, `_swing`, `_dodge_side`, `_circle`, `_hop` (then-approach).
- Docs: `docs/current/enemy-ai-template.md` (swarm extras, avoided-hit text).

## "Missed" text
- `CombatAvoid.TEXT[&"miss"] = "Missed"`, in the same grey and size as Dodged and Blocked.
- `CombatTuning.swing_outcome(acc, dodge)` splits the existing single roll into hit / dodge / miss. The odds and
  the number of RNG draws are unchanged.
- "Missed" shows for:
  - a failed accuracy roll (creature on survivor, creature on creature, survivor on creature);
  - a creature bite with the prey out of reach at the contact frame (`Creature._on_hit`);
  - a pounce that lands with her out of its jaws;
  - a survivor swing the creature stepped out of, or got behind (`Hunt._on_swing_hit`).

## Tests
- `t_swarm` PASS. New checks:
  - after a bite it jumps back (leap_back on 13 of 13 back-offs);
  - back-offs are leaps, never a scurry;
  - pounces from range (18 pounces, nearest take-off 2.3 m);
  - strafe jumps while circling (22 dodges);
  - a pounce whiffs when the survivor sidesteps after take-off: it flies 3.9 m to its locked point and recovers
    1.0 s;
  - landed share with real accuracy rolls: standing 0.59 (10 of 17), walking 2 m/s 0.72 (13 of 18).

  The old checks still hold: surround gap 179 deg (< 180, close to the line), plain bite 0.03, strafe-clip share
  0.91, flee, scatter, and bolder in numbers (15 vs 12 per minute).
- `t_dodgetext` PASS. New checks: "Missed" on the survivor (failed roll, out of reach at contact) and on a
  creature's plate (failed roll, stepped out of the swing).
- `t_tactical`, `t_canim`, `t_labspawn` PASS. all_tests and smoke: see the end of this file.

## PNGs (`docs/orchestration/reports/compyjumps/`)
- `hop_back.png`, `leap_back.png`, `pounce.png`, `dodge_left.png`, `dodge_right.png`, `walk_back.png`: 8 frames
  each, side row over front row (Workbench, in place: the game adds the travel and the arc).
- `walk_back_old_vs_new_side.png`: the old reversed walk on top, the new backpedal below.

## Known issues / next agent
- The surround-gap check passed at 179 deg against a 180 deg limit. Leaps and pounces throw members off their slots.
  If it flakes, raise `slot_catchup_mult` before touching the test.
- Thin diagonal lines show at the legs on rest-pose frames in the Workbench renders. They are also on the shipped
  attack_primary frame 0, so they come from the renders, not from these clips.
- I made no in-game clip-viewer recording. The strips stand in for it.

Credits: none (Tripo 0, Meshy 0, Higgsfield 0).

## Gates (final code)
- all_tests: 132 tests, pass=130 fail=2 on the loaded machine. The two failures, each rerun alone:
  - `t_buildspeed` failed a timing budget (2534 ms against 2500 ms). It passed when rerun alone.
  - `t_tribe` failed "the member mined" twice. It passed on a rerun, and it also passed on a clean checkout of
    the base in a temporary worktree (since removed). It is load-flaky, not a regression.

  So fail=0 with the reruns. `t_save` passed inside the suite.
- `bash tools/smoke.sh --no-import`: SMOKE PASS.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
