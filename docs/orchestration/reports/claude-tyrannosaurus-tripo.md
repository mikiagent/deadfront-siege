# Tyrannosaurus: Tripo mesh + DeepSeek rig replaces the Quaternius stand-in

Date: 2026-10-18. Agent: Claude Code (art pipeline). Branch `claude/trex-tripo-2a1267`, not merged:
**waiting on the user's approval of the footage below.**

## What shipped

- `game/assets/creatures/tyrannosaurus/tyrannosaurus.glb`: Tripo P1 multiview mesh (task
  `c7aea80d-714b-49f6-b59b-645c87f8a6c9`, 50 Tripo credits), rigged and animated in Blender by
  DeepSeek V4.1 Flash through the dsc harness (30 bones incl. `Jaw` and `Tail1`-`Tail7`, about $0.29).
  8.00 m, origin at the feet, facing -Z. 13.9k triangles, one 2K PBR material (textures extracted by
  Godot's import next to the GLB, same as utahraptor).
- `anim/*.glb`: 12 clips: the 9 contract clips plus `feed`, `tail_swipe`, `sleep`.
  **Changed from the source:** the source clip GLBs each embedded the full mesh and three 2K textures
  (62 MB for 12 files). I stripped them to nodes + skin + animation, like every other species
  (1.5 MB total). Bone names and keys are untouched; the stripped files import and remap with
  `missing=0`. Unstripped originals stay in `DeepseekCLI/trex-tripo/out/tyrannosaurus/anim/`.
- `sheet.png`, `ref/` (approved Codex sheet `tyrannosaurus_sheet_v1.png` + the four Tripo input
  views), `work/` (`REPORT.md`, `pipeline.json` committed; `tyrannosaurus.blend` local only, like
  the other species' blends). Both folders have `.gdignore`.
- `game/data/creatures/tyrannosaurus.json`: every gameplay field unchanged. `pipeline` drops
  `stand_in` and `stand_in_model_scale`, keeps `forward_axis: "-Z"`, adds `source_height_m: 8.0`
  and the provenance (Tripo task + credits, DeepSeek/dsc rig, reference sheet, views, clip list).
  Dropping `stand_in` also turns off the 1.6x stand-in run speed in `CreatureClips.clip_speed`; the
  new `run` is authored as a run.

## Verification

- Headless `--import`: clean.
- Real `creature_lab` (driven from an out-of-repo SceneTree script that adds one tyrannosaurus to
  the lab's existing raptors and protoceratops; no repo scripts touched):
  `[creature] clip <x> tracks=… missing=0` for all 12 clips, **no "missing clip falling back to
  idle" lines**. Measured mesh height in engine 8.00 m, view scale 1.0, no rotation applied.
- Scale and facing next to utahraptor, protoceratops and the survivor: correct (stills below).
  Faces -Z, so it walks head-first.
- Bite (`attack_primary`, `hit_frac` 0.42): the head drops from 6.3 m to its lowest (3.75 m jaw)
  between 40% and 50% of the clip. The 42% hit lands on the bite. Good.
- Stomp (`attack_heavy`, `hit_frac` 0.72, held raised right foot): the right foot rises and **holds
  from 20% to 54%** (visible in the side view). The foot comes back down fast and is lowest at
  **about 62%**. By 72% the body has dropped into a crouch and the right leg is partly drawn up
  again (right metatarsal 1.47 m vs 0.87 m at rest). So the damage at 72% lands about 0.15 s after
  the visible plant at boss speed. Readable, not exact. Two fixes: re-key the stomp so the plant
  sits at 72% (art side, DeepSeek redo of one clip), or use a per-species `hit_frac` 0.62 override.
  I did not change `anim_events.json` because its `hit_frac` is per clip name and shared by every
  species.
- While biting and stomping, the foot bones lift 0.2-0.4 m off their rest height. In the side
  footage the feet still read as planted at normal zoom. Worth a look in the close clip.
- `tools/smoke.sh`: **SMOKE PASS**.
- Real raid (`--tyrant-window-probe` on `volcanic_60`, real AI and combat): ran 430 s of game time,
  boss from 200000 to 1719 HP, bite and stomp windups and a stagger all play on the new mesh, no
  fallback lines.

## Footage (in `docs/orchestration/reports/trex-tripo/`)

| file | what |
|---|---|
| `lab_side_all_clips.mp4` | creature lab, side-on: idle, walk, run, alert, bite, stomp, tail_swipe, hit_react, feed, sleep, knockdown, death |
| `lab_isocam_all_clips.mp4` | same sequence through the game's own IsoCamera (zoomed out to 24) |
| `raid_volcanic_60s.mp4` | first 60 s of the real volcanic raid fight |
| `lab_side_idle.png`, `lab_side_bite.png`, `lab_side_stomp_hold.png`, `lab_side_tail_swipe.png`, `lab_isocam_idle.png`, `raid_volcanic.png` | stills |

## Issues seen

1. Stomp plant at about 62%, not 72% (above).
2. Raid camera: at the default IsoCamera zoom the 8 m boss overflows the frame and its head is
   mostly off-screen during the fight. The old stand-in was the same height, so this is not new,
   but the new mesh makes it obvious. Game-side (IsoCamera zoom for big bosses).
3. `death` ends belly-up, so from the iso camera the pale belly makes the corpse read almost white.
   `sleep` from above shows the legs splayed sideways. Both are fine side-on.
4. `run` (0.9 s cycle) is played at `anim_events` speed 1.6 for every species. On an 8 m animal it
   looks quick; consider a species override.

## For Cursor

- New clips: `feed`, `tail_swipe`, `sleep`. `RiggedModel` already loads them into the library
  (seen in the lab log), but `CreatureClips.CONTRACT`/`LOOPING` don't list `tail_swipe` or `sleep`,
  so `sleep` won't loop and nothing plays either.
- `tyrant_brain.gd` only alternates bite and stomp (`attack_number % 3`). The species `verb` says
  "three-phase raid: stomp, roar, tail". `alert` (rear and roar) and `tail_swipe` (1.97 s, sweeps
  behind the hips) are ready for the roar and tail phases. `tail_swipe` has no `hit_frac` yet; I did
  not measure where the sweep peaks.

## Credits

This task: 0 Meshy, 0 Tripo. The asset's own cost: 50 Tripo credits + about $0.29 DeepSeek.
