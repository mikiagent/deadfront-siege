# MEGARUN: the megaloceros gallop re-authored, stride match scaled by body size, legs that bend the right way

Branch `claude/mmo-megarun` (from `origin/claude/mmo-overhaul` f54eb43f; canon a3fa0f45 merged back in). Not merged to canon.

Owner, verbatim, from the god-mode fight lab:
- "megaloceros doe strafe left animation is cursed... strafe right too"
- "the run animation is cursed too, especially obvious on the alpha variant"
- later: "megaloceros, the motion is right but the legs are getting mangled or something watch out for that"

## Credits
Tripo 0, Meshy 0. Every clip is a Blender script. The Tripo inputs (`work/megaloceros_{stag,doe}_tripo.glb`, gitignored) were copied from the megajoust worktree. `build_rig.py` rebuilt both GLBs byte-identical from them.

## Why the run was cursed (measured in `t_megarun`, straight line at run speed)
| | stag | doe | alpha stag 1.27x |
|---|---|---|---|
| before, worst slip per stance | hinds 40-42 cm | 5-8 cm | 17-43 cm |
| after | 1-2 cm | 1-4 cm | 1-2 cm |

1. **A hitch at the loop seam: the ~40 cm hind slip.** `clips.py` keyed loops from Blender frame 1, so glTF time started at 1/24 s. Godot held the first pose for 1/24 s every cycle. Both hinds are planted at the seam, and the body travels ~40 cm in that time, so the hinds slid each stride. It was also a visible stutter about 1.5 times a second.
2. **The alpha's stride ignored its size.** `CreatureAnim` matched cadence to the species' baked natural speed. It never read `size_scale()`, but the model is drawn at that size: alphas are 1.24-1.32x, normal animals 0.85-1.15x. A 1.27x alpha swept its hooves 27 % faster than the ground moved. This affected every species, not only megaloceros.
3. **The doe slid ~7 %.** Her GLB is drawn 1.069x, because the rig is fitted to `height_meters`, but she used the stag's natural speed.
4. **Godot resampled the clips at 30 fps on import.** The slerp between samples dipped a landing hoof 3 cm through its planted height.
5. **The old gallop flung the hind legs out behind.** They lifted off 1.2 m back on a symmetric swing that lingered there, so they trailed level behind the rump for a third of the cycle. The stance targets were also beyond the right hind's reach: that leg is 13 cm shorter on this Tripo rig. That hoof landed late and hovered.

The alpha has no texture or rig variant. It is the stag's (or doe's) model, scaled and darker.

## What changed
- **`tools/gait/megaloceros/clips.py` `gallop()`, rewritten.** A transverse gallop with one gathered suspension:
  - Touchdowns at 0 / .1 / .34 / .44 of the cycle (LH, RH, LF, RF); each hoof is planted for 34 %.
  - A planted hoof slides back at exactly stride / (duty x T). Through the heel-off the pastern rolls about the hoof's front edge (`TOE_PIVOT`), so the toe stays put and the skin never dips under the floor.
  - The swing follows a Hermite path. It leaves still moving back and lands moving back at 0.6 (front) / 0.9 (hind) of ground speed: a retraction, no stab.
  - Hind legs tuck forward right after push-off (time warp `u + 1.5u(1-u)^2`), and the forelegs unfold early to reach.
  - Stride 0.70 x 3.05 m. The doe strides 0.85x (`DOE_STRIDE`): stag strides overreached her legs.
- **Hock and carpus guard (owner: "legs are getting mangled").**
  - The cannon tilt that `apply()` sets could push the hock or carpus past straight the wrong way: up to 66 deg on a reaching hind, and 12 deg of carpus hyperextension in the walk.
  - The cannon now turns about the fetlock until the joint bends its rest way by at least 3 deg (`signed_bend`, `HOCK_MARGIN`).
  - The stifle and elbow were already pole-solved.
- **Loops are keyed from frame 0 (glTF time 0).**
  - Fast loops (T < 1 s) are keyed at 48 fps. Their `.import` is set to `animation/fps=48` (run, charge, doe run).
  - One-shots are unchanged.
- **The stag `charge`** inherits the new gallop. Its neck carriage is 18/26 deg (was 30/18): the new forelegs reach further under the neck, and the brisket skin hit 12.6 of 12 stretch.
- **Rebuilt clips:** run, walk and walk_back (stag and doe), and charge (stag). The strafes, one-shots and turn clips are untouched.
- **`game/scripts/creatures/creature_anim.gd`** (shared code):
  - Every natural speed is scaled by `size_scale()` (`_size()`): in `set_move_speed`, the strafe/walk_back path and `set_gait_clip`. This fixes stride matching for every species' scaled and alpha animals.
  - A body variant's `model_variants.<v>.natural_speeds` overrides the species' per clip.
  - `pipeline.disabled_clips` builds no state for the listed clips, so callers fall back as on a rig without them.
- **`megaloceros.json`:**
  - `disabled_clips: [strafe_left, strafe_right]`. A sideways step outside the joust now plays the forward walk. The strafe GLBs stay for the clip viewer.
  - Doe `natural_speeds` `{run 8.539, walk 2.452, walk_back 2.452}`, computed in the note as 0.85 x 1.069 and 1.069 x the stag's.
- **`anim_events.json` natural_speeds.megaloceros:** rebaked with `tools/bake_clip_speeds.py --dry-run` (run 9.409, walk / walk_back 2.295, lengths 0.667 / 1.25). Only that row was spliced in; the strafe rows are unchanged.
- **Skin weights:** checked in Blender for vertices weighted to the other side's leg bones. There are 0 on both bodies.

## Gates (HEAD after the canon merge)
- `t_megarun` (new): **PASS**.
  - Worst hoof slip per stance at run speed, limit 5 cm:

    | animal | worst slip (cm) |
    |---|---|
    | stag 1.0 | 2.4 |
    | doe 1.0 | 3.5 |
    | alpha stag 1.27 | 2.0 |
    | alpha doe 1.27 | 3.6 |
    | stag 0.85 | 2.8 |
    | stag 1.15 | 2.1 |
    | doe 0.85 | 3.5 |

  - Walk: stag 3.2, doe 2.3, alpha 4.1 cm.
  - Every hoof is planted for at least 20 % of the cycle, so a hoof that bobs out of the measuring band cannot pass unmeasured.
  - In walk, run, charge and walk_back (and the run turns, when present), no leg bone twists more than 30 deg about its axis relative to its parent, or more than 30 deg between 60 Hz samples. The worst is 18 deg, on the stag's front pastern in the charge.
  - Knee, hock, elbow and carpus always bend the anatomical way: 0 wrong samples.
  - A sideways velocity plays the walk, not a strafe.
- `audit_gaits.py --gate`: GATE PASS.
- `check_megaloceros.py`: PASS for the stag (16 clips) and the doe (15). Run stretch: stag 9.75, doe 11.53; charge 11.75.
- `t_canim`, `t_combat`, `t_sp_megaloceros`: PASS.
- `run_all.gd`: [tests] PASS.
- `tools/smoke.sh --no-import`: SMOKE PASS.

## Shots (`docs/orchestration/reports/megarun/`, `--lab=megarun_lab`, windowed at `--position 6000,3000`, self-quitting)
- `run_{stag,doe,stag_alpha}.png`: side-on, six frames over one stride, through the game's own stride match at run speed. Every planted hoof drops a coloured disc each frame, so a slipping hoof would smear into a streak. They stay dots.
- `legs_{stag,doe,stag_alpha}.png`: the same instants, close on the legs.
- `run_stag_before_blender.png` / `run_stag_after_blender.png`: Blender strips of the old and new clips. The old one shows the hind legs trailing level behind the rump.

## For the integrator (megajoust lands last)
- **`clips.py` will conflict.** The joust adds `ground()`, a `turn` parameter to `gait()` and `gallop()`, `run_turn`, the doe `tackle` and `charge_crouch`.
  - Keep my `gallop()` and add the turn: in the stance branch replace the straight ground point with `ground(L["home"] + REACH offset, STRIDE * (u - 0.5), turn)`, and the same for the swing's y.
  - `t_megajoust` compares the turn clips against the straight run, so it must be rerun anyway.
- **Rebuild with `tools/gait/megaloceros/build.sh` after the merge.**
  - Set `animation/fps=48` in the `.import` of every new fast loop: `run_turn_left/right`, the doe `charge`. Without it the 30 fps resample dips the hooves.
  - Then rebake (`tools/bake_clip_speeds.py --dry-run`, splice the megaloceros row only).
  - Then rerun `t_megarun` and `t_megajoust`. `t_megarun` already covers `run_turn_*` and `charge` in its leg check when they exist.
- **The joust's doe tackle (`charge`) has no natural speed row,** so it falls back to her run (8.539). It strides like her run, so that holds.
- **`t_megajoust` spawns at size 1** and noted that stride matching ignored genetic size. That is fixed here.

## Left as is
- The strafe GLBs still carry the old 1/24 s seam hold. They are disabled for megaloceros, so they never play in game.
- The doe's walk and walk_back are still authored in stag metres, which are long for her. She now plays them at her own speed, so they do not slide.
- The front pastern twists up to 16-18 deg in the stag's gallop, the asymmetric right foreleg on the Tripo rig. That is within the 30 deg limit.
- `ASSUMPTION`s:
  - MR1: gallop footfall timing, duty 0.34, stride 0.70 x 3.05 m;
  - MR2: the doe strides 0.85x;
  - MR3: the 3 deg minimum hock/carpus bend;
  - MR4: the charge neck carriage 18/26.
