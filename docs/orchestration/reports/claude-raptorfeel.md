# Report: RAPTORFEEL (velociraptor head tilts and curious, aggressive idle), Claude

Branch `claude/mmo-raptorfeel`, cut from `origin/claude/mmo-overhaul` (019a98b2). Pushed, not merged.

Milan asked for this (verbatim): "they gave this raptor like a head tilt and curious/inquisitive movement (similar to
compy but more aggressive)".

## What shipped
- **`investigate.glb`** (velociraptor, 4.0 s loop). It is built by the new `tools/gait/make_investigate_idle.py`, the
  same method as the compy's `make_nervous_idle.py`: small rest-relative turns keyed per frame, and two-bone leg IK
  onto the root-parented feet. The loop is seamless. What it does:
  - holds a low crouch: the body drops 20 % of hip height, the chest dips and the neck is carried low, with the
    snout kept level on the prey;
  - the head snaps between cocked tilts of 30 to 38 deg and holds each one;
  - it glances aside and does a double-take;
  - it cocks hard toward the prey with the jaw parted 11 deg (a silent hiss) while the crouch deepens;
  - the weight shifts in twitches rather than a sway;
  - the arms are held out and flex on the snaps;
  - the tail is stiff and lashes slowly, with a flick at the hiss.
- **`sniff.glb`** (1.5 s one-shot, `--clip sniff`). From the same crouch, the neck stretches to the ground ahead,
  the snout bobs with the jaw working, it tilts to inspect, then snaps back up with a cock.
- **AI (smallest change)**:
  - `CreatureAnim.play_idle(aware)`: when the brain is aware but not attacking, a rig that has an `investigate`
    clip plays it instead of `idle`. Aware means `CreatureBrain.aware_idle()`: state `alert` with a valid target.
  - `CreatureBrain._spot` plays `sniff` where the rig has it, and `alert` otherwise.
  - `RaptorPackBrain` ignored `alert` before (it charged on the next think). Species with an investigate clip now
    hold alert for 3 s: sniff, then investigate, then commit. A hit or prey inside reach ends the hold at once.
  - Only the velociraptor has the clips, so the deinonychus, utahraptor and the rest behave as before.
- `check_leap.py --grounded`: an additive flag that treats every frame as a ground frame. Without the flag the tool
  behaves as before.
- `creature_lab --clipsheet=DIR [--clips=a,b]`: in-engine contact sheets with the HUD hidden. The tree is stepped
  by hand, the creature's brain is off, and the lab quits by itself when done.

## Shots (`docs/orchestration/reports/raptorfeel/`)
- `velociraptor_investigate.png`, `velociraptor_sniff.png`, `velociraptor_idle.png` (the old idle, for comparison).
  They come from the creature lab, windowed at `--position 6000,3000` with `-- --skip-charcreate`, and the run quit
  by itself. Each sheet has 8 frames: the top row is head-on three-quarter, the bottom row is the side.
- `blender_investigate.png`, `blender_sniff.png`: Blender Eevee renders, textured, in three rows: three-quarter,
  side, and a head close-up. The cocks and the hiss read most clearly here.
- What I fixed after looking at the shots:
  - the first crouch was too shallow to read, so I deepened it and lowered the neck;
  - the tail rose like a scorpion's at the hiss, so I cut it from -12 to -9 deg;
  - the lab sheets had the HUD over them and missed the head, so I hid the HUD and reframed the cameras.

## Gates
- `check_leap.py --grounded` (feet grounded, no foot sliding):
  - investigate: slide 0.00 cm, penetration -0.41 cm, PASS;
  - sniff: slide 0.00 cm, penetration -0.36 cm, PASS.
- `python3 tools/audit_gaits.py --gate`: GATE PASS (no moonwalk). Walk and run are untouched.
- `audit_creature_deformation.py velociraptor`:
  - investigate: p99 edge ratio 1.22, max 8.9, on the mouth-corner edge that alert and the attacks also stretch
    (18-29); loop delta 0;
  - sniff: p99 1.22, max 4.7.
- `t_raptorfeel` PASS. It checks that:
  - both clips load, investigate loops and sniff is a one-shot;
  - the hind feet stay on the idle's ground with 0 slide, while the head turns 45-49 deg;
  - a spotted survivor brings alert, then sniff, then investigate, with the raptor holding still;
  - after the hold the raptor goes to approach;
  - a hit during the hold makes it charge.
- `t_combat`, `t_ai`, `t_canim`, `t_swarm`, `t_tactical` PASS. `run_all.gd` `[tests] PASS`.
  `tools/smoke.sh --no-import` SMOKE PASS.

## Notes / for the next agent
- ASSUMPTION: the 3 s hold (`RaptorPackBrain.INVESTIGATE_HOLD_S`). It is a pacing change: a velociraptor now waits
  about 3 s after spotting you before it runs in, unless you hit it or walk into reach. Tune it there.
- Skipped the optional look notes (black quill crest, pale tiger stripes on grey-blue). They need a texture or mesh
  pass, not a cheap Blender tweak.
- Possible existing bug, outside this package: `RiggedModel.LOOPING` (the list GLB creatures actually use) lacks
  `strafe_left`, `strafe_right`, `walk_back` and `charge`. Only `CreatureClips.LOOPING` lists them, so those clips
  may load as non-looping. I added `investigate` to both lists. I did not touch the others or check them in game.
- The old velociraptor `idle.glb` slides its feet 8.5 cm under `check_leap --grounded`. I left it as it is.
- Not touched: tyrannosaurus files and shared rig tooling (`make_gait`, `transplant_rig`, the jaw tools).
- External verifiers (`~/Documents/DeepseekCLI/verifiers`) are not on this machine. I used the repo's checks instead.

Credits: none. Meshy 0, Tripo 0, Higgsfield 0.
