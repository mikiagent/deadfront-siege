# claude-townpolish: the tutorial town, polished in a pixels loop

Branch `claude/mmo-townpolish` (pushed, not merged), from `origin/claude/mmo-overhaul`, with canon
48f132d3 and NORTHUP (north-up camera) merged. Six capture rounds, each judged by eye, defects listed
in `docs/orchestration/reports/townpolish/round-N/defects.md`.

Scope: the whole town except the guild/faction hall and its plaza (claude/mmo-factions). `_guild_hall`
and `_pit_shelter` are untouched, but the hall is built by the shared `house()`, so it now gets a
town-kit roof (`town_roof_*_10x8`) like every other house.

## How the shots are made
`game/scripts/dev/townpolish_shots.gd`: a fresh new game (`--new-game --occupation=soldier`,
`--weather=clear`), windowed off-screen at `--position 6000,3000`, self-quitting. It aims at real lots
(the lot nearest each district's centre, plus a second one further out), and shoots the game camera
(default and zoomed out), street level with the survivor for scale, every gate and an overview, by day
and by night, at 1600x900 and 844x390 (`--quick` = game camera only). Debug flags: `--only=<name>`,
`--hide=<runtime child>`, `--spot=x,z`.

```
Godot --path game --position 6000,3000 --resolution 1600x900 --script res://scripts/dev/townpolish_shots.gd \
  -- --new-game --occupation=soldier --weather=clear --out=<dir> [--quick]
```

## What changed
**Blender town kit** (`tools/blender/structures/townkit.py`, headless `build.py`, sheet `townkit_sheet.py`):
- 24 whole roofs `town_roof_<thatch|shingle|slate|tile>_<LxS>`. Each has lapped courses, eave fascia, barge boards, a ridge roll or cap, and closed gable ends with a vent or attic window. They are sized to the house plan, so they always sit on the walls.
- `town_chimney`, `town_lamp`, `town_gate`, `town_stall`, `town_awning`, `town_woodpile`, `town_flowerbox`, `town_cart`.
- Two new atlas tiles, `roof_tile` and `plaster`, appended. Existing tiles are unchanged.

**town_dress.gd**:
- Props and houses show at the game camera. The visibility ranges were 110 m and 220 m, but the camera stands 186-240 m back. They now come from `IsoCamera.cull_range`.
- Houses use the kit roofs. The blue floating gable triangles and the noise "thatch" are gone. Doors hang in their doorways.
- Windows have warm glass that lights after dusk. Lamps and stalls have glowing glass and a halo. One shared material follows the clock, with no real lights added.
- Fixtures: awnings, flower boxes, woodpiles and chimneys.
- Stalls: a kit frame, a striped canvas and a lantern.
- Workshops: kit roofs and darker floors.
- Gates: one kit gate on the avenue axis, never half in water.
- Fields and gardens: planted 4x3, each bed seated on its own ground.
- Yard clutter fills gaps: carts, woodpiles, barrels, straw, wells and troughs.
- Ground: inside the wall, the tall reeds and ferns go and about a third of the grass stays. Road tiles between cross-sections are now cleared too.
- Pathing: the t_tutorial bot wedged in pinches the new layout made. Gate towers now mark every tile they cover, and wicket posts no longer stand beside a gate. Lamps keep 2 m clear of walls, and clutter stays out of the router grid.
- Chunks are 120 m (was 80 m), which keeps the batch count in budget.

## Before / after (round-1 vs round-6, same folder names)
| What | Before | After |
|---|---|---|
| Homes, game camera | round-1/homes_game_day_1600x900.png | round-6/homes_game_day_1600x900.png |
| Market | round-1/market_game_day_1600x900.png | round-6/market_game_day_1600x900.png |
| Farms | round-1/farms_wide_day_1600x900.png | round-6/farms_wide_day_1600x900.png |
| Gate | round-1/gate_144_day_1600x900.png | round-6/gate_144_day_1600x900.png |
| Night | round-1/pens_game_night_1600x900.png | round-6/pens_game_night_1600x900.png |
| Street level | round-1/homes_street_ring_day_1600x900.png | round-6/homes_street_day_1600x900.png |
| Overview | round-1/overview_day_1600x900.png | round-6/overview_day_1600x900.png |
| Phone | (none in round 1) | round-6/*_844x390.png |

Round 1 used angle-based aims, and some of its shots look at the sea. From round 2 on, every shot is
aimed at a lot.

## Gates (merged tree)
| Gate | Result |
|---|---|
| t_tutorial (own HOME, TEST_TIMEOUT 1200) | PASS (449 s); also 2/2 PASS run in parallel before the last canon merge |
| t_tutguide | PASS |
| t_perfgates | PASS: tutorial scene_nodes 5,885 (cap 9,000), ticking 29 |
| t_islandgen | PASS |
| run_all | `[tests] PASS` |
| `tools/smoke.sh --no-import` | SMOKE PASS |

Town numbers: 49 houses, 13 stalls, 4 workshops, 8 fields, 4 pens, 24 lamps, 169 MultiMeshes,
2,709 instances. The town builds in about 550 ms.

## What remains (not ship-blocking)
- Some open grass between homes. A tree prop would help; the tutorial's tree cards are harvest nodes.
- Lamps dropped from 41 to 24. The ones that would have made a pinch are skipped.
- A road strip breaks on a wet or steep point and the terrain shows through (round-6/workshops_wide_day).
- Fence modules show double posts at the joins.
- **Other packages:**
  - Occlusion dithers houses beside the survivor, not only in front of him.
  - The survivor sits knee-deep on slopes after a teleport (player ground snap).
  - While I chased the reeds, I suspected physics interpolation was keeping cleared cards drawn. That turned out to be wrong: the reeds were the tall share of the third I kept. TownDress still resets interpolation on the cards it clears, as a harmless guard.

## Assumptions
Every kit size, pitch, overhang and density here is `# ASSUMPTION` (TT1 family): roof pitches (thatch
0.9, others 0.62), the clutter rate, one third of the grass kept, the 2 m lamp clearance and the 8 m
gateway band.

## Credits
None spent (Blender only, no Tripo or Meshy).
