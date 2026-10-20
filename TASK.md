# TASK (round 2): update game/tests/t_occlude.gd for the whole-object fade

## Why
DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) has a shared see-through system. You
already wrote `game/tests/t_occlude.gd` for its first version (round 1, commit a862df1). The owner
then ruled (2026-10-20): "make the tree partially see through, not fully see through; it should
still feel like the tree is there, not a clear hole in it". The reviewer (Claude) rewrote the
system, so the test must follow. `./verify_occlude.sh` is the spec: it runs your test on the real
code and then on twelve deliberately broken copies of the system; each must make your test FAIL.

What changed in the system (read `game/scripts/world/occlusion.gd` and
`game/shaders/occlusion/occlusion.gdshaderinc` first; do not edit them):
- "between" no longer cuts a cylinder around the sight line. An occluding prop fades AS A WHOLE
  OBJECT: the CPU finds props whose bounds cross the camera-survivor line and steps a fade 0..1
  per object over `FADE_S` (0.25 s); the shader drops `fade * BETWEEN_DROP` (0.55) of its pixels
  with a 4x4 ordered dither (`occl_bayer4`). Roofs ("inside") drop `fade * INSIDE_DROP` (0.85).
- Objects: a MultiMesh instance is one object (shader finds its fade by world origin in globals
  `occl_slot_0..7`, at most `SLOTS` = 8 at once); any other node is one object made of all its
  meshes (fade sent as the per-node instance uniform `occl_fade` on every mesh).
- API on the driver node (`Occ.driver()`, added deferred: await one `process_frame` after the first
  `make_occludable`): `in_the_way(chest: Vector3, back: Vector3) -> Dictionary` (Obj -> true; `back`
  is the unit vector from the survivor towards the camera), `step_between(hits: Dictionary, delta,
  fwd: Vector3)`, `step_inside(p, delta)`, `_flush_pending()` (files MultiMesh cells; normally run
  by `_process`), fields `_active`, `_owned`, `_grid`, `_slots_used`. Static:
  `ray_hits_cylinder(s, b, c: Vector2, r, y0, y1)`, `fade_of(node)` (inside node, or a between
  node's own meshes), `instance_fade(mmi, slot)`, `live_materials()`.
- `OcclusionMaterial.derive(src)` takes ONE argument now (no mode). Both modes share one derived
  material per source; the shader code no longer has `OCCL_BETWEEN` / `OCCL_INSIDE` defines; it
  `#include`s `res://shaders/occlusion/occluder_standard.gdshaderinc`.
- The driver's own `_process` also calls `step_between` every frame (with no camera/player in a
  test it steps every fade back toward 0). So drive it by hand: after the awaits a case needs, call
  `drv.set_process(false)`, then call `in_the_way` / `step_between` / `step_inside` yourself and
  check the results synchronously; `drv.set_process(true)` at the end of the case.
- Headless note: the dummy renderer reads every MultiMesh instance transform back as identity, so
  in tests put each MultiMeshInstance3D NODE where the instance should be and leave the instance
  transforms identity (that is what the system then files).
- Geometry for between cases: the iso camera looks along `fwd = (-0.5774, -0.5774, -0.5774)`
  roughly, so `back = -fwd.normalized()`; survivor chest at `Vector3(0, 1.2, 0)`. A BoxMesh is
  centred on its node, so a 2x6x2 box on a node at `Vector3(3, 3, 3)` spans y 0..6 and is in the
  way; at `Vector3(3, 3, -3)` it is beside the line; at `Vector3(-3, 3, -3)` it is behind the
  survivor. Use the same placement for MultiMeshInstance3D nodes.

## What to change: ONE file, `game/tests/t_occlude.gd`
Keep the house style and rules of round 1 (SceneTree, `## ` header, load() inside functions, never
`Occlusion.` / `OcclusionMaterial.` / `VegBatch.` at parse time, one `[t_occlude] ok <case>` line
per passing case, `[t_occlude] PASS` + quit(0) or `[t_occlude] FAIL <what>` lines + quit(1), the
"every case reached its ok line" count). Keep all 13 round-1 case functions, updated:
- `_test_between_mesh`: the surface override is a ShaderMaterial whose code contains
  `occluder_standard`; still `mode_of` "between" and `occl_surfaces` 1.
- `_test_mode_switch`: same mode twice -> same count and same derived material; "between" ->
  "inside" keeps a ShaderMaterial and `mode_of` becomes "inside".
- `_test_inside_fade`: values follow `FADE_S` and `INSIDE_DROP` read from the script's constant map
  (`Occ.get_script_constant_map()`), not hard-coded: under the roof for 1 s -> `fade_of` 1.0 and the
  mesh's `get_instance_shader_parameter(&"occl_fade")` == INSIDE_DROP; 0.1 s outside ->
  1 - 0.1 / FADE_S; long outside -> 0 and the parameter 0; above the roof -> stays 0.
- `_test_parity`: `derive(src)` with one argument; check the defines/tokens that still exist.
Add these cases (exact function names; each prints its ok line):
14. `_test_cylinder_table`: a TABLE of at least 10 rows for `ray_hits_cylinder` (hit in front,
    miss beside, miss behind the start (t < 0 only), miss above the top, miss below the bottom,
    start inside the cylinder, straight-down ray inside / outside the radius, grazing just inside /
    just outside the radius).
15. `_test_between_node_fade`: the 2x6x2 box prop in the way (above): `in_the_way` returns exactly
    one object for it; beside and behind return none. `step_between(hits, FADE_S / 2, fwd)` ->
    `fade_of(prop)` 0.5 and the mesh parameter `occl_fade` == 0.5 * BETWEEN_DROP; another
    FADE_S -> 1.0 and BETWEEN_DROP (never above it); then steps with empty hits for FADE_S -> 0,
    parameter 0, and the object left `_active`.
16. `_test_whole_object_share`: evaluate the shader's dither in GDScript (copy the `occl_bayer4`
    formula from `occlusion.gdshaderinc`, read the file to be sure it is still that formula) over
    one 4x4 block: the share of cells KEPT at drop = BETWEEN_DROP must be within 0.40..0.60 (owner:
    the tree keeps 40-60 % of its pixels) and at drop = INSIDE_DROP within (0, 0.30] (a faint roof
    outline that never vanishes). Also: the include must not test a fragment's position against the
    sight line (the file contains none of `VERTEX`, `occl_target`, `occl_between`), because that is
    the hole the owner rejected.
17. `_test_multimesh_instances`: a MultiMeshInstance3D (one instance, identity transform, mesh a
    BoxMesh 2x6x2 with a StandardMaterial3D) whose node sits in the way; `make_occludable` "between"
    on its parent Node3D; await process frames until `drv._owned` has its objects (or call
    `drv._flush_pending()`); `in_the_way` returns one object; after `step_between` with it for
    FADE_S: `instance_fade(mmi, 0)` == 1.0 and `drv._slots_used` == 1; after FADE_S with no hits:
    `_slots_used` == 0.
18. `_test_slots_cap`: ten such MultiMeshInstance3D props all on the sight line (in the way, at
    different distances along `back`, e.g. 2.5 m apart): all ten are hits; after stepping with all
    of them `drv._slots_used` == the script's SLOTS (8), not 10, and no error is logged.
19. `_test_forget_on_free`: a between prop in the way, then `queue_free()` it and await two
    frames: `drv._owned` no longer holds its id, no `_grid` cell holds one of its objects and
    `in_the_way` returns nothing for it.
20. `_test_release_between`: after a between prop was faded (fade 1), `release(prop)` -> materials
    restored, `occl_fade` parameter 0, and it is gone from `_owned` and `_active`.
Free every node you create. Keep the file under ~650 lines.

## Rules
- Edit ONLY `game/tests/t_occlude.gd`. Do not touch `game/scripts/**`, `game/shaders/**`,
  `game/tests/run_all.gd`, `project.godot`, `override.cfg`, the verify script or this file.
- If you believe the system has a bug (a case cannot pass on the real code), do NOT weaken the
  test and do NOT edit the system: write the case, the evidence and your proposed fix in
  `DSC_NOTES.md` at the worktree root and say so in your last message.
- Run Godot ONLY via the slot wrapper with a timeout, from the worktree root:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_occlude.gd`
  Never pass --editor, never run windowed, never play audio, never run --import.
- Commit with `git add game/tests/t_occlude.gd` only (never `git add -A`), message ending
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never push.

## Milestones
1. Round-1 cases updated to the new API; clean run has no SCRIPT ERROR. Commit.
2. Cases 14-17. Commit.
3. Cases 18-20. Commit.
4. `./verify_occlude.sh` prints `VERIFY PASS`. Fix the test (never the system) until it does.
