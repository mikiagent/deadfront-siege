# HOUSEKIT: modular house parts in three material tiers (dsc)

Owner: "keep buildings 3D". Spec: `docs/design/durango-prompts/30_building_construction_and_crafting_stations.md`
§13 (houses and modular parts: floors, walls, roofs, doors, stairs; material choice affects
appearance) and `docs/design/durango-prompts/10_construction_building_quality.md` §8 (modular
houses, footprints and visual materials). Reference looked at:
`docs/reference/durango-tamed-island-overview.webp` (wooden houses with dark roofs, paths and
farm plots on a tamed island).

**16 new GLBs** in `game/assets/props/blender/`, built headless with the structure pipeline
(`tools/blender/structures/structures.py`, one builder per model, registered in `BUILDERS`; the
shared 1024 atlas and the bmesh helpers in `lib.py`). The existing stand-ins (`floor`, `wall`,
`wall_doorway`, `roof`) are untouched and still build identically; the house kit is a new set
beside them.

## Module rules (all ASSUMPTION: no spec gives numbers)

| Rule | Value |
|---|---|
| House module in plan | 2.0 m x 2.0 m |
| Storey height | 2.4 m |
| Wall thickness | 0.24 m |
| Roof slope | 1.0 m run for 0.6 m rise (about 31 deg), ridge along X at the module middle |
| Window opening | 0.9 m x 0.9 m, sill 1.0 m (same in every tier) |
| Doorway | 1.0 m x 2.0 m |
| Origin | plan centre of the part, based at z = 0; the foundation sinks (top course 0.12 m proud, base 0.39 m down); the door leaf's origin is its hinge |
| Front | -Y in Blender, +Z in Godot, towards the iso camera |

Because every tier uses the same module, the same storey height, the same window opening and
the same doorway, a house can mix log, timber-frame and stone parts.

## Models

| Model | Tris | AABB x, y(up), z (m) | Min corner |
|---|---:|---|---|
| `house_foundation` | 696 | 2.02, 0.51, 2.02 | -1.01, -0.39, -1.01 |
| `house_floor` | 132 | 2.00, 0.13, 2.00 | -1.00, 0.00, -1.00 |
| `house_wall` | 300 | 2.06, 2.40, 0.23 | -1.03, 0.00, -0.12 |
| `house_wall_window` | 324 | 2.00, 2.40, 0.34 | -1.00, 0.00, -0.15 |
| `house_wall_doorway` | 540 | 2.00, 2.40, 0.30 | -1.00, 0.00, -0.15 |
| `house_door` | 164 | 0.95, 2.00, 0.16 | 0.00, 0.00, -0.03 (hinge at x = 0) |
| `house_roof` | 228 | 2.00, 0.73, 1.11 | -1.00, -0.06, -0.54 |
| `house_roof_corner` | 100 | 1.15, 0.68, 1.15 | -0.58, -0.02, -0.58 |
| `house_roof_gable` | 80 | 0.33, 0.60, 2.03 | -0.20, 0.00, -1.01 |
| `house_stairs` | 136 | 1.32, 1.60, 1.40 | -0.62, -0.02, -0.76 |
| `house_wall_timber` | 152 | 2.02, 2.40, 0.28 | -1.01, 0.00, -0.12 |
| `house_wall_window_timber` | 252 | 2.02, 2.40, 0.31 | -1.01, 0.00, -0.12 |
| `house_roof_timber` | 144 | 2.00, 0.73, 1.10 | -1.00, -0.06, -0.53 |
| `house_wall_stone` | 540 | 2.00, 2.36, 0.30 | -1.00, 0.02, -0.15 |
| `house_wall_window_stone` | 864 | 1.96, 2.36, 0.35 | -0.98, 0.02, -0.16 |
| `house_roof_stone` | 144 | 2.00, 0.73, 1.11 | -1.00, -0.06, -0.54 |

One material each (the shared atlas), no embedded image, 80-864 triangles.

## Tiers

- **Log (starter)**: `house_wall`, `house_wall_window`, `house_wall_doorway` (stacked logs with
  corner posts), `house_roof` in dark weathered thatch, `house_roof_corner` as a thatch hip.
- **Timber frame**: `house_wall_timber` and `house_wall_window_timber` (posts, rails, diagonal
  braces over a plank infill), `house_roof_timber` in dark cedar shingles.
- **Stone**: `house_wall_stone` and `house_wall_window_stone` (coursed blocks with corner
  quoins), `house_roof_stone` in grey slate.

Shared parts: `house_foundation` (stone plinth), `house_floor` (plank deck on joists),
`house_door` (hinged plank leaf with iron straps and a diagonal brace), `house_roof_gable`
(boarded gable end with a king post), `house_stairs` (four treads, 0.2 m rise each, handrail).

## Atlas

Three new tiles appended to the shared 1024 atlas (indices 38-40, the existing 38 tiles are
byte-identical so the rest of the set is unaffected): `shingle` (dark cedar tabs), `slate`
(grey stone tabs) and `thatch_dark` (weathered dark straw). The owner's reference shows dark
roofs, so the house thatch is darker than the tent's pale straw.

## Manifest

`game/data/props_manifest.json` gains 16 rows (`house_foundation`, `house_floor`, `house_wall`,
`house_wall_window`, `house_wall_doorway`, `house_door`, `house_roof`, `house_roof_corner`,
`house_roof_gable`, `house_stairs`, `house_wall_timber`, `house_wall_window_timber`,
`house_roof_timber`, `house_wall_stone`, `house_wall_window_stone`, `house_roof_stone`), each
with `glb`, the measured `aabb_m`, `art_status: REVIEW` and the set's `upgrade` path. The door
row carries a `nodes` entry: the leaf origin is the hinge, swing about local Y.

`tools/blender/structures/check_manifest.py` learns the house kit: a `HOUSE_KIT` table with each
part's module footprint, whether it stands on the ground (a roof slope and the plinth do not),
whether its origin is a pivot (the door leaf) and a 20 % allowance for eave boards, hip rolls
and rafters that overhang their module. `check_manifest.py --write` creates the rows;
`[check_manifest] PASS 57 kinds resolve to existing GLBs`.

## Contact sheet

`docs/orchestration/reports/dsc-housekit-sheet.png`, rendered headless by
`tools/blender/structures/housekit_sheet.py` from the game's camera (perspective, pitch 38.7
deg down, yaw 45 deg) with a 1.8 m figure for scale, and with three assembled 4 x 2 m cabins,
one per tier.

What it showed:

- The cabins snap: the log, timber-frame and stone cabins stand on the same module and take the
  same roof slopes and gables, so the tiers really are interchangeable.
- Every loose part reads at the game angle: plinth, floor, the three log walls, the door leaf,
  the three roof pieces, the stair and the timber and stone variants.
- The three roofs separate by value as the reference does: dark thatch, brown shingles, grey
  slate.
- Fixes made after looking at earlier sheets: the plinth was an empty ring sunk below ground
  (now three courses with the top one proud); the stair handrail post stood in the middle of
  the flight (now two posts at the ends); the thatch fringe read as teeth (shallower fringe);
  the roof tiles were stretched to slab size (the shingle and slate courses now repeat at
  shingle scale); the thatch was pale straw (now `thatch_dark`, per the reference).
- Left as art notes: the log cabin's thatch slope reads a little flat at iso distance, and the
  timber cabin's plank infill is lighter than the log cabin's walls.

## Verification

- `bash <scratchpad>/dsc/verify_blender.sh housekit m1` / `m2` / `1`: PASS at every stage.
- `python3 tools/blender/structures/check_manifest.py`: PASS, 57 kinds.
- The 16 GLBs import in Godot with no errors (the final verify runs the import).

## Notes for the next agent

- The house parts are **not** 1 m grid pieces: they are modular parts that a house builder
  snaps together, so their manifest `footprint` is the module footprint in metres. The building
  system (W2-BUILDSYS) should place them by module, not by build-grid cell; the grid cell
  count of a 2 m module would be 2x2.
- The door leaf is a pivot part like the gate leaf: origin on the hinge, rotate about local Y.
- The roof slope, hip and gable are not ground-standing: their origin is the eave line at the
  wall top (z = 2.4 for a one-storey house), so a house builder places them relative to the
  walls, not on the ground.
- The atlas grew by three tiles (38-40). Anything that hard-codes the tile count should be
  checked (the Godot test reads only the tiles it needs).
- `tools/blender/structures/housekit_sheet.py` is a new file in the structures folder: it
  renders the contact sheet and is not part of the build.
