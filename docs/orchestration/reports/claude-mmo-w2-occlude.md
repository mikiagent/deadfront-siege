# W2-OCCLUDE: shared see-through system (trees, rocks, roofs)

Branch `claude/mmo-w2-occlude`, merged with `claude/mmo-overhaul` at 85c2b63b.

## What shipped

The owner's correction (2026-10-20) is the design: "make the tree partially see through, not
fully see through; it should still feel like the tree is there, not a clear hole in it."

- `game/scripts/world/occlusion.gd` (class `Occlusion`). A prop that stands between the camera
  and the survivor now fades as a whole object. It keeps 7 of 16 pixels (about 44 %) in an even
  ordered dither over its whole silhouette, with a 0.25 s fade in and out. The trunk, crown shape
  and outline stay readable. The old "between" mode cut a dithered cylinder around the sight line
  and dropped up to 80 % there; it is gone.
  - Which props are in the way is decided on the CPU each frame. Objects are filed in an 8 m grid.
    Only cells along the camera-survivor line are visited, and each candidate gets a ray test:
    a vertical cylinder for MultiMesh instances, the world box for other nodes. Both are widened by
    the survivor's body (0.3 m wide, head 0.6 m above the chest, feet 1.2 m below). The test uses
    live instance transforms, so a harvested VegBatch tree (shrunk in place) never fades and a
    regrown one does.
  - Each MultiMesh instance (a VegBatch tree) is its own object. The shader finds its fade by
    world origin in eight `occl_slot_*` globals, so the fadingest 8 at once. Any other node is
    one object made of all its meshes, and its fade goes to every mesh through the instance
    uniform `occl_fade`.
  - "inside" (roofs, ceilings): the whole node fades to 2 of 16 pixels (a faint outline) while
    the survivor is under its footprint, and is solid from outside.
  - Shadows and depth from other cameras are untouched: a faded tree keeps its whole shadow.
- `game/shaders/occlusion/occlusion.gdshaderinc`: globals, the Bayer 4x4 dither and the per-object
  lookup, run in `vertex()`. `occluder_standard.gdshaderinc`: the StandardMaterial3D replica the
  props are converted to. It draws pixel-identical to the source material while nothing fades
  (gate `idle_change` below).
- `game/scripts/world/occlusion_material.gd`: `derive(src)` (one argument now; both modes share one
  derived material per source).
- `game/scripts/world/island_scatter.gd`: three-line hook. A VegBatch with any instance at least
  `Occlusion.TALL_M` (2.4 m) tall becomes "between".
- `game/scripts/dev/occlusion_lab.gd` + `game/scenes/dev/occlusion_lab.tscn`: shots by name,
  `--occl-gates=<dir>` (the owner's pixel gates) and `--occl-perf` (island frame cost).
- `game/tests/t_occlude.gd`: 20 table-driven cases, written by dsc (see below).

## Acceptance

Commands run from the work tree, each wrapped in gslot with a perl alarm.

Pixel gates, `--lab=occlusion_lab --occl-gates=<dir>`, windowed 1600x900. The tree is 9 m tall
and stands 5 m in front of the survivor. The scene is paused so the poses match, and shadows are
off so only the prop's own pixels count:

| gate | Forward+ | gl_compatibility (web) |
|---|---|---|
| tree keeps 40-60 % of its unfaded pixels | 0.437 of 71315 px PASS | 0.438 of 70057 px PASS |
| no 48x48 window inside the silhouette below 30 % | min 0.430 over 295 windows PASS | min 0.431 over 293 windows PASS |
| survivor keeps >= 50 % of its unoccluded pixels | 0.684 of 6200 px PASS (unfaded tree: 0.275; of the 4492 px the tree covers, 0.564 show through) | 0.683 PASS (unfaded: 0.280; covered part 0.560) |
| no visual change when nothing is in the way | 0.00000 of the frame PASS | 0.00007 PASS |
| roof inside: faint outline (5-30 % kept) | 0.125 PASS | 0.125 PASS |
| roof from outside unchanged | 0.00000 PASS | 0.00000 PASS |
| verdict | `[occl] gates PASS renderer=forward_plus` | `[occl] gates PASS renderer=gl_compatibility` |

Frame cost, `--occl-perf --disable-vsync`, windowed 1600x900, island_lab's island (temperate_25)
and camp view, with the survivor behind a tree (3 objects fading). Rounds with every prop
occludable and rounds with every prop released alternate, 4 x 240 frames each:

| renderer | on | off | delta |
|---|---|---|---|
| gl_compatibility 1x | 9.980 ms | 9.935 ms | +0.045 ms |
| gl_compatibility, 3D supersampled 2x | 11.123 ms | 11.203 ms | -0.080 ms (noise) |
| Forward+ 1x and 2x | 8.333 ms | 8.333 ms | 0.000 ms (held at 120 Hz by the Mac's driver vsync, so both sides finish inside 8.3 ms) |

The driver's own CPU work (sight test plus fade step) is 0.008 ms per frame for that island's
64 objects. The GPU timestamp query returns 0 on this Mac, so Forward+ GPU cost is only bounded
by the 120 Hz cap. Every row is within the 0.3 ms budget.

Tests, all headless, after the merge with claude/mmo-overhaul:
- `tools/smoke.sh` -> `SMOKE PASS`
- `t_occlude` -> `[t_occlude] PASS` (TODO numbers)
- `run_all` -> `[tests] PASS`
- t_ai, t_build, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light,
  t_lighting, t_save, t_structart, t_tame, t_web -> PASS

No Godot crash report appeared during this session. The newest `Godot-*.ips` is from 02:03,
before the session started.

## Screenshots looked at

All are in `docs/orchestration/reports/`:
- `w2-occlude-gates-forward_plus.png`, `w2-occlude-gates-gl_compatibility.png`: unfaded tree
  (left) next to the faded tree (right), with the survivor behind both. On the right the crown,
  the trunk and the outline all still read as the tree, and the survivor shows through as a
  half-tone. There is no clear hole. Zoomed to 3x, the dither is a pixel checkerboard and not a
  coarse screen.
- `w2-occlude-roof-inside-gl.png`: the roof over the survivor is a faint outline and the posts
  stay solid. `w2-occlude-roof-outside-gl.png`: from outside, the roof is solid.
- `w2-occlude-rock-fwd.png`: a 3 m rock in front of the survivor fades as a whole.
- `w2-occlude-phone-gl.png`: landscape phone at 844x390 in the web renderer. The tree reads as a
  tree and the survivor is visible through it.

## API for W2-BUILDSYS (and anything else that can hide the survivor)

```gdscript
# A wall's upper half, a tall gate, a tower: fades as one object while it is in the way.
Occlusion.make_occludable(upper_wall_node, Occlusion.BETWEEN)
# A roof or ceiling piece: fades to a faint outline while the survivor stands under it.
Occlusion.make_occludable(roof_node, Occlusion.INSIDE)
# Before re-skinning a piece (tier upgrade swaps meshes) or to stop fading it:
Occlusion.release(node)
```

- `make_occludable(node, mode) -> int` returns the number of surfaces that can now fade (0 when
  `--no-occlusion` is set or nothing converts). Calling it again with the same mode does nothing;
  another mode replaces the first. Meshes added under `node` later are converted too. Call it on
  the piece's root, after or before `add_child`: a node that is not in the tree yet is filed when
  it enters.
- One node is one object, with one fade for all its meshes. For walls, give the lower and upper
  halves separate nodes and make only the upper one occludable. For roofs, make each roof piece
  its own node, so only the piece over the survivor fades.
- Only `BaseMaterial3D` (StandardMaterial3D, ORMMaterial3D) surfaces fade. A ShaderMaterial stays
  solid and is reported once in the log. The replica covers albedo (+texture, vertex colour),
  roughness and metallic (+textures and channels), normal map, alpha scissor/hash/blend, emission
  (colour), cull, depth draw, unshaded and per-vertex shading. AO, rim, clearcoat, detail,
  triplanar, billboard, distance fade and emission textures are not copied (also reported once).
- Static pieces only. The bounds are read when the node is filed; a node that moves afterwards
  needs `release()` and `make_occludable()` again. A node taken out of the tree is forgotten.
- `mode_of(node)`, `fade_of(node)` (0..1), `instance_fade(mmi, slot)` and `live_materials()` are
  there for tests.

## Integrator hooks

Already applied on this branch, because no running package owns `island_scatter.gd`. Listed here
so the integrator knows the hunk (`IslandScatter._attach_batched`, after `batch.add(xf)`):

```gdscript
	# Tall props can hide the survivor at the iso pitch: the part on the sight line dithers away.
	if scale * h >= Occlusion.TALL_M:
		Occlusion.make_occludable(batch, Occlusion.BETWEEN)
```

W2-BUILDSYS: the two calls in the API section above, from the code that spawns a piece.

## dsc usage

TODO

## Assumptions

- `# ASSUMPTION`-free code. Decisions the PRDs do not make:
  - The faded share is 9/16 dropped for "between" and 14/16 for "inside". This is the nearest
    ordered-dither level that keeps the tree inside 40-60 % and still shows at least half of a
    survivor fully behind it.
  - TALL_M = 2.4 m. Every scattered rock today is 0.4-1.4 m tall (nature_manifest), so in game
    only trees and palms fade. A bigger rock family turns occludable through the same hook.
  - The survivor is the camera's own follow target (IsoCamera), falling back to the first node in
    group "player".

## Limits

- At most 8 MultiMesh instances fade at once (the fadingest win). In a very dense stand of trees,
  a ninth tree in the way stays solid. Upgrade path: more slots, or MultiMesh custom data.
- MultiMesh instances are read once, when their cell is filed (a frame or a few after the cell
  arrives, because instance transforms read back as zero until the next physics-interpolation
  tick). An instance added to an existing cell later never fades; VegBatch commits every cell
  once, after the scatter.
- Node objects use their world box. A long diagonal wall's box is larger than the wall, so it can
  fade a little early near its ends.
- Every occludable material contains a `discard`. That costs nothing measurable here (table
  above), but on tile-based phone GPUs it can turn off some hidden-surface removal for those
  props even while nothing fades.
- The 9/16 ordered dither is a 1-pixel checkerboard. If a renderer ever upscales the 3D view
  (scaling_3d_scale < 1 on phones), the pattern grows to 2x2 blocks.
