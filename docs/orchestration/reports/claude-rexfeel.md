# claude-rexfeel: exaggerated T. rex clips (Part A), new-model reference sheet (Part B)

Branch `claude/mmo-rexfeel`, cut from `origin/claude/mmo-overhaul` 019a98b2. Not merged to canon.
- Part A: commit 949b756d. It can merge on its own.
- Part B: commit 4463b482 (reference images only; Milan approves them first).
- This report is the commit after that.

## Part A: shipped

### Clips
Made with `tools/gait/make_rex_moves.py` (new). It is headless Blender on the existing 30-bone rig, and the feet are IK-planted on their prints.
- **idle** (4 s loop): two heavy breaths (chest heaves, belly sags, jaw parts on the exhale), weight rolling foot to foot, a slow look, tail sway.
- **alert, the roar** (2.4 s): head drops and the chest loads, then she heaves up and throws the head skyward. Jaws open to 46 deg. She holds the bellow with a head shake and a lashing tail.
- **attack_primary, the lunge bite** (1.67 s, hit at 0.42): rocks back with the jaws gaping, then throws the body forward 1.3 m and down 0.85 m, nose-down and near horizontal. The right foot steps out under the lunge. The jaws snap shut on the hit, she wrenches the head, then steps back onto the print.
- **attack_heavy, the stomp** (1.67 s, hit at 0.72): shifts onto the left leg and rears 18 deg. The right foot is hauled up 2.5 m and held (the telegraph), then slammed down 1.2 m ahead. Body, head and jaws drive down with the impact, she bounces, and steps back.
- **tail_swipe** (2 s, hit at the default 0.55): winds the hips right while looking back over the shoulder. Then she unwinds hard left, the wave runs out to the tail tip, and the tail swings about 85 deg to the side.

### Carriage
Every gait now uses the low stalking carriage (Tarbosaurus reference): body tipped 5 deg nose-down, neck down, skull level with the back.
- The rex walk/run/strafes/walk_back are re-made with `make_gait.py`, with the carriage added to `tools/gait/tyrannosaurus.json` as "hold" and "lean_deg".
- The run is new: 0.92 s, 4.2 m stride.
- The old clips were broken:
  - The run barely strode (natural speed 0.42 m/s).
  - The walk and run moonwalked.
  - The strafes moonwalked and sank 34 cm.

### Base mesh bug fixed
The leg skin was bound to the opposite side's bones: the left foot was on Toe.R/Metatarsal.R, and the whole left leg was on the .R chain.
- Rotating Thigh.R moved 2988 left-side vertices and none on the right.
- `tools/gait/fix_side_weights.py` (new) moves each leg weight to the vertex's own side. It changes JOINTS_0 indices only and leaves every other byte alone.

### Gates and tools
- `tools/gait/check_rex_clips.py` (new, Blender, on the skinned mesh). One-shots and idle: sink, float, slip, airborne, ends. Gaits: sink and moonwalk.
- `tools/audit_gaits.py --gate` now checks -Z rigs by their JSON `forward_axis`. It fails the old rex walk/run and passes the new ones.

### Game wiring
- `TyrantBrain`, tail whip: a target behind her (dot < -0.35) draws `tail_swipe` instead of a turn into a bite. It has a 0.9 s windup and a "TAIL - ROLL OR GET CLEAR" telegraph, and hits only behind or beside her. This is an **ASSUMPTION**, built on the "tail" phase of the json verb "stomp, roar, tail".
- `TyrantBrain`, follow-through: the timed attack no longer cuts to idle at the impact. The snap, slam or whip plays on through recovery, and `_end_phase` returns her to idle.
- The roar was already wired: `_spot` plays `alert`.
- `anim_events.json`: the tyrannosaurus `natural_speeds` row was re-measured by `bake_clip_speeds.py`, plus strafe and walk_back rows. Only the rex row was written back, because the tool would have deleted other species' hand-added strafe rows.
- `creature_lab --species=X --clipshots=DIR` (new) writes a selector shot plus 6 frames per clip, side-on beside the survivor, then quits.

## Part A: shots
In `docs/orchestration/reports/rexfeel/`, from off-screen windowed runs (`--position 6000,3000`, self-quitting, `-- --skip-charcreate`):
- `before_after_<clip>.png`: top row is the old clip, bottom row the new.
- `after_all_clips.png`
- `creature_lab_selector.png`

I looked at every sheet. Two problems I found and fixed:
- The tail whip curled up like a scorpion; I dropped the tail pitch.
- The stomp lift and rear were too small; I made them bigger.

## Gates
| Gate | Result |
|---|---|
| `check_rex_clips.py`, 10 clips | PASS, worst sink 2.5 cm |
| `creature-verify.mjs tyrannosaurus --height 8 --require-jaw` | ALL HARD CHECKS PASSED |
| `audit_gaits.py --gate` | PASS |
| `t_rexclips` (new) | PASS: clips load; the brain picks bite, stomp and tail and the tree plays them; the follow-through plays; spotting roars; a foot on its print every frame |
| `t_combat`, `t_mounts`, `t_canim`, `t_ai`, `t_turnrate`, `t_dismount`, `t_saddles`, `t_tame`, `t_ragdoll`, `t_eyeglow`, `t_boneparts`, `t_eyetrails`, `t_alphas` | PASS |
| `run_all.gd` | [tests] PASS |
| `tools/smoke.sh --no-import` | SMOKE PASS |

Two notes on the tests:
- `t_turnrate`'s "bite behind" case now puts the prey beside her (+X), since straight behind is now the tail.
- `t_playerturn` fails `tap_walk_away_target_gone`. It fails the same way on canon (`mmo-overhaul` ba65da3b), so it was already failing before this work.

## Part B: the owner changed it to a new model
Milan: "we will likely need a new Trex model with an open jaw so you can animate it better".
- I made the Codex sheet in the ankylosaurus layout, and a clean left side view for Tripo.
  - `/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/rex-ref/tyrannosaurus_sheet_v1.png`
  - `/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/rex-ref/tyrannosaurus_side_v1.png`
  - The prompts and logs are beside them.
- Copies are on the branch in `game/assets/creatures/tyrannosaurus/ref/` as `*_v2.png`.
- What the sheet shows:
  - mouth modelled open about 30 deg, with a separate lower jaw and big teeth
  - heavy brow ridges
  - scutes down the back and tail
  - olive crocodile hide with dark stripes and a pale cracked belly
  - a black bristle crest from the skull to the shoulders
  - low, head-forward stance
- Nothing was modelled on the current mesh.
- Credits: 0 Tripo, 0 Meshy, 0 Higgsfield.

## Not done, and risks
- The knockdown, death, sleep, feed and hit_react clips are untouched, but the weight fix changes how they skin. Renders look the same, but the skin sinks deeper in the lying clips: sleep -66 cm vs -30 cm before, knockdown -16 cm vs -1 cm. They were authored against the mirrored binding and need a re-pass. A new model would replace them anyway.
- The roar opens the jaw to 46 deg on the old mouth-shut mesh, so the lips stretch (the known jaw issue). The v2 model would fix it.
- No in-engine video was recorded, only frame strips. There is no old-vs-new look side-by-side, because Part B became a reference sheet.
- `sheet.png` (the asset validation render) was not regenerated.

## Next agent
1. If Milan approves the sheet:
   - four views from `tyrannosaurus_sheet_v1.png` (Codex, `-i` the sheet)
   - Tripo multiview with `P1-20260311`, 50 credits, cap to be set by Milan
   - transplant the rig with a real Jaw bone
   - re-run `make_rex_moves.py`, `make_gait.py` and `check_rex_clips.py` on the new base. The scripts read bone names only, so they carry over.
2. Otherwise, re-pass knockdown, death and sleep on the fixed weights.
