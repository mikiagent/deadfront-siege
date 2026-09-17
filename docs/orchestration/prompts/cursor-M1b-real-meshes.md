# Cursor follow-up M1b — make real creature GLBs work, then commit

Your M0–M3 reports were reviewed and accepted; the labs reproduce every line you quoted. This follow-up fixes what only showed up once real animated meshes landed under `game/assets/creatures/`. Stand-in dinosaurs (CC0, one file per clip exactly as SCHEMA describes) now exist for velociraptor, deinonychus, utahraptor and protoceratops. Read `game/data/creatures/SCHEMA.md` §2–3 again (revised) and the `pipeline` block in each species JSON.

## Observed in `--lab=creature_lab` (headless)

```
[creature] warning AABB height=4.83 def.height_meters=0.80 species=velociraptor
[creature] warning AABB height=4.22 def.height_meters=2.00 species=utahraptor
[creature] missing bone RootNode/Armature  Dino/Skeleton3D:LeftLegB
[creature] missing bone RootNode/Armature  Dino/Skeleton3D:Spine
... (one per bone, every clip, every species)
```

The mesh is instantiated under `View/Mesh`, so the imported hierarchy is `View/Mesh/RootNode/Armature  Dino/Skeleton3D`. The clip files carry track paths relative to their own root (`RootNode/Armature  Dino/Skeleton3D:Bone`). Nothing remaps them to the `AnimationPlayer`'s root, so no clip drives the skeleton. `_verify_tracks` also checks the wrong things (`view.has_node` with the unprefixed path, and `p.get_file()` returns `Skeleton3D:Bone`, not the bone name), which is why it reports every bone missing.

## Tasks

1. **Remap clip tracks.** In `CreatureClips._from_glb`, after duplicating the animation, find the creature's `Skeleton3D` under `View`, compute `rel := ap.get_node(ap.root_node).get_path_to(skel)`, and for every track whose path ends in `Skeleton3D:<bone>` (or any `<node>:<bone>` where `<bone>` is a bone of `skel`), set the path to `"%s:%s" % [rel, bone]`. Do the same for `_steal_embedded`. Fix `_verify_tracks` to check `skel.find_bone(bone) != -1` on the subname only. Log one line per clip: `[creature] clip <name> tracks=<n> remapped=<n> missing=<n>`.

2. **Normalise facing and scale in `CreatureView.setup`** per SCHEMA §3: read `def.pipeline.forward_axis` (default `-Z`) and rotate `Mesh` so that axis points to `-Z` (`+Z` → 180° yaw, `+X` → 90°, `-X` → -90°, `-Z` → 0). Remove the unconditional 180° yaw on the view itself, or keep it and compensate, but the placeholder must still face the same way it does now. Then measure the mesh AABB height (or use `def.pipeline.source_height_m` when present) and set `Mesh.scale` uniformly to `def.height_meters / measured`. Move the AABB warning after scaling so it only fires when the result is still off by more than 15%. `MountSocket` height must use the scaled height.

3. **Clip fallbacks** (SCHEMA §2): the stand-ins have `idle, walk, run, attack_primary, attack_heavy, death, knockdown` and no `hit_react`, `alert`, or `feed`. Implement the fallbacks: `run` = `walk` with `AnimationTree` time scale 1.6 when the run file is absent (the stand-ins do ship a `run.glb` that is identical to walk, so the time scale must apply either way — drive it from a per-clip `speed` in `anim_events.json` with default 1.6 for run when `pipeline.stand_in` exists); `hit_react` = the first 40% of `knockdown`; `alert` = `idle`. Loop modes: idle/walk/run loop, everything else holds its last frame.

4. **Expose a `CreatureDef.pipeline: Dictionary`** so the above can read the JSON block, and treat `archetype` values from SCHEMA §4 as canonical: map `raptor_pack` and `apex_raptor` to `RaptorPackBrain` (keep your `pack_raptor` / `pack_flanker` aliases working).

5. **Input hygiene** (mobile rule): `player.gd` line ~177 reads `InputEventMouseButton` directly for tap-to-target; use the `tap` action instead. Line ~167 reads `KEY_1 + i` for lab clip forcing; keep it, but only when `Game.lab_force_clips` is true (dev-only). Register `hunt_chase` and `bandage` in `scripts/core/input_setup.gd` if they are not already, and add touch buttons for them in `scripts/ui/touch_controls.gd` (`BUTTONS` array): `bandage` as a small "AID" button near USE, `hunt_chase` as a small toggle labelled "HOLD".

6. **Visual check.** Run `--lab=creature_lab` in a window (not headless). The four species must appear at roughly their `height_meters` (velociraptor knee-high to the player capsule, utahraptor taller than the player), face their movement direction, and play idle/walk/attack/death on keys 1/2/4/8. Take a screenshot with `screencapture -x docs/orchestration/reports/m1b-creature-lab.png` and reference it in the report.

7. **Commit.** Your M0–M3 work is still uncommitted (about 150 changed files). Commit it as `M0-M3: foundation, creature runtime, hunt/status, capture/pets` before starting this task, then commit this task separately as `M1b: real creature meshes, scale/facing, clip remap`. Only files under `game/scenes`, `game/scripts`, `game/data` (not `creatures/*.json`), `archive/`, and your reports.

## Acceptance
- `tools/smoke.sh` prints `SMOKE PASS`.
- `--lab=creature_lab` headless prints zero `missing bone` lines and no AABB warnings for the four stand-in species.
- The screenshot shows four correctly sized, correctly facing, animating dinosaurs.
- `docs/orchestration/reports/cursor-M1b-real-meshes.md` written, with the `[creature] clip ...` lines pasted.
