# SPRITES2D: cut the owner's green-screen sheets into 2D game sprites

Shipped the cut-out pipeline and its data. Everything runs over every `docs/reference/2d-assets/sheet-*.webp`,
so a new sheet needs only a re-run of `cut.py` (plus a naming pass in `label.py`). No GDScript or scenes touched.

## What shipped

| file | role |
|---|---|
| `tools/sprites2d/cut.py` | key -> despill -> split -> trim -> PNG + `game/data/world/sprites2d.json` |
| `tools/sprites2d/overrides.json` | hand boxes: `split`, `merge`, `drop` per sheet |
| `tools/sprites2d/label.py` | the reading table of every sheet -> writes `tools/sprites2d/labels.json` |
| `tools/sprites2d/labels.json` | name/kind/height/blocks/destroyable/pivot per sprite, survives re-cuts |
| `tools/sprites2d/contact.py` | builds `docs/orchestration/reports/dsc-sprites2d-sheet.png` |
| `game/assets/nature/sprites2d/<sheet>/` | 117 trimmed RGBA PNGs |
| `game/data/world/sprites2d.json` | manifest, one row per sprite |

## Sprites per sheet

| sheet | sprites | PNG MB | mapped |
|---|---|---|---|
| sheet-beach-shells | 30 | 4.1 | 30 (shells, shell piles, driftwood, coral rock, icons) |
| sheet-jungle-plants | 42 | 4.9 | 29 (ferns, cycads, vines, shrubs, grass, log tangles) |
| sheet-palms | 21 | 4.3 | 13 (palms, crown, trunk, stump, root ball, coconuts) |
| sheet-resources | 24 | 3.8 | 24 (crystals, boulder, clay, logs, plants, fruit, bones, shells) |
| **total** | **117** | **16.4 MB** | **96 (82 %)**, 21 `unused` leaf/frond fragments |

Budget is 24 MB; the set sits at 16.4 MB, so a future cliff/tree sheet has ~7 MB of headroom before
anything needs rescaling (the script writes at native painted resolution).

## Thresholds and why

- **Key colour** (5, 250, 4). Alpha = distance in RGB units: fully clear at <= 28 (covers the key's
  own ~2/channel spread), fully opaque at >= 78, linear between.
- **Foliage test.** On these sheets leaf greens sit 95+ units from the key, so `D_SPILL = 95`: an
  opaque pixel closer than that is screen mix, not paint. This is the single most important number:
  it is why no "green is largest" heuristic is used and why moss/leaf interiors survive.
- **Despill.** Boundary = part-transparent pixels + a 3 px ring next to the clear background + any
  near-key pixel. Each boundary pixel takes the colour of the nearest real paint (BFS over 6 rings,
  8-neighbour), and its green excess is capped at `min(paint excess - 6, item mean - 10)`, so a rim
  is never greener than the item it sits on. Boundary pixels with no paint in reach get
  `G = max(R,B) + 2`, and a final belt-and-braces pass pushes any visible pixel out of the 92-unit
  neighbourhood of the key. Measured result: 0.0 % opaque key-green, ~0 % edge key-green, no edge
  greener than its interior on any sprite.
- **Segmentation.** Full resolution (half-res sampling lost 1-2 px frond stalks and welded
  neighbours), 1 px close, 4-connected run-length flood fill, drop components under 1000 px,
  discard items under 30 px on a side, trim with 2 px transparent padding. The alpha inside a
  bbox is multiplied by the item's own component mask, so art near a neighbour never leaks in.
- **Overrides.** `split` boxes are removed from the mask *before* labelling (removing after
  labelling only slices one component, it does not separate two items). `merge` unions every
  component a box touches; `drop` removes components mostly inside a box.

One override is in use: `sheet-jungle-plants [318, 0, 20, 290]`, which separates the two ferns that
touch at the top left. Everything else separated cleanly without hand boxes; the contact sheet was
reviewed per sheet at 300 px cells (and at 2x zoom on suspicious crops) for halos, clipped fronds,
glued pairs and split shells.

## Mapping rules used

- `kind` is a `nature_manifest.json` family id where the art is that resource (`PalmTree`,
  `Plant`, `VinePlant`, `ReedPlant`, `WildGrass`, `Rock`-family boulder, `GraniteBoulder`,
  `WoodLog`, `WoodLog_Moss`, `MangoBush`, `HerbPlant`, `clay`, `TreeStump`, ...), `prop:<name>` for
  scenery (`prop:shells`, `prop:driftwood`, `prop:coral_rock`, `prop:palm_crown`,
  `prop:fallen_trunk`, `prop:root_ball`, `prop:log_tangle`, `prop:mushroom_clump_*`,
  `prop:crystal_cluster`, `prop:bamboo_bundle`, `prop:rock_chip`, `prop:moss_rock`), `icon:<item>`
  for loose bag items (coconuts, bananas, chestnuts, bones, tusk, clam/scallop/open shells,
  seashells, oyster shells), and `unused` for single leaves/fronds.
- `blocks`: families follow the game's `HarvestNode.blocks_movement()` (tree role, or family height
  span top above 1.25 m) — so palms, reeds, `GraniteBoulder` and `MangoBush` block; `ReedPlant`
  is a family, not a grass prop, and the checker blocks it. Props block when `height_m > 1.25`;
  grass/reed props never. Hanging vines/roots, icons and `unused` never block.
- `destroyable`: true for everything on these four sheets — there is no cliff, arch, pillar or
  waterfall of 4 m or more here (owner rule: only those are indestructible). The big boulder pile is
  2.0 m, so it stays destroyable.
- `pivot`: ground contact = centre of the bottom 3-pixel band of visible pixels (so a leaning palm
  pivots under its trunk base, not its bounding box). Hanging vines and root curtains use the top
  attach point instead.

## What CARD2D needs

- Read `game/data/world/sprites2d.json`, field `sprites`.
- `file` is a `res://` path to the PNG; `px` is its pixel size (matches the PNG, alpha included);
  `src_rect` is where it came from on the sheet (useful for tweaking cut settings, not needed to
  draw).
- Draw the sprite with its local origin at `pivot` (px from the image's top-left): `pivot.y` is the
  ground line, `pivot.x` the trunk/base centre. Scale factor = `height_m / px.y` if you want the
  painted item to stand at its stated height; the art includes the padding, so prefer scaling by
  `height_m / (px.y - 4)` if you need the last 1 %.
- `kind` is safe to match: a family id is a harvest node, `prop:*` is scenery, `icon:*` suits a bag
  icon and should not be placed in the world, `unused` should not be drawn.
- `blocks` and `destroyable` are already resolved from the game rules — use them directly rather
  than re-deriving from `height_m`.
- Families with painted art now: `PalmTree`, `TreeStump`, `Plant`, `VinePlant`, `ReedPlant`,
  `WildGrass`, `GraniteBoulder`, `WoodLog`, `WoodLog_Moss`, `MangoBush`, `HerbPlant`, `clay`.
  Everything else still uses the 3D/baked cards.
- PNGs are straight (non-premultiplied) 8-bit RGBA; Godot's default importer settings did not need
  changing (headless `--import` reports no errors on any of the 117 files).

## Could not split cleanly / caveats

- The jungle-plants sheet has 13 single leaves/fronds in its bottom rows that are fragments of
  larger plants. They are cut and kept but labelled `unused`; they are the reason 21 of 117 rows
  are `unused`.
- Palm crowns painted from above (palms_04/05) read ambiguously as either a crown or a young palm;
  they are labelled `prop:palm_crown`. Palette and shape match the crowns, not the young palms.
- Two palms at the top left of sheet-palms overlap slightly in their fronds; the `split` would have
  to cut real fronds, so they are kept as one sprite (palms_01 is the largest tree, palms_02 the
  next). The contact sheet shows no visible double image.
- Coconuts painted on the trunk region of palms read as `icon:coconuts`; anything that is really a
  palm-top detail is `prop:palm_crown`.

## Assumptions (all heights are `# ASSUMPTION`)

- Every `height_m` was judged from the art against the task's ranges, not measured from a 3D
  reference: palms 2.5-12 m (young palm 2.5, leaning 10, tall 11, large 12), jungle plants
  0.5-1.4 m, grass 1.2-1.4 m, reeds 1.5-1.6 m, boulder pile 2.0 m, clay mound 0.9 m, logs
  0.8-0.9 m, mushrooms 0.6-0.7 m, shells 0.2-0.4 m, icons 0.2-0.6 m, stump 1.2 m, root ball 1.0 m.
- The pivot for hanging vines/root curtains is the top-centre attach point (task allows this);
  everything else is bottom-centre.
- `blocks` for `ReedPlant` follows the game family rule (blocks), which differs from the "tall
  grasses never block" prop rule; reeds are a resource family, not a `prop:reed*`.
- Cluster sheets that arrive later (jungle cliffs, jungle trees, tall grasses) will need their own
  `overrides.json` rows and a `label.py` table entry; the cutter itself is generic already.

## Verification

- `bash .../verify_sprites2d.sh 1` — PASS (keying, trimming, >= 10 sprites per sheet, <= 24 MB).
- `bash .../verify_sprites2d.sh 2` — PASS (mapping rules, 82 % mapped).
- `bash .../verify_sprites2d.sh` — PASS (contact sheet + report present, scope clean, Godot
  headless import with 0 errors on sprites2d files).
- `tools/sprites2d/cut.py` runs the whole set in ~8 s; `contact.py` in ~10 s.
