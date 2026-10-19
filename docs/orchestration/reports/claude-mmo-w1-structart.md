# W1-STRUCTART: Blender structure set with visible processing stages

Branch `claude/mmo-w1-structart` (cut from `claude/mmo-overhaul`). Closes build-art-01 and the art half of
world-harbour-07 (pier model only; placing it on the coast is W2-TERRAIN).

## What shipped

- **24 hand-built GLBs** in `game/assets/props/blender/`: tent, basket, workbench, sign, fence, gate (LeafL/LeafR
  nodes with their origins on the hinges), campfire, bonfire, stone_fire_pit (with spit), drying_rack in four
  stages (`drying_rack`, `_raw`, `_drying`, `_dried`), smoker, crock_pot, steamer, mortar, well, catapult (textured
  spoked wheels, `Arm` node with its origin on the axle), pier (3 x 8 m dock), and floor/wall/wall_doorway/roof
  stand-ins for W2-BUILDSYS. 36-984 triangles each, one material, origin at the ground centre, front faces +Z.
- **One 1024 atlas for the whole set** (`structures_atlas.png`, 8x8 tiles of 128 px painted procedurally: wood
  grains, planks, bark, log ends, canvas, hide, rope, thatch, weave, stone, cobble, clay, iron, ash, embers,
  water, soot, carved sign board, cart wheel, and the three meat stages). Godot uses one shared material
  `structures_atlas.tres`; each GLB's `.import` points at it and discards the GLB's embedded copy
  (`tools/blender/structures/godot_import_settings.py`), so the set loads one texture.
- **Drying-rack stages** read by colour and shape: empty frame on a hide mat; raw = wide, long, bright red strips
  with fat streaks; drying = dark red, narrower, slightly curled; dried = leathery brown, thin, curled, plus a tied
  jerky bundle on the mat. The frame is identical in every stage so swapping models reads as the meat changing.
- **Reproducible headless build**: `Blender -b --factory-startup -P tools/blender/structures/build.py -- [names]`
  rebuilds the atlas and any or all GLBs (`lib.py` = atlas painter, self-UVing bmesh primitives, exporter;
  `structures.py` = one builder per structure). `preview.py` renders an iso contact sheet.
- **props_manifest.json**: 22 kinds gain `glb` (res:// path), `aabb_m` (measured, Godot axes), `art_status:
  REVIEW`; drying_rack gains `stages` [{id, glb}] x4; fence_gate and catapult gain `nodes`; new `pier` row. The 19
  kinds still on Kenney art keep `model` and are marked `art_status: REPLACE` (owner rule of 2026-10-19:
  low-quality assets are marked for replacement). `model` stays on every row as the fallback until the
  integrator hook below lands, so nothing in game changes before then.
- `tools/blender/structures/check_manifest.py` (enforces the acceptance rules; `--write` regenerates the rows),
  `glb_info.py` (pure-Python GLB reader), lab `structart_lab`, test `game/tests/t_structart.gd`, and the review
  shot `tools/blender/structures/built_base_shot.gd`.

Commits: ddc1aef (WIP helper), 04027fe, 5cb3f5c, 59f1f3f, (uids), 8fb71cf, (stages/canvas), plus this report.

## Acceptance checklist

| Item | Result (exact line) |
|---|---|
| check_manifest prints PASS, every kind resolves to an existing GLB | `[check_manifest] PASS 41 kinds resolve to existing GLBs (22 Blender, 19 Kenney marked REPLACE)` |
| Each GLB <= 4k tris, one atlas material, origin at ground centre, footprint within manifest AABB +-5 % | enforced by check_manifest (same PASS line; largest is drying_rack_dried at 984 tris) and in Godot by `[t_structart] PASS` (material path == structures_atlas.tres, measured AABB vs aabb_m within 5 %) |
| Four drying-rack stages differ | `[t_structart] drying_rack stages ["empty", "raw", "drying", "dried"] distinct`, and seen in the shots below |
| Windowed 1600x900 scripted base, Forward+ | `[audit] swapped 23 visuals, racks 4` / `[audit] shot .../built_base_forward.png` (+ `_racks.png`) |
| Same in gl_compatibility | `[audit] shot .../built_base_compat.png` (+ `_racks.png`) |
| --lab=build_lab headless still passes | exit 0, `[build] restored 6` (this base has no `[build] PASS` line; that line is W1-BUILD's addition). Colliders are unchanged until the hook; the new aabb_m values are what the hook makes them use |
| t_structart | `[t_structart] PASS` |
| run_all suite | `[tests] PASS` |
| smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |
| structart lab headless | `[structart] lab placed 24 models, missing []` |

## Screenshots inspected

All under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/structart/`:

- `built_base_forward.png`, `built_base_forward_racks.png`: the audit base rebuilt with every placed visual
  swapped for its GLB. No salmon palette on any swapped kind; tent, well, smoker, catapult, fences and gate
  read at gameplay zoom; the four racks show empty / bright red / dark red / brown strips.
- `built_base_compat.png`, `built_base_compat_racks.png`: same in gl_compatibility; stages still distinct.
- `lab_forward_10.png` (four racks side by side, close) and `lab_forward_28.png` (the whole set).
- `sheet1.png`, `racks.png`, `groupA.png`, `groupB.png`, `groupC.png`: Blender Eevee contact sheets.

Still visible in those shots and not mine: the orange procedural Cargo Warp (`cargo_warp.gd`), the grey harbour
slab, and the Kenney stone_grill/field kinds (marked REPLACE).

## Integrator hooks (W1-BUILD owns these files)

`game/scripts/world/prop_visuals.gd`, in `model_path()` after `var row := _building_row(kind)`:

```gdscript
	var glb := str(row.get("glb", ""))
	if glb != "" and ResourceLoader.exists(glb):
		return glb
```

and at the top of `collision_size()` after `var row := _building_row(kind)`:

```gdscript
	var aabb: Variant = row.get("aabb_m", null)
	if str(row.get("glb", "")) != "" and aabb is Array and (aabb as Array).size() >= 3:
		return Vector3(maxf(0.2, float(aabb[0])), maxf(0.2, float(aabb[1])), maxf(0.2, float(aabb[2])))
```

`game/scripts/world/field_catapult.gd` `_ready()`: before the box/cylinder loops,
`if PropVisuals.attach_model(self, kind) != null: <skip the primitive meshes>` (keep the collision box and label).
Gate open state (W1-BUILD): rotate `Prop/gate/LeafL` and `LeafR` about Y (hinges at x = -/+0.84).
Drying rack (W2-PROCESS): swap the Prop to `row.stages[i].glb` per stage; `StructartLab.glb_path(kind, stage)`
and `StructartLab.swap_visual(node, stage)` show the lookup.

## Labs to register

- `structart_lab` (`game/scripts/dev/structart_lab.gd`, `game/scenes/dev/structart_lab.tscn`).

## Assumptions

- `# ASSUMPTION` in structures.py: building-system pieces are 1 m modules (manifest footprints are 1x1); W2-BUILDSYS
  sets the real size.
- `# ASSUMPTION` in the manifest pier row: the pier's pile feet sit at y = 0 and W2-TERRAIN sinks them into water.
- `canvas_tent` reuses the tent model; `tent_canvas` (3x2) stays Kenney and REPLACE.
- Stage colours for "drying" and "dried" are my reading of the owner's "darker drying strips, dark dried strips";
  dried is leathery brown rather than near-black because black strips vanished against the dark dirt disc.

## What failed or is left

- **I crashed the owner's Blender.** My first live build switched the window to a temporary scene and ran the glTF
  exporter under `temp_override`; Blender 5.2 segfaulted in the depsgraph (crash log
  `~/Library/Logs/DiagnosticReports/Blender-2026-10-19-085350.ips`). The open file was unsaved and held only
  the default 3-object scene, so I do not believe anything was lost, but the owner should know, and the Blender
  MCP connection is down until they reopen Blender with the addon. After that every build ran headless
  (`lib.new_scene` now refuses to run inside a live session); I did not touch Blender MCP again.
- The art is not in game until the hooks above land (deliberate: prop_visuals/field_catapult belong to W1-BUILD).
- Not built: technical_workbench, grindstone, bedroll, large_box, chest, barrel, bucket, fortified fence, taming
  pen, signpost, fishing stand, fields, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand (all
  marked REPLACE). Cargo Warp is procedural and should get a register row.
- gl_compatibility lights the tent canvas brighter than Forward+; acceptable but worth a look on the web build.
- `docs/orchestration/mmo/asset-replacement.md` is not on this branch and not mine: suggest setting the
  Structures rows for Kenney structures, Tent, Catapult and the processing stations to `REVIEW (W1-STRUCTART
  built; needs the prop_visuals hook)`, the Harbour row to `REPLACE (pier model built; placement W2-TERRAIN)`,
  and adding rows for the 19 manifest kinds marked REPLACE and for Cargo Warp.
- No credits spent (no Meshy/Tripo/generate_3d).
