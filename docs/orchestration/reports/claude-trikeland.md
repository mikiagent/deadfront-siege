# TRIKELAND: the rigged triceratops on today's canon

Branch `claude/mmo-trikeland`: `origin/claude/mmo-trike` (1aeb461f) with `origin/claude/mmo-overhaul` merged in.
Not merged to canon. No credits spent.

## Merge
Three conflicts:
- `docs/orchestration/mmo/asset-replacement.md`: canon deleted it in 8278635c (historical docs moved to the archive line).
  I kept the deletion. The triceratops row is now IN PROGRESS -> done in this report and in `triceratops.json` `pipeline`.
- `game/data/combat_tuning.json`: canon's kick block (with `stagger_s`) and `auto_ability` are kept.
  Canon never changed `kick.giant_mass` (60 at the merge base and on canon), so the trike branch's 60 -> 40 stays, with its
  `# ASSUMPTION` note. Side effect, unchanged from the trike report: dilophosaurus, utahraptor, gallimimus and
  ankylosaurus also become too heavy to kick. The owner should confirm.
- `game/data/creatures/anim_events.json`: every canon row is kept, including styracosaurus, ankylosaurus, stego, rex and raptor.
  One `natural_speeds.triceratops` row is added.

## Model against today's bar
- `tools/audit_gaits.py --gate`: GATE PASS. The triceratops faces -z, and its planted feet slide backwards: walk +1.02/+0.74, run +1.25/+1.20 in glTF z.
- New `tools/gait/check_trike.py` is `check_ankylo.py` adapted to the trike's bones:
  - feet are the Hand/Finger and Metatarsal/Toe skin;
  - the rig faces +Y in Blender, so the moonwalk sign is flipped;
  - there is no tail-club check, because the horns are judged in the shots.
- Result: TRIKE_CHECK PASS on all 9 clips, at game scale (4.645 m).
  - Stretch is 2.0-9.7, under the 12 limit. The worst is death 9.7 at a 3 cm edge where Thigh.R meets Tail1.
  - Lowest skin point -0.4 cm in every standing clip. Knockdown dips to -2.4 cm, which is inside the -3 cm tolerance.
  - Planted feet slide backwards in walk (-0.52 to -1.02 m) and run (-0.65 to -1.21 m). No clip moonwalks.
- No clip failed, so `ground_clip.py` and `rejoint_legs.py` were not needed.
- The trike has 9 clips. It has no walk_back, strafe or feed/sleep clips (ankylo and stego have them).
  t_canim passes without them. Adding them is follow-up work, not a fix.

## NOBOXES
- t_noboxes PASS. It lists `species triceratops model=true`.
- New `game/tests/t_trikeland.gd` loads swamp_55, the only island whose tables name the triceratops (working and crater spawns).
  6 triceratops spawn there. They draw the GLB with no box body, and all 9 pipeline clips load.
- t_petfollow: I removed its `allow_placeholder = true` line, which was there for the model-less triceratops.
  The summoned triceratops now uses the real model, and the test still passes.
- t_stationstate: its opt-in is for the ankylosaurus, not the triceratops.
  It lists the triceratops in the large pen and passes unchanged.

## Shots (`docs/orchestration/reports/trikeland/`)
Taken from a self-quitting windowed run off-screen (`--position 6000,3000 -- --skip-charcreate --lab=trikeland_lab --out=DIR`).
The new `game/scripts/dev/trikeland_lab.gd` + `game/scenes/dev/trikeland_lab.tscn` are `ankylo3d_lab` re-aimed at a 9 m body.
- `contact_side.jpg`: all 9 clips at 30 % and 60 %, plus both attacks at their hit frame (42 % and 72 %). The survivor stands ahead of the head for scale.
- `contact_tq.jpg`: the same frames from a high three-quarter rear view. Full frames are in `sheet/`.

What I looked at:
- Size reads right: the survivor reaches about to the elbow.
- The feet are planted in walk and run, the horns dip and hook in both attacks, and alert lifts the head.
- Knockdown and death end on the left side with the legs away from the side camera.
- Nothing read wrong enough to change.

Left as is:
- In the neutral coloration the hide reads tan-brown rather than the sheet's dark olive. The frill is rust.
  Wild spawns get the species coloration on top.
- The three-quarter camera sees the shadowed side, so the side sheet is the one to judge by.

## Gates
- Gait checks: `audit_gaits.py --gate` GATE PASS; `check_trike.py` TRIKE_CHECK PASS.
- PASS: t_noboxes, t_combat, t_canim, t_petfollow, t_stationstate, t_boneparts, t_data, t_trikeland.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.

## For the next agent
- Missing clips compared with ankylo and stego: walk_back, strafe_left/right, feed, sleep.
  The rig and the four-leg IK in `tools/blender/triceratops/clips.py` can author them. The work files are outside the repo, in `deadfront-dsc-work/triceratops-v2`.
- `kick.giant_mass` 40 is still an ASSUMPTION waiting on the owner.
