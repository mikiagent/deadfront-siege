# Island map format (`*.map.json`, v1)

An authored island: what the owner paints in the map lab and hands to an agent or the island
generator to build. Files live in `game/data/maps/<name>.map.json`, each with a `<name>.png` preview
next to it. Reader, writer and validator: `game/scripts/world/map_doc.gd` (`MapDoc`). Editor:
`--lab=map_lab`. Test: `game/tests/t_maplab.gd`. Example: `game/data/maps/sample.map.json`.

## Running the map lab

```
Godot --path game -- --lab=map_lab                 # blank home-size map
Godot --path game -- --lab=map_lab --map=sample    # open game/data/maps/sample.map.json
Godot --path game -- --lab=map_lab --make-sample   # rewrite sample.map.json + sample.png, then quit
```

- **Paint** (left): Land, Sea, Erase (clears height, zone, water and road, keeps the land), the
  height classes Low / Hill / Mountain, River, Lake, Road. **Fill** turns any paint tool into a flood
  fill of the connected region with the same value. `-` / `+` set the brush radius in cells (0 = one cell).
- **Zones**: one button per zone in `biomes.json`, and Unset (the generator decides).
- **Markers**: Select (tap a marker to edit it, drag to move it) and one tool per marker kind. A
  tap drops a marker. Its fields show under **Selected marker** on the right.
- Header: Undo, Redo (also ctrl+Z / ctrl+Y), Validate, Export. Export writes `<name>.map.json`
  and `<name>.png` into `game/data/maps/`. **Save draft** / **Load draft** use `user://maplab/`.
  Load draft falls back to `game/data/maps/` when no draft has that name.
- **Map**: name, climate, size preset (Home 416 m, Tutorial 880 m, Custom) and the cell size.
  **New map** starts a blank grid of that size. You can undo it.
- **Layers** turns zones, height, water, roads, markers and grid lines on and off in the view.
  Hiding a layer does not change the data.

Every control is a 64 px tap target. A touch arrives as a mouse event, so tap and drag paint on a
phone too. There is no pinch zoom: the canvas always shows the whole map.

## The grid

| field | meaning |
|---|---|
| `format` | always `"wildlands.map"` |
| `version` | `1`. A reader refuses any other version. |
| `name` | the file name without `.map.json` |
| `climate` | one climate row of `game/data/world/biomes.json` (grassland, savannah, temperate, tropical, tundra, desert, swamp, snowfield, blue_tropical, volcanic). One climate per island (islands plan ruling 1). |
| `size_m` | the side of the square grid in metres. It equals the island's `size_m`: home 416, tutorial 880. |
| `cell_m` | the side of one cell in metres. The default is 4 (*ASSUMPTION*). |
| `cells` | cells per side, `size_m / cell_m` |

The grid is centred on the world origin, like the island grid. Cell `(col, row)` covers
x = `-size_m/2 + col*cell_m` to `+cell_m`, and z the same way from `row`. Row 0 is the north edge
(-z) and col 0 is the west edge (-x). A cell's centre is at `-size_m/2 + (col + 0.5)*cell_m`.

## Layers

`layers.<name>` is an array of `cells` strings, one per row from north to south, with one
character per cell from west to east. `legend` in the file repeats the table below.

| layer | characters | notes |
|---|---|---|
| `land` | `.` sea, `#` land | The coastline runs along cell edges. |
| `height` | `0` low, `1` hill, `2` mountain/cliff | Ground target in metres: `height_m` = [1.2, 4.5, 10.0] (*ASSUMPTION*: the plan's hills are 3-6 m and its terraces are 3.2 m risers). |
| `zone` | `.` unset, `m` meadow, `f` forest, `s` savanna, `c` canyon, `b` basalt, `w` wetland, `e` beach, `r` rocky | The biome zones of `biomes.json` (`BiomeZones.ZONE_NAMES` order). Unset cells keep the generator's zone. |
| `water` | `.` none, `~` river, `o` lake | Rivers are painted cells. A river should reach the sea or a lake. |
| `road` | `.` none, `=` road/path | Data only for now (see the importer). |

Only land cells carry height, zone, water or road. Painting sea clears them.

## Markers

`markers` is an array of `{id, kind, x, z, props}`. `x` and `z` are world metres (0.1 m
resolution), and `id` is unique within the file.

| kind | props | meaning |
|---|---|---|
| `town` | `name` | Town centre. It is the camp hint when there is no `camp`. |
| `dock` | `name` | Harbour. It must sit on the coast: land and sea within 2 cells. |
| `camp` | `name` | Camp centre (the island's `camp`). |
| `guild` | `name` | The Adventurer's Guild building. |
| `landmark` | `name` | A named point of interest (peak, pond, ruin). |
| `resource` | `resource`, `count`, `radius_m` | A cluster of `count` nodes within `radius_m`. `resource` is one of trees, rock, fibre, berries, herbs, clay, reeds, ore, flint, salt. The builder picks the climate's family for it. |
| `spawn` | `species`, `level`, `count`, `radius_m` | A creature group. `species` is a `game/data/creatures/<id>.json` id. `level` is 1-60. |
| `claim_free` | `name`, `radius_m` | No player claims inside this circle (town, guild, dock approaches). |

`level` and `count` are integers, and `radius_m` is metres.

## Validation (`MapDoc.issues()`)

Each issue is `{level, code, msg}`. An `error` makes the map unusable. A `warn` is worth a look.

| code | level | when |
|---|---|---|
| `no_land` | error | no land cell |
| `unknown_climate` | error | `climate` is not a climate row |
| `marker_off_map` | error | a marker outside the grid |
| `dock_not_coast` | error | a dock with no land and sea within 2 cells |
| `marker_in_sea` | error | any other marker on a sea cell |
| `unknown_marker` | error | a kind not in the table above |
| `unknown_species` / `bad_level` / `bad_count` | error | spawn species missing, level outside 1-60, count < 1 |
| `unknown_resource` | error | a resource group not in the list |
| `land_at_edge` | warn | land within 24 m of the grid edge (the plan keeps that much sea) |
| `no_dock` / `no_camp` | warn | no harbour, or neither a camp nor a town |
| `river_no_outlet` | warn | a connected river that touches neither the sea nor a lake |

## Building an island from a map

**The importer (works today).** An island definition with `"map": "res://data/maps/<name>.map.json"`
(or `MapDoc.island_def(base)`, which fills in the rest) builds through the normal `IslandRuntime`.
`MapDoc.apply_to_shape` replaces `IslandShape.compute()`:

- Land and sea come from the land layer, through a signed coast distance, so the coast is smooth
  and not cell steps. Sea drops at 0.6 m per metre to -3 m.
- Ground height ramps from the waterline to the painted class's height over 6 m inland. The
  classes are blurred over about 3 cells, so hills are slopes and mountains turn rock and cliff on
  their own (slope rules in `IslandTerrain`).
- River and lake cells are carved to the -0.3 m MUD bed, with 3 m banks. That makes them fresh
  water, and TilePath routes around them.
- After the generator's zone pass, `MapDoc.paint_zones` writes the painted zones over it. Unset
  cells keep the generator's zones, and the sandy-beach rule still runs.
- `island_def` takes `harbour` from the dock marker, `camp` from the camp marker (else the town),
  and `creatures` from the spawn markers (`species`, `count`, `at`, plus `level` as data). The
  harbour snaps to the legal coast pose nearest the dock, as for every island.

Run `Godot --path game -- --lab=islandgen_lab --map=<name> --shot-dir=<dir>` for a top-down shot
of the built island and its coast metrics.

**Not imported yet. These are data an agent places by hand:**

- `town`, `guild`, `landmark`: no buildings or props are placed. The tutorial island's town
  (`Tutorial.dress`) is the pattern to follow.
- `resource` clusters: the normal scatter still places the resource nodes by zone, and the clusters
  are not used yet.
- `claim_free`: not wired into `IslandClaims`.
- `road`: no path tiles are painted.
- Spawn `level` and `radius_m`: the spawner uses the island tier and places the group at `at`.
- The river is cells, not the generator's polyline, so `IslandShape.river`, the ford and the waterfall are
  empty on a map-built island (islandgen_lab prints `river_to_sea=false`). Rivers drawn at 4 m cells
  show small steps.

To build one by hand, read the file with `MapDoc.load_file`, then use `doc.cell_of(x, z)`,
`doc.get_cell(layer, col, row)` and `doc.markers` to place things. Run `doc.issues()` first.
