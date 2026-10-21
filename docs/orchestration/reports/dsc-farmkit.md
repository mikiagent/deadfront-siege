# dsc FARMKIT: farm plots, crop stages, paths and farm props

Branch `claude/mmo-farmkit` (work tree `.claude/worktrees/mmo-farmkit`). Models only: the game keeps
its own field logic (`game/scripts/world/field_plot.gd`), this branch ships the meshes.

**What shipped:** 15 new GLBs in `game/assets/props/blender/`, one builder per model in
`tools/blender/structures/farmkit.py`, eight new tiles on the shared 1024 atlas
(`structures_atlas.png`), a `farm` section in `game/data/props_manifest.json` and a contact sheet
renderer (`tools/blender/structures/farmkit_sheet.py`).

No credits spent (no Meshy, no Tripo, no image generation). Every build ran headless
(`Blender -b --factory-startup -P tools/blender/structures/build.py -- <names>`); no live Blender
session was touched.

## The models

All sizes are **# ASSUMPTION**: the PRD and `field_plot.gd` give no dimensions for these props.
The assumptions are: a field plot module is **2 x 2 m** (field_plot.gd's `field_small` fallback
collider is `Vector3(2.0, 0.2, 2.0)` and the build grid is 1 m cells), a path tile is **2 x 2 m**
and at most **0.05 m high**, the fence run is **2 m** (the same run length as the existing
`fence.glb`), and the other props are sized against the 1.8 m survivor.

| Model | Size (x, y up, z) m | Tris | Notes |
|---|---|---|---|
| `field_tilled` | 2.30 x 0.17 x 2.30 | 340 | dark furrowed soil, five heaped furrow ridges, broken earth berm |
| `field_crop_0` | 2.30 x 0.23 x 2.30 | 1108 | seedlings: two small leaves per shoot, 4 rows x 6 |
| `field_crop_1` | 2.30 x 0.38 x 2.30 | 1300 | young plants, three leaves, taller stalk |
| `field_crop_2` | 2.30 x 0.54 x 2.30 | 1300 | grown plants, darker leaves, tallest stalk |
| `field_crop_3` | 2.30 x 0.60 x 2.30 | 2260 | ripe plants with clay-red fruit, harvestable look |
| `path_dirt` | 2.00 x 0.07 x 2.00 | 104 | packed dirt on a grass base, pebbles |
| `path_dirt_corner` | 2.00 x 0.07 x 2.00 | 96 | L of packed dirt, grass inside the turn |
| `path_stone` | 2.00 x 0.05 x 2.00 | 132 | 3 x 3 flat cobbles in a dirt bed |
| `path_stone_corner` | 2.00 x 0.05 x 2.00 | 144 | L of cobbles, grass inside the turn |
| `fence_post_rail` | 2.01 x 1.41 x 0.21 | 272 | two sharpened posts, two rails, rope lashings |
| `fence_post_rail_gate` | 2.04 x 1.71 x 0.31 | 428 | two posts, a lintel and **node `Leaf`** (origin on the hinge at x = -0.86 m) |
| `trellis` | 1.28 x 1.72 x 0.41 | 380 | A-frame lattice with two climbing vines |
| `scarecrow` | 1.06 x 1.90 x 0.38 | 260 | straw head, straw hat, cloth shirt, straw hands |
| `compost_heap` | 1.00 x 0.86 x 0.76 | 464 | slatted bin full of compost, straw on top, a fork leaning on it |
| `water_trough` | 1.50 x 0.52 x 0.63 | 140 | plank trough, iron bands, water surface |

Conventions follow the structure set (`docs/orchestration/reports/claude-mmo-w1-structart.md`): one
material (the shared atlas), origin at the ground centre, front faces +Z in Godot, real metres.
Every GLB has one node except the gate, whose leaf is a child node with its origin on the hinge, so
code can swing it the way `placed_building.gd` swings the existing gate's `LeafL`/`LeafR`.

## The atlas

Eight tiles were appended to `lib.TILES` (indices 38-45): `soil`, `soil_dark`, `grass`,
`crop_leaf`, `crop_leaf_dark`, `straw`, `compost`, `soil_ridge`. The 38 existing tiles keep their
index and their paint, so the other 24+ GLBs of the structure set rebuild unchanged. The soil
tiles are deliberately low contrast and free of directional stripes: a striped soil texture made
the tilled bed read as planking at the iso camera's distance (fixed, see below).

## The manifest

`game/data/props_manifest.json` has a new top-level `farm` section with one row per model:
`glb`, measured `aabb_m`, `tris`, `art_status: REVIEW`, a note and the standard low-poly
`upgrade` path. The farm models are **not** building kinds, so they do not become placeable
properties and do not collide with `build_grid.gd`'s footprint rules; the game picks them up by
name. `tools/blender/structures/check_manifest.py` writes and checks the section (material, one
atlas, ground level, square plots, triangle budget).

## What the contact sheet showed

`docs/orchestration/reports/dsc-farmkit-sheet.png` renders all 15 models from the game's own
camera (perspective, pitch 38.7 deg, yaw 45, the game's 4.3 deg vertical field of view) with the
survivor GLB scaled to 1.80 m standing beside the ripe plot, the scarecrow and the trough.

What it showed, and what was fixed because of it:

- The first renders read as **wooden planks**, not soil: the furrow ridges were boxes and the soil
  tile had vertical stripes. Fixed by building the ridges as triangular heaps, dropping the
  stripes from the soil tiles and adding a separate mottled `soil_ridge` tile.
- The gate's leaf **floated away from its frame**: the leaf was modelled around the origin while
  the node origin sat on the hinge, so the export offset it by the hinge. Fixed by modelling the
  leaf in place and moving the origin to the hinge, like the existing gate.
- The compost heap read as **scattered dark rocks**. Rebuilt as a slatted bin with a heap inside.
- The crop leaves were flat squares; they are now tapered wedges that lean off the stalk.
- The path tiles' grass was too dark against the terrain, so it was lightened.

Final read: the five plots step clearly from bare furrowed soil to ripe red-fruited crops, the
path tiles read as dirt and stone surfaces with a grass corner, the fence run and the gate read as
the same family as the existing `fence.glb`, and the trellis, scarecrow, compost bin and trough
all read at their real size next to the 1.8 m figure.

## Known limits

- The crops are one generic leafy plant with clay-red fruit, not per-crop species: the PRD lists
  no crop roster, so one plant serves all four stages.
- `field_crop_*` models carry their own bed, so swapping a crop stage means replacing the whole
  plot model (the field's own logic may want to hide the bed instead).
- Low-poly and albedo-only, like the rest of the set: the PBR pass is the same open item as the
  structure set (`build-art-03` in the plan register).
- The models are not wired into the game: `field_plot.gd` still draws its own fallback, and the
  path tiles have no placement code. That belongs to the game-side owner.

## Verification

- `bash .../dsc/verify_blender.sh farmkit m1` -> `VERIFY STAGE 1 PASS` (the field group).
- `bash .../dsc/verify_blender.sh farmkit m2` -> `VERIFY STAGE 1 PASS` (the field and path groups).
- `bash .../dsc/verify_blender.sh farmkit 1` -> `VERIFY STAGE 1 PASS` (all 15 models).
- `bash .../dsc/verify_blender.sh farmkit` -> full gate: manifest rows, contact sheet, report,
  scope and a Godot import with no errors on the new models.
- `python3 tools/blender/structures/check_manifest.py` -> `[check_manifest] PASS 41 kinds resolve to
  existing GLBs`, plus a `farm.*` line per new model.
