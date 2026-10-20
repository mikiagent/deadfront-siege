# DSC-CLIPS: vetting three dsc creature-clip jobs

Date: 2026-10-20. Agent: Claude Code (integrator). Branch `claude/mmo-clips2`. Credits spent: 0.

## Result

| job | clips | verdict |
|---|---|---|
| zebra | zebraceratops idle, alert, attack_primary, attack_heavy, hit_react, knockdown, death, new sleep, new feed | **accepted** |
| trex-sleep | tyrannosaurus sleep | **accepted**, with one flaw (below) |
| quads-loco | protoceratops walk, run; megaloceros walk, run | **rejected**, the game keeps the current clips |

Commit `b783b10` holds the accepted clips and the test change. Zebraceratops walk/run and every other T. rex clip are byte-identical to the game's (the dsc inputs matched the game's files by md5).

## Checks run

- `./verify.sh` exit 0 for all three jobs. The zebra script prints "2 FAILED". Both lines are the frozen mesh's facing and spine checks, which the script exempts. It also warns that tail_swipe is missing.
- Forced re-import: touched the GLBs, ran `--import` (rc 0), and confirmed the `.godot/imported/*.md5` source_md5 equals the new files.
- `tools/bake_clip_speeds.py` ran ("BAKE OK: 10 species"). `anim_events.json` came out byte-identical, because no walk or run changed.
- `t_canim`: PASS, including the new `zebraceratops play_clip(sleep|feed)` checks. The no-sleep fallback check now uses deinonychus.
- `run_all`: `[tests] PASS`, rc 0.
- `tools/smoke.sh`: SMOKE PASS.
- 0 "couldn't resolve track" warnings in t_canim, run_all, import and lab logs. Every clip reports `missing=0`.
- No `t_creature_anim` test exists.

## Measurements

Stride is measured with `measure_stride.py` (planted-foot contact speed in mesh units, m/s).

| clip | current game clip | dsc clip | target in the task |
|---|---|---|---|
| protoceratops walk | 0.094 / 0.094 / 0.095 / 0.095 | 1.680 (all feet) | 1.68 |
| protoceratops run | 0.351 / 0.351 / 0.357 / 0.357 | 4.200 (all feet) | 4.2 |
| megaloceros walk | 0.096 / 0.096 / 0.094 / 0.094 | 3.040 (all feet; BackFoot.R only 2 contact frames) | 3.04 |
| megaloceros run | 0.359 (all feet) | 7.500 / 6.174 / 7.500 / 7.007 | 7.6 |

Foot order is BackFoot.L / BackFoot.R / FrontFoot.L / FrontFoot.R.

Pose is measured with `measure_pose.py` (bone heads):

| clip | top | bottom | near_floor |
|---|---|---|---|
| T. rex idle (reference) | 6.632 | 0.000 | 1 |
| T. rex sleep, current | 3.706 | **0.805** | **0** |
| T. rex sleep, dsc | 2.331 | 0.000 | 7 |

In-game cadence of the current quad clips, from the `creature_anim_lab` log:
- protoceratops plays its run at x2.67 at 1.7 m/s and x6.67 at 4.2 m/s.
- megaloceros plays its run at x7.31 at 3.0 m/s and x16.00 (the cadence clamp) at 7.6 m/s.

## Per clip

### Zebraceratops: accepted

Each new clip is clearly better than the current one:
- **attack_primary** loads with the horns low, then thrusts them level at 42 %. The current clip is indistinguishable from idle.
- **attack_heavy** holds a cocked telegraph, then drives in at 72 %. The hit fractions match `anim_events.json`, so no timing change was needed.
- **knockdown** and **death** end lying on the side, grounded, with the head on the floor and the legs folded. The current clips roll the body 90° with all four legs sticking straight out sideways.
- **hit_react** flinches with a head snap and a stagger step. **alert** lifts the head and chest. In the current clips both barely differ from idle.
- **idle** moves 25 channels; the current one moves 5.
- **sleep** and **feed** are new. sleep reuses the side-lying pose and breathes. In feed the head goes down to the ground.

All of these were checked in a windowed lab shot, Forward+ and gl_compatibility, every lane grounded and readable.

### T. rex sleep: accepted, with one flaw

The current clip is rolled onto its side about 0.8 m above the floor, and its legs stick out sideways. The new clip lies belly-down: chest, jaw and tail on the ground, loop delta 0.

Flaw: the hind legs fold forward, and the feet end up with their toe claws pointing up above the hips. This is visible in-game from the side. It is still far better than the floating roll, so I accepted it.

Follow-up: refold the metatarsals so they lie flat along the ground with the toes forward.

### protoceratops walk and run: rejected

The new loops stride correctly but look worse than the current clips:
- The body crouches into a belly-low crawl.
- The planted forefoot skin stretches into long flat spikes in front of the foot. Both are visible at 520 px and 900 px renders.

Root cause is a units error in the dsc TASK.md. It gave the game's move speeds (1.68 / 4.2 m/s) as stride targets, but the clips are authored in mesh units. The game scales protoceratops by 1.6 / 0.891 = **1.80x**. So dsc built strides 1.8x too long, and had to crouch to reach them.

Estimated effect in game:
- The walk would play at x0.56 at 1.68 m/s.
- The game picks the gait at the geometric mean of the walk and run speeds, about 5.2 m/s. Protoceratops tops out at 4.2 m/s, so it would never switch to the run.

### megaloceros walk and run: rejected

Large jagged triangles tear out of the rump and hips on most walk and run frames. dsc's report explains why:
- 19 rump vertices are weighted to `Tail5` + `BackFoot.L`.
- A 157-vertex hip seam stretches 32-45x.

With cadence about x0.86 to x0.96, the timing would be good. The torn geometry is still a harder defect than the current x7 to x16 cadence. The target units here were also off, by 2.1 / 1.811 = 1.16x.

## Next agent

1. Re-run quads-loco with targets in mesh units (game speed ÷ the scale):
   - protoceratops: walk **0.94**, run **2.34** m/s.
   - megaloceros: walk **2.62**, run **6.55** m/s.

   With the real stride length the deep crouch is no longer needed.
2. Fixing the megaloceros rump needs a re-weight of those 19 + 157 vertices. That is a mesh change, which the dsc job's rules forbid. Make it an art-pipeline task, or keep the hind stance behind the hip with a shorter stride.
3. T. rex sleep: fold the hind feet flat (see above).

## Evidence

Durable dsc contact sheets:
- `~/Documents/DeepseekCLI/deadfront-reanim/zebra/out/zebraceratops/sheets/*.png`
- `.../trex-sleep/out/tyrannosaurus/sheets/sleep.png`
- `.../trex-sleep/work/sheets_in/sleep.png` (the current clip)
- `.../quads-loco/out/{protoceratops,megaloceros}/sheets/{walk,run}.png`

My comparison renders and in-game shots are in session scratch and will not persist: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/clips2/`.
- `before/` holds the current game clips.
- `big/` holds old vs new walk and run side views; the meg tearing and proto forefoot spikes are here.
- `zbig/` holds the zebra and T. rex close-ups.
- `shots/` holds `zebra_clips.png`, `zebra_clips_gl.png`, `canim_walk.png` and `canim_rexsleep_gl.png`.

The zebraceratops shots came from a throwaway lab, `zz_clips2_lab`. It was deleted and never committed.

No `# ASSUMPTION:` markers were added.
