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
- **Drying-rack stages** read by value, colour and shape: empty frame on a hide mat; raw = wide, long, bright red
  strips with fat streaks (tile luma 68); drying = deep maroon, narrower, slightly curled (27); dried = near-black
  brown, thin, curled (16) with an amber fat rim down each strip so it still reads on the dark dirt disc, plus a
  tied jerky bundle on the mat. The rack frame (bark, luma 59) is identical in every stage, so swapping models
  reads as the meat changing.
- **Reproducible headless build**: `Blender -b --factory-startup -P tools/blender/structures/build.py -- [names]`
  rebuilds the atlas and any or all GLBs (`lib.py` = atlas painter, self-UVing bmesh primitives, exporter;
  `structures.py` = one builder per structure). `preview.py` renders an iso contact sheet.
- **props_manifest.json**: 23 kinds gain `glb` (res:// path) and `aabb_m` (measured, Godot axes); drying_rack gains
  `stages` [{id, glb}] x4; fence_gate and catapult gain `nodes`; new `pier` row; taming_pen now points at the
  Blender fence (its ring is built from 2 m fence segments), so the pen no longer mixes Kenney fences with the
  Blender gate. Owner rule of 2026-10-19 (low-quality and low-poly assets are marked for replacement):
  - the 18 kinds still on Kenney art and the 4 building-system stand-ins (floor, wall, wall_doorway, roof) are
    `art_status: REPLACE`;
  - the other 19 Blender kinds are `REVIEW`, and every Blender row carries `upgrade`, which records that it is
    low-poly (36-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map) and gives
    the upgrade path (a higher-poly PBR model keeping origin, pivots and aabb_m).
  `model` stays on every row as the fallback until the integrator hook below lands, so nothing in game changes
  before then.
- `tools/blender/structures/check_manifest.py` (enforces the acceptance rules; `--write` regenerates the rows),
  `glb_info.py` (pure-Python GLB reader), lab `structart_lab`, test `game/tests/t_structart.gd`, and the review
  shot `tools/blender/structures/built_base_shot.gd`.

Commits: ddc1aef (WIP helper), 04027fe, 5cb3f5c, 59f1f3f, 209539f, 8fb71cf, 825ef4c, 82f06dc, 45efa5f (first
report); review round: 1c2417a, 8be17c1, 78a251d and the commit carrying this update.

## Acceptance checklist

| Item | Result (exact line) |
|---|---|
| check_manifest prints PASS, every kind resolves to an existing GLB | `[check_manifest] PASS 41 kinds resolve to existing GLBs (23 Blender, 18 Kenney marked REPLACE, 4 Blender stand-ins marked REPLACE)` |
| Each GLB <= 4k tris, one atlas material, origin at ground centre, footprint within manifest AABB +-5 % | enforced by check_manifest (same PASS line; largest is pier at 1416 tris) and in Godot by `[t_structart] PASS` (material path == structures_atlas.tres, measured AABB vs aabb_m within 5 %) |
| Four drying-rack stages differ | `[t_structart] drying_rack stages ["empty", "raw", "drying", "dried"] distinct`; check_manifest now also fails when two stage GLBs hash the same; seen in the shots below |
| Stages separate by value, dried clear of the frame | `[t_structart] stage luma raw 68 drying 27 dried 16, frame bark 59` (test fails on a step under 10 or dried within 20 of the bark) |
| Atlas imported with mipmaps | `[t_structart] PASS` (fails when `structures_atlas.png` has no mipmaps); `godot_import_settings.py` prints `[import_settings] structures_atlas.png mipmaps on` and forces `mipmaps/generate=true` |
| Low-poly marking | `[t_structart] PASS` (fails when a stand-in is not REPLACE or a Blender row has no `upgrade`); check_manifest enforces the same |
| Windowed 1600x900 scripted base, Forward+ | `[audit] swapped 23 visuals, racks 4` / `[audit] shot .../r5_base_forward.png` (+ `_racks.png`) |
| Same in gl_compatibility | `OpenGL API 4.1 Metal - 90.5 - Compatibility` / `[audit] shot .../r5_base_compat.png` (+ `_racks.png`) |
| --lab=build_lab headless still passes | exit 0, `[build] restored 6` (this base has no `[build] PASS` line; that line is W1-BUILD's addition). Colliders are unchanged until the hook; the new aabb_m values are what the hook makes them use |
| t_structart | `[t_structart] PASS` |
| run_all suite | `[tests] PASS` |
| smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |
| structart lab (windowed, cam 28) | `[structart] lab placed 24 models, missing []` (run before the last colour-only rebuild; same 24 files) |
| field_catapult hook parses | scratch copy with the hook compiled in a headless `GDScript.reload()`: no error on the hook lines (only the copy's own self-type errors from dropping `class_name`); a control copy with `modl` typo fails with `Identifier "modl" not declared` |

## Screenshots inspected

All under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/structart/`:

Review round (current art):

- `r5_base_forward.png` (cam size 22, gameplay zoom) and its crop `r5_forward_racks_crop.png`: empty rack is bare
  poles; raw is bright red; drying is visibly darker maroon; dried shows thin dark curled strips with amber rims
  and no longer reads as an empty rack. `r5_base_forward_racks.png` (cam 10) shows the same at close range.
- `r5_base_compat.png`, `r5_compat_racks_crop.png`: gl_compatibility. All four still distinct, but the web renderer
  lights the maroon brighter, so raw vs drying separate less there than in Forward+ (see "left").
- `r4_lab_28.png` and its crop `r4_pier_crop.png`: the pier deck now reads as boards with staggered butt joints
  and wood grain; the earlier wavy moire is gone (mipmaps on, ~1 m board lengths).
- `r2_base_racks_crop.png` / `r3_base_racks_crop.png`: the intermediate attempts (near-black dried strips vanished
  on the dirt; then pale rims read as sticks), kept as the evidence for the rim colour choice.

First round:

- `built_base_forward.png`, `built_base_forward_racks.png`: the audit base rebuilt with every placed visual
  swapped for its GLB. No salmon palette on any swapped kind; tent, well, smoker, catapult, fences and gate
  read at gameplay zoom.
- `built_base_compat.png`, `built_base_compat_racks.png`: same in gl_compatibility.
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

`game/scripts/world/field_catapult.gd` `_ready()` (land it after the prop_visuals hook: the catapult row has no
Kenney `model`, so until then attach_model returns null and the primitives stay). Three added lines; the
collision box and label are untouched:

```gdscript
	add_child(shape)
	var model := PropVisuals.attach_model(self, kind)  # Blender catapult once prop_visuals reads the glb row
	for spec in [[Vector3(2.0,0.25,2.0),Vector3(0,0.25,0)], ...unchanged...]:
		if model != null: continue
		var mesh := MeshInstance3D.new()
	...
	for x in [-0.85,0.85]:
		if model != null: continue
		for z in [-0.65,0.65]:
```

Taming pen (`taming_pen.gd`, W1-TAME/W1-BUILD): no code change needed. The manifest `taming_pen` row now points at
the Blender `fence.glb`, so once the prop_visuals hook lands `model_path(&"makeshift_taming_pen")` returns the
Blender fence and `model_path(&"gate")` the Blender gate: one style. Before the hook the pen keeps both Kenney
pieces. The pen's collider is set explicitly in `_build_visual` (4 x 1.8 x 4), so the row's fence-sized `aabb_m`
does not shrink it; the placement ghost already showed one fence segment and still does.

Asset-replacement register (`docs/orchestration/mmo/asset-replacement.md`, orchestrator-owned and not on this
branch): proposed rows, Structures and props table:

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Kenney survival-kit structures (fences, frames, workbench, basket, etc.) | Flat salmon palette | Blender set with one atlas | W1-STRUCTART | REVIEW (built; in game after the prop_visuals hook) |
| W1-STRUCTART Blender set (tent, catapult, smoker, well, racks, crock pot, steamer, mortar, fires, fence, gate, sign, basket, workbench, pier) | Low-poly: 100-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map | Higher-poly Blender rebuild with PBR normal/roughness keeping origin, pivots, aabb_m (manifest `upgrade`) | W1-STRUCTART, later art pass | REVIEW (low-poly, upgrade path recorded) |
| Building-system stand-ins floor, wall, wall_doorway, roof | Bare 1 m boxes and logs | Blender modular kit per tier | W2-BUILDSYS | REPLACE |
| 18 Kenney manifest kinds without a Blender model (technical_workbench, grindstone, tent_canvas, bedroll, large_box, chest, barrel, bucket, fence_fortified, signpost, fishing_stand, field_small, field_large, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand) | Kenney placeholder | Blender | unassigned | REPLACE |
| Harbour | Grey box inland | Pier model built; coast placement | W2-TERRAIN | REPLACE (pier built) |
| Cargo Warp | Procedural orange primitive (`cargo_warp.gd`) | Blender | unassigned | REPLACE |
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
- Stage colours are my reading of the owner's "darker drying strips, dark dried strips": deep maroon, then
  near-black brown with an amber fat rim (geometry, tile `meat_fat`). The rim is my addition so the near-black
  strips do not vanish on the dark dirt disc; a pale rim was tried first and read as sticks.
- The hero stations keep their low-poly budgets (largest 1416 tris). I chose to mark them REVIEW with an upgrade
  path rather than spend more triangles now; the owner may prefer an immediate higher-poly pass.

## What failed or is left

- **Review round response.** Fixed: atlas mipmaps (enforced by godot_import_settings.py and t_structart);
  stage values (t_structart luma assertions); stand-ins REPLACE plus `upgrade` on every Blender row (t_structart and
  check_manifest); exact field_catapult hook; taming pen now on the Blender fence; per-length pier boards;
  check_manifest stage-hash check. Not fixed: byte-identical rebuilds. Rebuilds still differ by a few bytes inside
  normal/tangent buffers (the reviewer rated it acceptable; geometry, JSON and checks are stable).
- **Owner, please confirm about Blender.** It is still not running (checked with pgrep this round), so the Blender
  MCP lock is unusable. Before an integrator merges this branch, the owner should reopen Blender and confirm
  nothing was lost from the crash below.
- **I crashed the owner's Blender.** My first live build switched the window to a temporary scene and ran the glTF
  exporter under `temp_override`; Blender 5.2 segfaulted in the depsgraph (crash log
  `~/Library/Logs/DiagnosticReports/Blender-2026-10-19-085350.ips`). The open file was unsaved and held only
  the default 3-object scene, so I do not believe anything was lost, but the owner should know, and the Blender
  MCP connection is down until they reopen Blender with the addon. After that every build ran headless
  (`lib.new_scene` now refuses to run inside a live session); I did not touch Blender MCP again.
- The art is not in game until the hooks above land (deliberate: prop_visuals/field_catapult belong to W1-BUILD).
- Not built: technical_workbench, grindstone, bedroll, large_box, chest, barrel, bucket, fortified fence,
  signpost, fishing stand, fields, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand, tent_canvas
  (all marked REPLACE). Cargo Warp is procedural and needs a register row (proposed above).
- gl_compatibility lights the tent canvas and the drying-stage maroon brighter than Forward+; raw vs drying stays
  distinct there but by less. Worth a look on the web build (W1-LIGHT owns lighting).
- The register itself is not edited: it is orchestrator-owned and not on this branch. The rows to apply are
  under Integrator hooks; the manifest (`art_status` + `upgrade`) carries the marking in the meantime.
- No credits spent (no Meshy/Tripo/generate_3d).
