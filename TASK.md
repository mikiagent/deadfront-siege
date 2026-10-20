# TASK: write game/tests/t_occlude.gd (table-driven tests for the see-through system)

## Why
DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) has a new shared see-through system:
tall trees and big rocks dither away the part between the iso camera and the survivor, and roofs
fade completely while the survivor stands under them. The reviewer (Claude) wrote the system; you
write its test. The test is the guard every later package runs, so it must FAIL when the system
breaks, not only pass when it works. `./verify_occlude.sh` is the spec: it runs your test on the
real code and then on eight deliberately broken copies of the system, and each broken copy must
make your test fail.

## Read first (do not edit them)
- `game/scripts/world/occlusion.gd` (class Occlusion): `make_occludable(node, mode)`, `release`,
  `mode_of`, `fade_of`, `live_materials`, `driver()`, `driver().step_inside(p, delta)`, constants
  `BETWEEN`/`INSIDE`/`FADE_PER_S`/`EDGE_M`/`BELOW_M`, static var `enabled`.
- `game/scripts/world/occlusion_material.gd` (class OcclusionMaterial): `derive(src, mode)` turns a
  StandardMaterial3D into an equivalent ShaderMaterial; constants FILTERS/CULL/DEPTH/CHANNEL;
  static var `_warned`.
- `game/shaders/occlusion/*.gdshaderinc` (the shader body the derived materials include).
- `game/scripts/world/veg_batch.gd`, `game/scripts/world/island_scatter.gd` (`_nature_path`).
- House style for tests: `game/tests/t_web.gd`, `game/tests/t_structart.gd`.

## What to write: ONE file, `game/tests/t_occlude.gd`
- `extends SceneTree`, a `## ` header saying what it checks and the run line
  (`Godot --headless --path game --script res://tests/t_occlude.gd`).
- Wait in `_process` until `get_root().get_node_or_null("Data")` exists (autoloads appear on the
  first frame), run every case once, then print `[t_occlude] PASS` and `quit(0)`, or one
  `[t_occlude] FAIL <what>` line per failure and `quit(1)`.
- NEVER name game classes at parse time (`Occlusion.`, `OcclusionMaterial.`, `VegBatch.` are
  forbidden in this file). Inside functions: `var Occ: GDScript = load("res://scripts/world/occlusion.gd")`,
  then `Occ.make_occludable(node, "between")`, `Occ.get("enabled")`, `Occ.set("enabled", false)`,
  `Occ.driver().step_inside(...)`; same for occlusion_material.gd (`OM.get("_warned")`).
  Use the strings "between" / "inside" for modes.
- One function per case with exactly these names, each printing `[t_occlude] ok <case>` when it
  passes (the gate counts them):
  1. `_test_between_mesh`: MeshInstance3D + BoxMesh whose surface material is a StandardMaterial3D,
     in the tree. Returns 1; the surface override is a ShaderMaterial whose shader code contains
     `OCCL_BETWEEN`; `mode_of` is "between"; meta `occl_surfaces` is 1.
  2. `_test_override_paths`: `material_override` source -> override replaced; a mesh with a
     surface override material -> that surface converted from the override, not the mesh material.
  3. `_test_release_restores`: after `release`, every original material is back (same object, `==`),
     overrides that were null are null again, `mode_of` is "" and the `occl_*` metas are gone.
  4. `_test_mode_switch`: same mode twice returns the same count and keeps the same derived
     material; switching "between" -> "inside" gives a material whose code has `OCCL_INSIDE`.
  5. `_test_disabled`: with `enabled` false, returns 0 and nothing changes; restore `enabled` after.
  6. `_test_non_base_material`: a ShaderMaterial source stays as it is (returns 0).
  7. `_test_multimesh_single`: MultiMeshInstance3D with a one-surface mesh -> `material_override`
     becomes a ShaderMaterial; release -> null again.
  8. `_test_multimesh_multi_surface`: ArrayMesh with two surfaces (two StandardMaterial3Ds) in a
     MultiMesh -> `multimesh.mesh` becomes a twin whose surface materials are ShaderMaterials while
     the ORIGINAL mesh keeps its StandardMaterial3Ds; release -> `multimesh.mesh` is the original.
  9. `_test_late_child`: occludable empty Node3D in the tree, then add a MeshInstance3D under it;
     after `await process_frame` (twice) the child is converted and `occl_surfaces` grew.
  10. `_test_inside_fade`: a roof Node3D at y=3 holding a 4x0.2x4 BoxMesh; "inside". Then with
      `Occ.driver()` (await one frame first: the driver is added deferred):
      survivor under it `step_inside(Vector3(0, 0.9, 0), 1.0)` -> `fade_of` 1.0 and the mesh's
      `get_instance_shader_parameter(&"occl_fade")` is 1.0; a 0.1 s step back outside
      (`Vector3(10, 0.9, 0)`) -> 0.5 (FADE_PER_S is 5); far outside long enough -> 0.0;
      standing above the roof (y = 6) -> stays 0.
  11. `_test_parity`: a TABLE (Array of Dictionaries) of at least 10 StandardMaterial3D setups:
      albedo colour + texture, roughness/metallic values + texture channels, normal map + scale,
      alpha scissor + threshold, TRANSPARENCY_ALPHA, cull back/front/disabled, unshaded, vertex
      colour as albedo, uv1 scale/offset, emission colour + energy. For each, `derive()` must carry
      the values over exactly (`get_shader_parameter`) and the shader code must hold the matching
      render_mode token (`cull_disabled`, `unshaded`, ...) or define (`OCCL_SCISSOR`, `OCCL_ALPHA`,
      `OCCL_NORMAL`, `OCCL_VCOLOR`, `OCCL_EMISSION`).
  12. `_test_shared_cache_and_leak`: two meshes sharing one StandardMaterial3D get the SAME
      derived material; `live_materials()` grows by exactly 1; after releasing and freeing both it
      returns to the starting count.
  13. `_test_nature_sweep`: walk `Data.nature_families`; for every family whose `role` begins
      with "tree" or equals "rock", every model path (a `res://` path, or a bare name meaning
      `res://assets/nature/<name>.glb`, as `island_scatter._nature_path` does) that exists:
      instantiate, add to the tree, `make_occludable` -> at least 1 surface, every MeshInstance3D
      surface now draws a ShaderMaterial, the albedo colour/texture match the source material;
      then release and free. `OM.get("_warned")` must stay empty. Print
      `[t_occlude] ok nature_sweep models=<N>` (N = models checked; about 97 today).
- Free every node you create (no leaks), keep the file under ~400 lines, typed GDScript, short
  why-comments only.

## Rules
- Edit ONLY `game/tests/t_occlude.gd`. Do not touch `game/scripts/**`, `game/shaders/**`,
  `game/tests/run_all.gd`, `project.godot`, `override.cfg`, the verify script or this file.
- If you believe the system has a bug (a case cannot pass on the real code), do NOT weaken the
  test and do NOT edit the system: write the case, the evidence and your proposed fix in
  `DSC_NOTES.md` at the worktree root and say so in your last message.
- Run Godot ONLY via the slot wrapper with a timeout, from the worktree root:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_occlude.gd`
  Never pass --editor, never run windowed, never play audio, never run --import (ask with a note
  if you think one is needed).
- Commit with `git add game/tests/t_occlude.gd` only (never `git add -A`), message ending
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never push.

## Milestones
1. Skeleton with cases 1-6 printing ok lines; clean run PASS. Commit.
2. Cases 7-10. Commit.
3. Cases 11-13. Commit.
4. `./verify_occlude.sh` prints `VERIFY PASS`. Fix the test (never the system) until it does.
