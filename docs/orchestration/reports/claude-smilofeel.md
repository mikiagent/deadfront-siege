# SMILOFEEL: a bigger smilodon that chases in bursts, makes long leaps, pins and mauls

Branch `claude/mmo-smilofeel`, cut from `origin/claude/mmo-overhaul`, with canon merged back in (allocharge, dilofrill) before the final gates. Pushed, not merged to canon.

Owner, from the god-mode fight lab, verbatim:
- "make smilodon bigger and give it more maul style attacks, pin attacks, large leap attacks"
- "when it chases after the player, it shouldn't follow so closely, it should just jump towards the player and bound toward them. burst movement"

Credits: none. The two new clips were keyed in headless Blender on the existing rig.

## What shipped

### 1. Size
- `height_meters` goes from 2.0 to 2.5 (+25 %). This is marked `# ASSUMPTION` in `smilodon.json` `size_note`.
  - The shoulder is now about 2.0 m and the body about 4.4 m long.
- natural_speeds scale with height on their own, so the gaits still match the ground: run 7.77 m/s, sprint 15.83, lope 4.52. t_smilorun now compares against the height-scaled value.
- Hitbox radii were re-calibrated with `t_hitboxes -- --calibrate --species=smilodon`:
  - swipe 1.06 -> 0.74
  - lunge 0.85 -> 0.53
  - pounce 0.91 -> 1.28
  - pin_stab 0.76 -> 0.99
  - new rows: `leap`, `long_leap`, `maul_bite`
- The `leap` row has a window of 0.62-0.8. Without it, the bound strike was judged mid-flight (the leap clip has no hit_frac), and at the new size it missed every time.
- The throat crit spot scales by 1.25: offset [0, -0.41, 0.26], radius 0.25.

### 2. Burst chase (`tactics.pulse`, `TacticalBrain._pulse_prowl`)
Everything below applies while she runs away:
- **Bounds:** 5-15 m (was 4-12), with `bound_cd` 1.2 s (was 1.8). Each bound lands `land_short_m` 1.3 m short of her, which puts her under the forepaws, where the strike and the pin happen. Before, it landed 0.8 m short, under the chest.
- **Pause:** a bound that doesn't strike is followed by a 0.4 s planted, crouched pause (`pause_s`) facing her.
- **Prowl:** within 6 m (`hold_m`) it no longer runs at her heels. It creeps after her on the stalk clip at 1.6 m/s, and holds still within 3 m. As she pulls away she comes back into bound range.
- **Burst sprint:** it now starts only on a gap of 9 m or more (`burst.min_m`, was 3) and is cut off at `hold_m`.
- **Escape is still very hard:**
  - With the strike on, a full-sprint survivor is caught in 0.95 s (t_smilorun).
  - With the strike held off, she is never more than 8.5 m clear after 8 s.
- Shot: `smilofeel/fight_chase_high.png`. It shows about five bound-then-pause cycles in 6 s.

### 3. Long leap (`tactics.long_leap`, new clip `long_leap`, 1.4 s)
- It reuses the pounce machinery (`_start_pounce(&"long_leap")`), so it has the same ring telegraph and the same roll fairness.
- **Range:** 8-14 m, judged where she will be when it lands. It is effectively 8 to about 12 m, because the aggro ring is about 12-13 m.
- **Timing:** a 0.5 s crouch telegraph, then airborne from 0.2 to 0.7 of the clip.
- **In the air:** both forelegs are thrown far forward with the claws out and the jaws wide, while the hinds trail.
- **Landing:** the forepaws slam down at 0.7 and the sabres drive in at 0.74. The strike does x1.6 and is judged by the `long_leap` hitbox.
- **When it fires:** as the opener on approach, after a hop back off the ring (new `backstep_long_leap` sequence), and in a chase.
- **Pin and maul:** a landing that hits her pins her into the maul.
- Shots: `fight_leap_air.png` and `clips_sheet.jpg` (top row).

### 4. Pin (PINFEEL rule)
- With `tactics.pin_hold`, every smilodon pin goes through `PinHold`:
  - `can_start`: she must already be within 0.6 x height of the right forepaw. That is true only after a leap, pounce or bound strike has actually landed on her.
  - `lay_down`: she is put on her back.
  - `snap`: she is slid under the paw at no more than `pin_slide_mps`.
- New `big_stomp.species.smilodon` row: pin under `FrontFoot.R`. There is no big_stomp clip, so the cat does not stomp.
- While it holds her, the cat no longer turns on its feet.
- Shot: `fight_pin.png`.

### 5. Maul (new clip `maul_bite`, 2.6 s)
- The clip is timed exactly like the shared MAUL BITE:
  - hit_fracs 0.24 / 0.5 / 0.74
  - release_frac 0.86
- Its `anim_events` row is byte-identical to the one on claude/mmo-maulbite.
- **Hit 0:** both forepaws come down on her and hold, and the sabres bite in (x1.2). If she wasn't already held, the bite pins her.
- **Hits 1 and 2:** two head-shake worries (x0.6 each), each with one forepaw raking back.
- **Release:** the jaws open at 0.86 and she is let go.
- The hind paws stay planted throughout.
- **When it fires:**
  - point blank in front (`point_blank` now starts with `maul`, `maul_cd` 7 s);
  - as the pin's clip after a long leap.
  - The pounce and the bound still pin into `pin_stab`.
- maulbite is not on canon, so the smilodon lands its own maul hits in `TacticalBrain._maul_tick`, the same way `MaulBite._step` does. `maul_bite` stays out of `ATTACKS`, as maulbite has it.
- Shot: `fight_maul.png`.

### 6. Feet and teleports
- The pinned survivor slides at most 0.05 m a frame (3 m/s).
- During the maul, the hind paws drift 0.000 m.
- t_noteleport passes for the smilodon.
- The maul clip's hinds and the long leap's landing hinds both sit on their rest prints. An earlier version had a 0.13 m offset, which made the blend between them slide.

## Gates

| Gate | Result |
|---|---|
| `t_sp_smilodon`, extended | PASS (see below) |
| t_smilorun | PASS |
| t_noteleport (`NOTELEPORT_SPECIES=smilodon`) | PASS |
| t_hitboxes | PASS |
| t_critspots | PASS |
| t_knockdown | PASS |
| t_combat | PASS |
| t_stunlock | PASS |
| t_pinfeel | PASS |
| t_tactical, t_bigstomp, t_sp_majungasaurus (shared `_pin` / `_hold_victim`) | PASS before the merge |
| After the merge: t_sp_smilodon, t_smilorun, t_noteleport, t_hitboxes, t_critspots, t_knockdown, t_combat, t_stunlock, t_pinfeel, t_sp_allosaurus, gait audit | all PASS |
| `audit_gaits.py --gate` | GATE PASS |
| `check_smilodon.py --height 2.5 --reach 1.5` on the new clips | SMILODON_CHECK PASS |
| `run_all.gd` (after the canon merge) | `[tests] PASS` |
| `tools/smoke.sh --no-import` (after the canon merge) | SMOKE PASS |
| t_canim | skipped: it fails the same way on canon e32ea4e22 (styracosaurus, therizinosaurus, triceratops, utahraptor and carnotaurus: `_on_damaged` hit_react) |
| t_noteleport, full roster | fails on canon too (compsognathus kick, gallimimus dodge). The smilodon passes. |

The new checks in `t_sp_smilodon`:
- **Size:** 2.5 m.
- **Burst chase:** 9 pulses in 8 s. 54 % of frames are under 3 m/s. The longest steady run within 5 m of her is 0.27 s (limit 1.0). It bounds 7 times and she is never more than 8.5 m clear.
- **Long leap:** it flies 10.3 m and gets 1.23 m off the ground. At the top the forepaws are 2.36 m ahead. The strike lands, she is pinned, and all three maul hits land.
- **Pin only when landed:** a long leap that lands on nothing never pins her, and a pin asked for with her 6 m away does not start.
- **Maul:** bite plus 2 worries land, the bite pins her, it lets go afterwards, and the hind paws drift 0.000 m.

`check_smilodon.py` also gained hit checks for the new clips and a "hind paws hold their prints" check on the maul.

## Shots (`docs/orchestration/reports/smilofeel/`)
They come from an off-screen windowed run with the live brain and a GOD survivor. The run quits by itself:
`Godot --path game --position 6000,3000 -- --skip-charcreate --lab=smilodon_lab --out=DIR --fight`.
- `fight_leap_air.png`: the long leap in mid-air, forepaws out, with the telegraph ring on her.
- `fight_pin.png`: she is on her back under the forepaws, head out in front.
- `fight_maul.png`: head down on her, sabres in, mid-worry.
- `fight_chase_high.png`: the burst chase seen from above. There is one dot every 0.1 s, colored by the cat's speed. The bounds are spread out and the dark-red pauses show between them.
- `clips_sheet.jpg`: long_leap and maul_bite posed at 10, 40 and 74 %, with the survivor for scale.

I looked at every image. The fight shots needed `reset_physics_interpolation()` on the moved camera and dots. Without it, the project's physics interpolation swept the camera in from its last position.

## Assumptions (every number is an `# ASSUMPTION`)
- **Size:** 2.5 m.
- **Pulse:** pause 0.4 s, hold 6 m, keep 3 m, prowl 1.6 m/s.
- **Bound:** 5-15 m, cooldown 1.2 s, lands 1.3 m short.
- **Burst:** starts on a gap of 9 m or more.
- **Long leap:** 8-14 m, 0.5 s telegraph, x1.6, cooldown 8 s, energy 14.
- **Maul:** bite x1.2, worries x0.6, cooldown 7 s.
- **Pin:** under the right forepaw, `pin_reach_frac` 0.6.
- **Clip shapes:** tuned by eye on the sheet.
- **SM4 still stands:** a 100 HP survivor dies to the leap alone outside GOD mode.

## For the next agent
- **When claude/mmo-maulbite lands:**
  - `anim_events.maul_bite` is identical, so it should merge clean.
  - The ONESHOT, OPTIONAL and FIGHT_CLIPS list lines will conflict. Resolve them as the union.
  - To move the smilodon onto the shared move, add `"smilodon": {}` to `ai.json maul_bite.species`, then drop `_maul_tick`. The clip, the timing and the hitbox row (`moves.maul_bite`, Head) are already in place. MaulBite reads the first part as the jaw. Our part is Head, so check its reach with `t_maulbite -- --calibrate`.
- **Pins:** the pounce and the bound still pin into pin_stab; only the long leap and the clinch use the maul. If Milan wants more mauls, give `_start_pin` a chance for the pounce, but first re-key the pounce's landing hinds onto their prints, or the blend into the maul slides them 0.25 m.
- **Untested combination:** a long leap into a survivor who rolls. It uses the pounce's roll window, but was not looked at on its own.
- **Disk:** this worktree is a sparse checkout without the old report image folders. The disk was full when I started.
