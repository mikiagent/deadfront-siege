# claude-mmo-stego: Stegosaurus v2 in game (STEGO)

Owner: "stegosaurus model is wrong, we should have a new one from an earlier coding job for you to use".
The v2 asset (Tripo H3.1 mesh, Opus rig, 34 bones, 9 clips) was already in the repo; `creature_view.gd`
forced a box placeholder for every stegosaurus. The game now loads v2.

Branch `claude/mmo-stego` from `claude/mmo-overhaul` at ddaab662. Commits:

- `145f6e8c` stego_lab, the reproduction lab (committed before any game change; BEFORE shots ran on it)
- `da00f610` the fix: override and box fallback deleted from `creature_view.gd`, `stegosaurus.json`, `t_stego.gd`
- `46c6db30` t_stego: capture flow, deterministic walk-clip stride check
- the report commit (this file, the hooks patch, the register row)

Files other packages own ship as `docs/orchestration/reports/claude-mmo-stego-hooks.patch` (5 files, 84+/12-).
`git apply --cached --check` passes on the branch head. The work tree has them applied and every AFTER gate
below ran with them applied. The branch and the patch must land together. Without the patch the stegosaurus
loads but slides at 4x (t_stego's stride section fails, see Gates).

## What shipped

On the branch (ORCHESTRATOR GRANT files and my own new files):

- `creature_view.gd`: deleted `force_safe_placeholder` (the "catastrophic weights" override written for the
  v1 transplant) and the stegosaurus plate/spike block in `_build_placeholder`. No stegosaurus code is left in
  the view; the generic box placeholder stays for species with no GLB (allosaurus, triceratops, ...).
- `stegosaurus.json` (pipeline only, gameplay fields untouched):
  - `authored_clips` for the 9 v2 clips. `creature.gd` plays the authored `hit_react` only when it is listed
    there; without it a v2 hit fell back to the procedural flinch.
  - `stride_matched: true`, read by the creature.gd hook below.
- `game/tests/t_stego.gd`: the acceptance test (Gates).
- `game/scripts/dev/stego_lab.gd`, `game/scenes/dev/stego_lab.tscn`: the lab. Idle and walking run the
  game's own physics step (gait, cadence, ground conform), then attack_primary, a real `_on_damaged` hit and
  death are posed; it measures each toe against the terrain at the camp spot and on the steepest slope within
  30 m; `--stego-perf` times frames with 4 stegosauri in the game camera's view against none.
  `Godot --path game --resolution 1600x900 [--rendering-method gl_compatibility] -- --lab=stego_lab
  --stego-island=<id> --stego-at=x,z [--stego-out=<prefix>] [--stego-perf]`. Exit 1 on a failed check.
- `asset-replacement.md`: stegosaurus row -> REVIEW.

Hooks patch, one line each:

- `creature.gd` (W2-CVIEW): the walk/run call uses `anim.set_move_speed(speed)` when
  `def.pipeline.stride_matched`, else the old `play_locomotion(speed / 8)`; after `_slide()` in the alive step
  it calls `view.conform_to_ground(delta)`. Only the stegosaurus opts in to stride matching: W1-CANIM's report
  says not to wire `set_move_speed` for the donor-clip species yet.
- `creature_view.gd` (W2-CVIEW, the non-stegosaurus lines): `conform_to_ground` for GLB quadrupeds (pitch, roll
  and height from the terrain under the four feet, picked once at setup as the lowest bone per quarter) and
  `body_box` (the model's rest bounds).
- `creature_plates.gd` (W1-UI): `creature_box` uses `view.body_box` for GLB rigs instead of
  `real_length_m` x `body_radius` (the old formula stays for placeholders).
- `anim_events.json` (W1-CANIM): `natural_speeds.stegosaurus` from `tools/bake_clip_speeds.py`:
  walk 0.961 m/s (L 0.961, R 0.961), run 3.458 (L 3.461, R 3.455), height 6.4, lens 1.6 / 0.8. The re-bake
  left the other 10 species byte-identical (checked with `--dry-run` first).
- `tools/bake_clip_speeds.py`: the foot list learns v2's `hind_toe_L/R` (it only knew `BackFoot.L`, `Toe.L`,
  `Metatarsal.L`, so it skipped the stegosaurus).

## Before and after

All PNGs under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/stego/`:

- `before3/` (today's base ddaab662 + the lab only, tree `trees/stego-before`): 42 shots,
  `{fwd,glc,phone}_{home_grassland,temperate_45}_{idle,walk,attack,hit,dead,slope,iso}.png`, sheets
  `before3/sheet_*.png`. The box placeholder: a slab body on one cylinder leg pair, seven upright slabs, four
  bars for spikes; dead = the slab tipped over, red-tinted.
- `after/` (this work tree, hooks applied): the same 42, sheets `after/A_*.png` (idle, walking, attack, hit)
  and `after/B_*.png` (dead, slope, iso).
- Configs: `fwd` 1600x900 Forward+, `glc` 1600x900 gl_compatibility, `phone` 844x390 gl_compatibility.
  Islands: `home_grassland` at (4, 16) and `temperate_45` at (-160, 20), next to the crater spawn where
  stegosauri actually live (temperate_35 and temperate_45 spawn them; temperate_25 does not).
- Skin-in-motion frames (raw rig, neutral light): `probe/ts_<clip>_{side,rear34}.png`, 9 times per clip.
- Perf frame: `perf/glc1_temperate_45_perf.png`.

What I saw in every AFTER PNG: the v2 silhouette (small head, arched back, two rows of plates, four
thagomizer spikes) reads in all three configs on both islands; the survivor reaches about the knee, the plates
top out at 6.3 m. Feet stand on the terrain at both camp spots and on both slopes (the animal pitches up the
slope). Walking shows the trot with a diagonal pair lifted. Hit shows the hit_react pose, the white hit sparks
and the aggro ring. Dead lies on its side, belly to the camera, legs out. No stretched skin, no plate leaving
its base, no gaps at the tail spikes. gl_compatibility matches Forward+ apart from shadow softness.
The attack shot is side-on at the hit frame; the tail sweeps sideways, so it reads less than in
`probe/ts_attack_heavy_rear34.png`.

## Checks, with numbers

**Model, axis, scale.** Spawned through the game's path: GLB rig, 34 bones (jaw, tail_07), 29,928 triangles,
skinned. Rest mesh spans y 0.00 .. 6.40 m in the creature's frame; head bone z -3.12, tail tip z +7.49, so it
faces -Z with no extra yaw (pipeline `forward_axis: "-Z"`, `source_height_m: 6.4`, scale 1.0).
Mesh bounds 2.42 x 6.40 x 11.88 m.

**Clips.** All 9 load from their own GLBs: 21-26 tracks each, 0 unresolved (every track's bone exists in the
skeleton); each differs from idle (largest rotation gap 0.41-1.35 rad). Import log lines:
`[creature] clip <name> tracks=23-28 remapped=all missing=0 scale_dropped=2`. The 2 dropped scale tracks are
float noise: every scale channel in the 9 GLBs is 1.000 (checked in the glTF accessors). 0
"couldn't resolve track" and 0 SCRIPT ERROR in t_stego, every stego_lab run and the perf runs.

**States.** A real `_on_damaged` hit plays hit_react, then idle; alert, attack_primary and attack_heavy play
and return to idle; knockdown holds with the lowest skin at 0.00 m; death ends lying down, skin 0.00 .. 2.98 m.
Capture: groggy at 20 % HP, one hit -> knockdown status, knockdown clip held, `capturable()` and
`field_tame_open()` true.

**Skin in motion (the reason for the old override).** CPU-skinned every clip at 0/25/50/75/100 % and compared
each triangle edge with its rest length. v2: worst edge growth 0.200 m (death at 50 %, a few shoulder-crease
edges), 268 edge-samples over 0.10 m across 45 poses, none over 0.25 m. The v1 transplant: 0.387 m (run),
749 over 0.10 m. Looking at the frames (`probe/ts_*`): the stretched edges are inside the armpit and neck crease;
nothing visible at gameplay range, plates stay on their bases through death's roll. No defect to report.
A first probe of mine showed plates "sinking" and the run lying on its side. That was the probe, not the
asset: it reused an AnimationPlayer without resetting the skeleton, so death's roll leaked into the next clip.
The game's AnimationTree resets unkeyed bones to rest, and the test resets between clips.

**Sliding.** v2's walk strides 0.96 m/s and its run 3.46 m/s at cadence 1. The game's current path,
`play_locomotion(speed / 8)`, plays the walk at x1.0 at roam speed (3.5-4.6 m/s with genetics): planted toes
0.96 m/s under a 3.86 m/s body, a 4x slide (t_stego on the branch without the hooks). With the hook:
roam 3.55 m/s -> run x1.03, toes 3.56; chase 2.49 m/s -> run x0.72, toes 2.49; 1.2 m/s -> walk x1.25, toes 1.20.
All four toes within 1 % of the body. Consequence for the owner: at the stat speed (400 = 4 m/s) a roaming
stegosaurus plays its run (a trot); the walk shows only under about 1.8 m/s (slowed, trapped).

**Feet on the terrain.** Before the conform hook, on the 23-degree slope of home_grassland: front toes
0.52-0.63 m inside the ground, hind toes 0.83-0.87 m in the air (no creature tilts to slopes; the capsule's
round bottom also lifts the body 0.19 m there). Terrain within 20 m of the spawned stegosauri: temperate_45 (5 animals, 2,205
samples) 83 % under 5 degrees, 16 % 5-15, 0.5 % 15-20; temperate_35 (1 animal) all under 5. With the hook (AFTER lab runs): camp spots worst
0.00 / 0.07 m, 21.2-degree slope worst 0.11 m, 19.3-degree crater rim worst 0.06 m (gate 0.25 m).

**Plates, HP bar, aggro ring.** Idle top of the plates 6.32 m; the HP bar's world anchor (height + 0.3) is
6.70 m, just above. The aggro ring is drawn on the terrain at the leash radius and does not read the height.
In the game's iso camera the bar sat far above the animal (y 35 px for a plate top at y 375) because
`creature_plates` keeps the pill off a box `real_length_m` (18 m) long, longer than the 11.9 m model. With the
plates hook the box is the model's own bounds: same frame, bar at y 178. It still floats about 200 px above the
plates in the iso view because an axis-aligned box is loose at its top corners for an animal whose ends are low;
the side views put it 0.4 m + 70 px above the plates. Not fixed further here: a tighter silhouette test is
W1-UI's call. At 844x390 the side-camera shots show no pill (no free spot on the small screen); the iso phone
shot shows it.

**Pets, mount.** The height readers (`creature_plates`, `gather_ring` tame ring at height + 0.35, `hunt` aim,
mass proxy, drip, label) read `height_meters` (6.4, unchanged), so they behave as before. The stegosaurus has no
`mount/mount.json` and its tamed roles are bag and combat, so `begin_ride` is not reachable; the generic mount
socket stays at 0.85 x height on the view.

**Frame cost (gl_compatibility, 1600x900, 4 stegosauri in the iso view, vsync off, 300 frames).**
Run 1: 4.950 ms/frame with them, 3.556 ms without, +1.395 ms. Run 2: 6.041 vs 3.862 ms, +2.179 ms. The machine was shared with other
workflows' Godot runs, so treat it as an upper bound.

## Gates

Logs under `.../scratchpad/stego/gates/` and `.../scratchpad/stego/gates_after/`.

| Gate | Result |
|---|---|
| t_stego on today's code (tree `trees/stego-before`: ddaab662 + the lab, t_stego copied in) | exit 1: `FAIL spawned stegosaurus is the GLB rig, not the box placeholder (using_glb=false)`, then clips, states, stride and skin each `FAIL ...: no GLB rig`, `FAIL creature_view.gd has no stegosaurus override or fallback` |
| t_stego on the branch without the hooks patch (same tree at da00f610) | exit 1, only the stride section: `FAIL walk and run natural speeds baked`, `FAIL game physics step (roam) at 3.86 m/s -> walk x1.00: planted toes [0.96, 0.96, 0.96, 0.96] m/s`, same for chase and set_move_speed |
| t_stego with the hooks (this tree) | exit 0, `[t_stego] PASS`, 6 of 6 sections, lines quoted under Checks |
| every `game/tests/t_*.gd` (23 files, hooks applied) | all exit 0 and print PASS: t_ai, t_build, t_canim, t_combat, t_data, t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, each announced by the test), t_server_domain, t_srvdom, t_stego, t_structart, t_tame, t_ui, t_uiicons, t_w2_skills, t_water, t_web; 0 SCRIPT ERROR elsewhere |
| `run_all.gd` | exit 0, `[tests] PASS` (its fixed list does not include t_stego; run it on its own) |
| `tools/smoke.sh --no-import` | `[smoke] ok player_pos=(0.0, 1.0, 0.0) phase=day`, `SMOKE PASS` |
| stego_lab AFTER, windowed, 6 runs (2 islands x Forward+ / gl_compatibility / 844x390) | all `[stegolab] PASS`, 0 SCRIPT ERROR, 0 "couldn't resolve track"; the only warnings are LabKit's nav-bake mesh parse and the iso camera interpolation notice, also present in every BEFORE run |
| stego_lab AFTER, headless: home_grassland (4,16), temperate_45 (-36,92), (-160,20), (-150,30) | all PASS; slopes 21.2, 2.3, 19.3, 19.2 degrees, worst toe 0.11, 0.01, 0.06, 0.03 m |
| stego_lab BEFORE, windowed, 6 runs | `FAIL stegosaurus uses its GLB (using_glb=false)` as expected, 0 SCRIPT ERROR |
| frame cost, gl_compatibility 1600x900, `--stego-perf` | +1.395 ms and +2.179 ms per frame for 4 stegosauri (two runs) |
| `--import` | once at the start (exit 0); no asset changed after it |

## What W2-RAGDOLL must re-tune (do not merge blind)

The ragdoll branch (`claude/mmo-w2-ragdoll`, 56890436) built its stegosaurus profile on the v2 GLB through a
lab-only flag, so the profile itself fits this skeleton. What changes once STEGO lands:

1. `creature_view.gd` conflict: it adds `static var allow_stegosaurus_rig` and edits the override line STEGO
   deletes. Drop the flag, and the `CreatureView.allow_stegosaurus_rig = true` line in `ragdoll_lab.gd`.
2. `t_ragdoll._test_placeholder_body` asserts "stegosaurus is the placeholder in game" and expects the
   "no skeleton" fallback. It will fail; point it at a species with no GLB (allosaurus, triceratops, ...).
3. In game the stegosaurus now takes the ragdoll path (2,500 kg profile, pins at hips and shoulders) instead of
   the death-clip fallback: re-run the 4-at-once budget and the perf gate with real in-game stegosauri.
4. `Ragdoll.on_death` reads `creature.view.transform` as its tilt start. With the conform hook the view of a
   GLB quadruped is already pitched, rolled and lifted on a slope; check the rest solve and the corpse lift on
   the slope cases (stegosaurus, protoceratops, megaloceros, zebraceratops).
5. Its report line "Stegosaurus in game is still the box placeholder" becomes false.

## Assumptions

- A triangle edge growing more than 0.25 m in a pose is visible stretching on a 6.4 m animal (t_stego).
- A toe within 0.25 m of where it rests on flat ground stands on the terrain (stego_lab).
- Ground conform for every GLB quadruped, not just the stegosaurus: the same tilt problem, the same fix. It
  touches protoceratops, megaloceros and zebraceratops on slopes (smaller animals, smaller error).
- The stride opt-in is a data flag (`pipeline.stride_matched`) so W2-CVIEW can wire every species later and
  delete it.

## Not done, and risks

- `real_length_m` stays 18.0 (the model is 11.9 m nose to spikes). It drives the collision radius (2.16 m vs a
  1.21 m half-width), melee reach, pack spacing and the mass proxy, so changing it is a balance call for the
  owner, not this package. Its only visual effect (the plate box) is handled by the hook.
- The hide reads grey-blue in game light; `look` and `texture_prompt` ask for green-brown with orange-edged
  plates. A retexture is an art job (register row notes it).
- `game/assets/creatures/stegosaurus/work/rig_manifest.json` is still v1's manifest (transplant route, +Z).
  Not used at runtime; worth replacing or deleting with the v1 files.
- `creature_anim_lab` was not changed (its lanes are fixed); stego_lab is the creature lab for this gate.
- The plate pill in the iso view still sits about 200 px above a close stegosaurus (see above).
