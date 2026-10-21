# Island map and Sail check (spec 15)

Read-only study on `claude/mmo-overhaul` at 9440552f, using the scratch tree trees/islandmap and probe/islandmap_probe. Nothing was committed. I looked at every shot in `scratchpad/islandmap/shots/` and at the reference `docs/reference/durango-island-map.webp`. The Sail screenshot was not saved, so its description comes from spec 15 section 2.

## Verdict
- **Size:** unstable islands are close to the reference: 406 x 404 m of land, against about 300 x 374 m for Durango. Home is far too small at 134 x 131 m.
- **Shape:** every island is the same crinkled round disc. There are 4 distinct heightmaps across 15 islands, with coast radius within ±5 % and aspect 1.0. Durango's island is ragged and elongated (aspect 0.80).
- **Map screen:** a flat-colour pixel atlas with no fog, no scale bar, no info panel and no fatigue.
- **Travel menu:** a vertical list of 14 grey text rows. About 2.5 rows are visible at 844x390. It is not a rightward sea chart.

## Measurements

**Reference (1306x624)**
- The 50 m bar line is 44 px, so the scale is 1.136 m/px.
- Revealed land is 264 x 329 px, which is **300 x 374 m**. If the label is counted with the bar, it is 189 x 235 m.
- Spec 15's "165 x 215 m" estimate is low.

**Our islands**

| | Land | Area | Run 7 m/s, edge to edge | Coast P/√A | Camp to harbour |
|---|---|---|---|---|---|
| Home | 134 x 131 m | 13,663 m² | 19 s | 3.72 | 54 m |
| Unstable | 406 x 404 m | 122,716 m² | 58 s | 4.27 | 186–210 m |

**Our map screen:** it fits every island into a 762 px square at 1600x900. That gives 1.59 px/m for unstable islands and 4.76 px/m for home.

## Side by side (short)

| Element | Ours | Durango |
|---|---|---|
| Fog | none: everything, including resource and creature dots, is visible | cloud over unexplored land |
| Info panel | header line and 4 island cards | Lv header, Climate, Life Span, Fatigue N/100 and Change Rate, difficulty laurel, 50 m bar |
| Marker | white triangle, coordinates in header (can be negative) | gold ring, coordinates under it, dotted trail |
| Domain | none on map | "<name>'s Domain" with portrait |
| Legend | 8 items in a column, top right | 5 items in a row, bottom right |
| Buttons | Return to camp, Warp home, Harbour routes, Close | To Harbor, To Waypoint, X |
| Travel | vertical text rows | horizontal chart, level bands darkening to the right, nodes with art and ? / check badges |

## Packages

1. **SAILUI**: the rightward chart.
   - **What:** Home Lv10 at the far left, then tier bands 15..60, one 96 px node per island with a state badge, and a card with a Sail button that calls the unchanged `World.sail`. It also adds one shared island-name function.
   - **Gates:**
     - Content is at least 2x the viewport width, x increases with tier, and there is no vertical scroll.
     - Every tap rect is at least 64 px.
     - At least 6 nodes are visible at 1600x900 and at least 4 at 844x390.
     - t_harbour, camp_travel_probe and smoke pass, and island_lab still prints 378/24.
   - **When:** start now, using INVUI's Durango theme. It carries no count risk.
2. **MAPUI**: the island map rebuild.
   - **What:**
     - A filtered, painted-look map with a saved fog bitmask.
     - The left info panel, including a fatigue rate taken from the fatigue change over 60 s.
     - A scale bar of 50 m x px/m.
     - A gold-ring marker, a trail, the domain label with portrait, and shelter and bonfire markers.
     - A 5-item legend and To Harbor / To Waypoint.
   - **Gates:**
     - The scale bar is accurate to within 1 px at both sizes, and nothing overlaps.
     - Revealed land is at most 10 % on arrival and survives save/load.
     - No resource dots are drawn.
     - island_lab is unchanged.
   - **When:** after SAILUI, DOMAIN (portrait) and HUD-DAYNIGHT (both edit hunt_hud.gd).
3. **ISLANDSHAPE**: the generator, folded into W2-TERRAIN.
   - **What:**
     - A per-id seed, an elongated and lobed coast, and a grass edge that follows the coast.
     - The owner's size target, rings measured from the harbour, the camp within 40 m of the harbour, and craters inland.
     - Scatter scaled by area, and the 13 stale harbour hints fixed along with the t_harbour JSON check.
   - **Gates:**
     - Land size within ±10 % of the target.
     - At least 12 of 15 distinct heightmaps.
     - Aspect 0.70–0.90, P/√A 4.4–5.5 and solidity 0.80–0.92.
     - 40–55 s edge to edge at run.
     - One new island_lab baseline, with node density within ±15 % of today.
   - **When:** last, after the finish-6 merge lands and the owner answers Q1.

## Quick fixes found
- 13 data/islands hints are 256–288 m from the real dock.
- t_harbour's "JSON harbour = arrival point" check reads the row after it was overwritten, so it cannot fail.
- temperate_25's crater is at r 184.5, past land_radius 182.4, so it sits on the beach.
- The atlas names temperate_20/35/45 all "Temperate Island".
- Savannah draws green on the atlas but is tan in 3D.

## Owner questions
1. Size target: keep ours, use the reference (about 300 x 375 m for both home and unstable), or use the docs (160 / 240 m)?
2. Chart nodes: keep 14 fixed islands, or switch to climate seas that roll a seeded island on each trip and each sinking? Should the chart also add the missing Lv18 sea, Ancora, the Safe House and a city island?
3. To Harbor / To Waypoint: walk, or teleport (free or paid)? Should sailing stay possible from anywhere on the island?

## Not checked
- Forward+ shots.
- Walking times along nav paths (straight lines only).
- A top-down image of the temperate shape (measured only).
- Whether Durango's buttons teleport.
- Land hidden under the reference's fog.
