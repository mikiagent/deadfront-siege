# W1-STRUCTART: Blender structure set with visible processing stages

Branch `claude/mmo-w1-structart` (cut from `claude/mmo-overhaul`, base e93b863 merged in at 4d87e3b). Closes
build-art-01 and, with W1-HARBOUR's coast placement, world-harbour-07: the `harbour` row in props_manifest now
puts the Blender pier at the dock HarbourSite picks, on the water.

**Owner, please confirm (Blender).** In round 1 my first live MCP build segfaulted the owner's Blender 5.2 (it
switched the window to a temporary scene and ran the glTF exporter under `temp_override`; crash log
`~/Library/Logs/DiagnosticReports/Blender-2026-10-19-085350.ips`). The open file was unsaved and I believe it
held only the default 3-object scene, but I cannot verify that nothing was lost. Please confirm before merge.
Every build since then ran headless (`Blender -b --factory-startup -P`), `lib.new_scene` refuses to run inside
a live session, and rounds 3 to 5 made no Blender MCP call.

## What shipped

- **24 hand-built GLBs** in `game/assets/props/blender/`: tent, basket, workbench, sign, fence, gate (LeafL/LeafR
  nodes with their origins on the hinges), campfire, bonfire, stone_fire_pit (with spit), drying_rack in four
  stages (`drying_rack`, `_raw`, `_drying`, `_dried`), smoker, crock_pot, steamer, mortar, well, catapult (textured
  spoked wheels, `Arm` node with its origin on the axle), pier (the harbour dock, 3 x 6 m: plank deck on log
  piles, a canvas shed with crates and a barrel at the landward end, mooring posts and rope at the seaward end),
  and floor/wall/wall_doorway/roof stand-ins for W2-BUILDSYS. 36-1416 triangles each, one material, origin at
  the ground centre, front faces +Z (the tent's door faces +X so that at rot 0 the camera sees its sunlit slope).
- **One 1024 atlas for the whole set** (`structures_atlas.png`, 8x8 tiles of 128 px painted procedurally: wood
  grains, planks, bark, log ends, canvas, the tent's slope canvas, hide, rope, thatch, weave, stone, cobble, clay,
  iron, ash, embers, water, soot, carved sign board, cart wheel, and the three meat stages). Godot uses one shared
  material `structures_atlas.tres`; each GLB's `.import` maps the GLB material `structures_atlas` to it. Since
  round 5 the GLBs carry no embedded image (`export_image_format="NONE"`): the 24 GLBs went from 2.77 MB to
  0.90 MB, and a rebuild no longer re-churns 24 copies of the atlas.
- **Drying-rack stages** read by value, colour and shape: empty frame on a hide mat; raw = wide, long red strips
  with fat marbling veins (tile luma 75); drying = deep maroon, narrower, slightly curled (27); dried = near-black
  brown, shorter, more curled (16), each strip outlined by thin amber fat rims so it still reads on the dark dirt
  disc, plus a tied jerky bundle on the mat. The rack frame (bark, luma 59) is identical in every stage.
- **Canvas is oiled ochre**; the tent's two long slopes use a lighter, warmer `canvas_slope` tile with stitched
  panel seams (round 5, for the shaded slope at rot 1 and rot 3; see review round 5 finding 2).
- **Reproducible headless build**: `Blender -b --factory-startup -P tools/blender/structures/build.py -- [names]`
  rebuilds the atlas and any or all GLBs (`lib.py` = atlas painter, self-UVing bmesh primitives, exporter;
  `structures.py` = one builder per structure). `preview.py` renders an iso contact sheet.
- **props_manifest.json**: 23 kinds gain `glb` (res:// path) and `aabb_m` (measured, Godot axes); drying_rack gains
  `stages` [{id, glb}] x4; fence_gate and catapult gain `nodes`; taming_pen points at the Blender fence and its
  `aabb_m` is the assembled ring, 4.05 x 1.84 x 4.12. **`harbour` row (round 5)**: `glb` pier.glb, `footprint`
  [3, 6] (= `HarbourSite.FOOTPRINT`, so the layout ghost matches the legal footprint), `aabb_m` [2.784, 3.266,
  6.035]. `harbour.gd` (W1-HARBOUR, merged) already reads `buildings.harbour.glb`, so the pier is in game with no
  code change. The round-4 standalone `pier` row is gone: nothing read it. Owner rule of 2026-10-19:
  - the 18 kinds still on Kenney art and the 4 building-system stand-ins (floor, wall, wall_doorway, roof) are
    `art_status: REPLACE`;
  - the other 19 Blender kinds (harbour included) are `REVIEW`, and every Blender row carries `upgrade` (low-poly,
    36-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map; upgrade path: a
    higher-poly PBR model keeping origin, pivots and aabb_m).
  `model` stays on every Kenney-backed row as the fallback until the integrator hooks land.
- **`tools/blender/structures/check_manifest.py`** enforces the acceptance rules; `--write` regenerates the rows.
  Round 5: `harbour` maps to `pier`; `--write` never strips a `glb` outside `res://assets/props/blender/` (another
  package's model is left alone and only checked for existence; a stale row of this set's own GLBs is still
  dropped); the material check asks for exactly `[structures_atlas]` and 0 images.
- `glb_info.py` (pure-Python GLB reader, now also lists material names), lab `structart_lab` (its last row now
  shows the `harbour` kind), test `game/tests/t_structart.gd` (round 5 adds the harbour check; it also checks the
  hooks once they are applied), review shot `tools/blender/structures/built_base_shot.gd`, and
  **`tools/blender/structures/integrator_hooks.patch`** (W1-BUILD's three files plus, since round 5,
  W1-HARBOUR's `t_harbour.gd`). See Integrator hooks.

Commits: review round 5: 4d87e3b (merge of claude/mmo-overhaul e93b863; 65 untracked `.import`/`.uid` files that
the base now tracks were moved to `scratchpad/structart_untracked_bak`, not copied by hand), e3e8d59 (harbour row,
pier, tent slope tile, GLBs without the embedded atlas, checks), d3a319c (t_harbour hook), and the commit carrying
this report. Round 4: 03bc8bd, 36266bc, bcd4883, 1a1eb21. Earlier: ddc1aef, 04027fe, 5cb3f5c, 59f1f3f, 209539f,
8fb71cf, 825ef4c, 82f06dc, 45efa5f; review round: 1c2417a, 8be17c1, 78a251d, 3018e79; resumed round: c00a1e9,
8813169, 796ec3a; review round 3: c06733a, 25435fd, d44ef93, b44388f.

## Review round 5: findings and responses

| # | Finding | Fix | What would have caught it (now in place) |
|---|---|---|---|
| 1 major | W1-HARBOUR's hook (a `harbour` row pointing at pier.glb, footprint [3, 6]) broke check_manifest and t_structart, and `--write` stripped its `glb`, so the pier could not reach the game | I own props_manifest, so I added the row: `KIND_GLB["harbour"] = "pier"`. The pier is rebuilt to fit the 3x6 footprint (6.03 m long, was 7.8 m): `HarbourSite` puts the footprint's landward edge at local z = +3 and the arrival point (where travel lands the survivor) at z = +3.5, so a centred 7.8 m pier would have stood 0.9 m over the survivor's landing spot. No overhang exception is needed, and the footprint stays equal to `HarbourSite.FOOTPRINT`. A canvas shed with crates and a barrel replaces the composite's shed and cargo. `write()` leaves another package's glb alone | check_manifest with the old 7.8 m pier.glb put back: `[check_manifest] FAIL harbour: pier.glb 7.80 m wide on axis 2, footprint 6` (plus AABB lines), exit 1. Python probe of `write()`: a row with `res://assets/props/kenney/box.glb` comes back unchanged, and a stale `res://assets/props/blender/old.glb` row loses its glb and becomes REPLACE. `t_structart._check_harbour` instances `harbour.gd` and fails unless its `Visual` is the row's glb, inside the footprint, with a footprint equal to `HarbourSite.FOOTPRINT`: `[t_structart] harbour shows pier.glb: x 2.78 m, z -3.00..3.03 m, deck at y 0.45 (footprint (3, 6))`. Its first run caught a real bug in the check (JSON floats vs ints), fixed before commit |
| 1b (found this round) | With the row in place, W1-HARBOUR's `t_harbour` fails on all 15 islands: `[t_harbour] FAIL home_grassland harbour is a prop composite (1 meshes, 0 boxes)`. Its rule is that the dock must be "a prop composite (>= 20 meshes), not a box", and the Blender pier is one mesh | `t_harbour.gd` is W1-HARBOUR's file, so the fix is an integrator hook (in `integrator_hooks.patch`). The check also accepts a Visual that is the manifest's harbour glb. Every placement check (coast, water depth, arrival, pathing) passes with the pier | Hooked tree: `[t_harbour] PASS islands=15`, exit 0 |
| 2 minor | Tent dark slab at rot 1 and rot 3 | The two long slopes use a new `canvas_slope` tile: lighter, warmer, with stitched panel seams. Measured on the shaded slope: Forward+ (51, 57, 59) luma 56, slate blue (reviewer's `after_rot1_fwd_west.png`), became (67, 70, 63) luma 69, warm neutral. The lit slope went from luma 151 to 178 (Forward+) and compat luma 206, (235, 204, 163), not clipped. **This is not a full fix.** The shaded slope is lit by sky ambient only, about (0.04, 0.11, 0.33) linear R/G/B from my samples, so no albedo can bring its red channel above about sRGB 56. I also tried tilting the slope normals towards the sky (`bend_up`, 0.6). It came out darker (luma 61, because the sky top is darker than the horizon), so I reverted it | Shots `r10/tents_fwd.png` and `r10/tents_compat.png` (rot 0-3), crops `r10/tents_*_rot13_crop.png`. The remaining gap is W1-LIGHT's ambient (register row build-art-02, updated below) |
| 3 minor | Rack stages not driven in game | Unchanged: W2-PROCESS owns station state. Register row proc-vis-01 (below), lookup `row.stages[i].glb` | Register row |
| 4 minor | Every GLB embedded a redundant 77 KB JPEG of the atlas, and the images == 1 check locked it in | `lib.export` uses `export_image_format="NONE"`. UVs (TEXCOORD_0) and the `structures_atlas` material name stay, and the importer maps that name to the shared .tres as before. The check now asks for materials `[structures_atlas]` and 0 images | check_manifest with the old JPEG-carrying tent.glb put back: `[check_manifest] FAIL tent: tent.glb has materials ['structures_atlas'] / 1 images (want [structures_atlas] / 0)`. In Godot, `t_structart._check_glb` still requires the one atlas material on every mesh: PASS |
| 5 minor | Stale lib.py docstring ("live via MCP") | It now says builds run headless only and a live session is used only to look at the results. `godot_import_settings.py`'s docstring is updated the same way (no embedded image) | — |
| 6 minor | Merge evidence named base 8d872e3; owner confirmation | Base e93b863 is merged into the branch (4d87e3b). `git merge-tree --write-tree HEAD claude/mmo-overhaul` is rechecked in the checklist. The owner question is now at the top of this report | Checklist row "Merges cleanly" |

## Review round 4: findings and responses

| # | Finding | Fix | What would have caught it (now in place) |
|---|---|---|---|
| 1 blocker | Branch edited orchestrator docs; STATUS.md conflicted with claude/mmo-overhaul 8d872e3 | 03bc8bd: `git checkout ea2d167 -- docs/orchestration/mmo/STATUS.md docs/orchestration/mmo/contracts.md` and `git rm` of docs/design/durango-prompts/ and the three docs/reference/durango-* images. `git diff --name-status ea2d167 HEAD` now lists only this report under docs/ | `git merge-tree --write-tree HEAD claude/mmo-overhaul` prints only a tree id (`bcbce0c...` after 03bc8bd, `a89eb26...` after 36266bc), exit 0 |
| 2 major | Round 1 crashed the owner's live Blender while its file was unsaved | No code change possible. Builds are headless-only and `lib.new_scene` raises unless `bpy.app.background`. This round did not touch the owner's Blender (no MCP call) | **Owner: please confirm nothing was lost before merge** (see "What failed or is left") |
| 3 minor | At rot 0 the tent showed the camera its shaded slope, a near-black slab | The tent is built turned +90 deg (`structures.tent`, `bmesh.ops.rotate`): at rot 0 its camera-side slope faces +Z and the door +X. W1-LIGHT's sun crosses from -X (yaw band -35 to -85), so the old +X slope was shaded all day | `t_structart._check_tent_faces_sun`: area-weighted N.sun over the canvas the iso camera sees, at W1-LIGHT's noon (read from `data/world/lighting.json`, default band when absent). Old GLB: `[t_structart] tent at rot 0: camera-side canvas sunlit 0.10 (min 0.35), sun yaw -60 elevation 58` / `[t_structart] FAIL tent at rot 0 shows its shaded slope to the camera (sunlit 0.10 < 0.35)`, exit 1. New: `... sunlit 0.43 ...`, PASS. Shots `r9/tent_fwd_crop.png`, `r9/tent_compat_crop.png` |
| 4 minor | `_check_stages` printed "distinct" even after recording a failure | It prints only when it added no failure | Mutation probe (dried stage pointed at the raw GLB, manifest restored after, `cmp` identical): exit 1, `[t_structart] FAIL drying_rack raw and dried look identical`, and no "distinct" line |
| 5 minor | Stale drying_rack note | `check_manifest.write()` sets the note from a `NOTES` table. Five more Blender rows had placeholder notes (mortar, well, crock_pot, canvas_tent, smoker, catapult) and are fixed the same way | check_manifest fails a Blender row whose note mentions "kenney", "placeholder" or "until a dedicated". On the old manifest: `[check_manifest] FAIL drying_rack: note still describes the placeholder: 'use the canvas frame as a rack until a dedicated model exists'` (and the five others) |
| 6 minor | Origin tolerance grew with the footprint (about 1 m on the pier); PASS line double counted stand-ins | Fixed `ORIGIN_TOL_M = 0.15`. The worst real offset is 0.108 m (workbench.glb, x). PASS line now reads `23 Blender (4 of them stand-ins marked REPLACE)` | Probe with the pier's AABB shifted 1 m: `pier: pier.glb origin off centre on axis 2 by 1.00 m`. The old limit (0.12 x 8 + 0.05 = 1.01 m) passed it |
| 7 minor | No hook drives the four rack stages from station state | Deliberate (W2-PROCESS owns station state). Register row proposed below (proc-vis-01). The lookup is `row.stages[i].glb`, the same as `StructartLab.swap_visual(node, stage)` | Register row |

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

Round 5 reruns, all on this work tree at d3a319c plus the uncommitted docstring and report changes (base
e93b863 merged in). "Hooked" = the same tree with `git apply tools/blender/structures/integrator_hooks.patch`
(applies cleanly on e93b863), run, then the four files restored with `git checkout`. Logs are in
`scratchpad/w1/structart/r10/`.

| Item | Result (exact line) |
|---|---|
| check_manifest prints PASS, every kind resolves to an existing GLB | `[check_manifest] PASS 41 kinds resolve to existing GLBs (23 Blender (4 of them stand-ins marked REPLACE), 18 Kenney marked REPLACE)`, preceded by `[check_manifest] harbour          pier.glb                 1404 tris  aabb [2.78, 3.27, 6.03]` |
| Each GLB <= 4k tris, one atlas material, origin at ground centre, footprint within manifest AABB +-5 % | enforced by the same PASS (largest: drying_rack_dried 1416 tris, pier 1404) and in Godot by `[t_structart] PASS` |
| Harbour shows the pier on the water (world-harbour-07) | `[t_structart] harbour shows pier.glb: x 2.78 m, z -3.00..3.03 m, deck at y 0.45 (footprint (3, 6))`; harbour_lab `[harbour] lab island=home_grassland cell=(-1, 64) rot=2 harbour=(0.5, 67.0) arrival=(0.5, 63.5) camp=(0.5, 8.5) camp_to_harbour_m=58.5`, shots `r10/harbour_fwd.png` and `r10/harbour_compat.png` |
| Four drying-rack stages differ | `[t_structart] drying_rack stages ["empty", "raw", "drying", "dried"] distinct` |
| Stages separate by value, dried clear of the frame | `[t_structart] stage luma raw 75 drying 27 dried 16, frame bark 59` |
| Tent shows sunlit canvas at rot 0 | `[t_structart] tent at rot 0: camera-side canvas sunlit 0.43 (min 0.35), sun yaw -60 elevation 58` (the check now counts both canvas tiles) |
| t_structart, branch | `[t_structart] hooks not applied (gate resolves to res://assets/props/kenney/fence-doorway.glb), hook checks skipped` / `[t_structart] PASS` (exit 0) |
| t_structart, hooked | `[t_structart] hooks applied: gate leaves, catapult model and pen collider checked` / `[t_structart] PASS` (exit 0; the hook check also confirms `PropVisuals.model_path(&"harbour")` is pier.glb) |
| t_harbour (W1-HARBOUR's test) | branch with the row and without the hook: exit 1, `[t_harbour] FAIL home_grassland harbour is a prop composite (1 meshes, 0 boxes)` (same on all 15 islands; this is why the hook is needed). Hooked: `[t_harbour] PASS islands=15` (exit 0) |
| run_all suite | branch `[tests] PASS` (exit 0); hooked `[tests] PASS` (exit 0) |
| smoke | branch `SMOKE PASS`; hooked `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot, exit 0) |
| --lab=build_lab headless | branch `[build] rejected water` / `[build] restored 6` / `[build] PASS` (exit 0); hooked `[build] PASS` (exit 0) |
| --lab=structart_lab headless | `[structart] lab placed 24 models, missing []` (exit 0) |
| Windowed 1600x900, four tents at rot 0-3 | `[shot] tent rot=1 cell=(-3, 5) screen=(1012.132, 389.3456)` / `[shot] tent rot=3 cell=(-3, 9) screen=(800.0, 511.4312)` / `[shot] saved .../r10/tents_compat.png`; the same in Forward+ (`r10/tents_fwd.png`) |
| Windowed scripted base, both renderers | round 4 evidence (r9, r8) stands: round 5 changed only the tent slopes, the pier, and the embedded image (geometry of the other 22 GLBs is identical: tris and AABB compared against the round-4 files, only pier.glb changed) |
| Merges cleanly into claude/mmo-overhaul | base e93b863 is an ancestor of HEAD (`git merge-base --is-ancestor claude/mmo-overhaul HEAD` exit 0); `git merge-tree --write-tree HEAD claude/mmo-overhaul` prints only `e5a8116a998d5c91578b7c3e1c76ab5e866aa326` (exit 0) at d3a319c |
| GLBs reproduce headlessly | `[structart] built 24` (full rebuild, `r10/build.log`); after it, the 22 GLBs I did not change match the round-4 tris and AABB exactly |

## Screenshots inspected

All under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/structart/`.

Review round 5 (`r10/`):

- `r10/harbour_before_fwd.png`: before, with the merged base and no row. W1-HARBOUR's Kenney composite: salmon
  planks, a canvas shed, a barrel and crates, and a log raft.
- `r10/harbour_fwd.png`, crop `r10/harbour_fwd_crop.png` (Forward+): after. The Blender pier runs from the beach
  out over the water on log piles, and its piles reflect in the water. The deck is warm timber in mixed board
  shades. The canvas shed (crates and a barrel under it) stands at the landward end, with mooring posts with
  rope, a rope coil and a crate at the seaward end. The survivor stands on the sand just behind the shed; the
  pier does not overlap him. No grey block.
- `r10/harbour_compat.png`, crop `r10/harbour_compat_crop.png` (gl_compatibility): the same layout. Deck and
  shed roof are paler. It still reads as a timber pier on the water.
- `r10/tents_fwd.png`, crop `r10/tents_fwd_rot13_crop.png`: tents at rot 0-3 (screen positions in the log).
  Rot 0 and rot 2 show light ochre sunlit slopes. Rot 1 (upper right, lit gable) and rot 3 (bottom) still show a
  dark slope. It is now dark olive-grey with visible panel seams and a hide patch, not slate blue, but still
  clearly darker than everything around it.
- `r10/tents_compat.png`, crop `r10/tents_compat_rot13_crop.png`: the same in compat. The lit slopes are pale
  cream-ochre (not clipped) and the rot-1/rot-3 slopes are dark green-grey.
- `r10/tents2_fwd.png`, `r10/tents2_compat.png`: the reverted normal-bend trial. The shaded slopes come out darker
  (luma 60-62).

Earlier rounds: `r9/` (tent at rot 0 and rot 1, round 4), `r8/` (hooked gate open and shut, ochre canvas, racks,
lab set, pier deck), `r7_*`, `r6_*`, `r5_*`, `r4_*`, `r2_*`/`r3_*`, `built_base_*`, `lab_forward_*`, `sheet*.png`.

## Integrator hooks

Apply from the repo root on a tree that has this branch merged:

```
git apply tools/blender/structures/integrator_hooks.patch
```

It applies cleanly on claude/mmo-overhaul e93b863 (checked). It touches W1-BUILD's `prop_visuals.gd`,
`placed_building.gd` and `field_catapult.gd`, and W1-HARBOUR's `game/tests/t_harbour.gd`. Then run
`t_structart.gd`. Once the gate resolves to `gate.glb` it checks the hooks and must print `[t_structart] hooks
applied: gate leaves, catapult model and pen collider checked`. Then run `t_harbour.gd`, which must print
`[t_harbour] PASS islands=15`. The harbour itself needs no code hook: `harbour.gd` already reads the manifest
row. The full patch:

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
--- a/game/tests/t_harbour.gd
+++ b/game/tests/t_harbour.gd
@@ -84,7 +84,12 @@ func _check_island(id: String) -> void:
 	for m in meshes:
 		if (m as MeshInstance3D).mesh is BoxMesh:
 			boxes += 1
-	_expect(meshes.size() >= 20 and boxes == 0, "%s harbour is a prop composite (%d meshes, %d boxes)" % [id, meshes.size(), boxes])
+	# W1-STRUCTART's props_manifest harbour row swaps the composite for the Blender pier (one mesh).
+	var rows: Dictionary = (root.get_node("Data").get("props_manifest") as Dictionary).get("buildings", {})
+	var pier_glb := str((rows.get("harbour", {}) as Dictionary).get("glb", ""))
+	var vis := h.get_node_or_null("Visual")
+	var is_pier := pier_glb != "" and vis != null and vis.scene_file_path == pier_glb
+	_expect(is_pier or (meshes.size() >= 20 and boxes == 0), "%s harbour is the manifest pier or a prop composite (%d meshes, %d boxes)" % [id, meshes.size(), boxes])
 	var near := INF
 	for c in _host.get_tree().get_nodes_in_group("creatures"):
 		if c is Node3D:
```

Notes for the integrator:

- Optional, W1-HARBOUR's `harbour.gd`: its tap collider is still sized for the 8 m composite (`box.size =
  Vector3(2.2, 2.3, 8.0)` at z -1, so z +3 to -5). The pier spans z +3 to -3, which leaves 2 m of collider over
  open water past the pier tip. Tapping there opens the harbour, which does no harm. If you want it exact, use
  `box.size = Vector3(2.8, 2.3, 6.0)` with `_shape.position = Vector3(0.0, _visual.position.y + DECK_H + 0.85, 0.0)`.
  Only do that while the manifest row exists; the composite still needs the long box.
- The catapult's collision box (2 x 1.2 x 2) and label are unchanged; the Blender model is 2.7 x 1.83 x 1.76.
- Taming pen (`taming_pen.gd`): no code change. Once prop_visuals resolves the glb, the pen ring uses the Blender
  fence and gate. Its collider stays the explicit 4 x 1.8 x 4; the row's `aabb_m` is the ring extent too.
- Drying rack (W2-PROCESS): swap the Prop to `row.stages[i].glb` per stage; `StructartLab.glb_path(kind, stage)`
  and `StructartLab.swap_visual(node, stage)` show the lookup. Until then the rack shows the empty model in game.

Plan register (`docs/orchestration/mmo/plan-register.md` section 6, orchestrator-owned): proposed gap rows.

| id | Sev | Adj | V | blocker | Eff | Gap | Evidence | Pkg |
|---|---|---|---|---|---|---|---|---|
| proc-vis-01 | P1 | | C | none | S | In game the drying rack always shows the empty model: nothing swaps `props_manifest.drying_rack.stages[i].glb` (empty, raw, drying, dried) from station state, so the owner's "processing must be visible" is unmet in game | stage GLBs shown only by `StructartLab.swap_visual` (lab, `built_base_shot.gd`); `r9/tent_fwd_racks.png` | W2-PROCESS |
| build-art-02 | P2 | | C | none | S | At rot 1 and rot 3 the tent turns towards the camera the slope that W1-LIGHT's sun never reaches (yaw band -35 to -85). Sky ambient only (about 0.04/0.11/0.33 linear R/G/B, ambient_energy 0.3) caps that slope near sRGB 56 red. The round-5 slope tile lifted it from luma 56 (slate blue) to 69 (warm neutral), but it still reads as a dark slope. Every large shaded face in the game has the same limit | `r10/tents_fwd_rot13_crop.png`, `r10/tents_compat_rot13_crop.png` | W1-LIGHT follow-up (warmer and stronger fill or ambient) |

Asset-replacement register (`docs/orchestration/mmo/asset-replacement.md`, orchestrator-owned): proposed rows.

| Asset | Problem | Route | Package | Status |
|---|---|---|---|---|
| Kenney survival-kit structures (fences, frames, workbench, basket, etc.) | Flat salmon palette | Blender set with one atlas | W1-STRUCTART | REVIEW (built; in game after the hooks) |
| W1-STRUCTART Blender set (tent, catapult, smoker, well, racks, crock pot, steamer, mortar, fires, fence, gate, sign, basket, workbench, pier) | Low-poly: 36-1416 tris of a 4000 budget, 4-10 segment cylinders, albedo-only atlas, no normal map | Higher-poly Blender rebuild with PBR normal/roughness keeping origin, pivots, aabb_m (manifest `upgrade`) | W1-STRUCTART, later art pass | REVIEW |
| Harbour dock | Was a grey box inland, then the Kenney composite | W1-HARBOUR coast placement + Blender pier via the manifest `harbour` row | W1-HARBOUR, W1-STRUCTART | REVIEW (in game now; low-poly) |
| Building-system stand-ins floor, wall, wall_doorway, roof | Bare 1 m boxes and logs | Blender modular kit per tier | W2-BUILDSYS | REPLACE |
| 18 Kenney manifest kinds without a Blender model (technical_workbench, grindstone, tent_canvas, bedroll, large_box, chest, barrel, bucket, fence_fortified, signpost, fishing_stand, field_small, field_large, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand) | Kenney placeholder | Blender | unassigned | REPLACE |
| Cargo Warp | Procedural orange primitive (`cargo_warp.gd`) | Blender | unassigned | REPLACE |

## Labs to register

- `structart_lab` (`game/scripts/dev/structart_lab.gd`, `game/scenes/dev/structart_lab.tscn`): `--lab=structart_lab
  [--shot=<png>] [--cam-size=N]`, prints `[structart] lab placed 24 models, missing []`, headless quits.

## Assumptions

- `# ASSUMPTION` in structures.py: building-system pieces are 1 m modules (manifest footprints are 1x1); W2-BUILDSYS
  sets the real size.
- The pier is 6 m long so it fits `HarbourSite.FOOTPRINT` (3x6). Its landward end stops at the base row, because
  the arrival point is 0.5 m behind it. The composite reached 2 m further out to sea; HarbourSite only
  guarantees water depth up to the tip row. If the owner wants a longer pier, the clean way is a longer
  HarbourSite footprint (W1-HARBOUR's rule), not an overhang. (The round-4 pier ASSUMPTION about W2-TERRAIN
  sinking the piles is gone: harbour.gd already stands the pile feet at y = -0.75, under the water.)
- The pier's shed, crates and barrel stand in for the composite's shed and cargo. The composite's moored log raft
  is not in the GLB: it sat outside the 3 m footprint width.
- `canvas_tent` reuses the tent model; `tent_canvas` (3x2) stays Kenney and REPLACE.
- Stage colours are my reading of the owner's "darker drying strips, dark dried strips": deep maroon, then
  near-black brown with an amber fat rim (my addition so the near-black strips do not vanish on the dirt disc).
- Canvas colour: oiled ochre on the gables, a lighter warmer ochre on the slopes, chosen from the measured shade
  illuminant and the art bible's "warmer against cooler wilderness".
- The tent's door faces +X, not +Z like the rest of the set. This depends on W1-LIGHT's sun staying on the -X side
  (yaw band -35 to -85); `t_structart` reads the band from lighting.json and fails if it moves.
- The gate opens away from its front (+Z). The PRD does not say which way.
- The hero stations keep their low-poly budgets (largest 1416 tris), marked REVIEW with an upgrade path.

## What failed or is left

- **Owner confirmation about the round-1 Blender crash** (top of this report).
- **Tent at rot 1 and rot 3**: improved (slate blue at luma 56 is now warm neutral at 69), not fixed. The rest
  is ambient-limited and needs W1-LIGHT (build-art-02). The normal-bend trial made it darker and was reverted.
- **Rack stages in game** wait for W2-PROCESS (proc-vis-01).
- **t_harbour needs its hook** (in the patch). Without it, merging this branch turns `t_harbour` red, because the
  harbour shows the pier and not the 20-mesh composite. The integrator should apply the patch in the same merge.
- Rebuilds are not byte-identical (a few bytes differ inside normal/tangent buffers). The atlas PNG is
  deterministic; geometry, JSON and all checks are stable.
- gl_compatibility renders the lit canvas and the pier deck paler than Forward+.
- The art is not in game until the hooks land, except the harbour pier, which is in game through the manifest
  row alone.
- Not built: technical_workbench, grindstone, bedroll, large_box, chest, barrel, bucket, fortified fence,
  signpost, fishing stand, fields, stone_grill, straw_roll, log_shelter, cabin_bed, campfire_stand, tent_canvas
  (all marked REPLACE), and Cargo Warp.
- The registers are not edited (orchestrator-owned). Proposed rows are above.
- No credits spent (no Meshy/Tripo/generate_3d).
