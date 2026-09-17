# Codex task C2b — harden the skeleton transplant and finish the survivor's clips

The dinosaur rigging route is decided and proven: Meshy image-to-3D supplies the mesh, and a CC0 donor rig with real clips supplies skeleton and animation, transplanted in Blender. The orchestrator's proof-of-concept tool is `tools/transplant_rig.py`; it already produced contract-layout output for utahraptor, deinonychus and velociraptor from the Quaternius velociraptor rig (`tools/standins/quaternius/`, CC0, 37 bones, clips idle/walk/run/attack/jump/death). Your job is to make it production quality, and to finish the player character's missing clips through Meshy. Read the tool's docstring, `game/data/creatures/SCHEMA.md`, `tools/render_posed.py`, and `docs/orchestration/reports/orchestrator-C2-review.md` first.

Budget: **≤ 80 Meshy credits**, all of it for the survivor (text-to-motion is 10 per clip, presets 3). The dinosaur work costs nothing.

## Part A — dinosaur transplant hardening (no credits)

1. **Landmark fit instead of bounding-box fit.** The donor armature is currently scaled and centred by bbox only, so hips and knees can sit outside the mesh. Fit per landmark: derive hip height, neck base, head tip, tail tip and foot contact from the mesh (cross-section analysis along the body axis: the tallest slice is the hips, the front-most is the snout, the lowest points are feet) and move/scale donor bones to match (edit-mode bone heads/tails: `Hips`, `Neck`, `Head`, `Tail1..5`, `BackUpLeg.*`, `BackLowLeg.*`, `BackFoot.*`, `FrontUpLeg.*`). Keep the rig's bone names unchanged so the donor clips still apply.
2. **Mesh repair before weighting.** Meshy meshes have holes (Utahraptor chest/neck) and stray shells (Deinonychus tail fan, Velociraptor stretched triangles). Add a repair pass: delete loose shells below 1% of volume, fill holes (`bmesh` `holes_fill` with a size cap), merge by distance, recalc normals. Keep textures and UVs intact (do not remesh the shipped mesh; the voxel proxy is only for weights).
3. **Missing contract clips.** Author `knockdown` (death clip's first 45% then hold on the side), `hit_react` (first 35% of death, reversed back to idle), and `alert` (idle with the head raised 20° over 0.4 s, hold, return) by editing copies of the donor actions in Blender. `attack_heavy` (the Jump clip) needs a visible held beat before the leap: insert a 0.35 s hold at the crouch frame.
4. **Validation sheets.** For each species render `sheet.png` (four rest views, via `tools/render_glb.py`) plus a posed contact sheet with `tools/render_posed.py` (side view at 50% of every clip). Use the textured shading mode so texture problems are visible; the current renders are black.
5. **JSON.** Write the `pipeline` block per SCHEMA §3 (`route`, `forward_axis`, `source_height_m`, `donor`, `clips` with frame ranges) and remove the `stand_in` block once the transplanted files replace the Gobkit ones. Run `tools/smoke.sh` and a headless `--lab=creature_lab`, and confirm zero `missing bone` lines (requires Cursor's M1b remap; if it is not merged yet, say so rather than working around it).
6. **Protoceratops.** Same route with the Quaternius Triceratops rig as donor (quadruped, clips idle/walk/run/attack/death). Generate its mesh first through the C1 reference-image route (2 attempts max, 24 credits, the only dinosaur credits allowed here). If C2's 24-credit meshes for the theropods were acceptable, this is too.

## Part B — survivor clips through Meshy (≤ 80 credits)

The player character is `game/assets/characters/survivor/` (Meshy humanoid rig task `01a0b198-7d6e-7761-a3e8-242a26cbe7e3`, see `game/data/characters/survivor.json`). It has idle, walk, run, hit_react, death. Produce:

- `attack_primary`: a one-hand knife slash. Use `python3 tools/meshy.py library --search slash` (and `knife`, `stab`) to pick a preset; 3 credits.
- `attack_heavy`: two-hand overhead club swing, preset if one exists, else text-to-motion prime (10).
- `roll`: forward dodge roll, preset (`roll`, `dodge`) or text-to-motion.
- `gather`: crouch and pull at something at waist height for 1.2 s, text-to-motion.
- `knockdown`: knocked off the feet onto the back, holds, text-to-motion.
- `mount_idle`: seated riding pose with knees bent, text-to-motion.

`tools/meshy.py` needs a `--rig-task` override (or a `characters/` spec path) so it can animate a rig it did not create; add that. Files go to `anim/<clip>.glb` next to the existing ones, and `survivor.json` gets the task ids and credits. Render a posed contact sheet.

## Report
`docs/orchestration/reports/codex-C2b-transplant.md`: per species, what the landmark fit changed (before/after sheets), repair stats, the clip list with durations, credits (Part A: 24 max, Part B: 80 max), and anything the Godot side must know (bone names, root motion present or not). Commit only your folders plus `tools/`.
