# DSC-CLIPS: vetting three dsc creature-clip jobs

Date: 2026-10-20. Agent: Claude Code (integrator). Branch `claude/mmo-clips2`. Credits spent: 0.

## Round 3: review fixes (2026-10-20)

All findings of the third review are handled on `claude/mmo-clips2`. The base `claude/mmo-overhaul` (85c2b63) is merged in (888a081).

| finding | fix | commit |
|---|---|---|
| **blocker**: protoceratops and megaloceros walk/run are out of scope (quads-loco2 redoes them) | the 4 GLBs and both `natural_speeds` rows restored from `claude/mmo-overhaul`; both species in t_canim `KNOWN_GLIDERS` until quads-loco2 lands | c5c1158 |
| **major**: the 1.125 s zebraceratops hit_react stunlocks the animal under a 1.0 s hit cadence | `anim_events.json` `clips.hit_react.speed = 2.0`; new t_canim check `_test_hit_react_window` (written by dsc) | c5c1158, 3290080 |
| minor: zebraceratops not in `STRIDE_SPECIES` | added | c5c1158 |
| minor: `KNOWN_GLIDERS` empty, dead branch | now lists protoceratops and megaloceros (blocker fix) | c5c1158 |
| minor: T. rex sleep reads as a crouch from low behind | not done, see below | - |
| minor: megaloceros plays its run at walk speed | moot here, the base rows are back; note for quads-loco2 below | - |

`git diff claude/mmo-overhaul -- game/assets/creatures/{protoceratops,megaloceros}` is now empty. This branch changes `anim_events.json` only in the zebraceratops `natural_speeds` row and the new `hit_react` speed line.

### The hit_react fix applies to every species

The stunlock was not limited to zebraceratops. Seven species in the base already had long authored hurt clips: coelophysis, compsognathus, gallimimus, utahraptor and velociraptor at 1.25 s, protoceratops and megaloceros at 1.125 s. At x1.00 each of them, zebraceratops included, had 0.00 s free per second.

`CreatureClips.clip_speed` keys on the clip name, so the only speed knob inside this package's files (`anim_events.json`) is global. `game/scripts` is out of scope, so a per-species speed was not an option. Every species' `authored_clips` note calls its clip a "0.6 s" recoil, and x2.0 plays the long clips in 0.56-0.63 s.

Cost: deinonychus has the only short clip (0.625 s), and it now plays in 0.31 s. I did not judge that visually. If the quicker flinch reads badly, the alternative is to retime the eight long GLBs to about 0.6 s and drop the global speed. That means GLB edits in eight species' anim folders.

The new check is `_test_hit_react_window` in t_canim. For every species with an authored hit_react, it:
- calls the real `Creature._on_damaged` once per second of tree time, six times, resetting `_stagger_immune_until` before each call because the real code reads the wall clock;
- steps `stagger_left` down as `_physics_process` would;
- counts the frames where `anim.is_busy()` is false and `stagger_left` is 0, which is the brain's attack gate (`creature_brain.gd` around line 459);
- requires at least 0.30 s free in every second after the first.

With the fix (t_canim log, rc 0, `[t_canim] PASS`):
- zebraceratops, protoceratops and megaloceros: 1.125 s clip at x2.00, `free to attack 0.42 s of each second`;
- coelophysis, compsognathus, gallimimus, utahraptor and velociraptor: 1.250 s clip at x2.00, `free to attack 0.35 s`;
- deinonychus: 0.625 s clip at x2.00, `free to attack 0.67 s`;
- `9 species with an authored hit_react checked`.

Without the fix, the dsc gate deletes the speed line from `anim_events.json`, reruns t_canim, then restores the file. t_canim exits 1, and the eight long-clip species print `FAIL <id> hit_react ... at x1.00 ... free to attack 0.00 s of each second`. I ran that gate myself and saw `VERIFY PASS`.

### Checks that would have caught each finding

- **Blocker.** If this branch ships non-gliding protoceratops or megaloceros clips again, the `KNOWN_GLIDERS` line fails: `<id> is a known glider (...); if it no longer glides, drop it from KNOWN_GLIDERS`. Today it prints `ok` with `run x16.00 at 7.60 m/s` (megaloceros) and `run x6.67 at 4.20 m/s` (protoceratops). The base clips still pass `_test_stride_match`.
- **Major.** `_test_hit_react_window`, as above.
- **STRIDE_SPECIES.** `zebraceratops set_move_speed(1.60) -> walk x1.00: planted feet ratio L 1.00 R 1.00` and `set_move_speed(4.00) -> run x1.14: ratio L 1.00 R 1.00`.

### What dsc did, and what I changed in its diff

- **Job.** Sub-worktree `mmo-clips2-dsc1`, branch `claude/mmo-clips2-dsc1`, `dsc cook start TASK.md --once --verify ./verify_hitwin.sh --budget 2 --max-hours 4 --effort high`. It finished done with 0 verify failures, $0.01, under a minute.
- **dsc's part.** It wrote `_test_hit_react_window` (36 lines) and the call in `_process`.
- **My part.** I wrote TASK.md and the read-only gate `verify_hitwin.sh` (555). The gate checks:
  - only `t_canim.gd` changed;
  - the function calls `_on_damaged(` and does not call `play_clip(&"hit_react")` itself;
  - it reads `is_busy()`, `stagger_left` and `clip_speed(&"hit_react"`;
  - there is one `ok` line at x2.00 for each species with an authored hit_react, read from the JSON;
  - zebraceratops reports its 1.125 s clip and velociraptor its 1.250 s clip;
  - with the speed line deleted, t_canim fails, and the file is restored afterwards.
- **What could pass while wrong, and is covered.** A test that calls `play_clip` directly, or one that skips every species. The gate's `_on_damaged` grep and `checked >= 9` cover these.
- **What I changed in its diff.** I took only `game/tests/t_canim.gd`; its commit also added TASK.md and verify_hitwin.sh at the repo root, and I left those out. I reworded the tail of its message from `was 0.00`, which is wrong for deinonychus, to `the 1.125-1.25 s clips at x1.00 left 0.00`.

### Re-import, tests

- I touched the four restored GLBs and ran `--import` (rc 0, 0 "couldn't resolve track"). Each `.godot/imported/<clip>.glb-*.md5` source_md5 equals the restored file.
- t_canim: `[t_canim] PASS` on 3290080.
- run_all: `[tests] PASS`, rc 0, on c5c1158. Since then only t_canim.gd has changed.
- `tools/smoke.sh`: `SMOKE PASS` on c5c1158.
- 0 "couldn't resolve track" in import, t_canim and run_all logs.
- No new `Godot-*.ips` in DiagnosticReports.
- No windowed shots this round. Nothing visible changed except the hit_react playback rate, which a still frame cannot show.

### Not done

- **T. rex sleep polish.** The review marked lowering the pelvis and laying the tail base flat as optional, for a later dsc pass. It needs a new Blender job and another visual review round, so I left it. The `trex-sleep2` gate (`~/Documents/DeepseekCLI/deadfront-reanim/trex-sleep2/verify.sh`) is the place to add a pelvis-height bound and a tail-under-sky ray test.
- **For quads-loco2 (orchestrator).** Its gate should require that walk speed selects the walk clip. The base clips fail that as well: at walk speed both quads play their run (`megaloceros set_move_speed(3.04) -> run x7.31`, `protoceratops set_move_speed(1.68) -> run x2.67`). When quads-loco2 lands, drop both species from `KNOWN_GLIDERS`; the list line fails until someone does.

No `# ASSUMPTION:` markers were added this round.

## Round 2: review fixes (2026-10-20, superseded where round 3 says so)

All four round-1 review findings are fixed on `claude/mmo-clips2`.

| finding | fix | commit |
|---|---|---|
| **blocker**: t_canim's feed check could not fail (CreatureClips copies idle into `feed`) | `_expect_authored_feed`: feed must rotate some bone > 0.1 rad away from idle at 25/50/75 % | f87e0f0 |
| **major**: T. rex sleep crossed the legs, a foot over the hip with claws up, a skin wedge under the chest, sky under the hips | dsc job `trex-sleep2` re-keyed the clip against a gate that measures each flaw. t_canim now checks the rest pose in the game | c05d888 |
| minor: misleading `raptor` variable | renamed to `c` / `probe` | f87e0f0 |
| minor: zebraceratops clips 2.5x larger; walk/run still glided | keyframe-reduced re-export (1.03 MB -> 0.53 MB, 0 pose drift); dsc `zebra-loco` walk/run (run x1.14, was x10) | d422a8d, 25073a3 |

### Checks that fail on the old behaviour

- **Feed.** I ran a throwaway script (deleted, never committed) that applies the same `_pose_gap` to species with no `feed.glb`:
  - `deinonychus has feed state true, gap 0.0054 rad -> FAIL`
  - `stegosaurus has feed state true, gap 0.0000 rad -> FAIL`

  The authored clips measure 0.578 (T. rex), 0.481 (velociraptor) and 0.597 (zebraceratops).
- **T. rex sleep.** `_expect_rest_sleep` samples the sleep in the game and requires:
  - lowest bone within 3 % of idle hip height of the floor;
  - each toe within 12 % of hip height of the floor and on its own side of the midline, measured on the hip-to-hip axis, so yaw does not matter;
  - each metatarsal flat (|up| <= 0.5) and running heel-back toes-forward (>= 0.5), each toe forward (>= 0.6);
  - hands not crossing the midline.

  On the interim clip it printed: `FAIL tyrannosaurus sleep rests on its belly: lowest bone 0.00 m (idle hip 3.43 m) L foot or hand crosses the midline, L foot not flat heel-back toes-forward (metatarsal up -0.45 fwd -0.88, toe fwd -0.77), R ...` (same for R).

  On the new clip: `ok ... lowest bone 0.00 m (idle hip 3.43 m) feet flat on their own side, toes forward`.

  Not run: the oldest clip, which floated 0.8 m up. The floor rule targets it, but I did not swap that clip back in to watch the rule fail.

### What dsc did, and what I changed in its diff

`~/Documents/DeepseekCLI/deadfront-reanim/trex-sleep2` (dsc cook, `--budget 2 --max-hours 4`): finished done, verify failures 0, $1.21, 2.1 h. dsc did the following in headless Blender:
- searched a leg fold: thigh near rest, shin folded about +80°, metatarsal and toe laid flat;
- re-searched the trunk, tail and arms around that fold;
- baked a 121-frame breathing loop (5.0 s, first frame == last) and exported it skeleton-only with the skin and keyframe reduction (52 KB).

My part:
- I wrote TASK.md, the read-only gate (`verify.sh`, 555) and two measuring tools (`check_rest_legs.py`, `measure_skin.py`, 444).
- I re-ran the gate myself and saw `VERIFY PASS`:
  - `sleep POSE top=3.551 bottom=0.000 near_floor=6` (idle top 6.632)
  - `LEGS ok frames=121`
  - `STRETCH max=3.41 over2=43` (interim: 804 edges past 2x)
  - `BELLY gap=0.133`
- `git diff` of the job shows TASK.md, verify.sh, input/ and ref/ untouched. The mesh and the other 11 T. rex clips are byte-identical to the game's.
- **I changed nothing in its clip.** It went into the game as-is.

What the gate could pass while it looks wrong:
- feet tucked but floating;
- the wedge moved somewhere else;
- sky under the trunk.

The gate's belly ray profile and stretch count cover those. I also looked at gameplay angles (below).

### Re-import, tests

- I replaced `sleep.glb`, touched it and ran `--import` (rc 0). `.godot/imported/sleep.glb-*.md5` source_md5 is `1c6ea802…`, which equals the new file.
- t_canim: `[t_canim] PASS`, including the new rest-pose and feed lines.
- run_all: `[tests] PASS`, rc 0.
- `tools/smoke.sh`: `SMOKE PASS`.
- 0 "couldn't resolve track" warnings in the import, t_canim, run_all and all 14 lab logs of this round.
- No new `Godot-*.ips` in DiagnosticReports.

### What I looked at (windowed, 1600x900)

Throwaway lab `zz_clips3_lab`, deleted and never committed:
- **T. rex sleep, 3/4 view, Forward+ and gl_compatibility.** Belly, jaw and tail on the ground. Each hind foot is tucked flat beside the belly on its own side with the claws forward. The arms are under the chest. No pale wedge.
- **T. rex sleep, low camera 0.6 m up.** No sky under the hip span. One small sky gap shows between the tucked thigh and the chest, above the foot. Minor.
- **T. rex sleep, side view, gl_compatibility.** Body grounded. No foot above the hip.
- **Zebraceratops:**
  - sleep: side-lying, grounded, legs folded.
  - feed, held at the dip: the head goes down with the beak at the ground. In-game Head bone height is 0.54 -> 0.41 m, two dips per 2.54 s loop.
  - attack_heavy and walk (gl_compatibility): feet on the ground, standing height.

Shots are in session scratch and will not persist: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/clips3/shots/` (`rex_q34.png`, `rex_q34_gl.png`, `rex_low.png`, `rex_side_gl.png`, `zeb_sleep.png`, `zeb_feed_dip.png`, `zeb_heavy_gl.png`, `zeb_walk_gl.png`; `before_*.png` is the interim sleep, `proto_*`/`meg_*`/`zebra_*` the earlier loco vetting). The durable dsc sheets are `trex-sleep2/out/tyrannosaurus/sheets/sleep.png` and `sleep_34.png`.

### Still imperfect

- **Sleep mesh below the floor.** The deepest posed vertex is 0.30 m below the floor (a metatarsal flap; dsc report). In-game it reads as the body pressing into the ground, and terrain hides it.
- **Small breath.** The breath is at most 0.7° per bone, because the pose sits near the stretch ceiling.

### For the orchestrator: protoceratops and megaloceros walk/run (superseded: round 3 restored the base clips)

Before this round, earlier DSC-CLIPS work committed these:
- `73663d7`: protoceratops walk/run, dsc `proto-loco2`: walk x1.00, run x1.10 in game.
- `75d1dd9`: megaloceros walk/run, dsc `meg-loco2`: run x0.78 / x1.96, short hind stride because of the rump weights.
- `2276472`: t_canim's gait-cadence check (no species above x3.0).

The running `quads-loco2` job, which I did not touch, redoes the same four clips from the round-1 state. When it lands, choose one set:
- If you take quads-loco2's clips, they must also pass `_test_cadence_sane` and `_test_stride_match`.
- If you keep these, stop that job.

I did not revert them. Reverting would bring back the x6.67 / x16 gliding, which the cadence check fails.

No `# ASSUMPTION:` markers were added this round.

---

# Round 1 (superseded where round 2 says so)

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

### T. rex sleep: accepted, with one flaw (fixed in round 2)

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
