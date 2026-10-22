# SPRITES2D: cut the owner's green-screen sheets into 2D game sprites

Round 3 (merge-review fixes) of the cut-out pipeline. Everything runs over every
`docs/reference/2d-assets/sheet-*.webp`, so a new sheet needs only a re-run of `cut.py` plus a naming
pass in `label.py`. No GDScript, scenes or scripts touched.

## What shipped

| file | role |
|---|---|
| `tools/sprites2d/cut.py` | per-sheet key -> despill -> split -> trim -> downscale -> PNG + `game/data/world/sprites2d.json` |
| `tools/sprites2d/overrides.json` | hand boxes: `split`, `merge`, `drop` per sheet |
| `tools/sprites2d/label.py` | matches `label_table.json` rows to sprites by exact `src_rect` then IoU >= 0.7, writes `labels.json` |
| `tools/sprites2d/rules.py` | shared label matching + blocks/destroyable/hanging rules used by cut.py, label.py and tidy_table.py |
| `tools/sprites2d/tidy_table.py` | reconciles `label_table.json` with the manifest after a re-cut; `label_new.json` names new crops |
| `tools/sprites2d/audit.py` | 2x-on-two-grounds review renders per sheet |
| `tools/sprites2d/label_table.json` | one row per sprite: `[sheet, x, y, w, h, name, kind, height_m]` |
| `tools/sprites2d/labels.json` | name/kind/height/blocks/destroyable/pivot per sprite |
| `tools/sprites2d/contact.py` | builds `docs/orchestration/reports/dsc-sprites2d-sheet.png` |
| `game/assets/nature/sprites2d/<sheet>/` | 251 trimmed RGBA PNGs (+ Godot `.import` sidecars) |
| `game/data/world/sprites2d.json` | manifest, one row per sprite |

## Sheets

| sheet | sheet px | sprites | block | unused | PNG MB | key (border median) | max side | scale |
|---|---|---|---|---|---|---|---|---|
| sheet-beach-shells | 1254x1254 | 30 | 0 | 0 | 3.4 | (4, 249, 3) | 448 | 0.73-1.0 |
| sheet-jungle-cliffs | 1536x1024 | 69 | 29 | 0 | 4.0 | (2, 239, 2) | 704 | 0.77-1.0 |
| sheet-jungle-plants | 1254x1254 | 44 | 0 | 13 | 4.5 | (4, 250, 3) | 657 | 0.70-1.0 |
| sheet-jungle-trees | 1536x1024 | 17 | 16 | 1 | 3.1 | (3, 234, 5) | 663 | 0.76-1.0 |
| sheet-palms | 1254x1254 | 21 | 6 | 7 | 3.3 | (4, 250, 3) | 704 | 0.66-1.0 |
| sheet-resources | 1254x1254 | 24 | 3 | 0 | 3.5 | (4, 249, 3) | 448 | 0.85-1.0 |
| sheet-tall-grasses | 1448x1086 | 46 | 24 | 16 | 2.6 | (3, 250, 3) | 448 | 0.32-1.0 |
| **total** | | **251** | **78** | **37** | **23.2 MiB** | budget 24 MiB |

The four round-1 sheets are 1254x1254; the three later sheets the owner sent are not. The screen
green is also not the same on every sheet: jungle-trees is noticeably darker (G 234) and
jungle-cliffs slightly darker still. `cut.detect_key()` takes the median of a 6 px border ring per
sheet. A hardcoded key welded whole rows of jungle-trees into one 918x994 blob.

## Keying and despill (rewritten, round 3)

1. Soft alpha from RGB distance to that sheet's key: clear <= 28, opaque >= 78, colour un-mixed
   against the key.
2. `despill()`: rim = visible pixels within **2 px** of clear background. Each rim pixel copies the
   colour of the nearest real paint, grown inwards-to-outwards over at most 4 rings; rim green is
   capped at the paint's own green excess (its 90th percentile, which may be negative for sand,
   shell, rock) plus 12.
3. A visible pixel still within 95 units of the key is screen showing through a pinhole or a thin
   strand: it becomes fully transparent instead of being recoloured or faded. Fading alone left
   lime rows (1-5 % of opaque pixels were still screen green); recolouring alone painted khaki
   matte over real foliage.
4. `rim_fix()` is the per-item pass and only touches the outermost 2 px (it used to touch every
   pixel that was not 2 px eroded, which matted whole items).
5. After the holes are cleared the crop is trimmed again, so alpha reaches every border (the
   checker requires trimming within 3 px).

Round-3 regressions this fixes: `resources_09_red_heliconia`, `resources_10_white_flower_herb`,
`resources_08_berry_palm` had lost every leaf to flat tan (the old fallback painted anything
"greener than the item's average"); tall-grasses 12-30 and jungle-cliffs 24/26/42/47/48/55-60/64 and
jungle-trees 15-21 carried a 4-8 px opaque khaki matte.

## Downscale and size

`resize_area()` is an exact area-average (box) filter on premultiplied colour. Longest side is
exported at most **448 px**, or **704 px** when `height_m >= 8` (the tall trees and cliffs the
camera sees close in a 2D card). Softer limits (512/768) put the set at 24.4 MB. Every manifest row
carries the resulting `scale` and the resized `px`/`pivot`; the smallest scale is 0.32.

## Splits (overrides.json)

`split` partitions the touched component along the box centre line and keeps every pixel
(`split_by_box`); `auto_welds` does the same automatically where two clumps share a few blades at the
base, and is limited to the clump rows of tall-grasses so the isometric tiles and ground patches stay
one sprite each. Round-3 changes:

- **jungle-trees**: the boxes at x 1372, 525, 720, 1130, 1280 and 634/723 were deleted - they cut
  through canopy and fronds (05 had a flat right edge, 06 was its sliver, 11/12 had flat frond
  edges). The sheet is now cut on the real green bands only: two horizontal boxes separate the
  buttress tree / palms row / vine-tree row in column 1. Where art genuinely overlaps it stays one
  sprite named as a pair (`canopy_tree_pair`, `palm_pair_leaning`).
- **tall-grasses**: the boxes were replaced by `auto_welds: [280, 650]`. It finds the nearly empty
  columns between two touching clumps and partitions the component there, so no rectangular bite can
  appear; the pass repeats on each half, so rows of three tufts separate too. 38 -> 46 sprites,
  every clump single and complete. A split used to fuse straight back because `split_sheet()` re-ran
  `label()` afterwards and the two halves are edge-adjacent; `relabel()` now renumbers without
  re-connecting.
- **jungle-plants**: [318,0,20,290] (two ferns) and [529,612,300,12] (bromeliad over broadleaf).
- **resources_08** stays ONE sprite: the berry bunch hangs under big green leaves that belong to
  the same plant; every split line tried cut the fruit away from its own leaves (recorded in
  `overrides.json` as `_note_resources_08`).

## Labels

`label.py` matches by **(sheet, exact src_rect)**, falling back to **IoU >= 0.7**, one-to-one.
Centre distance and index order both slid labels onto neighbours when a split changed the item
count. The script prints both directions (sprite with no row / row with no sprite); the current run
matches 251/251 with 0 rows unused.

Round-3 label corrections (all re-read from the crops): jungle-cliffs_19 palm+banana group (not a
cliff block), _20 boulder, _24/26/39/40/42/47 ferns, _33/34 vine curtains, and in 49-69 the shells,
driftwood and ferns sorted out; jungle-trees_01 giant buttress tree, _08 broadleaf tree, _12 vine
tree; jungle-plants_26 red flower shrub, _28 log tangle with ivy, 41-45 leaves/fern/moss;
tall-grasses ground tiles vs grass clumps vs loose tufts; palms_16-21 coconut cluster, fallen trunk,
stump, root ball, coconut bunch, one coconut; resources_21/22 bone shaft and fragment.

## Rules applied

- `blocks` follows `HarvestNode.blocks_movement()`: tree roles block, and any family whose height
  span reaches above 1.25 m. `prop:grass*` / `prop:reed*` never block. **Hanging vines and root
  curtains never block** (`prop:vine*`, `prop:root_curtain`) - 78 of 251 sprites block.
- Pivots are measured from each PNG's own alpha: bottom-centre band for ground props, top band for
  hanging vines and root curtains (`prop:root_ball` deliberately does NOT match, it is a ball on the
  ground), bottom-centre for waterfalls (they stand).
- `destroyable: false` for cliff walls, arches, pillars and waterfalls >= 4 m (18 sprites).

## Unused

37 sprites are `unused`: single leaves, canopy slivers, stem fragments, the isometric ground tiles
and big ground patches of tall-grasses (a colour reference on the sheet, not game art), and the
waterfall/rock fragments of jungle-cliffs. They are still cut and shipped as PNGs so the sheet stays
fully covered; the game simply never spawns them.

## Verification

- `check_sprites2d.py` stage 1 and 2: 0 failures (screen-green share of opaque pixels, edge fringe,
  trimming, px vs PNG, ids, kinds, heights, pivots, blocks, size budget).
- Full `verify_sprites2d.sh` (no argument): **VERIFY PASS**, including the Godot headless import.
- Visual self-check at 2x on sand (225,205,160) and dark grass (70,90,60) per sheet: resources,
  beach-shells, palms, jungle-plants, jungle-trees, tall-grasses, jungle-cliffs. See NOTES.md for
  what each sheet looked like; no khaki matte, no lime rim, no black ticks, no flat fills.
- Contact sheet: `docs/orchestration/reports/dsc-sprites2d-sheet.png` (251 cells, re-generated, reviewed in four crops at 180 px cells).

## Junk

`cut.py` deletes `<png>.import` together with a stale PNG and also sweeps orphan `*.png.import`
files (sidecar whose PNG is gone) in every sheet dir: 0 orphans on disk after a full run. `tools/sprites2d/__pycache__` is out
of git and `.gitignore`d. No `game/assets/props/meshy/*`, `game/scripts/dev/*.uid` or
`game/tests/*.uid` added.

## Assumptions

- `height_m` per sprite is a reading of the art against the game's nature families, not measured
  geometry; the same value drives the downscale limit.
- Ground tiles and big ground patches in tall-grasses are marked `unused` (the world builds its own
  ground); they are cut anyway.
- `icon:*` kinds for shells mirror the round-1 beach-shells naming so the inventory can use them.
