# W1-STRUCTART: Blender structure set with visible processing stages

Branch `claude/mmo-w1-structart` (cut from `claude/mmo-overhaul`). Closes build-art-01 and the art half of
world-harbour-07 (pier model only; placing it on the coast is W2-TERRAIN).

## What shipped

- **24 hand-built GLBs** in `game/assets/props/blender/`: tent, basket, workbench, sign, fence, gate (LeafL/LeafR
  nodes with their origins on the hinges), campfire, bonfire, stone_fire_pit (with spit), drying_rack in four
  stages (`drying_rack`, `_raw`, `_drying`, `_dried`), smoker, crock_pot, steamer, mortar, well, catapult (textured
  spoked wheels, `Arm` node with its origin on the axle), pier (3 x 8 m dock), and floor/wall/wall_doorway/roof
  stand-ins for W2-BUILDSYS. 36-1416 triangles each, one material, origin at the ground centre, front faces +Z.
- **One 1024 atlas for the whole set** (`structures_atlas.png`, 8x8 tiles of 128 px painted procedurally: wood
  grains, planks, bark, log ends, canvas, hide, rope, thatch, weave, stone, cobble, clay, iron, ash, embers,
  water, soot, carved sign board, cart wheel, and the three meat stages). Godot uses one shared material
  `structures_atlas.tres`; each GLB's `.import` points at it and discards the GLB's embedded copy
  (`tools/blender/structures/godot_import_settings.py`), so the set loads one texture.
- **Drying-rack stages** read by value, colour and shape: empty frame on a hide mat; raw = wide, long red strips
  with fat marbling veins (tile luma 75); drying = deep maroon, narrower, slightly curled (27); dried = near-black
  brown, shorter, more curled (16), each strip outlined by thin amber fat rims down both edges so it still reads
  on the dark dirt disc, plus a tied jerky bundle on the mat. The rack frame (bark, luma 59) is identical in every
  stage, so swapping models reads as the meat changing.
- **Canvas is oiled ochre** (tile mean sRGB 161/106/60), not cream: in the merged sky-lit lighting a cream slope
  facing away from the sun rendered slate blue. **Pier deck** boards vary by length between weathered, fresh and
  dark timber tiles, and the weathered tile is warmer.
- **Reproducible headless build**: `Blender -b --factory-startup -P tools/blender/structures/build.py -- [names]`
  rebuilds the atlas and any or all GLBs (`lib.py` = atlas painter, self-UVing bmesh primitives, exporter;
  `structures.py` = one builder per structure). `preview.py` renders an iso contact sheet.
- **props_manifest.json**: 23 kinds gain `glb` (res:// path) and `aabb_m` (measured, Godot axes); drying_rack gains
  `stages` [{id, glb}] x4; fence_gate and catapult gain `nodes`; new `pier` row; taming_pen points at the Blender
  fence (its ring is built from 2 m fence segments) and its `aabb_m` is the assembled ring, 4.05 x 1.84 x 4.12.
  Owner rule of 2026-10-19 (low-quality and low-poly assets are marked for replacement):
  - the 18 kinds still on Kenney art and the 4 building-system stand-ins (floor, wall, wall_doorway, roof) are
    `art_status: REPLACE`;
  - the other 19 Blender kinds are `REVIEW`, and every Blender row carries `upgrade`, which records that it is
    low-poly (36-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map) and gives
    the upgrade path (a higher-poly PBR model keeping origin, pivots and aabb_m).
  `model` stays on every row as the fallback until the integrator hooks land, so nothing in game changes before
  then.
- **`tools/blender/structures/integrator_hooks.patch`**: a `git apply` diff against claude/mmo-overhaul for the
  three W1-BUILD files (prop_visuals, placed_building, field_catapult). See Integrator hooks.
- `tools/blender/structures/check_manifest.py` (enforces the acceptance rules; `--write` regenerates the rows),
  `glb_info.py` (pure-Python GLB reader), lab `structart_lab`, test `game/tests/t_structart.gd` (it also checks
  the hooks once they are applied), and the review shot `tools/blender/structures/built_base_shot.gd`.

Commits: ddc1aef (WIP helper), 04027fe, 5cb3f5c, 59f1f3f, 209539f, 8fb71cf, 825ef4c, 82f06dc, 45efa5f (first
report); review round: 1c2417a, 8be17c1, 78a251d, 3018e79; resumed round: c00a1e9, 8813169, 796ec3a; review round 3:
c06733a (marbled raw meat, warmer deck, pen collider, applyable hooks, test hook checks), 25435fd (ochre canvas,
GLBs rebuilt on the final atlas), d44ef93 and the commit carrying this correction (report).

## Review round 3: findings and responses

| # | Finding | Fix | What would have caught it (now in place) |
|---|---|---|---|
| 1 major | Prose gate hook: the Blender leaves stayed shut and W1-BUILD's plank leaf swung as a stray panel | `integrator_hooks.patch` adds exact lines to `placed_building.gd`. `_build_gate_leaf` returns when `Prop` has a `LeafL`; `_apply_gate_state` turns LeafL +100 deg and LeafR -100 deg about Y (both swing away from +Z); the GateHinge path stays for the Kenney fallback. Hooked tree shots: `hooked_gate_open_crop.png` shows a clear doorway, `hooked_gate_shut_crop.png` both leaves across it, and neither shows a plank panel | `t_structart._check_gate_hook` (runs once the hooks are applied): no GateHinge on the Blender gate, the leaves block the doorway when shut and clear it when open. Negative probe: the hooked tree with the old placed_building/field_catapult gave exit 1 and `[t_structart] FAIL hook: the Kenney plank GateHinge leaf still spawns on the Blender gate` / `FAIL hook: open gate leaves still cross the doorway (L 0 deg, R 0 deg)` |
| 2 minor | field_catapult hook elided | Full unified diff in the patch (3 added lines) | `_check_catapult_hook`: the catapult must attach `Prop` and build no BoxMesh/CylinderMesh. Same negative probe: `FAIL hook: field catapult did not attach the Blender model` / `FAIL hook: field catapult still builds its primitive placeholder` |
| 3 minor | taming_pen `aabb_m` was one fence segment | `aabb_m` = ring extent [4.05, 1.84, 4.12] (computed from `taming_pen._ring_layout`: segments at +-1.92 m, gate 1.842 m tall) | check_manifest: on the old row it printed `[check_manifest] FAIL taming_pen: aabb_m [2.006, 1.47, 0.211] is not the assembled ring [4.05, 1.84, 4.12]`; t_structart fails when an assembly's aabb_m does not cover its footprint, and with the hooks applied when `collision_size(&"makeshift_taming_pen")` is under 3.6 m |
| 4 minor | `_check_stages` crashed on a missing stage GLB | UV collection is skipped when `ResourceLoader.exists` is false (the missing file is already a failure). Also found: a runtime error inside a check let the test print PASS, so `_check_hooks` now returns true only on completion and an abort is a FAIL | Probe with the drying stage pointed at a missing file: exit 1, `[t_structart] FAIL drying_rack.drying: res://assets/props/blender/missing_stage.glb missing`, no SCRIPT ERROR |
| 5 minor | Cream canvas renders slate blue in the merged lighting and near-white in compat | Measured: the shaded slope passes about 0.31/0.5/0.8 of R/G/B (sky-lit ambient, W1-LIGHT). Specular is not the cause (metallic_specular 0 moved the slope only from 47/63/70 to 46/60/65). The canvas is now ochre with R/B 2.7, which a cream tan cannot reach while staying cream. Shaded slope: Forward+ 50/56/59 (was 47/63/70), compat 47/60/61 (was 45/67/72). Lit slope: Forward+ 199/146/102, compat 216/182/147 (not blown out). Art bible: "Player-made objects should read warmer against cooler wilderness" | Pixel samples of `ochre_fwd_racks.png` / `ochre_compat_racks.png` (sampler `scratchpad/w1/structart/tools/sample.py`) |
| 6 minor | Raw strips looked like flat plastic red; pier deck looked like grey paving | meat_raw: less saturated red with thin fat marbling veins (luma 68 -> 75; the step checks still pass). Weathered tile warmed; deck boards pick weathered/wood/wood_dark per length (crc32 hash, no diagonal pattern) | `[t_structart] stage luma raw 75 drying 27 dried 16, frame bark 59`; shots `ochre_fwd_racks_crop.png`, `lab_pier_crop.png`, `sheet2.png` |
| 7 minor | Dead `keep` / `KEEP` in build.py | Removed | `grep -n "keep\|KEEP" tools/blender/structures/*.py` finds only comments |
| 8 process | I crashed the owner's Blender in round 1 | Nothing to change in code. Owner to confirm (below). This round used headless Blender only | — |

## Acceptance checklist

Branch = this work tree at 25435fd. Hooked tree = `git merge-tree` of c06733a with claude/mmo-overhaul 8ca2496,
then `git apply tools/blender/structures/integrator_hooks.patch` (it applied with no fuzz: `Checking patch
game/scripts/world/prop_visuals.gd... placed_building.gd... field_catapult.gd...`), then 25435fd's atlas, test
and manifest copied in (`cmp`-identical), in `scratchpad/w1/structart/r8/tree`.

| Item | Result (exact line) |
|---|---|
| check_manifest prints PASS, every kind resolves to an existing GLB | `[check_manifest] PASS 41 kinds resolve to existing GLBs (23 Blender, 18 Kenney marked REPLACE, 4 Blender stand-ins marked REPLACE)` (rerun after the final rebuild) |
| Each GLB <= 4k tris, one atlas material, origin at ground centre, footprint within manifest AABB +-5 % | enforced by the same check_manifest PASS (largest: pier and drying_rack_dried, 1416 tris) and in Godot by `[t_structart] PASS` |
| Four drying-rack stages differ | `[t_structart] drying_rack stages ["empty", "raw", "drying", "dried"] distinct`; seen in `ochre_fwd_racks_crop.png` and `ochre_compat_racks_crop.png` |
| Stages separate by value, dried clear of the frame | `[t_structart] stage luma raw 75 drying 27 dried 16, frame bark 59` |
| t_structart, branch | `[t_structart] hooks not applied (gate resolves to res://assets/props/kenney/fence-doorway.glb), hook checks skipped` / `[t_structart] PASS` (exit 0, after an --import) |
| t_structart, hooked tree | `[build] gate open` / `[build] gate closed` / `[t_structart] hooks applied: gate leaves, catapult model and pen collider checked` / `[t_structart] PASS` |
| run_all suite | branch `[tests] PASS`; hooked tree `[tests] PASS` |
| smoke | branch `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |
| --lab=build_lab headless | branch exit 0, `[build] restored 6` (this base predates W1-BUILD's PASS line); hooked tree exit 0, `[build] restored 6` / `[build] PASS` (colliders now come from aabb_m) |
| Windowed 1600x900 scripted base, Forward+, hooked tree | `Metal 4.0 - Forward+` / `[audit] swapped 24 visuals, racks 4` / `[audit] shot .../r8/hooked_fwd.png` (+ `_racks.png`); with a second tent at rot 1: `[audit] swapped 25 visuals, racks 4`, `ochre_fwd.png` |
| Same in gl_compatibility | `OpenGL API 4.1 Metal - 90.5 - Compatibility - Using Device: Apple - Apple M5 Pro` / `[audit] swapped 25 visuals, racks 4`, `ochre_compat.png` (+ `_racks.png`) |
| build_lab gate shots, hooked tree | `[build] gate open` / `[boot] shot .../r8/hooked_gate_open.png`; shut: `[boot] shot .../r8/hooked_gate_shut.png` |
| structart lab (windowed), hooked tree | `[structart] lab placed 24 models, missing []` / `[boot] shot .../r8/lab_set.png` |
| Merges cleanly into claude/mmo-overhaul | **Not now.** Against 8ca2496 it was clean (`git merge-tree --write-tree` printed only the tree id). claude/mmo-overhaul has since moved to 8d872e3 and edited STATUS.md again; `git merge-tree --write-tree HEAD claude/mmo-overhaul` now prints `CONFLICT (content): Merge conflict in docs/orchestration/mmo/STATUS.md`. It is the only conflict listed. See "What failed or is left" |

## Screenshots inspected

All under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/structart/`.

Review round 3 (`r8/`, merged lighting, hooks applied):

- `r8/hooked_gate_open.png`, crop `r8/hooked_gate_open_crop.png`: the doorway between the posts is clear (grass
  shows through) and both picket leaves are folded back on their posts. There is no dark plank panel.
  `r8/hooked_gate_shut_crop.png`: both leaves across the doorway, nothing behind them.
- `r8/hooked_fwd.png`, `r8/hooked_fwd_racks.png`, `r8/hooked_compat.png`, `r8/hooked_compat_racks.png`: base with
  the hooks and the first (tan) canvas. The catapult is the textured Blender model. The tent slope facing away
  from the sun was still slate blue, which led to finding 5's measurement.
- `r8/probe_spec0_racks.png`: the same with metallic_specular 0 (scratch-only): the slope colour barely moves.
- `r8/ochre_fwd_racks.png` / `r8/ochre_compat_racks.png` (crops `_racks_crop.png`): final art. The rot-1 tent shows
  its sunlit slope warm tan in both renderers, not white. The rot-0 tent's shaded slope is a dark near-neutral
  grey, not blue. Raw strips are marbled red, drying is maroon, dried is dark with amber rims, and the empty
  rack is bare poles. All four are distinct in both renderers.
- `r8/lab_set.png`, crop `r8/lab_pier_crop.png`: the pier deck reads as warm timber boards of different shades.
- `r8/sheet.png`, `r8/sheet2.png`: Blender Eevee contact sheets (pier, tent, racks, gate) from `preview.py`.

Earlier rounds (older art, kept as evidence for earlier choices): `r7_*` (dried rims), `r6_*` (single-rim try),
`r5_*`, `r4_lab_28.png` / `r4_pier_crop.png`, `r2_*` / `r3_*` (rim colour attempts), `built_base_*`,
`lab_forward_*`, `sheet1.png`, `racks.png`, `group[ABC].png`.

Still visible in the shots and not mine: the orange procedural Cargo Warp (`cargo_warp.gd`), the grey harbour
slab, and the Kenney stone_grill/field kinds (marked REPLACE).

## Integrator hooks (W1-BUILD owns these files)

Apply from the repo root on a tree that has this branch merged:

```
git apply tools/blender/structures/integrator_hooks.patch
```

It is generated against claude/mmo-overhaul 8ca2496 and touches only the three files below. Then run
`t_structart.gd`: once the gate resolves to `gate.glb` it checks the hooks and must print
`[t_structart] hooks applied: gate leaves, catapult model and pen collider checked`. The full patch:

```diff
--- a/game/scripts/world/prop_visuals.gd
+++ b/game/scripts/world/prop_visuals.gd
@@ -85,6 +85,9 @@
 
 static func model_path(kind: StringName) -> String:
 	var row := _building_row(kind)
+	var glb := str(row.get("glb", ""))  # W1-STRUCTART Blender set wins; Kenney `model` is the fallback
+	if glb != "" and ResourceLoader.exists(glb):
+		return glb
 	var model := str(row.get("model", ""))
 	if model == "":
 		return ""
@@ -92,6 +95,10 @@
 
 static func collision_size(kind: StringName, model_root: Node3D, fallback_size: Vector3 = Vector3.ONE) -> Vector3:
 	var row := _building_row(kind)
+	var glb := str(row.get("glb", ""))
+	var aabb: Variant = row.get("aabb_m", null)  # measured Blender size, Godot axes (x, y up, z)
+	if glb != "" and ResourceLoader.exists(glb) and aabb is Array and (aabb as Array).size() >= 3:
+		return Vector3(maxf(0.2, float(aabb[0])), maxf(0.2, float(aabb[1])), maxf(0.2, float(aabb[2])))
 	var model_name := str(row.get("model", ""))
 	if model_name != "":
 		var sizes: Dictionary = Data.props_manifest.get("model_sizes_m", {})
--- a/game/scripts/world/placed_building.gd
+++ b/game/scripts/world/placed_building.gd
@@ -115,6 +115,12 @@
 	var hinge := get_node_or_null("GateHinge") as Node3D
 	if hinge:
 		hinge.rotation.y = deg_to_rad(-100.0) if gate_open else 0.0
+	# Blender gate: both leaves swing about their hinge origins, away from the front (+Z).
+	var left := _model_leaf("LeafL")
+	var right := _model_leaf("LeafR")
+	if left and right:
+		left.rotation.y = deg_to_rad(100.0) if gate_open else 0.0
+		right.rotation.y = deg_to_rad(-100.0) if gate_open else 0.0
 	if is_inside_tree() and World.runtime and World.runtime.get("build_grid") is BuildGrid:
 		var grid := World.runtime.get("build_grid") as BuildGrid
 		grid.refresh_path(self)
@@ -123,8 +129,8 @@
 # leaf; plain planks until W1-STRUCTART ships a gate model. The model's opening is 1.25 m wide,
 # centred on x, on the back edge of the cell (z = -0.92 after its x4 scale).
 func _build_gate_leaf() -> void:
-	if get_node_or_null("GateHinge") != null:
-		return
+	if get_node_or_null("GateHinge") != null or _model_leaf("LeafL") != null:
+		return  # the Blender gate carries its own hinged leaves; the plank leaf is for the Kenney frame
 	var hinge := Node3D.new()
 	hinge.name = "GateHinge"
 	hinge.position = Vector3(-0.6, 0.0, -0.92)
@@ -141,6 +147,11 @@
 	leaf.material_override = mat
 	hinge.add_child(leaf)
 
+## A hinged leaf of the Blender gate model (props_manifest fence_gate.nodes), or null on the Kenney frame.
+func _model_leaf(leaf_name: String) -> Node3D:
+	var prop := get_node_or_null("Prop")
+	return prop.find_child(leaf_name, true, false) as Node3D if prop else null
+
 func sleep_duration() -> float:
 	return 12.0 if kind == &"straw_roll" else (8.0 if kind == &"canvas_tent" else (7.0 if kind == &"log_shelter" else (5.0 if kind == &"cabin_bed" else 10.0)))
 
--- a/game/scripts/world/field_catapult.gd
+++ b/game/scripts/world/field_catapult.gd
@@ -19,7 +19,9 @@
 	shape.shape = box
 	shape.position.y = 0.6
 	add_child(shape)
+	var model := PropVisuals.attach_model(self, kind)  # Blender catapult (manifest glb); primitives are the fallback
 	for spec in [[Vector3(2.0,0.25,2.0),Vector3(0,0.25,0)],[Vector3(0.25,1.5,0.25),Vector3(-0.7,1.0,0)],[Vector3(0.25,1.5,0.25),Vector3(0.7,1.0,0)],[Vector3(0.2,0.2,2.4),Vector3(0,1.4,0)]]:
+		if model != null: continue
 		var mesh := MeshInstance3D.new()
 		var b := BoxMesh.new()
 		b.size = spec[0]
@@ -30,6 +32,7 @@
 		mesh.material_override = mat
 		add_child(mesh)
 	for x in [-0.85,0.85]:
+		if model != null: continue
 		for z in [-0.65,0.65]:
 			var wheel := MeshInstance3D.new()
 			var cylinder := CylinderMesh.new()
```

Notes for the integrator:

- The catapult's collision box (2 x 1.2 x 2) and label are unchanged; the Blender model is 2.7 x 1.83 x 1.76.
- Taming pen (`taming_pen.gd`): no code change. Once prop_visuals resolves the glb, the pen ring uses the Blender
  fence and gate (one style). Its collider stays the explicit 4 x 1.8 x 4 in `_build_visual`; the row's
  `aabb_m` is now the ring extent too, so the `placed <= 0` fallback gets the same size.
- Drying rack (W2-PROCESS): swap the Prop to `row.stages[i].glb` per stage; `StructartLab.glb_path(kind, stage)`
  and `StructartLab.swap_visual(node, stage)` show the lookup.

Asset-replacement register (`docs/orchestration/mmo/asset-replacement.md`, orchestrator-owned and not on this
branch): proposed rows, Structures and props table:

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Kenney survival-kit structures (fences, frames, workbench, basket, etc.) | Flat salmon palette | Blender set with one atlas | W1-STRUCTART | REVIEW (built; in game after the hooks) |
| W1-STRUCTART Blender set (tent, catapult, smoker, well, racks, crock pot, steamer, mortar, fires, fence, gate, sign, basket, workbench, pier) | Low-poly: 100-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map | Higher-poly Blender rebuild with PBR normal/roughness keeping origin, pivots, aabb_m (manifest `upgrade`) | W1-STRUCTART, later art pass | REVIEW (low-poly, upgrade path recorded) |
| Building-system stand-ins floor, wall, wall_doorway, roof | Bare 1 m boxes and logs | Blender modular kit per tier | W2-BUILDSYS | REPLACE |
| 18 Kenney manifest kinds without a Blender model (technical_workbench, grindstone, tent_canvas, bedroll, large_box, chest, barrel, bucket, fence_fortified, signpost, fishing_stand, field_small, field_large, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand) | Kenney placeholder | Blender | unassigned | REPLACE |
| Harbour | Grey box inland | Pier model built; coast placement | W2-TERRAIN | REPLACE (pier built) |
| Cargo Warp | Procedural orange primitive (`cargo_warp.gd`) | Blender | unassigned | REPLACE |

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
- Canvas colour: oiled ochre rather than cream, chosen from the measured shade illuminant and the art bible's
  "warmer against cooler wilderness". If the owner wants a pale canvas back, W1-LIGHT's sky-lit ambient
  needs to carry less blue first.
- The gate opens away from its front (+Z). The PRD does not say which way; the plank leaf swung the other way.
- The hero stations keep their low-poly budgets (largest 1416 tris). I chose to mark them REVIEW with an upgrade
  path rather than spend more triangles now; the owner may prefer an immediate higher-poly pass.

## What failed or is left

- **Merge conflict on STATUS.md (blocked on permission).** Earlier rounds copied orchestrator docs into this
  branch (6b72675, c00a1e9: STATUS.md, contracts.md, docs/design/durango-prompts/, three docs/reference images) so
  I could read them. claude/mmo-overhaul has since edited STATUS.md again (8d872e3), so the merge now conflicts
  there. The fix is to put those paths back to the merge base (ea2d167), after which the merge always takes the
  target's versions:
  `git checkout ea2d167 -- docs/orchestration/mmo/STATUS.md docs/orchestration/mmo/contracts.md && git rm -r
  docs/design/durango-prompts docs/reference/durango-bag-caged-animal.webp docs/reference/durango-fatigue-meter.png
  docs/reference/durango-gather-hud-levelup.webp`. The permission classifier refused that command ("Modify
  Shared Resources"), so it is not done and I did not try another route. Either the owner allows it, or the
  integrator takes theirs at merge (`git checkout --theirs docs/orchestration/mmo/STATUS.md`). No other path
  conflicts.
- **Hooked tree basis.** The hooked-tree runs merged c06733a with claude/mmo-overhaul at 8ca2496. The two newer
  target commits (55c6541, 8d872e3) were not in that tree. `git diff --stat 8ca2496 claude/mmo-overhaul` shows
  they touch only docs: two Durango addenda (08 cooking, 09 capture) and STATUS.md.
- **Owner, please confirm about Blender.** In round 1 my first live MCP build segfaulted the owner's Blender 5.2
  (it switched the window to a temporary scene and ran the glTF exporter under `temp_override`; crash log
  `~/Library/Logs/DiagnosticReports/Blender-2026-10-19-085350.ips`). The open file was unsaved and I believe it
  held only the default 3-object scene, but I cannot verify that nothing was lost; the owner should confirm
  before merge. Every build since then ran headless (`Blender -b --factory-startup -P`). `lib.new_scene` refuses
  to run inside a live session, and this round did not touch Blender MCP.
- Rebuilds are not byte-identical (a few bytes differ inside normal/tangent buffers). The atlas PNG is
  deterministic: the final rebuild reproduced the tested atlas byte for byte (`cmp`). Geometry, JSON and all
  checks are stable.
- The shaded tent slope is a dark near-neutral grey, not warm. A warmer shade needs W1-LIGHT's sky ambient
  (`world_lighting.gd` `ambient_light_sky_contribution = 1.0`) to carry less blue. That holds for every shaded
  surface in the game; the large flat tent slope just shows it most.
- gl_compatibility lights the drying-stage maroon a little brighter than Forward+; raw vs drying stays distinct.
- The art is not in game until the hooks land (deliberate: the three files belong to W1-BUILD).
- Not built: technical_workbench, grindstone, bedroll, large_box, chest, barrel, bucket, fortified fence,
  signpost, fishing stand, fields, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand, tent_canvas
  (all marked REPLACE). Cargo Warp is procedural and needs a register row (proposed above).
- The register itself is not edited: it is orchestrator-owned and not on this branch.
- No credits spent (no Meshy/Tripo/generate_3d).
