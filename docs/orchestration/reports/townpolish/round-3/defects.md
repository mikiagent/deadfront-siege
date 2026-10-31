# Round 3 defects (after round 2 fixes)

Fixed since round 2 (visible here): streets and yards clear of reeds and ferns (road rows between
cross-sections marked; tall cards cleared inside the wall), fields fully planted, darker workshop
floors, 184 MultiMeshes at 120 m chunks, yard clutter (carts, woodpiles, barrels, straw, wells,
troughs) in the gaps.

| # | Defect | Where seen | Severity |
|---|---|---|---|
| R3-1 | Two bare wicket posts stand inside the avenue gate opening (a wicket next to a gate puts its posts in the gate). | gate_144_day | ship-block |
| R3-2 | Crop modules stand on lawn, not in soil: no tilled bed under the crops. | farms_wide_day | major |
| R3-3 | Inside the wall every tall card AND most short grass went: lots read as flat mown lawn (threshold 0.5 m caught grass too). | homes_wide_day, pens2_wide_day | minor |
| R3-4 | Market after dark: stalls are black shapes, no light. | market_game_night | major |
| R3-5 | Street-level probe stood the survivor knee-deep on slopes (probe placement, not the town). | gate_144_day, homes2_street_day | probe |
| R3-6 | Fence segments leave double posts and 15 cm gaps at module joins (fence.glb is 2.0 m, segments are 2.15 m apart). | homes2_street_day | minor (kept) |
| R3-7 | Houses near the player go see-through (Occlusion dither) even when they are not between the camera and the survivor, e.g. pens2. Occlusion is another package's system; noted, not changed. | pens2_wide_day, harbour_wide_day (round 2) | not this package |
