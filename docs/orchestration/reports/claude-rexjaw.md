# claude-rexjaw: the T. rex's jaw in its bite clips

Owner 2026-10-31: "tyrannosaurus rex jaw is not moving correctly in bite animations, fix or i will make a new model".
Branch `claude/mmo-rexjaw` (from `claude/mmo-overhaul` fde2d3340, canon e32ea4e22 merged in). Regular tyrannosaurus only;
megarex and tarbosaurus files untouched.

**Verdict: FIXED.** No new model needed. The mesh opens cleanly; the clips were turning the jaw the wrong way.

## What was wrong (measured on the deformed skin)

| clip | widest jaw before | direction | worst skin stretch before |
|---|---|---|---|
| attack_primary (bite) | 50 deg | **up through the skull** | 21.7x |
| attack_heavy (stomp) | 38 deg | **up** | 16.5x |
| alert (roar) | 48 deg | **up** | 21.0x |
| roar (THERO-ROAR) | 47 deg | down (correct) | 22.2x |
| big_stomp, pin_foot, idle, tail_swipe | 37 / 37 / 9 / 26 deg | **up** | |

- Cause: `tools/gait/make_rex_moves.py` turned the Jaw about the bone's own +X. On this rex rig +X swings the tip up
  (on megarex and tarbosaurus +X opens, which is why those look right). Every clip it authored for the regular rex
  had the lower jaw flipping up over the snout. `before/attack_primary_full.png` shows it.
- Not the cause: the Jaw bone exists, is parented to Head, pivots at the hinge, and turns on the head's side axis
  (no sideways jaw); skin held 100 % by Jaw follows it rigidly; the skull does not bend. Every clip has jaw keys.
- Second problem, in every clip that opens the mouth (the roar too): open_mouth.py left the mouth corner as a hard
  100 % Head / 100 % Jaw seam, so 2 cm edges became 40 cm slivers at full gape, and the throat under the jaw jumped
  from Jaw straight to Neck1, partly bound to Arm.L (1.2 m from the arm), so the roar's head throw stretched it 1.4 m.
- Bite timing was right once flipped: wide (44 deg) at frame 15, shut with a 3 deg clench at frame 17 for the
  hit at 0.42 (frame 16.8).

## What shipped

- Clips: `tools/jaw/fix_jaw_keys.py` rewrites only the Jaw rotation keys in place (every other byte of the clip is
  unchanged): mirrors them about the hinge in alert, attack_primary, attack_heavy, big_stomp, idle, tail_swipe,
  pin_foot, and caps the widest gape at 44 deg (bite 50 -> 44, alert 48 -> 44, roar 47 -> 44). Stomp 38, pin 37.
- Mesh weights: `tools/jaw/blend_corner.py --radius 0.5 --arm-reach 0.8 --seed-clip anim/roar.glb@58` averages the
  weights of the head/jaw/neck skin around every edge that stretches past 3x (at a 40 deg gape and at the roar's
  worst frame), fading out over 0.5 m, so the corner opens like a cheek fold; arm weights are taken off head/neck
  skin more than 0.8 m from the arms. 1307 verts change; only their JOINTS_0/WEIGHTS_0 bytes are rewritten.
- `make_rex_moves.py` picks the jaw sign per rig (`JAW_SIGN`), so a rebuild can't bring the bug back. Megarex and
  tarbo get +1 (unchanged); regenerating the rex bite with it opens 50 deg down as it should.
- Gate: `tools/gait/check_rex_jaw.py` (Blender, deformed skin). Per clip: widest gape 30-46 deg, never closing
  past -5 deg, hinge on the head's side axis (>= 0.98), Jaw skin rigid (<= 2 cm), skull rigid (X = 5 cm), no
  head/jaw edge past 3x, bite open >= 30 deg before the hit and shut within one frame of it.
- `game/scripts/dev/rexjaw_lab.gd` (`--lab=rexjaw_lab --shot-dir=DIR`): in-game side close-ups at closed / half /
  full open per clip, phases read from the Jaw bone.

## Gates (after merging canon e32ea4e22)

| gate | result |
|---|---|
| check_rex_jaw (attack_primary, attack_heavy, roar, alert) | before 4/4 FAIL; **after 4/4 PASS**: gape 44 / 38 / 44 / 44, stretch 2.33x / 2.12x / 2.65x / 2.33x, skull 0.5 cm, jaw 0.6-1.0 cm, snap 44 deg before the hit, -3 deg on it |
| check_rex_clips (feet) | identical to before: same 14 pass, same 5 old failures (death, feed, hit_react, knockdown, sleep) |
| t_rexclips, t_theroroar, t_spacingstomp, t_hitboxes, t_critspots, t_combat | PASS |
| run_all | [tests] PASS |
| tools/smoke.sh --no-import | SMOKE PASS |
| t_canim | FAIL, skipped: 10 lines, all `_on_damaged starts hit_react` on carnotaurus, styracosaurus, therizinosaurus, triceratops, utahraptor; none on the rex, and this branch changes only rex files |

## Shots

`docs/orchestration/reports/rexjaw/{before,after}/<clip>_{closed,half,full}.png`, from off-screen windowed runs
(`--position 6000,3000`, self-quitting, `-- --lab=rexjaw_lab --skip-charcreate`), the same camera for both. The
before set was shot with the old GLBs swapped in and re-imported, then the fixed ones put back (checked byte-equal).

## Not fixed, for the next agent

- Inside the mouth at close range: the lip lining is jagged and a few shards of the original Tripo mouth interior
  poke through the mouth floor (`after/roar_full.png`, which faces the camera). This dates from the mmo-jaws mouth
  bag (blind A/B winner); it reads as an open mouth at game distance. A cleaner interior needs a re-cut of the lining in
  open_mouth.py, or the new model.
- The roar's skyward head throw still crumples the throat skin under the jaw (seen in a Blender close-up at frame 58;
  not in the shot set). That's the THERO-ROAR neck pose, not the jaw. The worst edge there is now 4.2x, down from 20.4x.
- 458 neck/chest verts lost their arm weights (these sit more than 0.8 m from any arm bone). The foot gate and every
  combat test are unchanged, but a close look at the arms in the roar flail would confirm it.

Credits: Tripo 0, Meshy 0, Higgsfield 0.
