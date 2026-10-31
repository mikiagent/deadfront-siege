# Round 1 defects (canon town, origin/claude/mmo-overhaul 24d2a22f)

Shots: this folder, 1600x900, captured by `game/scripts/dev/townpolish_shots.gd` (fresh new game,
`--occupation=soldier --new-game`). Round 1 aimed districts by angle and several shots landed in the
sea (harbour_wide, workshops_*); round 2 aims at real lots.

| # | Defect | Where seen | Severity |
|---|---|---|---|
| D1 | Every GLB prop is invisible at the game camera: FAR_PROP 110 m, but the iso camera stands 186 m back (240 m at max zoom). Fences, palisade, crates, barrels, fields, stalls' goods, piers' clutter all missing; houses (220 m) drop out at max zoom. The town reads as empty boxes on grass. | homes_game_day, farms_wide_day, overview_day | ship-block |
| D2 | Gable triangles render flat sky-blue (one-sided plaster quad, normal lit from the wrong side) and poke past the roof as thin spikes. | homes_game_day, market_game_day, gate_144_day, homes_street_ring_day | ship-block |
| D3 | Roofs are a unit prism with blotchy noise "thatch"; slate/tile are flat colour. No eaves, ridge or barge boards: reads unfinished. | all house shots | major |
| D4 | Gate beam turned the wrong way (crosses the opening diagonally, one black end face); gate is three bare boxes. | gate_144_day | ship-block |
| D5 | Tall reeds, ferns and bushes all over streets and yards inside the town (only footprints and roads cleared). Weedy, abandoned look. | homes_game_day, market_game_day, farms_wide_day | major |
| D6 | Door leaf hung half outside the doorway (hinge origin placed at the doorway centre): half the doorway open onto the blue roof underside. | homes_game_day (blue door slot) | major |
| D7 | Lamps: a pale box on a stick; by day it looks like a sign, at night no glow round it. | homes_game_day, *_night | major |
| D8 | Night: town is dark, no lit windows; only the player's torch reads. | *_night | major |
| D9 | Big empty dull areas between houses (partly D1, partly no clutter). | homes_game_day, farms_wide_day | major |
| D10 | Probe: rain in night shots (weather random); fixed with `--weather=clear`. | pens_game_night | probe |
